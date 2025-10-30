//
//  DashboardView.swift
//  InvCU
//
//  Created by work on 10/30/25.
//

import SwiftUI

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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    statsCard
                    quickAccessGrid
                    recentActivityCard
                    lowStockCard
                    Spacer(minLength: 40)
                }
                .padding()
            }
           
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(.image)
                .resizable()
                .frame(width: 52, height: 52)
                .foregroundColor(.yellow)
                .background(Circle().fill(Color.white))
                .shadow(radius: 2)
            
            VStack(alignment: .leading) {
                Text("Welcome back, User!")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Here's your quick overview")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    // MARK: - Stats Card (Single White Card)
    private var statsCard: some View {
        VStack(spacing: 16) {
            // Card Title
            Text("Quick Overview")
                .font(.headline)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

            
            // Stats Row
            HStack(spacing: 12) {
                ForEach(stats) { s in
                    VStack {
                        Text(s.value)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text(s.title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 6)
    }
    
    // MARK: - Quick Access Grid
    private var quickAccessGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Access")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(actions) { a in
                    Button(action: a.action) {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0/255, green: 40/255, blue: 104/255))
                                    .frame(width: 52, height: 52)
                                Image(systemName: a.systemIcon)
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            Text(a.title)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Activity Card
    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Activity")
                .font(.headline)
            
            ForEach(activities) { act in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(act.date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(act.text)
                            .font(.subheadline)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
    }
    
    // MARK: - Low Stock Card
    private var lowStockCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Low Stock Items")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(lowStock) { item in
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .resizable()
                            .frame(width: 70, height: 70)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Text(item.name)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        
                        Text("\(item.remaining) Left in Stock")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 3)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        if hex.count == 6 {
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
        } else {
            r = 0; g = 0; b = 0
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

// MARK: - Preview
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .preferredColorScheme(.light)
    }
}

