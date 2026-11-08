import CarPlay

struct NitroImageRowItem {
  var id: String?
  var title: String
  var accessorySystemImage: String? = nil
  var playbackDuration: Double? = nil
  var playbackElapsedTime: Double? = nil
}

// These stand-ins isolate the template from Nitro and application scene setup.
// The tested ListTemplate and all CarPlay template, section and item objects are real.
struct NitroRow {
  var id: String?
  var title: String
  var selected: Bool? = nil
  var imageRowItems: [NitroImageRowItem]? = nil
  var imageRowVariant: String? = nil
  var imageRowAllowsMultipleLines: Bool? = nil
  var onPress: (() -> Void)? = nil
  var enabled = true
  var imageUri: String? = nil
  var isPaginationItem: Bool? = nil
}

struct NitroSection {
  var title: String?
  var items: [NitroRow]
  var type = "default"
}

struct NitroListTemplateDetailsHeader {
  var title: String?
}

struct ListTemplateConfig {
  var id: String
  var title: String?
  var sections: [NitroSection]?
  var detailsHeader: NitroListTemplateDetailsHeader?
  var autoDismissMs: Double? = nil
  var headerActions: [String]? = nil
  var onWillAppear: ((Bool) -> Void)? = nil
  var onDidAppear: ((Bool) -> Void)? = nil
  var onWillDisappear: ((Bool) -> Void)? = nil
  var onDidDisappear: ((Bool) -> Void)? = nil
  var onPopped: (() -> Void)? = nil
}

class AutoPlayHeaderProviding: NSObject {
  var autoDismissMs: Double? { nil }
  var barButtons: [String]?
  var deferInvalidation = false
  func getTemplate() -> CPTemplate { CPTemplate() }
  @MainActor func _invalidate() {}
  @MainActor func invalidate() {
    if !deferInvalidation { _invalidate() }
  }
  func onWillAppear(animated: Bool) {}
  func onDidAppear(animated: Bool) {}
  func onWillDisappear(animated: Bool) {}
  func onDidDisappear(animated: Bool) {}
  func onPopped() {}
}

@MainActor
func setBarButtons(template: CPTemplate, barButtons: [String]?) {}

enum SceneStore {
  static var traitCollection: UITraitCollection? = UITraitCollection(userInterfaceStyle: .light)
  static func getRootTraitCollection() -> UITraitCollection? { traitCollection }
}

enum AutoPlayDevelopmentLogger {
  static func log(_ message: String) {}
}

extension CPListTemplate {
  convenience init(
    title: String?,
    sections: [CPListSection],
    assistantCellConfiguration: CPAssistantCellConfiguration?,
    id: String
  ) {
    self.init(
      title: title,
      sections: sections,
      assistantCellConfiguration: assistantCellConfiguration
    )
    userInfo = id
  }
}

enum Parser {
  private static let imageRowPlaybackStates = ImageRowPlaybackStateStore()
  static func parseText(text: String?) -> String? { text }
  static func listSectionHeaderContentSignature(section: NitroSection) -> String {
    section.title ?? ""
  }
  static func listTemplateDetailsHeaderContentSignature(
    detailsHeader: NitroListTemplateDetailsHeader?
  ) -> String {
    detailsHeader?.title ?? "none"
  }
  @available(iOS 26.4, *)
  static func parseListTemplateDetailsHeader(
    detailsHeader: NitroListTemplateDetailsHeader,
    traitCollection: UITraitCollection
  ) -> CPListTemplateDetailsHeader {
    CPListTemplateDetailsHeader(
      thumbnail: CPThumbnailImage(image: UIImage()),
      title: detailsHeader.title,
      subtitle: nil,
      bodyVariants: [],
      actionButtons: []
    )
  }
  static func parseSections(
    sections: [NitroSection]?,
    updateSection: @escaping (NitroSection, Int) -> Void,
    traitCollection: UITraitCollection,
    reusableListItem: (NitroRow, Int) -> (item: NitroRow, listItem: CPListItem)? = { _, _ in nil }
  ) -> [CPListSection] {
    (sections ?? []).enumerated().map { sectionIndex, section in
      CPListSection(
        items: section.items.enumerated().map { itemIndex, item -> any CPListTemplateItem in
          if let imageRowItems = item.imageRowItems {
            let row = CPListImageRowItem(
              text: item.title,
              condensedElements: createImageRowElements(items: imageRowItems),
              allowsMultipleLines: item.imageRowAllowsMultipleLines ?? false
            )
            imageRowPlaybackStates.register(
              listItem: row,
              elements: createImageRowDescriptors(items: imageRowItems)
            )
            return row
          }
          let reusableItem = reusableListItem(item, sectionIndex)
          let row = reusableItem?.listItem ?? CPListItem(text: item.title, detailText: nil)
          configureListItem(
            currentItem: reusableItem?.item,
            item: item,
            itemIndex: itemIndex,
            listItem: row,
            section: section,
            sectionIndex: sectionIndex,
            selectedIndex: nil,
            traitCollection: traitCollection,
            updateSection: updateSection
          )
          return row
        },
        header: section.title,
        sectionIndexTitle: nil
      )
    }
  }
  static func imageRowContentSignature(item: NitroRow) -> String { item.title }
  static func configureImageRowItem(
    item: NitroRow,
    imageRowItems: [NitroImageRowItem],
    listItem: CPListImageRowItem,
    traitCollection: UITraitCollection
  ) {
    listItem.text = item.title
    imageRowPlaybackStates.replaceElements(
      listItem: listItem,
      elements: createImageRowElements(items: imageRowItems),
      sourceElements: createImageRowDescriptors(items: imageRowItems)
    )
  }
  static func updateImageRowPlayingItem(listItem: CPListImageRowItem, itemId: String?) -> Int {
    imageRowPlaybackStates.updatePlayingItem(listItem: listItem, itemId: itemId)
  }
  private static func createImageRowElements(
    items: [NitroImageRowItem]
  ) -> [CPListImageRowItemCondensedElement] {
    items.map { item in
      let element = CPListImageRowItemCondensedElement(
        image: UIImage(),
        imageShape: .roundedRectangle,
        title: item.title,
        subtitle: nil,
        accessorySymbolName: item.accessorySystemImage
      )
      configurePlaybackConfiguration(
        item: element,
        duration: item.playbackDuration,
        elapsedTime: item.playbackElapsedTime
      )
      return element
    }
  }
  private static func createImageRowDescriptors(
    items: [NitroImageRowItem]
  ) -> [ImageRowPlaybackStateStore.Element] {
    items.map { item in
      ImageRowPlaybackStateStore.Element(
        id: item.id,
        accessorySystemImage: item.accessorySystemImage,
        playbackTimes: PlaybackConfigurationTimes(
          duration: item.playbackDuration,
          elapsedTime: item.playbackElapsedTime
        )
      )
    }
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
    listItem.setText(item.title)
    listItem.userInfo = item.id
    listItem.isEnabled = item.enabled
    if let imageUri = item.imageUri {
      SearchTestArtworkRequests.add(uri: imageUri, listItem: listItem)
    }
    listItem.handler = { _, completion in
      item.onPress?()
      completion()
    }
  }
}
