import Foundation
import Logging
import Vapor

// MARK: - WebsocketClients webSocketStorage -

class WebsocketClients: @unchecked Sendable {
    
    static let logger = Logger(label: "com.Peter-Schorn.WebsocketClients")

    private let eventLoop: EventLoop
    private var webSocketStorage: [UUID: WebSocketClient]
    
    var active: [WebSocketClient] {
        self.webSocketStorage.values.filter { !$0.socket.isClosed }
    }

    init(eventLoop: EventLoop, clients: [UUID: WebSocketClient] = [:]) {
        self.eventLoop = eventLoop
        self.webSocketStorage = clients
    }
    
    func add(_ client: WebSocketClient) {
        
        Self.logger.info(
            """
            WebsocketClients.add(_:) adding client: \(client.user) \
            (client id: \(client.id)
            """
        )

        self.webSocketStorage[client.id] = client

        //  handle incoming messages
        client.socket.onText { [weak self] ws, text in

            guard let self = self else { return }
        
            let loggingPrefix = """
                [\(Date())] \(client.user) (client id: \(client.id))
                """

            // send high-level pong response
            if text == "ping" {
                Self.logger.info(
                    """
                    \(loggingPrefix) received ping -> sending pong
                    """
                )
                ws.send("pong")
            }
            else {
                Self.logger.info(
                    """
                    \(loggingPrefix) received text: "\(text)"
                    """
                )
            }
    
        }

        // handle websocket disconnect
        client.socket.onClose.whenComplete { [weak self] result in
            Self.logger.info(
                """
                websocket disconnected for user \(client.user) \
                (client id: \(client.id)) result: \(result)
                """
            )
        }


        client.socket.pingInterval = .seconds(5)

        client.socket.onPing { [weak self] ws, data in
            Self.logger.trace(
                """
                \(client.user) received low-level PING for user '\(client.user)' \
                (client id: \(client.id)): \
                \(String(buffer: data))
                """
            )
        }

        client.socket.onPong { [weak self] ws, data in
            Self.logger.trace(
                """
                \(client.user) received low-level PONG for user '\(client.user)' \
                (client id: \(client.id)) \
                \(String(buffer: data))
                """
            )
        }

    }

    func sendJSON(
        _ value: Encodable,
        to clients: [WebSocketClient],
        user: String,
        using encoder: JSONEncoder = .iso8601
    ) async {

        // only group together delete scans for now
        // (and grouped messages must be of the same type)
        if let deleteScans = value as? DeleteScans {

            let transactionHash = deleteScans.transactionHash
            let transactionHashString = transactionHash.map { "\($0)" } ?? "nil"

            Self.logger.info(
                """
                WebsocketClients.sendJSON: sending deleteScans message \
                to clients (transactionHash: \(transactionHashString)): \
                \(clients)
                """
            )

            // MARK: Group together delete notifications at this point
            // group based on the transaction hash and time of the message

            for client in clients {
                do {
                    try await client.sendJSON(deleteScans, using: encoder)

                } catch {
                    Self.logger.error(
                        """
                        could not send deleteScans message \
                        to client: \(client): \(error)
                        """
                    )
                }
            }
        }
        else {
            for client in clients {
                do {
                    try await client.sendJSON(value, using: encoder)

                } catch {
                    Self.logger.error(
                        """
                        could not send JSON message \
                        to client: \(client): \(error)
                        """
                    )
                }
            }
        }

    
    }

    func remove(_ client: WebSocketClient) {

        Self.logger.info(
            """
            WebsocketClients.remove(_:) removing client: \(client.user) \
            (client id: \(client.id))
            """
        )

        client.close()

        self.webSocketStorage[client.id] = nil

    }
    
    /// Returns all clients for the given user.
    func clientsForUser(_ user: String) -> [WebSocketClient] {
        self.webSocketStorage.values.filter { $0.user == user }
    }

    subscript(uuid: UUID) -> WebSocketClient? {
        get {
            self.webSocketStorage[uuid]
        }
        set {
            self.webSocketStorage[uuid] = newValue
        }
    }

    deinit {
        
        Self.logger.notice(
            """
            WebSocketClients.deinit: calling self.closeWebsockets()
            """
        )

        self.closeWebsockets()

    }

    func closeWebsockets() {

        let clients = self.webSocketStorage.values
        Self.logger.notice(
            """
            WebSocketClients.closeWebsockets: closing websockets for clients: \
            \(clients)
            """
        )
        let futures = self.webSocketStorage.values.map { $0.socket.close() }

        do {
            try self.eventLoop.flatten(futures).wait()

        } catch {
            Self.logger.error(
                """
                WebSocketClients.closeWebsockets: error closing sockets: \
                clients: \(clients): \(error)
                """
            )
        }

    }

}
