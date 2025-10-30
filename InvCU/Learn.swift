import SwiftUI

struct Learn: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Dashboard")
                }
            
            Text("Marketing Inventory")
                .tabItem {
                    Image(systemName: "shippingbox")
                    Text("Inventory")
                }
            
            Text("Search")
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
            
            Text("Notifications")
                .tabItem {
                    Image(systemName: "bell.fill")
                    Text("Notifications")
                }
        }
    }
}

#Preview {
    Learn()
}

