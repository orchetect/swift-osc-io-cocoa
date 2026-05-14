//
//  OSCUDPServer Core.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
internal import SwiftOSCIOInternals
import Foundation
import SwiftOSCCore

extension OSCUDPServer {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCUDPServer

        let udpSocket: GCDAsyncUdpSocket
        let udpDelegate = Parent.Delegate()
        let queue: DispatchQueue
        var receiveHandler: OSCPacketHandler?
        var receiveErrorHandler: OSCDecodeErrorHandlerBlock?

        var localPort: UInt16 {
            udpSocket.localPort()
        }

        private var _localPort: UInt16?
        private(set) var interface: String?
        var isPortReuseEnabled: Bool = false
        private(set) var isStarted: Bool = false

        init(
            port: UInt16?,
            interface: String?,
            isPortReuseEnabled: Bool,
            queue: DispatchQueue?,
            receiveHandler: OSCPacketHandler?
        ) {
            _localPort = (port == nil || port == 0) ? nil : port
            self.interface = interface
            self.isPortReuseEnabled = isPortReuseEnabled
            self.queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCUDPServer.queue", target: .global())
            self.receiveHandler = receiveHandler

            udpSocket = GCDAsyncUdpSocket(delegate: udpDelegate, delegateQueue: self.queue, socketQueue: nil)
            udpDelegate.oscServer = self
        }

        deinit {
            stop()
        }
    }
}

extension OSCUDPServer.Core: @unchecked Sendable { }

// MARK: - Lifecycle

extension OSCUDPServer.Core {
    func start() throws {
        guard !isStarted else { return }

        stop()

        try udpSocket.enableReusePort(isPortReuseEnabled)

        do {
            try udpSocket.bind(
                toPort: _localPort ?? 0, // 0 causes system to assign random open port
                interface: interface
            )
        } catch let error as GCDAsyncUdpSocketError where error.code == .badParamError {
            // catch invalid interface error because we have a specific SwiftOSC error case for it.
            // CocoaAsyncSocket does not provide granular enough error types to know if it's an interface error
            // so we must resort to error string introspection.
            throw OSCIOError.invalidInterface
        } catch {
            throw error
        }

        try udpSocket.beginReceiving()

        isStarted = true
    }

    func stop() {
        udpSocket.close()

        isStarted = false
    }
}

// MARK: - Communication

extension OSCUDPServer.Core: _OSCPacketDispatcherProtocol {
    // provides implementation for dispatching incoming OSC data
}

// MARK: - Properties

extension OSCUDPServer.Core {
    func setReceiveHandler(_ handler: OSCPacketHandler?) {
        queue.sync {
            self.receiveHandler = handler
        }
    }

    func setReceiveErrorHandler(_ handler: OSCDecodeErrorHandlerBlock?) {
        queue.sync {
            self.receiveErrorHandler = handler
        }
    }
}

#endif
