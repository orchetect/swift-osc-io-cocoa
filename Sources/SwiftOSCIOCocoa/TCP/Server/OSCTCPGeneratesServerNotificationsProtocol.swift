//
//  OSCTCPGeneratesServerNotificationsProtocol.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency import CocoaAsyncSocket

protocol _OSCTCPGeneratesServerNotificationsProtocol {
    func _generateConnectedNotification(
        remoteHost: String,
        remotePort: UInt16,
        clientID: OSCTCPClientSessionID
    )

    func _generateDisconnectedNotification(
        remoteHost: String,
        remotePort: UInt16,
        clientID: OSCTCPClientSessionID,
        error: GCDAsyncSocketError?
    )
}

#endif
