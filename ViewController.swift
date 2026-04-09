import UIKit

class HomeVC: UIViewController {
    
    let connect = Connect.connection

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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAccountSwitch), name: .accountDidSwitch, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNavigationBar()
    }
    
    


    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(scanButton)
        
        NSLayoutConstraint.activate([
            scanButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scanButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scanButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            scanButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func updateNavigationBar() {
        Task { [weak self] in
            guard let self = self
            else {
                return
            }

            let account = self.connect.metamaskSDK.account

            guard !account.isEmpty
            else {
                await MainActor.run {
                    self.navigationItem.rightBarButtonItem = nil
                }
                return
            }

            let role = await self.connect.resolveRole(for: account)

            await MainActor.run {
                if role == .manufacturer {
                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addingProductVC))
                }
                else {
                    self.navigationItem.rightBarButtonItem = nil
                }
            }
        }
    }
    
    @objc private func onAccountSwitch() {
        updateNavigationBar()
    }
    
    private func setupActions() {
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
    }

    @objc private func scanButtonTapped() {
        let scanning = ScanningVC()
        navigationController?.pushViewController(scanning, animated: true)
    }
    
    @objc private func addingProductVC() {
        let navi = UINavigationController(rootViewController: AddProductInfoVC())
        if let sheetNew = navi.sheetPresentationController {
            sheetNew.detents = [.custom { _ in return 450}]
        }
        navigationController?.present(navi, animated: true)
        
    }
}


