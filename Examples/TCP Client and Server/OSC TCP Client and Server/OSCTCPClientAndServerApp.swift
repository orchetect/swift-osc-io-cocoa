//
//  OSCTCPClientAndServerApp.swift
//  SwiftOSC • https://github.com/orchetect/SwiftOSC
//  © 2020-2026 Steffan Andrews • Licensed under MIT License
//

import SwiftUI

@main
struct OSCTCPClientAndServerApp: App {
    @StateObject var oscManager = OSCManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(oscManager)
        }
    }
}
