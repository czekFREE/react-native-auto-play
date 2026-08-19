//
//  HybridListTemplate.swift
//  Pods
//
//  Created by Manuel Auer on 15.10.25.
//

import NitroModules

class HybridListTemplate: HybridListTemplateSpec {
    func createListTemplate(config: ListTemplateConfig) throws {
        let template = ListTemplate(config: config)

        try RootModule.withTemplateStore { templateStore in
            templateStore.addTemplate(
                template: template,
                templateId: config.id
            )
        }
    }

    func updateListTemplateSections(
        templateId: String,
        sections: [NitroSection]?
    ) throws -> Promise<Void> {
        return Promise.async {
            try await MainActor.run {
                try RootModule.withAutoPlayTemplate(templateId: templateId) {
                    (template: ListTemplate) in
                    template.updateSections(sections: sections)
                }
            }
        }
    }

    func updateListTemplateContent(
        templateId: String,
        sections: [NitroSection]?,
        detailsHeader: NitroListTemplateDetailsHeader?
    ) throws -> Promise<Void> {
        return Promise.async {
            try await MainActor.run {
                try RootModule.withAutoPlayTemplate(templateId: templateId) {
                    (template: ListTemplate) in
                    template.updateContent(
                        sections: sections,
                        detailsHeader: detailsHeader
                    )
                }
            }
        }
    }

    func updateListTemplatePlayingItem(
        templateId: String,
        itemId: String?
    ) throws -> Promise<Void> {
        return Promise.async {
            try await MainActor.run {
                try RootModule.withAutoPlayTemplate(templateId: templateId) {
                    (template: ListTemplate) in
                    template.updatePlayingItem(itemId: itemId)
                }
            }
        }
    }

    func completeListItemPress(completionId: String) throws -> Promise<Void> {
        return Promise.async {
            ListItemPressCompletionStore.complete(completionId)
        }
    }
}
