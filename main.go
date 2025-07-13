package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/gorilla/websocket"
	"github.com/rs/cors"
)

// Global storage (in production, use a database)
var (
	messages []Message
	chats    []Chat
	users    []User
	clients  = make(map[*websocket.Conn]bool)
	upgrader = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool {
			return true // Allow all origins in development
		},
	}
)

// CORS middleware
func enableCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// API Handlers

// GET /api/messages - Get all messages
func getMessages(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	response := NewSuccessResponse(messages)
	json.NewEncoder(w).Encode(response)
}

// POST /api/messages - Send a message
func sendMessage(w http.ResponseWriter, r *http.Request) {
	var message Message
	if err := json.NewDecoder(r.Body).Decode(&message); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		response := NewErrorResponse[Message]("Invalid message format")
		json.NewEncoder(w).Encode(response)
		return
	}

	// Generate ID and timestamp if not provided
	id := uuid.New().String()
	message.ID = &id
	timestamp := CurrentTimestamp()
	message.Timestamp = &timestamp

	// Add to storage
	messages = append(messages, message)

	// Broadcast to all WebSocket clients
	broadcastMessage(message)

	w.Header().Set("Content-Type", "application/json")
	response := NewSuccessResponse(message)
	json.NewEncoder(w).Encode(response)
}

// DELETE /api/messages/{id} - Delete a message
func deleteMessage(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	messageID := vars["id"]

	// Find and remove message
	for i, msg := range messages {
		if msg.ID != nil && *msg.ID == messageID {
			messages = append(messages[:i], messages[i+1:]...)
			w.WriteHeader(http.StatusOK)
			response := NewSuccessResponse(map[string]string{"status": "deleted"})
			json.NewEncoder(w).Encode(response)
			return
		}
	}

	w.WriteHeader(http.StatusNotFound)
	response := NewErrorResponse[map[string]string]("Message not found")
	json.NewEncoder(w).Encode(response)
}

// GET /api/messages/between/{user1}/{user2} - Get messages between two users
func getMessagesBetween(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	user1 := vars["user1"]
	user2 := vars["user2"]

	var filteredMessages []Message
	for _, msg := range messages {
		if (msg.From == user1 && msg.To == user2) || (msg.From == user2 && msg.To == user1) {
			filteredMessages = append(filteredMessages, msg)
		}
	}

	w.Header().Set("Content-Type", "application/json")
	response := NewSuccessResponse(filteredMessages)
	json.NewEncoder(w).Encode(response)
}

// POST /api/files - Upload a file
func uploadFile(w http.ResponseWriter, r *http.Request) {
	// Parse multipart form
	err := r.ParseMultipartForm(10 << 20) // 10 MB max
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		response := NewErrorResponse[FileInfo]("Failed to parse multipart form")
		json.NewEncoder(w).Encode(response)
		return
	}

	file, handler, err := r.FormFile("file")
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		response := NewErrorResponse[FileInfo]("No file provided")
		json.NewEncoder(w).Encode(response)
		return
	}
	defer file.Close()

	// Create uploads directory if it doesn't exist
	uploadsDir := "uploads"
	if err := os.MkdirAll(uploadsDir, 0755); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		response := NewErrorResponse[FileInfo]("Failed to create uploads directory")
		json.NewEncoder(w).Encode(response)
		return
	}

	// Generate unique filename
	fileID := uuid.New().String()
	ext := filepath.Ext(handler.Filename)
	filename := fileID + ext
	filePath := filepath.Join(uploadsDir, filename)

	// Create the file
	dst, err := os.Create(filePath)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		response := NewErrorResponse[FileInfo]("Failed to create file")
		json.NewEncoder(w).Encode(response)
		return
	}
	defer dst.Close()

	// Copy file content
	if _, err := io.Copy(dst, file); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		response := NewErrorResponse[FileInfo]("Failed to save file")
		json.NewEncoder(w).Encode(response)
		return
	}

	// Get file info
	fileInfo, err := dst.Stat()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		response := NewErrorResponse[FileInfo]("Failed to get file info")
		json.NewEncoder(w).Encode(response)
		return
	}

	// Create FileInfo response
	responseData := FileInfo{
		ID:       fileID,
		FileName: handler.Filename,
		FileSize: fileInfo.Size(),
		FileType: handler.Header.Get("Content-Type"),
		FileURL:  fmt.Sprintf("/uploads/%s", filename),
	}

	w.Header().Set("Content-Type", "application/json")
	response := NewSuccessResponse(responseData)
	json.NewEncoder(w).Encode(response)
}

