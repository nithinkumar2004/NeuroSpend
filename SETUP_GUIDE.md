# NeuroSpend — Complete Production Setup Guide

## Project Structure

```
NeuroSpend/
├── NeuroSpendApp.swift          # App entry point, Firebase + RevenueCat init
├── AppState.swift               # Global app state (onboarding, tab selection)
│
├── Models/
│   └── Models.swift             # NSUser, Expense, Budget, AIInsight, CurrencyRate
│
├── ViewModels/
│   └── ViewModels.swift         # AuthVM, ExpenseVM, AIInsightsVM, BudgetVM, SubscriptionVM
│
├── Views/
│   ├── MainTabView.swift        # Tab container + custom tab bar
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   ├── Auth/
│   │   └── AuthView.swift       # Email + Apple Sign In
│   ├── Dashboard/
│   │   └── DashboardView.swift  # Main dashboard with Swift Charts
│   ├── Expense/
│   │   └── AddExpenseView.swift # Add expense with AI categorization
│   ├── Insights/
│   │   └── AIInsightsView.swift # AI-powered insights & predictions
│   ├── Budget/
│   │   └── BudgetView.swift     # Budget tracking with circular chart
│   ├── Settings/
│   │   └── SettingsView.swift
│   ├── Subscription/
│   │   └── SubscriptionView.swift # RevenueCat paywall
│   └── Components/              # GlassCard, ExpenseRow, InsightCard, etc.
│
├── Services/
│   └── Services.swift           # FirebaseService, AIService, CurrencyService, KeychainService
│
└── functions/
    └── index.js                 # Firebase Cloud Functions (Node.js)
```

---

## 1. Firebase Setup

### Step 1: Create Firebase Project
1. Go to https://console.firebase.google.com
2. Create project "neurospend"
3. Add iOS app with bundle ID: `com.yourcompany.neurospend`
4. Download `GoogleService-Info.plist` → add to Xcode project root

### Step 2: Enable Authentication
- Firebase Console → Authentication → Sign-in methods
- Enable: Email/Password ✓
- Enable: Apple ✓
  - In Xcode: Signing & Capabilities → Add "Sign in with Apple"
  - Apple Developer: Register App ID with "Sign in with Apple" capability
  - Add Apple as OAuth provider in Firebase (get Team ID from Apple Developer)

### Step 3: Set Up Firestore
- Firebase Console → Firestore Database → Create database (Production mode)
- Copy the security rules from `functions/index.js` comments
- Paste into Firestore Rules tab and publish

### Step 4: Deploy Cloud Functions
```bash
npm install -g firebase-tools
firebase login
cd functions && npm install
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set EXCHANGE_RATE_API_KEY
firebase deploy --only functions
```

### Step 5: Update iOS app with function URLs
In `Services/Services.swift`, replace:
```swift
private let cloudFunctionBaseURL = "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net"
```
with your actual Firebase project URL (found in Firebase Console → Functions).

---

## 2. Xcode Setup

### Swift Package Manager Dependencies
File → Add Package Dependencies:

| Package | URL | Version |
|---------|-----|---------|
| Firebase iOS SDK | https://github.com/firebase/firebase-ios-sdk | 11.x |
| RevenueCat | https://github.com/RevenueCat/purchases-ios | 4.x |

### Required Firebase Products (in package selection):
- FirebaseAuth
- FirebaseFirestore
- FirebaseFirestoreSwift

### Info.plist additions:
```xml
<key>NSCameraUsageDescription</key>
<string>Scan receipts to add expenses</string>

<key>NSMicrophoneUsageDescription</key>
<string>Voice input for expense logging</string>
```

### Capabilities to enable in Xcode:
- Sign in with Apple
- Push Notifications (for budget alerts)
- Keychain Sharing

---

## 3. RevenueCat Setup

### Dashboard Configuration
1. Create account at https://app.revenuecat.com
2. Create new project → iOS app
3. Copy API key → replace `YOUR_REVENUECAT_API_KEY` in `NeuroSpendApp.swift`

### App Store Connect
1. Create two subscriptions in App Store Connect:
   - `neurospend_premium_monthly` — Monthly, $7.99/mo
   - `neurospend_premium_annual` — Annual, $47.99/yr (~$4/mo, 40% saving)
2. Add both products to RevenueCat dashboard
3. Create Entitlement named `premium`
4. Create Offering named `default` with both packages

### RevenueCat Webhook (for Firestore sync)
In RevenueCat → Integrations → Webhooks, point to:
```
https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/revenuecatWebhook
```

---

## 4. Claude AI Integration Architecture

```
iOS App
  ↓ (authenticated request with Firebase token)
Firebase Cloud Functions (secure proxy)
  ↓ (ANTHROPIC_API_KEY stored as Firebase Secret)
Claude API (claude-opus-4-5)
  ↓
Parsed structured response
  ↓
iOS App renders result
```

### Why Cloud Functions proxy?
- API key NEVER touches the client device
- Rate limiting can be enforced per user
- Request logging for debugging/billing
- Can add caching layer (Firestore) for repeated similar queries

### AI Models used:
- **Categorization**: `claude-opus-4-5` — Fast, cheap, accurate for classification
- **Analysis**: `claude-opus-4-5` — Needs reasoning for spending patterns  
- **Prediction**: `claude-opus-4-5` — Statistical reasoning
- **Fraud**: `claude-opus-4-5` — Pattern recognition in structured data

---

## 5. Currency API Setup

1. Sign up at https://exchangerate-api.com (free: 1,500 req/month)
2. Get API key
3. Set in Firebase: `firebase functions:secrets:set EXCHANGE_RATE_API_KEY`
4. Rates are cached in Firestore for 1 hour to minimize API calls

