// Views/MainTabView.swift

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject var expenseVM = ExpenseViewModel()
    @StateObject var insightsVM = AIInsightsViewModel()
    @StateObject var budgetVM = BudgetViewModel()
    @StateObject var subscriptionVM = SubscriptionViewModel()
    @State private var selectedTab = 0
    @State private var showAddExpense = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tag(0)
                
                AIInsightsView()
                    .tag(1)
                
                Color.clear.tag(2) // Placeholder for center FAB
                
                BudgetView()
                    .tag(3)
                
                SettingsView()
                    .tag(4)
            }
            .environmentObject(expenseVM)
            .environmentObject(insightsVM)
            .environmentObject(budgetVM)
            .environmentObject(subscriptionVM)
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab, showAddExpense: $showAddExpense)
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView()
                .environmentObject(expenseVM)
                .environmentObject(authViewModel)
        }
        .onAppear {
            if let userId = authViewModel.currentUser?.id {
                expenseVM.startListening(userId: userId)
                Task {
                    await budgetVM.loadBudget(userId: userId)
                    await CurrencyService.shared.fetchRates()
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// Views/CustomTabBar.swift
// ─────────────────────────────────────────────────────────────

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showAddExpense: Bool
    
    let tabs: [(icon: String, label: String)] = [
        ("house.fill", "Home"),
        ("brain.head.profile", "AI"),
        ("", ""),  // FAB placeholder
        ("chart.pie.fill", "Budget"),
        ("gearshape.fill", "Settings")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<5) { index in
                if index == 2 {
                    // Central FAB button
                    Button {
                        showAddExpense = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#6C63FF"), Color(hex: "#A855F7")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 58, height: 58)
                                .shadow(color: Color(hex: "#6C63FF").opacity(0.5), radius: 12, y: 4)
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .offset(y: -16)
                    .frame(maxWidth: .infinity)
                } else {
                    Button {
                        selectedTab = index
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tabs[index].icon)
                                .font(.system(size: 20, weight: selectedTab == index ? .semibold : .regular))
                                .foregroundColor(selectedTab == index ? Color(hex: "#6C63FF") : Color.gray.opacity(0.6))
                            
                            if selectedTab == index {
                                Circle()
                                    .fill(Color(hex: "#6C63FF"))
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "#1C1C2E").opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 20, y: -4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// ─────────────────────────────────────────────────────────────
// Views/Onboarding/OnboardingView.swift
// ─────────────────────────────────────────────────────────────

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "brain.head.profile",
            gradientColors: ["#6C63FF", "#A855F7"],
            title: "AI-Powered Finance",
            subtitle: "NeuroSpend uses Claude AI to automatically categorize your expenses and predict your spending patterns."
        ),
        OnboardingPage(
            icon: "globe.americas.fill",
            gradientColors: ["#06B6D4", "#3B82F6"],
            title: "Global Currency Support",
            subtitle: "Track expenses in any of 24 currencies with real-time conversion. Travel without financial confusion."
        ),
        OnboardingPage(
            icon: "chart.xyaxis.line",
            gradientColors: ["#10B981", "#059669"],
            title: "Smart Predictions",
            subtitle: "Know where your money will be at month-end before it happens. Set budgets and get warned early."
        )
    ]
    
    var body: some View {
        ZStack {
            Color(hex: "#0F0F1A").ignoresSafeArea()
            
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        OnboardingPageView(page: pages[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color(hex: "#6C63FF") : Color.white.opacity(0.2))
                            .frame(width: i == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 40)
                
                VStack(spacing: 12) {
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation { currentPage += 1 }
                        } else {
                            appState.completeOnboarding()
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#6C63FF"), Color(hex: "#A855F7")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                    }
                    
                    Button("Skip") {
                        appState.completeOnboarding()
                    }
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

struct OnboardingPage {
    let icon: String
    let gradientColors: [String]
    let title: String
    let subtitle: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradientColors.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                    .opacity(0.5)
                
                Image(systemName: page.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: page.gradientColors.map { Color(hex: $0) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}

// ─────────────────────────────────────────────────────────────
// Views/Auth/AuthView.swift
// ─────────────────────────────────────────────────────────────

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "#0F0F1A").ignoresSafeArea()
            
            // Ambient glow
            Circle()
                .fill(Color(hex: "#6C63FF").opacity(0.15))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(x: -60, y: -200)
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)
                    
                    // Logo
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#6C63FF"), Color(hex: "#A855F7")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 72, height: 72)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        
                        Text("NeuroSpend")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("AI-Powered Finance")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    // Form
                    VStack(spacing: 16) {
                        if isSignUp {
                            NSTextField(icon: "person.fill", placeholder: "Full Name", text: $name)
                        }
                        
                        NSTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        
                        NSTextField(icon: "lock.fill", placeholder: "Password", text: $password, isSecure: true)
                    }
                    .padding(.horizontal, 24)
                    
                    // Error
                    if let error = authViewModel.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, 24)
                    }
                    
                    // CTA Button
                    VStack(spacing: 16) {
                        Button {
                            Task {
                                isLoading = true
                                if isSignUp {
                                    await authViewModel.signUp(email: email, password: password, name: name)
                                } else {
                                    await authViewModel.signIn(email: email, password: password)
                                }
                                isLoading = false
                            }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient(
                                colors: [Color(hex: "#6C63FF"), Color(hex: "#A855F7")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .cornerRadius(16)
                        }
                        
                        // Divider
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                            Text("or").font(.caption).foregroundColor(.white.opacity(0.3))
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        }
                        
                        // Apple Sign In
                        SignInWithAppleButton(onRequest: { request in
                            let nonce = authViewModel.prepareAppleSignIn()
                            request.nonce = nonce
                            request.requestedScopes = [.email, .fullName]
                        }, onCompletion: { result in
                            Task { await authViewModel.handleAppleSignIn(result) }
                        })
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .cornerRadius(16)
                        
                        // Toggle auth mode
                        Button {
                            withAnimation { isSignUp.toggle() }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                    .foregroundColor(.white.opacity(0.4))
                                Text(isSignUp ? "Sign In" : "Sign Up")
                                    .foregroundColor(Color(hex: "#6C63FF"))
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 14))
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
            }
        }
    }
}

// MARK: - Custom Text Field
struct NSTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#6C63FF"))
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// ─────────────────────────────────────────────────────────────
// Views/Dashboard/DashboardView.swift
// ─────────────────────────────────────────────────────────────

import Charts

struct DashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var expenseVM: ExpenseViewModel
    @EnvironmentObject var budgetVM: BudgetViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0F0F1A").ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        dashboardHeader
                        
                        // Total Spend Card
                        totalSpendCard
                        
                        // Budget Progress
                        if budgetVM.monthlyLimit > 0 {
                            budgetProgressCard
                        }
                        
                        // Category Chart
                        if let summary = expenseVM.dashboardSummary,
                           !summary.categoryBreakdown.isEmpty {
                            categoryChartCard(summary: summary)
                        }
                        
                        // Recent Expenses
                        recentExpensesSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    var dashboardHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Good \(greetingTime())")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
                Text(authViewModel.currentUser?.name.components(separatedBy: " ").first ?? "there")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
            
            // Avatar
            Circle()
                .fill(LinearGradient(
                    colors: [Color(hex: "#6C63FF"), Color(hex: "#A855F7")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(authViewModel.currentUser?.name.prefix(1) ?? "U"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                )
        }
        .padding(.horizontal, 20)
    }
    
    var totalSpendCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(
                    colors: [Color(hex: "#6C63FF").opacity(0.8), Color(hex: "#A855F7").opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            // Glass overlay
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial.opacity(0.1))
            
            VStack(spacing: 8) {
                Text("Total Spent This Month")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(CurrencyService.shared.formatAmount(
                    expenseVM.dashboardSummary?.totalSpentThisMonth ?? 0,
                    currency: authViewModel.currentUser?.preferredCurrency ?? "USD"
                ))
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)
                
                HStack(spacing: 24) {
                    statPill(
                        icon: "calendar",
                        value: CurrencyService.shared.formatAmount(
                            expenseVM.dashboardSummary?.dailyAverage ?? 0,
                            currency: authViewModel.currentUser?.preferredCurrency ?? "USD"
                        ),
                        label: "Daily Avg"
                    )
                    statPill(
                        icon: "bag.fill",
                        value: "\(expenseVM.expenses.count)",
                        label: "Expenses"
                    )
                }
                .padding(.top, 4)
            }
            .padding(28)
        }
        .frame(height: 180)
        .padding(.horizontal, 20)
        .shadow(color: Color(hex: "#6C63FF").opacity(0.3), radius: 20, y: 8)
    }
    
    var budgetProgressCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Monthly Budget")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    
                    if budgetVM.isWarning {
                        Label("Warning", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.08))
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                colors: budgetVM.isWarning ?
                                    [.orange, .red] :
                                    [Color(hex: "#6C63FF"), Color(hex: "#A855F7")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * min(budgetVM.budgetUsedPercentage / 100, 1))
                            .animation(.spring(response: 0.6), value: budgetVM.budgetUsedPercentage)
                    }
                }
                .frame(height: 10)
                
                HStack {
                    Text("\(Int(budgetVM.budgetUsedPercentage))% used")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text(CurrencyService.shared.formatAmount(budgetVM.monthlyLimit, currency: authViewModel.currentUser?.preferredCurrency ?? "USD"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            budgetVM.updateBudgetUsage(totalSpent: expenseVM.dashboardSummary?.totalSpentThisMonth ?? 0)
        }
    }
    
    func categoryChartCard(summary: DashboardSummary) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Category Breakdown")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                // Swift Charts Pie Chart
                Chart(summary.categoryBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { item in
                    SectorMark(
                        angle: .value("Amount", item.value),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(Color(hex: item.key.color))
                    .cornerRadius(4)
                }
                .frame(height: 180)
                
                // Legend
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(summary.categoryBreakdown.sorted(by: { $0.value > $1.value }).prefix(6), id: \.key) { item in
                        HStack(spacing: 8) {
                            Circle().fill(Color(hex: item.key.color)).frame(width: 8, height: 8)
                            Text(item.key.rawValue)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                            Spacer()
                            Text(CurrencyService.shared.formatAmount(
                                item.value,
                                currency: authViewModel.currentUser?.preferredCurrency ?? "USD"
                            ))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    var recentExpensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Expenses")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            VStack(spacing: 1) {
                ForEach(expenseVM.expenses.prefix(10)) { expense in
                    ExpenseRow(expense: expense, currency: authViewModel.currentUser?.preferredCurrency ?? "USD")
                }
            }
        }
    }
    
    // MARK: - Helpers
    func statPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                Text(label).font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    func greetingTime() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Morning,"
        case 12..<17: return "Afternoon,"
        default: return "Evening,"
        }
    }
}

