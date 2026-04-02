import Foundation
import Network

public final class Server: Sendable {
    private let listener: NWListener
    private let onNotification: @Sendable (NotificationPayload) -> Void

    public init(port: UInt16 = 7433, onNotification: @escaping @Sendable (NotificationPayload) -> Void) throws {
        self.onNotification = onNotification
        let params = NWParameters.tcp
        self.listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
    }

    public func start() {
        listener.newConnectionHandler = { [onNotification] connection in
            Server.handleConnection(connection, onNotification: onNotification)
        }
        listener.stateUpdateHandler = { state in
            if case .ready = state {
                print("KeepGoing listening on port \(self.listener.port?.rawValue ?? 0)")
            }
        }
        listener.start(queue: .global(qos: .userInitiated))
    }

    public func stop() {
        listener.cancel()
    }

    private static func handleConnection(
        _ connection: NWConnection,
        onNotification: @escaping @Sendable (NotificationPayload) -> Void
    ) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
            defer {
                let response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                connection.send(
                    content: response.data(using: .utf8),
                    completion: .contentProcessed { _ in connection.cancel() }
                )
            }

            guard let data, let str = String(data: data, encoding: .utf8) else { return }

            // Extract body after HTTP headers
            guard let separatorRange = str.range(of: "\r\n\r\n") else { return }
            let body = String(str[separatorRange.upperBound...])
            guard let bodyData = body.data(using: .utf8) else { return }

            do {
                let payload = try JSONDecoder().decode(NotificationPayload.self, from: bodyData)
                onNotification(payload)
            } catch {
                print("KeepGoing: failed to decode payload: \(error)")
            }
        }
    }
}
