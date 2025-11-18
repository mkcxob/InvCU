//
//  NotificationView.swift
//  InvCU
//
//  Created by work on 11/17/2025
//

import SwiftUI

// MARK: - Notification View
struct NotificationView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var notifications: [ActivityNotification] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.06)
    }
    
    // Group notifications by date
    private var groupedNotifications: [(String, [ActivityNotification])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        var grouped: [String: [ActivityNotification]] = [:]
        
        for notification in notifications {
            let notificationDate = calendar.startOfDay(for: notification.timestamp)
            
            let key: String
            if notificationDate == today {
                key = "TODAY"
            } else if notificationDate == yesterday {
                key = "YESTERDAY"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM d, yyyy"
                key = formatter.string(from: notificationDate)
            }
            
            grouped[key, default: []].append(notification)
        }
        
        // Sort groups by date (most recent first)
        let sortedGroups = grouped.sorted { pair1, pair2 in
            if pair1.key == "TODAY" { return true }
            if pair2.key == "TODAY" { return false }
            if pair1.key == "YESTERDAY" { return true }
            if pair2.key == "YESTERDAY" { return false }
            return pair1.key > pair2.key
        }
        
        // Sort notifications within each group by timestamp (newest first)
        return sortedGroups.map { (key, notifications) in
            (key, notifications.sorted { $0.timestamp > $1.timestamp })
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    header
                    
                    if isLoading && notifications.isEmpty {
                        Spacer()
                        ProgressView()
                        Text("Loading notifications...")
                            .foregroundColor(.secondary)
                            .padding(.top)
                        Spacer()
                    } else if let error = errorMessage {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            Text("Failed to load notifications")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button("Retry") {
                                Task { await loadNotifications() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Spacer()
                    } else if notifications.isEmpty {
                        Spacer()
                        emptyState
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(groupedNotifications, id: \.0) { section in
                                    sectionHeader(section.0)
                                    
                                    ForEach(section.1) { notification in
                                        NotificationRow(notification: notification)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 20)
                        }
                        .refreshable {
                            await loadNotifications()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if notifications.isEmpty {
                    Task {
                        await loadNotifications()
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Image(.image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color(UIColor.systemBlue)))
                .clipShape(Circle())
                .shadow(color: shadowColor, radius: 2, x: 0, y: 2)
            
            Spacer()
            
            Text("Notifications")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            // Invisible spacer to balance the header
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .padding(.top, title == "TODAY" ? 0 : 20)
            .padding(.bottom, 12)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No notifications yet")
                .font(.headline)
            Text("Activity will appear here when items are added, updated, or transferred")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Load Notifications from Supabase
    private func loadNotifications() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("Fetching notifications...")
            let fetchedNotifications = try await supabaseManager.fetchActivityNotifications()
            
            await MainActor.run {
                self.notifications = fetchedNotifications
                self.isLoading = false
            }
            
            print("Loaded \(fetchedNotifications.count) notifications")
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("Error loading notifications:", error)
        }
    }
}

// MARK: - Notification Row (Matching Design)
struct NotificationRow: View {
    let notification: ActivityNotification
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with background circle
            ZStack {
                Circle()
                    .fill(notification.action.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: notification.action.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(notification.action.color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.displayText)
                    .font(.system(size: 15))
                    .foregroundColor(Color(UIColor.label))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(notification.timeString)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 0)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview
struct NotificationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NotificationView()
                .previewDisplayName("Light")
            
            NotificationView()
                .previewDisplayName("Dark")
                .preferredColorScheme(.dark)
        }
    }
}
