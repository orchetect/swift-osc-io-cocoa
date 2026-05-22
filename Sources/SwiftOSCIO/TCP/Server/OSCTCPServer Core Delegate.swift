//
//  OSCTCPServer Core Delegate.swift
//  SwiftOSC I/O: Cocoa • https://github.com/orchetect/swift-osc-io-cocoa
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if canImport(Darwin) && !os(watchOS)

@preconcurrency internal import CocoaAsyncSocket
internal import SwiftOSCIOInternals
import Foundation
import Synchronization

extension OSCTCPServer.Core {
    /// Internal TCP receiver class so as to not expose `GCDAsyncSocketDelegate` methods as public.
    final class Delegate: NSObject {
        nonisolated(unsafe)
        weak var oscServer: (any _OSCTCPPacketDispatcherProtocol & OSCTCPGeneratesServerNotificationsProtocol)?

        /// Internal queue used for synchronizing access to mutable properties.
        let syncQueue = DispatchQueue(label: "com.orchetect.SwiftOSC.OSCTCPServer.Delegate.syncQueue", target: .global())

        let framingMode: OSCTCPFramingMode

        /// Currently connected client sessions.
        var clients: [OSCTCPClientSessionID: ClientConnection] {
            get {
                syncQueue.sync { _clients }
            }
            _modify {
                var value = syncQueue.sync { _clients }
                yield &value
                syncQueue.sync { _clients = value }
            }
            set {
                syncQueue.sync { _clients = newValue }
            }
        }

        nonisolated(unsafe) private var _clients: [OSCTCPClientSessionID: ClientConnection] = [:]

        init(framingMode: OSCTCPFramingMode) {
            self.framingMode = framingMode
        }

        deinit {
            closeClients()
        }
    }
}

extension OSCTCPServer.Core.Delegate: Sendable { }

extension OSCTCPServer.Core.Delegate: GCDAsyncSocketDelegate {
    func newSocketQueueForConnection(fromAddress address: Data, on sock: GCDAsyncSocket) -> dispatch_queue_t? {
        oscServer?.queue
    }

    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        // add new connection to connections dictionary
        let clientID = newClientID()
        let newConnection = ClientConnection(
            tcpSocket: newSocket,
            clientID: clientID,
            framingMode: framingMode,
            delegate: self
        )
        clients[clientID] = newConnection
        newSocket.delegate = self

        // send notification
        oscServer?.generateConnectedNotification(
            remoteHost: newSocket.connectedHost ?? "",
            remotePort: newSocket.connectedPort,
            clientID: clientID
        )

        // read initial data
        newSocket.readData(withTimeout: -1, tag: clientID)
    }

    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        defer {
            // request socket to continue reading data
            sock.readData(withTimeout: -1, tag: tag)
        }

        oscServer?._dispatch(receivedTCPFramedData: data, on: sock)
    }

    // note that this is NOT called when we initiate a graceful connection closure.
    // this is called when the remote server closes the connection, and possibly when
    // the connection drops due to poor network conditions or the server becoming unreachable (?).
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: (any Error)?) {
        // remove connection from connections dictionary

        // in almost all cases, this should only return one client,
        // however for sake of over-engineering, we'll remove all matches
        let disconnectedClients: [(clientID: Int, host: String, port: UInt16)] = clients
            .filter { $0.value.tcpSocket == sock }
            .map {
                (
                    clientID: $0.key,
                    host: $0.value.remoteHost,
                    port: $0.value.remotePort
                )
            }

        for (clientID, _, _) in disconnectedClients {
            clients[clientID]?.delegate = nil
            clients[clientID] = nil
        }

        // errors should only ever be of type `GCDAsyncSocketError`
        var error = err as? GCDAsyncSocketError
        // CocoaAsyncSocket populates `err` with GCDAsyncSocketError.closedError
        // whenever the remote peer closes its connection intentionally,
        // so we'll interpret that as a non-error condition
        if error?.code == GCDAsyncSocketError.closedError {
            error = nil
        }

        // send notification
        // note that sock.connectedHost will be nil, and sock.connectedPort will be 0
        // so we need to grab host/port from the local clients info
        for (clientID, host, port) in disconnectedClients {
            oscServer?.generateDisconnectedNotification(
                remoteHost: host,
                remotePort: port,
                clientID: clientID,
                error: error
            )
        }
    }
}

// MARK: - Methods

extension OSCTCPServer.Core.Delegate {
    /// Close connections for any connected clients and remove them from the list of connected clients.
    func closeClients() {
        for clientID in clients.keys {
            closeClient(clientID: clientID)
        }
    }

    /// Close a connection and remove it from the list of connected clients.
    func closeClient(clientID: Int) {
        guard clients[clientID] != nil,
              let host = clients[clientID]?.remoteHost,
              let port = clients[clientID]?.remotePort
        else { return }

        clients[clientID]?.close()
        clients[clientID] = nil

        // send notification
        // (when we close a client connection, the `socketDidDisconnect` method does not fire
        // so we have to manually generate a notification here.
        oscServer?.generateDisconnectedNotification(
            remoteHost: host,
            remotePort: port,
            clientID: clientID,
            error: nil
        )
    }
}

// MARK: - Utilities

extension OSCTCPServer.Core.Delegate {
    /// Generate a new client ID that is not currently in use by any connected client(s).
    private func newClientID() -> OSCTCPClientSessionID {
        var clientID: Int = 0
        while clientID == 0 || clients.keys.contains(clientID) {
            // don't allow 0 or negative numbers
            clientID = Int.random(in: 1 ... Int.max)
        }
        assert(clientID > 0)
        return clientID
    }
}

#endif
