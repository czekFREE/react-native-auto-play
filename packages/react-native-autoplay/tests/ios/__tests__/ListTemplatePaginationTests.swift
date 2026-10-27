import CarPlay
import XCTest

@MainActor
final class ListTemplatePaginationTests: XCTestCase {
  override func setUp() {
    super.setUp()
    SceneStore.traitCollection = UITraitCollection(userInterfaceStyle: .light)
  }

  func testAppendingPageRetainsLoadedRowsAndPlayingIndicator() throws {
    let list = makeList(ids: ["show-1", "show-2", "load-more"])
    let initialRows = list.template.sections[0].items
    list.updatePlayingItem(itemId: "show-2")

    list.updateSections(sections: makeSections(ids: ["show-1", "show-2", "show-3", "load-more"]))

    let rows = list.template.sections[0].items
    XCTAssertEqual(rows.count, 4)
    XCTAssertTrue(rows[0] === initialRows[0])
    XCTAssertTrue(rows[1] === initialRows[1])
    XCTAssertTrue(rows[3] === initialRows[2])
    XCTAssertTrue(try XCTUnwrap(rows[1] as? CPListItem).isPlaying)
  }

  func testRemovalAndReorderRetainMatchingRows() {
    let list = makeList(ids: ["show-1", "show-2", "show-3"])
    let initialRows = list.template.sections[0].items

    list.updateSections(sections: makeSections(ids: ["show-3", "show-1"]))

    let rows = list.template.sections[0].items
    XCTAssertEqual(rows.count, 2)
    XCTAssertTrue(rows[0] === initialRows[2])
    XCTAssertTrue(rows[1] === initialRows[0])
  }

  func testDuplicateIdsDoNotReuseOneObjectForTwoRows() {
    let list = makeList(ids: ["show-1"])
    let initialRow = list.template.sections[0].items[0]

    list.updateSections(sections: makeSections(ids: ["show-1", "show-1"]))

    let rows = list.template.sections[0].items
    XCTAssertEqual(rows.count, 2)
    XCTAssertFalse(rows[0] === rows[1])
    XCTAssertFalse(rows[0] === initialRow)
    XCTAssertFalse(rows[1] === initialRow)
  }

  func testPreviouslyAmbiguousIdsAreNotReused() {
    let list = makeList(ids: ["show-1", "show-1"])
    let initialRows = list.template.sections[0].items

    list.updateSections(sections: makeSections(ids: ["show-1"]))

    let row = list.template.sections[0].items[0]
    XCTAssertFalse(row === initialRows[0])
    XCTAssertFalse(row === initialRows[1])
    XCTAssertEqual(row.text, "Show show-1")
  }

  func testTraitChangeRecreatesRowsForNewArtworkAppearance() {
    let list = makeList(ids: ["show-1"])
    let initialRow = list.template.sections[0].items[0]
    SceneStore.traitCollection = UITraitCollection(userInterfaceStyle: .dark)

    list._invalidate()

    let row = list.template.sections[0].items[0]
    XCTAssertFalse(row === initialRow)
    XCTAssertEqual(row.text, "Show show-1")
  }

  func testRetainedRowReceivesUpdatedContentAndHandler() throws {
    let list = makeList(ids: ["show-1"])
    let initialRow = try XCTUnwrap(list.template.sections[0].items[0] as? CPListItem)
    var pressedShow = ""

    list.updateSections(sections: [
      NitroSection(
        title: "Shows",
        items: [
          NitroRow(id: "show-2", title: "Another show"),
          NitroRow(id: "show-1", title: "Updated show", onPress: { pressedShow = "show-1" }),
        ])
    ])

    let updatedRow = try XCTUnwrap(list.template.sections[0].items[1] as? CPListItem)
    XCTAssertTrue(updatedRow === initialRow)
    XCTAssertEqual(updatedRow.text, "Updated show")
    updatedRow.handler?(updatedRow, {})
    XCTAssertEqual(pressedShow, "show-1")
  }

  func testImageRowsAreNotReusedAsStandardRows() {
    let list = makeList(ids: ["show-1"])
    let standardRow = list.template.sections[0].items[0]

    list.updateSections(sections: [
      NitroSection(
        title: "Shows",
        items: [
          NitroRow(id: "show-1", title: "Artwork", imageRowItems: ["image"]),
          NitroRow(id: "show-2", title: "Another show"),
        ])
    ])
    let imageRow = list.template.sections[0].items[0]
    XCTAssertTrue(imageRow is CPListImageRowItem)
    XCTAssertFalse(imageRow === standardRow)

    list.updateSections(sections: makeSections(ids: ["show-1"]))
    let updatedRow = list.template.sections[0].items[0]
    XCTAssertTrue(updatedRow is CPListItem)
    XCTAssertFalse(updatedRow === imageRow)
    XCTAssertEqual(updatedRow.text, "Show show-1")
  }

  func testSameStructureUpdatesDoNotReplaceNativeSection() {
    let list = makeList(ids: ["show-1", "load-more"])
    let initialSection = list.template.sections[0]

    list.updateSections(sections: [
      NitroSection(
        title: "Shows",
        items: [
          NitroRow(id: "show-1", title: "Show show-1"),
          NitroRow(id: "load-more", title: "Loading more shows"),
        ])
    ])

    XCTAssertTrue(list.template.sections[0] === initialSection)
    XCTAssertEqual(list.template.sections[0].items[1].text, "Loading more shows")
  }

  func testDeferredUpdatesReuseAppliedRowsInsteadOfPendingConfiguration() {
    let list = makeList(ids: ["show-1"])
    let initialRow = list.template.sections[0].items[0]
    list.deferInvalidation = true

    list.updateSections(sections: makeSections(ids: ["show-1", "show-2"]))
    list.updateSections(sections: makeSections(ids: ["show-2", "show-1", "show-3"]))
    list._invalidate()

    let rows = list.template.sections[0].items
    XCTAssertEqual(rows.map { $0.text }, ["Show show-2", "Show show-1", "Show show-3"])
    XCTAssertTrue(rows[1] === initialRow)
  }

  func testRowsAreNotReusedAcrossDifferentSectionHeaders() {
    let list = makeList(ids: ["show-1"])
    let initialRow = list.template.sections[0].items[0]

    list.updateSections(sections: [NitroSection(title: "Other collection", items: [
      NitroRow(id: "show-1", title: "Show show-1"),
      NitroRow(id: "show-2", title: "Show show-2")
    ])])

    XCTAssertFalse(list.template.sections[0].items[0] === initialRow)
    XCTAssertEqual(list.template.sections[0].header, "Other collection")
  }

  private func makeList(ids: [String]) -> ListTemplate {
    let list = ListTemplate(
      config: ListTemplateConfig(
        id: "shows",
        title: "Shows",
        sections: makeSections(ids: ids),
        detailsHeader: nil
      ))
    list._invalidate()
    return list
  }

  private func makeSections(ids: [String]) -> [NitroSection] {
    [NitroSection(title: "Shows", items: ids.map { NitroRow(id: $0, title: "Show \($0)") })]
  }
}
