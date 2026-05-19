import UIKit

final class DepositPressableButton: UIButton {
    var onTap: (() -> Void)?
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(handleDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(handleUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func handleDown() {
        UIView.animate(withDuration: 0.12) {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }
    }
    @objc private func handleUp() {
        UIView.animate(withDuration: 0.12) {
            self.transform = .identity
        }
    }
    @objc private func handleTap() {
        haptic.impactOccurred()
        onTap?()
    }
}

final class DepositAmountField: UITextField, UITextFieldDelegate {
    init() {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.cgColor
        tintColor = .systemBlue
        font = .monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        keyboardType = .decimalPad
        returnKeyType = .done
        clearButtonMode = .whileEditing
        placeholder = "0.0000"
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 54).isActive = true

        delegate = self

        let unitLabel = UILabel()
        unitLabel.text = "SEP"
        unitLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        unitLabel.textColor = .secondaryLabel
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 48, height: 24))
        unitLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(unitLabel)
        NSLayoutConstraint.activate([
            unitLabel.topAnchor.constraint(equalTo: container.topAnchor),
            unitLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            unitLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            unitLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        ])
        rightView = container
        rightViewMode = .always
    }
    required init?(coder: NSCoder) { fatalError() }

    var amount: Decimal? {
        guard let raw = text?.replacingOccurrences(of: ",", with: "."),
              !raw.isEmpty,
              let d = Decimal(string: raw),
              d > 0 else { return nil }
        return d
    }

    private let textInsets = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
    override func textRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: textInsets) }
    override func editingRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: textInsets) }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: textInsets) }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        layer.borderColor = UIColor.separator.cgColor
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "0123456789.,")
        if string.rangeOfCharacter(from: allowed.inverted) != nil { return false }
        let next = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        return next.filter { $0 == "." || $0 == "," }.count <= 1
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
