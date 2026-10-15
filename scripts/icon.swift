// Draws the app icon: a white zipper on a violet squircle, Apple 1024px grid. Usage: icon <out.png>
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
ctx.addPath(round(tile, 185)); ctx.setFillColor(rgb(0x5B3DF5)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(round(tile, 185)); ctx.clip()
let bg = CGGradient(colorsSpace: nil, colors: [rgb(0x8A6CFF), rgb(0x4A2BE0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: size / 2, y: inset), end: CGPoint(x: size / 2, y: inset + body), options: [])
ctx.restoreGState()

// Glyph: interlocking teeth, slider, pull tab — all white
let white = rgb(0xFFFFFF), cx = size / 2
ctx.setFillColor(white)
let tooth = CGSize(width: 96, height: 34), gap = 13.0, teeth = 7
let sliderH = 104.0, tabH = 176.0
let glyphH = Double(teeth) * tooth.height + Double(teeth - 1) * gap + 22 + sliderH + 12 + tabH
var y = (size - glyphH) / 2
for i in 0..<teeth { // alternate sides, overlapping the centre line so they read as interlocked
    let x = i % 2 == 0 ? cx - tooth.width + 14 : cx - 14
    ctx.addPath(round(CGRect(x: x, y: y, width: tooth.width, height: tooth.height), tooth.height / 2)); ctx.fillPath()
    y += tooth.height + gap
}
y += 22 - gap
let slider = CGRect(x: cx - 66, y: y, width: 132, height: sliderH)
ctx.addPath(round(slider, 34)); ctx.fillPath()
let tab = CGRect(x: cx - 44, y: slider.maxY + 12, width: 88, height: tabH)
let tabPath = CGMutablePath()
tabPath.addPath(round(tab, 44))
tabPath.addPath(round(CGRect(x: cx - 17, y: tab.maxY - 90, width: 34, height: 56), 17))
ctx.addPath(tabPath); ctx.fillPath(using: .evenOdd)

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
