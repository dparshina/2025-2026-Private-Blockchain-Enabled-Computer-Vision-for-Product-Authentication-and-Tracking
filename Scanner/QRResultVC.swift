import UIKit
import BigInt

class QRResultVC: UIViewController, UIDocumentPickerDelegate {
    private let qrImage: UIImage
    private let publicKey: String
    private let productId: BigUInt
    private let onSubmitPublicKey: (() async throws -> Void)?
    private var submitButton: UIButton?
    private var didSubmit = false

    init(qrImage: UIImage,
         publicKey: String,
         productId: BigUInt,
         onSubmitPublicKey: (() async throws -> Void)? = nil) {
        self.qrImage = qrImage
        self.publicKey = publicKey
        self.productId = productId
        self.onSubmitPublicKey = onSubmitPublicKey
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Product QR"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(closeTapped)
        )

        let imgView = UIImageView(image: qrImage)
        imgView.contentMode = .scaleAspectFit
        imgView.backgroundColor = .white
        imgView.layer.cornerRadius = 16
        imgView.layer.masksToBounds = true
        imgView.translatesAutoresizingMaskIntoConstraints = false
        imgView.heightAnchor.constraint(equalToConstant: 280).isActive = true

        let saveQR = makeButton(title: "Save QR", icon: "square.and.arrow.down", action: #selector(saveQRTapped))

        let keyHeader = UILabel()
        keyHeader.text = "Public key"
        keyHeader.font = .systemFont(ofSize: 11, weight: .medium)
        keyHeader.textColor = .secondaryLabel

        let keyLabel = UILabel()
        keyLabel.text = publicKey
        keyLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        keyLabel.numberOfLines = 0
        let keyBG = UIView()
        keyBG.backgroundColor = .secondarySystemGroupedBackground
        keyBG.layer.cornerRadius = 12
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        keyBG.addSubview(keyLabel)
        NSLayoutConstraint.activate([
            keyLabel.topAnchor.constraint(equalTo: keyBG.topAnchor, constant: 12),
            keyLabel.bottomAnchor.constraint(equalTo: keyBG.bottomAnchor, constant: -12),
            keyLabel.leadingAnchor.constraint(equalTo: keyBG.leadingAnchor, constant: 12),
            keyLabel.trailingAnchor.constraint(equalTo: keyBG.trailingAnchor, constant: -12)
        ])

        var arranged: [UIView] = [imgView, saveQR, keyHeader, keyBG]
        if onSubmitPublicKey != nil {
            let submit = makeButton(title: "Add public key", icon: "plus", action: #selector(submitPublicKeyTapped))
            submit.backgroundColor = .systemBlue
            submit.setTitleColor(.white, for: .normal)
            submit.setTitleColor(.white.withAlphaComponent(0.6), for: .disabled)
            submit.tintColor = .white
            submitButton = submit
            arranged.append(submit)
        }
        let stack = UIStackView(arrangedSubviews: arranged)
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(20, after: saveQR)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func makeButton(title: String, icon: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = UIColor.tintColor.withAlphaComponent(0.15)
        button.layer.cornerRadius = 14
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func saveQRTapped() {
        guard let png = qrImage.pngData() else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("product-\(productId)-qr.png")
        do {
            try png.write(to: url, options: .atomic)
        } catch {
            return
        }
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func submitPublicKeyTapped() {
        guard let onSubmit = onSubmitPublicKey, !didSubmit
        else {
            return
        }
        submitButton?.isEnabled = false
        let progress = UIAlertController(title: "Sending public key…",
                                         message: "Sign in your wallet to continue",
                                         preferredStyle: .alert)
        present(progress, animated: true)
        Task {
            do {
                try await onSubmit()
                self.didSubmit = true
                progress.dismiss(animated: true) {
                    self.submitButton?.setTitle("Public key added", for: .normal)
                    self.submitButton?.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
                    self.submitButton?.isEnabled = false
                    self.submitButton?.alpha = 0.7
                }
            } catch {
                self.submitButton?.isEnabled = true
                progress.dismiss(animated: true) {
                    let alert = UIAlertController(title: "Couldn't add public key",
                                                  message: error.localizedDescription,
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

}
