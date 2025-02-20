//
//  ViewController.swift
//  voschat
//
//  Created by Владимир Голубев on 20.02.2025.
//

import UIKit
import Foundation

class MessageCell: UITableViewCell {
    private let bubbleView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = .white
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let fileButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.layer.cornerRadius = 8
        button.backgroundColor = .secondarySystemBackground
        button.isHidden = true
        return button
    }()
    
    weak var delegate: MessageCellDelegate?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(fileButton)
        
        [bubbleView, messageLabel, timeLabel, fileButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),
            
            timeLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 2),
            timeLabel.heightAnchor.constraint(equalToConstant: 15),
            timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            fileButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 4),
            fileButton.leadingAnchor.constraint(equalTo: messageLabel.leadingAnchor),
            fileButton.heightAnchor.constraint(equalToConstant: 30),
            fileButton.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8)
        ])
        
        fileButton.addTarget(self, action: #selector(fileButtonTapped), for: .touchUpInside)
    }
    
    func configure(with message: Message, isFromCurrentUser: Bool) {
        messageLabel.text = message.content
        timeLabel.text = message.formattedTime
        
        if isFromCurrentUser {
            bubbleView.backgroundColor = .systemBlue
            bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 40).isActive = true
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8).isActive = true
            timeLabel.textAlignment = .right
            timeLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor).isActive = true
        } else {
            bubbleView.backgroundColor = .systemGray
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8).isActive = true
            bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -40).isActive = true
            timeLabel.textAlignment = .left
            timeLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor).isActive = true
        }
        
        if let fileInfo = message.fileInfo {
            fileButton.isHidden = false
            fileButton.setTitle("📎 \(fileInfo.fileName)", for: .normal)
            fileButton.tag = fileInfo.id.hashValue
        } else {
            fileButton.isHidden = true
        }
    }
    
    @objc private func fileButtonTapped() {
        delegate?.didTapFile(in: self)
    }
}

protocol MessageCellDelegate: AnyObject {
    func didTapFile(in cell: MessageCell)
}

