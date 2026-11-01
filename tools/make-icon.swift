// Renders the app icon (1024 x 1024): progress ring with the time in the middle.
// light: white tile, dark ink text; dark: system dark tile, white text; tinted: white glyph.
// Usage: swift tools/make-icon.swift <accent hex> light|dark|tinted <out.png> [ring hex for light]
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let accent = UInt32(args[1], radix: 16)!
let mode = args[2], outPath = args[3]
let label = ":20"
let lightRing = args.count > 4 ? UInt32(args[4], radix: 16)! : accent

let size = 1024, s = CGFloat(1024)
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
                                         CGFloat(hex & 0xFF) / 255, a])!
}

let ring: UInt32 = mode == "tinted" ? 0xFFFFFF : mode == "light" ? lightRing : accent
let text: UInt32 = mode == "light" ? 0x0E1A00 : 0xFFFFFF

// Background: white with a faint cool shade at the bottom (opaque only for the default icon).
if mode == "light" {
    let g = CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF), rgb(0xEEF0EC)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])
} else {
    ctx.clear(CGRect(x: 0, y: 0, width: s, height: s))
}

let c = CGPoint(x: s / 2, y: s / 2)
let r: CGFloat = 318, line: CGFloat = 76
ctx.setLineWidth(line)
ctx.setLineCap(.round)
ctx.setStrokeColor(rgb(ring, mode == "light" ? 0.28 : 0.22))
ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
ctx.strokePath()
ctx.setStrokeColor(rgb(ring))
ctx.addArc(center: c, radius: r, startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi * 0.74, clockwise: true)
ctx.strokePath()

// Time, SF Pro Rounded heavy, optically centred on the digits.
let base = NSFont.systemFont(ofSize: 300, weight: .heavy)
let font = NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: 300) ?? base
let str = NSAttributedString(string: label, attributes: [
    .font: font,
    .foregroundColor: NSColor(cgColor: rgb(text))!,
    .kern: -6,
])
let ctLine = CTLineCreateWithAttributedString(str)
let bounds = CTLineGetImageBounds(ctLine, ctx)
ctx.textPosition = CGPoint(x: c.x - bounds.midX, y: c.y - bounds.midY)
CTLineDraw(ctLine, ctx)

let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
