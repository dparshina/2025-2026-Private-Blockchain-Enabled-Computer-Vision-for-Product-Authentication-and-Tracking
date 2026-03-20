import UIKit

class ProductVC: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let verifyButton = UIButton()
    private let nameLabel = UILabel()
    private let originLabel = UILabel()
    private let manufacturerLabel = UILabel()
    private let timestampLabel = UILabel()
    private var lastCard: CardView?
    
    var product: Product
        
    init(product: Product) {
        self.product = product
        super.init(nibName: nil, bundle: nil)
    }
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        configureScroll()
        configureContent()
        setupCards()
        setupButton()
        setupConstraints()
        
    }
}

private extension ProductVC {
    
    @objc func handleVerify() {
        let verifyVC = VerificationVC()
        navigationController?.pushViewController(verifyVC, animated: true)
    }
    
    func setupLayout() {
        configureScroll()
        configureContent()
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
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            
            verifyButton.topAnchor.constraint(equalTo: lastCard!.bottomAnchor, constant: 20),
            verifyButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            verifyButton.heightAnchor.constraint(equalToConstant: 56),
            verifyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            verifyButton.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.9),
            verifyButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    func setupButton(){
        verifyButton.setTitle("Verify", for: .normal)
        verifyButton.tintColor = .white
        verifyButton.backgroundColor = .blue
        verifyButton.layer.cornerRadius = 30
        verifyButton.addTarget(self, action: #selector(handleVerify), for: .touchUpInside)
        verifyButton.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 26.0, *) {
            var config = UIButton.Configuration.glass()
            config.title = "Verify"
            config.baseForegroundColor = .white
            verifyButton.configuration = config
        } else {
            verifyButton.setTitle("Verify", for: .normal)
            verifyButton.tintColor = .white
            verifyButton.backgroundColor = .blue
        }
        scrollView.addSubview(verifyButton)
    }
    
    func setupCards(){
        let nameCard = CardView(title: "Product name", sub: "Registered product", main: product.location)
        let originCard = CardView(title: "Origin", sub: "Country of manufacture", main: product.location)
        let manufacturerCard = CardView(title: "Manufacturer", sub: "Company that manufactures the product", main: product.location)
        
        let idCard = CardView(title: "ID", sub: "Unique identifier", main: String(product.gymid))
        let registeredCard = CardView(title: "Registered", sub: "at 9:41 AM UTC", main: "Feb 20, 2026")
        lastCard = registeredCard
        
        manufacturerCard.mainLabel.font = .systemFont(ofSize: 13, weight: .bold)
        originCard.mainLabel.font = .systemFont(ofSize: 13, weight: .bold)

        [nameCard, idCard, originCard, manufacturerCard, registeredCard].forEach { contentView.addSubview($0)}

        let gap: CGFloat = 12
        let edge: CGFloat = 16
        
        
        [nameCard, originCard, manufacturerCard].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            nameCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            nameCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: edge),
            nameCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -edge),

            idCard.topAnchor.constraint(equalTo: nameCard.bottomAnchor, constant: gap),
            idCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: edge),
            idCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -edge),

            originCard.topAnchor.constraint(equalTo: idCard.bottomAnchor, constant: gap),
            originCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: edge),
            originCard.trailingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: -gap / 2),

            manufacturerCard.topAnchor.constraint(equalTo: idCard.bottomAnchor, constant: gap),
            manufacturerCard.leadingAnchor.constraint(equalTo: contentView.centerXAnchor, constant: gap / 2),
            manufacturerCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -edge),
            manufacturerCard.heightAnchor.constraint(equalTo: originCard.heightAnchor),

            registeredCard.topAnchor.constraint(equalTo: originCard.bottomAnchor, constant: gap),
            registeredCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: edge),
            registeredCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -edge)])
        
    }
    
    
    
}




class CardView: UIView {
    
    let mainLabel = UILabel()
    let titleLabel = UILabel()
    let subLabel = UILabel()
    let stack = UIStackView()
    
    init(title: String, sub: String, main: String, frame: CGRect = .zero) {
        super.init(frame: frame)
        titleLabel.text = title
        subLabel.text = sub
        mainLabel.text = main
        
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }
    
    private func setup() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.numberOfLines = 1
        
        mainLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        mainLabel.textColor = .label
        mainLabel.numberOfLines = 0
        
        subLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subLabel.textColor = .secondaryLabel
        subLabel.numberOfLines = 0
        
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        [titleLabel, mainLabel, subLabel].forEach { stack.addArrangedSubview($0) }
        
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
}
