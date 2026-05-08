//
//  OSCTCPClient Delegate.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
import Foundation
internal import SwiftOSCIOInternals

extension OSCTCPClient {
    /// Internal TCP receiver class so as to not expose `GCDAsyncSocketDelegate` methods as public.
    final class Delegate: NSObject {
        weak var oscServer: (any _OSCTCPHandlerProtocol & _OSCTCPGeneratesClientNotificationsProtocol)?
        
        // already implemented by NSObject
        // init() { }
    }
}

extension OSCTCPClient.Delegate: @unchecked Sendable { } // TODO: unchecked

extension OSCTCPClient.Delegate: GCDAsyncSocketDelegate {
    func newSocketQueueForConnection(fromAddress address: Data, on sock: GCDAsyncSocket) -> dispatch_queue_t? {
        oscServer?.queue
    }

    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        // send notification
        oscServer?._generateConnectedNotification()

        // read initial data
        oscServer?.tcpSocket.readData(withTimeout: -1, tag: 0)
    }

    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        defer {
            // request socket to continue reading data
            sock.readData(withTimeout: -1, tag: tag)
        }

        oscServer?._handle(receivedData: data, on: sock)
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: (any Error)?) {
        // errors should only ever be of type `GCDAsyncSocketError`
        var error = err as? GCDAsyncSocketError
        // CocoaAsyncSocket populates `err` with GCDAsyncSocketError.closedError
        // whenever the remote peer closes its connection intentionally,
        // so we'll interpret that as a non-error condition
        if error?.code == GCDAsyncSocketError.closedError {
            error = nil
        }

        // send notification
        oscServer?._generateDisconnectedNotification(
            error: error
        )
    }
}

#endif
