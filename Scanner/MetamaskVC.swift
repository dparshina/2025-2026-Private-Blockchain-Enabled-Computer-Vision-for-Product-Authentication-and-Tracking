import UIKit
import metamask_ios_sdk

class MetaMaskVC: UIViewController {
      

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)


    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        updateUI()
    }


    private var isInstalled: Bool {
        UIApplication.shared.canOpenURL(URL(string: "metamask://")!)
    }
    private var isConnected: Bool {
        !Connect.connection.metamaskSDK.account.isEmpty
    }

    private func updateUI() {
        spinner.stopAnimating()
        actionButton.isEnabled = true

        if !isInstalled {
            iconView.image = UIImage(systemName: "wallet.pass")
            iconView.tintColor = .systemOrange
            titleLabel.text = "MetaMask Required"
            subtitleLabel.text = "Install MetaMask to use this app."
            setButton(title: "Install MetaMask", color: .systemOrange)
        } else if isConnected {
            let addr = Connect.connection.metamaskSDK.account
            let short = "\(addr.prefix(6))...\(addr.suffix(4))"
            iconView.image = UIImage(systemName: "checkmark.seal.fill")
            iconView.tintColor = .systemGreen
            titleLabel.text = "Connected"
            subtitleLabel.text = short
            setButton(title: "Disconnect", color: .systemRed)
        } else {
            iconView.image = UIImage(systemName: "link.circle.fill")
            iconView.tintColor = .systemBlue
            titleLabel.text = "Connect Wallet"
            subtitleLabel.text = "Connect your MetaMask wallet to continue."
            setButton(title: "Connect with MetaMask", color: .systemOrange)
        }
    }


    @objc private func actionTapped() {
        if !isInstalled {
            UIApplication.shared.open(URL(string: "https://apps.apple.com/app/metamask/id1438144202")!)
        } else if isConnected {
            Connect.connection.metamaskSDK.disconnect()
            Connect.connection.metamaskSDK.account.removeAll()
            updateUI()
        } else {
            Task { await connect() }
        }
    }

    private func connect() async {
        spinner.startAnimating()
        actionButton.isEnabled = false

        let result = await Connect.connection.metamaskSDK.connect()

        await MainActor.run {
            spinner.stopAnimating()
            actionButton.isEnabled = true

            switch result {
            case .success:
                (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.showHome()
            case .failure(let error):
                showError(error.localizedDescription)
            }

            updateUI()
        }
    }
    


    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }


    private func setButton(title: String, color: UIColor) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = color
        config.cornerStyle = .large
        actionButton.configuration = config
    }

    private func setupUI() {
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        actionButton.translatesAutoresizingMaskIntoConstraints = false

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true

        [iconView, titleLabel, subtitleLabel, actionButton, spinner].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -120),
            iconView.widthAnchor.constraint(equalToConstant: 72),
            iconView.heightAnchor.constraint(equalToConstant: 72),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            actionButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            actionButton.heightAnchor.constraint(equalToConstant: 52),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: actionButton.bottomAnchor, constant: 16),
        ])
    }
}


