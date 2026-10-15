// Draws the app icon (Ertaga kech): a green zipper on a matte-black squircle, Apple 1024px grid. Usage: icon <out.png>
import AppKit

let size = 1024.0, body = 824.0, inset = (size - body) / 2
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.displayP3)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.translateBy(x: 0, y: size); ctx.scaleBy(x: 1, y: -1) // top-left origin

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
func round(_ r: CGRect, _ radius: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil) }

// Tile: soft shadow, then violet gradient
let tile = CGRect(x: inset, y: inset, width: body, height: body)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: rgb(0x000000, 0.28))
ctx.addPath(round(tile, 185)); ctx.setFillColor(rgb(0x000000)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(round(tile, 185)); ctx.clip()
let bg = CGGradient(colorsSpace: nil, colors: [rgb(0x1C1C1C), rgb(0x050505)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: size / 2, y: inset), end: CGPoint(x: size / 2, y: inset + body), options: [])
// green light from the top-right and bottom-left, like the brand's light traces
let glow = CGGradient(colorsSpace: nil, colors: [rgb(0x3AD754, 0.45), rgb(0x3AD754, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: inset + body * 0.9, y: inset), startRadius: 0,
                       endCenter: CGPoint(x: inset + body * 0.9, y: inset), endRadius: body * 0.75, options: [])
let glow2 = CGGradient(colorsSpace: nil, colors: [rgb(0x3AD754, 0.2), rgb(0x3AD754, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow2, startCenter: CGPoint(x: inset, y: inset + body), startRadius: 0,
                       endCenter: CGPoint(x: inset, y: inset + body), endRadius: body * 0.6, options: [])
ctx.restoreGState()
// 1px-style top highlight
ctx.saveGState()
ctx.addPath(round(tile.insetBy(dx: 3, dy: 3), 182)); ctx.setLineWidth(6)
ctx.setStrokeColor(rgb(0xFFFFFF, 0.08)); ctx.strokePath()
ctx.restoreGState()

// Glyph: interlocking teeth, slider, pull tab — one shape, filled with a light-to-brand green gradient
let cx = size / 2
let glyph = CGMutablePath()
let tooth = CGSize(width: 96, height: 34), gap = 13.0, teeth = 7
let sliderH = 104.0, tabH = 176.0
let glyphH = Double(teeth) * tooth.height + Double(teeth - 1) * gap + 22 + sliderH + 12 + tabH
var y = (size - glyphH) / 2
for i in 0..<teeth { // alternate sides, overlapping the centre line so they read as interlocked
    let x = i % 2 == 0 ? cx - tooth.width + 14 : cx - 14
    glyph.addPath(round(CGRect(x: x, y: y, width: tooth.width, height: tooth.height), tooth.height / 2))
    y += tooth.height + gap
}
y += 22 - gap
let slider = CGRect(x: cx - 66, y: y, width: 132, height: sliderH)
glyph.addPath(round(slider, 34))
let tab = CGRect(x: cx - 44, y: slider.maxY + 12, width: 88, height: tabH)
let tabPath = CGMutablePath()
tabPath.addPath(round(tab, 44))
tabPath.addPath(round(CGRect(x: cx - 17, y: tab.maxY - 90, width: 34, height: 56), 17))
glyph.addPath(tabPath)
ctx.saveGState()
ctx.addPath(glyph); ctx.clip(using: .evenOdd)
let wave = CGGradient(colorsSpace: nil, colors: [rgb(0x9CF2AB), rgb(0x3AD754)] as CFArray, locations: [0, 1])!
let box = glyph.boundingBox
ctx.drawLinearGradient(wave, start: CGPoint(x: box.midX, y: box.minY), end: CGPoint(x: box.midX, y: box.maxY), options: [])
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
