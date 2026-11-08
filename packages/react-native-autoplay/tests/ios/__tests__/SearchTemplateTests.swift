import CarPlay
import XCTest

@MainActor
final class SearchTemplateTests: XCTestCase {
  override func setUp() {
    super.setUp()
    SceneStore.traitCollection = UITraitCollection(userInterfaceStyle: .light)
    SearchTestArtworkRequests.pending = []
  }

  func testInitialAndRepeatedEmptyQueryCompleteWithConfiguredResults() {
    let search = makeSearch()
    var completions: [[String?]] = []

    for _ in 0..<2 {
      updateQuery(search, text: "") { completions.append($0.map(\.text)) }
    }

    XCTAssertEqual(completions.count, 2)
    XCTAssertEqual(completions[0], ["Initial show"])
    XCTAssertEqual(completions[1], ["Initial show"])
    XCTAssertNil(search.completionHandler)
  }

  func testInitialEmptyQueriesExposeConfiguredBackRowBeforeAppearance() throws {
    var backSelections = 0
    let search = makeSearch(
      results: NitroSection(
        title: nil,
        items: [NitroRow(id: "back", title: "Zpět", onPress: { backSelections += 1 })]
      ))
    let delegate = try XCTUnwrap(search.template.delegate)
    var completions: [[CPListItem]] = []

    for _ in 0..<2 {
      delegate.searchTemplate(search.template, updatedSearchText: "") { completions.append($0) }
    }

    XCTAssertEqual(completions.map { $0.map(\.text) }, [["Zpět"], ["Zpět"]])
    var selectionCompletions = 0
    delegate.searchTemplate(
      search.template,
      selectedResult: try XCTUnwrap(completions.first?.first)
    ) { selectionCompletions += 1 }

    XCTAssertEqual(backSelections, 1)
    XCTAssertEqual(selectionCompletions, 1)
    XCTAssertNil(search.completionHandler)
  }

  func testReturningSearchExposesResultsDuringWillAppearBeforeDidAppear() {
    let search = makeSearch(results: makeResults(title: "Zpět"))
    var completions: [[String?]] = []
    search.onWillDisappear(animated: true)
    XCTAssertNil(search.template.delegate)
    search.config.onWillAppear = { _ in
      search.template.delegate?.searchTemplate(search.template, updatedSearchText: "") {
        completions.append($0.map(\.text))
      }
    }

    search.onWillAppear(animated: true)
    search.config.onWillAppear = nil

    XCTAssertEqual(completions, [["Zpět"]])
    XCTAssertNil(search.completionHandler)
  }

  func testFirstNonemptyCallbackRequestsSearchInsteadOfLosingEnteredText() {
    let search = makeSearch()
    var queries: [String] = []
    search.config.onSearchTextChanged = { queries.append($0) }

    updateQuery(search, text: "podcast") { _ in }

    XCTAssertEqual(queries, ["podcast"])
  }

  func testSupersededCompletionSettlesAndOldResultsCannotCompleteNewQuery() {
    let search = makeSearch()
    var firstCompletions: [[String?]] = []
    var secondCompletions: [[String?]] = []
    updateQuery(search, text: "first") { firstCompletions.append($0.map(\.text)) }
    updateQuery(search, text: "second") { secondCompletions.append($0.map(\.text)) }

    XCTAssertEqual(firstCompletions.count, 1)
    XCTAssertEqual(firstCompletions[0], [])
    search.updateSearchResults(results: makeResults(title: "Stale show"), searchText: "first")
    XCTAssertTrue(secondCompletions.isEmpty)
    search.updateSearchResults(results: makeResults(title: "Current show"), searchText: "second")
    search._invalidate()

    XCTAssertEqual(firstCompletions.count, 1)
    XCTAssertEqual(secondCompletions.count, 1)
    XCTAssertEqual(secondCompletions[0], ["Current show"])
    XCTAssertNil(search.completionHandler)
  }

  func testRepeatedPendingQueryKeepsLatestCompletionUntilResultsArrive() {
    let search = makeSearch()
    var changedQueries: [String] = []
    var firstCompletions = 0
    var secondCompletions: [[String?]] = []
    search.config.onSearchTextChanged = { changedQueries.append($0) }
    updateQuery(search, text: "podcast") { _ in firstCompletions += 1 }
    updateQuery(search, text: "podcast") { secondCompletions.append($0.map(\.text)) }

    XCTAssertEqual(firstCompletions, 1)
    XCTAssertTrue(secondCompletions.isEmpty)
    XCTAssertEqual(changedQueries, ["podcast"])
    search.updateSearchResults(results: makeResults(title: "Podcast show"), searchText: "podcast")

    XCTAssertEqual(secondCompletions.count, 1)
    XCTAssertEqual(secondCompletions[0], ["Podcast show"])
  }

