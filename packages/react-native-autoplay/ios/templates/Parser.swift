//
//  Parser.swift
//  Pods
//
//  Created by Manuel Auer on 08.10.25.
//

import CarPlay
import CoreMedia
import ImageIO
import UIKit

struct HeaderActions {
    let leadingNavigationBarButtons: [CPBarButton]
    let trailingNavigationBarButtons: [CPBarButton]
    let backButton: CPBarButton?
}

class Parser {
    static let PLACEHOLDER_DISTANCE = "{distance}"
    static let PLACEHOLDER_DURATION = "{duration}"

    static func parseAlertActions(alertActions: [NitroAction]?)
        -> [CPAlertAction]
    {
        var actions: [CPAlertAction] = []

        if let alertActions = alertActions {
            alertActions.forEach { alertAction in
                let action = CPAlertAction(
                    title: alertAction.title!,
                    style: parseActionAlertStyle(style: alertAction.style),
                    handler: { actionHandler in
                        alertAction.onPress()
                    }
                )

                actions.append(action)
            }
        }

        return actions
    }

    static func parseHeaderActions(
        headerActions: [NitroAction]?,
        traitCollection: UITraitCollection
    )
        -> HeaderActions
    {
        var leadingNavigationBarButtons: [CPBarButton] = []
        var trailingNavigationBarButtons: [CPBarButton] = []
        var backButton: CPBarButton?

        if let headerActions = headerActions {
            headerActions.forEach { action in
                if action.type == .back {
                    backButton = CPBarButton(title: "") { _ in
                        action.onPress()
                    }
                    return
                }

                var image: UIImage?
                if let glypImage = action.image?.glyphImage {
                    image = SymbolFont.imageFromNitroImage(
                        image: glypImage,
                        // this icon is not scaled properly when used as image asset, so we use the plain image, as CP does the correct coloring anyways
                        noImageAsset: true,
                        traitCollection: traitCollection
                    )!
                }
                if let assetImage = action.image?.assetImage {
                    image = Parser.parseAssetImage(
                        assetImage: assetImage,
                        traitCollection: traitCollection
                    )
                }
                if let remoteImage = action.image?.remoteImage {
                    image = Parser.parseRemoteImage(
                        remoteImage: remoteImage,
                        traitCollection: traitCollection
                    )
                }

                var button: CPBarButton

                if let image = image {
                    button = CPBarButton(image: image) { _ in action.onPress() }
                }
                else {
                    button = CPBarButton(title: action.title ?? "") { _ in
                        action.onPress()
                    }
                }

                if action.alignment == .leading {
                    // for whatever reason CarPlay decieds to reverse the order to what we get from js side so we can not append here
                    leadingNavigationBarButtons.insert(button, at: 0)
                    return
                }

                // for whatever reason CarPlay decieds to reverse the order to what we get from js side so we can not append here
                trailingNavigationBarButtons.insert(button, at: 0)
            }
        }

        return HeaderActions(
            leadingNavigationBarButtons: leadingNavigationBarButtons,
            trailingNavigationBarButtons: trailingNavigationBarButtons,
            backButton: backButton
        )
    }

    static func parseText(text: AutoText?) -> String? {
        guard let text else { return nil }

        var result = text.text

        if let distance = text.distance {
            result = result.replacingOccurrences(
                of: Parser.PLACEHOLDER_DISTANCE,
                with: formatDistance(distance: distance)
            )
        }

        if let duration = text.duration {
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .short
            formatter.allowedUnits = [.hour, .minute]
            formatter.zeroFormattingBehavior = .dropAll
            formatter.collapsesLargestUnit = false

            result = result.replacingOccurrences(
                of: Parser.PLACEHOLDER_DURATION,
                with: formatter.string(from: duration)?.replacingOccurrences(
                    of: ",",
                    with: ""
                ) ?? ""
            )
        }

        return result
    }

    static func parseAttributedStrings(
        attributedStrings: [NitroAttributedString],
        traitCollection: UITraitCollection
    ) -> [NSAttributedString] {
        return attributedStrings.map { variant in
            let attributedString = NSMutableAttributedString(
                string: variant.text
            )
            if let nitroImages = variant.images {
                nitroImages.forEach { image in
                    let attachment = NSTextAttachment(
                        image: Parser.parseNitroImage(
                            image: image.image,
                            traitCollection: traitCollection
                        )!
                    )
                    let container = NSAttributedString(
                        attachment: attachment
                    )
                    attributedString.insert(
                        container,
                        at: Int(image.position)
                    )
                }
            }
            return attributedString
        }
    }

    static func formatDistance(distance: Distance) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .medium
        formatter.numberFormatter.minimumFractionDigits = 0
        formatter.numberFormatter.roundingMode = .halfUp

        switch distance.unit {
        case .meters:
            formatter.numberFormatter.maximumFractionDigits = 0
        case .miles:
            formatter.numberFormatter.maximumFractionDigits = 1
        case .yards:
            formatter.numberFormatter.maximumFractionDigits = 0
        case .feet:
            formatter.numberFormatter.maximumFractionDigits = 0
        case .kilometers:
            formatter.numberFormatter.maximumFractionDigits = 1
        }

        let measurement = parseDistance(distance: distance)

