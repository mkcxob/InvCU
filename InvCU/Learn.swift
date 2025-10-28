import SwiftUI

struct Learn: View {
    var body: some View {
        TabView {
            Text("Home")
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            Text("Home")
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            Text("Home")
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            Text("Home")
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            Text("Home")
                .tabItem {
                    Label("Home", systemImage: "house")
                }
        }
    }
}

#Preview {
    Learn()
}
