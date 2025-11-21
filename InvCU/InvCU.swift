//
//  InvCU.swift
//  InvCU
//
//  Created by work on 10/30/25.
//
import SwiftUI
import Supabase

@main
struct InvCUApp: App {
    @State private var isAuthenticated = false
    
    var body: some Scene {
        WindowGroup {
            if isAuthenticated {
                Learn(isAuthenticated: $isAuthenticated)
            } else {
                SignInView(isAuthenticated: $isAuthenticated)
            }
        }
    }
}
