import UIKit
import metamask_ios_sdk

class MetaMaskVC: UIViewController {
    
    let connect = Connect.connection
      
    private let titleLabel = UILabel()
    private let iconView = UIImageView()
    private let subtitleLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let buttonBack = UIButton(type: .system)


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
        !connect.metamaskSDK.account.isEmpty
    }

    private func updateUI() {
        spinner.stopAnimating()
        actionButton.isEnabled = true
        buttonBack.isHidden = !isConnected

        if !isInstalled {
            titleLabel.text = "MetaMask required"
            subtitleLabel.text = "Install MetaMask to use this app."
            setButton(title: "Install MetaMask", color: .systemGreen)
            iconView.image = UIImage(systemName: "arrow.2.circlepath.circle")
            iconView.tintColor = .systemYellow
        }
        else if isConnected {
            let addr = connect.metamaskSDK.account
            let short = "\(addr.prefix(6))...\(addr.suffix(4))"
            titleLabel.text = "Connected"
            subtitleLabel.text = short
            setButton(title: "Disconnect", color: .systemRed)
            iconView.image = UIImage(systemName: "checkmark.circle")
            iconView.tintColor = .systemGreen
        }
        else {
            titleLabel.text = "Connect wallet"
            subtitleLabel.text = "Connect your MetaMask wallet to continue."
            setButton(title: "Connect with MetaMask", color: .systemGreen)
            iconView.image = UIImage(systemName: "arrow.2.circlepath.circle")
            iconView.tintColor = .systemYellow
        }
    }


    @objc private func actionTapped() {
        if !isInstalled {
            UIApplication.shared.open(URL(string: "https://apps.apple.com/app/metamask/id1438144202")!)
        }
        else if isConnected {
            let sdk = connect.metamaskSDK
            sdk.disconnect()
            sdk.account.removeAll()
            sdk.clearSession()
            updateUI()
        }
        else {
            Task {
                await connect()
            }
        }
    }
    
    @objc private func goingBack() {
        (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.showHome()
    }

    private func connect() async {
        spinner.startAnimating()
        actionButton.isEnabled = false

        let result = await connect.metamaskSDK.connect()

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
        actionButton.setTitle(title, for: .normal)
        actionButton.backgroundColor = color
    }

    private func setupUI() {
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        
        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        actionButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        actionButton.layer.cornerRadius = 20
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        
        buttonBack.setTitle("Go back", for: .normal)
        buttonBack.tintColor = .white
        buttonBack.backgroundColor = .systemBlue
        buttonBack.layer.cornerRadius = 20
        buttonBack.titleLabel?.font = .systemFont(ofSize: 18, weight: .regular)
        buttonBack.translatesAutoresizingMaskIntoConstraints = false
        buttonBack.addTarget(self, action: #selector(goingBack), for: .touchUpInside)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true

        [stack, subtitleLabel, actionButton, buttonBack, spinner].forEach {
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -120),

            subtitleLabel.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 20),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            actionButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            actionButton.heightAnchor.constraint(equalToConstant: 52),
            
            buttonBack.topAnchor.constraint(equalTo: actionButton.bottomAnchor, constant: 15),
            buttonBack.leadingAnchor.constraint(equalTo: actionButton.leadingAnchor),
            buttonBack.trailingAnchor.constraint(equalTo: actionButton.trailingAnchor),
            buttonBack.heightAnchor.constraint(equalToConstant: 52),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: actionButton.bottomAnchor, constant: 16),
        ])
    }
}


