import CarPlay

// These stand-ins isolate the template from Nitro and application scene setup.
// The tested ListTemplate and all CarPlay template, section and item objects are real.
struct NitroRow {
  var id: String?
  var title: String
  var selected: Bool? = nil
  var imageRowItems: [String]? = nil
  var imageRowVariant: String? = nil
  var imageRowAllowsMultipleLines: Bool? = nil
  var onPress: (() -> Void)? = nil
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

class AutoPlayHeaderProviding {
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
  static var traitCollection = UITraitCollection(userInterfaceStyle: .light)
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
          if item.imageRowItems != nil {
            return CPListImageRowItem(text: item.title, elements: [], allowsMultipleLines: true)
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
    imageRowItems: [String],
    listItem: CPListImageRowItem,
    traitCollection: UITraitCollection
  ) {}
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
    listItem.handler = { _, completion in
      item.onPress?()
      completion()
    }
  }
}
