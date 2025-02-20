import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    private let baseURL = "http://vos9.su:8080/api"
    
    func getMessages(completion: @escaping (Result<[Message], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/messages") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let response = try JSONDecoder().decode(APIResponse<[Message]>.self, from: data)
                if let messages = response.data {
                    completion(.success(messages))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func sendMessage(_ message: Message, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/messages") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(message)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }.resume()
    }
}

class WebSocketManager {
    static let shared = WebSocketManager()
    private var webSocket: URLSessionWebSocketTask?
    var onMessage: ((Message) -> Void)?
    
    init() {
        connect()
    }
    
    private func connect() {
        guard let url = URL(string: "ws://vos9.su:8080/ws") else { return }
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        receiveMessage()
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let message = try? JSONDecoder().decode(Message.self, from: data) {
                        self?.onMessage?(message)
                    }
                default:
                    break
                }
                self?.receiveMessage()
            case .failure(let error):
                print("WebSocket receive error:", error)
            }
        }
    }
    
    func send(_ message: Message) {
        guard let data = try? JSONEncoder().encode(message),
              let string = String(data: data, encoding: .utf8) else { return }
        
        webSocket?.send(.string(string)) { error in
            if let error = error {
                print("WebSocket send error:", error)
            }
        }
    }
}
