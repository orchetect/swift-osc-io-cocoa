//
//  OSCTCPPacketHandlerProtocol.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
internal import SwiftOSCIOInternals
import Foundation
import SwiftOSCCore

/// Internal protocol that TCP-based OSC I/O classes adopt in order to handle incoming OSC packets.
protocol _OSCTCPPacketHandlerProtocol: OSCTCPPacketHandlerProtocol {
    var tcpSocket: GCDAsyncSocket { get }
}

extension _OSCTCPPacketHandlerProtocol {
    func _handle(receivedData data: Data, on sock: GCDAsyncSocket) {
        let remoteHost = sock.connectedHost ?? ""
        let remotePort = sock.connectedPort

        handle(receivedData: data, remoteHost: remoteHost, remotePort: remotePort)
    }
}

#endif