---

## 6. Architecture: MVVM + Combine

```
View (SwiftUI)
  ↕ @Published / @EnvironmentObject
ViewModel (@MainActor, ObservableObject)
  ↕ async/await
Service Layer (Firebase, AI, Currency)
  ↕ network/SDK
External APIs
```

### Data flow example (Add Expense):
1. User taps "Add" in `AddExpenseView`
2. Calls `ExpenseViewModel.addExpense()`
3. If AI categorization enabled:
   a. `AIService.categorizeExpense()` called
   b. Cloud Function invoked with auth token
   c. Claude returns category string
   d. Parsed back to `Expense.ExpenseCategory`
4. Currency converted via `CurrencyService.convert()`
5. `FirebaseService.addExpense()` saves to Firestore
6. Real-time listener updates `expenses` array
7. Dashboard recomputes via `computeDashboard()`
8. UI updates automatically via `@Published`

---

## 7. Free vs Premium Feature Matrix

| Feature | Free | Premium |
|---------|------|---------|
| Manual expense logging | ✓ | ✓ |
| Basic dashboard | ✓ | ✓ |
| Up to 50 expenses/month | ✓ | ✓ |
| Multiple currencies | ✓ | ✓ |
| AI auto-categorization | ✗ | ✓ |
| AI insights (3/month) | ✗ | ✓ |
| Spending predictions | ✗ | ✓ |
| Fraud detection | ✗ | ✓ |
| Unlimited expenses | ✗ | ✓ |
| PDF export | ✗ | ✓ |
| Smart advice | ✗ | ✓ |

---

## 8. App Store Optimization (ASO)

### App Name
`NeuroSpend: AI Expense Tracker`

### Subtitle (30 chars)
`Smart Budget & Finance AI`

### Keywords (100 chars)
`expense tracker,budget,AI finance,spending,money,currency,personal finance,receipt,savings,bills`

### Description (first 3 lines = most important)
```
NeuroSpend uses AI to automatically track, categorize, and predict your spending.
Connect your brain to your budget — let AI handle the hard work.
Multi-currency support for global travelers and expats.
```

### Screenshots strategy:
1. Dashboard with beautiful charts (dark mode)
2. AI categorizing an expense in real-time  
3. AI Insights screen with predictions
4. Budget circular progress
5. Multi-currency add expense

### Ratings strategy:
- Show in-app rating prompt after 3rd successful expense logged
- Use SKStoreReviewRequest API

---

## 9. Phase 2 Roadmap

### Bank Integration (Plaid)
```swift
// Link Plaid via OAuth webflow
// Sync transactions automatically
// AI categorizes bank transactions
```

### AI Chat Assistant
- Use Claude with conversation history
- User can ask: "How much did I spend on food last week?"
- Claude queries Firestore and responds naturally

### Voice Input
```swift
import Speech
// SFSpeechRecognizer → transcribe → send to Claude → parse expense
// "Add 15 dollars for coffee at Starbucks" → structured Expense object
```

### Smart Subscription Detection
- Claude analyzes recurring patterns
- Auto-detects subscriptions (same amount, monthly/yearly)
- Alerts user: "You have 8 active subscriptions costing $127/month"

### PDF Export
```swift
import PDFKit
// Monthly report with Swift Charts rendered as PDF
// AI-generated monthly summary paragraph
```

### Tax Summary
- Categorize business vs personal expenses
- Export IRS Schedule C compatible report
- Multi-currency with base currency conversion for tax year

---

## 10. Scaling Strategy

### Performance
- Firestore pagination (limit 50 per query, load more on scroll)
- AI calls debounced (don't call per keystroke, only on submit)
- Currency rates cached 1 hour in Firestore
- Dashboard computed locally (not AI-dependent)

### Cost Management
- Claude API: Only called for Premium users
- Rate limit: Max 20 AI calls/user/day (enforced in Cloud Functions)
- Cache common categorizations (e.g., "Starbucks" always → Food)

```javascript
// Cloud Function: Check cache before calling Claude
const cached = await admin.firestore()
  .collection('categorizationCache')
  .doc(normalizedMerchant)
  .get();
if (cached.exists) return res.json(cached.data());
// ... call Claude, then cache result for 30 days
```

### Firebase Costs (estimated at 10k users)
- Firestore reads: ~$5/month (most reads are cached)
- Cloud Functions: ~$3/month
- Firebase Auth: Free
- Total backend: ~$10-15/month

### RevenueCat at scale
- Handles all subscription state, webhooks, analytics
- A/B test pricing via Experiments feature
- No custom subscription logic needed

---

## 11. Security Checklist

- [x] API keys in Firebase Secrets (never in code)
- [x] Firebase Auth token verified on every Cloud Function call
- [x] Firestore rules enforce user-data isolation
- [x] Keychain used for any local sensitive storage
- [x] No PII logged to console
- [x] HTTPS enforced on all network calls
- [x] RevenueCat handles payment data (PCI compliant)
- [ ] (Phase 2) Certificate pinning for additional network security
- [ ] (Phase 2) Biometric authentication option

---

## Quick Start Commands

```bash
# Clone and setup
git clone <repo>
cd NeuroSpend
xcodegen generate  # if using XcodeGen

# Firebase
firebase init
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set EXCHANGE_RATE_API_KEY
cd functions && npm install && cd ..
firebase deploy --only functions,firestore:rules

# Xcode
open NeuroSpend.xcodeproj
# Add GoogleService-Info.plist
# Build & Run on simulator or device
```

---

*NeuroSpend — Built with SwiftUI, Firebase, and Claude AI*
*Architecture: MVVM + Combine | Target: iOS 17+ | Dark Mode first*
