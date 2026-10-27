import CarPlay
import XCTest

@available(iOS 26.4, *)
@MainActor
final class ListTemplateHeaderTests: XCTestCase {
  override func setUp() {
    super.setUp()
    SceneStore.traitCollection = UITraitCollection(userInterfaceStyle: .light)
  }

  func testAppendingEpisodesPreservesUnchangedHeader() {
    let list = makeList()
    list._invalidate()
    let initialHeader = list.template.listHeader
    XCTAssertNotNil(initialHeader)

    list.updateContent(
      sections: makeSections(count: 2),
      detailsHeader: makeHeader()
    )

    XCTAssertEqual(list.template.itemCount, 2)
    XCTAssertTrue(list.template.listHeader === initialHeader)
  }

  func testUpdatingHeaderContentReplacesHeaderWithoutChangingRows() {
    let list = makeList()
    list._invalidate()
    let initialHeader = list.template.listHeader

    list.updateContent(
      sections: makeSections(count: 1),
      detailsHeader: makeHeader(title: "Updated show")
    )

    XCTAssertEqual(list.template.listHeader?.title, "Updated show")
    XCTAssertFalse(list.template.listHeader === initialHeader)
  }

  func testRemovingHeaderClearsIt() {
    let list = makeList()
    list._invalidate()

    list.updateContent(sections: makeSections(count: 2), detailsHeader: nil)

    XCTAssertNil(list.template.listHeader)
  }

  func testChangedColorAppearanceRebuildsHeader() {
    let list = makeList()
    list._invalidate()
    let initialHeader = list.template.listHeader
    SceneStore.traitCollection = UITraitCollection(userInterfaceStyle: .dark)

    list._invalidate()

    XCTAssertNotNil(list.template.listHeader)
    XCTAssertFalse(list.template.listHeader === initialHeader)
  }

  func testEquivalentTraitCollectionsPreserveHeader() {
    let list = makeList()
    list._invalidate()
    let initialHeader = list.template.listHeader
    SceneStore.traitCollection = UITraitCollection(userInterfaceStyle: .light)

    list._invalidate()

    XCTAssertTrue(list.template.listHeader === initialHeader)
  }

  private func makeList() -> ListTemplate {
    ListTemplate(
      config: ListTemplateConfig(
        id: "show-detail",
        title: "Show",
        sections: makeSections(count: 1),
        detailsHeader: makeHeader()
      )
    )
  }

  private func makeHeader(title: String = "Show") -> NitroListTemplateDetailsHeader {
    NitroListTemplateDetailsHeader(title: title)
  }

  private func makeSections(count: Int) -> [NitroSection] {
    [
      NitroSection(
        title: "Episodes",
        items: (1...count).map { index in
          NitroRow(id: "episode-\(index)", title: "Episode \(index)")
        }
      )
    ]
  }
}