// POST /api/chats - Create a new chat
func createChat(w http.ResponseWriter, r *http.Request) {
	var request CreateChatRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		response := NewErrorResponse[Chat]("Invalid request format")
		json.NewEncoder(w).Encode(response)
		return
	}

	chat := Chat{
		ID:      uuid.New().String(),
		Name:    request.Name,
		Members: request.Members,
		IsGroup: len(request.Members) > 2,
		Created: CurrentTimestamp(),
	}

	chats = append(chats, chat)

	w.Header().Set("Content-Type", "application/json")
	response := NewSuccessResponse(chat)
	json.NewEncoder(w).Encode(response)
}

// WebSocket handler
func handleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}
	defer conn.Close()

	// Register client
	clients[conn] = true
	log.Printf("Client connected. Total clients: %d", len(clients))

	// Send user status update
	status := UserStatus{
		Type:     "user_status",
		UserID:   "1", // Default user ID
		Online:   true,
		LastSeen: CurrentTimestamp(),
	}
	broadcastStatus(status)

	// Handle incoming messages
	for {
		var msg Message
		err := conn.ReadJSON(&msg)
		if err != nil {
			log.Printf("WebSocket read error: %v", err)
			break
		}

		// Process message (similar to POST /api/messages)
		id := uuid.New().String()
		msg.ID = &id
		timestamp := CurrentTimestamp()
		msg.Timestamp = &timestamp

		messages = append(messages, msg)
		broadcastMessage(msg)
	}

	// Remove client on disconnect
	delete(clients, conn)
	log.Printf("Client disconnected. Total clients: %d", len(clients))

	// Send offline status
	status.Online = false
	status.LastSeen = CurrentTimestamp()
	broadcastStatus(status)
}

// Broadcast message to all connected WebSocket clients
func broadcastMessage(message Message) {
	for client := range clients {
		err := client.WriteJSON(message)
		if err != nil {
			log.Printf("WebSocket write error: %v", err)
			client.Close()
			delete(clients, client)
		}
	}
}

// Broadcast user status to all connected WebSocket clients
func broadcastStatus(status UserStatus) {
	for client := range clients {
		err := client.WriteJSON(status)
		if err != nil {
			log.Printf("WebSocket write error: %v", err)
			client.Close()
			delete(clients, client)
		}
	}
}

// Serve uploaded files
func serveFile(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	filename := vars["filename"]
	
	filePath := filepath.Join("uploads", filename)
	
	// Check if file exists
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		http.NotFound(w, r)
		return
	}
	
	http.ServeFile(w, r, filePath)
}

// Initialize sample data
func initSampleData() {
	// Add some sample messages
	timestamp1 := CurrentTimestamp()
	timestamp2 := time.Now().Add(-1 * time.Minute).Format(time.RFC3339)
	
	id1 := uuid.New().String()
	id2 := uuid.New().String()
	
	messages = []Message{
		{
			ID:        &id1,
			Content:   "Привет! Как дела?",
			From:      "1",
			To:        "2",
			Timestamp: &timestamp2,
		},
		{
			ID:        &id2,
			Content:   "Привет! Всё отлично, спасибо!",
			From:      "2",
			To:        "1",
			Timestamp: &timestamp1,
		},
	}

	// Add sample users
	users = []User{
		{
			ID:       "1",
			Username: "user1",
			Created:  CurrentTimestamp(),
			LastSeen: CurrentTimestamp(),
		},
		{
			ID:       "2",
			Username: "user2",
			Created:  CurrentTimestamp(),
			LastSeen: CurrentTimestamp(),
		},
	}
}

func main() {
	// Initialize sample data
	initSampleData()

	// Create router
	r := mux.NewRouter()

	// API routes
	api := r.PathPrefix("/api").Subrouter()
	api.HandleFunc("/messages", getMessages).Methods("GET")
	api.HandleFunc("/messages", sendMessage).Methods("POST")
	api.HandleFunc("/messages/{id}", deleteMessage).Methods("DELETE")
	api.HandleFunc("/messages/between/{user1}/{user2}", getMessagesBetween).Methods("GET")
	api.HandleFunc("/files", uploadFile).Methods("POST")
	api.HandleFunc("/chats", createChat).Methods("POST")

	// WebSocket route
	r.HandleFunc("/ws", handleWebSocket)

	// File serving route
	r.HandleFunc("/uploads/{filename}", serveFile).Methods("GET")

	// Setup CORS
	c := cors.New(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"*"},
	})

	handler := c.Handler(r)

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	log.Printf("API endpoints available at http://localhost:%s/api/", port)
	log.Printf("WebSocket endpoint available at ws://localhost:%s/ws", port)
	
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatal("Server failed to start:", err)
	}
}