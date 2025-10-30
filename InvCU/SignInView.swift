//
//  SignInView.swift
//  Marketing Inventory
//
//  Created by Amy on 10/21/25.
//

import SwiftUI
import Supabase

struct SignInView: View {
    @Binding var isAuthenticated: Bool
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HeaderCard()
                
                VStack(spacing: 16) {
                    // Email field
                    LabeledField(
                        systemIcon: "envelope",
                        placeholder: "email@carolinau.edu",
                        text: $email,
                        isSecure: false
                    )
                    
                    // Password field with show/hide toggle
                    ZStack {
                        if showPassword {
                            LabeledField(
                                systemIcon: "lock",
                                placeholder: "Password",
                                text: $password,
                                isSecure: false
                            )
                        } else {
                            LabeledField(
                                systemIcon: "lock",
                                placeholder: "Password",
                                text: $password,
                                isSecure: true
                            )
                        }
                        
                        HStack {
                            Spacer()
                            Button {
                                withAnimation { showPassword.toggle() }
                            } label: {
                                Image(systemName: showPassword ? "eye" : "eye.slash")
                                    .foregroundStyle(.gray.opacity(0.7))
                                    .padding(.trailing, 16)
                            }
                            .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                        }
                    }
                    
                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Continue button
                    Button {
                        Task {
                            await signIn()
                        }
                    } label: {
                        Text(isSubmitting ? "Signing in…" : "Continue")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(email.isEmpty || password.isEmpty || isSubmitting)
                    .opacity((email.isEmpty || password.isEmpty) ? 0.7 : 1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Spacer(minLength: 0)
            }
        }
    }
    
    // MARK: - Sign in function
    func signIn() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        
        do {
            _ = try await supabase.auth.signIn(email: email, password: password)
            // Successfully signed in
            withAnimation {
                isAuthenticated = true
            }
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
            print("Debug error: \(error)")
        }
    }
}

// MARK: - Header Card
private struct HeaderCard: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color.brandNavy)
                .frame(height: 220)
                .ignoresSafeArea(edges: .top)
            
            RoundedCorner(radius: 16, corners: [.bottomLeft, .bottomRight])
                .fill(Color.brandNavy)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 4)
                .frame(height: 220)
            
            VStack(alignment: .center, spacing: 6) {
                HStack {
                    Spacer()
                    Image(.image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                    Spacer()
                }
                .padding(.bottom, 8)
                
                Text("Marketing Inventory")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text("Log in")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text("Enter your CU credentials to log in")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Reusable Field
private struct LabeledField: View {
    let systemIcon: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemIcon)
                .foregroundStyle(.gray.opacity(0.7))
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                } else {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                }
            }
        }
        .font(.system(size: 16))
        .padding(.horizontal, 16)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.03), radius: 1, y: 1)
    }
}

// MARK: - Primary Button Style
private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(Color.brandNavy)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Rounded Corner Shape
private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Brand Color
extension Color {
    static let brandNavy = Color(red: 0/255, green: 41/255, blue: 105/255)
}

// MARK: - Preview
struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView(isAuthenticated: .constant(false))
    }
}