// ─────────────────────────────────────────────────────────────
// Views/Expense/AddExpenseView.swift
// ─────────────────────────────────────────────────────────────

struct AddExpenseView: View {
    @EnvironmentObject var expenseVM: ExpenseViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var amount = ""
    @State private var note = ""
    @State private var selectedCurrency: String = CurrencyService.localeCurrency()
    @State private var selectedCategory: Expense.ExpenseCategory? = nil
    @State private var selectedDate = Date()
    @State private var useAICategory = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0F0F1A").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Amount input
                        amountSection
                        
                        // Note
                        noteSection
                        
                        // Currency picker
                        currencySection
                        
                        // AI Categorize toggle
                        aiCategorySection
                        
                        // Date picker
                        GlassCard {
                            DatePicker("Date", selection: $selectedDate, displayedComponents: [.date])
                                .datePickerStyle(.compact)
                                .colorScheme(.dark)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        
                        // Add button
                        Button {
                            submitExpense()
                        } label: {
                            HStack {
                                if expenseVM.isLoading {
                                    ProgressView().tint(.white)
                                    Text("Saving...")
                                } else if expenseVM.isCategorizing {
                                    ProgressView().tint(.white)
                                    Text("AI Categorizing...")
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Add Expense")
                                }
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient(
                                colors: [Color(hex: "#6C63FF"), Color(hex: "#A855F7")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                        }
                        .disabled(amount.isEmpty || expenseVM.isLoading)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: "#6C63FF"))
                }
            }
            .colorScheme(.dark)
        }
    }
    
    var amountSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount").font(.caption).foregroundColor(.white.opacity(0.4))
                HStack(alignment: .center) {
                    Text(currencySymbol).font(.system(size: 28, weight: .light)).foregroundColor(.white.opacity(0.5))
                    TextField("0.00", text: $amount)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                        .keyboardType(.decimalPad)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    var noteSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Description").font(.caption).foregroundColor(.white.opacity(0.4))
                TextField("e.g. Starbucks coffee, Uber ride...", text: $note)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
    }
    
    var currencySection: some View {
        GlassCard {
            HStack {
                Text("Currency").foregroundColor(.white.opacity(0.6)).font(.system(size: 14))
                Spacer()
                Picker("Currency", selection: $selectedCurrency) {
                    ForEach(CurrencyService.supportedCurrencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color(hex: "#6C63FF"))
            }
        }
        .padding(.horizontal, 20)
    }
    
    var aiCategorySection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $useAICategory) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(Color(hex: "#A855F7"))
                        Text("AI Auto-Categorize")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                    }
                }
                .tint(Color(hex: "#6C63FF"))
                
                if !useAICategory {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(Expense.ExpenseCategory.allCases, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 20))
                                    Text(category.rawValue.components(separatedBy: " ").first ?? category.rawValue)
                                        .font(.system(size: 10))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedCategory == category ?
                                    Color(hex: category.color).opacity(0.3) :
                                    Color.white.opacity(0.05)
                                )
                                .foregroundColor(selectedCategory == category ?
                                    Color(hex: category.color) : .white.opacity(0.6)
                                )
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedCategory == category ? Color(hex: category.color) : Color.clear, lineWidth: 1.5)
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    var currencySymbol: String {
        Locale(identifier: Locale.identifier(fromComponents: [NSLocale.Key.currencyCode.rawValue: selectedCurrency]))
            .currencySymbol ?? selectedCurrency
    }
    
    func submitExpense() {
        guard let amountValue = Double(amount), let userId = authViewModel.currentUser?.id else { return }
        
        Task {
            await expenseVM.addExpense(
                amount: amountValue,
                currency: selectedCurrency,
                note: note,
                category: useAICategory ? nil : selectedCategory,
                date: selectedDate,
                userId: userId,
                preferredCurrency: authViewModel.currentUser?.preferredCurrency ?? "USD"
            )
            dismiss()
        }
    }
}

