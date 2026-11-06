// Renders scripts/icon/AppIcon-*.svg to 1024 px PNGs in the app's asset catalog.
// Usage (from the repo root): swift scripts/icon/render_icon.swift
import AppKit

let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let root = repo.appending(path: "scripts/icon")
let output = repo.appending(path: "App/Assets.xcassets/AppIcon.appiconset")
let size = 1024

// The default icon must be opaque (no alpha channel); dark and tinted keep transparency.
for variant in ["default", "dark", "tinted"] {
    let opaque = variant == "default"
    let svgURL = root.appending(path: "AppIcon-\(variant).svg")
    guard let image = NSImage(contentsOf: svgURL) else { fatalError("Cannot load \(svgURL.path)") }
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    guard let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: alpha.rawValue
    ) else { fatalError("Cannot create context") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    guard let cgImage = context.makeImage(),
          let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    else { fatalError("PNG encoding failed") }
    let url = output.appending(path: "AppIcon-\(variant).png")
    try png.write(to: url)
    print(url.path)
}
