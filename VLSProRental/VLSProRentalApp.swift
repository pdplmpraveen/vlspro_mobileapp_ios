import SwiftUI

@main
struct VLSProRentalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth  = AuthManager.shared
    @StateObject private var data  = DataService.shared
    @StateObject private var store = StoreKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(data)
                .environmentObject(store)
        }
    }
}
