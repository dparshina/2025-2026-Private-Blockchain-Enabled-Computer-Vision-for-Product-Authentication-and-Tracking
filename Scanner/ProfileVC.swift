import UIKit

class ProfileVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let settingTV = UITableView(frame: .zero, style: .insetGrouped)
    private var currentRole: WalletRole = .recipient
    let connect = Connect.connection
    
    
    enum ProfileRow {
        case role
        case address
        case accounts
        case logout
    }
    
    private var tableData: [[ProfileRow]] {
        var sections: [[ProfileRow]] = []
        
        if currentRole == .recipient {
            sections.append([.address])
        }
        else {
            sections.append([.role, .address])
        }
        
        sections.append([.accounts])
        sections.append([.logout])
        
        return sections
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        title = "Profile"
    
        configureTV()
        
        Task {
            await loadCurrentRole()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(onAccountSwitch(_:)), name: .accountDidSwitch, object: nil)
    }
    
    
    private func loadCurrentRole() async {
        let account = connect.metamaskSDK.account
        guard !account.isEmpty
        else {
            return
        }
        let role = await connect.resolveRole(for: account)
        await MainActor.run {
            currentRole = role
            settingTV.reloadData()
        }
    }

    @objc private func onAccountSwitch(_ notification: Notification) {
        if let role = notification.userInfo?["role"] as? WalletRole {
            currentRole = role
        }
        settingTV.reloadData()
    }

    
    func configureTV(){
        settingTV.backgroundColor = .systemGroupedBackground
        settingTV.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingTV)
        settingTV.dataSource = self
        settingTV.delegate = self
        
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
        return tableData[section].count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return tableData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        if cell == nil {
            cell = UITableViewCell(style: .value1, reuseIdentifier: "cell")
        }
        
        guard let cell = cell else { return UITableViewCell() }
        
        cell.accessoryType = .none
        cell.textLabel?.textColor = .label
        cell.detailTextLabel?.font = .systemFont(ofSize: 14)
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.imageView?.tintColor = nil
        cell.imageView?.image = nil
        cell.detailTextLabel?.text = nil

        let rowType = tableData[indexPath.section][indexPath.row]

        switch rowType {
        case .role:
            cell.textLabel?.text = "Role"
            cell.detailTextLabel?.text = currentRole.rawValue

        case .address:
            cell.textLabel?.text = "Address"
            let account = connect.metamaskSDK.account
            cell.detailTextLabel?.text = account.isEmpty ? "Not connected" : "\(account.prefix(6))...\(account.suffix(4))"
            cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

        case .accounts:
            cell.textLabel?.text = "Switch account"
            cell.imageView?.image = UIImage(systemName: "person.2.fill")
            cell.imageView?.tintColor = .blue
            cell.accessoryType = .disclosureIndicator

        case .logout:
            cell.textLabel?.text = "Log out"
            cell.imageView?.image = UIImage(systemName: "rectangle.portrait.and.arrow.right")
            cell.textLabel?.textColor = .systemRed
            cell.imageView?.tintColor = .systemRed
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }


    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let rowType = tableData[indexPath.section][indexPath.row]
        
        switch rowType {
        case .accounts:
            showSwitchAccount()
            
        case .logout:
            showLogoutAlert()
            
        default:
            break
        }
    }


    func showLogoutAlert() {
        let alert = UIAlertController(title: "Log out?", message: "You will have to login again.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Log out", style: .destructive) { [weak self] _ in
            self?.performLogout()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func performLogout() {
        let loginVC = UINavigationController(rootViewController: MetaMaskVC())
        guard let window = view.window
        else {
            return
        }
        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
            window.rootViewController = loginVC
        }
    }


    func showSwitchAccount() {
        let vc = SwitchAccountVC()
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.custom { _ in return 250}]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        present(vc, animated: true)
    }
}
    



