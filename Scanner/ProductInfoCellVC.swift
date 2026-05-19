import UIKit
import Web3
import BigInt
import UniformTypeIdentifiers
import QuickLook

class ProductInfoCellVC: UIViewController {
    private struct JourneyStop {
        let location: String
        let note: String
        let timestamp: TimeInterval
        let isDestination: Bool
    }

    private var vm: ProductInfoViewModel!
    private let initialData: [String: Any]

    var role: WalletRole?
    var onStatusChanged: ((BigUInt, UInt) -> Void)?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    private var statusBadge: PaddedLabel?
    private var routeContent: UIStackView?
    private var conditionsContent: UIStackView?
    private var journeyContent: UIStackView?
    private var certsHeaderLabel: UILabel?
    private var certsContainer: UIStackView?
    private var qrButton: UIButton?

    init(data: [String: Any]) {
        self.initialData = data
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Shipment"
        navigationItem.largeTitleDisplayMode = .never

        let product = ProductInfo(dict: initialData)
        vm = ProductInfoViewModel(product: product, role: role)
        bindViewModel()

        buildLayout()
        renderSections()
        setupRoleMenu()
        CertificateCache.prefetch(certificateURLs: vm.certificates)
        Task { await vm.load() }
    }

    private func bindViewModel() {
        vm.onProductChanged = {
            [weak self] in
            self?.refreshStatusBadge()
            self?.refreshDynamic()
            if self?.vm.hasPublicKey == true {
                self?.setQRButtonGenerated()
            }
        }
        vm.onPathChanged = {
            [weak self] in self?.refreshDynamic()
        }
        vm.onConditionsChanged = {
            [weak self] in self?.renderConditions()
        }
        vm.onCertificatesChanged = {
            [weak self] in self?.renderCertificates()
        }
        vm.onStatusChanged = {
            [weak self] id, st in self?.onStatusChanged?(id, st)
        }
    }

