import XCTest
import BlipCore
@testable import Blip

/// Draws each renderer into an offscreen bitmap and checks pixel colors and alpha
final class EffectRendererTests: XCTestCase {
    private let size = 400
    private var bounds: CGRect { CGRect(x: 0, y: 0, width: size, height: size) }
    private var center: CGPoint { CGPoint(x: 200, y: 200) }
    /// Expected alpha of the dim layer (0.55 × 255)
    private var dimAlpha: Int { Int((Config.dimOpacity * 255).rounded()) }

    private struct Pixel {
        let r: Int, g: Int, b: Int, a: Int
    }

    private func render(_ renderer: EffectRenderer, spot: CGPoint?, elapsed: TimeInterval = 0) -> [UInt8] {
        let ctx = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        renderer.draw(in: ctx, bounds: bounds, spot: spot, elapsed: elapsed)
        let data = ctx.data!.assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: data, count: size * size * 4))
    }

    /// Row 0 of the CGContext bitmap is the top, so flip y when reading
    private func pixel(_ image: [UInt8], x: Int, y: Int) -> Pixel {
        let row = size - 1 - y
        let offset = (row * size + x) * 4
        return Pixel(r: Int(image[offset]), g: Int(image[offset + 1]), b: Int(image[offset + 2]), a: Int(image[offset + 3]))
    }

    private func assertDim(_ p: Pixel, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(p.a, dimAlpha, accuracy: 2, "\(message): alpha", file: file, line: line)
        XCTAssertEqual(p.r, 0, "\(message): black", file: file, line: line)
    }

    private func assertClear(_ p: Pixel, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(p.a, 0, "\(message): clear", file: file, line: line)
    }

    private func assertRing(_ p: Pixel, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(p.a, 200, "\(message): opaque", file: file, line: line)
        XCTAssertGreaterThan(p.r, p.b + 100, "\(message): yellow (red well above blue)", file: file, line: line)
    }

    private let allRenderers: [(String, EffectRenderer)] = [
        ("spotlight", SpotlightRenderer()),
        ("zoom", ZoomRenderer()),
        ("flash", FlashRenderer()),
        ("focusLines", FocusLinesRenderer()),
    ]

    // MARK: Shared

    func testEveryRendererDimsWholeScreenWhenCursorIsElsewhere() {
        for (name, renderer) in allRenderers {
            let image = render(renderer, spot: nil, elapsed: 0.5)
            for (x, y) in [(0, 0), (399, 399), (200, 200), (50, 350)] {
                assertDim(pixel(image, x: x, y: y), "\(name) (\(x), \(y))")
            }
        }
    }

    func testEveryRendererKeepsCursorPointClear() {
        for (name, renderer) in allRenderers {
            for elapsed in [0.0, 0.2, 1.0] {
                let image = render(renderer, spot: center, elapsed: elapsed)
                assertClear(pixel(image, x: 200, y: 200), "\(name) elapsed \(elapsed)")
            }
        }
    }

    func testMakeRendererMatchesEffect() {
        XCTAssertTrue(makeRenderer(for: .spotlight) is SpotlightRenderer)
        XCTAssertTrue(makeRenderer(for: .zoom) is ZoomRenderer)
        XCTAssertTrue(makeRenderer(for: .flash) is FlashRenderer)
        XCTAssertTrue(makeRenderer(for: .focusLines) is FocusLinesRenderer)
    }

    func testOnlySpotlightIsStatic() {
        XCTAssertFalse(SpotlightRenderer().isAnimated)
        XCTAssertTrue(ZoomRenderer().isAnimated)
        XCTAssertTrue(FlashRenderer().isAnimated)
        XCTAssertTrue(FocusLinesRenderer().isAnimated)
    }

    // MARK: Spotlight

    func testSpotlightHoleRingAndDim() {
        let image = render(SpotlightRenderer(), spot: center)
        let radius = Int(Config.spotRadius)
        // Inside the hole is clear
        assertClear(pixel(image, x: 200, y: 200), "center")
        assertClear(pixel(image, x: 200 + radius - 10, y: 200), "just inside the hole edge")
        // The edge is the ring (the 4 pt stroke is inset into the hole, so it sits at radius − 2)
        assertRing(pixel(image, x: 200 + radius - 2, y: 200), "ring on the right")
        assertRing(pixel(image, x: 200, y: 200 - radius + 2), "ring at the bottom")
        // Outside the hole is dimmed
        assertDim(pixel(image, x: 200 + radius + 5, y: 200), "just outside the hole")
        assertDim(pixel(image, x: 0, y: 0), "corner")
    }

    func testSpotlightFollowsSpotPosition() {
        let image = render(SpotlightRenderer(), spot: CGPoint(x: 60, y: 340))
        assertClear(pixel(image, x: 60, y: 340), "new center")
        assertDim(pixel(image, x: 200, y: 200), "old center is dimmed")
    }

    // MARK: Zoom

    func testZoomStartsWithEverythingClear() {
        let image = render(ZoomRenderer(), spot: center, elapsed: 0)
        for (x, y) in [(0, 0), (399, 0), (0, 399), (399, 399), (200, 200)] {
            assertClear(pixel(image, x: x, y: y), "(\(x), \(y))")
        }
    }

    func testZoomEndsLikeSpotlight() {
        let zoom = render(ZoomRenderer(), spot: center, elapsed: Config.zoomDuration + 1)
        let spotlight = render(SpotlightRenderer(), spot: center)
        XCTAssertEqual(zoom, spotlight)
    }

    func testZoomHoleShrinksOverTime() {
        let radius = Int(Config.spotRadius)
        let probe = (x: 200 + radius + 60, y: 200)
        let early = render(ZoomRenderer(), spot: center, elapsed: 0.02)
        let late = render(ZoomRenderer(), spot: center, elapsed: Config.zoomDuration)
        assertClear(pixel(early, x: probe.x, y: probe.y), "early in the zoom the area outside the final hole is still clear")
        assertDim(pixel(late, x: probe.x, y: probe.y), "dimmed once the zoom has settled")
    }

    // MARK: Flash

    func testFlashRingBlinks() {
        let radius = Int(Config.spotRadius)
        let ringWidth = Int(Config.ringWidth * Config.flashRingWidthScale)
        let probe = (x: 200 + radius - ringWidth / 2, y: 200)
        let on = render(FlashRenderer(), spot: center, elapsed: 0)
        let off = render(FlashRenderer(), spot: center, elapsed: Config.flashBlinkPeriod * 0.75)
        assertRing(pixel(on, x: probe.x, y: probe.y), "ring visible in the first half of the period")
        assertClear(pixel(off, x: probe.x, y: probe.y), "ring hidden in the second half")
    }

    func testFlashRippleExpandsOutsideTheHole() {
        // The first ripple starts at the hole edge at 0 s; at progress 0.25 it is at 1.5 × the spot radius
        let progress = 0.25
        let elapsed = Config.flashRippleLifetime * progress
        let expected = Config.spotRadius * (1 + (Config.flashRippleMaxScale - 1) * CGFloat(progress))
        let image = render(FlashRenderer(), spot: center, elapsed: elapsed)
        let ripple = pixel(image, x: 200 + Int(expected) - 2, y: 200)
        XCTAssertGreaterThan(ripple.r, ripple.b + 50, "ripple is yellow")
        // Inside and outside the ripple stays dimmed
        assertDim(pixel(image, x: 200 + Int(expected) - 12, y: 200), "inside the ripple")
        assertDim(pixel(image, x: 200 + Int(expected) + 12, y: 200), "outside the ripple")
    }

    // MARK: Focus Lines

    func testFocusLinesKeepTheCenterClear() {
        let image = render(FocusLinesRenderer(), spot: center)
        let clearRadius = Int(Config.focusLinesInnerRadius - Config.focusLinesInnerJitter) - 2
        for angle in stride(from: 0.0, to: 360.0, by: 15) {
            let x = 200 + Int((Double(clearRadius) * cos(angle * .pi / 180)).rounded())
            let y = 200 + Int((Double(clearRadius) * sin(angle * .pi / 180)).rounded())
            assertClear(pixel(image, x: x, y: y), "angle \(angle)")
        }
    }

    func testFocusLinesCoverPartOfTheOuterArea() {
        let image = render(FocusLinesRenderer(), spot: center)
        var dark = 0
        var clear = 0
        let radius = 150.0
        for angle in stride(from: 0.0, to: 360.0, by: 1) {
            let x = 200 + Int((radius * cos(angle * .pi / 180)).rounded())
            let y = 200 + Int((radius * sin(angle * .pi / 180)).rounded())
            let p = pixel(image, x: x, y: y)
            if p.a == 0 { clear += 1 } else { dark += 1 }
        }
        XCTAssertGreaterThan(dark, 30, "no wedges")
        XCTAssertGreaterThan(clear, 30, "no gaps")
    }

    func testFocusLinesChangeFrameOverTime() {
        let first = render(FocusLinesRenderer(), spot: center, elapsed: 0)
        let second = render(FocusLinesRenderer(), spot: center, elapsed: Config.focusLinesFrameInterval * 1.5)
        let loop = render(FocusLinesRenderer(), spot: center, elapsed: Config.focusLinesFrameInterval * Double(Config.focusLinesFrameCount) + 0.01)
        XCTAssertNotEqual(first, second, "the frame changes")
        XCTAssertEqual(first, loop, "after a full cycle the first frame returns")
    }
}
