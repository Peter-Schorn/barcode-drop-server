import Foundation
import Logging
import Vapor

// MARK: - WebsocketClients storage -

class WebsocketClients: @unchecked Sendable {
    
    let logger = Logger(label: "com.Peter-Schorn.WebsocketClients")

    private let eventLoop: EventLoop
    private var storage: [UUID: WebSocketClient]
    
    var active: [WebSocketClient] {
        self.storage.values.filter { !$0.socket.isClosed }
    }

    init(eventLoop: EventLoop, clients: [UUID: WebSocketClient] = [:]) {
        self.eventLoop = eventLoop
        self.storage = clients
    }
    
    func add(_ client: WebSocketClient) {
        
        self.logger.info(
            "WebsocketClients.add(_:) adding client with id: \(client.id)"
        )

        self.storage[client.id] = client

        //  handle incoming messages
        client.socket.onText { [weak self] ws, text in

            guard let self = self else { return }
        
            let loggingPrefix = """
                [\(Date())] \(client.user) (client id: \(client.id))
                """

            // send high-level pong response
            if text == "ping" {
                self.logger.info(
                    """
                    \(loggingPrefix) received ping -> sending pong
                    """
                )
                ws.send("pong")
            }
            else {
                self.logger.info(
                    """
                    \(loggingPrefix) received text: "\(text)"
                    """
                )
            }
    
        }

        // handle websocket disconnect
        client.socket.onClose.whenComplete { [weak self] result in
            self?.logger.info(
                """
                websocket disconnected for user \(client.user) \
                (client id: \(client.id)) result: \(result)
                """
            )
        }

        client.socket.pingInterval = .seconds(5)

        client.socket.onPing { [weak self] ws, data in
            self?.logger.trace(
                """
                \(client.user) received low-level PING for user '\(client.user)' \
                (client id: \(client.id)): \
                \(String(buffer: data))
                """
            )
        }

        client.socket.onPong { [weak self] ws, data in
            self?.logger.trace(
                """
                \(client.user) received low-level PONG for user '\(client.user)' \
                (client id: \(client.id)) \
                \(String(buffer: data))
                """
            )
        }

    }

    func remove(_ client: WebSocketClient) {
        self.storage[client.id] = nil
    }
    
    subscript(uuid: UUID) -> WebSocketClient? {
        get {
            self.storage[uuid]
        }
        set {
            self.storage[uuid] = newValue
        }
    }

    deinit {
        let clients = self.storage.values
        self.logger.notice(
            """
            WebSocketClients.deinit: deinitializing WebsocketClients: \
            \(clients)
            """
        )
        let futures = self.storage.values.map { $0.socket.close() }
        try? self.eventLoop.flatten(futures).wait()
    }

}