    private func buildLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    private func renderSections() {
        stack.addArrangedSubview(buildShipmentCard())
        stack.addArrangedSubview(sectionHeader("Details"))
        stack.addArrangedSubview(buildDetailsCard())

        let routeWrap = card(title: "Route")
        routeContent = routeWrap.content
        stack.addArrangedSubview(routeWrap.view)

        stack.addArrangedSubview(sectionHeader("Conditions"))
        let condCol = UIStackView()
        condCol.axis = .vertical
        condCol.spacing = 10
        conditionsContent = condCol
        stack.addArrangedSubview(condCol)

        stack.addArrangedSubview(sectionHeader("Journey"))
        let journeyWrap = card()
        journeyContent = journeyWrap.content
        stack.addArrangedSubview(journeyWrap.view)

        let certHeader = sectionHeader("Certificates (\(vm.certificates.count))")
        certsHeaderLabel = certHeader
        stack.addArrangedSubview(certHeader)
        let certsCard = card()
        certsContainer = certsCard.content
        stack.addArrangedSubview(certsCard.view)

        if vm.canManageCertificates {
            let add = UIButton(type: .system)
            add.setTitle("+ Add certificate", for: .normal)
            add.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            add.setTitleColor(.white, for: .normal)
            add.backgroundColor = .systemBlue
            add.layer.cornerRadius = 12
            add.heightAnchor.constraint(equalToConstant: 44).isActive = true
            add.addTarget(self, action: #selector(pickCertificate), for: .touchUpInside)
            stack.addArrangedSubview(add)
        }

        if vm.role == .manufacturer_emp {
            let button = UIButton(type: .system)
            button.setTitle("Generate QR", for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            button.setImage(UIImage(systemName: "qrcode"), for: .normal)
            button.tintColor = .white
            button.backgroundColor = .systemBlue
            button.layer.cornerRadius = 14
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
            button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
            button.heightAnchor.constraint(equalToConstant: 52).isActive = true
            button.addTarget(self, action: #selector(generateQRTapped), for: .touchUpInside)
            stack.addArrangedSubview(button)
            qrButton = button

            if vm.hasPublicKey { setQRButtonGenerated() }
        }

        renderRoute()
        renderConditions()
        renderJourney()
        renderCertificates()
    }

    private func buildShipmentCard() -> UIView {
        let product = vm.product

        let badge = makeStatusBadge(for: product.status)
        statusBadge = badge

        let titleLabel = UILabel()
        titleLabel.text = "Product name"
        titleLabel.font = .systemFont(ofSize: 11, weight: .regular)
        titleLabel.textColor = .tertiaryLabel

        let nameLabel = UILabel()
        nameLabel.text = product.name
        nameLabel.font = .systemFont(ofSize: 32, weight: .bold)
        nameLabel.numberOfLines = 0

        let nameStack = UIStackView(arrangedSubviews: [titleLabel, nameLabel])
        nameStack.axis = .vertical
        nameStack.spacing = 2

        let topRow = UIStackView(arrangedSubviews: [nameStack, badge])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 8
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)

        let originLabel = headedLine("Origin", product.origin, alignRight: false)
        let destinationLabel = headedLine("Destination", product.destination, alignRight: true)
        let arrowConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        let arrow = UIImageView(image: UIImage(systemName: "arrow.right",
                                               withConfiguration: arrowConfig))
        arrow.tintColor = .secondaryLabel
        arrow.contentMode = .scaleAspectFit

        let routeRow = UIView()
        [originLabel, arrow, destinationLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            routeRow.addSubview($0)
        }
        NSLayoutConstraint.activate([
            originLabel.leadingAnchor.constraint(equalTo: routeRow.leadingAnchor),
            originLabel.topAnchor.constraint(equalTo: routeRow.topAnchor),
            originLabel.bottomAnchor.constraint(equalTo: routeRow.bottomAnchor),
            originLabel.trailingAnchor.constraint(lessThanOrEqualTo: arrow.leadingAnchor, constant: -12),

            destinationLabel.trailingAnchor.constraint(equalTo: routeRow.trailingAnchor),
            destinationLabel.topAnchor.constraint(equalTo: routeRow.topAnchor),
            destinationLabel.bottomAnchor.constraint(equalTo: routeRow.bottomAnchor),
            destinationLabel.leadingAnchor.constraint(greaterThanOrEqualTo: arrow.trailingAnchor, constant: 12),

            arrow.centerXAnchor.constraint(equalTo: routeRow.centerXAnchor),
            arrow.centerYAnchor.constraint(equalTo: routeRow.centerYAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 30),
            arrow.heightAnchor.constraint(equalToConstant: 22)
        ])
        originLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        destinationLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let body = UIStackView(arrangedSubviews: [topRow, routeRow])
        body.axis = .vertical
        body.spacing = 14

        return wrapCard(body, padding: 16)
    }

    private func buildDetailsCard() -> UIView {
        let product = vm.product
        let added = product.timestamp > 0
            ? DateFormatter.localizedString(from: Date(timeIntervalSince1970: product.timestamp), dateStyle: .medium, timeStyle: .none)
            : "—"

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.addArrangedSubview(tileRow([detailTile("Serial number", product.serialNumber, mono: true), detailTile("Mass", product.mass)]))
        stack.addArrangedSubview(tileRow([detailTile("Added", added), detailTile("Product ID", "\(product.id)")]))
        stack.addArrangedSubview(detailTile("Recipient address", product.recipient, mono: true))
        return stack
    }

    private func detailTile(_ label: String, _ value: String, mono: Bool = false) -> UIView {
        let background = UIView()
        background.backgroundColor = .secondarySystemGroupedBackground
        background.layer.cornerRadius = 10

        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 11)
        labelView.textColor = .secondaryLabel

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = mono ? .monospacedSystemFont(ofSize: 12, weight: .regular) : .systemFont(ofSize: 13, weight: .medium)
        valueLabel.textColor = .label
        valueLabel.numberOfLines = 0

        let inner = UIStackView(arrangedSubviews: [labelView, valueLabel])
        inner.axis = .vertical
        inner.spacing = 3
        inner.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: background.topAnchor, constant: 10),
            inner.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -10),
            inner.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 12),
            inner.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -12)
        ])
        return background
    }

    private func tileRow(_ tiles: [UIView]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: tiles)
        row.axis = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually
        return row
    }

    private func headedLine(_ head: String, _ value: String, alignRight: Bool) -> UIView {
        let headLabel = UILabel()
        headLabel.text = head
        headLabel.font = .systemFont(ofSize: 11, weight: .regular)
        headLabel.textColor = .tertiaryLabel
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        valueLabel.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [headLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = alignRight ? .trailing : .leading
        if alignRight {
            headLabel.textAlignment = .right; valueLabel.textAlignment = .right
        }
        return stack
    }

    private func bigStatTile(value: String, label: String) -> (view: UIView, value: UILabel) {
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 26, weight: .bold)
        valueLabel.textAlignment = .center
        let captionLabel = UILabel()
        captionLabel.text = label
        captionLabel.font = .systemFont(ofSize: 13)
        captionLabel.textColor = .secondaryLabel
        captionLabel.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        let background = UIView()
        background.backgroundColor = .tertiarySystemGroupedBackground
        background.layer.cornerRadius = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -8)
        ])
        return (background, valueLabel)
    }

    private func makeStatusBadge(for raw: UInt) -> PaddedLabel {
        let (text, color): (String, UIColor) = switch raw {
        case 0: ("Awaiting", .systemYellow)
        case 1: ("Initiliazed", .systemGray)
        case 2: ("In transit", .systemBlue)
        case 3: ("Delivered", .systemMint)
        case 4: ("Received", .systemGreen)
        default: ("Unknown", .systemRed)
        }
        let badge = PaddedLabel()
        badge.text = "● \(text)"
        badge.font = .systemFont(ofSize: 12, weight: .semibold)
        badge.textColor = color
        badge.backgroundColor = color.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 10
        badge.clipsToBounds = true
        badge.insets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        return badge
    }

    private func refreshStatusBadge() {
        guard let badge = statusBadge else { return }
        let fresh = makeStatusBadge(for: vm.status)
        badge.text = fresh.text
        badge.textColor = fresh.textColor
        badge.backgroundColor = fresh.backgroundColor
    }

    private func renderRoute() {
        guard let content = routeContent else { return }
        content.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if vm.pathRecords.isEmpty && vm.status < 3 {
            content.addArrangedSubview(emptyLabel("No route logged yet"))
            return
        }
        let line = RouteTimelineView(
            records: vm.pathRecords,
            destination: vm.product.destination,
            status: vm.status
        )
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 80).isActive = true
        content.addArrangedSubview(line)
    }

    private func renderConditions() {
        guard let row = conditionsContent else { return }
        row.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let groups = Dictionary(grouping: vm.conditions) { $0.type.lowercased() }
        let keys = groups.keys.sorted()

        if keys.isEmpty {
            row.addArrangedSubview(emptyLabel("No condition logs yet"))
            return
        }
        let metrics = keys.compactMap { key -> (key: String, title: String, color: UIColor, entries: [ConditionRecord])? in
            let entries = (groups[key] ?? []).sorted { $0.timestamp < $1.timestamp }
            guard let displayTitle = entries.first?.type else { return nil }
            return (key, prettyTitle(displayTitle), colorForKey(key), entries)
        }

        for chunkStart in stride(from: 0, to: metrics.count, by: 3) {
            let chunk = Array(metrics[chunkStart..<min(chunkStart + 3, metrics.count)])
            let metricRow = UIStackView()
            metricRow.axis = .horizontal
            metricRow.spacing = 8
            metricRow.alignment = .fill
            metricRow.distribution = .fillEqually
            chunk.forEach {
                metricRow.addArrangedSubview(conditionChip(title: $0.title, color: $0.color, entries: $0.entries))
            }
            if chunk.count < 3 {
                for _ in chunk.count..<3 {
                    let spacer = UIView()
                    spacer.alpha = 0
                    spacer.isUserInteractionEnabled = false
                    metricRow.addArrangedSubview(spacer)
                }
            }
            row.addArrangedSubview(metricRow)
        }
    }

    private func prettyTitle(_ raw: String) -> String {
        let cleaned = raw.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return raw }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }

    private func colorForKey(_ key: String) -> UIColor {
        let palette: [UIColor] = [.systemBlue, .systemOrange, .systemTeal, .systemPurple,
                                  .systemPink, .systemGreen, .systemIndigo, .systemBrown]
        let hash = abs(key.hashValue)
        return palette[hash % palette.count]
    }

    private func conditionChip(title: String, color: UIColor, entries: [ConditionRecord]) -> UIControl {
        let latest = entries.last

        let control = UIControl()
        control.backgroundColor = .secondarySystemGroupedBackground
        control.layer.cornerRadius = 12
        control.translatesAutoresizingMaskIntoConstraints = false
        control.heightAnchor.constraint(greaterThanOrEqualToConstant: 74).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabel
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        let valueLabel = UILabel()
        valueLabel.font = .systemFont(ofSize: 18, weight: .bold)
        valueLabel.textColor = .label
        if let latest {
            let unit = latest.unit.isEmpty ? "" : " \(latest.unit)"
            valueLabel.text = "\(latest.value)\(unit)"
        } else {
            valueLabel.text = "—"
            valueLabel.textColor = .tertiaryLabel
        }
        valueLabel.numberOfLines = 1
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75

        let body = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        body.axis = .vertical
        body.spacing = 5
        body.translatesAutoresizingMaskIntoConstraints = false
        body.isUserInteractionEnabled = false
        control.addSubview(body)
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: control.topAnchor, constant: 12),
            body.bottomAnchor.constraint(equalTo: control.bottomAnchor, constant: -12),
            body.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 12),
            body.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -12)
        ])

        control.layer.borderColor = color.withAlphaComponent(0.18).cgColor
        control.layer.borderWidth = 1

        if entries.count > 1 {
            control.addAction(UIAction { [weak self] _ in
                self?.presentConditionChart(title: title, color: color, entries: entries)
            }, for: .touchUpInside)
        }
        return control
    }

    private func presentConditionChart(title: String, color: UIColor, entries: [ConditionRecord]) {
        guard entries.count > 1 else { return }
        let vc = ConditionChartViewController(title: title, color: color, entries: entries)
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        present(vc, animated: true)
    }

    private func renderJourney() {
        guard let content = journeyContent else { return }
        content.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let stops = journeyStops()
        if stops.isEmpty {
            content.addArrangedSubview(emptyLabel("No path logged yet"))
            return
        }
        for (idx, stop) in stops.enumerated() {
            let isLast = idx == stops.count - 1
            let isCurrentStop = isLast && vm.status != 4
            content.addArrangedSubview(journeyRow(stop: stop, isCurrent: isCurrentStop, isFinalSegment: isLast))
        }
    }

    private func journeyStops() -> [JourneyStop] {
        var stops = vm.pathRecords.map {
            JourneyStop(location: $0.location, note: $0.note, timestamp: $0.timestamp, isDestination: false)
        }
        if vm.status >= 3 {
            let destination = vm.product.destination.trimmingCharacters(in: .whitespacesAndNewlines)
            if !destination.isEmpty, destination != "—" {
                stops.append(JourneyStop(location: destination, note: "Delivered to destination", timestamp: 0, isDestination: true))
            }
        }
        return stops
    }

    private var statusColor: UIColor {
        switch vm.status {
        case 0: return .systemYellow
        case 1: return .systemGray
        case 2: return .systemBlue
        case 3: return .systemMint
        case 4: return .systemGreen
        default: return .systemRed
        }
    }

    private func journeyRow(stop: JourneyStop, isCurrent: Bool, isFinalSegment: Bool) -> UIView {
        let dot = UIView()
        dot.backgroundColor = isCurrent ? statusColor : .systemGreen
        dot.layer.cornerRadius = 6
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 12).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 12).isActive = true

        if isCurrent {
            let ring = UIView()
            ring.layer.borderColor = statusColor.withAlphaComponent(0.25).cgColor
            ring.layer.borderWidth = 6
            ring.layer.cornerRadius = 12
            ring.translatesAutoresizingMaskIntoConstraints = false
            ring.widthAnchor.constraint(equalToConstant: 24).isActive = true
            ring.heightAnchor.constraint(equalToConstant: 24).isActive = true
            ring.addSubview(dot)
            dot.centerXAnchor.constraint(equalTo: ring.centerXAnchor).isActive = true
            dot.centerYAnchor.constraint(equalTo: ring.centerYAnchor).isActive = true
            return makeJourneyContainer(marker: ring, stop: stop, drawConnector: !isFinalSegment)
        }
        return makeJourneyContainer(marker: dot, stop: stop, drawConnector: !isFinalSegment)
    }

    private func makeJourneyContainer(marker: UIView, stop: JourneyStop, drawConnector: Bool) -> UIView {
        let title = UILabel()
        title.text = stop.location.isEmpty ? "—" : stop.location
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.numberOfLines = 0

        let date = UILabel()
        date.text = stop.isDestination ? "" : formatShortDate(stop.timestamp)
        date.font = .systemFont(ofSize: 13)
        date.textColor = .secondaryLabel
        date.setContentHuggingPriority(.required, for: .horizontal)

        let head = UIStackView(arrangedSubviews: [title, date])
        head.axis = .horizontal
        head.alignment = .firstBaseline
        head.spacing = 8

        let note = UILabel()
        note.text = stop.note.isEmpty ? "—" : stop.note
        note.font = .systemFont(ofSize: 13)
        note.textColor = .secondaryLabel
        note.numberOfLines = 0

        let body = UIStackView(arrangedSubviews: [head, note])
        body.axis = .vertical
        body.spacing = 4

        let leftCol = UIView()
        leftCol.translatesAutoresizingMaskIntoConstraints = false
        marker.translatesAutoresizingMaskIntoConstraints = false
        leftCol.addSubview(marker)
        leftCol.widthAnchor.constraint(equalToConstant: 24).isActive = true
        marker.centerXAnchor.constraint(equalTo: leftCol.centerXAnchor).isActive = true
        marker.topAnchor.constraint(equalTo: leftCol.topAnchor, constant: 4).isActive = true

        if drawConnector {
            let line = UIView()
            line.backgroundColor = .separator
            line.translatesAutoresizingMaskIntoConstraints = false
            leftCol.addSubview(line)
            NSLayoutConstraint.activate([
                line.topAnchor.constraint(equalTo: marker.bottomAnchor, constant: 2),
                line.bottomAnchor.constraint(equalTo: leftCol.bottomAnchor),
                line.centerXAnchor.constraint(equalTo: leftCol.centerXAnchor),
                line.widthAnchor.constraint(equalToConstant: 1)
            ])
        }

        body.translatesAutoresizingMaskIntoConstraints = false
        let row = UIView()
        row.addSubview(leftCol)
        row.addSubview(body)
        leftCol.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leftCol.topAnchor.constraint(equalTo: row.topAnchor),
            leftCol.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            leftCol.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            body.topAnchor.constraint(equalTo: row.topAnchor, constant: 2),
            body.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12),
            body.leadingAnchor.constraint(equalTo: leftCol.trailingAnchor, constant: 10),
            body.trailingAnchor.constraint(equalTo: row.trailingAnchor)
        ])
        return row
    }

    private func renderCertificates() {
        guard let container = certsContainer else { return }
        container.arrangedSubviews.forEach { $0.removeFromSuperview() }
        certsHeaderLabel?.text = "Certificates (\(vm.certificates.count))"

        if vm.certificates.isEmpty {
            container.addArrangedSubview(emptyLabel("No certificates added"))
            return
        }
        for (idx, url) in vm.certificates.enumerated() {
            container.addArrangedSubview(certRow(url, index: idx))
        }
    }

    private func certRow(_ url: String, index: Int) -> UIView {
        let container = UIControl()
        container.backgroundColor = .tertiarySystemFill
        container.layer.cornerRadius = 14
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true

        container.addAction(UIAction { [weak self] _ in
            self?.previewCertificate(url: url)
        }, for: .touchUpInside)

        container.addAction(UIAction {
            [weak container] _ in
            UIView.animate(withDuration: 0.1) {
                container?.alpha = 0.6
            }
        }, for: [.touchDown, .touchDragEnter])

        container.addAction(UIAction {
            [weak container] _ in
            UIView.animate(withDuration: 0.15){
                container?.alpha = 1
            }
        }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        let iconBG = UIView()
        iconBG.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        iconBG.layer.cornerRadius = 10
        iconBG.translatesAutoresizingMaskIntoConstraints = false
        iconBG.isUserInteractionEnabled = false

        let icon = UIImageView(image: UIImage(systemName: "doc.richtext"))
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBG.addSubview(icon)

        let titleLbl = UILabel()
        titleLbl.text = "Certificate \(index + 1)"
        titleLbl.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLbl.textColor = .label

        let cid = Pinata.extractCID(from: url)
        let short = cid.count > 14
            ? String(cid.prefix(6)) + "…" + String(cid.suffix(4))
            : cid
        let ext = (url as NSString).pathExtension.uppercased()
        let kind = ext.isEmpty ? "IPFS" : ext
        let subtitleLbl = UILabel()
        subtitleLbl.text = "\(kind) \(short)"
        subtitleLbl.font = .systemFont(ofSize: 12)
        subtitleLbl.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLbl, subtitleLbl])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.isUserInteractionEnabled = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.isUserInteractionEnabled = false

        container.addSubview(iconBG)
        container.addSubview(textStack)
        container.addSubview(chevron)

        NSLayoutConstraint.activate([
            iconBG.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            iconBG.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconBG.widthAnchor.constraint(equalToConstant: 40),
            iconBG.heightAnchor.constraint(equalToConstant: 40),

            icon.centerXAnchor.constraint(equalTo: iconBG.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBG.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

            textStack.leadingAnchor.constraint(equalTo: iconBG.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            chevron.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 8),
            chevron.heightAnchor.constraint(equalToConstant: 14),
        ])

        chevron.isHidden = true

        let download = UIButton(type: .system)
        download.setImage(UIImage(systemName: "square.and.arrow.down"), for: .normal)
        download.tintColor = .systemBlue
        download.translatesAutoresizingMaskIntoConstraints = false
        download.addAction(UIAction { [weak self] _ in
            self?.downloadCertificate(url: url)
        }, for: .touchUpInside)
        container.addSubview(download)

        if vm.canManageCertificates {
            let del = UIButton(type: .system)
            del.setImage(UIImage(systemName: "trash"), for: .normal)
            del.tintColor = .systemRed
            del.translatesAutoresizingMaskIntoConstraints = false
            del.addAction(UIAction { [weak self] _ in
                self?.confirmDeleteCertificate(at: index)
            }, for: .touchUpInside)
            container.addSubview(del)
            NSLayoutConstraint.activate([
                del.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
                del.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                del.widthAnchor.constraint(equalToConstant: 36),
                del.heightAnchor.constraint(equalToConstant: 36),
                download.trailingAnchor.constraint(equalTo: del.leadingAnchor, constant: -2),
                download.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                download.widthAnchor.constraint(equalToConstant: 36),
                download.heightAnchor.constraint(equalToConstant: 36),
                textStack.trailingAnchor.constraint(lessThanOrEqualTo: download.leadingAnchor, constant: -8),
            ])
        } else {
            NSLayoutConstraint.activate([
                download.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
                download.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                download.widthAnchor.constraint(equalToConstant: 36),
                download.heightAnchor.constraint(equalToConstant: 36),
                textStack.trailingAnchor.constraint(lessThanOrEqualTo: download.leadingAnchor, constant: -8),
            ])
        }

        return container
    }

    private func downloadCertificate(url: String) {
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

    private func setupRoleMenu() {
        var actions: [UIAction] = []

        if vm.role == .manufacturer_admin {
            if vm.status == 1 {
                actions.append(UIAction(title: "Update status", image: UIImage(systemName: "arrow.up.circle")) { [weak self] _ in
                    self?.changeStatusTapped()
                })
            }
            if vm.status == 2, vm.pathRecords.isEmpty {
                actions.append(UIAction(title: "Log path", image: UIImage(systemName: "mappin.and.ellipse")) { [weak self] _ in
                    self?.logPathTapped()
                })
            }
        }

        guard !actions.isEmpty else {
            navigationItem.rightBarButtonItem = nil
            return
        }
        let menu = UIMenu(children: actions)
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)
    }

    private func refreshDynamic() {
        renderRoute()
        renderJourney()
        setupRoleMenu()
    }

    private func changeStatusTapped() {
        let progress = makeProgressAlert(title: "Updating status…",
                                         message: "Sign in your wallet to continue")
        present(progress, animated: true)
        Task {
            do {
                try await vm.changeStatus()
                progress.dismiss(animated: true)
            } catch {
                progress.dismiss(animated: true) {
                    self.presentAlert(title: "Couldn't update status", message: error.localizedDescription)
                }
            }
        }
    }

    private func logPathTapped() {
        let alert = UIAlertController(title: "Log path",
                                      message: "Enter the recipient address, location, and an optional note.",
                                      preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "0x…" }
        alert.addTextField { $0.placeholder = "Location" }
        alert.addTextField { $0.placeholder = "Note" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send", style: .default) { [weak self] _ in
            guard let self else { return }
            let toText = alert.textFields?[0].text ?? ""
            let location = alert.textFields?[1].text ?? ""
            let note = alert.textFields?[2].text ?? ""
            guard (try? EthereumAddress(hex: toText, eip55: false)) != nil else {
                self.presentAlert(title: "Invalid address", message: "Recipient must be a valid 0x address.")
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
                    progress.dismiss(animated: true)
                } catch {
                    progress.dismiss(animated: true) {
                        self.presentAlert(title: "Couldn't log path", message: error.localizedDescription)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    @objc private func generateQRTapped() {
        guard qrButton?.isEnabled != false else { return }
        qrButton?.isEnabled = false

        let progress = makeProgressAlert(title: "Generating QR…", message: "Sign in your wallet to continue")
        present(progress, animated: true)
        Task {
            do {
                let (image, pubKey) = try await vm.generateQR()
                progress.dismiss(animated: true) {
                    let vc = QRResultVC(
                        qrImage: image,
                        publicKey: pubKey,
                        productId: self.vm.productId,
                        onSubmitPublicKey: { [weak self] in
                            try await self?.vm.submitPublicKey(pubKey)
                        }
                    )
                    let nav = UINavigationController(rootViewController: vc)
                    self.present(nav, animated: true)
                }
            } catch {
                self.qrButton?.isEnabled = true
                progress.dismiss(animated: true) {
                    self.presentAlert(title: "Couldn't generate QR", message: error.localizedDescription)
                }
            }
        }
    }

    private func setQRButtonGenerated() {
        guard let button = qrButton else { return }
        button.isEnabled = false
        button.setTitle("QR is generated", for: .normal)
        button.setImage(UIImage(systemName: "checkmark.seal.fill"), for: .normal)
        button.backgroundColor = .systemGray
    }

    @objc private func pickCertificate() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .png, .jpeg], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func uploadAndRegister(data fileData: Data, filename: String, mime: String) {
        let progress = makeProgressAlert(title: "Uploading certificate", message: "Please wait…")
        present(progress, animated: true)
        Task {
            defer { Task { @MainActor in progress.dismiss(animated: true) } }
            do {
                try await vm.uploadCertificate(data: fileData, filename: filename, mime: mime)
            } catch {
                presentAlert(title: "Couldn't add certificate", message: error.localizedDescription)
            }
        }
    }

    private func confirmDeleteCertificate(at index: Int) {
        guard index < vm.certificates.count else { return }
        let alert = UIAlertController(title: "Delete certificate",
                                      message: "This will remove it from the product and unpin the file. Continue?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteCertificate(at: index)
        })
        present(alert, animated: true)
    }

    private func deleteCertificate(at index: Int) {
        let progress = makeProgressAlert(title: "Deleting certificate", message: "Please wait…")
        present(progress, animated: true)
        Task {
            defer { Task { @MainActor in progress.dismiss(animated: true) } }
            do {
                try await vm.deleteCertificate(at: index)
            } catch {
                presentAlert(title: "Couldn't delete certificate", message: error.localizedDescription)
            }
        }
    }

    private var previewItems: [PreviewItem] = []

    private func previewCertificate(url: String) {
        if let cached = CertificateCache.existingFile(cid: Pinata.extractCID(from: url)) {
            self.previewItems = [PreviewItem(url: cached, title: "Certificate")]
            let ql = QLPreviewController()
            ql.dataSource = self
            present(ql, animated: true)
            return
        }

        let progress = makeProgressAlert(title: "Loading…", message: "")
        present(progress, animated: true)

        Task {
            do {
                let local = try await CertificateCache.file(forCertificate: url)
                await MainActor.run {
                    self.previewItems = [PreviewItem(url: local, title: "Certificate")]
                    progress.dismiss(animated: true) {
                        let ql = QLPreviewController()
                        ql.dataSource = self
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

    private func card(title: String? = nil) -> (view: UIView, content: UIStackView) {
        let background = UIView()
        background.backgroundColor = .secondarySystemGroupedBackground
        background.layer.cornerRadius = 16

        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 10
        content.translatesAutoresizingMaskIntoConstraints = false

        if let title {
            let header = UILabel()
            header.text = title
            header.font = .systemFont(ofSize: 11, weight: .medium)
            header.textColor = .secondaryLabel
            content.addArrangedSubview(header)
        }
        background.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: background.topAnchor, constant: 14),
            content.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -14),
            content.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16)
        ])
        return (background, content)
    }

    private func wrapCard(_ inner: UIView, padding: CGFloat) -> UIView {
        let background = UIView()
        background.backgroundColor = .secondarySystemGroupedBackground
        background.layer.cornerRadius = 16
        inner.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: background.topAnchor, constant: padding),
            inner.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -padding),
            inner.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: padding),
            inner.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -padding)
        ])
        return background
    }

    private func sectionHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }

    private func emptyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13)
        label.textColor = .tertiaryLabel
        return label
    }

    private func formatShortDate(_ timestamp: TimeInterval) -> String {
        guard timestamp > 0 else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func makeProgressAlert(title: String, message: String) -> UIAlertController {
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
}

extension ProductInfoCellVC: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            presentAlert(title: "Couldn't read file", message: "Try another file.")
            return
        }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        uploadAndRegister(data: data, filename: url.lastPathComponent, mime: mime)
    }
}

