//
//  ProfileView.swift
//  InvCU
//
//  Created by work on 11/19/2025
//

import SwiftUI
import PhotosUI
import Supabase

struct ProfileView: View {
    @ObservedObject var supabaseManager = SupabaseManager.shared
    @Binding var isAuthenticated: Bool
    @Environment(\.dismiss) private var dismiss
    
    @State private var bookmarkedItems: [InventoryItem] = []
    @State private var isLoading = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUploadingImage = false
    @State private var profileImageURL: String?
    @State private var showLogoutAlert = false
    @State private var userName: String = "Loading..."
    @State private var userRole: String = "Loading..."
    @State private var selectedItem: InventoryItem?
    @State private var showingItemDetail = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.06)
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView {
                    VStack(spacing: 0) {
                        ProfileInfoSection(
                            userName: userName,
                            userRole: userRole,
                            profileImageURL: profileImageURL,
                            isUploadingImage: isUploadingImage,
                            selectedPhotoItem: $selectedPhotoItem
                        )
                        .padding(.top, 8)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        
                        Divider()
                            .padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Bookmarked")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                            
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                            } else if bookmarkedItems.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "bookmark.slash")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("No bookmarked items")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach($bookmarkedItems) { $item in
                                        BookmarkedItemCard(item: item, onTap: {
                                            selectedItem = item
                                            showingItemDetail = true
                                        })
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            
            if showingItemDetail, let selectedItem = selectedItem,
               let index = bookmarkedItems.firstIndex(where: { $0.id == selectedItem.id }) {
                ItemDetailOverlay(
                    item: $bookmarkedItems[index],
                    isPresented: $showingItemDetail,
                    onUpdate: { updatedItem in
                        Task {
                            await updateItem(updatedItem)
                        }
                    },
                    onBookmarkToggle: { item in
                        Task {
                            await toggleBookmark(for: item)
                        }
                    }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Profile")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showLogoutAlert = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 10, weight: .medium))
                        Text("Log Out")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
        }
        .task {
            await loadUserProfile()
            await loadBookmarkedItems()
            await loadProfileImage()
        }
        .refreshable {
            await loadUserProfile()
            await loadBookmarkedItems()
            await loadProfileImage()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    await uploadProfileImage(image)
                }
            }
        }
        .alert("Log Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                Task {
                    await logout()
                }
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        Color.clear
            .frame(height: 0)
    }
    
    // MARK: - Load User Profile
    
    /// Fetches user profile data from Supabase profiles table
    /// Falls back to direct session fetch if currentUser is not set
    private func loadUserProfile() async {
        guard let userId = supabaseManager.currentUser?.id else {
            print("DEBUG: No currentUser in supabaseManager")
            print("DEBUG: Attempting to fetch session directly...")
            
            do {
                let session = try await supabase.auth.session
                print("DEBUG: Found session, user ID: \(session.user.id)")
                
                await MainActor.run {
                    supabaseManager.currentUser = session.user
                }
                
                await loadUserProfileData(userId: session.user.id)
            } catch {
                print("ERROR: No session found: \(error)")
                await MainActor.run {
                    userName = "Not logged in"
                    userRole = "No session"
                }
            }
            return
        }
        
        await loadUserProfileData(userId: userId)
    }
    
    /// Loads profile data for specific user ID from database
    private func loadUserProfileData(userId: UUID) async {
        print("DEBUG: Loading profile for user ID: \(userId)")
        
        do {
            struct ProfileResponse: Codable {
                let username: String
                let full_name: String?
                let position: String?
                let role: String?
            }
            
            let response = try await supabase
                .from("profiles")
                .select("username, full_name, position, role")
                .eq("id", value: userId)
                .single()
                .execute()
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("DEBUG: Raw profile response: \(jsonString)")
            }
            
            let profile = try JSONDecoder().decode(ProfileResponse.self, from: response.data)
            
            print("DEBUG: Decoded profile - username: \(profile.username), full_name: \(profile.full_name ?? "nil"), position: \(profile.position ?? "nil"), role: \(profile.role ?? "nil")")
            
            await MainActor.run {
                if let fullName = profile.full_name, !fullName.isEmpty {
                    userName = fullName
                } else {
                    userName = profile.username
                }
                
                if let position = profile.position, !position.isEmpty {
                    userRole = position
                } else if let role = profile.role, !role.isEmpty {
                    userRole = role.capitalized
                } else {
                    userRole = "Employee"
                }
            }
            
            print("DEBUG: Display values - userName: \(userName), userRole: \(userRole)")
        } catch {
            print("ERROR: Failed to load user profile: \(error)")
            print("ERROR: Error details: \(error.localizedDescription)")
            
            await MainActor.run {
                userName = "Error loading name"
                userRole = "Error loading role"
            }
        }
    }
    
    // MARK: - Load Bookmarked Items
    
    /// Fetches all items and filters for bookmarked ones
    private func loadBookmarkedItems() async {
        await MainActor.run {
            isLoading = true
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let allItems = try await supabaseManager.fetchAllItems()
            await MainActor.run {
                bookmarkedItems = allItems.filter { $0.isBookmarked }
                print("DEBUG: Loaded \(bookmarkedItems.count) bookmarked items")
            }
        } catch {
            print("ERROR: Failed to load bookmarked items: \(error)")
        }
    }
    
    // MARK: - Load Profile Image
    
    /// Fetches user's avatar URL from profiles table
    private func loadProfileImage() async {
        guard let userId = supabaseManager.currentUser?.id else { return }
        
        do {
            struct ProfileImageResponse: Codable {
                let avatar_url: String?
            }
            
            let response = try await supabase
                .from("profiles")
                .select("avatar_url")
                .eq("id", value: userId)
                .single()
                .execute()
            
            let result = try JSONDecoder().decode(ProfileImageResponse.self, from: response.data)
            
            await MainActor.run {
                profileImageURL = result.avatar_url
            }
            
            print("DEBUG: Loaded profile image URL: \(result.avatar_url ?? "none")")
        } catch {
            print("ERROR: Failed to load profile image: \(error)")
        }
    }
    
    // MARK: - Upload Profile Image
    
    /// Uploads new profile image to Supabase storage and updates database
    private func uploadProfileImage(_ image: UIImage) async {
        await MainActor.run {
            isUploadingImage = true
        }
        
        defer {
            Task { @MainActor in
                isUploadingImage = false
            }
        }
        
        guard let userId = supabaseManager.currentUser?.id else { return }
        
        do {
            let imageURL = try await supabaseManager.uploadImage(image)
            
            struct ProfileUpdate: Codable {
                let avatar_url: String
            }
            
            let update = ProfileUpdate(avatar_url: imageURL)
            
            _ = try await supabase
                .from("profiles")
                .update(update)
                .eq("id", value: userId)
                .execute()
            
            await MainActor.run {
                profileImageURL = imageURL
            }
            
            print("DEBUG: Profile image uploaded successfully: \(imageURL)")
        } catch {
            print("ERROR: Failed to upload profile image: \(error)")
        }
    }
    
    // MARK: - Update Item
    
    /// Updates item in database and refreshes bookmarked list
    private func updateItem(_ item: InventoryItem) async {
        do {
            try await supabaseManager.updateItem(item)
            await loadBookmarkedItems()
            print("DEBUG: Item updated successfully")
        } catch {
            print("ERROR: Failed to update item: \(error)")
        }
    }
    
    // MARK: - Toggle Bookmark
    
    /// Toggles bookmark state and refreshes list
    private func toggleBookmark(for item: InventoryItem) async {
        guard let index = bookmarkedItems.firstIndex(where: { $0.id == item.id }) else { return }
        
        await MainActor.run {
            bookmarkedItems[index].isBookmarked.toggle()
        }
        
        do {
            try await supabaseManager.updateItem(bookmarkedItems[index])
            print("DEBUG: Bookmark toggled for \(item.name)")
            
            await loadBookmarkedItems()
        } catch {
            print("ERROR: Failed to toggle bookmark: \(error)")
            await MainActor.run {
                bookmarkedItems[index].isBookmarked.toggle()
            }
        }
    }
    
    // MARK: - Logout
    
    /// Signs user out and dismisses profile view
    private func logout() async {
        do {
            try await supabaseManager.signOut()
            await MainActor.run {
                dismiss()
                isAuthenticated = false
            }
            print("DEBUG: Logged out successfully")
        } catch {
            print("ERROR: Failed to logout: \(error)")
        }
    }
}

// MARK: - Profile Info Section
struct ProfileInfoSection: View {
    let userName: String
    let userRole: String
    let profileImageURL: String?
    let isUploadingImage: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                if let imageURL = profileImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
                    .shadow(color: shadowColor, radius: 3, x: 0, y: 2)
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .foregroundColor(.gray)
                        .shadow(color: shadowColor, radius: 3, x: 0, y: 2)
                }
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
                        )
                }
                .offset(x: 2, y: 2)
                
                if isUploadingImage {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color(.systemBackground)))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(userName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(userRole)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Bookmarked Item Card
struct BookmarkedItemCard: View {
    let item: InventoryItem
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                if item.isURLImage, let url = URL(string: item.imageName) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                        .frame(width: 70, height: 70)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Quantity: \(item.quantity) pc")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Preview
#Preview {
    ProfileView(isAuthenticated: .constant(true))
}
