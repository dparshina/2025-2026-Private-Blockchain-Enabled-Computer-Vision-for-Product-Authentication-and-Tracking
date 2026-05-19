import UIKit
import Web3
import BigInt
import QuickLook

class ProductVC: UIViewController {

    private var vm: ProductDetailsViewModel!
    private let initialProductId: BigUInt
    private let initialManufacturerAddress: EthereumAddress

    var role: WalletRole?

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let verifyButton = UIButton()
    private let confirmButton = UIButton(type: .system)
    private let buttonsStack = UIStackView()
    private var lastCard: CardView?
    private var logisticsBarButton: UIBarButtonItem?

    private var nameCard: CardView?
    private var idCard: CardView?
    private var serialCard: CardView?
    private var originCard: CardView?
    private var destinationCard: CardView?
    private var statusCard: CardView?
    private var massCard: CardView?
    private var manufacturerCard: CardView?
    private var recipientCard: CardView?
    private var certificatesCard: CardView?
    private var registeredCard: CardView?

    init(productID: BigUInt, manufacturerCompanyAddress: String) {
        self.initialProductId = productID
        self.initialManufacturerAddress = try! EthereumAddress(hex: manufacturerCompanyAddress, eip55: true)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        vm = ProductDetailsViewModel(productId: initialProductId,
                                     manufacturerAddress: initialManufacturerAddress,
                                     role: role)
        bindViewModel()

        configureScroll()
        configureContent()
        setupCards()
        setupButton()
        setupConstraints()
        setupLogisticsPanelIfNeeded()
        vm.load()
    }

    private let shimmerMinimumDuration: TimeInterval = 1.2
    private var shimmerStartedAt: Date?

    private func bindViewModel() {
        vm.onLoaded = { [weak self] in self?.applyProductAfterShimmer() }
        vm.onStatusChanged = { [weak self] in
            guard let self, let status = self.vm.status else { return }
            self.statusCard?.mainLabel.text = ProductDetailsViewModel.statusName(status)
            self.updateConfirmButtonVisibility()
        }
        vm.onLogisticsAvailabilityChanged = { [weak self] in self?.applyLogisticsAvailability() }
    }
}

private extension ProductVC {

    func updateConfirmButtonVisibility() {
        confirmButton.isHidden = !vm.canConfirmReceipt
    }

    @objc func handleConfirmReceipt() {
        guard vm.canConfirmReceipt else { return }
        confirmButton.isEnabled = false
        let progress = makeProgressAlert(title: "Confirming receipt…",
                                         message: "Sign in your wallet to continue")
        present(progress, animated: true)
        Task {
            do {
                try await vm.confirmReceipt()
                progress.dismiss(animated: true) {
                    self.presentAlert(title: "Receipt confirmed",
                                      message: "It may take a moment to confirm on-chain.")
                }
            } catch {
                confirmButton.isEnabled = true
                progress.dismiss(animated: true) {
                    self.presentAlert(title: "Couldn't confirm receipt",
                                      message: error.localizedDescription)
                }
            }
        }
    }

    @objc func handleVerify() {
        let verifyVC = CameraVC()
        verifyVC.productId = vm.productId
        verifyVC.manufacturerAddress = vm.manufacturerAddress
        verifyVC.onResult = { [weak self] isValid in
            guard let self else { return }
            if self.role == .recipient { return }
            let progress = self.makeProgressAlert(title: "Submitting verification…",
                                                  message: "Sign in your wallet to continue")
            self.present(progress, animated: true)
            Task {
                do {
                    try await self.vm.submitVerification(isValid: isValid)
                    progress.dismiss(animated: true) {
                        self.presentAlert(title: "Verification submitted",
                                          message: "It may take a moment to confirm on-chain.")
                    }
                } catch {
                    progress.dismiss(animated: true) {
                        self.presentAlert(title: "Couldn't submit verification",
                                          message: error.localizedDescription)
                    }
                }
            }
        }
        navigationController?.pushViewController(verifyVC, animated: true)
    }

