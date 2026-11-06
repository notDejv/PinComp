import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Island icon sizes: compact 28 pt and expanded 40 pt, at @3x.
public enum IslandIconSize: String, CaseIterable, Sendable {
    case compact
    case expanded

    public var pixels: Int {
        switch self {
        case .compact: 84
        case .expanded: 120
        }
    }
}

enum IconResizer {
    enum Failure: Error {
        case unreadableImage
        case encodingFailed
    }

    /// Downscales image data to a square PNG of `pixels` × `pixels`.
    static func png(from data: Data, pixels: Int) throws(Failure) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw .unreadableImage }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixels,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw .unreadableImage
        }
        let square = cropToSquare(thumbnail)
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            throw .encodingFailed
        }
        CGImageDestinationAddImage(destination, square, nil)
        guard CGImageDestinationFinalize(destination) else { throw .encodingFailed }
        return output as Data
    }

    /// Source icons are square; crop defensively in case one isn't.
    private static func cropToSquare(_ image: CGImage) -> CGImage {
        let side = min(image.width, image.height)
        guard image.width != image.height else { return image }
        let rect = CGRect(x: (image.width - side) / 2, y: (image.height - side) / 2, width: side, height: side)
        return image.cropping(to: rect) ?? image
    }
}
