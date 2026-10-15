// Turns the generated artwork (tile on white) into a transparent, Apple-grid 1024px icon.
import AppKit

let src = NSImage(contentsOfFile: CommandLine.arguments[1])!
let rep = NSBitmapImageRep(data: src.tiffRepresentation!)!
var (minX, minY, maxX, maxY) = (rep.pixelsWide, rep.pixelsHigh, 0, 0)
for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
    for x in stride(from: 0, to: rep.pixelsWide, by: 2) where rep.colorAt(x: x, y: y)!.brightnessComponent < 0.6 {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    }
}
let side = max(maxX - minX, maxY - minY) - 8   // trim the anti-aliased edge
let crop = rep.cgImage!.cropping(to: CGRect(x: minX + 4, y: minY + 4, width: side, height: side))!

let size = 1024, body = 824.0, inset = (1024 - body) / 2
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let rect = CGRect(x: inset, y: inset, width: body, height: body)
ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 185, cornerHeight: 185, transform: nil))
ctx.clip()
ctx.draw(crop, in: rect)
let out = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
