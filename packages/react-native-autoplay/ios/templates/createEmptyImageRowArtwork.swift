import UIKit

func createEmptyImageRowArtwork(
    asset: (uri: String, width: Double, height: Double)?
) -> UIImage? {
    guard let asset,
        asset.uri == "autoplay-internal://empty-image",
        asset.width == 0,
        asset.height == 0
    else { return nil }

    // CarPlay requires an image object even when this action has no artwork.
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    format.scale = 1
    format.preferredRange = .standard
    let size = CGSize(width: 1, height: 1)

    return UIGraphicsImageRenderer(size: size, format: format).image { context in
        context.cgContext.clear(CGRect(origin: .zero, size: size))
    }
}
