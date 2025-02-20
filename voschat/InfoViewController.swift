import UIKit

class InfoViewController: UIViewController {
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        return stack
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        title = "О приложении"
        view.backgroundColor = .systemBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Закрыть",
            style: .done,
            target: self,
            action: #selector(dismissVC)
        )
        
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        let appIcon = UIImageView(image: UIImage(named: "AppIcon"))
        appIcon.contentMode = .scaleAspectFit
        appIcon.widthAnchor.constraint(equalToConstant: 100).isActive = true
        appIcon.heightAnchor.constraint(equalToConstant: 100).isActive = true
        
        let titleLabel = makeLabel(text: "VOSChat", size: 24, weight: .bold)
        let versionLabel = makeLabel(text: "Версия 1.0.0", size: 17)
        let descriptionLabel = makeLabel(text: "Простой и быстрый мессенджер\nдля общения", size: 17)
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        
        let devLabel = makeLabel(text: "Разработчик: Владимир Голубев", size: 15)
        let websiteLabel = makeLabel(text: "vos9.su", size: 15)
        websiteLabel.textColor = .systemBlue
        
        [appIcon, titleLabel, versionLabel, descriptionLabel, devLabel, websiteLabel]
            .forEach { stackView.addArrangedSubview($0) }
    }
    
    private func makeLabel(text: String, size: CGFloat, weight: UIFont.Weight = .regular) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size, weight: weight)
        return label
    }
    
    @objc private func dismissVC() {
        dismiss(animated: true)
    }
}
