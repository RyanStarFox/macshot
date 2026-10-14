import Cocoa
import XCTest

/// The transparent drop shadow is a different output from beautify: the pixels
/// outside the image are clear, and the shadow itself is black with partial alpha.
final class TransparentShadowTests: XCTestCase {

    func testRadiusZeroDoesNotExpandTheCanvas() {
        let image = ImageProbe.solidImage(width: 40, height: 30)
        let result = BeautifyRenderer.renderTransparentShadow(image: image, shadowRadius: 0)
        XCTAssertEqual(result.size, image.size)
    }

    func testShadowSitsOnTransparency() {
        let width = 40
        let height = 30
        let radius: CGFloat = 20
        let image = ImageProbe.solidImage(
            width: width, height: height,
            color: CGColor(srgbRed: 1, green: 0.2, blue: 0.6, alpha: 1))
        let result = BeautifyRenderer.renderTransparentShadow(image: image, shadowRadius: radius, cornerRadius: 0)
        let bleed = BeautifyRenderer.shadowBleed(for: radius)

        XCTAssertEqual(result.size.width, CGFloat(width) + bleed * 2, accuracy: 0.01)
        XCTAssertEqual(result.size.height, CGFloat(height) + bleed * 2, accuracy: 0.01)

        let margin = Int(bleed.rounded())
        let corner = ImageProbe.pixelColor(result, x: 0, y: 0)
        XCTAssertNotNil(corner)
        XCTAssertEqual(corner?.alphaComponent ?? 1, 0, accuracy: 0.02, "the canvas corner stays clear")

        let center = ImageProbe.pixelColor(result, x: margin + width / 2, y: margin + height / 2)
        XCTAssertEqual(center?.alphaComponent ?? 0, 1, accuracy: 0.02)
        XCTAssertEqual(center?.redComponent ?? 0, 1, accuracy: 0.05)
        XCTAssertEqual(center?.greenComponent ?? 0, 0.2, accuracy: 0.05)
        XCTAssertEqual(center?.blueComponent ?? 0, 0.6, accuracy: 0.05)

        // AppKit draws the offset downward, which is toward the bottom of the bitmap.
        let shadow = ImageProbe.pixelColor(result, x: margin + width / 2, y: margin + height + 8)
        XCTAssertNotNil(shadow)
        let alpha = shadow?.alphaComponent ?? 0
        XCTAssertGreaterThan(alpha, 0.02)
        XCTAssertLessThan(alpha, 1)
        XCTAssertLessThan(shadow?.redComponent ?? 1, 0.2)
        XCTAssertLessThan(shadow?.greenComponent ?? 1, 0.2)
        XCTAssertLessThan(shadow?.blueComponent ?? 1, 0.2)
    }

    func testATransparentCornerStillShapesTheShadow() {
        let image = ImageProbe.makeImage(width: 40, height: 40) { context in
            context.setFillColor(CGColor(srgbRed: 0.1, green: 0.4, blue: 0.9, alpha: 1))
            context.fill(CGRect(x: 10, y: 0, width: 30, height: 40))
            context.fill(CGRect(x: 0, y: 10, width: 10, height: 30))
        }
        let result = BeautifyRenderer.renderTransparentShadow(image: image, shadowRadius: 16, cornerRadius: 0)
        let bleed = Int(BeautifyRenderer.shadowBleed(for: 16).rounded())
        let totalH = Int(result.size.height.rounded())
        // Bitmap y counts from the top. The empty region is the source's bottom-left.
        func bitmapY(sourceYFromBottom: Int) -> Int { totalH - 1 - (bleed + sourceYFromBottom) }
        let emptyCorner = ImageProbe.pixelColor(result, x: bleed + 2, y: bitmapY(sourceYFromBottom: 2))
        // A white caster plate would leave this pixel opaque. A real shadow is only partial black.
        XCTAssertLessThan(emptyCorner?.alphaComponent ?? 1, 0.99)
        if let emptyCorner, emptyCorner.alphaComponent > 0.05 {
            XCTAssertLessThan(emptyCorner.redComponent, 0.5)
        }
        let body = ImageProbe.pixelColor(result, x: bleed + 20, y: bitmapY(sourceYFromBottom: 20))
        XCTAssertEqual(body?.alphaComponent ?? 0, 1, accuracy: 0.02)
    }

    func testBeautifyStillPaintsAnOpaqueBackground() {
        let image = ImageProbe.solidImage(width: 20, height: 16)
        var config = BeautifyConfig()
        config.mode = .rounded
        config.padding = 24
        config.shadowRadius = 12
        config.styleIndex = 0
        let result = BeautifyRenderer.render(image: image, config: config)
        XCTAssertGreaterThan(result.size.width, image.size.width)
        let corner = ImageProbe.pixelColor(result, x: 0, y: 0)
        XCTAssertEqual(corner?.alphaComponent ?? 0, 1, accuracy: 0.02,
                       "beautify's shadow is composited onto its background")
    }

    func testJPEGMatsTheShadowOntoWhite() throws {
        guard ImageEncoder.isFormatAvailable(.jpeg) else { return }
        let image = ImageProbe.solidImage(width: 24, height: 18)
        let shadowed = BeautifyRenderer.renderTransparentShadow(image: image, shadowRadius: 12)
        XCTAssertTrue(shadowed.flattensJPEGOntoWhite)

        var data: Data?
        withDefaults(["imageFormat": "jpeg"]) {
            data = ImageEncoder.encode(shadowed)
        }
        let encoded = try XCTUnwrap(data)
        guard let rep = NSBitmapImageRep(data: encoded),
              let corner = rep.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB) else {
            XCTFail("JPEG did not decode")
            return
        }
        XCTAssertGreaterThan(corner.redComponent, 0.9)
        XCTAssertGreaterThan(corner.greenComponent, 0.9)
        XCTAssertGreaterThan(corner.blueComponent, 0.9)
    }
}
