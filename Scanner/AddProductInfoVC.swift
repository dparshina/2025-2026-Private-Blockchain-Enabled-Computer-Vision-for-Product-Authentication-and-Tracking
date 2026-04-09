import UIKit
import Web3
import BigInt

class AddProductInfoVC: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let addButton = UIButton(type: .system)
    let connect = Connect.connection

    private struct ProductField {
        let label: String
        var value: String
        let placeholder: String
        let keyboardType: UIKeyboardType
    }

    private var fields: [ProductField] = [
        ProductField(label: "Product name", value: "", placeholder: "Enter product name", keyboardType: .default),
        ProductField(label: "Serial number", value: "", placeholder: "Enter serial number", keyboardType: .default),
        ProductField(label: "Origin", value: "", placeholder: "Enter origin", keyboardType: .default),
        ProductField(label: "Destination", value: "", placeholder: "Enter destination", keyboardType: .default),
        ProductField(label: "Mass", value: "", placeholder: "Enter mass (kg)", keyboardType: .decimalPad),
        ProductField(label: "Recipient", value: "", placeholder: "Enter recipient address", keyboardType: .default)]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add product information"
        setupTableView()
        setUpAddition()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }


    private func setupTableView() {
        tableView.dataSource = self
        tableView.register(FieldCell.self, forCellReuseIdentifier: FieldCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.keyboardDismissMode = .onDrag
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        
        tableView.contentInset.bottom = 80
    }

    private func setUpAddition() {
        addButton.setTitle("Add", for: .normal)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.backgroundColor = .blue
        addButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .regular)
        addButton.setTitleColor(.white, for: .normal)
        addButton.layer.cornerRadius = 20
        view.addSubview(addButton)

        NSLayoutConstraint.activate([
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            addButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }


    @objc private func addTapped() {
        view.endEditing(true)

        let name = fields[0].value
        let serialNumber = fields[1].value
        let origin = fields[2].value
        let destination = fields[3].value
        let massString = fields[4].value
        let recipientStr = fields[5].value

        guard !name.isEmpty, !serialNumber.isEmpty, !origin.isEmpty,
              !destination.isEmpty, !massString.isEmpty, !recipientStr.isEmpty
        else {
            return
        }

        guard let massValue = BigUInt(massString)
        else {
            return
        }

        guard let recipient = try? EthereumAddress(hex: recipientStr, eip55: true)
        else {
            return
        }


        guard let employee = connect.account
        else {
            return
        }

        Task {
            do {
                let txHash = try await connect.addProductInfo(employee: employee, name: name, serialNumber: serialNumber, origin: origin, destination: destination, mass: massValue, recipient: recipient)
                print("Transaction sent: \(txHash)")
            } catch {
                print("Failed to add product: \(error)")
            }
        }
    }

    @objc private func keyboardChanged(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return
        }
        let inset = max(0, view.bounds.maxY - frame.minY)
        tableView.contentInset.bottom = inset
        tableView.verticalScrollIndicatorInsets.bottom = inset
    }
}


extension AddProductInfoVC: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fields.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FieldCell.reuseID, for: indexPath) as! FieldCell
        let field = fields[indexPath.row]
        cell.configure(label: field.label, value: field.value, placeholder: field.placeholder, keyboardType: field.keyboardType) { [weak self] newValue in
            self?.fields[indexPath.row].value = newValue
        }
        return cell
    }
}


private class FieldCell: UITableViewCell {

    static let reuseID = "fieldCell"

    private let label = UILabel()
    private let textField = UITextField()
    private var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        label.font = .systemFont(ofSize: 16)
        label.setContentHuggingPriority(.required, for: .horizontal)

        textField.textAlignment = .right
        textField.font = .systemFont(ofSize: 16)
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)

        let stack = UIStackView(arrangedSubviews: [label, textField])
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(label: String, value: String, placeholder: String, keyboardType: UIKeyboardType, onChange: @escaping (String) -> Void) {
        self.label.text = label
        self.textField.text = value.isEmpty ? nil : value
        self.textField.keyboardType = keyboardType
        self.textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.placeholderText]
        )
        self.onChange = onChange
    }

    @objc private func textChanged() {
        onChange?(textField.text ?? "")
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}