  func testQueryAssociationTrimsWhitespaceWithoutIgnoringCase() {
    let search = makeSearch()
    var completions: [[String?]] = []
    updateQuery(search, text: " Podcast  ") { completions.append($0.map(\.text)) }
    search.updateSearchResults(results: makeResults(title: "Wrong case"), searchText: "podcast")
    XCTAssertTrue(completions.isEmpty)

    search.updateSearchResults(results: makeResults(title: "Matching show"), searchText: "Podcast")

    XCTAssertEqual(completions.count, 1)
    XCTAssertEqual(completions[0], ["Matching show"])
  }

  func testCompletionWaitsForTerminalResultsAndRepeatedQueryRetainsThoseResults() {
    let search = makeSearch()
    var completions: [[String?]] = []
    var queries: [String] = []
    search.config.onSearchTextChanged = { queries.append($0) }
    updateQuery(search, text: "podcast") { completions.append($0.map(\.text)) }

    XCTAssertTrue(completions.isEmpty)
    XCTAssertNotNil(search.completionHandler)
    search.updateSearchResults(results: makeResults(title: "Matching show"), searchText: "podcast")
    updateQuery(search, text: "podcast") { completions.append($0.map(\.text)) }

    XCTAssertEqual(queries, ["podcast"])
    XCTAssertEqual(completions.count, 2)
    XCTAssertEqual(completions[0], ["Matching show"])
    XCTAssertEqual(completions[1], ["Matching show"])
    XCTAssertNil(search.completionHandler)
  }

  func testWhitespaceOnlyQueryChangeReturnsRetainedResultsWithoutAnotherRequest() {
    let search = makeSearch()
    var queries: [String] = []
    var completions: [[String?]] = []
    search.config.onSearchTextChanged = { queries.append($0) }
    updateQuery(search, text: "podcast") { completions.append($0.map(\.text)) }
    search.updateSearchResults(results: makeResults(title: "Podcast"), searchText: "podcast")

    updateQuery(search, text: " podcast ") { completions.append($0.map(\.text)) }

    XCTAssertEqual(queries, ["podcast"])
    XCTAssertEqual(completions.count, 2)
    XCTAssertEqual(completions[1], ["Podcast"])
    XCTAssertNil(search.completionHandler)
  }

  func testClearingQuerySettlesPendingSearchAndRestoresInitialResults() {
    let search = makeSearch()
    var firstCompletions = 0
    var emptyCompletions: [[String?]] = []
    var queries: [String] = []
    search.config.onSearchTextChanged = { queries.append($0) }
    updateQuery(search, text: "podcast") { _ in firstCompletions += 1 }
    updateQuery(search, text: " ") { emptyCompletions.append($0.map(\.text)) }

    XCTAssertEqual(firstCompletions, 1)
    XCTAssertEqual(emptyCompletions.count, 1)
    XCTAssertEqual(emptyCompletions[0], ["Initial show"])
    XCTAssertEqual(queries, ["podcast", " "])
    XCTAssertNil(search.completionHandler)
  }

  func testClearingCompletedQueryRestoresConfiguredBackRowAndSelectionHandler() throws {
    var backSelections = 0
    let search = SearchTemplate(
      config: SearchTemplateConfig(
        id: "search-input",
        title: "Hledat",
        results: NitroSection(
          title: nil,
          items: [
            NitroRow(id: "back", title: "Zpět", onPress: { backSelections += 1 }),
            NitroRow(id: "hint", title: "Zadejte hledaný výraz"),
          ]
        )
      )
    )
    var completedQueryResults: [[String?]] = []
    var emptyQueryResults: [[CPListItem]] = []
    updateQuery(search, text: "podcast") { completedQueryResults.append($0.map(\.text)) }
    search.updateSearchResults(results: makeResults(title: "Matching show"), searchText: "podcast")

    updateQuery(search, text: "") { emptyQueryResults.append($0) }
    search.updateSearchResults(results: makeResults(title: "Late show"), searchText: "podcast")
    search._invalidate()

    XCTAssertEqual(completedQueryResults, [["Matching show"]])
    XCTAssertEqual(emptyQueryResults.count, 1)
    XCTAssertEqual(
      try XCTUnwrap(emptyQueryResults.first).map(\.text), ["Zpět", "Zadejte hledaný výraz"])
    var selectionCompletions = 0
    search.searchTemplate(
      search.template,
      selectedResult: try XCTUnwrap(emptyQueryResults.first?.first)
    ) { selectionCompletions += 1 }
    search.onPopped()

    XCTAssertEqual(backSelections, 1)
    XCTAssertEqual(selectionCompletions, 1)
    XCTAssertEqual(emptyQueryResults.count, 1)
    XCTAssertNil(search.completionHandler)
  }

