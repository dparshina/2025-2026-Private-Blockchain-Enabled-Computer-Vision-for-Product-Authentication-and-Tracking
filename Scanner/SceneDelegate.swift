import UIKit
import metamask_ios_sdk

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    var web3: Web3Service = Connect.connection
    private var warmUpTask: Task<Void, Never>!

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene)
        else {
            return
        }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        window.makeKeyAndVisible()

        warmUpTask = Task.detached(priority: .userInitiated) { [web3] in
            web3.warmUp()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accountDidSwitch(_:)),
            name: .accountDidSwitch,
            object: nil
        )

        setUp()
    }

    @objc private func accountDidSwitch(_ note: Notification) {
        if let role = note.userInfo?["role"] as? WalletRole {
            showHome(role: role)
        } else {
            setUp()
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        if URLComponents(url: url, resolvingAgainstBaseURL: true)?.host == "mmsdk" {
            MetaMaskSDK.sharedInstance?.handleUrl(url)
        }
    }

    private func setUp() {
        if web3.account != nil {
            showLoading()
            resolveAndShowHome()
        }
        else {
            showAuth()
        }
    }

    private func showLoading() {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        vc.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor)
        ])
        window?.rootViewController = vc
    }

    func showHome(role: WalletRole) {
        let homeVC: HomeVC = switch role {
            case .manufacturer_emp: ManufacturerHomeVC()
            case .manufacturer_cert_emp: ManufacturerHomeVC()
            case .manufacturer_admin: ManufacturerHomeVC()
            case .logistics_admin: LogisticsHomeVC()
            case .logistics_emp:   LogisticsHomeVC()
            case .recipient:    RecipientHomeVC()
        }
        homeVC.role = role

        let homeNav = UINavigationController(rootViewController: homeVC)
        homeNav.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)

        let profileVC = ProfileVC()
        profileVC.role = role
        let profNav = UINavigationController(rootViewController: profileVC)
        profNav.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person"), tag: 1)

        let tabBar = UITabBarController()
        tabBar.viewControllers = [homeNav, profNav]
        window?.rootViewController = tabBar
    }

    func resolveAndShowHome() {
        Task {
            await warmUpTask.value
            guard let account = web3.account?.hex(eip55: false), !account.isEmpty else {
                await MainActor.run { showAuth() }
                return
            }
            let role = await web3.resolveRole(for: account)
            await MainActor.run { showHome(role: role) }
        }
    }

    func showAuth() {
        window?.rootViewController = MetaMaskVC()
    }

    func sceneDidDisconnect(_ scene: UIScene) {

    }

    func sceneDidBecomeActive(_ scene: UIScene) {

    }

    func sceneWillResignActive(_ scene: UIScene) {

    }

    func sceneWillEnterForeground(_ scene: UIScene) {

    }

    func sceneDidEnterBackground(_ scene: UIScene) {

    }

}
