import CarPlay
import CoreMedia
import XCTest

@available(iOS 26.4, *)
@MainActor
final class ImageRowPlaybackStateTests: XCTestCase {
  override func setUp() {
    super.setUp()
    SceneStore.traitCollection = UITraitCollection(userInterfaceStyle: .light)
  }

  func testStartSwitchAndPauseKeepTheNativeRowAndSectionMounted() throws {
    let list = makeList()
    let template = list.template
    let section = template.sections[0]
    let row = try imageRow(in: list)

    list.updatePlayingItem(itemId: "first")
    XCTAssertEqual(try element(in: row, at: 0).accessorySymbolName, "waveform")
    XCTAssertEqual(try element(in: row, at: 0).playbackConfiguration?.playbackAction, .pause)
    XCTAssertEqual(try element(in: row, at: 1).playbackConfiguration?.playbackAction, .play)

    list.updatePlayingItem(itemId: "second")
    XCTAssertEqual(try element(in: row, at: 0).accessorySymbolName, "tray.and.arrow.down")
    XCTAssertEqual(try element(in: row, at: 0).playbackConfiguration?.playbackAction, .play)
    XCTAssertEqual(try element(in: row, at: 1).accessorySymbolName, "waveform")

    list.updatePlayingItem(itemId: nil)
    XCTAssertNil(try element(in: row, at: 1).accessorySymbolName)
    XCTAssertEqual(try element(in: row, at: 1).playbackConfiguration?.playbackAction, .play)
    XCTAssertTrue(list.template === template)
    XCTAssertTrue(list.template.sections[0] === section)
    XCTAssertTrue(try imageRow(in: list) === row)
  }

  func testRepeatedPlayingUpdateDoesNotReplaceTheConfiguration() throws {
    let list = makeList()
    list.updatePlayingItem(itemId: "first")
    let row = try imageRow(in: list)
    let configuration = try XCTUnwrap(element(in: row, at: 0).playbackConfiguration)

    list.updatePlayingItem(itemId: "first")

    XCTAssertTrue(try element(in: row, at: 0).playbackConfiguration === configuration)
  }

  func testPlayingActionPreservesPresentationAndPlaybackTimes() throws {
    let store = ImageRowPlaybackStateStore()
    let nativeElement = makeElement(title: "Track")
    nativeElement.playbackConfiguration = CPPlaybackConfiguration(
      preferredPresentation: .video,
      playbackAction: .play,
      elapsedTime: CMTime(seconds: 31, preferredTimescale: 1_000),
      duration: CMTime(seconds: 245, preferredTimescale: 1_000)
    )
    let row = CPListImageRowItem(text: "", condensedElements: [nativeElement], allowsMultipleLines: false)
    store.register(listItem: row, elements: [descriptor(id: "track")])

    XCTAssertEqual(store.updatePlayingItem(listItem: row, itemId: "track"), 1)

    let configuration = try XCTUnwrap(element(in: row, at: 0).playbackConfiguration)
    XCTAssertEqual(configuration.playbackAction, .pause)
    XCTAssertEqual(configuration.preferredPresentation, .video)
    XCTAssertEqual(configuration.elapsedTime.seconds, 31)
    XCTAssertEqual(configuration.duration.seconds, 245)
  }

  func testShowAllRemainsANavigationElementEvenWhenItsIdMatches() throws {
    let list = makeList()
    list.updatePlayingItem(itemId: "show-all")
    let action = try element(in: imageRow(in: list), at: 2)

    XCTAssertEqual(action.accessorySymbolName, "chevron.right")
    XCTAssertNil(action.playbackConfiguration)
  }

  func testDesiredPlayingIdAppliesWhenTheTrackArrivesInAContentUpdate() throws {
    let list = makeList()
    let section = list.template.sections[0]
    let row = try imageRow(in: list)
    list.updatePlayingItem(itemId: "new-track")

    list.updateSections(
      sections: sections(items: [
        NitroImageRowItem(id: "new-track", title: "New track", playbackDuration: 120, playbackElapsedTime: 5)
      ])
    )

    XCTAssertTrue(list.template.sections[0] === section)
    XCTAssertTrue(try imageRow(in: list) === row)
    XCTAssertEqual(try element(in: row, at: 0).accessorySymbolName, "waveform")
    XCTAssertEqual(try element(in: row, at: 0).playbackConfiguration?.playbackAction, .pause)
  }

