import CoreMedia
import CoreVideo
import PinCompCore
import PinCompUI
import SwiftUI

/// The content of one PiP frame.
struct FloatingBoardFrame {
    let name: String
    let position: String
    let set: String
    let slots: [CompSlot]
}

/// The board as drawn inside the PiP window.
struct FloatingBoardView: View {
    let frame: FloatingBoardFrame

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(frame.name)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)
                Spacer()
                Text(frame.position)
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            BoardView(slots: frame.slots, set: frame.set, style: .floating)
        }
        .padding(16)
        .frame(width: FloatingFrameRenderer.size.width, height: FloatingFrameRenderer.size.height, alignment: .topLeading)
        .background(Surface.background)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}

extension BoardView.Style {
    /// Five 50 pt icons per row fill the 320 × 180 pt PiP frame.
    static let floating = BoardView.Style(iconSize: 50, spacing: 8)
}

@MainActor
enum FloatingFrameRenderer {
    /// 16:9 so the PiP window has a familiar video shape.
    static let size = CGSize(width: 320, height: 180)

    /// Renders the board into a BGRA pixel buffer and wraps it in a sample buffer marked "display immediately".
    static func sampleBuffer(for frame: FloatingBoardFrame) -> CMSampleBuffer? {
        let renderer = ImageRenderer(content: FloatingBoardView(frame: frame))
        renderer.scale = 3
        guard let image = renderer.cgImage, let pixelBuffer = pixelBuffer(from: image) else { return nil }

        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &format)
        guard let format else { return nil }

        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: nil,
            imageBuffer: pixelBuffer,
            formatDescription: format,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard let sampleBuffer else { return nil }

        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(
                dictionary,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }
        return sampleBuffer
    }

    private static func pixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        ]
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, image.width, image.height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer)
        guard let buffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return buffer
    }
}
