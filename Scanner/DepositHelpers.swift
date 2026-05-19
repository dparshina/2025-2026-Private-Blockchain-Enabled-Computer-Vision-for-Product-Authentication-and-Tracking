import UIKit
import BigInt

func weiFromEth(_ amount: Decimal) -> BigUInt? {
    let scaled = NSDecimalNumber(decimal: amount).multiplying(byPowerOf10: 18)
    return BigUInt(scaled.stringValue)
}

func formatWei(_ wei: BigUInt) -> String {
    let decimal = Decimal(string: wei.description) ?? 0
    let eth = decimal / Decimal(1_000_000_000_000_000_000)
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 5
    return formatter.string(from: eth as NSDecimalNumber) ?? "\(eth)"
}

extension UIViewController {
    func presentDepositAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
