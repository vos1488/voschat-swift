import Foundation

struct Message: Codable {
    var id: String?
    let content: String
    let from: String
    let to: String
    var timestamp: String?
}

struct User: Codable {
    let id: String
    let username: String
    let created: String
    let lastSeen: String
    
    enum CodingKeys: String, CodingKey {
        case id, username, created
        case lastSeen = "last_seen"
    }
}

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
}