// ─────────────────────────────────────────────────────────────
// Views/Insights/AIInsightsView.swift
// ─────────────────────────────────────────────────────────────

struct AIInsightsView: View {
    @EnvironmentObject var insightsVM: AIInsightsViewModel
    @EnvironmentObject var expenseVM: ExpenseViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var subscriptionVM: SubscriptionViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0F0F1A").ignoresSafeArea()
                
                if !subscriptionVM.isPremium {
                    premiumGateView
                } else {
                    insightsContent
                }
            }
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            guard let user = authViewModel.currentUser else { return }
                            await insightsVM.loadInsights(
                                expenses: expenseVM.expenses,
                                user: user,
                                summary: expenseVM.dashboardSummary
                            )
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color(hex: "#6C63FF"))
                    }
                }
            }
            .colorScheme(.dark)
        }
        .task {
            guard let user = authViewModel.currentUser, subscriptionVM.isPremium else { return }
            await insightsVM.loadInsights(
                expenses: expenseVM.expenses,
                user: user,
                summary: expenseVM.dashboardSummary
            )
        }
    }
    
    var insightsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if insightsVM.isLoading {
                    AILoadingView()
                } else {
                    // Predicted spend
                    predictedSpendCard
                    
                    // Financial advice
                    if !insightsVM.financialAdvice.isEmpty {
                        adviceCard
                    }
                    
                    // Insights cards
                    ForEach(insightsVM.insights) { insight in
                        InsightCard(insight: insight)
                    }
                    
                    // Anomalies
                    if !insightsVM.anomalousExpenses.isEmpty {
                        anomalySection
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding(.top, 8)
        }
    }
    
    var predictedSpendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("End-of-Month Prediction", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#A855F7"))
                    Spacer()
                }
                
                Text(CurrencyService.shared.formatAmount(
                    insightsVM.predictedMonthlySpend,
                    currency: authViewModel.currentUser?.preferredCurrency ?? "USD"
                ))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                
                Text("Predicted total spending by month-end based on your current patterns")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 20)
    }
    
    var adviceCard: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(Color(hex: "#6C63FF").opacity(0.2)).frame(width: 36, height: 36)
                    Image(systemName: "lightbulb.fill").foregroundColor(Color(hex: "#6C63FF")).font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Tip")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#6C63FF"))
                    Text(insightsVM.financialAdvice)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(2)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    var anomalySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Flagged Transactions", systemImage: "exclamationmark.shield.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.red)
                .padding(.horizontal, 20)
            
            ForEach(insightsVM.anomalousExpenses) { expense in
                ExpenseRow(expense: expense, currency: authViewModel.currentUser?.preferredCurrency ?? "USD")
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
    
    var premiumGateView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient(
                    colors: [Color(hex: "#6C63FF"), Color(hex: "#A855F7")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            
            VStack(spacing: 8) {
                Text("AI Insights")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("Upgrade to Premium to unlock AI-powered spending analysis, predictions, and fraud detection.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            NavigationLink(destination: SubscriptionView()) {
                Text("Upgrade to Premium")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient(
                        colors: [Color(hex: "#6C63FF"), Color(hex: "#A855F7")],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .cornerRadius(16)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
    }
}

// ─────────────────────────────────────────────────────────────
// Views/Budget/BudgetView.swift
// ─────────────────────────────────────────────────────────────

struct BudgetView: View {
    @EnvironmentObject var budgetVM: BudgetViewModel
    @EnvironmentObject var expenseVM: ExpenseViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var editingBudget = false
    @State private var budgetInput = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0F0F1A").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        budgetCircle
                        categoryBudgets
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editingBudget ? "Save" : "Edit") {
                        if editingBudget {
                            if let limit = Double(budgetInput), let userId = authViewModel.currentUser?.id {
                                Task {
                                    await budgetVM.saveBudget(
                                        userId: userId,
                                        limit: limit,
                                        currency: authViewModel.currentUser?.preferredCurrency ?? "USD"
                                    )
                                }
                            }
                        } else {
                            budgetInput = String(budgetVM.monthlyLimit)
                        }
                        editingBudget.toggle()
                    }
                    .foregroundColor(Color(hex: "#6C63FF"))
                }
            }
            .colorScheme(.dark)
        }
    }
    
    var budgetCircle: some View {
        GlassCard {
            VStack(spacing: 20) {
                if editingBudget {
                    TextField("Monthly limit", text: $budgetInput)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                } else {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 16)
                            .frame(width: 180, height: 180)
                        
                        Circle()
                            .trim(from: 0, to: min(budgetVM.budgetUsedPercentage / 100, 1))
                            .stroke(
                                LinearGradient(
                                    colors: budgetVM.isWarning ? [.orange, .red] : [Color(hex: "#6C63FF"), Color(hex: "#A855F7")],
                                    startPoint: .leading, endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 16, lineCap: .round)
                            )
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.8), value: budgetVM.budgetUsedPercentage)
                        
                        VStack(spacing: 4) {
                            Text("\(Int(budgetVM.budgetUsedPercentage))%")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            Text("Used")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    
                    HStack(spacing: 32) {
                        budgetStat(
                            label: "Spent",
                            value: CurrencyService.shared.formatAmount(
                                expenseVM.dashboardSummary?.totalSpentThisMonth ?? 0,
                                currency: authViewModel.currentUser?.preferredCurrency ?? "USD"
                            )
                        )
                        budgetStat(
                            label: "Remaining",
                            value: CurrencyService.shared.formatAmount(
                                max(budgetVM.monthlyLimit - (expenseVM.dashboardSummary?.totalSpentThisMonth ?? 0), 0),
                                currency: authViewModel.currentUser?.preferredCurrency ?? "USD"
                            )
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 20)
    }
    
    func budgetStat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
            Text(label).font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
        }
    }
    
    var categoryBudgets: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Category")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            ForEach(Expense.ExpenseCategory.allCases, id: \.self) { category in
                let spent = expenseVM.totalSpent(for: category)
                if spent > 0 {
                    GlassCard {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: category.color).opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Image(systemName: category.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: category.color))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 4)
                                        Capsule()
                                            .fill(Color(hex: category.color))
                                            .frame(width: geo.size.width * min(spent / max(budgetVM.monthlyLimit / 10, 1), 1), height: 4)
                                    }
                                }
                                .frame(height: 4)
                            }
                            
                            Text(CurrencyService.shared.formatAmount(
                                spent,
                                currency: authViewModel.currentUser?.preferredCurrency ?? "USD"
                            ))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// Views/Settings/SettingsView.swift
