// Models/Models.swift
// NeuroSpend Data Models

import Foundation
import FirebaseFirestore

// MARK: - User Model
struct NSUser: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var preferredCurrency: String
    var monthlyBudget: Double
    var subscriptionTier: SubscriptionTier
    var createdAt: Date
    var timezone: String
    
    enum SubscriptionTier: String, Codable {
        case free = "free"
        case premium = "premium"
        case annual = "annual"
        
        var isPremium: Bool { self != .free }
    }
    
    static var empty: NSUser {
        NSUser(
            name: "",
            email: "",
            preferredCurrency: Locale.current.currency?.identifier ?? "USD",
            monthlyBudget: 0,
            subscriptionTier: .free,
            createdAt: Date(),
            timezone: TimeZone.current.identifier
        )
    }
}

// MARK: - Expense Model
struct Expense: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var amount: Double
    var currency: String
    var convertedAmount: Double       // Always stored in user's preferred currency
    var convertedCurrency: String
    var category: ExpenseCategory
    var note: String
    var date: Date
    var isAICategorized: Bool
    var merchantName: String?
    var isFlagged: Bool               // Fraud/anomaly flag
    var createdAt: Date
    
    enum ExpenseCategory: String, Codable, CaseIterable {
        case food = "Food & Drinks"
        case transport = "Transport"
        case bills = "Bills"
        case entertainment = "Entertainment"
        case health = "Health"
        case shopping = "Shopping"
        case education = "Education"
        case travel = "Travel"
        case subscription = "Subscription"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .food: return "fork.knife"
            case .transport: return "car.fill"
            case .bills: return "doc.text.fill"
            case .entertainment: return "tv.fill"
            case .health: return "heart.fill"
            case .shopping: return "bag.fill"
            case .education: return "book.fill"
            case .travel: return "airplane"
            case .subscription: return "repeat.circle.fill"
            case .other: return "ellipsis.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .food: return "#FF6B6B"
            case .transport: return "#4ECDC4"
            case .bills: return "#45B7D1"
            case .entertainment: return "#96CEB4"
            case .health: return "#FF6F91"
            case .shopping: return "#C3A6FF"
            case .education: return "#FFD93D"
            case .travel: return "#6BCB77"
            case .subscription: return "#FF9A3C"
            case .other: return "#A8A8A8"
            }
        }
    }
}

// MARK: - Budget Model
struct Budget: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var monthlyLimit: Double
    var currency: String
    var categoryLimits: [String: Double]
    var month: Int
    var year: Int
}

// MARK: - AI Insight Model
struct AIInsight: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var type: InsightType
    var severity: Severity
    var generatedAt: Date
    
    enum InsightType: String, Codable {
        case spendingPattern = "spending_pattern"
        case prediction = "prediction"
        case anomaly = "anomaly"
        case advice = "advice"
        case budgetWarning = "budget_warning"
    }
    
    enum Severity: String, Codable {
        case info, warning, critical
    }
}

// MARK: - Currency Rate Model
struct CurrencyRate: Codable {
    var base: String
    var rates: [String: Double]
    var timestamp: Date
}

// MARK: - Dashboard Summary
struct DashboardSummary {
    var totalSpentThisMonth: Double
    var dailyAverage: Double
    var savingsEstimate: Double
    var budgetUsedPercentage: Double
    var categoryBreakdown: [Expense.ExpenseCategory: Double]
    var recentExpenses: [Expense]
    var topCategory: Expense.ExpenseCategory?
}
