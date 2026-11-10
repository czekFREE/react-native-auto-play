import UIKit

private let textImageArtworkCache: NSCache<NSString, UIImageAsset> = {
    let cache = NSCache<NSString, UIImageAsset>()
    cache.countLimit = 64
    cache.totalCostLimit = 8 * 1024 * 1024
    return cache
}()

func createTextImageArtwork(
    asset: (uri: String, width: Double, height: Double)?,
    traitCollection: UITraitCollection
) -> UIImage? {
    let prefix = "autoplay-internal://text-image/"
    guard let asset,
        asset.width == 128,
        asset.height == 128,
        asset.uri.hasPrefix(prefix),
        asset.uri.utf8.count <= 4096
    else { return nil }

    let components = asset.uri.dropFirst(prefix.count).split(
        separator: "?",
        maxSplits: 1,
        omittingEmptySubsequences: false
    )
    guard let encodedText = components.first,
        let text = String(encodedText).removingPercentEncoding,
        text.utf16.count <= 128
    else { return nil }

    var fontScale: CGFloat = 1
    var hasWhiteCircle = false
    if components.count == 2 {
        var keys = Set<Substring>()
        for parameter in components[1].split(separator: "&", omittingEmptySubsequences: false) {
            let pair = parameter.split(separator: "=", omittingEmptySubsequences: false)
            guard pair.count == 2, keys.insert(pair[0]).inserted else { return nil }
            switch pair[0] {
            case "fontScale":
                guard let value = Double(pair[1]),
                    value.isFinite,
                    value > 0,
                    value <= 1
                else { return nil }
                fontScale = CGFloat(value)
            case "background":
                guard pair[1] == "whiteCircle" else { return nil }
                hasWhiteCircle = true
            default:
                return nil
            }
        }
    }

    let key = "\(hasWhiteCircle):\(fontScale):\(text)" as NSString
    if let cached = textImageArtworkCache.object(forKey: key) {
        let image = cached.image(with: traitCollection)
        return hasWhiteCircle ? image.withRenderingMode(.alwaysOriginal) : image
    }

    let size = CGSize(width: 128, height: 128)
    let imageAsset = UIImageAsset()
    for style: UIUserInterfaceStyle in [.light, .dark] {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            if hasWhiteCircle {
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: 8, y: 8, width: 112, height: 112)).fill()
            }
            let label = text.replacingOccurrences(of: "\n", with: " ") as NSString
            let initialFont = UIFont.systemFont(ofSize: 64, weight: .semibold)
            let initialSize = label.size(withAttributes: [.font: initialFont])
            let factor = min(1, 108 / max(initialSize.width, 1), 108 / max(initialSize.height, 1))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 64 * factor * fontScale, weight: .semibold),
                .foregroundColor: hasWhiteCircle ? UIColor.black : UIColor.label.resolvedColor(with: traits),
            ]
            let textSize = label.size(withAttributes: attributes)
            label.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attributes
            )
        }
        imageAsset.register(image, with: traits)
    }
    textImageArtworkCache.setObject(imageAsset, forKey: key, cost: 128 * 128 * 4 * 2)
    let image = imageAsset.image(with: traitCollection)
    return hasWhiteCircle ? image.withRenderingMode(.alwaysOriginal) : image
}
