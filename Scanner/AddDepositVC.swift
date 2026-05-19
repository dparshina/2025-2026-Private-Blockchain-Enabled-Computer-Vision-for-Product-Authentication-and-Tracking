import UIKit
import BigInt

final class AddDepositVC: UIViewController {

    private let titleLabel = UILabel()
    private let explanationLabel = UILabel()
    private let amountField = DepositAmountField()
    private let confirmButton = DepositPressableButton(type: .system)

    var web3: Web3Service = Connect.connection
    var onFinished: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        setupLabels()
        setupConfirmButton()
        setupLayout()

        amountField.addTarget(self, action: #selector(amountChanged), for: .editingChanged)
        confirmButton.onTap = { [weak self] in self?.handleConfirm() }
        setConfirmEnabled(false)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func setupLabels() {
        titleLabel.text = "Add deposit"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .label

        explanationLabel.text = "You're adding ETH to your company's account on Sepolia. The amount you confirm will be deposited from your connected wallet."
        explanationLabel.font = .systemFont(ofSize: 14)
        explanationLabel.textColor = .secondaryLabel
        explanationLabel.numberOfLines = 0
    }

    private func setupConfirmButton() {
        confirmButton.setTitle("Confirm deposit", for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        confirmButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
        confirmButton.tintColor = .white
        confirmButton.backgroundColor = .systemBlue
        confirmButton.layer.cornerRadius = 16
        confirmButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        confirmButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
    }

    private func setupLayout() {
        let stack = UIStackView(arrangedSubviews: [titleLabel, explanationLabel, amountField, confirmButton])
        stack.axis = .vertical
        stack.spacing = 24
        stack.setCustomSpacing(12, after: titleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            confirmButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    private func setConfirmEnabled(_ enabled: Bool) {
        confirmButton.isEnabled = enabled
        confirmButton.alpha = enabled ? 1.0 : 0.5
    }

    @objc private func amountChanged() {
        setConfirmEnabled(amountField.amount != nil)
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    private func handleConfirm() {
        guard let amount = amountField.amount, let wei = weiFromEth(amount) else {
            presentDepositAlert(title: "Invalid amount", message: "Could not parse the amount.")
            return
        }
        amountField.resignFirstResponder()
        setConfirmEnabled(false)

        Task.detached { [weak self] in
            guard let self else { return }
            do {
                _ = try await web3.addDeposit(money: wei)
                try? await Task.sleep(nanoseconds: 3_800_000_000)
                await MainActor.run {
                    self.dismiss(animated: true) { self.onFinished?() }
                }
            } catch {
                print("=== ADD DEPOSIT ERROR ===\n\(error)")
                await MainActor.run {
                    self.setConfirmEnabled(true)
                    self.presentDepositAlert(title: "Transaction failed", message: error.localizedDescription)
                }
            }
        }
    }
}
