# VLSPro Rental — App Store Submission Guide

Your project details (already configured):
- Bundle ID: `in.co.vlspro.rental`
- Team ID: `58J4Z2BV4B`
- Subscription: `in.co.vlspro.rental.monthly` — ₹1,500/month, 2-month free trial
- Terms: https://vlspro.co.in/vlspro-rental/terms.php
- Privacy Policy: https://vlspro.co.in/vlspro-rental/privacy.php

---

## ✅ Two things that were likely to get you rejected — now fixed

**1. In-app account deletion (Guideline 5.1.1(v)) — done.**
More → Account → **Delete Account** (`DeleteAccountView.swift`) asks for the current password + typing "DELETE" to confirm, then calls `api/delete_account.php`. That endpoint anonymizes the user's name/email/phone, deactivates the login, and destroys the session — all inside the app, no website step. Remember to **upload `api/delete_account.php` to the live server** before you submit (see Deployment Checklist in AGENT.md) — it won't work against production until that file is live.

**2. Reviewers need a way in — still your action item.** Apple's reviewer will either use your real signup flow or a demo account you provide. Since the app requires login with no "browse without account" mode, have a test owner account ready (or let them use the signup flow) and mention it in App Review Notes (step 9 below). Nothing to build here — just make sure the credentials work before you submit.

---

## 1. Apple Developer Program

If not already enrolled: [developer.apple.com/programs](https://developer.apple.com/programs) — $99/year. Your project already has a team ID (`58J4Z2BV4B`), so this is likely already done.

## 2. Register the App ID (if not already done)

App Store Connect → **Certificates, IDs & Profiles** → Identifiers → check `in.co.vlspro.rental` exists. If not, register it there, enabling capabilities: Push Notifications (if used), Sign in with Apple (only if you use it), In-App Purchase (required — you have subscriptions).

## 3. Create the App record in App Store Connect

[appstoreconnect.apple.com](https://appstoreconnect.apple.com) → My Apps → **+ → New App**
- Platform: iOS
- Name: "VLSPro Rental" (must be unique across the whole App Store — check availability first)
- Primary language: English
- Bundle ID: select `in.co.vlspro.rental`
- SKU: any internal identifier, e.g. `vlsprorental001`

## 4. Set up the subscription in App Store Connect

This is required before the subscribe button will work for real users — StoreKit can't sell a product that doesn't exist on Apple's side.

1. App Store Connect → Agreements, Tax, and Banking → make sure the **Paid Applications Agreement** is active and your bank/tax info is filled in. No payouts happen without this.
2. Your app → **Subscriptions** → create a Subscription Group (e.g. "VLSPro Rental Plans") → add subscription:
   - Product ID: `in.co.vlspro.rental.monthly` (must match exactly what's in `StoreKitManager.swift`)
   - Reference name: "Monthly Plan"
   - Duration: 1 Month
   - Price: pick the tier that resolves to ₹1,500 in India
   - Add a **Free Trial** introductory offer: 2 months, all territories or India-only per your preference
   - Add localized display name/description, and a review screenshot showing the paywall (Apple requires this for subscriptions)

## 5. App Icon & screenshots

- App icon: already done (1024×1024, no alpha — verified).
- Screenshots: required for at least one device size — typically 6.7" (iPhone 15 Pro Max class) is enough since Apple scales down automatically for older sizes if you don't provide them, but it's safer to provide 6.7" and 5.5". Capture from Simulator (⌘S in Simulator saves a screenshot) after picking Device → matching size.
- Minimum 2 screenshots, Apple recommends 3–10 showing key screens (Dashboard, Rent Collection, Tenants, Electricity/UPI, paywall).

## 6. App Privacy questionnaire

App Store Connect → your app → App Privacy → **Get Started**. Since your app collects login credentials and financial data (rent, payments, tenant info), declare honestly:
- Contact Info (email, phone) — collected, linked to user, used for account functionality
- Financial Info (payment/rent records) — collected, linked to user, used for app functionality, **not used for tracking**
- Identifiers (user ID) — used for account functionality

Getting this wrong (declaring "no data collected" when you clearly collect login/financial data) is a common rejection reason.

## 7. Fill in App Store metadata

Your app's page → **App Store** tab:
- Description, keywords, support URL (can reuse your privacy/terms domain), marketing URL (optional)
- Support URL: consider `https://vlspro.co.in/vlspro-rental/` or a dedicated support page
- Category: Business or Productivity
- Age rating: fill the questionnaire (should come out 4+)
- Pricing: Free (with in-app purchase) — since the subscription gates access
- Copyright: your name/company + year

## 8. Archive and upload from Xcode

1. Open the project in Xcode, select scheme **VLSProRental**.
2. Set the destination to **Any iOS Device (arm64)** (not a Simulator — Archive is greyed out on Simulator).
3. Bump `MARKETING_VERSION` (currently `1.0`) and `CURRENT_PROJECT_VERSION` (currently `1`) if this isn't your first submission.
4. **Product → Archive.** Wait for it to build (can take a few minutes).
5. The **Organizer** window opens automatically with your archive. Click **Distribute App**.
6. Choose **App Store Connect → Upload** → Next through the signing options (Automatic signing should just work since `CODE_SIGN_STYLE = Automatic`) → Upload.
7. Wait for "Upload Successful." The build then takes 5–30 min to finish processing on Apple's servers before it's selectable in App Store Connect.

## 9. Select the build & submit for review

1. App Store Connect → your app → App Store tab → **Build** section → **+** → select the build you just uploaded.
2. Fill **App Review Information**:
   - Contact info (your email/phone)
   - **Demo account**: email + password for a working login (owner or test tenant account) — required since your app has no guest mode
   - Notes: mention the free trial subscription and anything reviewers should know (e.g. "Tap Electricity → Pay via UPI opens an external UPI app; this is expected and won't complete a real payment in review without a UPI app installed")
3. Click **Add for Review**, then **Submit to App Review**.

## 10. Review & release

- Typical review time: 24–48 hours (can be longer).
- If rejected: read the specific guideline cited in Resolution Center, fix, and resubmit — you don't need to re-upload a build if it's a metadata-only fix; you do if it's a code fix.
- On approval: choose **Manually release** (control exact launch moment) or **Automatically release** (goes live right after approval) — set this in the version's release settings before submitting.

---

## Recommended: TestFlight first

Before public submission, use **TestFlight** (App Store Connect → your app → TestFlight tab) to test the real subscription/payment flow with your own or a few testers' Apple IDs — sandbox purchases are free and let you verify the 2-month trial and renewal behave as expected before real money is involved. Internal testers (your own team, up to 100, via App Store Connect Users and Access) get access within minutes with no review; external testers require a quick Beta App Review (usually <24h) but let you invite people outside your team by email.