    func configureScroll() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
    }

    func configureContent() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
    }

    func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),

            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            buttonsStack.topAnchor.constraint(equalTo: lastCard!.bottomAnchor, constant: 20),
            buttonsStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            buttonsStack.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.9),

            verifyButton.heightAnchor.constraint(equalToConstant: 56),
            confirmButton.heightAnchor.constraint(equalToConstant: 56),

            buttonsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    func setupButton() {
        verifyButton.setTitle("Verify", for: .normal)
        verifyButton.setTitleColor(.white, for: .normal)
        verifyButton.tintColor = .white
        verifyButton.backgroundColor = .blue
        verifyButton.layer.cornerRadius = 30
        verifyButton.addTarget(self, action: #selector(handleVerify), for: .touchUpInside)
        verifyButton.translatesAutoresizingMaskIntoConstraints = false

        confirmButton.setTitle("Confirm Receipt", for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        confirmButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
        confirmButton.tintColor = .white
        confirmButton.backgroundColor = .systemBlue
        confirmButton.layer.cornerRadius = 14
        confirmButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        confirmButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.addTarget(self, action: #selector(handleConfirmReceipt), for: .touchUpInside)
        confirmButton.isHidden = true

        buttonsStack.axis = .vertical
        buttonsStack.spacing = 12
        buttonsStack.alignment = .fill
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        buttonsStack.addArrangedSubview(verifyButton)
        buttonsStack.addArrangedSubview(confirmButton)
        contentView.addSubview(buttonsStack)
    }

    func setupLogisticsPanelIfNeeded() {
        guard vm.isLogistics else { return }
        rebuildLogisticsMenu()
    }

    func applyLogisticsAvailability() {
        if vm.pathOrDeliverDone {
            navigationItem.rightBarButtonItem = nil
            logisticsBarButton = nil
            verifyButton.isHidden = true
        } else {
            rebuildLogisticsMenu()
        }
    }

    private func rebuildLogisticsMenu() {
        guard vm.isLogistics else { return }
        var actions: [UIAction] = []

        if !vm.logConditionDone {
            actions.append(UIAction(title: "Log condition",
                                    image: UIImage(systemName: "thermometer.medium")) { [weak self] _ in
                self?.logConditionTapped()
            })
        } else if !vm.pathOrDeliverDone {
            actions.append(UIAction(title: "Log path",
                                    image: UIImage(systemName: "mappin.and.ellipse")) { [weak self] _ in
                self?.logPathTapped()
            })
            actions.append(UIAction(title: "Mark Delivered",
                                    image: UIImage(systemName: "checkmark.seal.fill")) { [weak self] _ in
                self?.markDeliveredTapped()
            })
        }

        guard !actions.isEmpty else {
            navigationItem.rightBarButtonItem = nil
            logisticsBarButton = nil
            return
        }
        let menu = UIMenu(children: actions)
        let item = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)
        navigationItem.rightBarButtonItem = item
        logisticsBarButton = item
    }

    @objc func markDeliveredTapped() {
        let confirm = UIAlertController(title: "Mark as Delivered?",
                                        message: "This records that the shipment reached its destination.",
                                        preferredStyle: .alert)
        confirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        confirm.addAction(UIAlertAction(title: "Confirm", style: .default) { [weak self] _ in
            guard let self else { return }
            let progress = self.makeProgressAlert(title: "Marking Delivered…",
                                                  message: "Sign in your wallet to continue")
            self.present(progress, animated: true)
            Task {
                do {
                    try await self.vm.markDelivered()
                    progress.dismiss(animated: true) {
                        self.presentAlert(title: "Marked Delivered",
                                          message: "It may take a moment to confirm on-chain.")
                    }
                } catch {
                    progress.dismiss(animated: true) {
                        self.presentAlert(title: "Couldn't update status",
                                          message: error.localizedDescription)
                    }
                }
            }
        })
        present(confirm, animated: true)
    }

    @objc func logPathTapped() {
        let alert = UIAlertController(title: "Log path",
                                      message: "Record the next handoff for this shipment.",
                                      preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Next holder address (0x…)" }
        alert.addTextField { $0.placeholder = "Location" }
        alert.addTextField { $0.placeholder = "Note (optional)" }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send", style: .default) { [weak self] _ in
            guard let self else { return }
            let toText = alert.textFields?[0].text ?? ""
            let location = alert.textFields?[1].text ?? ""
            let note = alert.textFields?[2].text ?? ""

            guard (try? EthereumAddress(hex: toText, eip55: false)) != nil else {
                self.presentAlert(title: "Invalid address", message: "Next holder must be a valid 0x address.")
                return
            }
            guard !location.isEmpty else {
                self.presentAlert(title: "Location required", message: "Please provide a location.")
                return
            }

            let progress = self.makeProgressAlert(title: "Logging path…",
                                                  message: "Sign in your wallet to continue")
            self.present(progress, animated: true)
            Task {
                do {
                    try await self.vm.logPath(toAddress: toText, location: location, note: note)
                    progress.dismiss(animated: true) {
                        self.presentAlert(title: "Path logged",
                                          message: "It may take a moment to confirm on-chain.")
                    }
                } catch {
                    progress.dismiss(animated: true) {
                        self.presentAlert(title: "Couldn't log path",
                                          message: error.localizedDescription)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    @objc func logConditionTapped() {
        let vc = LogConditionVC(productId: vm.productId, manufacturerAddress: vm.manufacturerAddress)
        vc.onLogged = { [weak self] in
            self?.vm.markLogConditionDone()
        }
        let navi = UINavigationController(rootViewController: vc)
        if let sheet = navi.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navi, animated: true)
    }

    func makeProgressAlert(title: String, message: String) -> UIAlertController {
        let alert = UIAlertController(title: title, message: "\(message)\n\n", preferredStyle: .alert)
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        alert.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -40)
        ])
        return alert
    }

    func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func applyProductAfterShimmer() {
        let elapsed = shimmerStartedAt.map { Date().timeIntervalSince($0) } ?? shimmerMinimumDuration
        let remaining = max(0, shimmerMinimumDuration - elapsed)
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
            self?.applyProduct()
        }
    }

    func applyProduct() {
        guard let product = vm.product else { return }

        [nameCard, idCard, serialCard, originCard, destinationCard,
         statusCard, massCard, manufacturerCard, recipientCard,
         certificatesCard, registeredCard].forEach { $0?.stopShimmering() }

        nameCard?.mainLabel.text = product.name
        idCard?.mainLabel.text = "\(product.id)"
        serialCard?.mainLabel.text = product.serialNumber
        originCard?.mainLabel.text = product.origin
        destinationCard?.mainLabel.text = product.destination
        manufacturerCard?.mainLabel.text = product.manufacturer
        recipientCard?.mainLabel.text = product.recipient
        massCard?.mainLabel.text = product.mass

        statusCard?.mainLabel.text = ProductDetailsViewModel.statusName(product.status)
        applyLogisticsAvailability()
        updateConfirmButtonVisibility()

        renderCertificateRows(product.certificates)

        if product.timestamp > 0 {
            let date = Date(timeIntervalSince1970: product.timestamp)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a 'UTC'"
            timeFormatter.timeZone = TimeZone(identifier: "UTC")
            registeredCard?.mainLabel.text = dateFormatter.string(from: date) + " at " + timeFormatter.string(from: date)
        }
    }

    func setupCards() {
        let nameCard = CardView(title: "Product name", main: "—")
        let idCard = CardView(title: "ID", main: "\(vm.productId)")
        let serialCard = CardView(title: "Serial", main: "—")
        let originCard = CardView(title: "Origin", main: "—")
        let destinationCard = CardView(title: "Destination", main: "—")
        let statusCard = CardView(title: "Status", main: "—")
        let massCard = CardView(title: "Mass", main: "—")
        let manufacturerCard = CardView(title: "Manufacturer", main: "—")
        let recipientCard = CardView(title: "Recipient", main: "—")
        let certificatesCard = CardView(title: "Certificates", main: "No certificates")
        let registeredCard = CardView(title: "Registered", main: "—")
        lastCard = registeredCard

        self.nameCard = nameCard
        self.idCard = idCard
        self.serialCard = serialCard
        self.originCard = originCard
        self.destinationCard = destinationCard
        self.statusCard = statusCard
        self.massCard = massCard
        self.manufacturerCard = manufacturerCard
        self.recipientCard = recipientCard
        self.certificatesCard = certificatesCard
        self.registeredCard = registeredCard

        manufacturerCard.mainLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        recipientCard.mainLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        certificatesCard.mainLabel.font = .systemFont(ofSize: 12, weight: .regular)
        manufacturerCard.mainLabel.lineBreakMode = .byTruncatingMiddle
        recipientCard.mainLabel.lineBreakMode = .byTruncatingMiddle

        let allCards = [nameCard, idCard, serialCard, originCard, destinationCard,
                        statusCard, massCard, manufacturerCard, recipientCard,
                        certificatesCard, registeredCard]
        allCards.forEach {
            contentView.addSubview($0)
            $0.startShimmering()
        }
        shimmerStartedAt = Date()

        let gap: CGFloat = 8
        let edge: CGFloat = 12

        NSLayoutConstraint.activate([
            nameCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            nameCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: edge),
            nameCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -edge),

            idCard.topAnchor.constraint(equalTo: nameCard.bottomAnchor, constant: gap),
            idCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: edge),
            idCard.trailingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: -gap / 2),

            serialCard.topAnchor.constraint(equalTo: idCard.topAnchor),
            serialCard.leadingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: gap / 2),
            serialCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -edge),
            serialCard.heightAnchor.constraint(equalTo: idCard.heightAnchor),

            originCard.topAnchor.constraint(equalTo: idCard.bottomAnchor, constant: gap),
            originCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: edge),
            originCard.trailingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: -gap / 2),

            destinationCard.topAnchor.constraint(equalTo: originCard.topAnchor),
            destinationCard.leadingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: gap / 2),
            destinationCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -edge),
            destinationCard.heightAnchor.constraint(equalTo: originCard.heightAnchor),

            statusCard.topAnchor.constraint(equalTo: originCard.bottomAnchor, constant: gap),
            statusCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: edge),
            statusCard.trailingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: -gap / 2),

            massCard.topAnchor.constraint(equalTo: statusCard.topAnchor),
            massCard.leadingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: gap / 2),
            massCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -edge),
            massCard.heightAnchor.constraint(equalTo: statusCard.heightAnchor),

            manufacturerCard.topAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: gap),
            manufacturerCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: edge),
            manufacturerCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -edge),

            recipientCard.topAnchor.constraint(equalTo: manufacturerCard.bottomAnchor, constant: gap),
            recipientCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: edge),
            recipientCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -edge),

            certificatesCard.topAnchor.constraint(equalTo: recipientCard.bottomAnchor, constant: gap),
            certificatesCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: edge),
            certificatesCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -edge),

            registeredCard.topAnchor.constraint(equalTo: certificatesCard.bottomAnchor, constant: gap),
            registeredCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: edge),
            registeredCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -edge),
        ])
    }

    func renderCertificateRows(_ urls: [String]) {
        guard let card = certificatesCard else { return }
        card.stack.arrangedSubviews
            .filter { $0 !== card.titleLabel && $0 !== card.mainLabel && $0 !== card.subLabel }
            .forEach { $0.removeFromSuperview() }

        if urls.isEmpty {
            card.mainLabel.isHidden = false
            card.mainLabel.text = "No certificates"
            return
        }
        card.mainLabel.isHidden = true
        for (idx, url) in urls.enumerated() {
            card.stack.addArrangedSubview(makeCertRow(url: url, index: idx))
        }
    }

    func makeCertRow(url: String, index: Int) -> UIView {
        let container = UIControl()
        container.backgroundColor = .tertiarySystemFill
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true

        container.addAction(UIAction { [weak self] _ in
            self?.previewCertificate(url: url)
        }, for: .touchUpInside)
        container.addAction(UIAction { [weak container] _ in
            UIView.animate(withDuration: 0.1) { container?.alpha = 0.6 }
        }, for: [.touchDown, .touchDragEnter])
        container.addAction(UIAction { [weak container] _ in
            UIView.animate(withDuration: 0.15) { container?.alpha = 1 }
        }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        let iconBG = UIView()
        iconBG.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        iconBG.layer.cornerRadius = 8
        iconBG.translatesAutoresizingMaskIntoConstraints = false
        iconBG.isUserInteractionEnabled = false

        let icon = UIImageView(image: UIImage(systemName: "doc.richtext"))
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBG.addSubview(icon)

        let titleLbl = UILabel()
        titleLbl.text = "Certificate \(index + 1)"
        titleLbl.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLbl.textColor = .label

        let cid = Pinata.extractCID(from: url)
        let short = cid.count > 14
            ? String(cid.prefix(6)) + "…" + String(cid.suffix(4))
            : cid
        let ext = (url as NSString).pathExtension.uppercased()
        let kind = ext.isEmpty ? "IPFS" : ext
        let subtitleLbl = UILabel()
        subtitleLbl.text = "\(kind) \(short)"
        subtitleLbl.font = .systemFont(ofSize: 11)
        subtitleLbl.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLbl, subtitleLbl])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.isUserInteractionEnabled = false

        let download = UIButton(type: .system)
        download.setImage(UIImage(systemName: "square.and.arrow.down"), for: .normal)
        download.tintColor = .systemBlue
        download.translatesAutoresizingMaskIntoConstraints = false
        download.addAction(UIAction { [weak self] _ in
            self?.downloadCertificate(url: url)
        }, for: .touchUpInside)

        container.addSubview(iconBG)
        container.addSubview(textStack)
        container.addSubview(download)

        NSLayoutConstraint.activate([
            iconBG.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            iconBG.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconBG.widthAnchor.constraint(equalToConstant: 36),
            iconBG.heightAnchor.constraint(equalToConstant: 36),

            icon.centerXAnchor.constraint(equalTo: iconBG.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBG.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            textStack.leadingAnchor.constraint(equalTo: iconBG.trailingAnchor, constant: 10),
            textStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            download.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            download.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            download.widthAnchor.constraint(equalToConstant: 36),
            download.heightAnchor.constraint(equalToConstant: 36),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: download.leadingAnchor, constant: -8),
        ])
        return container
    }

    func previewCertificate(url: String) {
        let helper = ProductVC.certHelper(for: self)
        if let cached = CertificateCache.existingFile(cid: Pinata.extractCID(from: url)) {
            helper.previewItems = [PreviewItem(url: cached, title: "Certificate")]
            let ql = QLPreviewController()
            ql.dataSource = helper
            present(ql, animated: true)
            return
        }
        let progress = makeProgressAlert(title: "Loading…", message: "")
        present(progress, animated: true)
        Task {
            do {
                let local = try await CertificateCache.file(forCertificate: url)
                await MainActor.run {
                    helper.previewItems = [PreviewItem(url: local, title: "Certificate")]
                    progress.dismiss(animated: true) {
                        let ql = QLPreviewController()
                        ql.dataSource = helper
                        self.present(ql, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    progress.dismiss(animated: true) {
                        self.presentAlert(title: "Couldn't open certificate",
                                          message: error.localizedDescription)
                    }
                }
            }
        }
    }

    func downloadCertificate(url: String) {
        if let cached = CertificateCache.existingFile(cid: Pinata.extractCID(from: url)) {
            let picker = UIDocumentPickerViewController(forExporting: [cached], asCopy: true)
            present(picker, animated: true)
            return
        }
        let progress = makeProgressAlert(title: "Preparing…", message: "")
        present(progress, animated: true)
        Task {
            do {
                let local = try await CertificateCache.file(forCertificate: url)
                await MainActor.run {
                    progress.dismiss(animated: true) {
                        let picker = UIDocumentPickerViewController(forExporting: [local], asCopy: true)
                        self.present(picker, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    progress.dismiss(animated: true) {
                        self.presentAlert(title: "Couldn't download",
                                          message: error.localizedDescription)
                    }
                }
            }
        }
    }

    static func certHelper(for vc: ProductVC) -> ProductVCCertHelper {
        if let existing = objc_getAssociatedObject(vc, &ProductVCCertHelper.key) as? ProductVCCertHelper {
            return existing
        }
        let helper = ProductVCCertHelper()
        objc_setAssociatedObject(vc, &ProductVCCertHelper.key, helper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return helper
    }
}

final class ProductVCCertHelper: NSObject, QLPreviewControllerDataSource {
    static var key: UInt8 = 0
    var previewItems: [PreviewItem] = []
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { previewItems.count }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        previewItems[index]
    }
}