// ─────────────────────────────────────────────────────────────

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var subscriptionVM: SubscriptionViewModel
    @State private var showPaywall = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0F0F1A").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Profile Card
                        GlassCard {
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "#6C63FF"), Color(hex: "#A855F7")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Text(String(authViewModel.currentUser?.name.prefix(1) ?? "U"))
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(authViewModel.currentUser?.name ?? "")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(authViewModel.currentUser?.email ?? "")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                
                                Spacer()
                                
                                if subscriptionVM.isPremium {
                                    Label("Pro", systemImage: "crown.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color(hex: "#FFD700"))
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(Color(hex: "#FFD700").opacity(0.15))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Premium CTA
                        if !subscriptionVM.isPremium {
                            Button { showPaywall = true } label: {
                                HStack {
                                    Image(systemName: "crown.fill").foregroundColor(Color(hex: "#FFD700"))
                                    Text("Upgrade to Premium").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.3))
                                }
                                .padding(16)
                                .background(LinearGradient(
                                    colors: [Color(hex: "#6C63FF").opacity(0.3), Color(hex: "#A855F7").opacity(0.3)],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#6C63FF").opacity(0.3), lineWidth: 1))
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Settings rows
                        settingsGroup(title: "Preferences") {
                            settingsRow(icon: "dollarsign.circle.fill", color: "#10B981", title: "Preferred Currency") {
                                Text(authViewModel.currentUser?.preferredCurrency ?? "USD")
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            settingsRow(icon: "bell.fill", color: "#6C63FF", title: "Notifications") {
                                Toggle("", isOn: .constant(true)).tint(Color(hex: "#6C63FF"))
                            }
                        }
                        
                        settingsGroup(title: "Account") {
                            settingsRow(icon: "arrow.counterclockwise", color: "#F59E0B", title: "Restore Purchases") {
                                EmptyView()
                            } action: {
                                Task { await subscriptionVM.restorePurchases() }
                            }
                            settingsRow(icon: "rectangle.portrait.and.arrow.right", color: "#EF4444", title: "Sign Out") {
                                EmptyView()
                            } action: {
                                authViewModel.signOut()
                            }
                        }
                        
                        Text("NeuroSpend v1.0 • Made with ♥").font(.caption).foregroundColor(.white.opacity(0.2)).padding()
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .colorScheme(.dark)
            .sheet(isPresented: $showPaywall) {
                SubscriptionView().environmentObject(subscriptionVM)
            }
        }
    }
    
    func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption).foregroundColor(.white.opacity(0.3))
                .padding(.horizontal, 20).padding(.bottom, 8)
            GlassCard { VStack(spacing: 0) { content() } }
                .padding(.horizontal, 20)
        }
    }
    
    func settingsRow<Content: View>(icon: String, color: String, title: String, @ViewBuilder trailing: () -> Content, action: (() -> Void)? = nil) -> some View {
        Button { action?() } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color(hex: color).opacity(0.2)).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 14)).foregroundColor(Color(hex: color))
                }
                Text(title).font(.system(size: 15)).foregroundColor(.white)
                Spacer()
                trailing()
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────────
// Views/Subscription/SubscriptionView.swift
// ─────────────────────────────────────────────────────────────

