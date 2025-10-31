//
//  DashboardView.swift
//  InvCU
//
//  Created by work on 10/30/25.
//

import SwiftUI
import Supabase // make sure you have your Supabase client imported

// MARK: - Models (sample)
struct Stat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let systemIcon: String
    let action: () -> Void
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let date: String
    let text: String
}

struct LowStockItem: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    let remaining: Int
}

// MARK: - DashboardView
struct DashboardView: View {
    // Sample data
    let stats = [
        Stat(title: "Total Items", value: "247"),
        Stat(title: "Total Scans", value: "189"),
        Stat(title: "Low Stock Items", value: "58")
    ]
    
    let actions: [QuickAction] = [
        QuickAction(title: "Scanner", systemIcon: "viewfinder") { print("scanner") },
        QuickAction(title: "Inventory", systemIcon: "shippingbox.fill") { print("inventory") },
        QuickAction(title: "Add an item", systemIcon: "plus.circle.fill") { print("add item") },
        QuickAction(title: "Report", systemIcon: "chart.bar.fill") { print("report") }
    ]
    
    let activities = [
        ActivityItem(date: "10-15-2025 1:50 PM", text: "Amy Portillo checked out Gray Sweatshirt"),
        ActivityItem(date: "10-15-2025 3:49 PM", text: "Amy Portillo checked out Blue Mug"),
        ActivityItem(date: "10-15-2025 4:49 PM", text: "Amy Portillo checked out Blue Mug")
    ]
    
    let lowStock = [
        LowStockItem(name: "Gray Sweatshirt", imageName: "sweatshirt", remaining: 5),
        LowStockItem(name: "Blue Backpack", imageName: "backpack", remaining: 5)
    ]
    
    // Layout constants
    private let contentMaxWidth: CGFloat = 820
    private let cardCornerRadius: CGFloat = 12
    private let standardCardPadding: CGFloat = 16
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - User name state
    @State private var userName: String = "User" // default fallback
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        statsCard
                        quickAccessGrid
                        recentActivityCard
                        lowStockCard
                        Spacer(minLength: 36)
                    }
                    .frame(maxWidth: contentMaxWidth)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
            }
            .navigationBarHidden(true)
            .task {
                // Initial fetch if already signed in
                await fetchUserName()
            }
            .task {
                // React to auth state changes (sign-in, token refresh) and refetch
                for await (event, _) in supabase.auth.authStateChanges {
                    if event == .signedIn || event == .tokenRefreshed || event == .initialSession {
                        await fetchUserName()
                    }
                    if event == .signedOut {
                        await MainActor.run { userName = "User" }
                    }
                }
            }
        }
    }
    
    // MARK: - Fetch user name from Supabase
    private struct ProfileRow: Decodable {
        // Match the JSON exactly
        let full_name: String?
    }

    private func fetchUserName() async {
        do {
            // Fetch session; this throws if there is no session.
            let session = try await supabase.auth.session
            let userId = session.user.id

            // Execute the query
            let response = try await supabase
                .from("profiles")
                .select("full_name")
                .eq("id", value: userId)
                .single()
                .execute()
            
            // Diagnostics
            if let bodyString = String(data: response.data, encoding: .utf8) {
                print("profiles response (\(response.status)): \(bodyString)")
            } else {
                print("profiles response (\(response.status)): <non-utf8 data>")
            }
            
            // Decode with JSONDecoder (no special strategy needed)
            let row = try JSONDecoder().decode(ProfileRow.self, from: response.data)
            
            if let name = row.full_name, !name.isEmpty {
                await MainActor.run { self.userName = name }
            } else {
                print("full_name not found or empty in response")
            }
        } catch {
            // No session or other error; keep default "User"
            print("Failed to fetch user name: \(error)")
        }
    }

    // MARK: - Reusable Section Title
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
            Image(.image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .foregroundColor(.white)
                .background(Circle().fill(Color(UIColor.systemBlue)))
                .clipShape(Circle())
                .shadow(color: shadowColor, radius: 2, x: 0, y: 2)
            
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
    
    // MARK: - Stats Card (Single Card)
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
                ForEach(actions) { a in
                    Button(action: a.action) {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandNavy)
                                    .frame(width: 52, height: 52)
                                Image(systemName: a.systemIcon)
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            Text(a.title)
                                .font(.subheadline)
                                .fontWeight(.regular)
                                .foregroundColor(Color(UIColor.label))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity, minHeight: 110)
                        .padding(.vertical, 6)
                        .background(cardBackground)
                        .cornerRadius(10)
                        .shadow(color: shadowColor, radius: 4, x: 0, y: 3)
                    }
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
            
            VStack(spacing: 0) {
                ForEach(Array(activities.enumerated()), id: \.element.id) { index, act in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "clock")
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(act.date)
                                .font(.caption)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                            Text(act.text)
                                .font(.subheadline)
                                .foregroundColor(Color(UIColor.label))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    
                    if index != activities.count - 1 {
                        Divider()
                            .padding(.leading, 36)
                    }
                }
            }
            .padding(.horizontal, 2)
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
            
            HStack(spacing: 12) {
                ForEach(lowStock) { item in
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 70)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                        
                        Text(item.name)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(UIColor.label))
                        
                        Text("\(item.remaining) Left in Stock")
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
        .padding(standardCardPadding)
        .background(cardBackground)
        .cornerRadius(cardCornerRadius)
        .shadow(color: shadowColor, radius: 6, x: 0, y: 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Dynamic colors & helpers
    private var cardBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.06)
    }
}

// MARK: - Preview
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DashboardView()
                .previewDisplayName("Light")
                .preferredColorScheme(.light)
            
            DashboardView()
                .previewDisplayName("Dark iPad")
                .preferredColorScheme(.dark)
                .previewDevice("iPad (11-inch) (4th generation)")
        }
    }
}
