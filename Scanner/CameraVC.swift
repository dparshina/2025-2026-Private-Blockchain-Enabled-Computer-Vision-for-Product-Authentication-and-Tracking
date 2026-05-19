import UIKit
import AVFoundation
import Web3
import BigInt

class CameraVC: UIViewController {

    var productId: BigUInt?
    var manufacturerAddress: EthereumAddress?
    var onResult: ((Bool) -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var camera: CameraController?
    private var lastZoomFactor: CGFloat = 1.0
    private var isSending = false

    private let qrOverlayLayer = CAShapeLayer()
    private var qrHideTimer: Timer?
    private var lastQRString: String?

    private let metadataQueue   = DispatchQueue(label: "cameravc.metadata")
    private let cameraConfigQueue = DispatchQueue(label: "cameravc.config")
    private let saveQueue       = DispatchQueue(label: "cameravc.save", qos: .userInitiated)
    private var capturedScreenSize: CGSize = .zero
    private var capturedFramingRect: CGRect = .zero

    private let loadingOverlay = UIView()
    private let loadingCard = UIView()
    private let loadingSpinner = UIActivityIndicatorView(style: .large)
    private let loadingLabel = UILabel()
    private var loadingCardCenterX: NSLayoutConstraint?
    private var loadingCardCenterY: NSLayoutConstraint?

    private let framingLayer    = CAShapeLayer()
    private let maskOverlayView = UIView()
    private let dimView         = UIView()
    private let framingHintLabel = UILabel()
    private var framingRect: CGRect = .zero
    private var isQRInsideFrame = false {
        didSet {
            guard isQRInsideFrame != oldValue else { return }
            updateFramingAppearance(detected: isQRInsideFrame)
        }
    }

    private let controlsContainer = UIView()
    private let captureButton     = UIButton(type: .custom)

    private let zoomSlider    = UISlider()

    private let zoomLabel    = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupPreview()
        setupQROverlay()
        setupBlurMask()
        setupFramingSquare()
        setupControlsUI()
        setupActionButtons()
        setupGestures()
        setupLoadingOverlay()

        cameraConfigQueue.async { [weak self] in
            guard let self = self else { return }
            self.setupSession()
            self.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        let session = self.session
        cameraConfigQueue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame  = view.bounds
        qrOverlayLayer.frame = view.bounds
        framingLayer.frame   = view.bounds
        dimView.frame        = view.bounds
        maskOverlayView.frame = view.bounds
        updateFramingRect()
        loadingCardCenterX?.constant = framingRect.midX
        loadingCardCenterY?.constant = framingRect.midY
        view.bringSubviewToFront(controlsContainer)
        view.bringSubviewToFront(captureButton)
        view.bringSubviewToFront(framingHintLabel)
    }

    private func setupBlurMask() {
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        view.addSubview(dimView)
    }

    private func applyBlurMask() {
        let fullPath = UIBezierPath(rect: dimView.bounds)
        let holePath = UIBezierPath(rect: framingRect)
        fullPath.append(holePath)
        fullPath.usesEvenOddFillRule = true

        let maskLayer = CAShapeLayer()
        maskLayer.frame = dimView.bounds
        maskLayer.path = fullPath.cgPath
        maskLayer.fillRule = .evenOdd
        maskLayer.fillColor = UIColor.black.cgColor
        dimView.layer.mask = maskLayer
    }

    private func setupFramingSquare() {
        framingLayer.fillColor   = UIColor.clear.cgColor
        framingLayer.strokeColor = UIColor.white.cgColor
        framingLayer.lineWidth   = 2.5
        framingLayer.lineCap     = .round
        view.layer.addSublayer(framingLayer)

        framingHintLabel.text          = "Align QR within frame"
        framingHintLabel.textColor     = .white
        framingHintLabel.font          = .systemFont(ofSize: 13, weight: .medium)
        framingHintLabel.textAlignment = .center
        framingHintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(framingHintLabel)

        NSLayoutConstraint.activate([
            framingHintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            framingHintLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
    }

    private func updateFramingRect() {
        let side = min(view.bounds.width, view.bounds.height) * 0.6
        let cx   = view.bounds.midX
        let cy   = view.bounds.height * 0.42
        framingRect = CGRect(x: cx - side / 2, y: cy - side / 2, width: side, height: side)
        framingLayer.path = cornerPath(for: framingRect, length: 28)
        applyBlurMask()
    }

    private func updateFramingAppearance(detected: Bool) {
        let color = detected ? UIColor.systemGreen.cgColor : UIColor.white.cgColor
        let anim = CABasicAnimation(keyPath: "strokeColor")
        anim.fromValue = framingLayer.strokeColor
        anim.toValue   = color
        anim.duration  = 0.2
        framingLayer.add(anim, forKey: "colorChange")
        framingLayer.strokeColor = color

        framingHintLabel.text = detected ? "QR detected — ready to capture" : "Align QR within frame"
        UIView.transition(with: framingHintLabel, duration: 0.2, options: .transitionCrossDissolve, animations: nil)
    }

    private func isRect(_ qrRect: CGRect, insideFrame frame: CGRect) -> Bool {
        let intersection = qrRect.intersection(frame)
        guard !intersection.isNull else { return false }
        let qrArea = qrRect.width * qrRect.height
        guard qrArea > 0 else { return false }
        return (intersection.width * intersection.height) / qrArea >= 0.70
    }

    private func setupSession() {
        session.sessionPreset = .photo
        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        let controller = CameraController(device: cam)
        camera = controller

        guard let input = try? AVCaptureDeviceInput(device: cam) else { return }
        if session.canAddInput(input)  { session.addInput(input) }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
            if #available(iOS 16.0, *) {
                photoOutput.maxPhotoDimensions = cam.activeFormat.supportedMaxPhotoDimensions.last ?? photoOutput.maxPhotoDimensions
            }
        }

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)
            if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
                metadataOutput.metadataObjectTypes = [.qr]
            }
        }

        controller.configureDefaults()
    }

    private func setupPreview() {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    private func setupQROverlay() {
        qrOverlayLayer.frame       = view.bounds
        qrOverlayLayer.fillColor   = UIColor.clear.cgColor
        qrOverlayLayer.strokeColor = UIColor.white.cgColor
        qrOverlayLayer.lineWidth   = 3
        qrOverlayLayer.lineCap     = .round
        qrOverlayLayer.opacity     = 0
        view.layer.addSublayer(qrOverlayLayer)
    }

    private func cornerPath(for rect: CGRect, length: CGFloat = 20) -> CGPath {
        let path = UIBezierPath()
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (rect.origin,                                  1,  1),
            (CGPoint(x: rect.maxX, y: rect.minY),        -1,  1),
            (CGPoint(x: rect.minX, y: rect.maxY),         1, -1),
            (CGPoint(x: rect.maxX, y: rect.maxY),        -1, -1),
        ]
        for (origin, dx, dy) in corners {
            path.move(to: CGPoint(x: origin.x + length * dx, y: origin.y))
            path.addLine(to: origin)
            path.addLine(to: CGPoint(x: origin.x, y: origin.y + length * dy))
        }
        return path.cgPath
    }

    private func showQROverlay(for rect: CGRect, string: String?) {
        qrOverlayLayer.path = cornerPath(for: rect.insetBy(dx: -8, dy: -8))

        if qrOverlayLayer.opacity == 0 {
            let anim = CABasicAnimation(keyPath: "opacity")
            anim.fromValue = 0; anim.toValue = 1; anim.duration = 0.15
            qrOverlayLayer.add(anim, forKey: "fadeIn")
            qrOverlayLayer.opacity = 1
        }

        if let s = string, s != lastQRString {
            lastQRString = s
            DispatchQueue.main.async { self.showBanner(text: "QR: \(s.prefix(40))") }
        }

        qrHideTimer?.invalidate()
        qrHideTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.hideQROverlay()
            self?.isQRInsideFrame = false
        }
    }

    private func hideQROverlay() {
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1; anim.toValue = 0; anim.duration = 0.25
        qrOverlayLayer.add(anim, forKey: "fadeOut")
        qrOverlayLayer.opacity = 0
        lastQRString = nil
    }

    private func setupControlsUI() {
        controlsContainer.backgroundColor    = UIColor.black.withAlphaComponent(0.6)
        controlsContainer.layer.cornerRadius = 16
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsContainer)

        NSLayoutConstraint.activate([
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100)
        ])

        let stack = UIStackView()
        stack.axis    = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -14)
        ])

        stack.addArrangedSubview(makeRow(icon: "magnifyingglass", label: zoomLabel,slider: zoomSlider,min: 1, max: 15, initial: 1,        action: #selector(zoomChanged)))

        updateLabels()
    }

    private func setupActionButtons() {
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.backgroundColor    = .white
        captureButton.layer.cornerRadius = 36
        captureButton.layer.borderWidth  = 4
        captureButton.layer.borderColor  = UIColor.lightGray.cgColor
        captureButton.addTarget(self, action: #selector(captureSinglePhoto), for: .touchUpInside)
        view.addSubview(captureButton)

        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            captureButton.widthAnchor.constraint(equalToConstant: 72),
            captureButton.heightAnchor.constraint(equalToConstant: 72),
        ])
    }

    private func makeRow(icon: String, label: UILabel, slider: UISlider,
                         min: Float, max: Float, initial: Float, action: Selector) -> UIStackView {
        let row = UIStackView()
        row.axis      = .horizontal
        row.spacing   = 10
        row.alignment = .center

        let img = UIImageView(image: UIImage(systemName: icon) ?? UIImage())
        img.tintColor    = .white
        img.contentMode  = .scaleAspectFit
        img.widthAnchor.constraint(equalToConstant: 22).isActive  = true
        img.heightAnchor.constraint(equalToConstant: 22).isActive = true

        slider.minimumValue = min
        slider.maximumValue = max
        slider.value        = initial
        slider.tintColor    = .white
        slider.addTarget(self, action: action, for: .valueChanged)

        label.font          = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        label.textColor     = .white
        label.textAlignment = .right
        label.widthAnchor.constraint(equalToConstant: 80).isActive = true

        row.addArrangedSubview(img)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(label)
        return row
    }

    @objc private func zoomChanged() {
        let factor = CGFloat(zoomSlider.value)
        zoomLabel.text = String(format: "%.1f×", factor)
        cameraConfigQueue.async { [weak self] in self?.camera?.setZoom(factor) }
    }

    @objc private func captureSinglePhoto() {
        guard !isSending
        else {
            return
        }
        isSending = true
        showLoading(true)
        animateCaptureButton()
        captureActualPhoto()
    }

    private func setupLoadingOverlay() {
        loadingOverlay.backgroundColor = .clear
        loadingOverlay.isHidden = true
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.isUserInteractionEnabled = false
        view.addSubview(loadingOverlay)

        loadingCard.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        loadingCard.layer.cornerRadius = 14
        loadingCard.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.addSubview(loadingCard)

        loadingSpinner.color = .white
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingCard.addSubview(loadingSpinner)

        loadingLabel.text = "Verifying…"
        loadingLabel.textColor = .white
        loadingLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingCard.addSubview(loadingLabel)

        let cx = loadingCard.centerXAnchor.constraint(equalTo: view.leadingAnchor)
        let cy = loadingCard.centerYAnchor.constraint(equalTo: view.topAnchor)
        loadingCardCenterX = cx
        loadingCardCenterY = cy

        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            cx, cy,

            loadingSpinner.centerXAnchor.constraint(equalTo: loadingCard.centerXAnchor),
            loadingSpinner.topAnchor.constraint(equalTo: loadingCard.topAnchor, constant: 16),

            loadingLabel.centerXAnchor.constraint(equalTo: loadingCard.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: loadingSpinner.bottomAnchor, constant: 10),
            loadingLabel.bottomAnchor.constraint(equalTo: loadingCard.bottomAnchor, constant: -14),
            loadingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: loadingCard.leadingAnchor, constant: 18),
            loadingLabel.trailingAnchor.constraint(lessThanOrEqualTo: loadingCard.trailingAnchor, constant: -18),
        ])
    }

    private func showLoading(_ on: Bool) {
        isSending = on
        loadingOverlay.isHidden = !on
        view.bringSubviewToFront(loadingOverlay)
        on ? loadingSpinner.startAnimating() : loadingSpinner.stopAnimating()
        captureButton.isEnabled = !on
        captureButton.alpha = on ? 0.4 : 1.0
    }

    private func sendForVerification(jpeg: Data) {
        showLoading(true)
        guard let pid = productId, let manu = manufacturerAddress else {
            deliverAndPop(isValid: false, errorMessage: "Missing product context.")
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let isValid = try await VerificationPhotoStore.upload(jpeg: jpeg, productId: pid, manufacturerAddress: manu)
                await MainActor.run {
                    self.deliverAndPop(isValid: isValid, errorMessage: nil)
                }
            } catch {
                await MainActor.run { self.deliverAndPop(isValid: false, errorMessage: error.localizedDescription) }
            }
        }
    }

    private func deliverAndPop(isValid: Bool, errorMessage: String?) {
        showLoading(false)
        isSending = false

        if let msg = errorMessage {
            print("Verification error: \(msg)")
        }

        showResultBanner(isValid: isValid)

        let cb = onResult
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                cb?(isValid)
            }
        }
    }

    private func showResultBanner(isValid: Bool) {
        UINotificationFeedbackGenerator().notificationOccurred(isValid ? .success : .error)

        let card = UIView()
        card.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false

        let tint: UIColor = isValid ? .systemGreen : .systemRed
        let symbol = isValid ? "checkmark.seal.fill" : "xmark.octagon.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)
        let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: config))
        icon.tintColor = tint
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = isValid ? "Product verified" : "Verification failed"
        title.textColor = .white
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(icon)
        card.addSubview(title)
        view.addSubview(card)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.leadingAnchor, constant: framingRect.midX),
            card.centerYAnchor.constraint(equalTo: view.topAnchor, constant: framingRect.midY),
            card.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),

            icon.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            icon.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 52),
            icon.heightAnchor.constraint(equalToConstant: 52),

            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 10),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            title.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        card.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        card.alpha = 0
        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 0.4,
                       options: [.allowUserInteraction]) {
            card.alpha = 1
            card.transform = .identity
        }
    }

    private func captureActualPhoto() {
        capturedScreenSize = view.bounds.size
        capturedFramingRect = framingRect
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.photoQualityPrioritization = .quality
        if #available(iOS 16.0, *) {
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func animateCaptureButton() {
        UIView.animate(withDuration: 0.08, animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        }) { _ in UIView.animate(withDuration: 0.08) { self.captureButton.transform = .identity } }
    }

    private func updateLabels() {
        zoomLabel.text = "1.0×"
    }

    private func formatShutter(_ s: Double) -> String {
        s >= 1 ? String(format: "%.0fs", s) : "1/\(Int((1/s).rounded()))s"
    }

    private func showBanner(text: String) {
        let banner = UILabel()
        banner.text = text
        banner.textColor = .white
        banner.font = .systemFont(ofSize: 13, weight: .semibold)
        banner.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        banner.textAlignment = .center
        banner.layer.cornerRadius = 8
        banner.clipsToBounds = true
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)

        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 52),
            banner.heightAnchor.constraint(equalToConstant: 36),
            banner.widthAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])

        UIView.animate(withDuration: 0.3, delay: 1.0, options: [], animations: {
            banner.alpha = 0
        }) { _ in
            banner.removeFromSuperview()
        }
    }

    private func setupGestures() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        pinch.cancelsTouchesInView = false
        view.addGestureRecognizer(pinch)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func showFocusRing(at point: CGPoint) {
        let ring = UIView(frame: CGRect(x: 0, y: 0, width: 70, height: 70))
        ring.center             = point
        ring.layer.borderColor  = UIColor.systemYellow.cgColor
        ring.layer.borderWidth  = 1.5
        ring.layer.cornerRadius = 35
        view.addSubview(ring)

        UIView.animate(withDuration: 0.2, animations: {
            ring.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        }) { _ in
            UIView.animate(withDuration: 0.4, delay: 0.6, animations: { ring.alpha = 0 }) { _ in
                ring.removeFromSuperview()
            }
        }
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        guard let camera, let previewLayer
        else {
            return
        }
        let screenPoint = g.location(in: view)
        let cameraPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: screenPoint)

        showFocusRing(at: screenPoint)

        cameraConfigQueue.async {
            camera.focusAndExpose(atCameraPoint: cameraPoint)
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let camera
        else {
            return
        }
        if gesture.state == .began {
            lastZoomFactor = camera.currentZoom
        }
        if gesture.state == .changed {
            let factor = max(1.0, min(lastZoomFactor * gesture.scale, camera.maxZoom))
            zoomSlider.value = Float(factor)
            zoomLabel.text = String(format: "%.1f×", factor)

            cameraConfigQueue.async {
                camera.setZoom(factor)
            }
        }
    }
}

