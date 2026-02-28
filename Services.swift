// Services/FirebaseService.swift

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()
    
    // MARK: - User Operations
    func createUser(_ user: NSUser) async throws {
        guard let id = user.id ?? Auth.auth().currentUser?.uid else {
            throw NSError(domain: "NeuroSpend", code: 400, userInfo: [NSLocalizedDescriptionKey: "No user ID"])
        }
        try db.collection("users").document(id).setData(from: user)
    }
    
    func fetchUser(uid: String) async throws -> NSUser {
        let snapshot = try await db.collection("users").document(uid).getDocument()
        guard let user = try? snapshot.data(as: NSUser.self) else {
            throw NSError(domain: "NeuroSpend", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        return user
    }
    
    func updateUser(_ user: NSUser) async throws {
        guard let id = user.id else { return }
        try db.collection("users").document(id).setData(from: user, merge: true)
    }
    
    // MARK: - Expense Operations
    func addExpense(_ expense: Expense) async throws -> String {
        let ref = try db.collection("expenses").addDocument(from: expense)
        return ref.documentID
    }
    
    func fetchExpenses(userId: String, month: Int, year: Int) async throws -> [Expense] {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        guard let startDate = calendar.date(from: components),
              let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else {
            return []
        }
        
        let snapshot = try await db.collection("expenses")
            .whereField("userId", isEqualTo: userId)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("date", isLessThan: Timestamp(date: endDate))
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Expense.self) }
    }
    
    func fetchAllExpenses(userId: String, limit: Int = 100) async throws -> [Expense] {
        let snapshot = try await db.collection("expenses")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Expense.self) }
    }
    
    func deleteExpense(id: String) async throws {
        try await db.collection("expenses").document(id).delete()
    }
    
    func updateExpense(_ expense: Expense) async throws {
        guard let id = expense.id else { return }
        try db.collection("expenses").document(id).setData(from: expense, merge: true)
    }
    
    // MARK: - Real-time listener
    func expensesListener(userId: String, onUpdate: @escaping ([Expense]) -> Void) -> ListenerRegistration {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        
        return db.collection("expenses")
            .whereField("userId", isEqualTo: userId)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfMonth))
            .order(by: "date", descending: true)
            .addSnapshotListener { snapshot, _ in
                let expenses = snapshot?.documents.compactMap {
                    try? $0.data(as: Expense.self)
                } ?? []
                onUpdate(expenses)
            }
    }
    
    // MARK: - Budget Operations
    func saveBudget(_ budget: Budget) async throws {
        let _ = try db.collection("budgets").addDocument(from: budget)
    }
    
    func fetchBudget(userId: String, month: Int, year: Int) async throws -> Budget? {
        let snapshot = try await db.collection("budgets")
            .whereField("userId", isEqualTo: userId)
            .whereField("month", isEqualTo: month)
            .whereField("year", isEqualTo: year)
            .getDocuments()
        
        return snapshot.documents.first.flatMap { try? $0.data(as: Budget.self) }
    }
}

// ─────────────────────────────────────────────────────────────
// Services/AIService.swift
// Claude AI Integration via Cloud Functions Proxy
// ─────────────────────────────────────────────────────────────

import Foundation

class AIService {
    static let shared = AIService()
    
    // IMPORTANT: Never call Claude API directly from iOS.
    // All API calls route through Firebase Cloud Functions proxy
    // to keep the API key server-side and secure.
    private let cloudFunctionBaseURL = "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net"
    
    // MARK: - Expense Categorization
    func categorizeExpense(note: String, amount: Double, merchantName: String?) async throws -> Expense.ExpenseCategory {
        let prompt = buildCategorizationPrompt(note: note, amount: amount, merchant: merchantName)
        let response = try await callCloudFunction(endpoint: "/aiCategorize", body: ["prompt": prompt])
        
        guard let categoryString = response["category"] as? String,
              let category = Expense.ExpenseCategory.allCases.first(where: { $0.rawValue.lowercased() == categoryString.lowercased() }) else {
            return .other
        }
        return category
    }
    
    // MARK: - Spending Analysis
    func analyzeSpending(expenses: [Expense], budget: Double, currency: String) async throws -> [AIInsight] {
        let prompt = buildSpendingAnalysisPrompt(expenses: expenses, budget: budget, currency: currency)
        let response = try await callCloudFunction(endpoint: "/aiAnalyze", body: ["prompt": prompt])
        
        guard let insightsData = response["insights"] as? [[String: Any]] else { return [] }
        return parseInsights(from: insightsData)
    }
    