        return formatter.string(from: measurement)
    }

    static func parseDistance(distance: Distance) -> Measurement<UnitLength> {
        var unit: UnitLength

        switch distance.unit {
        case .meters:
            unit = UnitLength.meters
        case .miles:
            unit = UnitLength.miles
        case .yards:
            unit = UnitLength.yards
        case .feet:
            unit = UnitLength.feet
        case .kilometers:
            unit = UnitLength.kilometers
        }

        return Measurement(value: distance.value, unit: unit)
    }

    static func parseInformationActions(actions: [NitroAction]?)
        -> [CPTextButton]
    {
        guard let actions else { return [] }

        return actions.map { action in
            let button = CPTextButton(
                title: action.title!,
                textStyle: parseTextButtonStyle(style: action.style),
                handler: { void in
                    action.onPress()
                }
            )

            return button
        }
    }

    static func parseInformationItems(section: NitroSection)
        -> [CPInformationItem]
    {
        return section.items.map { item in
            return CPInformationItem(
                title: parseText(text: item.title),
                detail: parseText(text: item.detailedText)
            )
        }
    }

    static func parseSearchResults(
        section: NitroSection?,
        traitCollection: UITraitCollection
    ) -> [CPListItem] {
        guard let section else { return [] }

        return section.items.enumerated().map { (itemIndex, item) in
            let accessoryImage = item.systemAccessoryImage.flatMap {
                UIImage(systemName: $0)
            }
            let listItem = CPListItem(
                text: parseText(text: item.title),
                detailText: parseText(text: item.detailedText),
                image: Parser.parseNitroImage(
                    image: item.image,
                    traitCollection: traitCollection
                ),
                accessoryImage: accessoryImage,
                accessoryType: item.browsable == true && accessoryImage == nil
                    ? .disclosureIndicator : .none
            )

            listItem.isPlaying = item.isPlaying ?? false
            configureListItemPlayback(item: item, listItem: listItem)
            listItem.playingIndicatorLocation =
                item.playingIndicatorLocation == .trailing
                ? .trailing : .leading

            listItem.handler = { _, completionHandler in
                guard let onPress = item.onPress else {
                    completionHandler()
                    return
                }

                onPress(
                    nil,
                    ListItemPressCompletionStore.add(completionHandler)
                )
            }

            return listItem
        }
    }

    static func parseSections(
        sections: [NitroSection]?,
        updateSection: @escaping (NitroSection, Int) -> Void,
        traitCollection: UITraitCollection
    ) -> [CPListSection] {
        guard let sections else { return [] }

        return sections.enumerated().map { (sectionIndex, section) in
            let selectedIndex = section.items.firstIndex { item in
                item.selected == true
            }
            let items: [any CPListTemplateItem] = section.items.enumerated().map {
                (itemIndex, item) in
                if let imageRowItems = item.imageRowItems {
                    return parseImageRowItem(
                        item: item,
                        imageRowItems: imageRowItems,
                        traitCollection: traitCollection
                    )
                }

                let listItem = CPListItem(
                    text: parseText(text: item.title),
                    detailText: parseText(text: item.detailedText),
                    image: nil,
                    accessoryImage: nil,
                    accessoryType: .none
                )

                configureListItem(
                    currentItem: nil,
                    item: item,
                    itemIndex: itemIndex,
                    listItem: listItem,
                    section: section,
                    sectionIndex: sectionIndex,
                    selectedIndex: selectedIndex,
                    traitCollection: traitCollection,
                    updateSection: updateSection
                )

                return listItem
            }

            return parseListSection(
                items: items,
                section: section,
                traitCollection: traitCollection
            )
        }
    }

    private static func parseListSection(
        items: [any CPListTemplateItem],
        section: NitroSection,
        traitCollection: UITraitCollection
    ) -> CPListSection {
        let header = section.title?.isEmpty == false ? section.title : nil

        guard #available(iOS 15.0, *),
            section.headerImage != nil || section.headerSubtitle != nil
        else {
            return CPListSection(
                items: items,
                header: header,
                sectionIndexTitle: nil
            )
        }

        let headerImage = parseListSectionHeaderImage(
            image: section.headerImage,
            traitCollection: traitCollection
        )
        let listSection = CPListSection(
            items: items,
            header: header ?? "",
            headerSubtitle: section.headerSubtitle,
            headerImage: headerImage.image,
            headerButton: nil,
            sectionIndexTitle: nil
        )

        loadListSectionRemoteHeaderImage(
            listSection: listSection,
            remoteImage: headerImage.remoteImage,
            traitCollection: traitCollection
        )

        return listSection
    }

    private static func parseListSectionHeaderImage(
        image: ImageProtocol?,
        traitCollection: UITraitCollection
    ) -> (image: UIImage?, remoteImage: RemoteImage?) {
        guard let remoteImage = image?.remoteImage else {
            return (
                parseNitroImage(
                    image: image,
                    traitCollection: traitCollection
                ),
                nil
            )
        }

        if let cachedImage = cachedRemoteImage(uri: remoteImage.uri) {
            return (
                applyTint(
                    uiImage: cachedImage,
                    color: remoteImage.color,
                    traitCollection: traitCollection
                ),
                nil
            )
        }

        return (
            createRemoteImageLoadingPlaceholder(
                maximumImageSize: CPMaximumListSectionImageSize
            ),
            remoteImage
        )
    }

    private static func loadListSectionRemoteHeaderImage(
        listSection: CPListSection,
        remoteImage: RemoteImage?,
        traitCollection: UITraitCollection
    ) {
        guard let remoteImage else {
            listSectionRemoteImageRequestSignatures.removeObject(
                forKey: listSection
            )
            return
        }

        let requestSignature = UUID().uuidString as NSString
        listSectionRemoteImageRequestSignatures.setObject(
            requestSignature,
            forKey: listSection
        )
        let timeoutSeconds =
            remoteImage.timeoutMs.map { $0 / 1000.0 }
            ?? defaultAsyncRemoteTimeoutSeconds

        loadRemoteImageAsync(
            uri: remoteImage.uri,
            timeoutSeconds: timeoutSeconds
        ) { loadedImage in
            DispatchQueue.main.async {
                guard
                    listSectionRemoteImageRequestSignatures.object(
                        forKey: listSection
                    ) == requestSignature
                else { return }

                listSectionRemoteImageRequestSignatures.removeObject(
                    forKey: listSection
                )
                listSection.headerImage =
                    applyTint(
                        uiImage: loadedImage
                            ?? createRemoteImageFailurePlaceholder(
                                maximumImageSize: CPMaximumListSectionImageSize
                            ),
                        color: remoteImage.color,
                        traitCollection: traitCollection
                    )
                    ?? createRemoteImageFailurePlaceholder(
                        maximumImageSize: CPMaximumListSectionImageSize
                    )
            }
        }
    }

    private static let listSectionRemoteImageRequestSignatures =
        NSMapTable<CPListSection, NSString>.weakToStrongObjects()

    @available(iOS 26.4, *)
    static func parseListTemplateDetailsHeader(
        detailsHeader: NitroListTemplateDetailsHeader,
        traitCollection: UITraitCollection
    ) -> CPListTemplateDetailsHeader {
        let thumbnail = CPThumbnailImage(
            image: parseAsyncImage(
                image: detailsHeader.thumbnail,
                maximumImageSize: CPListImageRowItemCardElement
                    .maximumFullHeightImageSize,
                traitCollection: traitCollection
            )
        )
        let listHeader = CPListTemplateDetailsHeader(
            thumbnail: thumbnail,
            title: detailsHeader.title,
            subtitle: detailsHeader.subtitle,
            bodyVariants: detailsHeader.bodyVariants.map {
                NSAttributedString(string: $0)
            },
            actionButtons: parseListTemplateDetailsHeaderActions(
                actions: detailsHeader.actionButtons,
                traitCollection: traitCollection
            )
        )
        listHeader.wantsAdaptiveBackgroundStyle =
            detailsHeader.adaptiveBackgroundStyle

        loadListTemplateDetailsHeaderRemoteImages(
            detailsHeader: detailsHeader,
            listHeader: listHeader,
            traitCollection: traitCollection
        )

        return listHeader
    }

    @available(iOS 26.4, *)
    private static func parseListTemplateDetailsHeaderActions(
        actions: [NitroListTemplateDetailsHeaderAction],
        traitCollection: UITraitCollection
    ) -> [CPButton] {
        return actions.prefix(CPListTemplateDetailsHeader.maximumActionButtonCount)
            .map { action in
                let button = CPButton(
                    image: parseAsyncImage(
                        image: action.image,
                        maximumImageSize: CPButtonMaximumImageSize,
                        traitCollection: traitCollection
                    ),
                    handler: { _ in action.onPress?() }
                )
                button.title = action.title
                button.isEnabled = action.enabled
                return button
            }
    }

    private static func parseAsyncImage(
        image: ImageProtocol,
        maximumImageSize: CGSize,
        traitCollection: UITraitCollection
    ) -> UIImage {
        guard let remoteImage = image.remoteImage else {
            return parseNitroImage(
                image: image,
                traitCollection: traitCollection
            ) ?? createRemoteImageFailurePlaceholder(
                maximumImageSize: maximumImageSize
            )
                ?? createRemoteImageLoadingPlaceholder(
                    maximumImageSize: maximumImageSize
                )
        }

        return applyTint(
            uiImage: cachedRemoteImage(uri: remoteImage.uri),
            color: remoteImage.color,
            traitCollection: traitCollection
        )
            ?? createRemoteImageLoadingPlaceholder(
                maximumImageSize: maximumImageSize
            )
    }

    @available(iOS 26.4, *)
    private static func loadListTemplateDetailsHeaderRemoteImages(
        detailsHeader: NitroListTemplateDetailsHeader,
        listHeader: CPListTemplateDetailsHeader,
        traitCollection: UITraitCollection
    ) {
        let remoteImages =
            [detailsHeader.thumbnail.remoteImage]
            + detailsHeader.actionButtons.map { $0.image.remoteImage }

        guard remoteImages.contains(where: { $0 != nil }) else {
            listTemplateDetailsHeaderRemoteImageRequestSignatures.removeObject(
                forKey: listHeader
            )
            return
        }

        let requestSignature = UUID().uuidString as NSString
        listTemplateDetailsHeaderRemoteImageRequestSignatures.setObject(
            requestSignature,
            forKey: listHeader
        )

        for (index, remoteImage) in remoteImages.enumerated() {
            guard let remoteImage,
                cachedRemoteImage(uri: remoteImage.uri) == nil
            else { continue }

            let timeoutSeconds =
                remoteImage.timeoutMs.map { $0 / 1000.0 }
                ?? defaultAsyncRemoteTimeoutSeconds
            loadRemoteImageAsync(
                uri: remoteImage.uri,
                timeoutSeconds: timeoutSeconds
            ) { loadedImage in
                DispatchQueue.main.async {
                    guard
                        listTemplateDetailsHeaderRemoteImageRequestSignatures
                            .object(forKey: listHeader) == requestSignature
                    else { return }

                    if index == 0 {
                        listHeader.thumbnail.image =
                            applyTint(
                                uiImage: loadedImage,
                                color: remoteImage.color,
                                traitCollection: traitCollection
                            )
                            ?? createRemoteImageFailurePlaceholder(
                                maximumImageSize:
                                    CPListImageRowItemCardElement
                                    .maximumFullHeightImageSize
                            )
                            ?? listHeader.thumbnail.image
                    }
                    else {
                        listHeader.actionButtons =
                            parseListTemplateDetailsHeaderActions(
                                actions: detailsHeader.actionButtons,
                                traitCollection: traitCollection
                            )
                    }
                }
            }
        }
    }

    @available(iOS 26.4, *)
    private static let listTemplateDetailsHeaderRemoteImageRequestSignatures =
        NSMapTable<CPListTemplateDetailsHeader, NSString>.weakToStrongObjects()

    static func listTemplateDetailsHeaderContentSignature(
        detailsHeader: NitroListTemplateDetailsHeader?
    ) -> String {
        guard let detailsHeader else { return "none" }

        let actionButtonsSignature = detailsHeader.actionButtons.map { action in
            [
                action.title ?? "",
                "\(action.enabled)",
                imageSignature(image: action.image),
            ].joined(separator: "|")
        }.joined(separator: ";")

        return [
            imageSignature(image: detailsHeader.thumbnail),
            detailsHeader.title ?? "",
            detailsHeader.subtitle ?? "",
            detailsHeader.bodyVariants.joined(separator: "|"),
            actionButtonsSignature,
            "\(detailsHeader.adaptiveBackgroundStyle)",
        ].joined(separator: "|")
    }

    static func listSectionHeaderContentSignature(
        section: NitroSection
    ) -> String {
        return [
            section.title ?? "",
            section.headerSubtitle ?? "",
            imageSignature(image: section.headerImage),
        ].joined(separator: "|")
    }

    private static func parseImageRowItem(
        item: NitroRow,
        imageRowItems: [NitroImageRowItem],
        traitCollection: UITraitCollection
    ) -> CPListImageRowItem {
        let content = parseImageRowContent(
            imageRowItems: imageRowItems,
            variant: item.imageRowVariant ?? .row,
            traitCollection: traitCollection
        )
        let images = content.parsedItems.map { $0.image }
        let listItem: CPListImageRowItem

        if #available(iOS 26.0, *) {
            listItem = createImageRowItem(
                item: item,
                images: images,
                parsedItems: content.parsedItems
            )
        }
        else if #available(iOS 17.4, *) {
            listItem = CPListImageRowItem(
                text: parseText(text: item.title) ?? "",
                images: images,
                imageTitles: content.parsedItems.map { $0.title ?? "" }
            )
        }
        else {
            listItem = CPListImageRowItem(
                text: parseText(text: item.title) ?? "",
                images: images
            )
        }

        configureImageRowInteraction(
            item: item,
            listItem: listItem,
            parsedItems: content.parsedItems
        )
        loadImageRowRemoteImages(
            images: images,
            listItem: listItem,
            parsedItems: content.parsedItems,
            remoteImagesToLoad: content.remoteImagesToLoad,
            variant: item.imageRowVariant ?? .row,
            traitCollection: traitCollection
        )

        return listItem
    }

    private typealias ParsedImageRowItem = (
        accessibilityLabel: String?,
        accessorySystemImage: String?,
        enabled: Bool,
        image: UIImage,
        imageShape: NitroImageRowElementShape?,
        maximumImageSize: CGSize,
        onPress: ((String?) -> Void)?,
        showsImageFullHeight: Bool,
        subtitle: String?,
        tintColor: NitroColor?,
        title: String?
    )
    private typealias ImageRowRemoteImageToLoad = (
        index: Int,
        maximumImageSize: CGSize,
        remoteImage: RemoteImage
    )

    private static func parseImageRowContent(
        imageRowItems: [NitroImageRowItem],
        variant: NitroImageRowVariant,
        traitCollection: UITraitCollection
    ) -> (
        parsedItems: [ParsedImageRowItem],
        remoteImagesToLoad: [ImageRowRemoteImageToLoad]
    ) {
        var parsedItems: [ParsedImageRowItem] = []
        var remoteImagesToLoad: [ImageRowRemoteImageToLoad] = []

        for imageRowItem in imageRowItems {
            let maximumImageSize = imageRowMaximumImageSize(
                variant: variant,
                imageRowItem: imageRowItem
            )

            let image: UIImage
            if let remoteImage = imageRowItem.image.remoteImage {
                if let cachedImage = cachedRemoteImage(uri: remoteImage.uri) {
                    image =
                        applyTint(
                            uiImage: cachedImage,
                            color: remoteImage.color,
                            traitCollection: traitCollection
                        )
                        ?? createImageRowFailurePlaceholder(
                            maximumImageSize: maximumImageSize
                        )
                }
                else {
                    image = createRemoteImageLoadingPlaceholder(
                        maximumImageSize: maximumImageSize
                    )
                    remoteImagesToLoad.append(
                        (
                            index: parsedItems.count,
                            maximumImageSize: maximumImageSize,
                            remoteImage: remoteImage
                        )
                    )
                }
            }
            else {
                image =
                    parseNitroImage(
                        image: imageRowItem.image,
                        traitCollection: traitCollection
                    )
                    ?? createImageRowFailurePlaceholder(
                        maximumImageSize: maximumImageSize
                    )
            }

            parsedItems.append(
                (
                    accessibilityLabel: imageRowItem.accessibilityLabel,
                    accessorySystemImage: imageRowItem.accessorySystemImage,
                    enabled: imageRowItem.enabled,
                    image: image,
                    imageShape: imageRowItem.imageShape,
                    maximumImageSize: maximumImageSize,
                    onPress: imageRowItem.onPress,
                    showsImageFullHeight: imageRowItem.showsImageFullHeight
                        ?? false,
                    subtitle: imageRowItem.subtitle,
                    tintColor: imageRowItem.tintColor,
                    title: imageRowItem.title
                )
            )
        }

        return (parsedItems, remoteImagesToLoad)
    }

    private static func configureImageRowInteraction(
        item: NitroRow,
        listItem: CPListImageRowItem,
        parsedItems: [ParsedImageRowItem]
    ) {
        listItem.userInfo = item.id
        listItem.isEnabled = item.enabled
        listItem.handler = { _, completion in
            guard let onPress = item.onPress else {
                completion()
                return
            }

            onPress(
                nil,
                ListItemPressCompletionStore.add(completion)
            )
        }
        listItem.listImageRowHandler = { _, index, completion in
            guard parsedItems.indices.contains(index) else {
                completion()
                return
            }

            guard parsedItems[index].enabled,
                let onPress = parsedItems[index].onPress
            else {
                completion()
                return
            }

            onPress(
                ListItemPressCompletionStore.add(completion)
            )
        }
    }

    @available(iOS 26.0, *)
    static func configureImageRowItem(
        item: NitroRow,
        imageRowItems: [NitroImageRowItem],
        listItem: CPListImageRowItem,
        traitCollection: UITraitCollection
    ) {
        let content = parseImageRowContent(
            imageRowItems: imageRowItems,
            variant: item.imageRowVariant ?? .row,
            traitCollection: traitCollection
        )
        let images = content.parsedItems.map { $0.image }

        listItem.text = parseText(text: item.title)
        listItem.elements = createImageRowElements(
            variant: item.imageRowVariant ?? .row,
            images: images,
            parsedItems: content.parsedItems
        )
        configureImageRowInteraction(
            item: item,
            listItem: listItem,
            parsedItems: content.parsedItems
        )
        loadImageRowRemoteImages(
            images: images,
            listItem: listItem,
            parsedItems: content.parsedItems,
            remoteImagesToLoad: content.remoteImagesToLoad,
            variant: item.imageRowVariant ?? .row,
            traitCollection: traitCollection
        )
    }

    static func imageRowContentSignature(item: NitroRow) -> String {
        let imageItemsSignature =
            item.imageRowItems?.map(imageRowItemContentSignature).joined(
                separator: ";"
            ) ?? "none"

        return [
            parseText(text: item.title) ?? "",
            "\(item.enabled)",
            item.imageRowVariant?.stringValue ?? "row",
            "\(item.imageRowAllowsMultipleLines ?? false)",
            imageItemsSignature,
        ].joined(separator: "|")
    }

    private static func imageRowItemContentSignature(
        imageRowItem: NitroImageRowItem
    ) -> String {
        let enabled = imageRowItem.enabled ? "true" : "false"
        let showsImageFullHeight =
            imageRowItem.showsImageFullHeight == true ? "true" : "false"

        return [
            imageRowItem.title ?? "",
            imageRowItem.subtitle ?? "",
            imageSignature(image: imageRowItem.image),
            enabled,
            showsImageFullHeight,
            colorSignature(color: imageRowItem.tintColor),
            imageRowItem.imageShape?.stringValue ?? "",
            imageRowItem.accessorySystemImage ?? "",
            imageRowItem.accessibilityLabel ?? "",
        ].joined(separator: "|")
    }

    private static func loadImageRowRemoteImages(
        images: [UIImage],
        listItem: CPListImageRowItem,
        parsedItems: [ParsedImageRowItem],
        remoteImagesToLoad: [ImageRowRemoteImageToLoad],
        variant: NitroImageRowVariant,
        traitCollection: UITraitCollection
    ) {
        var images = images

        guard !remoteImagesToLoad.isEmpty else {
            imageRowRemoteRequestSignatures.removeObject(forKey: listItem)
            return
        }

        let requestSignature = UUID().uuidString as NSString
        imageRowRemoteRequestSignatures.setObject(
            requestSignature,
            forKey: listItem
        )
        var remainingImageCount = remoteImagesToLoad.count

        for remoteImageToLoad in remoteImagesToLoad {
            let timeoutSeconds =
                remoteImageToLoad.remoteImage.timeoutMs.map { $0 / 1000.0 }
                ?? defaultAsyncRemoteTimeoutSeconds

            loadRemoteImageAsync(
                uri: remoteImageToLoad.remoteImage.uri,
                timeoutSeconds: timeoutSeconds
            ) { loadedImage in
                DispatchQueue.main.async {
                    guard
                        imageRowRemoteRequestSignatures.object(
                            forKey: listItem
                        ) == requestSignature,
                        images.indices.contains(remoteImageToLoad.index)
                    else { return }

                    images[remoteImageToLoad.index] =
                        applyTint(
                            uiImage: loadedImage
                                ?? createImageRowFailurePlaceholder(
                                    maximumImageSize: remoteImageToLoad
                                        .maximumImageSize
                                ),
                            color: remoteImageToLoad.remoteImage.color,
                            traitCollection: traitCollection
                        )
                        ?? createImageRowFailurePlaceholder(
                            maximumImageSize: remoteImageToLoad
                                .maximumImageSize
                        )

                    updateImageRowItem(
                        images: images,
                        listItem: listItem,
                        parsedItems: parsedItems,
                        variant: variant
                    )

                    remainingImageCount -= 1
                    if remainingImageCount == 0 {
                        imageRowRemoteRequestSignatures.removeObject(
                            forKey: listItem
                        )
                    }
                }
            }
        }

    }

    private static let imageRowRemoteRequestSignatures =
        NSMapTable<CPListImageRowItem, NSString>.weakToStrongObjects()

    @available(iOS 26.0, *)
    private static func createImageRowItem(
        item: NitroRow,
        images: [UIImage],
        parsedItems: [ParsedImageRowItem]
    ) -> CPListImageRowItem {
        let text = parseText(text: item.title)
        let allowsMultipleLines = item.imageRowAllowsMultipleLines ?? false

        switch item.imageRowVariant ?? .row {
        case .card:
            return CPListImageRowItem(
                text: text,
                cardElements: createImageRowCardElements(
                    images: images,
                    parsedItems: parsedItems
                ),
                allowsMultipleLines: allowsMultipleLines
            )
        case .condensed:
            return CPListImageRowItem(
                text: text,
                condensedElements: createImageRowCondensedElements(
                    images: images,
                    parsedItems: parsedItems
                ),
                allowsMultipleLines: allowsMultipleLines
            )
        case .grid:
            return CPListImageRowItem(
                text: text,
                gridElements: createImageRowGridElements(
                    images: images,
                    parsedItems: parsedItems
                ),
                allowsMultipleLines: allowsMultipleLines
            )
        case .imagegrid:
            return CPListImageRowItem(
                text: text,
                imageGridElements: createImageRowImageGridElements(
                    images: images,
                    parsedItems: parsedItems
                ),
                allowsMultipleLines: allowsMultipleLines
            )
        case .row:
            return CPListImageRowItem(
                text: text,
                elements: createImageRowRowElements(
                    images: images,
                    parsedItems: parsedItems
                ),
                allowsMultipleLines: allowsMultipleLines
            )
        }
    }

    @available(iOS 26.0, *)
    private static func createImageRowElements(
        variant: NitroImageRowVariant,
        images: [UIImage],
        parsedItems: [ParsedImageRowItem]
    ) -> [CPListImageRowItemElement] {
        switch variant {
        case .card:
            return createImageRowCardElements(
                images: images,
                parsedItems: parsedItems
            )
        case .condensed:
            return createImageRowCondensedElements(
                images: images,
                parsedItems: parsedItems
            )
        case .grid:
            return createImageRowGridElements(
                images: images,
                parsedItems: parsedItems
            )
        case .imagegrid:
            return createImageRowImageGridElements(
                images: images,
                parsedItems: parsedItems
            )
        case .row:
            return createImageRowRowElements(
                images: images,
                parsedItems: parsedItems
            )
        }
    }

    @available(iOS 26.0, *)
    private static func createImageRowRowElements(
        images: [UIImage],
        parsedItems: [ParsedImageRowItem]
    ) -> [CPListImageRowItemRowElement] {
        return images.enumerated().compactMap { index, image in
            guard parsedItems.indices.contains(index) else { return nil }

            let element = CPListImageRowItemRowElement(
                image: image,
                title: parsedItems[index].title,
                subtitle: parsedItems[index].subtitle
            )
            configureImageRowElement(
                element: element,
                parsedItem: parsedItems[index]
            )
            return element
        }
    }

    @available(iOS 26.0, *)
    private static func createImageRowCardElements(
        images: [UIImage],
        parsedItems: [ParsedImageRowItem]
    ) -> [CPListImageRowItemCardElement] {
        return images.enumerated().compactMap { index, image in
            guard parsedItems.indices.contains(index) else { return nil }

            let parsedItem = parsedItems[index]
            let element = CPListImageRowItemCardElement(
                image: image,
                showsImageFullHeight: parsedItem.showsImageFullHeight,
                title: parsedItem.title,
                subtitle: parsedItem.subtitle,
                tintColor: parsedItem.tintColor.map { parseColor(color: $0) }
            )
            configureImageRowElement(
                element: element,
                parsedItem: parsedItem
            )
            return element
        }
    }

    @available(iOS 26.0, *)
    private static func createImageRowCondensedElements(
        images: [UIImage],
        parsedItems: [ParsedImageRowItem]
    ) -> [CPListImageRowItemCondensedElement] {
        return images.enumerated().compactMap { index, image in
            guard parsedItems.indices.contains(index) else { return nil }

            let parsedItem = parsedItems[index]
            let element = CPListImageRowItemCondensedElement(
                image: image,
                imageShape: parsedItem.imageShape == .circular
                    ? .circular : .roundedRectangle,
                title: parsedItem.title ?? "",
                subtitle: parsedItem.subtitle,
                accessorySymbolName: parsedItem.accessorySystemImage
            )
            configureImageRowElement(
                element: element,
                parsedItem: parsedItem
            )
            return element
        }
    }

    @available(iOS 26.0, *)
    private static func createImageRowGridElements(
        images: [UIImage],
        parsedItems: [ParsedImageRowItem]
    ) -> [CPListImageRowItemGridElement] {
        return images.enumerated().compactMap { index, image in
            guard parsedItems.indices.contains(index) else { return nil }

            let element = CPListImageRowItemGridElement(image: image)
            configureImageRowElement(
                element: element,
                parsedItem: parsedItems[index]
            )
            return element
        }
    }

    @available(iOS 26.0, *)
    private static func createImageRowImageGridElements(
        images: [UIImage],
        parsedItems: [ParsedImageRowItem]
    ) -> [CPListImageRowItemImageGridElement] {
        return images.enumerated().compactMap { index, image in
            guard parsedItems.indices.contains(index) else { return nil }

            let parsedItem = parsedItems[index]
            let element = CPListImageRowItemImageGridElement(
                image: image,
                imageShape: parsedItem.imageShape == .circular
                    ? .circular : .roundedRectangle,
                title: parsedItem.title ?? "",
                accessorySymbolName: parsedItem.accessorySystemImage
            )
            configureImageRowElement(
                element: element,
                parsedItem: parsedItem
            )
            return element
        }
    }

    @available(iOS 26.0, *)
    private static func configureImageRowElement(
        element: CPListImageRowItemElement,
        parsedItem: ParsedImageRowItem
    ) {
        element.isEnabled = parsedItem.enabled
        if #available(iOS 26.4, *) {
            element.accessibilityLabel = parsedItem.accessibilityLabel
        }
    }

    private static func imageRowMaximumImageSize(
        variant: NitroImageRowVariant,
        imageRowItem: NitroImageRowItem
    ) -> CGSize {
        guard #available(iOS 26.0, *) else {
            return CPListImageRowItem.maximumImageSize
        }

        switch variant {
        case .card:
            return imageRowItem.showsImageFullHeight == true
                ? CPListImageRowItemCardElement.maximumFullHeightImageSize
                : CPListImageRowItemCardElement.maximumImageSize
        case .condensed:
            return CPListImageRowItemCondensedElement.maximumImageSize
        case .grid:
            return CPListImageRowItemGridElement.maximumImageSize
        case .imagegrid:
            return CPListImageRowItemImageGridElement.maximumImageSize
        case .row:
            return CPListImageRowItemRowElement.maximumImageSize
        }
    }

    private static func createImageRowFailurePlaceholder(
        maximumImageSize: CGSize
    ) -> UIImage {
        return createRemoteImageFailurePlaceholder(
            maximumImageSize: maximumImageSize
        ) ?? createRemoteImageLoadingPlaceholder(maximumImageSize: maximumImageSize)
    }

    private static func updateImageRowItem(
        images: [UIImage],
        listItem: CPListImageRowItem,
        parsedItems: [ParsedImageRowItem],
        variant: NitroImageRowVariant
    ) {
        if #available(iOS 26.0, *) {
            // Reassign the copied collection so CarPlay reloads the visible row.
            listItem.elements = createImageRowElements(
                variant: variant,
                images: images,
                parsedItems: parsedItems
            )
            return
        }

        listItem.update(images)
    }

    static func configureListItem(
        currentItem: NitroRow?,
        item: NitroRow,
        itemIndex: Int,
        listItem: CPListItem,
        section: NitroSection,
        sectionIndex: Int,
        selectedIndex: Int?,
        traitCollection: UITraitCollection,
        updateSection: @escaping (NitroSection, Int) -> Void
    ) {
        let text = parseText(text: item.title)
        if currentItem == nil
            || parseText(text: currentItem?.title) != text
        {
            listItem.setText(text ?? "")
        }

        let detailText = parseText(text: item.detailedText)
        if currentItem == nil
            || parseText(text: currentItem?.detailedText) != detailText
        {
            listItem.setDetailText(detailText)
        }

        if currentItem == nil
            || imageSignature(image: currentItem?.image)
                != imageSignature(
                    image: item.image
                )
        {
            configureListItemImage(
                image: item.image,
                listItem: listItem,
                traitCollection: traitCollection
            )
        }

        if currentItem == nil
            || currentItem?.browsable != item.browsable
            || currentItem?.checked != item.checked
            || currentItem?.selected != item.selected
            || currentItem?.systemAccessoryImage
                != item.systemAccessoryImage
        {
            let accessoryImage = parseListItemAccessoryImage(
                item: item,
                itemIndex: itemIndex,
                section: section,
                selectedIndex: selectedIndex
            )
            listItem.setAccessoryImage(accessoryImage)
            listItem.accessoryType = parseListItemAccessoryType(
                accessoryImage: accessoryImage,
                item: item
            )
        }

        if currentItem == nil || currentItem?.enabled != item.enabled {
            listItem.isEnabled = item.enabled
        }

        if currentItem == nil || currentItem?.isPlaying != item.isPlaying {
            listItem.isPlaying = item.isPlaying ?? false
        }

        if currentItem == nil
            || currentItem?.playbackDuration != item.playbackDuration
            || currentItem?.playbackElapsedTime != item.playbackElapsedTime
            || currentItem?.playbackProgress != item.playbackProgress
        {
            configureListItemPlayback(item: item, listItem: listItem)
        }

        if currentItem == nil
            || currentItem?.playingIndicatorLocation
                != item.playingIndicatorLocation
        {
            listItem.playingIndicatorLocation =
                item.playingIndicatorLocation == .trailing
                ? .trailing : .leading
        }

        listItem.userInfo = item.id

        listItem.handler = { _item, completion in
            let shouldUpdateSection =
                section.type == .radio || item.checked != nil
            AutoPlayDevelopmentLogger.log(
                "[AutoPlay] list item press section=\(sectionIndex), row=\(itemIndex), updatesNativeState=\(shouldUpdateSection), title=\(parseText(text: item.title) ?? "")"
            )

            if shouldUpdateSection {
                let updatedItems = section.items.enumerated().map {
                    (rowIndex, row) in
                    let checked: Bool? =
                        if rowIndex == itemIndex, let checked = row.checked {
                            !checked
                        }
                        else { row.checked }

                    let selected: Bool? =
                        if section.type == .radio {
                            rowIndex == itemIndex
                        }
                        else {
                            nil
                        }

                    return NitroRow(
                        title: row.title,
                        id: row.id,
                        detailedText: row.detailedText,
                        systemAccessoryImage: row.systemAccessoryImage,
                        browsable: row.browsable,
                        enabled: row.enabled,
                        image: row.image,
                        isPlaying: row.isPlaying,
                        playbackDuration: row.playbackDuration,
                        playbackElapsedTime: row.playbackElapsedTime,
                        playbackProgress: row.playbackProgress,
                        playingIndicatorLocation: row.playingIndicatorLocation,
                        checked: checked,
                        onPress: row.onPress,
                        selected: selected,
                        imageRowItems: row.imageRowItems,
                        imageRowVariant: row.imageRowVariant,
                        imageRowAllowsMultipleLines: row
                            .imageRowAllowsMultipleLines
                    )
                }

                let updatedSection = NitroSection(
                    headerImage: section.headerImage,
                    headerSubtitle: section.headerSubtitle,
                    title: section.title,
                    items: updatedItems,
                    type: section.type
                )

                updateSection(updatedSection, sectionIndex)
            }

            guard let onPress = item.onPress else {
                completion()
                return
            }

            onPress(
                item.checked.map { checked in !checked },
                ListItemPressCompletionStore.add(completion)
            )
        }
    }

    private static func configureListItemPlayback(
        item: NitroRow,
        listItem: CPListItem
    ) {
        listItem.playbackProgress = CGFloat(item.playbackProgress ?? 0)

        if #available(iOS 26.4, *) {
            guard let duration = item.playbackDuration,
                let elapsedTime = item.playbackElapsedTime,
                duration.isFinite,
                elapsedTime.isFinite,
                duration > 0
            else {
                listItem.playbackConfiguration = nil
                return
            }

            let clampedElapsedTime = min(max(elapsedTime, 0), duration)
            listItem.playbackConfiguration = CPPlaybackConfiguration(
                preferredPresentation: .audio,
                playbackAction: .play,
                elapsedTime: CMTime(
                    seconds: clampedElapsedTime,
                    preferredTimescale: 1_000
                ),
                duration: CMTime(
                    seconds: duration,
                    preferredTimescale: 1_000
                )
            )
        }
    }

    private static let remoteImageRequestSignatures =
        NSMapTable<CPListItem, NSString>.weakToStrongObjects()

    private static func configureListItemImage(
        image: ImageProtocol?,
        listItem: CPListItem,
        traitCollection: UITraitCollection
    ) {
        guard let remoteImage = image?.remoteImage else {
            remoteImageRequestSignatures.removeObject(forKey: listItem)
            listItem.setImage(
                parseNitroImage(
                    image: image,
                    traitCollection: traitCollection
                )
            )
            return
        }

        let requestSignature = imageSignature(image: image) as NSString
        remoteImageRequestSignatures.setObject(
            requestSignature,
            forKey: listItem
        )

        if let cachedImage = cachedRemoteImage(uri: remoteImage.uri) {
            remoteImageRequestSignatures.removeObject(forKey: listItem)
            listItem.setImage(
                applyTint(
                    uiImage: cachedImage,
                    color: remoteImage.color,
                    traitCollection: traitCollection
                )
            )
            return
        }

        listItem.setImage(
            createRemoteImageLoadingPlaceholder(
                maximumImageSize: CPListItem.maximumImageSize
            )
        )

        let timeoutSeconds =
            remoteImage.timeoutMs.map { $0 / 1000.0 }
            ?? defaultAsyncRemoteTimeoutSeconds

        loadRemoteImageAsync(
            uri: remoteImage.uri,
            timeoutSeconds: timeoutSeconds
        ) { loadedImage in
            DispatchQueue.main.async {
                guard
                    remoteImageRequestSignatures.object(forKey: listItem)
                        == requestSignature
                else { return }

                remoteImageRequestSignatures.removeObject(forKey: listItem)
                listItem.setImage(
                    applyTint(
                        uiImage: loadedImage
                            ?? createRemoteImageFailurePlaceholder(
                                maximumImageSize: CPListItem.maximumImageSize
                            ),
                        color: remoteImage.color,
                        traitCollection: traitCollection
                    )
                )
            }
        }
    }

    private static func parseListItemAccessoryImage(
        item: NitroRow,
        itemIndex: Int,
        section: NitroSection,
        selectedIndex: Int?
    ) -> UIImage? {
        if let systemAccessoryImage = item.systemAccessoryImage {
            return UIImage(systemName: systemAccessoryImage)
        }

        let isSelected =
            section.type == .radio
            && Int(selectedIndex ?? -1) == itemIndex

        if isSelected {
            return UIImage.checkmark
        }

        return item.checked.map { checked in
            UIImage.makeToggleImage(
                enabled: checked,
                maximumImageSize: CPListItem.maximumImageSize
            )
        }
    }

    private static func parseListItemAccessoryType(
        accessoryImage: UIImage?,
        item: NitroRow
    ) -> CPListItemAccessoryType {
        item.browsable == true && accessoryImage == nil
            ? .disclosureIndicator : .none
    }

    private static func imageSignature(image: ImageProtocol?) -> String {
        if let glyphImage = image?.glyphImage {
            return [
                "glyph",
                "\(glyphImage.glyph)",
                glyphImage.fontName,
                colorSignature(color: glyphImage.color),
                colorSignature(color: glyphImage.backgroundColor),
                "\(glyphImage.fontScale ?? -1)",
            ].joined(separator: "|")
        }

        if let assetImage = image?.assetImage {
            return [
                "asset",
                assetImage.uri,
                "\(assetImage.width)",
                "\(assetImage.height)",
                "\(assetImage.scale)",
                "\(assetImage.packager_asset)",
                colorSignature(color: assetImage.color),
            ].joined(separator: "|")
        }

        if let remoteImage = image?.remoteImage {
            return [
                "remote",
                remoteImage.uri,
                "\(remoteImage.timeoutMs ?? -1)",
                colorSignature(color: remoteImage.color),
            ].joined(separator: "|")
        }

        return "none"
    }

    private static func colorSignature(color: NitroColor?) -> String {
        guard let color else { return "none" }

        return "\(color.lightColor):\(color.darkColor)"
    }

    static func parseTextButtonStyle(style: NitroButtonStyle?)
        -> CPTextButtonStyle
    {
        guard let style else { return .normal }
        switch style {
        case .cancel:
            return .cancel
        case .normal:
            return .normal
        case .confirm:
            return .confirm
        default:
            return .normal
        }
    }

    static func parseActionAlertStyle(style: NitroButtonStyle?)
        -> CPAlertAction.Style
    {
        guard let style else { return .default }
        switch style {
        case .default:
            return CPAlertAction.Style.default
        case .destructive:
            return CPAlertAction.Style.destructive
        case .cancel:
            return CPAlertAction.Style.cancel
        default:
            return .default
        }
    }

    static func parseActionAlertStyle(style: AlertActionStyle?)
        -> CPAlertAction.Style
    {
        guard let style else { return .default }
        switch style {
        case .default:
            return CPAlertAction.Style.default
        case .destructive:
            return CPAlertAction.Style.destructive
        case .cancel:
            return CPAlertAction.Style.cancel
        default:
            return .default
        }
    }

    static func parseTripPreviewTextConfig(
        textConfig: TripPreviewTextConfiguration
    ) -> CPTripPreviewTextConfiguration {
        return CPTripPreviewTextConfiguration(
            startButtonTitle: textConfig.startButtonTitle,
            additionalRoutesButtonTitle: textConfig.additionalRoutesButtonTitle,
            overviewButtonTitle: textConfig.overviewButtonTitle
        )
    }

    static func parseTripPoint(point: TripPoint) -> MKMapItem {
        let coordinate = CLLocationCoordinate2D(
            latitude: point.latitude,
            longitude: point.longitude
        )
        let placemark = MKPlacemark(coordinate: coordinate)

        let item = MKMapItem(placemark: placemark)
        item.name = point.name
        return item
    }

    static func parseRouteChoice(routeChoice: RouteChoice) -> CPRouteChoice {
        let travelEstimate = parseText(
            text: AutoText(
                text:
                    "\(Parser.PLACEHOLDER_DURATION) (\(Parser.PLACEHOLDER_DISTANCE))",
                distance: routeChoice.steps.last!.travelEstimates
                    .distanceRemaining,
                duration: routeChoice.steps.last!.travelEstimates.timeRemaining
                    .seconds
            )
        )!

        let selectionSummaryVariants =
            routeChoice.selectionSummaryVariants.map { text in
                text + "\n " + travelEstimate
            }

        let additionalInformationVariants = routeChoice
            .additionalInformationVariants.flatMap { summary in
                routeChoice.selectionSummaryVariants.map { selection in
                    summary + "\n" + selection
                }
            }

        let route = CPRouteChoice(
            summaryVariants: routeChoice.summaryVariants,
            additionalInformationVariants: additionalInformationVariants,
            selectionSummaryVariants: selectionSummaryVariants,
            id: routeChoice.id,
            // we don't want to keep the origin travel estimate
            travelEstimates: routeChoice.steps[1...].map { step in
                parseTravelEstimates(travelEstimates: step.travelEstimates)
            }
        )

        return route
    }

    static func parseTrip(tripConfig: TripConfig) -> CPTrip {
        let routeChoices = parseRouteChoice(routeChoice: tripConfig.routeChoice)
        let trip = CPTrip(
            origin: parseTripPoint(
                point: tripConfig.routeChoice.steps.first!
            ),
            destination: parseTripPoint(
                point: tripConfig.routeChoice.steps.last!
            ),
            routeChoices: [routeChoices],
            id: tripConfig.id
        )

        return trip
    }

    static func parseTrips(trips: [TripsConfig]) -> [CPTrip] {
        return trips.map { tripConfig in
            CPTrip(
                origin: parseTripPoint(
                    point: tripConfig.routeChoices.first!.steps.first!
                ),
                destination: parseTripPoint(
                    point: tripConfig.routeChoices.first!.steps.last!
                ),
                routeChoices: tripConfig.routeChoices.map { routeChoice in
                    Parser.parseRouteChoice(routeChoice: routeChoice)
                },
                id: tripConfig.id
            )
        }
    }

    static func parseTravelEstimates(travelEstimates: TravelEstimates)
        -> CPTravelEstimates
    {
        return CPTravelEstimates(
            distanceRemaining: parseDistance(
                distance: travelEstimates.distanceRemaining
            ),
            timeRemaining: travelEstimates.timeRemaining.seconds
        )
    }

    /// Card background `UIColor` for routing maneuvers and loading pause — same light/dark component pick as `parseManeuver`.
    static func routingManeuverCardBackgroundUIColor(
        color: NitroColor,
        traitCollection: UITraitCollection
    ) -> UIColor {
        if #available(iOS 15.4, *) {
            let component =
                traitCollection.userInterfaceStyle == .dark
                ? color.darkColor
                : color.lightColor
            return doubleToColor(value: component)
        }
        return parseColor(color: color)
    }

    static func parseManeuver(
        nitroManeuver: NitroRoutingManeuver,
        traitCollection: UITraitCollection
    ) -> CPManeuver {
        let maneuver = CPManeuver(id: nitroManeuver.id)

        maneuver.attributedInstructionVariants = parseAttributedStrings(
            attributedStrings: nitroManeuver
                .attributedInstructionVariants,
            traitCollection: traitCollection
        )

        maneuver.initialTravelEstimates = Parser.parseTravelEstimates(
            travelEstimates: nitroManeuver.travelEstimates
        )
        maneuver.symbolImage = Parser.parseNitroImage(
            image: nitroManeuver.symbolImage,
            traitCollection: traitCollection
        )
        maneuver.junctionImage = Parser.parseNitroImage(
            image: nitroManeuver.junctionImage,
            traitCollection: traitCollection
        )

        if #available(iOS 15.4, *) {
            maneuver.cardBackgroundColor = routingManeuverCardBackgroundUIColor(
                color: nitroManeuver.cardBackgroundColor,
                traitCollection: traitCollection
            )
        }

        if #available(iOS 17.4, *) {
            maneuver.maneuverType = getManeuverType(maneuver: nitroManeuver)
            maneuver.trafficSide = CPTrafficSide(
                rawValue: UInt(nitroManeuver.trafficSide.rawValue)
            )!
            maneuver.roadFollowingManeuverVariants =
                nitroManeuver.roadName

            if nitroManeuver.maneuverType == .roundabout {
                maneuver.junctionType = .roundabout
            }

            if nitroManeuver.maneuverType == .turn {
                maneuver.junctionType = .intersection
            }

            if let junctionExitAngle = nitroManeuver.angle {
                maneuver.junctionExitAngle = doubleToAngle(
                    value: junctionExitAngle
                )
            }

            if let junctionElementAngles = nitroManeuver
                .elementAngles
            {
                maneuver.junctionElementAngles = Set(
                    doubleToAngle(values: junctionElementAngles)
                )
            }

            if let highwayExitLabel = nitroManeuver.highwayExitLabel {
                maneuver.highwayExitLabel = highwayExitLabel
            }

            if let linkedLaneGuidance = nitroManeuver.linkedLaneGuidance {
                let laneGuidance = parseLaneGuidance(
                    laneGuidance: linkedLaneGuidance
                )
                maneuver.linkedLaneGuidance = laneGuidance
                // iOS does not store the actual CPLaneGuidance type but some NSConcreteMutableAttributedString so we store it in userInfo so we can access it later on
                maneuver.laneGuidance = laneGuidance

                let laneImages = linkedLaneGuidance.lanes.compactMap { lane in
                    switch lane {
                    case .first(let nitroLaneGuidance):
                        return nitroLaneGuidance.image
                    case .second(let nitroLaneGuidance):
                        return nitroLaneGuidance.image
                    }
                }

                maneuver.laneImages = laneImages
            }
        }

        return maneuver
    }

    @available(iOS 17.4, *)
    static func getManeuverType(maneuver: NitroRoutingManeuver)
        -> CPManeuverType
    {
        switch maneuver.maneuverType {
        case .depart:
            return .startRoute
        case .arrive:
            return .arriveAtDestination
        case .arriveleft:
            return .arriveAtDestinationLeft
        case .arriveright:
            return .arriveAtDestinationRight
        case .straight:
            return .straightAhead
        case .turn:
            switch maneuver.turnType {
            case .normalleft:
                return .leftTurn
            case .normalright:
                return .rightTurn
            case .sharpleft:
                return .sharpLeftTurn
            case .sharpright:
                return .sharpRightTurn
            case .slightleft:
                return .slightLeftTurn
            case .slightright:
                return .slightRightTurn
            case .uturnright, .uturnleft:
                return .uTurn
            default:
                return .noTurn
            }
        case .roundabout:
            if let exitNumber = maneuver.exitNumber {
                if exitNumber < 1 || exitNumber > 19 {
                    return .exitRoundabout
                }
                let maneuverType =
                    CPManeuverType.roundaboutExit1.rawValue
                    + (UInt(exitNumber) - 1)
                return CPManeuverType(rawValue: maneuverType) ?? .exitRoundabout
            }
            return .exitRoundabout
        case .offramp:
            switch maneuver.offRampType {
            case .slightleft, .normalleft:
                return .highwayOffRampLeft
            case .slightright, .normalright:
                return .highwayOffRampRight
            default:
                return .offRamp
            }
        case .onramp:
            return .onRamp
        case .fork:
            switch maneuver.forkType {
            case .left:
                return .slightLeftTurn
            case .right:
                return .slightRightTurn
            default:
                return .noTurn
            }
        case .enterferry:
            return .enter_Ferry
        case .keep:
            switch maneuver.keepType {
            case .left:
                return .keepLeft
            case .right:
                return .keepRight
            default:
                return .followRoad
            }
        }
    }

    @available(iOS 17.4, *)
    static func parseLaneGuidance(laneGuidance: LaneGuidance)
        -> CPLaneGuidance
    {
        let instructionVariants = laneGuidance.instructionVariants

        let lanes = laneGuidance.lanes.map { lane in
            var angles: [Measurement<UnitAngle>] = []
            var highlightedAngle: Measurement<UnitAngle>?
            var isPreferred = false

            switch lane {
            case .first(let nitroLaneGuidance):
                angles = doubleToAngle(values: nitroLaneGuidance.angles)
                highlightedAngle = doubleToAngle(
                    value: nitroLaneGuidance.highlightedAngle
                )
                isPreferred = nitroLaneGuidance.isPreferred
            case .second(let nitroLaneGuidance):
                angles = doubleToAngle(values: nitroLaneGuidance.angles)
            }

            return CPLane(
                angles: angles,
                highlightedAngle: highlightedAngle,
                isPreferred: isPreferred
            )
        }

        return CPLaneGuidance(
            instructionVariants: instructionVariants,
            lanes: lanes
        )
    }

    static func parseColor(color: NitroColor) -> UIColor {
        let darkColor = doubleToColor(value: color.darkColor)
        let lightColor = doubleToColor(value: color.lightColor)

        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return darkColor
            case .light:
                return lightColor
            case .unspecified:
                return darkColor
            @unknown default:
                return darkColor
            }
        }
    }

    static func doubleToAngle(values: [Double]) -> [Measurement<UnitAngle>] {
        return values.map {
            doubleToAngle(value: $0)
        }
    }

    static func doubleToAngle(value: Double) -> Measurement<UnitAngle> {
        return Measurement(value: value, unit: UnitAngle.degrees)
    }

    static func doubleToColor(value: Double) -> UIColor {
        return NitroConvert.uiColor(value)
    }

    static func parseNitroImage(
        image: ImageProtocol?,
        traitCollection: UITraitCollection
    ) -> UIImage? {
        if let glyphImage = image?.glyphImage {
            return SymbolFont.imageFromNitroImage(
                image: glyphImage,
                traitCollection: traitCollection
            )!
        }

        if let assetImage = image?.assetImage {
            return Parser.parseAssetImage(
                assetImage: assetImage,
                traitCollection: traitCollection
            )
        }

        if let remoteImage = image?.remoteImage {
            return Parser.parseRemoteImage(
                remoteImage: remoteImage,
                traitCollection: traitCollection
            )
        }

        return nil
    }

    // MARK: - Remote image cache
    private static let remoteImageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 50
        cache.totalCostLimit = 8 * 1024 * 1024  // 8 MB, matching Android's BitmapCache
        return cache
    }()

    /// Shared session — long-lived by design; failed tasks don't invalidate it.
    private static let remoteImageSession = URLSession(configuration: .default)

    /// Default network timeout for remote images when no `timeoutMs` is provided.
    private static let defaultRemoteTimeoutSeconds: TimeInterval = 0.5
    private static let defaultAsyncRemoteTimeoutSeconds: TimeInterval = 5

    static func parseAssetImage(
        assetImage: AssetImage,
        traitCollection: UITraitCollection
    ) -> UIImage? {
        let uiImage = NitroConvert.uiImage([
            "height": assetImage.height, "width": assetImage.width,
            "uri": assetImage.uri, "scale": assetImage.scale,
            "__packager_asset": assetImage.packager_asset,
        ])

        return applyTint(
            uiImage: uiImage,
            color: assetImage.color,
            traitCollection: traitCollection
        )
    }

    static func parseRemoteImage(
        remoteImage: RemoteImage,
        traitCollection: UITraitCollection
    ) -> UIImage? {
        let timeoutSeconds = remoteImage.timeoutMs.map { $0 / 1000.0 } ?? defaultRemoteTimeoutSeconds
        let uiImage = loadRemoteImage(uri: remoteImage.uri, timeoutSeconds: timeoutSeconds)

        return applyTint(
            uiImage: uiImage,
            color: remoteImage.color,
            traitCollection: traitCollection
        )
    }

    private static func applyTint(
        uiImage: UIImage?,
        color: NitroColor?,
        traitCollection: UITraitCollection
    ) -> UIImage? {
        guard let image = uiImage else { return nil }
        guard let color else { return image }

        return getTintedImageAsset(
            color: color,
            uiImage: image,
            traitCollection: traitCollection
        )
    }

    /// Synchronously loads an image for CarPlay APIs that require a complete image value.
    /// Ordinary list rows use `loadRemoteImageAsync` instead.
    private static func loadRemoteImage(uri: String, timeoutSeconds: TimeInterval) -> UIImage? {
        let cacheKey = uri as NSString
        if let cached = remoteImageCache.object(forKey: cacheKey) {
            return cached
        }

        guard let url = URL(string: uri) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutSeconds

        var resultData: Data?
        let semaphore = DispatchSemaphore(value: 0)
        let task = remoteImageSession.dataTask(with: request) { data, _, _ in
            resultData = data
            semaphore.signal()
        }
        task.resume()
        if semaphore.wait(timeout: .now() + timeoutSeconds) == .timedOut {
            task.cancel()
            return createRemoteImageFailurePlaceholder()
        }

        guard let data = resultData, let image = UIImage(data: data) else {
            return createRemoteImageFailurePlaceholder()
        }

        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        remoteImageCache.setObject(image, forKey: cacheKey, cost: cost)
        return image
    }

    private static func cachedRemoteImage(uri: String) -> UIImage? {
        remoteImageCache.object(forKey: uri as NSString)
    }

    private static func loadRemoteImageAsync(
        uri: String,
        timeoutSeconds: TimeInterval,
        completion: @escaping (UIImage?) -> Void
    ) {
        if let cachedImage = cachedRemoteImage(uri: uri) {
            completion(cachedImage)
            return
        }

        guard let url = URL(string: uri) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutSeconds

        remoteImageSession.dataTask(with: request) { data, _, _ in
            guard let data, let image = UIImage(data: data) else {
                completion(nil)
                return
            }

            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            remoteImageCache.setObject(image, forKey: uri as NSString, cost: cost)
            completion(image)
        }.resume()
    }

    private static func createRemoteImageLoadingPlaceholder(
        maximumImageSize: CGSize
    ) -> UIImage {
        UIGraphicsImageRenderer(size: maximumImageSize).image { _ in }
    }

    private static func createRemoteImageFailurePlaceholder(
        maximumImageSize: CGSize = CPListImageRowItem.maximumImageSize
    ) -> UIImage? {
        guard let symbol = UIImage(systemName: "exclamationmark.circle") else {
            return nil
        }

        let canvasSize = maximumImageSize
        let symbolSide = min(canvasSize.width, canvasSize.height) * 0.28
        let symbolRect = CGRect(
            x: (canvasSize.width - symbolSide) / 2,
            y: (canvasSize.height - symbolSide) / 2,
            width: symbolSide,
            height: symbolSide
        )
        let tintedSymbol = symbol.withTintColor(
            .systemGray,
            renderingMode: .alwaysOriginal
        )

        return UIGraphicsImageRenderer(size: canvasSize).image { _ in
            tintedSymbol.draw(in: symbolRect)
        }
    }

    static func getTintedImageAsset(
        color: NitroColor,
        uiImage: UIImage,
        traitCollection: UITraitCollection
    ) -> UIImage {
        let imageAsset = UIImageAsset()

        let lightTraits = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .light)
        ])
        imageAsset.register(
            getTintedImage(color: color.lightColor, uiImage: uiImage),
            with: lightTraits
        )

        let darkTraits = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark)
        ])
        imageAsset.register(
            getTintedImage(color: color.darkColor, uiImage: uiImage),
            with: darkTraits
        )

        return imageAsset.image(with: traitCollection)
    }

    static func getTintedImage(color: Double, uiImage: UIImage) -> UIImage {
        guard let cgImage = uiImage.cgImage else { return uiImage }

        let rect = CGRect(origin: .zero, size: uiImage.size)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard
            let context = CGContext(
                data: nil,
                width: Int(uiImage.size.width),
                height: Int(uiImage.size.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return uiImage }

        context.clip(to: rect, mask: cgImage)
        context.setFillColor(doubleToColor(value: color).cgColor)
        context.fill(rect)

        guard let tintedCGImage = context.makeImage() else { return uiImage }

        return UIImage(
            cgImage: tintedCGImage,
            scale: uiImage.scale,
            orientation: uiImage.imageOrientation
        )
    }

    // MARK: - Animated image decoding

    /// Decodes raw image data via ImageIO, walking every frame so animated GIF/APNG/WebP all
    /// animate. UIImage(data:) only ever decodes the first frame for any of these formats.
    /// `maxDuration` caps the assembled cycle length; pass `.greatestFiniteMagnitude` to skip capping.
    static func decodeImage(data: Data, scale: CGFloat, maxDuration: TimeInterval = .greatestFiniteMagnitude)
        -> UIImage?
    {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }

        guard frameCount > 1 else {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
        }

        var frames: [UIImage] = []
        var totalDuration: TimeInterval = 0
        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            totalDuration += frameDuration(source: source, index: index)
            frames.append(UIImage(cgImage: cgImage, scale: scale, orientation: .up))
        }
        guard !frames.isEmpty else { return nil }
        return UIImage.animatedImage(with: frames, duration: min(totalDuration, maxDuration))
    }

    /// Reads the per-frame delay from whichever format dictionary ImageIO populated
    /// (GIF, APNG, or WebP), falling back to a sane default if none is present.
    private static func frameDuration(source: CGImageSource, index: Int) -> TimeInterval {
        let defaultDuration: TimeInterval = 0.1
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        else { return defaultDuration }

        if let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
            if let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double, unclamped > 0 {
                return unclamped
            }
            if let delay = gif[kCGImagePropertyGIFDelayTime] as? Double, delay > 0 {
                return delay
            }
        }

        if let png = properties[kCGImagePropertyPNGDictionary] as? [CFString: Any] {
            if let unclamped = png[kCGImagePropertyAPNGUnclampedDelayTime] as? Double, unclamped > 0 {
                return unclamped
            }
            if let delay = png[kCGImagePropertyAPNGDelayTime] as? Double, delay > 0 {
                return delay
            }
        }

        if let webp = properties[kCGImagePropertyWebPDictionary] as? [CFString: Any],
            let delay = webp[kCGImagePropertyWebPDelayTime] as? Double, delay > 0
        {
            return delay
        }

        return defaultDuration
    }

    private static func targetSize(for size: CGSize, max maxSize: CGSize) -> CGSize {
        guard size.width > maxSize.width || size.height > maxSize.height else { return size }
        let scale = min(maxSize.width / size.width, maxSize.height / size.height)
        return CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }

    static func resize(_ image: UIImage, max maxSize: CGSize) -> UIImage {
        let target = targetSize(for: image.size, max: maxSize)
        guard target != image.size else { return image }
        return UIGraphicsImageRenderer(size: target).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Resizes every frame of an animated UIImage while preserving the per-frame timing.
    /// UIImage.draw(in:) only renders the current frame, so resize() alone would collapse
    /// the animation to a still image.
    static func resizeAnimated(_ image: UIImage, max maxSize: CGSize) -> UIImage {
        guard let frames = image.images, !frames.isEmpty else {
            return resize(image, max: maxSize)
        }
        let target = targetSize(for: image.size, max: maxSize)
        guard target != image.size else { return image }
        let resizedFrames = frames.map { frame in
            UIGraphicsImageRenderer(size: target).image { _ in
                frame.draw(in: CGRect(origin: .zero, size: target))
            }
        }
        return UIImage.animatedImage(with: resizedFrames, duration: image.duration) ?? image
    }

    static func imageFromLanes(
        laneImages: Array<NitroImage>.SubSequence,
        traitCollection: UITraitCollection
    ) -> UIImage {
        let lightTrait = UITraitCollection(userInterfaceStyle: .light)
        let darkTrait = UITraitCollection(userInterfaceStyle: .dark)

        // Parse all images once
        let parsedImages = laneImages.compactMap { image in
            Parser.parseNitroImage(
                image: image,
                traitCollection: traitCollection
            )
        }

        // Resolve one set (light) just to measure dimensions
        let sampleResolved = parsedImages.map {
            $0.imageAsset?.image(with: lightTrait) ?? $0
        }

        let totalWidth: CGFloat =
            sampleResolved.reduce(0) { $0 + $1.size.width }
            + CGFloat(sampleResolved.count - 1)
        let maxHeight: CGFloat = sampleResolved.map(\.size.height).max() ?? 0
        let rendererSize = CGSize(width: totalWidth, height: maxHeight)

        func mergedImage(for trait: UITraitCollection) -> UIImage {
            let resolvedImages = parsedImages.map {
                $0.imageAsset?.image(with: trait) ?? $0
            }

            let renderer = UIGraphicsImageRenderer(size: rendererSize)
            let image = renderer.image { _ in
                var x: CGFloat = 0
                for img in resolvedImages {
                    img.draw(at: CGPoint(x: x, y: 0))
                    x += img.size.width
                }
            }

            return image.withRenderingMode(.alwaysOriginal)
        }

        let asset = UIImageAsset()
        asset.register(mergedImage(for: lightTrait), with: lightTrait)
        asset.register(mergedImage(for: darkTrait), with: darkTrait)

        return asset.image(with: traitCollection)
    }
}
