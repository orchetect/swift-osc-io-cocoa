//
//  OSCUDPSocket Delegate.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

extension OSCUDPSocket {
    typealias Delegate = OSCUDPServer.Delegate
}

#endif
