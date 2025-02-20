import Foundation

struct Message: Codable {
    var id: String?
    let content: String
    let from: String
    let to: String
    var timestamp: String?
    var chatId: String?
    var fileInfo: FileInfo?
    
    var formattedTime: String {
        guard let timestamp = timestamp,
              let date = ISO8601DateFormatter().date(from: timestamp) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, content, from, to, timestamp
        case chatId = "chat_id"
        case fileInfo = "file_info"
    }
}

struct FileInfo: Codable {
    let id: String
    let fileName: String
    let fileSize: Int
    let fileType: String
    let fileUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case fileName = "file_name"
        case fileSize = "file_size"
        case fileType = "file_type"
        case fileUrl = "file_url"
    }
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

struct Chat: Codable {
    let id: String
    let name: String
    let members: [String]
    let isGroup: Bool
    let created: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, members, created
        case isGroup = "is_group"
    }
}

struct UserStatus: Codable {
    let type: String
    let userId: String
    let online: Bool
    let lastSeen: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case userId = "user_id"
        case online
        case lastSeen = "last_seen"
    }
}

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
}

struct CreateChatRequest: Codable {
    let name: String
    let members: [String]
}