extension ProductInfoCellVC: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        previewItems.count
    }
    func previewController(_ controller: QLPreviewController,
                           previewItemAt index: Int) -> QLPreviewItem {
        previewItems[index]
    }
}

final class ConditionChartViewController: UIViewController {
    private let chartTitle: String
    private let color: UIColor
    private let entries: [ConditionRecord]

    init(title: String, color: UIColor, entries: [ConditionRecord]) {
        self.chartTitle = title
        self.color = color
        self.entries = entries.sorted { $0.timestamp < $1.timestamp }
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = chartTitle
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.numberOfLines = 1

        let subtitleLabel = UILabel()
        subtitleLabel.text = latestText()
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 1

        let sparkline = SparklineView()
        sparkline.lineColor = color
        sparkline.values = entries.map { CGFloat(Double($0.value)) }
        sparkline.translatesAutoresizingMaskIntoConstraints = false
        sparkline.heightAnchor.constraint(equalToConstant: 180).isActive = true

        let rangeLabel = UILabel()
        rangeLabel.text = rangeText()
        rangeLabel.font = .systemFont(ofSize: 12)
        rangeLabel.textColor = .tertiaryLabel
        rangeLabel.numberOfLines = 1

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, sparkline, rangeLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func latestText() -> String {
        guard let latest = entries.last else { return "" }
        let unit = latest.unit.isEmpty ? "" : " \(latest.unit)"
        return "Latest: \(latest.value)\(unit)"
    }

    private func rangeText() -> String {
        guard let first = entries.first, let last = entries.last else { return "" }
        return "\(formatDate(first.timestamp)) - \(formatDate(last.timestamp)) · \(entries.count) readings"
    }

    private func formatDate(_ timestamp: TimeInterval) -> String {
        guard timestamp > 0 else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}
