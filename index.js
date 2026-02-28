// functions/index.js
// Firebase Cloud Functions — Secure AI proxy for NeuroSpend
// Never expose API keys in the iOS app; all AI calls route through here.

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const Anthropic = require("@anthropic-ai/sdk");
const axios = require("axios");
const cors = require("cors")({ origin: true });

admin.initializeApp();

// Initialize Claude client — key stored in Firebase environment config
// Deploy with: firebase functions:secrets:set ANTHROPIC_API_KEY
const getAnthropicClient = () =>
  new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// ─────────────────────────────────────────────────────────────
// MIDDLEWARE: Verify Firebase Auth token
// ─────────────────────────────────────────────────────────────
async function verifyAuth(req, res) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({ error: "Unauthorized" });
    return null;
  }
  try {
    const token = authHeader.split("Bearer ")[1];
    return await admin.auth().verifyIdToken(token);
  } catch {
    res.status(401).json({ error: "Invalid token" });
    return null;
  }
}

// ─────────────────────────────────────────────────────────────
// FUNCTION: AI Expense Categorization
// ─────────────────────────────────────────────────────────────
exports.aiCategorize = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    const user = await verifyAuth(req, res);
    if (!user) return;

    const { prompt } = req.body;
    if (!prompt) return res.status(400).json({ error: "No prompt provided" });

    try {
      const client = getAnthropicClient();
      const message = await client.messages.create({
        model: "claude-opus-4-5",
        max_tokens: 50,
        messages: [{ role: "user", content: prompt }],
      });

      const category = message.content[0].text.trim();
      res.json({ category });
    } catch (err) {
      console.error("Categorization error:", err);
      res.status(500).json({ error: "AI service error", category: "Other" });
    }
  });
});

// ─────────────────────────────────────────────────────────────
// FUNCTION: Spending Analysis → 3 Insights
// ─────────────────────────────────────────────────────────────
exports.aiAnalyze = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    const user = await verifyAuth(req, res);
    if (!user) return;

    const { prompt } = req.body;

    try {
      const client = getAnthropicClient();
      const message = await client.messages.create({
        model: "claude-opus-4-5",
        max_tokens: 600,
        system:
          "You are a precise financial AI. Always respond with valid JSON only. No markdown, no explanation.",
        messages: [{ role: "user", content: prompt }],
      });

      const raw = message.content[0].text.trim();
      const insights = JSON.parse(raw);
      res.json({ insights });
    } catch (err) {
      console.error("Analysis error:", err);
      res.status(500).json({ insights: [] });
    }
  });
});

// ─────────────────────────────────────────────────────────────
// FUNCTION: Monthly Spend Prediction
// ─────────────────────────────────────────────────────────────
exports.aiPredict = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    const user = await verifyAuth(req, res);
    if (!user) return;

    const { prompt } = req.body;

    try {
      const client = getAnthropicClient();
      const message = await client.messages.create({
        model: "claude-opus-4-5",
        max_tokens: 100,
        system: "Respond with valid JSON only. No explanation.",
        messages: [{ role: "user", content: prompt }],
      });

      const result = JSON.parse(message.content[0].text.trim());
      res.json(result);
    } catch (err) {
      console.error("Prediction error:", err);
      res.status(500).json({ predictedAmount: 0 });
    }
  });
});

// ─────────────────────────────────────────────────────────────
// FUNCTION: Fraud / Anomaly Detection
// ─────────────────────────────────────────────────────────────
exports.aiDetectFraud = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    const user = await verifyAuth(req, res);
    if (!user) return;

    const { prompt } = req.body;

    try {
      const client = getAnthropicClient();
      const message = await client.messages.create({
        model: "claude-opus-4-5",
        max_tokens: 300,
        system: "Respond with valid JSON only. No explanation.",
        messages: [{ role: "user", content: prompt }],
      });

      const result = JSON.parse(message.content[0].text.trim());
      res.json(result);
    } catch (err) {
      console.error("Fraud detection error:", err);
      res.status(500).json({ flaggedIds: [] });
    }
  });
});

// ─────────────────────────────────────────────────────────────
// FUNCTION: Smart Financial Advice (single tip)
// ─────────────────────────────────────────────────────────────
exports.aiAdvice = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    const user = await verifyAuth(req, res);
    if (!user) return;

    const { prompt } = req.body;

    try {
      const client = getAnthropicClient();
      const message = await client.messages.create({
        model: "claude-opus-4-5",
        max_tokens: 100,
        messages: [{ role: "user", content: prompt }],
      });

      res.json({ advice: message.content[0].text.trim() });
    } catch (err) {
      console.error("Advice error:", err);
      res.status(500).json({ advice: "" });
    }
  });
});

// ─────────────────────────────────────────────────────────────
// FUNCTION: Currency Rates (cached proxy)
// ─────────────────────────────────────────────────────────────
exports.getCurrencyRates = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    const base = req.query.base || "USD";
    const cacheRef = admin.firestore().collection("cache").doc(`rates_${base}`);

    try {
      const cached = await cacheRef.get();
      if (cached.exists) {
        const data = cached.data();
        const age = Date.now() - data.timestamp.toMillis();
        if (age < 3600000) {
          // 1 hour cache
          return res.json(data);
        }
      }

      // Fetch fresh rates (use ExchangeRate-API free tier)
      const apiKey = process.env.EXCHANGE_RATE_API_KEY;
      const response = await axios.get(
        `https://v6.exchangerate-api.com/v6/${apiKey}/latest/${base}`
      );

      const rateData = {
        base,
        rates: response.data.conversion_rates,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      };

      await cacheRef.set(rateData);
      res.json(rateData);
    } catch (err) {
      console.error("Currency fetch error:", err);
      res.status(500).json({ error: "Failed to fetch rates" });
    }
  });
});

// ─────────────────────────────────────────────────────────────
// FIRESTORE SECURITY RULES (firestore.rules)
// ─────────────────────────────────────────────────────────────
/*
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can only read/write their own document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Expenses: users can only access their own
    match /expenses/{expenseId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null 
        && request.auth.uid == request.resource.data.userId;
    }
    
    // Budgets: users can only access their own
    match /budgets/{budgetId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null 
        && request.auth.uid == request.resource.data.userId;
    }
    
    // Cache: read-only for authenticated users (rates, etc.)
    match /cache/{document} {
      allow read: if request.auth != null;
      allow write: if false; // Only Cloud Functions can write
    }
  }
}
*/
