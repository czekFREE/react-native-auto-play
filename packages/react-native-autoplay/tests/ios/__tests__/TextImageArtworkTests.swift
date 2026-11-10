import UIKit
import XCTest

@MainActor
final class TextImageArtworkTests: XCTestCase {
  func testCountRendersAsVisibleBitmapAndKeepsDistinctText() throws {
    let count = try image(text: "1248")
    let letter = try image(text: "A")
    let pixels = try pixels(image: count)

    XCTAssertEqual(count.size, CGSize(width: 128, height: 128))
    XCTAssertTrue(pixels.enumerated().contains { $0.offset % 4 == 3 && $0.element > 0 })
    XCTAssertNotEqual(pixels, try self.pixels(image: letter))
  }

  func testUnicodeAndEncodedPunctuationAreRenderedAsText() throws {
    let encoded = try XCTUnwrap(
      createTextImageArtwork(
        asset: (
          uri: "autoplay-internal://text-image/%C4%8C%20%2F%20%3F%20%25", width: 128, height: 128
        ),
        traitCollection: UITraitCollection(userInterfaceStyle: .light)
      )
    )
    XCTAssertEqual(try pixels(image: encoded), try pixels(image: image(text: "Č / ? %")))
  }

  func testCachedArtworkAdaptsToLightAndDarkTraits() throws {
    for fontScale in [1.0, 0.5] {
      let light = try pixels(image: image(text: "128", style: .light, fontScale: fontScale))
      let dark = try pixels(image: image(text: "128", style: .dark, fontScale: fontScale))
      let opaquePixel = try XCTUnwrap(
        stride(from: 0, to: light.count, by: 4).first { light[$0 + 3] > 240 }
      )

      XCTAssertEqual(light[opaquePixel], 0)
      XCTAssertGreaterThan(dark[opaquePixel], 240)
      XCTAssertEqual(light[opaquePixel + 3], dark[opaquePixel + 3])
    }
  }

  func testReducedScaleShrinksAndCentersTextWithoutChangingItsCanvas() throws {
    let full = try image(text: "1248")
    let reduced = try image(text: "1248", fontScale: 0.5)
    let fullBounds = try alphaBounds(image: full)
    let reducedBounds = try alphaBounds(image: reduced)

    XCTAssertEqual(reduced.size, CGSize(width: 128, height: 128))
    XCTAssertLessThan(reducedBounds.width, fullBounds.width * 0.65)
    XCTAssertLessThan(reducedBounds.height, fullBounds.height * 0.65)
    XCTAssertEqual(reducedBounds.midX, 64, accuracy: 3)
    XCTAssertEqual(reducedBounds.midY, 64, accuracy: 4)
    XCTAssertNotEqual(try pixels(image: full), try pixels(image: reduced))
    XCTAssertEqual(
      try pixels(image: reduced), try pixels(image: image(text: "1248", fontScale: 0.5)))
    XCTAssertEqual(try pixels(image: full), try pixels(image: image(text: "1248")))
  }

  func testScaleQueryPreservesEncodedTextAndFullScaleCompatibility() throws {
    for (text, encoded, scale) in [
      ("Č / ? %", "%C4%8C%20%2F%20%3F%20%25", 0.65),
      ("A", "A", 1.0),
    ] {
      let parsed = try XCTUnwrap(
        createTextImageArtwork(
          asset: (
            uri: "autoplay-internal://text-image/\(encoded)?fontScale=\(scale)",
            width: 128,
            height: 128
          ),
          traitCollection: UITraitCollection(userInterfaceStyle: .light)
        )
      )
      XCTAssertEqual(
        try pixels(image: parsed), try pixels(image: image(text: text, fontScale: scale)))
    }
  }

