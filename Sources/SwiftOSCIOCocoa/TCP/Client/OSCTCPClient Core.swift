//
//  OSCTCPClient Core.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
import Foundation
import SwiftOSCCore
internal import SwiftOSCIOInternals

extension OSCTCPClient {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Wrapper = OSCTCPClient
        
        let tcpSocket: GCDAsyncSocket
        let tcpDelegate: Delegate
        let clientID: OSCTCPClientSessionID = 0
        let queue: DispatchQueue
        var receiveHandler: OSCHandlerBlock?
        var notificationHandler: Wrapper.NotificationHandlerBlock?
        var timeTagMode: OSCTimeTagMode
        let remoteHost: String
        let remotePort: UInt16
        let interface: String?
        let framingMode: OSCTCPFramingMode
        
        init(
            remoteHost: String,
            remotePort: UInt16,
            interface: String?,
            timeTagMode: OSCTimeTagMode,
            framingMode: OSCTCPFramingMode,
            queue: DispatchQueue?,
            receiveHandler: OSCHandlerBlock?
        ) {
            self.remoteHost = remoteHost
            self.remotePort = remotePort
            self.interface = interface
            self.timeTagMode = timeTagMode
            self.framingMode = framingMode
            let queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCTCPClient.queue")
            self.queue = queue
            self.receiveHandler = receiveHandler
            
            tcpDelegate = Delegate()
            tcpSocket = GCDAsyncSocket(delegate: tcpDelegate, delegateQueue: queue, socketQueue: nil)
            tcpDelegate.oscServer = self
        }
        
        deinit {
            close()
        }
    }
}

extension OSCTCPClient.Core: @unchecked Sendable { } // TODO: unchecked

// MARK: - Lifecycle

extension OSCTCPClient.Core {
    func connect(timeout: TimeInterval = 5.0) throws {
        try tcpSocket.connect(
            toHost: remoteHost,
            onPort: remotePort,
            viaInterface: interface,
            withTimeout: max(1.0, timeout) // negative values mean indefinite (no timeout) which is a bit dangerous
        )
    }
    
    func close() {
        tcpSocket.disconnectAfterWriting()
    }
}

// MARK: - Communication

extension OSCTCPClient.Core: _OSCTCPHandlerProtocol {
    // provides implementation for dispatching incoming OSC data
}

extension OSCTCPClient.Core: _OSCTCPSendProtocol {
    // provides implementation for sending OSC data
    
    func send(_ packet: OSCPacket) throws {
        try _send(packet)
    }
}

extension OSCTCPClient.Core: OSCTCPGeneratesClientNotificationsProtocol {
    func generateConnectedNotification() {
        let notif: Wrapper.Notification = .connected
        notificationHandler?(notif)
    }
    
    func generateDisconnectedNotification(error: (any Error)?) {
        let notif: Wrapper.Notification = .disconnected(error: error)
        notificationHandler?(notif)
    }
}

// MARK: - Properties

extension OSCTCPClient.Core {
    var isConnected: Bool {
        tcpSocket.isConnected
    }
    
    func setReceiveHandler(_ handler: OSCHandlerBlock?) {
        queue.async {
            self.receiveHandler = handler
        }
    }
    
    func setNotificationHandler(_ handler: Wrapper.NotificationHandlerBlock?) {
        queue.async {
            self.notificationHandler = handler
        }
    }
}

#endif