    // MARK: - Monthly Prediction
    func predictMonthlySpend(expenses: [Expense], currentDay: Int, daysInMonth: Int) async throws -> Double {
        let prompt = buildPredictionPrompt(expenses: expenses, currentDay: currentDay, daysInMonth: daysInMonth)
        let response = try await callCloudFunction(endpoint: "/aiPredict", body: ["prompt": prompt])
        return response["predictedAmount"] as? Double ?? 0
    }
    
    // MARK: - Fraud Detection
    func detectAnomalies(expenses: [Expense]) async throws -> [Expense] {
        let prompt = buildFraudDetectionPrompt(expenses: expenses)
        let response = try await callCloudFunction(endpoint: "/aiDetectFraud", body: ["prompt": prompt])
        
        guard let flaggedIds = response["flaggedIds"] as? [String] else { return [] }
        return expenses.filter { flaggedIds.contains($0.id ?? "") }
    }
    
    // MARK: - Smart Financial Advice
    func getFinancialAdvice(summary: DashboardSummary, user: NSUser) async throws -> String {
        let prompt = buildFinancialAdvicePrompt(summary: summary, user: user)
        let response = try await callCloudFunction(endpoint: "/aiAdvice", body: ["prompt": prompt])
        return response["advice"] as? String ?? ""
    }
    
    // MARK: - Prompt Engineering
    
    private func buildCategorizationPrompt(note: String, amount: Double, merchant: String?) -> String {
        """
        You are a financial categorization AI. Categorize the following expense into EXACTLY one of these categories:
        Food & Drinks, Transport, Bills, Entertainment, Health, Shopping, Education, Travel, Subscription, Other.
        
        Expense details:
        - Description: \(note)
        - Amount: \(amount)
        \(merchant != nil ? "- Merchant: \(merchant!)" : "")
        
        Rules:
        - Return ONLY the category name, nothing else
        - Match spelling exactly as listed above
        - Use context clues: "Netflix" → Subscription, "Uber" → Transport, "Starbucks" → Food & Drinks
        """
    }
    
    private func buildSpendingAnalysisPrompt(expenses: [Expense], budget: Double, currency: String) -> String {
        let expenseSummary = buildExpenseSummaryJSON(expenses: expenses)
        return """
        You are a personal finance AI analyst. Analyze this spending data and provide exactly 3 financial insights.
        
        Spending Data (this month):
        \(expenseSummary)
        
        Monthly Budget: \(currency) \(budget)
        
        Requirements:
        - Return valid JSON array with exactly 3 objects
        - Each object: { "title": "...", "description": "...", "type": "spending_pattern|prediction|advice|anomaly", "severity": "info|warning|critical" }
        - Each description under 50 words
        - Be specific with percentages and amounts
        - Format: [{"title":"...","description":"...","type":"...","severity":"..."}]
        """
    }
    
    private func buildPredictionPrompt(expenses: [Expense], currentDay: Int, daysInMonth: Int) -> String {
        let dailySpends = calculateDailySpends(expenses: expenses)
        return """
        You are a financial prediction AI. Based on the daily spending pattern below, predict total end-of-month spending.
        
        Daily spending data (Day: Amount):
        \(dailySpends)
        
        Current day: \(currentDay) of \(daysInMonth)
        
        Return ONLY a JSON object: {"predictedAmount": <number>}
        Use linear regression on the provided data. Be conservative in estimates.
        """
    }
    
    private func buildFraudDetectionPrompt(expenses: [Expense]) -> String {
        let expenseList = expenses.prefix(50).map { e in
            "ID:\(e.id ?? "?") Amount:\(e.amount) Category:\(e.category.rawValue) Date:\(e.date.ISO8601Format())"
        }.joined(separator: "\n")
        
        return """
        You are a financial fraud detection AI. Analyze these transactions for anomalies.
        
        Transactions:
        \(expenseList)
        
        Flag transactions that are:
        - Unusually large compared to category average (>3x average)
        - Duplicate amounts within 24 hours
        - Unusual time patterns
        
        Return ONLY: {"flaggedIds": ["id1", "id2"]}
        Return empty array if no anomalies found.
        """
    }
    
    private func buildFinancialAdvicePrompt(summary: DashboardSummary, user: NSUser) -> String {
        """
        You are a personal financial advisor AI. Give ONE actionable financial tip based on this data.
        
        User Profile:
        - Monthly Budget: \(user.preferredCurrency) \(user.monthlyBudget)
        - Budget Used: \(Int(summary.budgetUsedPercentage))%
        - Daily Average: \(user.preferredCurrency) \(String(format: "%.2f", summary.dailyAverage))
        - Top Category: \(summary.topCategory?.rawValue ?? "Unknown")
        
        Requirements:
        - Under 30 words
        - Specific and actionable
        - Positive, encouraging tone
        - Return plain text only
        """
    }
    
