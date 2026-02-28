// ViewModels/AuthViewModel.swift

import SwiftUI
import Combine
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: NSUser?
    @Published var firebaseUser: User?
    @Published var isLoading = true
    @Published var error: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    
    init() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.firebaseUser = user
                if let uid = user?.uid {
                    self?.currentUser = try? await FirebaseService.shared.fetchUser(uid: uid)
                } else {
                    self?.currentUser = nil
                }
                self?.isLoading = false
            }
        }
    }
    
    // MARK: - Email Auth
    func signUp(email: String, password: String, name: String) async {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            var user = NSUser.empty
            user.name = name
            user.email = email
            try await FirebaseService.shared.createUser(user)
            self.currentUser = user
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func signIn(email: String, password: String) async {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.currentUser = try await FirebaseService.shared.fetchUser(uid: result.user.uid)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func signOut() {
        try? Auth.auth().signOut()
        currentUser = nil
        KeychainService.shared.delete(key: "authToken")
    }
    
    // MARK: - Apple Sign In
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let tokenString = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else { return }
            
            let firebaseCredential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: tokenString,
                rawNonce: nonce
            )
            
            do {
                let result = try await Auth.auth().signIn(with: firebaseCredential)
                let uid = result.user.uid
                
                // Check if user exists, create if not
                if let existing = try? await FirebaseService.shared.fetchUser(uid: uid) {
                    self.currentUser = existing
                } else {
                    var newUser = NSUser.empty
                    newUser.name = credential.fullName?.givenName ?? "User"
                    newUser.email = credential.email ?? result.user.email ?? ""
                    try await FirebaseService.shared.createUser(newUser)
                    self.currentUser = newUser
                }
            } catch {
                self.error = error.localizedDescription
            }
            
        case .failure(let error):
            self.error = error.localizedDescription
        }
    }
    
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }
    
    // MARK: - Nonce helpers
    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in charset.randomElement()! })
    }
    
    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// ─────────────────────────────────────────────────────────────
// ViewModels/ExpenseViewModel.swift
// ─────────────────────────────────────────────────────────────

