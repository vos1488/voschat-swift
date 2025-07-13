# VOSChat Go Server

A Go-based backend server for the VOSChat iOS application.

## Features

- RESTful API for chat messaging
- WebSocket support for real-time communication
- File upload and serving
- Group chat management
- CORS-enabled for cross-origin requests

## API Endpoints

### Messages
- `GET /api/messages` - Get all messages
- `POST /api/messages` - Send a new message
- `DELETE /api/messages/{id}` - Delete a message by ID
- `GET /api/messages/between/{user1}/{user2}` - Get messages between two users

### Files
- `POST /api/files` - Upload a file (multipart/form-data)
- `GET /uploads/{filename}` - Download/serve uploaded files

### Chats
- `POST /api/chats` - Create a new group chat

### WebSocket
- `WS /ws` - WebSocket endpoint for real-time messaging

## Building and Running

### Prerequisites
- Go 1.24+ installed

### Build
```bash
go build -o voschat-server
```

### Run
```bash
./voschat-server
```

The server will start on port 8080 by default. You can set a custom port using the `PORT` environment variable:

```bash
PORT=3000 ./voschat-server
```

## Configuration for iOS App

To use this server with the VOSChat iOS app, update the base URL in `NetworkManager.swift`:

```swift
private let baseURL = "http://localhost:8080/api"
```

And update the WebSocket URL in `WebSocketManager.swift`:

```swift
guard let url = URL(string: "ws://localhost:8080/ws") else { return }
```

## Data Models

The server uses the following data structures that match the iOS app:

- **Message**: Chat message with ID, content, sender, recipient, timestamp, and optional file info
- **FileInfo**: Information about uploaded files
- **User**: User information
- **Chat**: Chat room information
- **UserStatus**: Online status information
- **APIResponse**: Generic wrapper for all API responses

## Sample Data

The server initializes with sample messages between users "1" and "2" for testing purposes.

## File Storage

Uploaded files are stored in the `uploads/` directory relative to the server executable. In production, consider using cloud storage.

## WebSocket Communication

The WebSocket endpoint (`/ws`) supports:
- Real-time message broadcasting to all connected clients
- User status updates (online/offline)
- Automatic client management

## Development

For development, the server includes:
- CORS support for all origins
- Detailed logging
- Sample data initialization
- Error handling with proper HTTP status codes

## Production Considerations

For production deployment, consider:
- Adding authentication and authorization
- Using a proper database instead of in-memory storage
- Implementing rate limiting
- Adding input validation and sanitization
- Using environment variables for configuration
- Adding HTTPS support
- Implementing proper logging and monitoring