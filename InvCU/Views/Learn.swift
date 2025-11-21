import SwiftUI

struct Learn: View {
    @Binding var isAuthenticated: Bool
    
    var body: some View {
        TabView {
            DashboardView(isAuthenticated: $isAuthenticated)
                .tabItem {
                    Image(systemName: "house")
                    Text("")
                }
            
            InventoryView(isAuthenticated: $isAuthenticated)
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("")
                }
            
            ItemLookupView(isAuthenticated: $isAuthenticated)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("")
                }
            
            NotificationView(isAuthenticated: $isAuthenticated)
                .tabItem {
                    Image(systemName: "bell.fill")
                    Text("")
                }
        }
    }
}

#Preview {
    Learn(isAuthenticated: .constant(true))
}
