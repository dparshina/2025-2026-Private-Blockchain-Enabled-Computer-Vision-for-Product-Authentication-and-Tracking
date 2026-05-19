import UIKit
import Web3
import BigInt

class AddProductInfoVC: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let addButton = UIButton(type: .system)
    private let vm = AddProductInfoViewModel()

    var onFinished: (() -> Void)?

    private let overlayView = UIView()
    private let overlayBlur: UIBlurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
    private lazy var overlayCard = UIVisualEffectView(effect: overlayBlur)
    private lazy var overlayVibrancy = UIVisualEffectView(
        effect: UIVibrancyEffect(blurEffect: overlayBlur, style: .label)
    )
    private let overlayTint = UIView()
    private let overlayHighlight = CAGradientLayer()
    private let overlaySpinner = UIActivityIndicatorView(style: .medium)
    private let overlayIcon = UIImageView()
    private let overlayTitle = UILabel()
    private let overlaySubtitle = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add product information"
        view.backgroundColor = .systemGroupedBackground
        setupTableView()
        setUpAddition()
        setupOverlay()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange),
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
        tableView.keyboardDismissMode = .interactive
        tableView.contentInset.bottom = 80
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setUpAddition() {
        addButton.setTitle("Add", for: .normal)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.backgroundColor = .systemBlue
        addButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        addButton.setTitleColor(.white, for: .normal)
        addButton.layer.cornerRadius = 14
        view.addSubview(addButton)

        NSLayoutConstraint.activate([
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            addButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            addButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            addButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func setupOverlay() {

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        overlayView.isHidden = true
        overlayView.alpha = 0
        view.addSubview(overlayView)

        overlayCard.translatesAutoresizingMaskIntoConstraints = false
        overlayCard.layer.cornerRadius = 24
        overlayCard.layer.cornerCurve = .continuous
        overlayCard.clipsToBounds = true

        overlayCard.layer.borderWidth = 0.5
        overlayCard.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        overlayView.addSubview(overlayCard)

        overlayTint.translatesAutoresizingMaskIntoConstraints = false
        overlayTint.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        overlayTint.isUserInteractionEnabled = false
        overlayCard.contentView.addSubview(overlayTint)

        overlayHighlight.colors = [
            UIColor.white.withAlphaComponent(0.28).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        overlayHighlight.locations = [0.0, 0.6]
        overlayHighlight.startPoint = CGPoint(x: 0.5, y: 0.0)
        overlayHighlight.endPoint = CGPoint(x: 0.5, y: 1.0)
        overlayCard.contentView.layer.addSublayer(overlayHighlight)

        overlaySpinner.translatesAutoresizingMaskIntoConstraints = false
        overlaySpinner.hidesWhenStopped = true
        overlaySpinner.color = .label

        overlayIcon.translatesAutoresizingMaskIntoConstraints = false
        overlayIcon.contentMode = .scaleAspectFit
        overlayIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40, weight: .regular)
        overlayIcon.tintColor = .systemGreen
        overlayIcon.isHidden = true

        overlayTitle.translatesAutoresizingMaskIntoConstraints = false
        overlayTitle.font = UIFont.preferredFont(forTextStyle: .headline)
        overlayTitle.textColor = .label
        overlayTitle.textAlignment = .center
        overlayTitle.numberOfLines = 0
        overlayTitle.adjustsFontForContentSizeCategory = true

        overlaySubtitle.translatesAutoresizingMaskIntoConstraints = false
        overlaySubtitle.font = UIFont.preferredFont(forTextStyle: .footnote)
        overlaySubtitle.textColor = .secondaryLabel
        overlaySubtitle.textAlignment = .center
        overlaySubtitle.numberOfLines = 0
        overlaySubtitle.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [overlaySpinner, overlayIcon, overlayTitle, overlaySubtitle])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.setCustomSpacing(16, after: overlaySpinner)
        stack.setCustomSpacing(16, after: overlayIcon)
        stack.setCustomSpacing(6, after: overlayTitle)
        overlayCard.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            overlayCard.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            overlayCard.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
            overlayCard.widthAnchor.constraint(equalToConstant: 260),

            overlayTint.topAnchor.constraint(equalTo: overlayCard.contentView.topAnchor),
            overlayTint.bottomAnchor.constraint(equalTo: overlayCard.contentView.bottomAnchor),
            overlayTint.leadingAnchor.constraint(equalTo: overlayCard.contentView.leadingAnchor),
            overlayTint.trailingAnchor.constraint(equalTo: overlayCard.contentView.trailingAnchor),

            stack.topAnchor.constraint(equalTo: overlayCard.contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: overlayCard.contentView.bottomAnchor, constant: -22),
            stack.leadingAnchor.constraint(equalTo: overlayCard.contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: overlayCard.contentView.trailingAnchor, constant: -20),

            overlayIcon.widthAnchor.constraint(equalToConstant: 44),
            overlayIcon.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        overlayHighlight.frame = overlayCard.contentView.bounds
    }

    private func showLoadingOverlay(title: String, subtitle: String) {
        overlayTitle.text = title
        overlaySubtitle.text = subtitle
        overlayIcon.isHidden = true
        overlaySpinner.startAnimating()
        view.endEditing(true)
        addButton.isEnabled = false
        isModalInPresentation = true
        overlayView.isHidden = false
        view.bringSubviewToFront(overlayView)

        overlayCard.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        overlayCard.alpha = 0
        UIView.animate(withDuration: 0.25, delay: 0,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.2,
                       options: [.curveEaseOut, .allowUserInteraction]) {
            self.overlayView.alpha = 1
            self.overlayCard.alpha = 1
            self.overlayCard.transform = .identity
        }
    }

    private func showSuccessOverlay(title: String, subtitle: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        UIView.transition(with: overlayCard.contentView,
                          duration: 0.25,
                          options: [.transitionCrossDissolve, .allowUserInteraction]) {
            self.overlaySpinner.stopAnimating()
            self.overlayIcon.image = UIImage(systemName: "checkmark.circle.fill")
            self.overlayIcon.isHidden = false
            self.overlayTitle.text = title
            self.overlaySubtitle.text = subtitle
        }

        overlayIcon.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        UIView.animate(withDuration: 0.35, delay: 0.05, usingSpringWithDamping: 0.55, initialSpringVelocity: 0.3, options: [.allowUserInteraction]) {
            self.overlayIcon.transform = .identity
        }
    }

    private func hideOverlay() {
        UIView.animate(withDuration: 0.2, animations: {
            self.overlayView.alpha = 0
            self.overlayCard.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }, completion: { _ in
            self.overlayView.isHidden = true
            self.overlayCard.transform = .identity
            self.overlaySpinner.stopAnimating()
            self.addButton.isEnabled = true
            self.isModalInPresentation = false
        })
    }

    @objc private func addTapped() {
        view.endEditing(true)

        showLoadingOverlay(
            title: "Sending transaction…",
            subtitle: "Please confirm in MetaMask, then wait while the network finalises it."
        )

        Task {
            do {
                try await vm.submit()
                showSuccessOverlay(
                    title: "Product added!",
                    subtitle: "It may take a moment to appear in your list while the network confirms the transaction"
                )
                try? await Task.sleep(nanoseconds: 3_800_000_000)
                dismiss(animated: true) { self.onFinished?()
                }
            }
            catch let e as AddProductInfoViewModel.ValidationError {
                hideOverlay()
                presentInlineError(e.errorDescription ?? "Invalid input")
            }
            catch {
                print("=== ERROR ===\nfull: \(error)")
                hideOverlay()
                let alert = UIAlertController(title: "Transaction failed", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }

    private func presentInlineError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func keyboardWillChange(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveRaw = n.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else {
            return
        }

        let endInView = view.convert(frame, from: nil)
        let overlap = max(0, view.bounds.maxY - endInView.minY)

        let inset = overlap > 0 ? overlap + addButton.bounds.height + 24 : 80

        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            self.tableView.contentInset.bottom = inset
            self.tableView.verticalScrollIndicatorInsets.bottom = inset
        })
    }
}

extension AddProductInfoVC: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        vm.fields.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FieldCell.reuseID, for: indexPath) as! FieldCell
        let field = vm.fields[indexPath.row]
        cell.configure(label: field.label,
                       value: field.value,
                       placeholder: field.placeholder,
                       keyboardType: field.keyboardType) { [weak self] newValue in
            self?.vm.updateValue(at: indexPath.row, newValue)
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
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        textField.textAlignment = .right
        textField.font = .systemFont(ofSize: 16)
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        textField.delegate = self
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)

        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        ]
        toolbar.sizeToFit()
        textField.inputAccessoryView = toolbar

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

    func configure(label: String,
                   value: String,
                   placeholder: String,
                   keyboardType: UIKeyboardType,
                   onChange: @escaping (String) -> Void) {
        self.label.text = label
        self.onChange = onChange

        if self.textField.keyboardType != keyboardType {
            self.textField.keyboardType = keyboardType
            if self.textField.isFirstResponder { self.textField.reloadInputViews() }
        }
        if self.textField.placeholder != placeholder {
            self.textField.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: UIColor.placeholderText]
            )
        }
        let current = self.textField.text ?? ""
        if current != value {
            self.textField.text = value.isEmpty ? nil : value
        }
    }

    @objc private func textChanged() {
        onChange?(textField.text ?? "")
    }

    @objc private func dismissKeyboard() {
        textField.resignFirstResponder()
    }

    required init?(coder: NSCoder) { fatalError() }
}

extension FieldCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
