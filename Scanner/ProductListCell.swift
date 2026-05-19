import UIKit

class ProductListCell: UITableViewCell {

    static let reuseID = "productListCell"

    private let nameLabel    = UILabel()
    private let serialLabel  = UILabel()
    private let routeLabel   = UILabel()
    private let massLabel    = UILabel()
    private let statusBadge  = PaddedLabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator

        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.numberOfLines = 1
        nameLabel.textAlignment = .right
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)

        serialLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        serialLabel.textColor = .secondaryLabel

        routeLabel.font = .systemFont(ofSize: 13)
        routeLabel.textColor = .secondaryLabel

        massLabel.font = .systemFont(ofSize: 12)
        massLabel.textColor = .secondaryLabel

        statusBadge.font = .systemFont(ofSize: 11, weight: .medium)
        statusBadge.textAlignment = .center
        statusBadge.layer.cornerRadius = 8
        statusBadge.clipsToBounds = true
        statusBadge.insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)

        let upperRow = UIStackView(arrangedSubviews: [nameLabel, statusBadge])
        upperRow.axis = .horizontal
        upperRow.alignment = .center
        upperRow.distribution = .equalSpacing

        let stack = UIStackView(arrangedSubviews: [upperRow, serialLabel, routeLabel, massLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    func configure(with data: [String: Any]) {
        nameLabel.text = data["name"] as? String ?? "—"
        serialLabel.text = "S/N:  \(data["serialNumber"] as? String ?? "—")"

        let origin = data["origin"] as? String ?? "—"
        let dest   = data["destination"] as? String ?? "—"
        routeLabel.text = "\(origin)  →  \(dest)"

        if let mass = data["mass"] {
            massLabel.text = "\(mass) kg"
        } else {
            massLabel.text = nil
        }

        let statusRaw = data["status"] as? UInt ?? 0
        switch statusRaw {
        case 0: applyStatus("Awaiting", .systemYellow)
        case 1: applyStatus("Initialized", .systemGray)
        case 2: applyStatus("In transit", .systemBlue)
        case 3: applyStatus("Delivered", .systemMint)
        case 4: applyStatus("Received", .systemGreen)
        default: applyStatus("Unknown", .systemRed)
        }
    }

    private func applyStatus(_ text: String, _ color: UIColor) {
        statusBadge.text = text
        statusBadge.textColor = color
        statusBadge.backgroundColor = color.withAlphaComponent(0.12)
    }

    required init?(coder: NSCoder) { fatalError() }
}
