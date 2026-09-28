import AppKit
import CoreGraphics

// Recreates Tend's original sun-and-growth mark as an opaque Ocean app icon.
guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift generate_app_icon.swift OUTPUT.png")
}

let side = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
guard let context = CGContext(
    data: nil,
    width: side,
    height: side,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("Could not create icon drawing context")
}
context.translateBy(x: 0, y: CGFloat(side))
context.scaleBy(x: 1, y: -1)
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

func color(_ red: Int, _ green: Int, _ blue: Int) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [
        CGFloat(red) / 255, CGFloat(green) / 255, CGFloat(blue) / 255, 1
    ])!
}

let ocean = color(32, 83, 109)
let ivory = color(248, 247, 239)
let sun = color(225, 194, 125)

context.setFillColor(ocean)
context.fill(CGRect(x: 0, y: 0, width: side, height: side))
context.setFillColor(sun)
context.fillEllipse(in: CGRect(x: 410, y: 167, width: 204, height: 204))

context.setStrokeColor(ivory)
context.setLineCap(.round)
context.setLineJoin(.round)
context.setLineWidth(17)
context.move(to: CGPoint(x: 507, y: 389))
context.addCurve(to: CGPoint(x: 497, y: 657),
                 control1: CGPoint(x: 500, y: 480), control2: CGPoint(x: 483, y: 566))
context.addCurve(to: CGPoint(x: 512, y: 854),
                 control1: CGPoint(x: 497, y: 740), control2: CGPoint(x: 506, y: 816))
context.strokePath()

func leaf(center: CGPoint, width: CGFloat, height: CGFloat, rotation: CGFloat) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.rotate(by: rotation * .pi / 180)
    context.addEllipse(in: CGRect(x: -width / 2, y: -height / 2,
                                  width: width, height: height))
    context.setLineWidth(14)
    context.strokePath()
    context.restoreGState()
}

leaf(center: CGPoint(x: 389, y: 522), width: 248, height: 105, rotation: -5)
leaf(center: CGPoint(x: 637, y: 581), width: 242, height: 103, rotation: -6)
leaf(center: CGPoint(x: 390, y: 702), width: 202, height: 96, rotation: -5)
leaf(center: CGPoint(x: 612, y: 765), width: 222, height: 100, rotation: -4)

guard let image = context.makeImage(),
      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon PNG")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
