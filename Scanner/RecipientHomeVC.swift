import UIKit
import Web3
import BigInt

class RecipientHomeVC: HomeVC {

    private let tableView = UITableView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let footerSpinner = UIActivityIndicatorView(style: .medium)
    private var vm: ProductListViewModel?
    private let estimatedRowHeight: CGFloat = 80
    private var didLoadFirstPage = false

    private var pageLimit: BigUInt {
        let height = tableView.bounds.height
        guard height > 0 else { return 6 }
        let fit = Int(ceil(height / estimatedRowHeight)) + 1
        return BigUInt(max(6, fit))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My products"
        navigationController?.navigationBar.prefersLargeTitles = true
        setupTableView()
        setupScanButton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !didLoadFirstPage, tableView.bounds.height > 0 else { return }
        guard let account = web3.account else { return }
        let vm = ProductListViewModel(source: .user(account), web3: web3)
        vm.onChanged = { [weak self] in self?.handleVMChanged() }
        self.vm = vm
        didLoadFirstPage = true
        vm.loadPage(limit: pageLimit)
    }

    private func handleVMChanged() {
        guard let vm else { return }
        tableView.reloadData()
        if vm.isLoading {
            if vm.offset == 0 { spinner.startAnimating() } else { footerSpinner.startAnimating() }
        } else {
            spinner.stopAnimating()
            footerSpinner.stopAnimating()
        }
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(ProductListCell.self, forCellReuseIdentifier: ProductListCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80

        footerSpinner.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 50)
        footerSpinner.hidesWhenStopped = true
        tableView.tableFooterView = footerSpinner

        view.insertSubview(tableView, at: 0)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
}

extension RecipientHomeVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        vm?.products.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ProductListCell.reuseID, for: indexPath) as! ProductListCell
        if let product = vm?.products[indexPath.row] {
            cell.configure(with: product)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let vm, indexPath.row == vm.products.count - 1, vm.hasMore else { return }
        vm.loadPage(limit: pageLimit)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let vm else { return }
        let vc = ProductInfoCellVC(data: vm.products[indexPath.row])
        vc.role = role
        vc.onStatusChanged = { [weak self] productId, newStatus in
            self?.vm?.updateStatus(productId: productId, newStatus: newStatus)
        }
        navigationController?.pushViewController(vc, animated: true)
    }
}
