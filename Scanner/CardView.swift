import UIKit

class CardView: UIView {

    let mainLabel = UILabel()
    let titleLabel = UILabel()
    let subLabel = UILabel()
    let stack = UIStackView()

    private let shimmerContainer = UIView()
    private let titlePlaceholder = UIView()
    private let mainPlaceholder  = UIView()
    private let subPlaceholder   = UIView()
    private let highlightLayer   = CAGradientLayer()
    private(set) var isShimmering = false

    init(title: String, sub: String = "", main: String, frame: CGRect = .zero) {
        super.init(frame: frame)
        titleLabel.text = title
        subLabel.text = sub
        subLabel.isHidden = sub.isEmpty
        mainLabel.text = main

        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.06
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 5
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.numberOfLines = 1

        mainLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        mainLabel.textColor = .label
        mainLabel.numberOfLines = 0

        subLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        subLabel.textColor = .secondaryLabel
        subLabel.numberOfLines = 0

        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        [titleLabel, mainLabel, subLabel].forEach { stack.addArrangedSubview($0) }

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])

        setupShimmer()
        subPlaceholder.isHidden = subLabel.isHidden
    }

    private func setupShimmer() {
        shimmerContainer.translatesAutoresizingMaskIntoConstraints = false
        shimmerContainer.backgroundColor = .clear
        shimmerContainer.isHidden = true
        shimmerContainer.clipsToBounds = true
        shimmerContainer.layer.cornerRadius = 12
        addSubview(shimmerContainer)

        NSLayoutConstraint.activate([
            shimmerContainer.topAnchor.constraint(equalTo: topAnchor),
            shimmerContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            shimmerContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            shimmerContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let placeholderColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 0.28, alpha: 1)
                : UIColor(white: 0.85, alpha: 1)
        }

        [titlePlaceholder, mainPlaceholder, subPlaceholder].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.backgroundColor = placeholderColor
            $0.layer.cornerRadius = 5
            $0.clipsToBounds = true
            shimmerContainer.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titlePlaceholder.topAnchor.constraint(equalTo: shimmerContainer.topAnchor, constant: 12),
            titlePlaceholder.leadingAnchor.constraint(equalTo: shimmerContainer.leadingAnchor, constant: 12),
            titlePlaceholder.widthAnchor.constraint(equalTo: shimmerContainer.widthAnchor, multiplier: 0.45),
            titlePlaceholder.heightAnchor.constraint(equalToConstant: 8),

            mainPlaceholder.topAnchor.constraint(equalTo: titlePlaceholder.bottomAnchor, constant: 8),
            mainPlaceholder.leadingAnchor.constraint(equalTo: shimmerContainer.leadingAnchor, constant: 12),
            mainPlaceholder.trailingAnchor.constraint(equalTo: shimmerContainer.trailingAnchor, constant: -12),
            mainPlaceholder.heightAnchor.constraint(equalToConstant: 13),

            subPlaceholder.topAnchor.constraint(equalTo: mainPlaceholder.bottomAnchor, constant: 6),
            subPlaceholder.leadingAnchor.constraint(equalTo: shimmerContainer.leadingAnchor, constant: 12),
            subPlaceholder.widthAnchor.constraint(equalTo: shimmerContainer.widthAnchor, multiplier: 0.7),
            subPlaceholder.heightAnchor.constraint(equalToConstant: 8),
            subPlaceholder.bottomAnchor.constraint(lessThanOrEqualTo: shimmerContainer.bottomAnchor, constant: -12)
        ])

        let clear = UIColor.white.withAlphaComponent(0).cgColor
        let bright = UIColor.white.withAlphaComponent(0.55).cgColor
        highlightLayer.colors = [clear, bright, clear]
        highlightLayer.locations = [0.35, 0.5, 0.65]
        highlightLayer.startPoint = CGPoint(x: 0, y: 0.5)
        highlightLayer.endPoint   = CGPoint(x: 1, y: 0.5)
        shimmerContainer.layer.addSublayer(highlightLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlightLayer.frame = shimmerContainer.bounds
        CATransaction.commit()
    }

    func startShimmering() {
        guard !isShimmering else { return }
        isShimmering = true

        stack.isHidden = true
        shimmerContainer.isHidden = false
        bringSubviewToFront(shimmerContainer)

        layoutIfNeeded()
        highlightLayer.frame = shimmerContainer.bounds

        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = [-0.5, -0.25, 0.0]
        anim.toValue   = [1.0, 1.25, 1.5]
        anim.duration  = 1.1
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        highlightLayer.add(anim, forKey: "shimmer")
    }

    func stopShimmering() {
        guard isShimmering else { return }
        isShimmering = false
        highlightLayer.removeAnimation(forKey: "shimmer")
        stack.alpha = 0
        stack.isHidden = false
        UIView.animate(withDuration: 0.25, animations: {
            self.shimmerContainer.alpha = 0
            self.stack.alpha = 1
        }, completion: { _ in
            self.shimmerContainer.isHidden = true
            self.shimmerContainer.alpha = 1
        })
    }
}
