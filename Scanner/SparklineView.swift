import UIKit

final class SparklineView: UIView {
    var values: [CGFloat] = [] { didSet { setNeedsDisplay() } }
    var lineColor: UIColor = .systemBlue { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard values.count >= 2,
              let ctx = UIGraphicsGetCurrentContext() else { return }

        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let range = max(maxV - minV, 0.0001)
        let stepX = rect.width / CGFloat(values.count - 1)
        let bottomPad: CGFloat = 2
        let topPad: CGFloat = 2
        let usableH = rect.height - topPad - bottomPad

        let path = UIBezierPath()
        for (i, v) in values.enumerated() {
            let x = CGFloat(i) * stepX
            let y = rect.height - bottomPad - ((v - minV) / range) * usableH
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else      { path.addLine(to: CGPoint(x: x, y: y)) }
        }

        let fill = path.copy() as! UIBezierPath
        fill.addLine(to: CGPoint(x: rect.width, y: rect.height))
        fill.addLine(to: CGPoint(x: 0, y: rect.height))
        fill.close()

        ctx.saveGState()
        fill.addClip()
        let colors = [lineColor.withAlphaComponent(0.25).cgColor, lineColor.withAlphaComponent(0.0).cgColor] as CFArray
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: rect.height), options: [])
        }
        ctx.restoreGState()

        lineColor.setStroke()
        path.lineWidth = 1.5
        path.lineJoinStyle = .round
        path.stroke()
    }
}
