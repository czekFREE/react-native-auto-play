import NitroModules

class HybridTabBarTemplate: HybridTabBarTemplateSpec {
    func createTabBarTemplate(config: TabBarTemplateConfig) throws {
        try RootModule.withTemplateStore { templateStore in
            let childTemplates = try config.tabs.map { tab in
                try templateStore.getTemplate(templateId: tab.templateId)
            }
            let template = try TabBarTemplate(
                config: config,
                childTemplates: childTemplates
            )

            templateStore.addTemplate(
                template: template,
                templateId: config.id
            )
        }
    }

    func selectTabBarTemplateTab(
        tabBarTemplateId: String,
        selectedTemplateId: String
    ) throws -> Promise<Void> {
        return Promise.async {
            try await MainActor.run {
                try RootModule.withAutoPlayTemplate(
                    templateId: tabBarTemplateId
                ) {
                    (template: TabBarTemplate) in
                    try template.selectTab(templateId: selectedTemplateId)
                }
            }
        }
    }
}
