import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var data: DataService
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: selectedTab == 0 ? "chart.bar.fill" : "chart.bar")
                }
                .tag(0)

            TenantsView()
                .tabItem {
                    Label("Tenants", systemImage: selectedTab == 1 ? "person.2.fill" : "person.2")
                }
                .tag(1)

            RentView()
                .tabItem {
                    Label("Rent", systemImage: selectedTab == 2 ? "indianrupeesign.circle.fill" : "indianrupeesign.circle")
                }
                .tag(2)

            ExpensesView()
                .tabItem {
                    Label("Expenses", systemImage: selectedTab == 3 ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                }
                .tag(3)

            MoreView()
                .tabItem {
                    Label("More", systemImage: selectedTab == 4 ? "ellipsis.circle.fill" : "ellipsis.circle")
                }
                .tag(4)
        }
        .accentColor(Color(hex: "2E6DB4"))
        .onAppear { data.loadAll() }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
        .environmentObject(DataService.shared)
}