  func testWhiteCircleKeepsBlackTextAndOpaqueBackgroundInBothTraitsAndCache() throws {
    for style: UIUserInterfaceStyle in [.light, .dark] {
      let circle = try image(
        text: "1248", style: style, fontScale: 0.65, background: "whiteCircle")
      let data = try pixels(image: circle)
      let whitePixel = (16 * 128 + 64) * 4
      let cached = try image(
        text: "1248", style: style, fontScale: 0.65, background: "whiteCircle")

      XCTAssertEqual(circle.size, CGSize(width: 128, height: 128))
      XCTAssertEqual(circle.renderingMode, .alwaysOriginal)
      XCTAssertEqual(cached.renderingMode, .alwaysOriginal)
      XCTAssertEqual(try pixels(image: cached), data)
      XCTAssertEqual(Array(data[whitePixel..<(whitePixel + 4)]), [255, 255, 255, 255])
      XCTAssertEqual(Array(data[0..<4]), [0, 0, 0, 0])
      XCTAssertTrue(
        stride(from: 0, to: data.count, by: 4).contains {
          data[$0] == 0 && data[$0 + 1] == 0 && data[$0 + 2] == 0 && data[$0 + 3] == 255
        })
      XCTAssertEqual(try alphaBounds(image: circle), CGRect(x: 8, y: 8, width: 112, height: 112))
    }
  }

  func testWhiteCircleKeepsScaleAndTextCenteredWithoutSharingPlainCache() throws {
    let plain = try image(text: "1248", fontScale: 0.65)
    let full = try image(text: "1248", background: "whiteCircle")
    let reduced = try image(text: "1248", fontScale: 0.65, background: "whiteCircle")
    let fullInk = try alphaBounds(image: full, blackInkOnly: true)
    let reducedInk = try alphaBounds(image: reduced, blackInkOnly: true)

    XCTAssertLessThan(reducedInk.width, fullInk.width * 0.8)
    XCTAssertLessThan(reducedInk.height, fullInk.height * 0.8)
    XCTAssertEqual(reducedInk.midX, 64, accuracy: 3)
    XCTAssertEqual(reducedInk.midY, 64, accuracy: 4)
    XCTAssertNotEqual(try pixels(image: full), try pixels(image: reduced))
    XCTAssertNotEqual(try pixels(image: plain), try pixels(image: reduced))
    XCTAssertEqual(
      try pixels(image: plain), try pixels(image: image(text: "1248", fontScale: 0.65)))
    XCTAssertEqual(
      try pixels(image: full), try pixels(image: image(text: "1248", background: "whiteCircle")))
  }

  func testCompoundQueriesAcceptEitherOrderAndPreserveEncodedPunctuation() throws {
    for query in [
      "fontScale=0.65&background=whiteCircle", "background=whiteCircle&fontScale=0.65",
    ] {
      let parsed = try XCTUnwrap(
        createTextImageArtwork(
          asset: (
            uri: "autoplay-internal://text-image/%C4%8C%20%2F%20%3F%20%25%20%26%20%3D?" + query,
            width: 128,
            height: 128
          ),
          traitCollection: UITraitCollection(userInterfaceStyle: .dark)
        ))
      XCTAssertEqual(
        try pixels(image: parsed),
        try pixels(
          image: image(
            text: "Č / ? % & =", style: .dark, fontScale: 0.65, background: "whiteCircle")))
    }
  }

  func testInvalidQueriesAreRejected() {
    let traits = UITraitCollection(userInterfaceStyle: .light)
    for query in [
      "", "fontScale", "fontScale=", "fontScale=0", "fontScale=-1", "fontScale=1.01",
      "fontScale=nan", "fontScale=inf", "fontScale=0.5&fontScale=0.7",
      "fontScale=0.5?fontScale=0.7",
      "fontScale=0.5&other=1", "other=0.5",
      "background", "background=", "background=plain", "background=whiteCircle=1",
      "background=whiteCircle&background=whiteCircle", "background=whiteCircle&",
      "&background=whiteCircle", "background=whiteCircle&&fontScale=0.65",
      "background=whiteCircle&fontScale=0", "fontScale=0.65&background=whiteCircle&other=1",
      "fontScale=0.5=1",
    ] {
      XCTAssertNil(
        createTextImageArtwork(
          asset: (uri: "autoplay-internal://text-image/A?" + query, width: 128, height: 128),
          traitCollection: traits
        )
      )
    }
  }

