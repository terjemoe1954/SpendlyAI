# Spendly AI App Store Metadata

## App Name

Spendly AI

## Subtitle

Know what you can spend today

## Description

Spendly AI helps you answer one everyday money question: how much can I safely spend today?

Add your income, fixed expenses, purchases, buffer, and savings goals. Spendly AI calculates a simple daily amount from your own budget data, updates it as you spend, and explains the result in short, practical language.

The app is built for manual budgeting without bank connections. Your core financial data stays on your device, and AI explanations use only the summary values needed to answer your question.

Key features:
- Daily safe-to-spend amount
- Quick purchase logging
- Fixed expenses and savings goals
- Friendly budget explanations
- Local fallback when AI access is unavailable
- English, Norwegian, and Thai language support
- Light, dark, and system appearance

Spendly AI is budgeting guidance, not professional financial advice.

## Keywords

budget,spending,savings,expenses,money,finance,daily budget,AI budget,personal finance,goals

## Age Rating Recommendation

4+

The app does not contain user-generated public content, web browsing, gambling, alcohol, tobacco, medical treatment, or explicit content.

## Review Notes

Spendly AI is a manual budgeting app. It does not connect to banks and does not request bank credentials, BankID, or payment account access.

AI access is designed to work through a backend/proxy before production so no secret API key is embedded in the iOS app. If AI access is unavailable, the app shows local fallback guidance and remains usable.

Core calculations are deterministic and performed locally by the budget engine. AI does not calculate balances or invent financial numbers.

## Demo And Test Information

No special demo account is required.

Suggested review flow:
1. Complete onboarding with a monthly income, next payday, minimum buffer, and one savings goal.
2. Open Home to see the calculated safe-to-spend amount.
3. Add a purchase and confirm the daily amount updates.
4. Open AI and ask a budget question.
5. Open Settings to review privacy/support information and notification settings.

## URLs To Provide In App Store Connect

Privacy Policy URL: https://terjemoe1954.github.io/app-page/spendly/privacy/

Support URL: https://terjemoe1954.github.io/app-page/spendly/support/

## App Privacy

Data Collection: No, we do not collect data from this app.

Rationale for version 1.0:
- Financial profile, expenses, transactions, savings goals, and budget snapshots are stored locally with SwiftData.
- The AI backend is not configured; AI questions and budget summaries are not transmitted.
- iCloud/CloudKit sync is not enabled.
- The app contains no analytics, advertising, or tracking SDKs.
- Purchases and entitlement checks are handled by Apple through StoreKit 2.

## Subscription

Subscription Group Reference Name: Spendly AI Plus

Product Reference Name: Spendly AI Plus Monthly

Product ID: spendlyai.plus.monthly

Duration: 1 month

Base Price: NOK 29 per month

### English (U.S.)

Display Name: Spendly AI Plus

Description: Unlock additional savings goals and support the continued development of Spendly AI.

### Norwegian Bokmål

Display Name: Spendly AI Plus

Description: Lås opp flere sparemål og støtt videreutviklingen av Spendly AI.

### Thai

Display Name: Spendly AI Plus

Description: ปลดล็อกเป้าหมายการออมเพิ่มเติมและสนับสนุนการพัฒนา Spendly AI อย่างต่อเนื่อง
