//
//  OSCTCPHandlerProtocol.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
import Foundation
import SwiftOSCCore
internal import SwiftOSCIOInternals

/// Internal protocol that TCP-based OSC classes adopt in order to handle incoming OSC data.
protocol _OSCTCPHandlerProtocol: OSCTCPHandlerProtocol {
    var tcpSocket: GCDAsyncSocket { get }
}

extension _OSCTCPHandlerProtocol {
    func _handle(receivedData data: Data, on sock: GCDAsyncSocket /* , tag: Int */) {
        let remoteHost = sock.connectedHost ?? ""
        let remotePort = sock.connectedPort
        
        handle(receivedData: data, remoteHost: remoteHost, remotePort: remotePort)
    }
}

#endif
