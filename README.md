# VLSPro Rental — iOS App

Native SwiftUI iOS app for the VLS Pro Rental Management system. Consumes the JSON API
exposed by the companion PHP/MySQL backend at
[`pdplmpraveen/rentalapp`](https://github.com/pdplmpraveen/rentalapp).

**Bundle ID:** `in.co.vlspro.rental`
**Backend:** https://vlspro.co.in/vlspro-rental (see `rentalapp` repo for API source + schema)

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (iOS 16+) |
| Networking | `URLSession` + session-cookie auth (`HTTPCookieStorage.shared`) |
| Auth | PHP session cookie, obtained from `POST /api/login.php` |
| Biometrics | Face ID / Touch ID via `LocalAuthentication` (`BiometricAuthManager.swift`) |
| Subscriptions | StoreKit 2 (`StoreKitManager.swift`) — auto-renewable monthly subscription |
| Persistence | None locally — all data fetched live from the API on each load |

---

## Project Structure

```
VLSProRental/
├── VLSProRentalApp.swift          # @main App entry point
├── AppDelegate.swift               # UIApplicationDelegate hooks
├── ContentView.swift                # Root view — swaps Login ↔ MainTabView on auth state
├── MainTabView.swift                # Tab bar: Dashboard / Rent / Tenants / Reports / More
│
├── LoginView.swift                  # Email/password login + biometric unlock
├── SignupView.swift                 # New owner account creation
├── BiometricAuthManager.swift       # Face ID / Touch ID wrapper, stores/clears credentials
│
├── DashboardView.swift              # Home tab — summary stats, recent payments, expiring leases
├── PropertiesView.swift             # Property list
├── TenantsView.swift                # Tenant list + detail
├── AddEditTenantView.swift          # Create/edit tenant form
├── LeasesView.swift                 # Lease list
├── AddLeaseView.swift               # Create lease form (can create tenant inline)
├── RentView.swift                   # Monthly rent/payments tab
├── ExpensesView.swift               # Expense list + add
├── DamagesView.swift                # Damage report list
├── AddDamageView.swift              # Create damage report form
├── ElectricityView.swift            # BESCOM bill list + UPI pay (opens GPay/PhonePe/etc.)
├── AddElectricityBillView.swift     # Create/edit electricity bill form
├── ReportsView.swift                # Annual rent/expense report
├── MoreView.swift                   # Settings hub: account, subscription, delete account
├── DeleteAccountView.swift          # In-app account deletion (App Store Guideline 5.1.1(v))
├── SubscriptionPaywallView.swift    # StoreKit 2 paywall UI
├── StoreKitManager.swift            # Product loading, purchase, subscription status
│
├── WebViewManager.swift / WebViewContainer.swift  # In-app WebView (e.g. terms/privacy links)
│
├── Services.swift                   # All API calls + DataService (@Published state, single source of truth)
├── Models.swift                     # Codable structs mirroring PHP JSON responses
│
├── Assets.xcassets/                 # App icon (all 9 sizes) + accent color
├── LaunchScreen.storyboard
├── Info.plist
├── VLSProRental.entitlements
└── VLSProRental.storekit            # Local StoreKit config for Simulator testing
```

---

## Backend Contract

The app talks exclusively to `/api/*.php` on the `rentalapp` backend. See that repo's
`README.md` for the full endpoint list and JSON shapes, and its `AGENT.md` for the
iOS ↔ PHP type-matching rules. Summary:

- **Auth:** `POST /api/login.php` → server sets a `PHPSESSID` cookie → stored automatically
  in `HTTPCookieStorage.shared` → sent on every subsequent request. No token to manage
  manually. A `401` response means the session expired; `AuthManager` logs the user out.
- **Field naming:** PHP returns `snake_case` JSON keys; Swift `Codable` structs in
  `Models.swift` use matching `snake_case` property names — no `CodingKeys` mapping needed.
- **Nullability:** if any row in a JSON array has a type mismatch (e.g. a non-optional
  Swift field receives `null`), the **entire array fails to decode silently** — the screen
  just shows empty, not an error. When the backend adds a nullable column, the matching
  Swift field **must** be declared `Optional`. See the "Swift model nullable rules" table
  in the backend's `AGENT.md` for the current list of nullable fields — keep both sides in
  sync whenever the DB schema changes.

### Adding a New Screen Backed by a New API Endpoint

1. Backend: add `api/new_feature.php` (see backend `AGENT.md` for the endpoint template).
2. `Models.swift`: add a `Codable` struct mirroring the JSON response; mark nullable DB
   columns as `Optional`.
3. `Services.swift`: add a `func loadNewFeature()` (or similar) to `DataService`, plus any
   mutation calls (`addX`, `payX`, etc.).
4. Create `NewFeatureView.swift` for the screen.
5. Register the new file in `MoreView.swift` (or the relevant tab) navigation.
6. **Manually register new files in `project.pbxproj`** — this project does not use Xcode's
   file-system-synchronized groups, so files added on disk never show up in the build
   automatically. Add `PBXBuildFile` / `PBXFileReference` / group / `Sources` entries by
   hand (or add the file via Xcode's "Add Files to..." so it does this for you).

---

## Subscriptions (StoreKit 2)

- Product: `in.co.vlspro.rental.monthly` — auto-renewable, ₹1,500/month, 2-month free
  trial intro offer for new subscribers.
- Configured in App Store Connect; `VLSProRental.storekit` mirrors the same product locally
  for testing in the Simulator (Xcode → scheme → StoreKit Configuration).
- `StoreKitManager.swift` handles product loading, purchase, and entitlement/subscription
  status; `SubscriptionPaywallView.swift` is the paywall UI shown to unsubscribed users.
- `owner@vlspro.co.in` is hardcoded as a lifetime-free account in `AuthManager` — bypasses
  the paywall.

---

## Account Deletion (App Store Guideline 5.1.1(v))

Apple requires in-app account deletion for apps with in-app account creation.
`DeleteAccountView.swift` (More → Account → Delete Account) asks for the current password
and "type DELETE to confirm", then calls `AuthManager.deleteAccount(password:)`
(`Services.swift` → `POST /api/delete_account.php`). This also clears any stored biometric
credentials before logging out. `ContentView` swaps back to `LoginView` automatically once
`auth.isLoggedIn` flips to `false`.

---

## Build & Run

1. Open `VLSProRental.xcodeproj` in Xcode (15+ recommended for iOS 16+ SDK).
2. Select the `VLSProRental` scheme, choose a Simulator or device.
3. Build & run (⌘R). The app points at the live backend
   (`https://vlspro.co.in/vlspro-rental`) — no local server needed for day-to-day iOS work.
4. For subscription testing, use the StoreKit Configuration file
   (`VLSProRental.storekit`) via Xcode's scheme editor rather than hitting the real App
   Store sandbox.

## Release / App Store Submission

See `App-Store-Submission-Guide.md` in this repo for the full checklist (App Store Connect
setup, subscription configuration, screenshots, review notes, etc.).

---

## Related Repo

Backend source, DB schema, and full API reference:
https://github.com/pdplmpraveen/rentalapp

---

## License

Private — VLS Pro. All rights reserved.
