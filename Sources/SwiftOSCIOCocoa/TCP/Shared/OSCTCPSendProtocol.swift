//
//  OSCTCPSendProtocol.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency import CocoaAsyncSocket
import Foundation
import SwiftOSCCore

/// Internal protocol that TCP-based OSC classes adopt in order to send OSC packets.
protocol _OSCTCPSendProtocol: AnyObject where Self: Sendable {
    var tcpSocket: GCDAsyncSocket { get }
    var clientID: OSCTCPClientSessionID { get }
    var framingMode: OSCTCPFramingMode { get }
}

extension _OSCTCPSendProtocol {
    func _send(_ packet: OSCPacket) throws {
        try _send(packet.rawData())
    }

    func _send(_ bundle: OSCBundle) throws {
        try _send(bundle.rawData())
    }

    func _send(_ message: OSCMessage) throws {
        try _send(message.rawData())
    }

    /// Send an OSC packet.
    ///
    /// - Parameters:
    ///   - oscData: Raw bytes of an OSC bundle or message.
    private func _send(_ oscData: Data) {
        // guard isConnected else {
        //     throw GCDAsyncUdpSocketError(
        //         .closedError,
        //         userInfo: ["Reason": "OSC TCP client socket is not connected to a remote host."]
        //     )
        // }

        // frame data
        let data = Data(framingMode.encode(data: oscData))

        // send packet
        tcpSocket.write(data, withTimeout: -1, tag: clientID)
    }
}

#endif