  func testClearingWithoutTraitsRestoresInitialResultsWhenTraitsReturn() {
    let search = makeSearch()
    updateQuery(search, text: "podcast") { _ in }
    search.updateSearchResults(results: makeResults(title: "Matching show"), searchText: "podcast")
    var completions: [[String?]] = []
    SceneStore.traitCollection = nil

    updateQuery(search, text: "") { completions.append($0.map(\.text)) }
    SceneStore.traitCollection = UITraitCollection(userInterfaceStyle: .light)
    updateQuery(search, text: "") { completions.append($0.map(\.text)) }

    XCTAssertEqual(completions, [[], ["Initial show"]])
    XCTAssertNil(search.completionHandler)
  }

  func testMissingTraitsAlwaysSettlesCompletion() {
    let search = makeSearch()
    var completions = 0
    var queries: [String] = []
    search.config.onSearchTextChanged = { queries.append($0) }
    SceneStore.traitCollection = nil
    updateQuery(search, text: "podcast") { items in
      completions += 1
      XCTAssertTrue(items.isEmpty)
    }
    search.updateSearchResults(results: makeResults(title: "Show"), searchText: "podcast")

    XCTAssertEqual(completions, 1)
    XCTAssertEqual(queries, ["podcast"])
    XCTAssertNil(search.completionHandler)
  }

  func testTraitlessQueryCanReceiveResultsAndCompleteRepeatedCallbackAfterTraitsReturn() {
    let search = makeSearch()
    var completions: [[String?]] = []
    SceneStore.traitCollection = nil
    updateQuery(search, text: "podcast") { completions.append($0.map(\.text)) }
    search.updateSearchResults(results: makeResults(title: "Show"), searchText: "podcast")
    SceneStore.traitCollection = UITraitCollection(userInterfaceStyle: .light)

    updateQuery(search, text: "podcast") { completions.append($0.map(\.text)) }

    XCTAssertEqual(completions.count, 2)
    XCTAssertEqual(completions[0], [])
    XCTAssertEqual(completions[1], ["Show"])
  }

  func testDeallocationCompletesPendingCallbackWithoutPopEvent() {
    var search: SearchTemplate? = makeSearch()
    var completions = 0
    if let search {
      updateQuery(search, text: "podcast") { _ in completions += 1 }
    }

    search = nil

    XCTAssertEqual(completions, 1)
  }

  func testLosingTraitsWhileRequestIsPendingSettlesCompletion() {
    let search = makeSearch()
    var completions = 0
    updateQuery(search, text: "podcast") { items in
      completions += 1
      XCTAssertTrue(items.isEmpty)
    }
    SceneStore.traitCollection = nil

    search.updateSearchResults(results: makeResults(title: "Show"), searchText: "podcast")

    XCTAssertEqual(completions, 1)
    XCTAssertNil(search.completionHandler)
  }

  func testDisappearanceAndPopCompletePendingCallbackOnlyOnce() {
    let search = makeSearch()
    var completions = 0
    updateQuery(search, text: "podcast") { _ in completions += 1 }

    search.onWillDisappear(animated: true)
    search.onPopped()
    search.updateSearchResults(results: makeResults(title: "Late show"), searchText: "podcast")

    XCTAssertEqual(completions, 1)
    XCTAssertNil(search.completionHandler)
  }

  func testReappearanceRestoresDelegateAndAllowsAnotherQuery() {
    let search = makeSearch()
    search.onDidAppear(animated: false)
    XCTAssertTrue(search.template.delegate === search)
    search.onWillDisappear(animated: true)
    XCTAssertNil(search.template.delegate)
    search.onWillAppear(animated: true)
    search.onDidAppear(animated: true)
    var completions: [[String?]] = []
    updateQuery(search, text: "another") { completions.append($0.map(\.text)) }
    search.updateSearchResults(results: makeResults(title: "Another show"), searchText: "another")

    XCTAssertTrue(search.template.delegate === search)
    XCTAssertEqual(completions.count, 1)
    XCTAssertEqual(completions[0], ["Another show"])
  }

