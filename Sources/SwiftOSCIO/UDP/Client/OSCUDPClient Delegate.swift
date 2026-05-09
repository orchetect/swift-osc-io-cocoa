//
//  OSCUDPClient Delegate.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
import Foundation
import SwiftOSCCore

extension OSCUDPClient {
    final class Delegate: NSObject { }
}

extension OSCUDPClient.Delegate: GCDAsyncUdpSocketDelegate {
    // we don't care about handling any delegate methods here so none are overridden
}

extension OSCUDPClient.Delegate: Sendable { }

#endif