  func testEmptyTextIsTransparentAndLongTextFitsCanvas() throws {
    XCTAssertTrue(try pixels(image: image(text: "")).allSatisfy { $0 == 0 })
    let long = try pixels(image: image(text: String(repeating: "8", count: 128)))
    XCTAssertTrue(long.enumerated().contains { $0.offset % 4 == 3 && $0.element > 0 })
    for coordinate in 0..<128 {
      XCTAssertEqual(long[(coordinate * 4) + 3], 0)
      XCTAssertEqual(long[((127 * 128 + coordinate) * 4) + 3], 0)
      XCTAssertEqual(long[((coordinate * 128) * 4) + 3], 0)
      XCTAssertEqual(long[((coordinate * 128 + 127) * 4) + 3], 0)
    }
  }

  func testUnrelatedMalformedAndOversizedAssetsAreRejected() {
    let traits = UITraitCollection(userInterfaceStyle: .light)
    XCTAssertNil(createTextImageArtwork(asset: nil, traitCollection: traits))
    for uri in [
      "https://example.com/128.png",
      "autoplay-internal://empty-image",
      "autoplay-internal://text-image/%",
      "autoplay-internal://text-image/" + String(repeating: "a", count: 129),
    ] {
      XCTAssertNil(
        createTextImageArtwork(asset: (uri: uri, width: 128, height: 128), traitCollection: traits)
      )
    }
    XCTAssertNil(
      createTextImageArtwork(
        asset: (uri: "autoplay-internal://text-image/A", width: 4096, height: 4096),
        traitCollection: traits
      )
    )
  }

  private func image(
    text: String, style: UIUserInterfaceStyle = .light, fontScale: Double = 1,
    background: String? = nil
  ) throws -> UIImage {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "/%?#&=")
    let encoded = try XCTUnwrap(text.addingPercentEncoding(withAllowedCharacters: allowed))
    let parameters = [
      fontScale == 1 ? nil : "fontScale=\(fontScale)",
      background.map { "background=\($0)" },
    ].compactMap { $0 }.joined(separator: "&")
    let query = parameters.isEmpty ? "" : "?" + parameters
    return try XCTUnwrap(
      createTextImageArtwork(
        asset: (uri: "autoplay-internal://text-image/" + encoded + query, width: 128, height: 128),
        traitCollection: UITraitCollection(userInterfaceStyle: style)
      )
    )
  }

  private func alphaBounds(image: UIImage, blackInkOnly: Bool = false) throws -> CGRect {
    let data = try pixels(image: image)
    let positions = stride(from: 0, to: data.count, by: 4).filter {
      data[$0 + 3] > 0
        && (!blackInkOnly
          || (data[$0 + 3] > 240 && data[$0] < 64 && data[$0 + 1] < 64 && data[$0 + 2] < 64))
    }
    let minX = try XCTUnwrap(positions.map { ($0 / 4) % 128 }.min())
    let maxX = try XCTUnwrap(positions.map { ($0 / 4) % 128 }.max())
    let minY = try XCTUnwrap(positions.map { ($0 / 4) / 128 }.min())
    let maxY = try XCTUnwrap(positions.map { ($0 / 4) / 128 }.max())
    return CGRect(
      x: CGFloat(minX), y: CGFloat(minY),
      width: CGFloat(maxX - minX + 1), height: CGFloat(maxY - minY + 1)
    )
  }

  private func pixels(image: UIImage) throws -> [UInt8] {
    let cgImage = try XCTUnwrap(image.cgImage)
    var data = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
    try data.withUnsafeMutableBytes { bytes in
      let context = try XCTUnwrap(
        CGContext(
          data: bytes.baseAddress,
          width: cgImage.width,
          height: cgImage.height,
          bitsPerComponent: 8,
          bytesPerRow: cgImage.width * 4,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
      )
      context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    }
    return data
  }
}