extension CameraVC: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],from connection: AVCaptureConnection) {
        if isSending {
            return
        }
        guard let qrObject = metadataObjects
                .compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
                .filter({ $0.type == .qr })
                .first
        else {
            return
        }
        let stringValue = qrObject.stringValue
        DispatchQueue.main.async {
            [weak self] in
            guard let self, let previewLayer = self.previewLayer,
                  let transformed = previewLayer.transformedMetadataObject(for: qrObject)
            else {
                return
            }
            let rect = transformed.bounds
            self.showQROverlay(for: rect, string: stringValue)
            self.isQRInsideFrame = self.isRect(rect, insideFrame: self.framingRect)
        }
    }
}

extension CameraVC: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            DispatchQueue.main.async { self.deliverAndPop(isValid: false, errorMessage: error.localizedDescription) }
            return
        }

        let frame = capturedFramingRect
        let size  = capturedScreenSize

        saveQueue.async {
            [weak self] in
            guard let jpeg = PhotoCropper.crop(photo: photo, framingRect: frame, screenSize: size) else {
                DispatchQueue.main.async {
                    self?.deliverAndPop(isValid: false, errorMessage: "Failed to crop image.") }
                return
            }
            DispatchQueue.main.async {
                self?.sendForVerification(jpeg: jpeg)
            }
        }
    }
}
