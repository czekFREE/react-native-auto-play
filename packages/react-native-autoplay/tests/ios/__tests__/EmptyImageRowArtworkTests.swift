import CarPlay
import XCTest

@MainActor
final class EmptyImageRowArtworkTests: XCTestCase {
  func testExplicitEmptyArtworkHasNoVisiblePixels() throws {
    let image = try XCTUnwrap(
      createEmptyImageRowArtwork(
        asset: (uri: "autoplay-internal://empty-image", width: 0, height: 0)
      )
    )

    let cgImage = try XCTUnwrap(image.cgImage)
    XCTAssertEqual(cgImage.width, 1)
    XCTAssertEqual(cgImage.height, 1)

    XCTAssertEqual(try renderPixel(image: cgImage), [0, 0, 0, 0])
  }

  func testOrdinaryMissingAndInvalidAssetsAreNotEmptyArtwork() {
    XCTAssertNil(createEmptyImageRowArtwork(asset: nil))
    XCTAssertNil(createEmptyImageRowArtwork(asset: (uri: "", width: 0, height: 0)))
    XCTAssertNil(
      createEmptyImageRowArtwork(asset: (uri: "file:///missing.png", width: 0, height: 0))
    )
    XCTAssertNil(
      createEmptyImageRowArtwork(
        asset: (uri: "autoplay-internal://empty-image", width: 1, height: 0)
      )
    )
    XCTAssertNil(
      createEmptyImageRowArtwork(
        asset: (uri: "autoplay-internal://empty-image", width: 0, height: 1)
      )
    )
  }

  @available(iOS 26.0, *)
  func testCondensedActionKeepsItsTitleAndChevronWithoutArtwork() throws {
    let image = try XCTUnwrap(
      createEmptyImageRowArtwork(
        asset: (uri: "autoplay-internal://empty-image", width: 0, height: 0)
      )
    )
    let element = CPListImageRowItemCondensedElement(
      image: image,
      imageShape: .roundedRectangle,
      title: "Zobrazit vše",
      subtitle: nil,
      accessorySymbolName: "chevron.right"
    )
    let row = CPListImageRowItem(
      text: "", condensedElements: [element], allowsMultipleLines: true
    )
    let nativeElement = try XCTUnwrap(row.elements.first as? CPListImageRowItemCondensedElement)

    let nativeImage = try XCTUnwrap(nativeElement.image.cgImage)
    XCTAssertEqual(nativeImage.width, 1)
    XCTAssertEqual(nativeImage.height, 1)
    XCTAssertEqual(try renderPixel(image: nativeImage), [0, 0, 0, 0])
    XCTAssertEqual(nativeElement.title, "Zobrazit vše")
    XCTAssertEqual(nativeElement.accessorySymbolName, "chevron.right")
    if #available(iOS 26.4, *) {
      XCTAssertNil(nativeElement.playbackConfiguration)
    }
  }

  private func renderPixel(image: CGImage) throws -> [UInt8] {
    var pixel: [UInt8] = [255, 255, 255, 255]
    try pixel.withUnsafeMutableBytes { bytes in
      let data = try XCTUnwrap(bytes.baseAddress)
      let context = try XCTUnwrap(
        CGContext(
          data: data,
          width: 1,
          height: 1,
          bitsPerComponent: 8,
          bytesPerRow: 4,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
      )
      context.setBlendMode(.copy)
      context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    return pixel
  }
}
