//
//  OSCTCPGeneratesClientNotificationsProtocol.swift
//  SwiftOSC • https://github.com/orchetect/SwiftOSC
//  © 2020-2026 Steffan Andrews • Licensed under MIT License
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
