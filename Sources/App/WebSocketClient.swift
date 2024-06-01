import Vapor

// MARK: - WebSocketClient -


class WebSocketClient: @unchecked Sendable {
    
    let id: UUID
    let user: String
    let socket: WebSocket

    init(id: UUID, user: String, socket: WebSocket) {
        self.id = id
        self.user = user
        self.socket = socket
    }
    
}
