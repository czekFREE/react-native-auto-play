//
//  SearchTemplate.swift
//  Pods
//
//  Created by Samuel Brucksch on 28.10.25.
//

import CarPlay

class SearchTemplate: AutoPlayTemplate, CPSearchTemplateDelegate {
    var template: CPSearchTemplate
    var config: SearchTemplateConfig
    var results: NitroSection

    override var autoDismissMs: Double? {
        return config.autoDismissMs
    }

    override func getTemplate() -> CPTemplate {
        return template
    }

    var completionHandler: (([CPListItem]) -> Void)?
    var pushedListTemplate: ListTemplate?
    var searchText = ""
    private var resultsSearchText = ""

    init(config: SearchTemplateConfig) {
        self.config = config
        results = config.results

        template = CPSearchTemplate(id: config.id)
    }

    deinit {
        completionHandler?([])
    }

    func updateSearchResults(results: NitroSection, searchText: String? = nil) {
        if let searchText,
            searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                != self.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        {
            return
        }

        self.results = results
        resultsSearchText = self.searchText
        guard SceneStore.getRootTraitCollection() != nil else {
            completePendingSearch(items: [])
            return
        }
        invalidate()
    }

    @MainActor
    override func _invalidate() {
        if let listTemplate = pushedListTemplate {
            listTemplate.updateSections(sections: [results])
        }

        guard completionHandler != nil else {
            return
        }

        guard
            resultsSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
                == searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            let traitCollection = SceneStore.getRootTraitCollection()
        else {
            completePendingSearch(items: [])
            return
        }

        let listItems = Parser.parseSearchResults(
            section: results,
            traitCollection: traitCollection
        )
        completePendingSearch(items: listItems)
    }

    override func onWillAppear(animated: Bool) {
        self.pushedListTemplate = nil
        config.onWillAppear?(animated)
    }

    override func onDidAppear(animated: Bool) {
        config.onDidAppear?(animated)
        template.delegate = self
    }

    override func onWillDisappear(animated: Bool) {
        completePendingSearch(items: [])
        config.onWillDisappear?(animated)
        template.delegate = nil
    }

    override func onDidDisappear(animated: Bool) {
        completePendingSearch(items: [])
        config.onDidDisappear?(animated)
    }

    override func onPopped() {
        completePendingSearch(items: [])
        config.onPopped?()
    }

    // MARK: - CPSearchTemplateDelegate

    func searchTemplate(
        _ searchTemplate: CPSearchTemplate,
        updatedSearchText searchText: String,
        completionHandler: @escaping ([CPListItem]) -> Void
    ) {
        completePendingSearch(items: [])
        let previousSearchText = self.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.searchText = searchText
        self.completionHandler = completionHandler

        if normalizedSearchText.isEmpty {
            results = config.results
            resultsSearchText = self.searchText
        }

        guard SceneStore.getRootTraitCollection() != nil else {
            completePendingSearch(items: [])
            if normalizedSearchText != previousSearchText {
                config.onSearchTextChanged(searchText)
            }
            return
        }

        if pushedListTemplate != nil
            || (normalizedSearchText == previousSearchText
                && resultsSearchText.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedSearchText)
        {
            invalidate()
            return
        }

        if normalizedSearchText == previousSearchText {
            return
        }

        if normalizedSearchText.isEmpty {
            invalidate()
        }
        config.onSearchTextChanged(searchText)
    }

    func searchTemplate(
        _ searchTemplate: CPSearchTemplate,
        selectedResult item: CPListItem,
        completionHandler: @escaping () -> Void
    ) {
        guard let handler = item.handler else {
            completionHandler()
            return
        }
        handler(item, completionHandler)
    }

    func searchTemplateSearchButtonPressed(
        _ searchTemplate: CPSearchTemplate
    ) {
        completePendingSearch(items: [])
        if config.automaticallyPushResults == false {
            config.onSearchTextSubmitted(searchText)
            return
        }

        guard pushedListTemplate == nil else {
            return
        }

        let listConfig = ListTemplateConfig(
            id: "\(config.id)-results",
            onWillAppear: nil,
            onWillDisappear: nil,
            onDidAppear: nil,
            onDidDisappear: nil,
            onPopped: nil,
            autoDismissMs: nil,
            detailsHeader: nil,
            headerActions: config.headerActions,
            title: config.title,
            sections: [results],
            mapConfig: nil
        )

        let listTemplate = ListTemplate(config: listConfig)
        self.pushedListTemplate = listTemplate

        // execute callback after creating the template to avoid race condition in updateSearchResults
        config.onSearchTextSubmitted(searchText)

        Task { @MainActor in
            do {
                try await RootModule.withSceneAndInterfaceController {
                    scene,
                    interfaceController in

                    scene.templateStore.addTemplate(
                        template: listTemplate,
                        templateId: listConfig.id
                    )

                    listTemplate.invalidate()

                    let _ = try await interfaceController.pushTemplate(
                        listTemplate.template,
                        animated: true
                    )
                }
            }
            catch {
                AutoPlayDevelopmentLogger.log(
                    "[AutoPlay] Failed to push list template: \(error)"
                )
            }
        }
    }

    private func completePendingSearch(items: [CPListItem]) {
        let completionHandler = self.completionHandler
        self.completionHandler = nil
        completionHandler?(items)
    }
}