  func testLateArtworkReplacementUsesTheLatestPlayingIdAndContentAccessories() throws {
    let store = ImageRowPlaybackStateStore()
    let row = CPListImageRowItem(text: "", condensedElements: [], allowsMultipleLines: false)
    store.replaceElements(
      listItem: row,
      elements: [makeElement(title: "First"), makeElement(title: "Second")],
      sourceElements: [descriptor(id: "first", accessory: "tray.and.arrow.down"), descriptor(id: "second")]
    )
    store.updatePlayingItem(listItem: row, itemId: "first")
    store.updatePlayingItem(listItem: row, itemId: "second")

    store.replaceElements(
      listItem: row,
      elements: [makeElement(title: "First artwork"), makeElement(title: "Second artwork")]
    )

    XCTAssertEqual(try element(in: row, at: 0).accessorySymbolName, "tray.and.arrow.down")
    XCTAssertEqual(try element(in: row, at: 1).accessorySymbolName, "waveform")
    XCTAssertEqual(try element(in: row, at: 1).playbackConfiguration?.playbackAction, .pause)

    store.replaceElements(
      listItem: row,
      elements: [makeElement(title: "Updated first"), makeElement(title: "Updated second")],
      sourceElements: [descriptor(id: "first", accessory: "checkmark"), descriptor(id: "second")]
    )
    store.updatePlayingItem(listItem: row, itemId: nil)
    XCTAssertEqual(try element(in: row, at: 0).accessorySymbolName, "checkmark")
    XCTAssertNil(try element(in: row, at: 1).accessorySymbolName)
  }

  func testImageGridRestoresItsAccessoryWhenPlaybackStops() throws {
    let store = ImageRowPlaybackStateStore()
    let element = CPListImageRowItemImageGridElement(
      image: UIImage(),
      imageShape: .roundedRectangle,
      title: "Track",
      accessorySymbolName: "tray.and.arrow.down"
    )
    configurePlaybackConfiguration(item: element, duration: 0, elapsedTime: 0)
    let row = CPListImageRowItem(text: "", imageGridElements: [element], allowsMultipleLines: false)
    store.register(listItem: row, elements: [descriptor(id: "track", accessory: "tray.and.arrow.down")])

    store.updatePlayingItem(listItem: row, itemId: "track")
    XCTAssertEqual(
      try XCTUnwrap(row.elements[0] as? CPListImageRowItemImageGridElement).accessorySymbolName,
      "waveform"
    )
    store.updatePlayingItem(listItem: row, itemId: nil)
    XCTAssertEqual(
      try XCTUnwrap(row.elements[0] as? CPListImageRowItemImageGridElement).accessorySymbolName,
      "tray.and.arrow.down"
    )
  }

  func testOrdinaryListRowPlayingIndicatorStillUpdates() throws {
    let list = makeList()
    let ordinaryRow = try XCTUnwrap(list.template.sections[0].items[0] as? CPListItem)

    list.updatePlayingItem(itemId: "ordinary")
    XCTAssertTrue(ordinaryRow.isPlaying)
    XCTAssertEqual(try element(in: imageRow(in: list), at: 0).accessorySymbolName, "tray.and.arrow.down")
    list.updatePlayingItem(itemId: nil)
    XCTAssertFalse(ordinaryRow.isPlaying)
  }

  private func makeList() -> ListTemplate {
    let list = ListTemplate(config: ListTemplateConfig(id: "preview", title: "Pro Tebe", sections: sections()))
    list._invalidate()
    return list
  }

  private func sections(items: [NitroImageRowItem]? = nil) -> [NitroSection] {
    [
      NitroSection(
        title: "Preview",
        items: [
          NitroRow(id: "ordinary", title: "Ordinary track"),
          NitroRow(
            id: "preview-row",
            title: "",
            imageRowItems: items ?? [
              NitroImageRowItem(
                id: "first",
                title: "First",
                accessorySystemImage: "tray.and.arrow.down",
                playbackDuration: 120,
                playbackElapsedTime: 20
              ),
              NitroImageRowItem(
                id: "second",
                title: "Second",
                playbackDuration: 0,
                playbackElapsedTime: 0
              ),
              NitroImageRowItem(
                id: "show-all",
                title: "Zobrazit vše",
                accessorySystemImage: "chevron.right"
              ),
            ],
            imageRowVariant: "condensed",
            imageRowAllowsMultipleLines: false
          ),
        ]
      )
    ]
  }

  private func imageRow(in list: ListTemplate) throws -> CPListImageRowItem {
    try XCTUnwrap(list.template.sections[0].items[1] as? CPListImageRowItem)
  }

  private func element(in row: CPListImageRowItem, at index: Int) throws -> CPListImageRowItemCondensedElement {
    try XCTUnwrap(row.elements[index] as? CPListImageRowItemCondensedElement)
  }

  private func makeElement(title: String) -> CPListImageRowItemCondensedElement {
    let element = CPListImageRowItemCondensedElement(
      image: UIImage(),
      imageShape: .roundedRectangle,
      title: title,
      subtitle: nil,
      accessorySymbolName: nil
    )
    configurePlaybackConfiguration(item: element, duration: 120, elapsedTime: 20)
    return element
  }

  private func descriptor(id: String, accessory: String? = nil) -> ImageRowPlaybackStateStore.Element {
    ImageRowPlaybackStateStore.Element(
      id: id,
      accessorySystemImage: accessory,
      playbackTimes: PlaybackConfigurationTimes(duration: 120, elapsedTime: 20)
    )
  }
}