@MainActor
class ExpenseViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var isCategorizing = false
    @Published var error: String?
    @Published var dashboardSummary: DashboardSummary?
    
    private var listenerRegistration: ListenerRegistration?
    private let firebase = FirebaseService.shared
    private let ai = AIService.shared
    private let currency = CurrencyService.shared
    
    func startListening(userId: String) {
        listenerRegistration = firebase.expensesListener(userId: userId) { [weak self] expenses in
            self?.expenses = expenses
            self?.computeDashboard()
        }
    }
    
    func stopListening() {
        listenerRegistration?.remove()
    }
    
    // MARK: - Add Expense
    func addExpense(
        amount: Double,
        currency: String,
        note: String,
        category: Expense.ExpenseCategory?,
        date: Date,
        userId: String,
        preferredCurrency: String,
        merchantName: String? = nil
    ) async {
        isLoading = true
        defer { isLoading = false }
        
        var finalCategory = category
        var isAICategorized = false
        
        // AI categorization if no manual category
        if finalCategory == nil && !note.isEmpty {
            isCategorizing = true
            finalCategory = try? await ai.categorizeExpense(
                note: note,
                amount: amount,
                merchantName: merchantName
            )
            isAICategorized = finalCategory != nil
            isCategorizing = false
        }
        
        let convertedAmount = CurrencyService.shared.convert(
            amount: amount,
            from: currency,
            to: preferredCurrency
        )
        
        let expense = Expense(
            userId: userId,
            amount: amount,
            currency: currency,
            convertedAmount: convertedAmount,
            convertedCurrency: preferredCurrency,
            category: finalCategory ?? .other,
            note: note,
            date: date,
            isAICategorized: isAICategorized,
            merchantName: merchantName,
            isFlagged: false,
            createdAt: Date()
        )
        
        do {
            let _ = try await firebase.addExpense(expense)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func deleteExpense(_ expense: Expense) async {
        guard let id = expense.id else { return }
        try? await firebase.deleteExpense(id: id)
    }
    
    // MARK: - Dashboard Computation
    func computeDashboard() {
        guard !expenses.isEmpty else {
            dashboardSummary = DashboardSummary(
                totalSpentThisMonth: 0,
                dailyAverage: 0,
                savingsEstimate: 0,
                budgetUsedPercentage: 0,
                categoryBreakdown: [:],
                recentExpenses: [],
                topCategory: nil
            )
            return
        }
        
        let total = expenses.reduce(0) { $0 + $1.convertedAmount }
        
        let calendar = Calendar.current
        let today = Date()
        let dayOfMonth = calendar.component(.day, from: today)
        let dailyAverage = dayOfMonth > 0 ? total / Double(dayOfMonth) : 0
        
        // Category breakdown
        var breakdown: [Expense.ExpenseCategory: Double] = [:]
        for expense in expenses {
            breakdown[expense.category, default: 0] += expense.convertedAmount
        }
        
        let topCategory = breakdown.max(by: { $0.value < $1.value })?.key
        
        dashboardSummary = DashboardSummary(
            totalSpentThisMonth: total,
            dailyAverage: dailyAverage,
            savingsEstimate: 0, // Will be populated with budget
            budgetUsedPercentage: 0, // Will be populated with budget
            categoryBreakdown: breakdown,
            recentExpenses: Array(expenses.prefix(5)),
            topCategory: topCategory
        )
    }
    
    // MARK: - Category filtered
    func expenses(for category: Expense.ExpenseCategory) -> [Expense] {
        expenses.filter { $0.category == category }
    }
    
    func totalSpent(for category: Expense.ExpenseCategory) -> Double {
        expenses(for: category).reduce(0) { $0 + $1.convertedAmount }
    }
}

// ─────────────────────────────────────────────────────────────
// ViewModels/AIInsightsViewModel.swift
// ─────────────────────────────────────────────────────────────

@MainActor
class AIInsightsViewModel: ObservableObject {
    @Published var insights: [AIInsight] = []
    @Published var predictedMonthlySpend: Double = 0
    @Published var anomalousExpenses: [Expense] = []
    @Published var financialAdvice: String = ""
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    
    private let ai = AIService.shared
    
    func loadInsights(expenses: [Expense], user: NSUser, summary: DashboardSummary?) async {
        guard !expenses.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        
        async let insightsTask = ai.analyzeSpending(
            expenses: expenses,
            budget: user.monthlyBudget,
            currency: user.preferredCurrency
        )
        
        let calendar = Calendar.current
        let today = Date()
        let dayOfMonth = calendar.component(.day, from: today)
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        
        async let predictionTask = ai.predictMonthlySpend(
            expenses: expenses,
            currentDay: dayOfMonth,
            daysInMonth: daysInMonth
        )
        
        async let anomalyTask = ai.detectAnomalies(expenses: expenses)
        
        if let sum = summary {
            async let adviceTask = ai.getFinancialAdvice(summary: sum, user: user)
            let (ins, pred, anom, adv) = await (
                (try? insightsTask) ?? [],
                (try? predictionTask) ?? 0,
                (try? anomalyTask) ?? [],
                (try? adviceTask) ?? ""
            )
            self.insights = ins
            self.predictedMonthlySpend = pred
            self.anomalousExpenses = anom
            self.financialAdvice = adv
        } else {
            async with [insightsTask, predictionTask, anomalyTask]
        }
        
        lastUpdated = Date()
    }
}

// ─────────────────────────────────────────────────────────────
// ViewModels/BudgetViewModel.swift
// ─────────────────────────────────────────────────────────────

@MainActor
class BudgetViewModel: ObservableObject {
    @Published var currentBudget: Budget?
    @Published var monthlyLimit: Double = 0
    @Published var budgetUsedPercentage: Double = 0
    @Published var isWarning: Bool = false
    
    private let firebase = FirebaseService.shared
    
    func loadBudget(userId: String) async {
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        currentBudget = try? await firebase.fetchBudget(userId: userId, month: month, year: year)
        monthlyLimit = currentBudget?.monthlyLimit ?? 0
    }
    
    func updateBudgetUsage(totalSpent: Double) {
        guard monthlyLimit > 0 else { return }
        budgetUsedPercentage = (totalSpent / monthlyLimit) * 100
        isWarning = budgetUsedPercentage >= 70
    }
    
    func saveBudget(userId: String, limit: Double, currency: String) async {
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        let budget = Budget(
            userId: userId,
            monthlyLimit: limit,
            currency: currency,
            categoryLimits: [:],
            month: month,
            year: year
        )
        try? await firebase.saveBudget(budget)
        currentBudget = budget
        monthlyLimit = limit
    }
}

// ─────────────────────────────────────────────────────────────
// ViewModels/SubscriptionViewModel.swift
// RevenueCat integration
// ─────────────────────────────────────────────────────────────

import RevenueCat

@MainActor
class SubscriptionViewModel: ObservableObject {
    @Published var isPremium = false
    @Published var availablePackages: [Package] = []
    @Published var isLoading = false
    @Published var error: String?
    
    init() {
        Task { await checkSubscriptionStatus() }
    }
    
    func checkSubscriptionStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isPremium = customerInfo.entitlements["premium"]?.isActive == true
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func fetchPackages() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            availablePackages = offerings.current?.availablePackages ?? []
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func purchase(package: Package) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            isPremium = result.customerInfo.entitlements["premium"]?.isActive == true
            return isPremium
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
    
    func restorePurchases() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPremium = info.entitlements["premium"]?.isActive == true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// ─────────────────────────────────────────────────────────────
// AppState.swift — Global app state
// ─────────────────────────────────────────────────────────────

class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "onboardingComplete") }
    }
    @Published var selectedTab: Int = 0
    
    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "onboardingComplete")
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}
