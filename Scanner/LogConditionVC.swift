import UIKit
import Web3
import BigInt

final class LogConditionVC: UIViewController {

    private let productId: BigUInt
    private let manufacturerAddress: EthereumAddress
    var onLogged: (() -> Void)?

    var web3: Web3Service = Connect.connection

    private let typeField = UITextField()
    private let valueField = UITextField()
    private let unitField = UITextField()
    private let presetSeg = UISegmentedControl(items: ["Temp", "Humidity", "Shock", "Custom"])
    private let sendButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(productId: BigUInt, manufacturerAddress: EthereumAddress) {
        self.productId = productId
        self.manufacturerAddress = manufacturerAddress
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Log condition"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))

        buildUI()
        applyPreset()
    }

    private func buildUI() {
        presetSeg.selectedSegmentIndex = 0
        presetSeg.addTarget(self, action: #selector(applyPreset), for: .valueChanged)
        presetSeg.translatesAutoresizingMaskIntoConstraints = false

        let typeRow = field(label: "Condition type", field: typeField, placeholder: "e.g. temperature")
        let valueRow = field(label: "Value", field: valueField, placeholder: "e.g. -4")
        valueField.keyboardType = .numbersAndPunctuation
        let unitRow = field(label: "Unit", field: unitField, placeholder: "e.g. °C")

        sendButton.setTitle("Log to chain", for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        sendButton.backgroundColor = .systemBlue
        sendButton.layer.cornerRadius = 14
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addTarget(self, action: #selector(send), for: .touchUpInside)

        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [presetSeg, typeRow, valueRow, unitRow])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(sendButton)
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            sendButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            sendButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            sendButton.heightAnchor.constraint(equalToConstant: 52),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: sendButton.topAnchor, constant: -16)
        ])
    }

    private func field(label: String, field: UITextField, placeholder: String) -> UIView {
        let wrap = UIView()
        wrap.backgroundColor = .secondarySystemGroupedBackground
        wrap.layer.cornerRadius = 12

        let l = UILabel()
        l.text = label.uppercased()
        l.font = .systemFont(ofSize: 11, weight: .semibold)
        l.textColor = .secondaryLabel

        field.placeholder = placeholder
        field.font = .systemFont(ofSize: 15)
        field.borderStyle = .none
        field.autocorrectionType = .no
        field.autocapitalizationType = .none

        let stack = UIStackView(arrangedSubviews: [l, field])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -14),
        ])
        return wrap
    }

    @objc private func applyPreset() {
        switch presetSeg.selectedSegmentIndex {
        case 0: typeField.text = "temperature"; unitField.text = "°C"
        case 1: typeField.text = "humidity"; unitField.text = "%"
        case 2: typeField.text = "shock"; unitField.text = "g"
        default: typeField.text = ""; unitField.text = ""
        }
    }

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func send() {
        let type = (typeField.text ?? "").trimmingCharacters(in: .whitespaces)
        let unit = (unitField.text ?? "").trimmingCharacters(in: .whitespaces)
        let raw = (valueField.text ?? "").trimmingCharacters(in: .whitespaces)

        guard !type.isEmpty else { return alert("Missing type", "Please specify a condition type.") }
        guard let value = Int(raw) else { return alert("Invalid value", "Value must be an integer (use a separate unit field for suffixes).") }
        guard let employee = web3.account else { return alert("Wallet not connected", "Connect your wallet to sign.") }

        sendButton.isEnabled = false
        spinner.startAnimating()

        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let opHash = try await self.web3.logCondition(
                    companyAccount: Config.logisticsAccountAddress,
                    employee: employee,
                    productId: self.productId,
                    manufacturerAddress: self.manufacturerAddress,
                    conditionType: type,
                    value: value,
                    unit: unit
                )
                print("Condition logged. Op hash: \(opHash)")
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.onLogged?()
                    self.dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    self.sendButton.isEnabled = true
                    self.spinner.stopAnimating()
                    self.alert("Couldn't log condition", error.localizedDescription)
                }
            }
        }
    }

    private func alert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
