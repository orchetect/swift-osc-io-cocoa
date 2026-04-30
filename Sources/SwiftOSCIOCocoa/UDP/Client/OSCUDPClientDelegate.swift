//
//  OSCUDPClientDelegate.swift
//  SwiftOSC • https://github.com/orchetect/SwiftOSC
//  © 2020-2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency import CocoaAsyncSocket
import Foundation
import SwiftOSCCore

final class OSCUDPClientDelegate: NSObject { }

extension OSCUDPClientDelegate: GCDAsyncUdpSocketDelegate {
    // we don't care about handling any delegate methods here so none are overridden
}

extension OSCUDPClientDelegate: Sendable { }

#endif