class ViewController: UIViewController {
    private let tableView = UITableView()
    private let inputField = UITextField()
    private let sendButton = UIButton()
    private let attachButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.tintColor = .systemBlue
        return button
    }()
    private var messages: [Message] = []
    private let websocket = WebSocketManager.shared
    private let filePreviewController = UIDocumentInteractionController()
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupWebSocket()
        loadMessages()
        setupNavigationBar()
        addLongPressGesture() // добавляем длинное нажатие для удаления сообщения
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: "MessageCell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = .systemBackground
        view.addSubview(tableView)
        
        let inputContainer = UIView()
        inputContainer.backgroundColor = .secondarySystemBackground
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputContainer)
        
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.placeholder = "Сообщение..."
        inputField.backgroundColor = .systemBackground
        inputField.layer.cornerRadius = 20
        inputField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        inputField.leftViewMode = .always
        inputContainer.addSubview(inputField)
        
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.tintColor = .systemBlue
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        inputContainer.addSubview(sendButton)
        
        inputContainer.addSubview(attachButton)
        inputContainer.addSubview(activityIndicator) // Add activityIndicator to view hierarchy
        
        [attachButton, activityIndicator].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),
            
            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            inputContainer.heightAnchor.constraint(equalToConstant: 60),
            
            inputField.leadingAnchor.constraint(equalTo: attachButton.trailingAnchor, constant: 8),
            inputField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            inputField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            inputField.heightAnchor.constraint(equalToConstant: 40),
            
            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 40),
            sendButton.heightAnchor.constraint(equalToConstant: 40),
            
            attachButton.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 16),
            attachButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            attachButton.widthAnchor.constraint(equalToConstant: 30),
            attachButton.heightAnchor.constraint(equalToConstant: 30),
            
            activityIndicator.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: sendButton.centerXAnchor)
        ])
        
        attachButton.addTarget(self, action: #selector(attachButtonTapped), for: .touchUpInside)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(titleTapped))
        navigationController?.navigationBar.addGestureRecognizer(tapGesture)
        
        NotificationCenter.default.addObserver(self, 
                                             selector: #selector(keyboardWillShow), 
                                             name: UIResponder.keyboardWillShowNotification, 
                                             object: nil)
        NotificationCenter.default.addObserver(self, 
                                             selector: #selector(keyboardWillHide), 
                                             name: UIResponder.keyboardWillHideNotification, 
                                             object: nil)
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
    
    private func setupNavigationBar() {
        title = "VOSChat"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(showInfo)
        )
    }
    
    @objc private func showInfo() {
        let infoVC = InfoViewController()
        let nav = UINavigationController(rootViewController: infoVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }
    
    @objc private func sendMessage() {
        guard let text = inputField.text, !text.isEmpty else { return }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let message = Message(content: text, from: "2", to: "1", timestamp: timestamp)
        sendMessageToServer(message: message)
    }
    
    private func sendMessageToServer(message: Message) {
        NetworkManager.shared.sendMessage(message) { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.inputField.text = ""
                }
            case .failure(let error):
                print("Error sending message:", error)
                DispatchQueue.main.async {
                    self?.showError("Не удалось отправить сообщение")
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func attachButtonTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Фото", style: .default) { [weak self] _ in
            self?.showImagePicker(sourceType: .photoLibrary)
        })
        
        alert.addAction(UIAlertAction(title: "Камера", style: .default) { [weak self] _ in
            self?.showImagePicker(sourceType: .camera)
        })
        
        alert.addAction(UIAlertAction(title: "Документ", style: .default) { [weak self] _ in
            self?.showDocumentPicker()
        })
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showImagePicker(sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else { return }
        
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        picker.mediaTypes = ["public.image"]
        present(picker, animated: true)
    }
    
    private func showDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.data", "public.content"], in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }
    
    @objc private func keyboardWillShow(notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let inset = keyboardFrame.height - view.safeAreaInsets.bottom
        tableView.contentInset.bottom = inset
        tableView.verticalScrollIndicatorInsets.bottom = inset
    }
    
    @objc private func keyboardWillHide(notification: Notification) {
        tableView.contentInset.bottom = 0
        tableView.verticalScrollIndicatorInsets.bottom = 0
    }
    
    private func showLoading(_ show: Bool) {
        if show {
            activityIndicator.startAnimating()
            sendButton.isHidden = true
        } else {
            activityIndicator.stopAnimating()
            sendButton.isHidden = false
        }
    }
    
    @objc private func titleTapped() {
        let alert = UIAlertController(title: "Участники и группы", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Добавить участника", style: .default) { [weak self] _ in
            self?.showAddMemberDialog()
        })
        alert.addAction(UIAlertAction(title: "Создать групповой чат", style: .default) { [weak self] _ in
            self?.showCreateGroupChatDialog()
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showAddMemberDialog() {
        let alert = UIAlertController(title: "Добавить участника", message: "Введите ID пользователя", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "ID пользователя"
        }
        
        alert.addAction(UIAlertAction(title: "Добавить", style: .default) { [weak self] _ in
            if let userId = alert.textFields?.first?.text, !userId.isEmpty {
                self?.addMemberToChat(userId: userId)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func addMemberToChat(userId: String) {
        // TODO: Implement API call to add user to chat
        print("Adding user with ID: \(userId) to chat")
    }
    
    private func showCreateGroupChatDialog() {
        let alert = UIAlertController(title: "Новый групповой чат", message: "Введите название и ID участников (через запятую)", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Название группы"
        }
        alert.addTextField { textField in
            textField.placeholder = "ID участников, через запятую"
        }
        alert.addAction(UIAlertAction(title: "Создать", style: .default) { [weak self, weak alert] _ in
            guard let fields = alert?.textFields, fields.count >= 2,
                  let groupName = fields[0].text, !groupName.isEmpty,
                  let membersText = fields[1].text, !membersText.isEmpty
            else { return }
            let members = membersText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            NetworkManager.shared.createGroupChat(name: groupName, members: members) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let chat):
                        let info = "Группа \"\(chat.name)\" создана"
                        let successAlert = UIAlertController(title: "Успех", message: info, preferredStyle: .alert)
                        successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(successAlert, animated: true)
                    case .failure(let error):
                        self?.showError("Ошибка создания группы: \(error.localizedDescription)")
                    }
                }
            }
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }
    
    private func addLongPressGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        tableView.addGestureRecognizer(longPress)
    }
    
    @objc private func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began,
              let indexPath = tableView.indexPathForRow(at: gestureRecognizer.location(in: tableView)),
              let messageId = messages[indexPath.row].id else { return }
        
        let alert = UIAlertController(title: "Удалить сообщение?",
                                      message: "Вы уверены, что хотите удалить это сообщение?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            NetworkManager.shared.deleteMessage(id: messageId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.messages.remove(at: indexPath.row)
                        self?.tableView.deleteRows(at: [indexPath], with: .automatic)
                    case .failure(let error):
                        self?.showError("Ошибка удаления: \(error.localizedDescription)")
                    }
                }
            }
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - MessageCellDelegate
extension ViewController: MessageCellDelegate {
    func didTapFile(in cell: MessageCell) {
        guard let indexPath = tableView.indexPath(for: cell),
              let fileInfo = messages[indexPath.row].fileInfo,
              let url = URL(string: fileInfo.fileUrl) else { return }
        
        showLoading(true)
        
        URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            DispatchQueue.main.async {
                self?.showLoading(false)
                
                if let error = error {
                    print("Error downloading file:", error)
                    return
                }
                
                guard let tempURL = tempURL else { return }
                
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsURL.appendingPathComponent(fileInfo.fileName)
                
                try? FileManager.default.removeItem(at: destinationURL)
                try? FileManager.default.moveItem(at: tempURL, to: destinationURL)
                
                self?.filePreviewController.url = destinationURL
                self?.filePreviewController.delegate = self
                self?.filePreviewController.presentPreview(animated: true)
            }
        }.resume()
    }
}

// MARK: - UIDocumentPickerDelegate
extension ViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        showLoading(true)
        
        guard let data = try? Data(contentsOf: url) else {
            showLoading(false)
            return
        }
        
        NetworkManager.shared.uploadFile(data, filename: url.lastPathComponent) { [weak self] result in
            DispatchQueue.main.async {
                self?.showLoading(false)
                
                switch result {
                case .success(let fileInfo):
                    let timestamp = ISO8601DateFormatter().string(from: Date())
                    let message = Message(content: "Отправлен файл", 
                                       from: "2", 
                                       to: "1", 
                                       timestamp: timestamp, 
                                       fileInfo: fileInfo)
                    self?.sendMessageToServer(message: message)
                case .failure(let error):
                    print("Error uploading file:", error)
                    // Показать ошибку пользователю
                    let alert = UIAlertController(title: "Ошибка", 
                                                message: "Не удалось загрузить файл", 
                                                preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
}

// MARK: - UIDocumentInteractionControllerDelegate
extension ViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
}

// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let url = info[.imageURL] as? URL else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        
        NetworkManager.shared.uploadFile(data, filename: url.lastPathComponent) { [weak self] result in
            switch result {
            case .success(let fileInfo):
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let message = Message(content: "Отправлен файл", from: "2", to: "1", timestamp: timestamp, fileInfo: fileInfo)
                self?.sendMessageToServer(message: message)
            case .failure(let error):
                print("Error uploading file:", error)
                DispatchQueue.main.async {
                    self?.showError("Не удалось загрузить файл")
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
        let message = messages[indexPath.row]
        let isFromCurrentUser = message.from == "2" // Здесь используем ваш ID пользователя
        cell.delegate = self
        cell.configure(with: message, isFromCurrentUser: isFromCurrentUser)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

