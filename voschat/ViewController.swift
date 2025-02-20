//
//  ViewController.swift
//  voschat
//
//  Created by Владимир Голубев on 20.02.2025.
//

import UIKit
import Foundation

class ViewController: UIViewController {
    private let tableView = UITableView()
    private let inputField = UITextField()
    private let sendButton = UIButton()
    private var messages: [Message] = []
    private let websocket = WebSocketManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupWebSocket()
        loadMessages()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        tableView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - 60)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        
        inputField.frame = CGRect(x: 16, y: view.bounds.height - 50, width: view.bounds.width - 80, height: 40)
        inputField.borderStyle = .roundedRect
        view.addSubview(inputField)
        
        sendButton.frame = CGRect(x: view.bounds.width - 56, y: view.bounds.height - 50, width: 40, height: 40)
        sendButton.setTitle("→", for: .normal)
        sendButton.setTitleColor(.blue, for: .normal)
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        view.addSubview(sendButton)
    }
    
    private func setupWebSocket() {
        websocket.onMessage = { [weak self] message in
            self?.messages.append(message)
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }
    }
    
    private func loadMessages() {
        NetworkManager.shared.getMessages { [weak self] result in
            switch result {
            case .success(let messages):
                self?.messages = messages
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            case .failure(let error):
                print("Error loading messages:", error)
            }
        }
    }
    
    @objc private func sendMessage() {
        guard let text = inputField.text, !text.isEmpty else { return }
        let message = Message(content: text, from: "1", to: "2") // Hardcoded IDs for example
        NetworkManager.shared.sendMessage(message) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.inputField.text = ""
                }
            case .failure(let error):
                print("Error sending message:", error)
            }
        }
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let message = messages[indexPath.row]
        cell.textLabel?.text = "\(message.from): \(message.content)"
        return cell
    }
}

