import UIKit
import metamask_ios_sdk
import Web3


enum WalletRole: String {
    case manufacturer = "Manufacturer"
    case logistics = "Logistics provider"
    case recipient = "Recipient"
}

extension Notification.Name {
    static let accountDidSwitch = Notification.Name("accountDidSwitch")
}

import UIKit
import metamask_ios_sdk

class SwitchAccountVC: UIViewController {
    
    let connect = Connect.connection
    private var currentRole: WalletRole = .recipient

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let switchButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupUI()

        NotificationCenter.default.addObserver(self, selector: #selector(handleSDKAccountChange), name: NSNotification.Name("MetaMaskSDKAccountChanged"), object: nil)
    }


    @objc private func handleSDKAccountChange() {
        let newAccount = connect.metamaskSDK.account
        guard !newAccount.isEmpty
        else {
            return
        }

        spinner.startAnimating()
        switchButton.isEnabled = false

        Task {
            let role = await connect.resolveRole(for: newAccount)

            await MainActor.run {
                spinner.stopAnimating()
                switchButton.isEnabled = true

                NotificationCenter.default.post(name: .accountDidSwitch, object: nil, userInfo: ["role": role, "address": newAccount])
                dismiss(animated: true)
            }
        }
    }
    
    
    private func switchAccount() async {
            await MainActor.run {
                switchButton.isEnabled = false
                spinner.startAnimating()
            }
            let sdk = connect.metamaskSDK
            sdk.clearSession()
    
            let result = await sdk.connect()
    
            await MainActor.run {
                spinner.stopAnimating()
                switchButton.isEnabled = true
            }
    
            switch result {
            case .success:
                let newAddress = connect.metamaskSDK.account
                guard !newAddress.isEmpty
                else {
                    return
                }
    
                let role = await connect.resolveRole(for: newAddress)
    
                await MainActor.run {
                    self.currentRole = role
                    NotificationCenter.default.post(name: .accountDidSwitch, object: nil, userInfo: ["role": role])
                    dismiss(animated: true)
                }

    
            case .failure(let err):
                await MainActor.run {
                    self.showError(err.localizedDescription)
                }
            }
        }
    
    @objc private func switchTapped() {
        Task {
            await switchAccount()
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func setupUI() {

        let currentAccount = connect.metamaskSDK.account
        let displayAddress = currentAccount.isEmpty ? "Not connected" : "\(currentAccount.prefix(6))…\(currentAccount.suffix(4))"

        let viewS = UIView()
        viewS.backgroundColor = .secondarySystemGroupedBackground
        viewS.layer.cornerRadius = 14
        viewS.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "Address: " + displayAddress
        titleLabel.font = .monospacedSystemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label

        let activeBadge = makeBadge()

        let stack = UIStackView(arrangedSubviews: [titleLabel, activeBadge])
        stack.axis      = .horizontal
        stack.alignment = .center
        stack.spacing   = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        viewS.addSubview(stack)

        let infoLabel = UILabel()
        infoLabel.text = "To switch accounts, open MetaMask and select a different wallet before switching account in this app. Then return and try again."
        infoLabel.font = .systemFont(ofSize: 14)
        infoLabel.textColor = .secondaryLabel
        infoLabel.numberOfLines = 0
        infoLabel.translatesAutoresizingMaskIntoConstraints = false

        switchButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        switchButton.setTitle("Switch account", for: .normal)
        switchButton.setTitleColor(.white, for: .normal)
        switchButton.backgroundColor = .blue
        switchButton.addTarget(self, action: #selector(switchTapped), for: .touchUpInside)
        switchButton.translatesAutoresizingMaskIntoConstraints = false
        switchButton.layer.cornerRadius = 15

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true

        view.addSubview(viewS)
        view.addSubview(infoLabel)
        view.addSubview(switchButton)
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: viewS.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: viewS.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: viewS.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: viewS.trailingAnchor, constant: -16),

            viewS.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            viewS.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            viewS.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            infoLabel.topAnchor.constraint(equalTo: viewS.bottomAnchor, constant: 20),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            switchButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            switchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            switchButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            switchButton.heightAnchor.constraint(equalToConstant: 52),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: switchButton.topAnchor, constant: -40)
        ])
    }

    private func makeBadge() -> UIView {
        let badge = UILabel()
        badge.text = "Active"
        badge.font = .systemFont(ofSize: 11, weight: .medium)
        badge.textColor = .systemGreen
        badge.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 8
        badge.clipsToBounds = true
        badge.textAlignment = .center
        badge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 52),
            badge.heightAnchor.constraint(equalToConstant: 24)
        ])
        return badge
    }
}
