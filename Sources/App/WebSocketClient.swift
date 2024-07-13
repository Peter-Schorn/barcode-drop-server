import Vapor

// MARK: - WebSocketClient -


class WebSocketClient: @unchecked Sendable {
    
    static let logger = Logger(label: "com.Peter-Schorn.WebsocketClient")

    let id: UUID
    let user: String
    let socket: WebSocket

    init(id: UUID, user: String, socket: WebSocket) {
        self.id = id
        self.user = user
        self.socket = socket
    }

    func sendJSON(
        _ value: Encodable,
        using encoder: JSONEncoder = .iso8601
    ) async throws {

        try await self.socket.sendJSON(value, using: encoder)
        
    }

    func close() {
        do {
            try self.socket.close().wait()

        } catch {
            Self.logger.error(
                """
                WebSocketClient.close: could not close websocket for client: \
                \(self): \(error)
                """
            )
        }
    }
    
}
