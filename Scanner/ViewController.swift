import UIKit

class HomeVC: UIViewController {

    private let scanButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Scan", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .blue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 30
        button.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 26.0, *) {
            button.configuration = .glass()
        } else {
                    
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = 0.15
            button.layer.shadowOffset = CGSize(width: 0, height: 4)
            button.layer.shadowRadius = 8
                    
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        }
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    private func setupLayout(){
        
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
    
    private func setupActions() {
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
    }

    @objc private func scanButtonTapped() {
        let scanning = ScanningVC()
        navigationController?.pushViewController(scanning, animated: true)
    }
}


