import CarPlay

typealias AutoPlayTemplate = AutoPlayHeaderProviding

struct SearchTemplateConfig {
  var id: String
  var title: String?
  var results: NitroSection
  var automaticallyPushResults: Bool? = nil
  var autoDismissMs: Double? = nil
  var headerActions: [String]? = nil
  var onWillAppear: ((Bool) -> Void)? = nil
  var onDidAppear: ((Bool) -> Void)? = nil
  var onWillDisappear: ((Bool) -> Void)? = nil
  var onDidDisappear: ((Bool) -> Void)? = nil
  var onPopped: (() -> Void)? = nil
  var onSearchTextChanged: (String) -> Void = { _ in }
  var onSearchTextSubmitted: (String) -> Void = { _ in }
}

extension ListTemplateConfig {
  init(
    id: String,
    onWillAppear: ((Bool) -> Void)?,
    onWillDisappear: ((Bool) -> Void)?,
    onDidAppear: ((Bool) -> Void)?,
    onDidDisappear: ((Bool) -> Void)?,
    onPopped: (() -> Void)?,
    autoDismissMs: Double?,
    detailsHeader: NitroListTemplateDetailsHeader?,
    headerActions: [String]?,
    title: String?,
    sections: [NitroSection]?,
    mapConfig: Never?
  ) {
    self.init(
      id: id,
      title: title,
      sections: sections,
      detailsHeader: detailsHeader,
      autoDismissMs: autoDismissMs,
      headerActions: headerActions,
      onWillAppear: onWillAppear,
      onDidAppear: onDidAppear,
      onWillDisappear: onWillDisappear,
      onDidDisappear: onDidDisappear,
      onPopped: onPopped
    )
  }
}

extension CPSearchTemplate {
  convenience init(id: String) {
    self.init()
    userInfo = id
  }
}

enum SearchTestArtworkRequests {
  static var pending: [(uri: String, listItem: CPListItem)] = []

  static func add(uri: String, listItem: CPListItem) {
    pending.append((uri, listItem))
  }

  static func complete(image: UIImage) {
    let requests = pending
    pending = []
    requests.forEach { $0.listItem.setImage(image) }
  }
}

struct SearchTestScene {
  let templateStore = SearchTestTemplateStore()
}

struct SearchTestTemplateStore {
  func addTemplate(template: AutoPlayTemplate, templateId: String) {}
}

struct SearchTestInterfaceController {
  func pushTemplate(_ template: CPTemplate, animated: Bool) async throws -> Bool { true }
}

enum RootModule {
  @MainActor
  static func withSceneAndInterfaceController<Result>(
    _ operation: (SearchTestScene, SearchTestInterfaceController) async throws -> Result
  ) async rethrows -> Result {
    try await operation(SearchTestScene(), SearchTestInterfaceController())
  }
}
