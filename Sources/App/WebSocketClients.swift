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

         // handle incoming messages
        client.socket.onText { [weak self] ws, text in
            
            self?.logger.info(#"received text: "\#(text)""#)
            
            ws.send(#"echoing back: "\#(text)""#)
        }

        // handle websocket disconnect
        client.socket.onClose.whenComplete { [weak self] _ in
            self?.logger.info("websocket disconnected")
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
        let futures = self.storage.values.map { $0.socket.close() }
        try? self.eventLoop.flatten(futures).wait()
    }

}
