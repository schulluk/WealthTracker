# App Store Listings

## Apple App Store

### App Name
Wealth Tracker

### Subtitle (30 characters max)
Simple Self-Hosted Net Worth

### Promotional Text (170 characters max)
A simple, self-hosted net worth tracker. See all your accounts in one place, track your balance over time, and keep your financial data on your own server - fully private.

### Description (4000 characters max, no unicode)

Ever wondered "how much do I actually have?" Wealth Tracker is a simple app that answers that question. Add your bank accounts, savings, investments, and retirement funds, and see your total net worth on a single screen. No spreadsheets, no complexity - just a clear number and a chart showing how it changes over time.

HOW IT WORKS
Wealth Tracker takes regular snapshots of your account balances. Over time, this builds a history that shows how your net worth grows (or dips). Think of it as a weighing scale for your finances - step on it regularly and watch the trend.

You can enter balances manually or connect supported accounts to sync automatically.

SELF-HOSTED - YOUR DATA, YOUR SERVER
Unlike other finance apps, Wealth Tracker does not store your data on someone else's cloud. You host the backend yourself. That means:
- Your financial data never leaves your control
- No company can sell, leak, or lose your information
- You decide where your data lives and who has access
- The app works with your own server - set it up once and you are good to go

BUILT FOR SECURITY
Your finances deserve serious protection:
- Per-user encryption: each account has its own encryption key derived from your password
- Ephemeral login tokens: credentials are never stored on the server after authentication
- Biometric unlock (Face ID, Touch ID) for quick but secure access
- All communication encrypted via TLS
- No ads, no tracking, no data sharing

CONNECT YOUR ACCOUNTS
Sync balances automatically from supported institutions:
- German banks via FinTS/HBCI
- Interactive Brokers (IBKR)
- TrueWealth (Swiss robo-advisor)
- VIAC (Swiss 3a retirement)
- Morgan Stanley at Work
- Or simply add any account manually

MULTI-CURRENCY SUPPORT
Have accounts in different currencies? No problem. Wealth Tracker fetches exchange rates automatically and shows everything in your preferred base currency.

CLEAN AND SIMPLE
- One dashboard with your total net worth
- A chart showing your wealth over time
- List of all accounts with their latest balances
- No bloat, no ads, no upsells

PERFECT FOR
- Anyone who wants to know their net worth at a glance
- People with accounts at multiple banks or brokers
- Privacy-conscious users who want to own their data
- Expats with finances in different countries
- Anyone saving toward a goal and wanting to see progress

Wealth Tracker is not a budgeting app and does not track individual transactions. It simply answers: "What is my net worth today, and how has it changed?"

Download it, point it at your server, and start tracking.

### Keywords (100 characters max, comma-separated)
net worth,self-hosted,portfolio,finance,wealth,tracker,privacy,balance,assets,savings,open source

### What's New (Version Notes)
Version 1.3.0:
- Added Firebase Crashlytics for improved stability
- Enhanced exchange rate fetching
- Bug fixes and performance improvements

---

## Apple App Store Privacy

Note: Wealth Tracker is a self-hosted app. All personal and financial data
(email, accounts, balances) is stored on the user's own server, not on any
server operated by the developer. The only data collected by the developer
is crash diagnostics via Firebase Crashlytics.

### Data Collection Declarations

#### Data Used to Track You
None

#### Data Linked to You
None

#### Data Not Linked to You

**Diagnostics**
- Crash Data
- Purpose: App Functionality (improving stability via Firebase Crashlytics)

### Privacy Nutrition Label Summary

| Data Type | Collected | Linked to Identity | Used for Tracking |
|-----------|-----------|-------------------|-------------------|
| Crash Data | Yes | No | No |

---

## App Store Connect Compliance Questions (manual)

