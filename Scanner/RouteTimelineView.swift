import UIKit

final class RouteTimelineView: UIView {
    private struct TimelinePoint {
        let location: String
        let timestamp: TimeInterval
        let isDestination: Bool
    }

    private let records: [PathRecord]
    private let destination: String
    private let status: UInt

    init(records: [PathRecord], destination: String, status: UInt) {
        self.records = records
        self.destination = destination
        self.status = status
        super.init(frame: .zero)
        backgroundColor = .clear
        build()
    }
    required init?(coder: NSCoder) {
        fatalError()
    }

    private func build() {
        let points = timelinePoints()
        guard !points.isEmpty
        else {
            return
        }

        let columns = UIStackView()
        columns.axis = .horizontal
        columns.distribution = .fillEqually
        columns.alignment = .top
        columns.translatesAutoresizingMaskIntoConstraints = false
        addSubview(columns)
        NSLayoutConstraint.activate([
            columns.topAnchor.constraint(equalTo: topAnchor),
            columns.bottomAnchor.constraint(equalTo: bottomAnchor),
            columns.leadingAnchor.constraint(equalTo: leadingAnchor),
            columns.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        var dotMarkers: [UIView] = []

        for (idx, point) in points.enumerated() {
            let isLast = idx == points.count - 1
            let isCurrent = isLast && status != 4

            let marker = UIView()
            marker.translatesAutoresizingMaskIntoConstraints = false
            marker.widthAnchor.constraint(equalToConstant: 28).isActive = true
            marker.heightAnchor.constraint(equalToConstant: 28).isActive = true

            if isCurrent {
                let ring = UIView()
                ring.backgroundColor = statusColor.withAlphaComponent(0.22)
                ring.layer.cornerRadius = 14
                ring.translatesAutoresizingMaskIntoConstraints = false
                marker.addSubview(ring)
                NSLayoutConstraint.activate([
                    ring.widthAnchor.constraint(equalToConstant: 28),
                    ring.heightAnchor.constraint(equalToConstant: 28),
                    ring.centerXAnchor.constraint(equalTo: marker.centerXAnchor),
                    ring.centerYAnchor.constraint(equalTo: marker.centerYAnchor)
                ])
            }

            let dot = UIView()
            dot.backgroundColor = isCurrent ? statusColor : .systemGreen
            dot.layer.cornerRadius = 7
            dot.translatesAutoresizingMaskIntoConstraints = false
            marker.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 14),
                dot.heightAnchor.constraint(equalToConstant: 14),
                dot.centerXAnchor.constraint(equalTo: marker.centerXAnchor),
                dot.centerYAnchor.constraint(equalTo: marker.centerYAnchor)
            ])
            dotMarkers.append(marker)

            let markerWrap = UIView()
            markerWrap.translatesAutoresizingMaskIntoConstraints = false
            markerWrap.addSubview(marker)
            NSLayoutConstraint.activate([
                marker.centerXAnchor.constraint(equalTo: markerWrap.centerXAnchor),
                marker.topAnchor.constraint(equalTo: markerWrap.topAnchor),
                marker.bottomAnchor.constraint(equalTo: markerWrap.bottomAnchor),
                markerWrap.heightAnchor.constraint(equalToConstant: 28)
            ])

            let title = UILabel()
            title.text = shortLabel(from: point.location)
            title.font = .systemFont(ofSize: 13, weight: .semibold)
            title.textAlignment = .center
            title.numberOfLines = 1
            title.lineBreakMode = .byTruncatingTail

            let date = UILabel()
            date.text = point.isDestination ? "" : shortDate(point.timestamp)
            date.font = .systemFont(ofSize: 12)
            date.textColor = .secondaryLabel
            date.textAlignment = .center

            let col = UIStackView(arrangedSubviews: [markerWrap, title, date])
            col.axis = .vertical
            col.alignment = .fill
            col.spacing = 4
            columns.addArrangedSubview(col)
        }

        if let first = dotMarkers.first, let last = dotMarkers.last, first !== last {
            let line = UIView()
            line.backgroundColor = .systemBlue.withAlphaComponent(0.6)
            line.translatesAutoresizingMaskIntoConstraints = false
            insertSubview(line, belowSubview: columns)
            NSLayoutConstraint.activate([
                line.heightAnchor.constraint(equalToConstant: 2),
                line.centerYAnchor.constraint(equalTo: first.centerYAnchor),
                line.leadingAnchor.constraint(equalTo: first.centerXAnchor),
                line.trailingAnchor.constraint(equalTo: last.centerXAnchor)
            ])
        }
    }

    private var statusColor: UIColor {
        switch status {
        case 0: return .systemYellow
        case 1: return .systemGray
        case 2: return .systemBlue
        case 3: return .systemMint
        case 4: return .systemGreen
        default: return .systemRed
        }
    }

    private func timelinePoints() -> [TimelinePoint] {
        var points = records.map {
            TimelinePoint(location: $0.location, timestamp: $0.timestamp, isDestination: false)
        }
        if status >= 3 {
            let cleanedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanedDestination.isEmpty, cleanedDestination != "—" {
                points.append(TimelinePoint(location: cleanedDestination, timestamp: 0, isDestination: true))
            }
        }
        return points
    }

    private func shortLabel(from loc: String) -> String {
        let comma = loc.split(separator: ",").first.map(String.init) ?? loc
        let bullet = comma.split(separator: "·").first.map(String.init) ?? comma
        return bullet.trimmingCharacters(in: .whitespaces)
    }

    private func shortDate(_ timestamp: TimeInterval) -> String {
        guard timestamp > 0
        else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}
