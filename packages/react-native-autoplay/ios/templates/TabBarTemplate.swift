import CarPlay

class TabBarTemplate: AutoPlayTemplate, CPTabBarTemplateDelegate {
    let template: CPTabBarTemplate
    let config: TabBarTemplateConfig
    let childTemplates: [AutoPlayTemplate]

    override var autoDismissMs: Double? {
        return config.autoDismissMs
    }

    override func getTemplate() -> CPTemplate {
        return template
    }

    init(config: TabBarTemplateConfig, childTemplates: [AutoPlayTemplate])
        throws
    {
        guard config.tabs.count == childTemplates.count else {
            throw AutoPlayError.invalidTemplateType(
                "Tab bar configuration and child template counts do not match"
            )
        }

        guard childTemplates.count <= CPTabBarTemplate.maximumTabCount else {
            throw AutoPlayError.invalidTemplateType(
                "Tab bar contains \(childTemplates.count) tabs, maximum is \(CPTabBarTemplate.maximumTabCount)"
            )
        }

        self.config = config
        self.childTemplates = childTemplates

        let carPlayTemplates = childTemplates.map { childTemplate in
            childTemplate.getTemplate()
        }

        for (index, childTemplate) in carPlayTemplates.enumerated() {
            childTemplate.tabTitle = config.tabs[index].title
        }

        template = CPTabBarTemplate(
            templates: carPlayTemplates,
            id: config.id
        )

        super.init()

        template.delegate = self
    }

    @MainActor
    override func _invalidate() {
        for childTemplate in childTemplates {
            childTemplate.invalidate()
        }
    }

    override func onWillAppear(animated: Bool) {
        config.onWillAppear?(animated)
    }

    override func onDidAppear(animated: Bool) {
        config.onDidAppear?(animated)
    }

    override func onWillDisappear(animated: Bool) {
        config.onWillDisappear?(animated)
    }

    override func onDidDisappear(animated: Bool) {
        config.onDidDisappear?(animated)
    }

    override func onPopped() {
        config.onPopped?()
    }

    @MainActor
    func selectTab(templateId: String) throws {
        guard #available(iOS 17.0, *) else {
            throw AutoPlayError.invalidTemplateType(
                "Programmatic tab selection requires iOS 17.0 or newer"
            )
        }

        guard
            let selectedTemplate = childTemplates.first(where: {
                $0.getTemplate().autoPlayId == templateId
            })
        else {
            throw AutoPlayError.templateNotFound(templateId)
        }

        template.select(selectedTemplate.getTemplate())
    }

    func tabBarTemplate(
        _ tabBarTemplate: CPTabBarTemplate,
        didSelect selectedTemplate: CPTemplate
    ) {
        guard let templateId = selectedTemplate.autoPlayId else { return }

        config.onTabSelected?(templateId)
    }
}
