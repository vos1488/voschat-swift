package main

import (
	"time"
)

// Message represents a chat message
type Message struct {
	ID        *string   `json:"id,omitempty"`
	Content   string    `json:"content"`
	From      string    `json:"from"`
	To        string    `json:"to"`
	Timestamp *string   `json:"timestamp,omitempty"`
	ChatID    *string   `json:"chat_id,omitempty"`
	FileInfo  *FileInfo `json:"file_info,omitempty"`
}

// FileInfo represents uploaded file information
type FileInfo struct {
	ID       string `json:"id"`
	FileName string `json:"file_name"`
	FileSize int64  `json:"file_size"`
	FileType string `json:"file_type"`
	FileURL  string `json:"file_url"`
}

// User represents a user in the system
type User struct {
	ID       string `json:"id"`
	Username string `json:"username"`
	Created  string `json:"created"`
	LastSeen string `json:"last_seen"`
}

// Chat represents a chat room or direct message
type Chat struct {
	ID      string   `json:"id"`
	Name    string   `json:"name"`
	Members []string `json:"members"`
	IsGroup bool     `json:"is_group"`
	Created string   `json:"created"`
}

// UserStatus represents user online status
type UserStatus struct {
	Type     string `json:"type"`
	UserID   string `json:"user_id"`
	Online   bool   `json:"online"`
	LastSeen string `json:"last_seen"`
}

// APIResponse is a generic wrapper for API responses
type APIResponse[T any] struct {
	Success bool   `json:"success"`
	Data    *T     `json:"data,omitempty"`
	Error   string `json:"error,omitempty"`
}

// CreateChatRequest represents a request to create a new chat
type CreateChatRequest struct {
	Name    string   `json:"name"`
	Members []string `json:"members"`
}

// WebSocketMessage represents messages sent over WebSocket
type WebSocketMessage struct {
	Type string      `json:"type"`
	Data interface{} `json:"data"`
}

// Helper functions to create timestamp strings
func CurrentTimestamp() string {
	return time.Now().Format(time.RFC3339)
}

// Helper to create API responses
func NewSuccessResponse[T any](data T) APIResponse[T] {
	return APIResponse[T]{
		Success: true,
		Data:    &data,
	}
}

func NewErrorResponse[T any](errorMsg string) APIResponse[T] {
	return APIResponse[T]{
		Success: false,
		Error:   errorMsg,
	}
}