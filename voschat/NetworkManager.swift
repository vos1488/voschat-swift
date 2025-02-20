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
    
    func uploadFile(_ fileData: Data, filename: String, completion: @escaping (Result<FileInfo, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/files") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let response = try JSONDecoder().decode(APIResponse<FileInfo>.self, from: data)
                if let fileInfo = response.data {
                    completion(.success(fileInfo))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func createGroupChat(name: String, members: [String], completion: @escaping (Result<Chat, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/chats") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let chatRequest = CreateChatRequest(name: name, members: members)
        
        do {
            request.httpBody = try JSONEncoder().encode(chatRequest)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let response = try JSONDecoder().decode(APIResponse<Chat>.self, from: data)
                if let chat = response.data {
                    completion(.success(chat))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

extension NetworkManager {
    func deleteMessage(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/messages/\(id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }.resume()
    }
    
    func getMessagesBetween(user1: String, user2: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/messages/between/\(user1)/\(user2)") else { return }
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
}

class WebSocketManager {
    static let shared = WebSocketManager()
    private var webSocket: URLSessionWebSocketTask?
    var onMessage: ((Message) -> Void)?
    var onStatusUpdate: ((UserStatus) -> Void)?
    
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
    
    private func handleWebSocketMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        if let statusUpdate = try? JSONDecoder().decode(UserStatus.self, from: data) {
            self.onStatusUpdate?(statusUpdate)
            return
        }
        
        if let message = try? JSONDecoder().decode(Message.self, from: data) {
            self.onMessage?(message)
        }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleWebSocketMessage(text)
                default:
                    break
                }
                self?.receiveMessage()
            case .failure(let error):
                print("WebSocket receive error:", error)
                // Implement reconnection logic here
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
