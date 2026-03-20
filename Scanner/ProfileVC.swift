import UIKit

class ProfileVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let settingTV = UITableView(frame: .zero, style: .insetGrouped)
    
    enum ProfileSection: Int, CaseIterable {
        case userInfo
        case accounts
        case logout
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        title = "Profile"
    
        configureTV()
    }
    

    
    func configureTV(){
        settingTV.backgroundColor = .systemGroupedBackground
        settingTV.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingTV)
        settingTV.dataSource = self
        settingTV.delegate = self
        
        settingTV.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        settingTV.sectionHeaderHeight = 8
        settingTV.sectionFooterHeight = 8
        settingTV.layer.cornerRadius = 10
        
        NSLayoutConstraint.activate([
            settingTV.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            settingTV.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingTV.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingTV.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    
        
    }
    
    

    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            switch ProfileSection(rawValue: section) {
            case .userInfo:  return 1
            case .accounts:  return 1
            case .logout:    return 1
            case .none:      return 0
            }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return ProfileSection.allCases.count  
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        cell.accessoryType = .none

        
        switch ProfileSection(rawValue: indexPath.section) {
            
        case .userInfo:
            config.text = "Address"
            config.secondaryText = Connect.connection.metamaskSDK.account
            
        case .accounts:
            config.text = "Switch account"
            config.image = UIImage(systemName: "person.2.fill")
            config.imageProperties.tintColor = .systemBlue
            cell.accessoryType = .disclosureIndicator
            
        case .logout:
            config.text = "Log out"
            config.image = UIImage(systemName: "rectangle.portrait.and.arrow.right")
            config.textProperties.color = .systemRed
            config.imageProperties.tintColor = .systemRed
            
        case .none:
            break
        }
        
        cell.contentConfiguration = config
        return cell
    }


        func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            switch ProfileSection(rawValue: section) {
            case .userInfo:  return nil
            case .accounts:  return nil
            case .logout:    return nil
            case .none:      return nil
            }
        }


        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)

            switch ProfileSection(rawValue: indexPath.section) {
            case .accounts:
                showSwitchAccount()
            case .logout:
                showLogoutAlert()
            default:
                break
            }
        }


        func showLogoutAlert() {
            let alert = UIAlertController(
                title: "Log out?",
                message: "You will have to login again to access your data.",
                preferredStyle: .actionSheet
            )
            alert.addAction(UIAlertAction(title: "Log out", style: .destructive) { [weak self] _ in
                self?.performLogout()
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        }

        func performLogout() {
            UserDefaults.standard.removeObject(forKey: "currentUser")

            let loginVC = UINavigationController(rootViewController: MetaMaskVC())
            guard let window = view.window else { return }
            UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
                window.rootViewController = loginVC
            }
        }


        func showSwitchAccount() {
            let vc = SwitchAccountVC()
            if let sheet = vc.sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 20
            }
            present(vc, animated: true)
        }
}
    



