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
    /// Send an OSC packet.
    ///
    /// - Parameters:
    ///   - oscPacket: OSC bundle or message.
    func _send(_ oscPacket: OSCPacket) throws {
        try _send(oscPacket.rawData())
    }

    /// Send an OSC bundle.
    ///
    /// - Parameters:
    ///   - oscBundle: OSC bundle.
    func _send(_ oscBundle: OSCBundle) throws {
        try _send(oscBundle.rawData())
    }

    /// Send an OSC message.
    ///
    /// - Parameters:
    ///   - oscMessage: OSC message.
    func _send(_ oscMessage: OSCMessage) throws {
        try _send(oscMessage.rawData())
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
