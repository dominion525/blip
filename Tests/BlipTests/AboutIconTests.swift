import XCTest
@testable import Blip

/// The About panel's icon is composed from two drawings in the bundle, one for each appearance.
/// makeAboutIcon takes the bundle so the real one does not have to be involved; these build a
/// directory with the resources it looks for and hand that over.
final class AboutIconTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BlipAboutIconTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    /// A small image written under the given name. NSImage reads the contents rather than the
    /// extension, so this stands in for the icns the build produces
    private func writeDrawing(named name: String, side: Int = 16) throws {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side,
            pixelsHigh: side,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: directory.appendingPathComponent(name))
    }

    private func bundle() throws -> Bundle {
        try XCTUnwrap(Bundle(url: directory), "a directory of resources stands in for the app bundle")
    }

    func testComposesAnIconWhenBothDrawingsArePresent() throws {
        try writeDrawing(named: "Blip-about.icns", side: 24)
        try writeDrawing(named: "Blip-about-dark.icns", side: 24)

        let icon = try XCTUnwrap(AppDelegate.makeAboutIcon(bundle: try bundle()))
        XCTAssertEqual(icon.size, NSSize(width: 24, height: 24), "the icon takes the size of the light drawing")
        XCTAssertNotNil(icon.tiffRepresentation, "the drawing block runs and produces something")
    }

    /// Losing either drawing has to give nothing rather than half an icon, since the About panel
    /// falls back to the app icon when this returns nil
    func testGivesNothingWhenTheDarkDrawingIsMissing() throws {
        try writeDrawing(named: "Blip-about.icns")
        XCTAssertNil(AppDelegate.makeAboutIcon(bundle: try bundle()))
    }

    func testGivesNothingWhenTheLightDrawingIsMissing() throws {
        try writeDrawing(named: "Blip-about-dark.icns")
        XCTAssertNil(AppDelegate.makeAboutIcon(bundle: try bundle()))
    }

    func testGivesNothingWhenNeitherDrawingIsPresent() throws {
        XCTAssertNil(AppDelegate.makeAboutIcon(bundle: try bundle()))
    }
}
