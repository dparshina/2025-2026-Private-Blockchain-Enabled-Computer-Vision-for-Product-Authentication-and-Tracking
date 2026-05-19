import UIKit

class LogisticsHomeVC: HomeVC {

    private let scrollView = UIScrollView()
    private let content = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Logistics"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemBackground

        buildLayout()
        buildHero()
        buildHowItWorks()
        buildActionTiles()

        setupScanButton()
    }

    private func buildLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -82)
        ])

        content.axis = .vertical
        content.spacing = 24
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }

    private func buildHero() {
        let card = GradientCard()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.heightAnchor.constraint(greaterThanOrEqualToConstant: 132).isActive = true

        let iconBg = UIView()
        iconBg.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        iconBg.layer.cornerRadius = 26
        iconBg.layer.borderWidth = 0.5
        iconBg.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 52).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "shippingbox.fill",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
        ])

        let eyebrow = UILabel()
        eyebrow.text = "Role"
        eyebrow.font = .systemFont(ofSize: 11, weight: .heavy)
        eyebrow.textColor = UIColor.white.withAlphaComponent(0.6)

        let headline = UILabel()
        headline.text = "Logistics operator"
        headline.font = .systemFont(ofSize: 24, weight: .bold)
        headline.textColor = .white

        let textStack = UIStackView(arrangedSubviews: [eyebrow, headline])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [iconBg, textStack])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 16
        row.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -22),
            row.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            row.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 22),
            row.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -22),
        ])

        content.addArrangedSubview(card)
    }

    private func buildHowItWorks() {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = 12

        section.addArrangedSubview(sectionHeader("How it works"))

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0

        stack.addArrangedSubview(step(index: 1, total: 3, icon: "qrcode.viewfinder", title: "Scan a product", subtitle: "Open its record from the QR code."))
        stack.addArrangedSubview(divider())
        stack.addArrangedSubview(step(index: 2, total: 3, icon: "arrow.triangle.swap", title: "Log handoffs and conditions", subtitle: "Record carriers and environmental readings while in transit."))
        stack.addArrangedSubview(divider())
        stack.addArrangedSubview(step(index: 3, total: 3, icon: "checkmark.seal", title: "Confirm delivery", subtitle: "Mark the shipment Delivered when it arrives."))

        let card = roundedCard()
        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
        ])

        section.addArrangedSubview(card)
        content.addArrangedSubview(section)
    }

    private func buildActionTiles() {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = 12

        section.addArrangedSubview(sectionHeader("What you can do"))

        let tiles = UIStackView(arrangedSubviews: [
            actionTile(icon: "checkmark.seal.fill", color: .systemOrange, title: "Mark Delivered",
                       subtitle: "Confirm a shipment reached its destination."),
            actionTile(icon: "mappin.and.ellipse", color: .systemBlue,
                       title: "Log Path",
                       subtitle: "Record handoffs between carriers along the route."),
            actionTile(icon: "thermometer.medium", color: .systemTeal,
                       title: "Log Condition",
                       subtitle: "Attach temperature, humidity, shock, and other readings."),
        ])
        tiles.axis = .vertical
        tiles.spacing = 10
        section.addArrangedSubview(tiles)
        content.addArrangedSubview(section)
    }

    private func sectionHeader(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label

        let wrap = UIStackView(arrangedSubviews: [label])
        wrap.isLayoutMarginsRelativeArrangement = true
        wrap.layoutMargins = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 0)
        return wrap
    }

    private func roundedCard() -> UIView {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 20
        return view
    }

    private func divider() -> UIView {
        let line = UIView()
        line.backgroundColor = .separator.withAlphaComponent(0.4)
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true

        let wrap = UIView()
        wrap.addSubview(line)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 64),
            line.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -16),
            line.topAnchor.constraint(equalTo: wrap.topAnchor),
            line.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
        ])
        return wrap
    }

    private func step(index: Int, total: Int, icon: String, title: String, subtitle: String) -> UIView {
        let iconBg = UIView()
        iconBg.backgroundColor = UIColor.label.withAlphaComponent(0.06)
        iconBg.layer.cornerRadius = 18
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 36).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let img = UIImageView(image: UIImage(systemName: icon))
        img.tintColor = .label
        img.contentMode = .scaleAspectFit
        img.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(img)
        NSLayoutConstraint.activate([
            img.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            img.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            img.widthAnchor.constraint(equalToConstant: 18),
            img.heightAnchor.constraint(equalToConstant: 18),
        ])

        let stepLabel = UILabel()
        stepLabel.text = "STEP \(index) OF \(total)"
        stepLabel.font = .systemFont(ofSize: 10, weight: .heavy)
        stepLabel.textColor = .tertiaryLabel

        let titleL = UILabel()
        titleL.text = title
        titleL.font = .systemFont(ofSize: 15, weight: .semibold)
        titleL.textColor = .label

        let subL = UILabel()
        subL.text = subtitle
        subL.font = .systemFont(ofSize: 13)
        subL.textColor = .secondaryLabel
        subL.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [stepLabel, titleL, subL])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [iconBg, textStack])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 14
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        return row
    }

    private func actionTile(icon: String, color: UIColor, title: String, subtitle: String) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 18
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconBg = UIView()
        iconBg.backgroundColor = color.withAlphaComponent(0.16)
        iconBg.layer.cornerRadius = 14
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 44).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let img = UIImageView(image: UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)))
        img.tintColor = color
        img.contentMode = .scaleAspectFit
        img.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(img)
        NSLayoutConstraint.activate([
            img.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            img.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
        ])

        let titleL = UILabel()
        titleL.text = title
        titleL.font = .systemFont(ofSize: 16, weight: .semibold)
        titleL.textColor = .label

        let subL = UILabel()
        subL.text = subtitle
        subL.font = .systemFont(ofSize: 13)
        subL.textColor = .secondaryLabel
        subL.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleL, subL])
        textStack.axis = .vertical
        textStack.spacing = 2

        let chevron = UIImageView(image: UIImage(systemName: "arrow.up.right",
                                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        chevron.tintColor = .tertiaryLabel
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [iconBg, textStack, chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 14
        row.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
        return card
    }
}

private class GradientCard: UIView {
    private let base = CAGradientLayer()
    private let accent = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 28
        clipsToBounds = true

        base.colors = [
            UIColor(red: 0.07, green: 0.09, blue: 0.18, alpha: 1).cgColor,
            UIColor(red: 0.13, green: 0.18, blue: 0.42, alpha: 1).cgColor
        ]
        base.startPoint = CGPoint(x: 0, y: 0)
        base.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(base, at: 0)

        accent.type = .radial
        accent.colors = [
            UIColor.systemPurple.withAlphaComponent(0.55).cgColor,
            UIColor.systemPurple.withAlphaComponent(0.0).cgColor
        ]
        accent.startPoint = CGPoint(x: 1.05, y: -0.1)
        accent.endPoint = CGPoint(x: 0.3, y: 0.8)
        layer.insertSublayer(accent, above: base)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        base.frame = bounds
        accent.frame = bounds
        CATransaction.commit()
    }
}
