import UIKit
import AVFoundation
import ImageIO

enum PhotoCropper {
    static func crop(photo: AVCapturePhoto, framingRect: CGRect, screenSize: CGSize) -> Data? {
        guard let data = photo.fileDataRepresentation(),
              let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else {
            return nil
        }

        let exif = (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any])?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let uiOrientation = uiImageOrientation(fromExif: exif)

        let rawW = CGFloat(cgImage.width)
        let rawH = CGFloat(cgImage.height)
        let upright = uprightSize(rawW: rawW, rawH: rawH, orientation: uiOrientation)
        let photoW = upright.width
        let photoH = upright.height

        let screenW = screenSize.width
        let screenH = screenSize.height
        let scale = min(photoW / screenW, photoH / screenH)
        let visibleW = screenW * scale
        let visibleH = screenH * scale
        let offsetX  = (photoW - visibleW) / 2
        let offsetY  = (photoH - visibleH) / 2

        let fx = framingRect.origin.x * scale + offsetX
        let fy = framingRect.origin.y * scale + offsetY
        let fw = framingRect.width  * scale
        let fh = framingRect.height * scale
        let pad = fw * 0.05

        let uprightCrop = CGRect(
            x: max(0, fx - pad),
            y: max(0, fy - pad),
            width:  min(photoW - max(0, fx - pad), fw + pad * 2),
            height: min(photoH - max(0, fy - pad), fh + pad * 2)
        ).integral

        let rawCrop = rawRect(forUprightRect: uprightCrop, upright: upright, orientation: uiOrientation)

        let imageBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)

        let safeCrop = rawCrop.intersection(imageBounds)

        guard !safeCrop.isNull, safeCrop.width > 0, safeCrop.height > 0
        else {
            print("Crop failed: safeCrop is null or zero size.")
            return nil
        }

        guard let cropped = cgImage.cropping(to: safeCrop) else {
            print("Crop failed during cgImage.cropping")
            return nil
        }

        return UIImage(cgImage: cropped, scale: 1.0, orientation: uiOrientation)
            .jpegData(compressionQuality: 1.0)
    }

    private static func uprightSize(rawW: CGFloat, rawH: CGFloat, orientation: UIImage.Orientation) -> CGSize {
        switch orientation {
        case .left, .right, .leftMirrored, .rightMirrored:
            return CGSize(width: rawH, height: rawW)
        default:
            return CGSize(width: rawW, height: rawH)
        }
    }

    private static func uiImageOrientation(fromExif exif: UInt32) -> UIImage.Orientation {
        switch exif {
        case 2:
            return .upMirrored
        case 3:
            return .down
        case 4:
            return .downMirrored
        case 5:
            return .leftMirrored
        case 6:
            return .right
        case 7:
            return .rightMirrored
        case 8:
            return .left
        default:
            return .up
        }
    }

    private static func rawRect(forUprightRect r: CGRect, upright s: CGSize, orientation: UIImage.Orientation) -> CGRect {
        switch orientation {
        case .up, .upMirrored:
            return r
        case .down, .downMirrored:
            return CGRect(x: s.width - r.maxX, y: s.height - r.maxY, width: r.width, height: r.height)
        case .right, .rightMirrored:
            return CGRect(x: r.origin.y, y: s.width - r.maxX, width: r.height, height: r.width)
        case .left, .leftMirrored:
            return CGRect(x: s.height - r.maxY, y: r.origin.x, width: r.height, height: r.width)
        @unknown default:
            return r
        }
    }
}
