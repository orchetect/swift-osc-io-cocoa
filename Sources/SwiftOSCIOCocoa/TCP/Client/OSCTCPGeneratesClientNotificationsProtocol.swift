//
//  OSCTCPGeneratesClientNotificationsProtocol.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency import CocoaAsyncSocket

protocol _OSCTCPGeneratesClientNotificationsProtocol {
    func _generateConnectedNotification()

    func _generateDisconnectedNotification(
        error: GCDAsyncSocketError?
    )
}

#endif
