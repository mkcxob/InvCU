//
//  DashboardView.swift
//  InvCU
//
//  Created by work on 10/30/25.
//

import SwiftUI
import Supabase

// MARK: - Models
struct Stat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

// MARK: - DashboardView
struct DashboardView: View {
    @Binding var isAuthenticated: Bool
    @StateObject private var supabaseManager = SupabaseManager.shared
    
    @State private var userName: String = "User"
    @State private var totalItems: Int = 0
    @State private var lowStockCount: Int = 0
    @State private var recentActivities: [ActivityNotification] = []
    @State private var lowStockItems: [InventoryItem] = []
    @State private var isLoading = false
    @State private var showingAddItem = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    private let contentMaxWidth: CGFloat = 820
    private let cardCornerRadius: CGFloat = 12
    private let standardCardPadding: CGFloat = 16
    
    /// Computed stats based on real data
    private var stats: [Stat] {
        [
            Stat(title: "Total Items", value: "\(totalItems)"),
            Stat(title: "Categories", value: "3"),
            Stat(title: "Low Stock Items", value: "\(lowStockCount)")
        ]
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            statsCard
                            quickAccessGrid
                            recentActivityCard
                            lowStockCard
                            Spacer(minLength: 36)
                        }
                    }
                    .frame(maxWidth: contentMaxWidth)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddItem) {
                AddItemView(
                    isPresented: $showingAddItem,
                    onAddItem: { newItem in
                        Task {
                            await addItem(newItem)
                        }
                    }
                )
            }
            .task {
                await loadDashboardData()
            }
            .task {
                for await (event, _) in supabase.auth.authStateChanges {
                    if event == .signedIn || event == .tokenRefreshed || event == .initialSession {
                        await loadDashboardData()
                    }
                    if event == .signedOut {
                        await MainActor.run { userName = "User" }
                    }
                }
            }
            .refreshable {
                await loadDashboardData()
            }
        }
    }
    
    /// Loads all dashboard data from Supabase
    private func loadDashboardData() async {
        await MainActor.run { isLoading = true }
        
        async let nameTask: () = fetchUserName()
        async let statsTask: () = fetchInventoryStats()
        async let activitiesTask: () = fetchRecentActivities()
        async let lowStockTask: () = fetchLowStockItems()
        
        await nameTask
        await statsTask
        await activitiesTask
        await lowStockTask
        
        await MainActor.run { isLoading = false }
    }
    
    /// Adds new item to inventory
    private func addItem(_ item: InventoryItem) async {
        do {
            _ = try await supabaseManager.addItem(item)
            await loadDashboardData()
            print("Item added successfully")
        } catch {
            print("Error adding item: \(error)")
        }
    }
    
    /// Fetches user's full name from profiles table
    private func fetchUserName() async {
        do {
            struct ProfileRow: Decodable {
                let full_name: String?
            }
            
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            let response = try await supabase
                .from("profiles")
                .select("full_name")
                .eq("id", value: userId)
                .single()
                .execute()
            
            let row = try JSONDecoder().decode(ProfileRow.self, from: response.data)
            
            if let name = row.full_name, !name.isEmpty {
                await MainActor.run { self.userName = name }
            }
        } catch {
            print("Failed to fetch user name: \(error)")
        }
    }
    
    /// Fetches inventory statistics
    private func fetchInventoryStats() async {
        do {
            let items = try await supabaseManager.fetchAllItems()
            
            let lowStock = items.filter { $0.quantity <= 10 }
            
            await MainActor.run {
                totalItems = items.count
                lowStockCount = lowStock.count
            }
        } catch {
            print("Failed to fetch inventory stats: \(error)")
        }
    }
    
    /// Fetches recent 3 activity notifications
    private func fetchRecentActivities() async {
        do {
            let allNotifications = try await supabaseManager.fetchActivityNotifications()
            
            await MainActor.run {
                recentActivities = Array(allNotifications.prefix(3))
            }
        } catch {
            print("Failed to fetch recent activities: \(error)")
        }
    }
    
    /// Fetches low stock items (quantity <= 10)
    private func fetchLowStockItems() async {
        do {
            let items = try await supabaseManager.fetchAllItems()
            
            let lowStock = items.filter { $0.quantity <= 10 }
                .sorted { $0.quantity < $1.quantity }
            
            await MainActor.run {
                lowStockItems = Array(lowStock.prefix(2))
            }
        } catch {
            print("Failed to fetch low stock items: \(error)")
        }
    }
    
    /// Reusable section title component
    @ViewBuilder
    private func SectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 0)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            NavigationLink(destination: ProfileView(isAuthenticated: $isAuthenticated)) {
                Image(.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .foregroundColor(.white)
                    .background(Circle().fill(Color(UIColor.systemBlue)))
                    .clipShape(Circle())
                    .shadow(color: shadowColor, radius: 2, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back, \(userName)!")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Here's your quick overview")
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
    
    // MARK: - Stats Card
    
    private var statsCard: some View {
        VStack(spacing: 14) {
            SectionTitle("Quick Overview")
            
            HStack(spacing: 12) {
                ForEach(stats) { s in
                    VStack(spacing: 6) {
                        Text(s.value)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(UIColor.label))
                        Text(s.title)
                            .font(.caption)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(standardCardPadding)
        .background(cardBackground)
        .cornerRadius(cardCornerRadius)
        .shadow(color: shadowColor, radius: 6, x: 0, y: 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Quick Access Grid
    
    private var quickAccessGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Quick Access")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                Button(action: {
                    showingAddItem = true
                }) {
                    QuickAccessButton(
                        title: "Add an item",
                        systemIcon: "plus.circle.fill"
                    )
                }
                
                NavigationLink(destination: InventoryView(isAuthenticated: $isAuthenticated)) {
                    QuickAccessButton(
                        title: "Inventory",
                        systemIcon: "shippingbox.fill"
                    )
                }
                
                NavigationLink(destination: ItemLookupView(isAuthenticated: $isAuthenticated)) {
                    QuickAccessButton(
                        title: "Scanner",
                        systemIcon: "viewfinder"
                    )
                }
                
                NavigationLink(destination: ProfileView(isAuthenticated: $isAuthenticated)) {
                    QuickAccessButton(
                        title: "Profile",
                        systemIcon: "person.circle.fill"
                    )
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Recent Activity Card
    
    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Recent Activity")
                .padding(.bottom, 6)
            
            if recentActivities.isEmpty {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentActivities.enumerated()), id: \.element.id) { index, activity in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(activity.action.color.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: activity.action.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(activity.action.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activity.timeString)
                                    .font(.caption)
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                Text(activity.displayText)
                                    .font(.subheadline)
                                    .foregroundColor(Color(UIColor.label))
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        
                        if index != recentActivities.count - 1 {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(standardCardPadding)
        .background(cardBackground)
        .cornerRadius(cardCornerRadius)
        .shadow(color: shadowColor, radius: 6, x: 0, y: 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Low Stock Card
    
    private var lowStockCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Low Stock Items")
            
            if lowStockItems.isEmpty {
                Text("No low stock items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                HStack(spacing: 12) {
                    ForEach(lowStockItems) { item in
                        VStack(spacing: 8) {
                            if item.isURLImage, let url = URL(string: item.imageName) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 70, height: 70)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(8)
                            } else {
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 70, height: 70)
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(8)
                            }
                            
                            Text(item.name)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(Color(UIColor.label))
                                .lineLimit(2)
                            
                            Text("\(item.quantity) Left in Stock")
                                .font(.caption)
                                .foregroundColor(Color(UIColor.systemRed))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(10)
                        .shadow(color: shadowColor.opacity(0.6), radius: 4, x: 0, y: 3)
                    }
                }
            }
        }
        .padding(standardCardPadding)
        .background(cardBackground)
        .cornerRadius(cardCornerRadius)
        .shadow(color: shadowColor, radius: 6, x: 0, y: 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Dynamic colors and helpers
    
    private var cardBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.06)
    }
}

// MARK: - Quick Access Button Component
struct QuickAccessButton: View {
    let title: String
    let systemIcon: String
    @Environment(\.colorScheme) private var colorScheme
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.06)
    }
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.brandNavy)
                    .frame(width: 52, height: 52)
                Image(systemName: systemIcon)
                    .font(.title2)
                    .foregroundColor(.white)
            }
            Text(title)
                .font(.subheadline)
                .fontWeight(.regular)
                .foregroundColor(Color(UIColor.label))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .shadow(color: shadowColor, radius: 4, x: 0, y: 3)
    }
}

// MARK: - Preview
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DashboardView(isAuthenticated: .constant(true))
                .previewDisplayName("Light")
                .preferredColorScheme(.light)
            
            DashboardView(isAuthenticated: .constant(true))
                .previewDisplayName("Dark iPad")
                .preferredColorScheme(.dark)
                .previewDevice("iPad (11-inch) (4th generation)")
        }
    }
}