  func testManagedSubmissionCallsApplicationWithoutCreatingInternalResults() {
    let search = makeSearch(automaticallyPushResults: false)
    var submitted: [String] = []
    var completions = 0
    search.config.onSearchTextSubmitted = { submitted.append($0) }
    updateQuery(search, text: "podcast") { _ in completions += 1 }

    search.searchTemplateSearchButtonPressed(search.template)

    XCTAssertEqual(submitted, ["podcast"])
    XCTAssertEqual(completions, 1)
    XCTAssertNil(search.pushedListTemplate)
  }

  func testAutomaticSubmissionRemainsDefaultAndDuplicateSubmitDoesNotCreateAnotherList() {
    let search = makeSearch()
    var submitted: [String] = []
    search.config.onSearchTextSubmitted = { submitted.append($0) }

    search.searchTemplateSearchButtonPressed(search.template)
    let results = search.pushedListTemplate
    search.searchTemplateSearchButtonPressed(search.template)

    XCTAssertNotNil(results)
    XCTAssertTrue(search.pushedListTemplate === results)
    XCTAssertEqual(submitted, [""])
  }

  func testSelectingResultWithoutHandlerCompletesImmediately() {
    let search = makeSearch()
    var completions = 0

    search.searchTemplate(
      search.template,
      selectedResult: CPListItem(text: "Noninteractive", detailText: nil),
      completionHandler: { completions += 1 }
    )

    XCTAssertEqual(completions, 1)
  }

  func testSelectingResultInvokesExistingHandlerAndItsCompletion() {
    let search = makeSearch()
    let row = CPListItem(text: "Podcast", detailText: nil)
    var selected = false
    var completions = 0
    row.handler = { _, completion in
      selected = true
      completion()
    }

    search.searchTemplate(search.template, selectedResult: row) { completions += 1 }

    XCTAssertTrue(selected)
    XCTAssertEqual(completions, 1)
  }

  func testSearchRowsArriveBeforeArtworkAndRetainIdentityWhenArtworkCompletes() throws {
    let rows = Parser.parseSearchResults(
      section: NitroSection(
        title: nil,
        items: [
          NitroRow(id: "show", title: "Podcast", imageUri: "https://example.com/artwork.png")
        ]),
      traitCollection: UITraitCollection(userInterfaceStyle: .light)
    )
    let row = try XCTUnwrap(rows.first)

    XCTAssertEqual(row.text, "Podcast")
    XCTAssertNil(row.image)
    XCTAssertEqual(SearchTestArtworkRequests.pending.count, 1)
    SearchTestArtworkRequests.complete(image: try XCTUnwrap(UIImage(systemName: "play")))

    XCTAssertTrue(rows.first === row)
    XCTAssertNotNil(row.image)
    XCTAssertTrue(SearchTestArtworkRequests.pending.isEmpty)
  }

  func testSearchRowsHonorDisabledStateAndSelectionHandler() throws {
    var selected = false
    let rows = Parser.parseSearchResults(
      section: NitroSection(
        title: nil,
        items: [
          NitroRow(id: "disabled", title: "Disabled", enabled: false),
          NitroRow(id: "show", title: "Podcast", onPress: { selected = true }),
        ]),
      traitCollection: UITraitCollection(userInterfaceStyle: .light)
    )

    XCTAssertFalse(try XCTUnwrap(rows.first).isEnabled)
    let row = try XCTUnwrap(rows.last)
    var completions = 0
    row.handler?(row, { completions += 1 })
    XCTAssertTrue(selected)
    XCTAssertEqual(completions, 1)
  }

  private func makeSearch(automaticallyPushResults: Bool? = nil, results: NitroSection? = nil)
    -> SearchTemplate
  {
    SearchTemplate(
      config: SearchTemplateConfig(
        id: "search-input",
        title: "Hledat",
        results: results ?? makeResults(title: "Initial show"),
        automaticallyPushResults: automaticallyPushResults
      ))
  }

  private func makeResults(title: String) -> NitroSection {
    NitroSection(title: nil, items: [NitroRow(id: "show", title: title)])
  }

  private func updateQuery(
    _ search: SearchTemplate,
    text: String,
    completion: @escaping ([CPListItem]) -> Void
  ) {
    search.searchTemplate(search.template, updatedSearchText: text, completionHandler: completion)
  }
}
