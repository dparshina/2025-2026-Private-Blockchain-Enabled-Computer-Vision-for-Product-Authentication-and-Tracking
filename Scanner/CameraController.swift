import AVFoundation
import CoreMedia
import UIKit

class CameraController {
    let device: AVCaptureDevice

    init(device: AVCaptureDevice) {
        self.device = device
    }

    var maxZoom: CGFloat {
        min(device.activeFormat.videoMaxZoomFactor, 10.0)
    }

    var currentZoom: CGFloat {
        device.videoZoomFactor
    }

    func configureDefaults() {
        try? device.lockForConfiguration()
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        device.unlockForConfiguration()
    }

    func setZoom(_ factor: CGFloat) {
        try? device.lockForConfiguration()
        device.videoZoomFactor = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))
        device.unlockForConfiguration()
    }

    func focusAndExpose(atCameraPoint point: CGPoint) {
        try? device.lockForConfiguration()
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
        }
        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = point
            device.exposureMode = .autoExpose
        }
        device.unlockForConfiguration()
    }

    private func clamp(_ val: CMTime, lo: CMTime, hi: CMTime) -> CMTime {
        if CMTimeCompare(val, lo) < 0 { return lo }
        if CMTimeCompare(val, hi) > 0 { return hi }
        return val
    }
}
