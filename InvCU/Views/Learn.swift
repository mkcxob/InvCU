import SwiftUI

struct Learn: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Image(systemName: "house")
                    Text("")
                }
            
            InventoryView()
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("")
                }
            ItemLookupView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("")
                }
            NotificationView()
                .tabItem {
                    Image(systemName: "bell.fill")
                    Text("")
                }
        }
    }
}

#Preview {
    Learn()
}
