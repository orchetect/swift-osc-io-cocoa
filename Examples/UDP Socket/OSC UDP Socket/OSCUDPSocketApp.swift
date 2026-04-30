//
//  OSCUDPSocketApp.swift
//  SwiftOSC • https://github.com/orchetect/SwiftOSC
//  © 2020-2026 Steffan Andrews • Licensed under MIT License
//

import SwiftOSCIOCocoa
import SwiftUI

@main
struct OSCUDPSocketApp: App {
    @StateObject var oscManager = OSCManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(oscManager)
        }
    }
}
