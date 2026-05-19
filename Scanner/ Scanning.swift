import UIKit
import Web3
import BigInt
import AVFoundation
import Foundation
import CryptoSwift

class ScanningVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var role: WalletRole?
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    var scanningAllow = true
    var warningLabel = UILabel()

    private var captureDevice: AVCaptureDevice?
    private var lastZoomFactor: CGFloat = 1.0
    private let metadataQueue = DispatchQueue(label: "scanner.metadata")
    private let cameraConfigQueue = DispatchQueue(label: "scanner.cameraConfig")

    private let controlsContainer = UIView()
    private let zoomSlider = UISlider()
    private let exposureSlider = UISlider()
    private let zoomLabel = UILabel()
    private let exposureLabel = UILabel()
    private let cameraView = UIView()

    private let unwrapCameraViewButton = UIButton(type: .system)

    private func configureCameraView(){
        cameraView.backgroundColor = .black
        cameraView.layer.cornerRadius = 20
        cameraView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(cameraView)
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        hidesBottomBarWhenPushed = true

        guard let device = AVCaptureDevice.default(for: .video)
        else {
            print("Failed to get the camera device")
            return
        }
        captureDevice = device

        do {
            captureSession.addInput(try AVCaptureDeviceInput(device: device))

            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession.addOutput(captureMetadataOutput)
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)
            captureMetadataOutput.metadataObjectTypes = [.qr]

            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            videoPreviewLayer?.videoGravity = .resizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds

            if let videoPreviewLayer = videoPreviewLayer {
                view.layer.addSublayer(videoPreviewLayer)
            }

            configureCameraSettings(device: device)
            setupControlsUI()

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
            pinch.cancelsTouchesInView = false
            view.addGestureRecognizer(pinch)
            view.bringSubviewToFront(controlsContainer)

            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }

        }
        catch {
            print("Error setting up capture session: \(error)")
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard videoPreviewLayer?.connection != nil else { return }
        videoPreviewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        scanningAllow = true
        if !captureSession.isRunning {
            cameraConfigQueue.async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = captureSession
        cameraConfigQueue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureCameraSettings(device: AVCaptureDevice) {
        try? device.lockForConfiguration()

        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            device.focusMode = .continuousAutoFocus
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            device.exposureMode = .continuousAutoExposure
        }

        let initialBias = Float(0.0)
        let clampedBias = max(device.minExposureTargetBias,
                              min(initialBias, device.maxExposureTargetBias))
        device.setExposureTargetBias(clampedBias, completionHandler: nil)

        device.unlockForConfiguration()
        enableStabilization()
    }

    private func enableStabilization() {
        guard let connection = videoPreviewLayer?.connection else { return }
        if connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .cinematic
        }
    }

    private func setupControlsUI() {

        controlsContainer.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        controlsContainer.layer.cornerRadius = 16
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsContainer)

        NSLayoutConstraint.activate([
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -16),
        ])

        stack.addArrangedSubview(makeSliderRow(
            icon: "magnifyingglass",
            label: zoomLabel,
            slider: zoomSlider,
            minValue: 0.0,
            maxValue: 15.0,
            initialValue: 0.0,
            format: "%.1fx",
            action: #selector(zoomChanged)
        ))

        stack.addArrangedSubview(makeSliderRow(
            icon: "plusminus.circle",
            label: exposureLabel,
            slider: exposureSlider,
            minValue: -8.0,
            maxValue: 8.0,
            initialValue: 0.0,
            format: "%+.1f EV",
            action: #selector(exposureChanged)
        ))

        zoomLabel.text = "1.0x"
        exposureLabel.text = "+1.0 EV"
    }

    private func makeSliderRow(icon: String, label: UILabel, slider: UISlider, minValue: Float, maxValue: Float, initialValue: Float, format: String, action: Selector) -> UIStackView {

        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22)
        ])

        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.value = initialValue
        slider.tintColor = .white
        slider.thumbTintColor = .white
        slider.addTarget(self, action: action, for: .valueChanged)

        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.textAlignment = .right
        label.widthAnchor.constraint(equalToConstant: 72).isActive = true

        row.addArrangedSubview(iconView)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(label)

        return row
    }

    @objc private func zoomChanged() {
        let factor = CGFloat(zoomSlider.value)
        setZoom(factor)
        zoomLabel.text = String(format: "%.1fx", factor)
    }

    @objc private func exposureChanged() {
        let bias = exposureSlider.value
        setExposureBias(bias)
        exposureLabel.text = String(format: "%+.1f EV", bias)
    }

    private func setZoom(_ factor: CGFloat) {
        guard let device = captureDevice else { return }
        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 15.0)
        let clamped = max(1.0, min(factor, maxZoom))
        cameraConfigQueue.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {
                print("setZoom lock failed: \(error)")
            }
        }
    }

    private func setExposureBias(_ bias: Float) {
        guard let device = captureDevice else { return }
        let clamped = max(device.minExposureTargetBias, min(bias, device.maxExposureTargetBias))
        cameraConfigQueue.async {
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(clamped, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {
                print("setExposureBias lock failed: \(error)")
            }
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let device = captureDevice
        else {
            return
        }

        switch gesture.state {
        case .began:
            lastZoomFactor = device.videoZoomFactor
        case .changed:
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 6.0)
            let newFactor = max(1.0, min(lastZoomFactor * gesture.scale, maxZoom))
            setZoom(newFactor)

            zoomSlider.value = Float(newFactor)
            zoomLabel.text = String(format: "%.1fx", newFactor)
        default:
            break
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard scanningAllow,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let stringValue = metadataObject.stringValue
        else {
            return
        }

        scanningAllow = false
        cameraConfigQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let barCodeObject = self.videoPreviewLayer?.transformedMetadataObject(for: metadataObject) {
                self.qrCodeFrameView?.frame = barCodeObject.bounds
            }
            self.launchApp(decodedURL: stringValue)
        }
    }

    func loading() {
        let circle = UIActivityIndicatorView(style: .large)
        circle.color = .white
        circle.translatesAutoresizingMaskIntoConstraints = false

        let square = UIView()
        square.layer.cornerRadius = 10
        square.backgroundColor = .black.withAlphaComponent(0.8)
        square.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(square)
        square.addSubview(circle)
        circle.startAnimating()

        NSLayoutConstraint.activate([
            circle.centerXAnchor.constraint(equalTo: square.centerXAnchor),
            circle.centerYAnchor.constraint(equalTo: square.centerYAnchor),
            square.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            square.centerYAnchor.constraint(equalTo: view.topAnchor,
                                             constant: view.bounds.height * 0.5),
            square.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.15),
            square.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.15),
        ])
        view.layoutIfNeeded()
    }

    private func stopLoading() {
        view.subviews
            .filter { $0.backgroundColor == .black.withAlphaComponent(0.8) }
            .forEach { $0.removeFromSuperview() }
    }

    private func launchApp(decodedURL: String) {
        let parts = decodedURL.components(separatedBy: ":")

            guard parts.count == 2,
                  let id = Int(parts[0]),
                  let addressData = Data(base64Encoded: parts[1]) else {
                print("Invalid QR format")
                return
            }

            let address = "0x" + addressData.map {
                String(format: "%02x", $0)
            }.joined()

            let checksum = toChecksumAddress(address)

            print(checksum)
            DispatchQueue.main.async {
                let productVC = ProductVC(
                    productID: BigUInt(id),
                    manufacturerCompanyAddress: checksum
                )

                productVC.role = self.role
                self.navigationController?.pushViewController(productVC, animated: true)
            }
    }

    func estWarning() {
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(warningLabel)
        NSLayoutConstraint.activate([
            warningLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            warningLabel.centerYAnchor.constraint(equalTo: view.topAnchor,
                                                   constant: view.bounds.height * 0.75),
            warningLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            warningLabel.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.2),
        ])
    }

    func toChecksumAddress(_ address: String) -> String {
        let clean = address
            .replacingOccurrences(of: "0x", with: "")
            .lowercased()

        let hash = clean.bytes.sha3(.keccak256).toHexString()

        var result = "0x"

        for (addrChar, hashChar) in zip(clean, hash) {
            if let hashInt = Int(String(hashChar), radix: 16),
               hashInt >= 8 {
                result += String(addrChar).uppercased()
            } else {
                result += String(addrChar)
            }
        }

        return result
    }
}

struct Product: Decodable {
    let productid: Int
    let manufacturer: String

    enum CodingKeys: String, CodingKey {
        case productid = "id"
        case manufacturer = "manufacturerCompanyAccount"
    }
}