Apple added these four questions in 2026. No release tooling sets them (not
store.yml, not ./release.sh, not the preflight): each is a manual step in
App Store Connect. The answers below are for Wealth Tracker
(ch.miniapps.wealthtracker, the only iOS app in this repository), checked
against the code on 2026-11-23. Re-check them whenever a feature adds
messaging, location, social features or user-facing generative AI, and update
this table and the questionnaire in the same release.

### App Compliance (China mainland)

Where: App Store Connect → app → General → App Compliance → "Add Info".
Can be answered at any time, even with no version in preparation. After "No"
there are no follow-up questions: click Save and both rows show "Active".
Due: Jan 31, 2027 for existing apps that are available in China mainland.
Wealth Tracker is not: China mainland, Hong Kong, Macau and Taiwan were
removed from its App Store availability on 2026-11-23 (Pricing and
Availability → App Availability → Manage Availability; 171 of 175 territories
remain, and "automatically available in all future territories" stays on), so
the deadline does not apply. The two answers below are No regardless. Territory
availability is a manual setting too; nothing in the repo or the release
tooling sets it.

| Question | Answer | Reason |
|----------|--------|--------|
| Does your app include features that require a security assessment in China mainland? (Yes only for end-to-end encrypted instant messaging or distributing AI-generated content) | No | No messaging between people at all: Firebase push and the Morgan Stanley phone relay are server-to-device plumbing. Nothing AI-generated is distributed; see the next row. |
| Does your app offer AIGC services in China mainland? (Yes only for AI chatbots, AI image/video generation or processing, AI voice/face generation or alteration) | No | The only AI feature is Gemini-assisted transaction categorization (backend/portfolio/ai_categorization.py, app/lib/presentation/screens/ai_suggestions_screen.dart): it classifies the user's own transactions into the user's own categories, with the user's own Gemini API key on their own server, and returns suggestions the user must confirm. No chatbot, no free-text prompt, no image, video, voice or face generation. |

### Age Ratings

Where: App Store Connect → app → General → App Information → Age Ratings → Edit.
The questionnaire can only be edited while a version is in "Prepare for
Submission"; otherwise every option is greyed out, so answer with the next
version. Due: Jan 15, 2027, or earlier if a new app is submitted or other
age-rating answers change.

| Step | Question | Answer | Reason |
|------|----------|--------|--------|
| 1, Features | Shared Location: sharing of real-world location with another person or group | No | The app never reads device location (no location usage description in app/ios/Runner/Info.plist, no location permission in the Android manifest, no location package in pubspec.yaml) and has no feature that shows anything to another user. |
| 2, Mature Themes | Dating and Relationships: dating or relationship connections between real people and/or a virtual companion with sexual or romantic content | No | Single-user net worth tracker with no social features, no other users' profiles and no companion or chat of any kind. |

---

## Google Play Store

### App Name
Wealth Tracker

### Short Description (80 characters max)
Simple, self-hosted net worth tracker. Your data stays on your own server.

### Full Description (4000 characters max)

Ever wondered "how much do I actually have?" Wealth Tracker is a simple app that answers that question. Add your accounts, see your total net worth, and watch how it changes over time. No spreadsheets, no complexity.

📊 HOW IT WORKS
Wealth Tracker takes regular snapshots of your account balances. Over time, this builds a history that shows how your net worth grows (or dips). Think of it as a weighing scale for your finances - step on it regularly and watch the trend.

You can enter balances manually or connect supported accounts to sync automatically.

🏠 SELF-HOSTED - YOUR DATA, YOUR SERVER
Unlike other finance apps, Wealth Tracker does not store your data on someone else's cloud. You host the backend yourself:
• Your financial data never leaves your control
• No company can sell, leak, or lose your information
• You decide where your data lives and who has access
• Set it up once and you are good to go

🔒 BUILT FOR SECURITY
Your finances deserve serious protection:
• Per-user encryption: each account has its own encryption key derived from your password
• Ephemeral login tokens: credentials are never stored on the server after authentication
• Biometric unlock (fingerprint, face) for quick but secure access
• All communication encrypted via TLS
• No ads, no tracking, no data sharing

