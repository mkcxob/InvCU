// Supabase.swift
import Foundation
import Supabase

struct Config {
    static var supabaseURL: URL {
        guard let urlString = ProcessInfo.processInfo.environment["SUPABASE_URL"],
              let url = URL(string: urlString) else {
            fatalError("Missing or invalid SUPABASE_URL in Config.xcconfig")
        }
        return url
    }
    
    static var supabaseKey: String {
        guard let key = ProcessInfo.processInfo.environment["SUPABASE_KEY"] else {
            fatalError("Missing SUPABASE_KEY in Config.xcconfig")
        }
        return key
    }
}

let supabase = SupabaseClient(
    supabaseURL: Config.supabaseURL,
    supabaseKey: Config.supabaseKey
)

