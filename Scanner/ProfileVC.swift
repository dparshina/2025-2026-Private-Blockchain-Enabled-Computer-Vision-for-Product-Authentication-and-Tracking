import UIKit

class ProfileVC: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let settingTV = UITableView(frame: .zero, style: .insetGrouped)
    private let vm = ProfileViewModel()
    var role: WalletRole? {
        get {
            vm.role
        }
        set {
            vm.setRole(newValue)
        }
    }

    enum ProfileRow {
        case role
        case address
        case accounts
        case manageDeposit
        case logout
    }

    private var tableData: [[ProfileRow]] {
        var sections: [[ProfileRow]] = []

        if role == .recipient {
            sections.append([.address])
        }
        else {
            sections.append([.role, .address])
        }

        sections.append([.accounts])
        if role == .manufacturer_admin || role == .logistics_admin {
            sections.append([.manageDeposit])
        }
        sections.append([.logout])

        return sections
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationController?.navigationBar.prefersLargeTitles = true
        title = "Profile"

        configureTV()

        vm.onChanged = {
            [weak self] in self?.settingTV.reloadData()
        }
        Task {
            await vm.load()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(onAccountSwitch(_:)), name: .accountDidSwitch, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task {
            await vm.load()
        }
    }

    @objc private func onAccountSwitch(_ notification: Notification) {
        let newRole = notification.userInfo?["role"] as? WalletRole
        vm.setRole(newRole ?? vm.role)
    }

    func configureTV(){
        settingTV.backgroundColor = .systemGroupedBackground
        settingTV.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingTV)
        settingTV.dataSource = self
        settingTV.delegate = self

        settingTV.sectionHeaderHeight = 5
        settingTV.sectionFooterHeight = 5
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

        guard let cell = cell
        else {
            return UITableViewCell()
        }

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
            cell.detailTextLabel?.text = role?.rawValue

        case .address:
            cell.textLabel?.text = "Address"
            let account = vm.account
            cell.detailTextLabel?.text = account.isEmpty ? "Not connected" : "\(account.prefix(6))...\(account.suffix(4))"
            cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

        case .accounts:
            cell.textLabel?.text = "Switch account"
            cell.imageView?.image = UIImage(systemName: "person.2.fill")
            cell.imageView?.tintColor = .blue
            cell.accessoryType = .disclosureIndicator

        case .manageDeposit:
            cell.textLabel?.text = "Manage deposit"
            cell.imageView?.image = UIImage(systemName: "dollarsign.ring")
            cell.imageView?.tintColor = .systemGreen
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

        case .manageDeposit:
            showMoneyDW()
        case .logout:
            showLogoutAlert()

        default:
            break
        }
    }

    func showLogoutAlert() {
        let alert = UIAlertController(title: "Log out?", message: "You will have to login again.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Log out", style: .destructive) {
            [weak self] _ in
            self?.performLogout()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func showMoneyDW() {
        let vc = DepositManagementVC()
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        present(vc, animated: true)
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
