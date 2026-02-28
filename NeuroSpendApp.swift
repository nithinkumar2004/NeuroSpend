// NeuroSpendApp.swift
// NeuroSpend - AI-Powered Global Expense Tracker
// Architecture: MVVM + Combine + Firebase + Claude AI

import SwiftUI
import Firebase
import RevenueCat

@main
struct NeuroSpendApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        setupFirebase()
        setupRevenueCat()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authViewModel)
                .preferredColorScheme(.dark)
        }
    }
    
    private func setupFirebase() {
        FirebaseApp.configure()
    }
    
    private func setupRevenueCat() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "YOUR_REVENUECAT_API_KEY")
    }
}

// MARK: - Root View (Navigation Controller)
struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if authViewModel.isLoading {
                SplashView()
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else if authViewModel.currentUser == nil {
                AuthView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.currentUser != nil)
    }
}