struct SubscriptionView: View {
    @EnvironmentObject var subscriptionVM: SubscriptionViewModel
    @Environment(\.dismiss) var dismiss
    
    let features = [
        ("brain.head.profile", "AI Auto-Categorization", "Let AI instantly sort your expenses"),
        ("chart.line.uptrend.xyaxis", "Spending Predictions", "Know your month-end total in advance"),
        ("exclamationmark.shield.fill", "Fraud Detection", "Catch unusual transactions automatically"),
        ("doc.richtext.fill", "Export Reports", "PDF reports for any time period"),
        ("infinity", "Unlimited Entries", "No cap on expense logging")
    ]
    
    var body: some View {
        ZStack {
            Color(hex: "#0F0F1A").ignoresSafeArea()
            
            // Glow effect
            Circle()
                .fill(Color(hex: "#6C63FF").opacity(0.2))
                .frame(width: 400).blur(radius: 100)
                .offset(y: -200)
            
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(LinearGradient(
                                colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                        
                        Text("NeuroSpend Premium")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Unlock the full power of AI finance")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.top, 40)
                    
                    // Features list
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(features, id: \.0) { feature in
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "#6C63FF").opacity(0.2))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: feature.0)
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(hex: "#A855F7"))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(feature.1).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                        Text(feature.2).font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Pricing
                    if subscriptionVM.isLoading {
                        ProgressView().tint(Color(hex: "#6C63FF"))
                    } else {
                        VStack(spacing: 12) {
                            ForEach(subscriptionVM.availablePackages, id: \.identifier) { package in
                                PackageButton(package: package) {
                                    Task { let _ = await subscriptionVM.purchase(package: package) }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Button("Restore Purchases") {
                        Task { await subscriptionVM.restorePurchases() }
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.3))
                    
                    Text("Cancel anytime. Billed through Apple.\nSubscription auto-renews unless cancelled.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.2))
                        .multilineTextAlignment(.center)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .task { await subscriptionVM.fetchPackages() }
    }
}

struct PackageButton: View {
    let package: Package
    let action: () -> Void
    
    var isAnnual: Bool { package.packageType == .annual }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(isAnnual ? "Annual Plan" : "Monthly Plan")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        if isAnnual {
                            Text("Save 40%").font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    Text(isAnnual ? "Per year, just \(monthlyEquivalent)/mo" : "Per month")
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                Text(package.localizedPriceString)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(18)
            .background(
                isAnnual ?
                    LinearGradient(colors: [Color(hex: "#6C63FF"), Color(hex: "#A855F7")], startPoint: .leading, endPoint: .trailing) :
                    LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.06)], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isAnnual ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .shadow(color: isAnnual ? Color(hex: "#6C63FF").opacity(0.3) : .clear, radius: 12, y: 4)
    }
    
    var monthlyEquivalent: String { "$3.33" } // Calculate from actual price
}

// ─────────────────────────────────────────────────────────────
// Shared Components
// ─────────────────────────────────────────────────────────────

struct GlassCard<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(16)
            .background(Color.white.opacity(0.06))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct ExpenseRow: View {
    let expense: Expense
    let currency: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: expense.category.color).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: expense.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: expense.category.color))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(expense.note.isEmpty ? expense.category.rawValue : expense.note)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if expense.isAICategorized {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "#A855F7"))
                    }
                    if expense.isFlagged {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                    }
                }
                Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                Text("-" + CurrencyService.shared.formatAmount(expense.convertedAmount, currency: currency))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                if expense.currency != currency {
                    Text("\(expense.currency) \(String(format: "%.0f", expense.amount))")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
    }
}

