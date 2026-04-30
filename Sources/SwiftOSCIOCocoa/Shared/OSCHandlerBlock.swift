//
//  OSCHandlerBlock.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

/// Received-message handler closure used by SwiftOSC socket classes.
public typealias OSCHandlerBlock = @Sendable (
    _ message: OSCMessage,
    _ timeTag: OSCTimeTag,
    _ host: String,
    _ port: UInt16
) -> Void
