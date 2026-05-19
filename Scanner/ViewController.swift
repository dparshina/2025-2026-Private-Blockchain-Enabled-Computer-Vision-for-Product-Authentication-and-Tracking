import UIKit

class HomeVC: UIViewController {

    var web3: Web3Service = Connect.connection
    var role: WalletRole?

    private let scanButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Scan", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .blue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 15
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.15
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8

        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        return button
    }()

    func setupScanButton() {
        view.addSubview(scanButton)
        view.bringSubviewToFront(scanButton)
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            scanButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scanButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scanButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            scanButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc private func scanButtonTapped() {
        let scanning = ScanningVC()
        scanning.role = role
        navigationController?.pushViewController(scanning, animated: true)
    }

}