struct InsightCard: View {
    let insight: AIInsight
    
    var severityColor: Color {
        switch insight.severity {
        case .info: return Color(hex: "#6C63FF")
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: insightIcon)
                        .foregroundColor(severityColor)
                    Text(insight.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Circle()
                        .fill(severityColor.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                Text(insight.description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(2)
                
                Text(insight.generatedAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(severityColor.opacity(0.2), lineWidth: 1)
                .padding(.horizontal, 20)
        )
    }
    
    var insightIcon: String {
        switch insight.type {
        case .spendingPattern: return "chart.bar.fill"
        case .prediction: return "chart.line.uptrend.xyaxis"
        case .anomaly: return "exclamationmark.triangle.fill"
        case .advice: return "lightbulb.fill"
        case .budgetWarning: return "gauge.with.dots.needle.67percent"
        }
    }
}

struct AILoadingView: View {
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color(hex: "#6C63FF").opacity(0.3 - Double(i) * 0.1), lineWidth: 1.5)
                        .frame(width: CGFloat(60 + i * 30))
                        .scaleEffect(animate ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double(i) * 0.2), value: animate)
                }
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "#6C63FF"), Color(hex: "#A855F7")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
            .frame(height: 120)
            .onAppear { animate = true }
            
            Text("AI is analyzing your spending...").font(.system(size: 15)).foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 40)
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(hex: "#0F0F1A").ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "#6C63FF"), Color(hex: "#A855F7")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                Text("NeuroSpend").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                ProgressView().tint(Color(hex: "#6C63FF"))
            }
        }
    }
}

// MARK: - Color extension
extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
