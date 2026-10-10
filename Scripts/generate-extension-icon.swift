import AppKit
import Foundation

let size = 128
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
NSColor.black.set()
let bookmark = NSBezierPath()
bookmark.move(to: NSPoint(x: 36, y: 110))
bookmark.line(to: NSPoint(x: 92, y: 110))
bookmark.line(to: NSPoint(x: 92, y: 18))
bookmark.line(to: NSPoint(x: 64, y: 38))
bookmark.line(to: NSPoint(x: 36, y: 18))
bookmark.close()
bookmark.fill()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
