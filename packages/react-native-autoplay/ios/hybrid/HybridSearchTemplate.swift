//
//  HybridSearchTemplate.swift
//  Pods
//
//  Created by Samuel Brucksch on 28.10.25.
//

import NitroModules

class HybridSearchTemplate: HybridSearchTemplateSpec {
    func createSearchTemplate(config: SearchTemplateConfig) throws {
        let template = SearchTemplate(config: config)

        try RootModule.withTemplateStore { templateStore in
            templateStore.addTemplate(
                template: template,
                templateId: config.id
            )
        }
    }

    func updateSearchResults(templateId: String, results: NitroSection, searchText: String?) throws
        -> Promise<Void>
    {
        return Promise.async {
            try await MainActor.run {
                try RootModule.withAutoPlayTemplate(templateId: templateId) {
                    (template: SearchTemplate) in
                    template.updateSearchResults(results: results, searchText: searchText)
                }
            }
        }
    }
}
