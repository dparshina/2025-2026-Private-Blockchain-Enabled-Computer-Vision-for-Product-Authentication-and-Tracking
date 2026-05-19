import UIKit
import BigInt

private final class BalanceCardView: UIView {

    var onToggleHidden: (() -> Void)?

    private let networkLabel = UILabel()
    private let visibilityButton = UIButton(type: .system)
    private let balanceLabel = UILabel()
    private let unitLabel = UILabel()

    init() {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 22
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.cgColor

        setupContent()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupContent() {
        networkLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        networkLabel.textColor = .label

        unitLabel.text = "SEP"
        unitLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        unitLabel.textColor = .secondaryLabel

        balanceLabel.font = .monospacedDigitSystemFont(ofSize: 52, weight: .bold)
        balanceLabel.textColor = .label
        balanceLabel.adjustsFontSizeToFitWidth = true
        balanceLabel.minimumScaleFactor = 0.6

        visibilityButton.tintColor = .secondaryLabel
        visibilityButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        visibilityButton.addTarget(self, action: #selector(visibilityTapped), for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [makePill(), UIView(), visibilityButton])
        header.alignment = .center

        let balanceRow = UIStackView(arrangedSubviews: [balanceLabel, unitLabel])
        balanceRow.alignment = .lastBaseline
        balanceRow.spacing = 8

        let stack = UIStackView(arrangedSubviews: [header, balanceRow])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
        ])
    }

    private func makePill() -> UIView {
        let pill = UIView()
        pill.backgroundColor = .tertiarySystemBackground
        pill.layer.cornerRadius = 12
        pill.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let dot = UIView()
        dot.backgroundColor = .systemGreen
        dot.layer.cornerRadius = 3

        [dot, networkLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            pill.addSubview($0)
        }

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),
            dot.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            dot.centerYAnchor.constraint(equalTo: pill.centerYAnchor),

            networkLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            networkLabel.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10),
            networkLabel.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
        ])
        return pill
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        layer.borderColor = UIColor.separator.cgColor
    }

    @objc private func visibilityTapped() { onToggleHidden?() }

    func apply(_ vm: BalanceState) {
        networkLabel.text = vm.network
        balanceLabel.text = vm.isBalanceHidden ? "••••••" : vm.balanceSep
        let iconName = vm.isBalanceHidden ? "eye.slash" : "eye"
        visibilityButton.setImage(UIImage(systemName: iconName), for: .normal)
        visibilityButton.setTitle(vm.isBalanceHidden ? " Hidden" : " Shown", for: .normal)
    }
}

class DepositManagementVC: UIViewController {

    var accent: UIColor = .systemBlue
    private let vm = DepositViewModel()

    private let scrollView = UIScrollView()
    private let titleLabel = UILabel()
    private let card = BalanceCardView()
    private let depositButton = DepositPressableButton(type: .system)
    private let withdrawButton = DepositPressableButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationController?.setNavigationBarHidden(true, animated: false)

        setupTitle()
        setupButtons()
        setupLayout()
        bindActions()

        vm.onStateChanged = { [weak self] in
            guard let self else { return }
            self.card.apply(self.vm.state)
        }
        card.apply(vm.state)
        vm.load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func setupTitle() {
        titleLabel.text = "Balance"
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = .label
    }

    private func setupButtons() {
        depositButton.setTitle("Add deposit", for: .normal)
        depositButton.setTitleColor(.white, for: .normal)
        depositButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        depositButton.setImage(UIImage(systemName: "arrow.down"), for: .normal)
        depositButton.tintColor = .white
        depositButton.backgroundColor = accent
        depositButton.layer.cornerRadius = 16

        withdrawButton.setTitle("Withdraw", for: .normal)
        withdrawButton.setTitleColor(.label, for: .normal)
        withdrawButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        withdrawButton.setImage(UIImage(systemName: "arrow.up"), for: .normal)
        withdrawButton.tintColor = .label
        withdrawButton.backgroundColor = .secondarySystemBackground
        withdrawButton.layer.cornerRadius = 16
        withdrawButton.layer.borderWidth = 1
        withdrawButton.layer.borderColor = UIColor.separator.cgColor
    }

    private func setupLayout() {
        let buttonRow = UIStackView(arrangedSubviews: [depositButton, withdrawButton])
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 10

        let stack = UIStackView(arrangedSubviews: [titleLabel, card, buttonRow])
        stack.axis = .vertical
        stack.spacing = 24
        stack.setCustomSpacing(16, after: card)
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        scrollView.refreshControl = refresh

        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),

            depositButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    private func bindActions() {
        depositButton.onTap = { [weak self] in
            let vc = AddDepositVC()
            vc.onFinished = { [weak self] in self?.vm.load() }
            self?.presentSheet(vc)
        }
        withdrawButton.onTap = { [weak self] in
            let vc = WithdrawDepositVC()
            vc.onFinished = { [weak self] in self?.vm.load() }
            self?.presentSheet(vc)
        }
        card.onToggleHidden = { [weak self] in
            self?.vm.toggleHidden()
        }
    }

    private func presentSheet(_ vc: UIViewController) {
        let nav = UINavigationController(rootViewController: vc)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.custom { _ in 550 }]
        }
        present(nav, animated: true)
    }

    @objc private func handleRefresh() {
        vm.load()
        scrollView.refreshControl?.endRefreshing()
    }
}