🔗 CONNECT YOUR ACCOUNTS
Sync balances automatically from supported institutions:
• German banks via FinTS/HBCI
• Interactive Brokers (IBKR)
• TrueWealth (Swiss robo-advisor)
• VIAC (Swiss 3a retirement)
• Morgan Stanley at Work
• Or simply add any account manually

💱 MULTI-CURRENCY SUPPORT
Have accounts in different currencies? No problem. Wealth Tracker fetches exchange rates automatically and shows everything in your preferred base currency.

✨ CLEAN AND SIMPLE
• One dashboard with your total net worth
• A chart showing your wealth over time
• List of all accounts with their latest balances
• No bloat, no ads, no upsells

👤 PERFECT FOR
• Anyone who wants to know their net worth at a glance
• People with accounts at multiple banks or brokers
• Privacy-conscious users who want to own their data
• Expats with finances in different countries
• Anyone saving toward a goal and wanting to see progress

Wealth Tracker is not a budgeting app and does not track individual transactions. It simply answers: "What is my net worth today, and how has it changed?"

Download it, point it at your server, and start tracking.

---

## Google Play Data Safety

Note: Wealth Tracker is a self-hosted app. All personal and financial data
is stored on the user's own server, not on any server operated by the
developer. The only data collected by the developer is crash diagnostics.

### Data Collection and Sharing

#### Data Collected

**App Info and Performance**
- Crash logs
- Diagnostics
- Collected: Yes
- Shared: Yes (with Firebase Crashlytics / Google)
- Purpose: App stability and performance

**Device or Other IDs**
- Device identifiers (Crashlytics Installation UUID)
- Collected: Yes
- Shared: Yes (with Firebase Crashlytics / Google)
- Purpose: App stability and performance

#### Data Not Collected

- Personal Info (email, name) - stored on user's own server, not collected by developer
- Financial Info (accounts, balances) - stored on user's own server, not collected by developer
- App Activity - not collected

### Security Practices

- Data is encrypted in transit (TLS/SSL)
- You can request that data be deleted (by managing your own server)
- Crash data is handled securely following industry standards

### Data Safety Form Answers

| Question | Answer |
|----------|--------|
| Does your app collect or share any required user data types? | Yes (crash data only) |
| Is all collected data encrypted in transit? | Yes |
| Do you provide a way for users to request data deletion? | Yes (user controls their own server) |
| Is any data shared with third parties? | Yes (crash/diagnostic data with Firebase) |
| Does your app comply with Google Play's Families Policy? | N/A (not a kids app) |

---

## App Categories

### Apple App Store
- Primary Category: Finance
- Secondary Category: Utilities

### Google Play Store
- Category: Finance
- Content Rating: Everyone

---

## Screenshots Required

### Apple App Store
- iPhone 6.7" (1290 x 2796 px) - Required
- iPhone 6.5" (1284 x 2778 px or 1242 x 2688 px) - Required
- iPhone 5.5" (1242 x 2208 px) - Required for older devices
- iPad Pro 12.9" (2048 x 2732 px) - If supporting iPad

### Google Play Store
- Phone screenshots (1080 x 1920 px minimum) - 2-8 required
- 7" Tablet (1200 x 1920 px) - Optional
- 10" Tablet (1600 x 2560 px) - Optional

### Recommended Screenshot Content
1. Dashboard showing total net worth
2. Account list with multiple connected accounts
3. Net worth chart over time
4. Individual account detail view
5. Asset allocation breakdown
6. Multi-currency support display

---

## App Icons

### Apple App Store
- 1024 x 1024 px (App Store listing)
- No transparency, no rounded corners (Apple applies automatically)

### Google Play Store
- 512 x 512 px (Hi-res icon)
- 32-bit PNG with alpha channel

---

## Contact Information

- Developer: Lukas Schulze
- Email: support@miniapps.ch
- Privacy Policy URL: https://miniapps.ch/wealth-tracker/privacy-policy.html
- Website: https://miniapps.ch