    // MARK: - Helpers
    private func buildExpenseSummaryJSON(expenses: [Expense]) -> String {
        var categoryTotals: [String: Double] = [:]
        for expense in expenses {
            categoryTotals[expense.category.rawValue, default: 0] += expense.convertedAmount
        }
        let total = expenses.reduce(0) { $0 + $1.convertedAmount }
        
        var summary = "Total: \(String(format: "%.2f", total))\nBreakdown:\n"
        for (category, amount) in categoryTotals.sorted(by: { $0.value > $1.value }) {
            let pct = total > 0 ? Int((amount / total) * 100) : 0
            summary += "  \(category): \(String(format: "%.2f", amount)) (\(pct)%)\n"
        }
        return summary
    }
    
    private func calculateDailySpends(expenses: [Expense]) -> String {
        let calendar = Calendar.current
        var dailyTotals: [Int: Double] = [:]
        for expense in expenses {
            let day = calendar.component(.day, from: expense.date)
            dailyTotals[day, default: 0] += expense.convertedAmount
        }
        return dailyTotals.sorted(by: { $0.key < $1.key })
            .map { "Day \($0.key): \(String(format: "%.2f", $0.value))" }
            .joined(separator: ", ")
    }
    
    private func parseInsights(from data: [[String: Any]]) -> [AIInsight] {
        return data.compactMap { dict in
            guard let title = dict["title"] as? String,
                  let description = dict["description"] as? String,
                  let typeStr = dict["type"] as? String,
                  let severityStr = dict["severity"] as? String else { return nil }
            
            return AIInsight(
                title: title,
                description: description,
                type: AIInsight.InsightType(rawValue: typeStr) ?? .advice,
                severity: AIInsight.Severity(rawValue: severityStr) ?? .info,
                generatedAt: Date()
            )
        }
    }
    
    // MARK: - Cloud Function Caller
    private func callCloudFunction(endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: cloudFunctionBaseURL + endpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Firebase Auth token for security
        if let token = try? await Auth.auth().currentUser?.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}

// ─────────────────────────────────────────────────────────────
// Services/CurrencyService.swift
// ─────────────────────────────────────────────────────────────

class CurrencyService {
    static let shared = CurrencyService()
    private var rates: [String: Double] = [:]
    private var lastFetched: Date?
    
    // Popular global currencies
    static let supportedCurrencies = [
        "USD", "EUR", "GBP", "JPY", "CNY", "INR", "AUD", "CAD",
        "CHF", "HKD", "SGD", "SEK", "NOK", "DKK", "BRL", "MXN",
        "KRW", "THB", "AED", "ZAR", "TRY", "RUB", "PLN", "NZD"
    ]
    
    func fetchRates(base: String = "USD") async throws {
        // Use ExchangeRate-API (free tier: 1500 req/month)
        // In production, proxy through Firebase Cloud Function
        let url = URL(string: "https://YOUR_PROJECT.cloudfunctions.net/getCurrencyRates?base=\(base)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let rateResponse = try JSONDecoder().decode(CurrencyRate.self, from: data)
        self.rates = rateResponse.rates
        self.lastFetched = Date()
        
        // Cache to UserDefaults for offline use
        UserDefaults.standard.set(rates, forKey: "cachedRates")
        UserDefaults.standard.set(Date(), forKey: "ratesFetchedAt")
    }
    
    func convert(amount: Double, from: String, to: String) -> Double {
        guard from != to else { return amount }
        
        let cachedRates = rates.isEmpty ?
            (UserDefaults.standard.dictionary(forKey: "cachedRates") as? [String: Double] ?? [:]) :
            rates
        
        // Convert via USD as base
        let fromRate = cachedRates[from] ?? 1.0
        let toRate = cachedRates[to] ?? 1.0
        
        return (amount / fromRate) * toRate
    }
    
    func formatAmount(_ amount: Double, currency: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
    
    static func localeCurrency() -> String {
        return Locale.current.currency?.identifier ?? "USD"
    }
}

// ─────────────────────────────────────────────────────────────
// Services/KeychainService.swift
// Secure token storage
// ─────────────────────────────────────────────────────────────

import Security

class KeychainService {
    static let shared = KeychainService()
    
    func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess, let data = dataTypeRef as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
