//
//  AutoPlayInterfaceController.swift
//  Pods
//
//  Created by Manuel Auer on 12.10.25.
//

import CarPlay

@MainActor
class AutoPlayInterfaceController: NSObject, CPInterfaceControllerDelegate {
    let interfaceController: CPInterfaceController

    init(
        interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        super.init()

        self.interfaceController.delegate = self
    }

    var carTraitCollection: UITraitCollection {
        return interfaceController.carTraitCollection
    }

    var rootTemplate: CPTemplate {
        interfaceController.rootTemplate
    }

    var topTemplate: CPTemplate? {
        interfaceController.topTemplate
    }

    var templates: [CPTemplate] {
        interfaceController.templates
    }

    var topTemplateId: String? {
        return interfaceController.topTemplate?.autoPlayId
    }

    var rootTemplateId: String? {
        return interfaceController.rootTemplate.autoPlayId
    }

    func pushTemplate(
        _ templateToPush: CPTemplate,
        animated: Bool
    ) async throws -> Bool {
        return try await interfaceController.pushTemplate(
            templateToPush,
            animated: animated
        )
    }

    func setRootTemplate(
        _ rootTemplate: CPTemplate,
        animated: Bool
    ) async throws -> Bool {
        return try await interfaceController.setRootTemplate(
            rootTemplate,
            animated: animated
        )
    }

    func popTemplate(
        animated: Bool
    ) async throws -> String? {
        guard let templateId = topTemplateId else { return nil }

        // Ensure at least one template remains
        guard templates.count > 1 else { return nil }

        try await interfaceController.popTemplate(
            animated: animated
        )

        try RootModule.withTemplateStore { templateStore in
            templateStore.removeTemplate(templateId: templateId)
        }

        return templateId
    }

    func popToRootTemplate(
        animated: Bool
    ) async throws -> [String] {
        var templateIds: [String] = []

        templates.forEach { template in
            guard let templateId = template.autoPlayId else {
                return
            }

            if templateId == rootTemplateId {
                return
            }
            templateIds.append(templateId)
        }

        if templateIds.count == 0 {
            return templateIds
        }
        try await interfaceController.popToRootTemplate(
            animated: animated
        )

        try RootModule.withTemplateStore { templateStore in
            templateStore.removeTemplates(templateIds: templateIds)
        }

        return templateIds
    }

    func popToTemplate(templateId: String, animated: Bool) async throws
        -> [String]
    {
        guard
            let template = interfaceController.templates.first(
                where: {
                    templateId == $0.autoPlayId
                })
        else { return [] }

        var templateIds: [String] = interfaceController.templates.compactMap {
            template in template.autoPlayId
        }

        if let startIndex = templateIds.firstIndex(where: {
            $0 == templateId
        }),
            let endIndex = templateIds.firstIndex(where: {
                $0 == topTemplateId
            })
        {
            templateIds = Array(templateIds[(startIndex)..<endIndex])
        }

        try await interfaceController.pop(
            to: template,
            animated: animated
        )

        return templateIds
    }

    func presentTemplate(
        _ templateToPresent: CPTemplate,
        animated: Bool
    ) async throws -> Bool {
        return try await interfaceController.presentTemplate(
            templateToPresent,
            animated: animated
        )
    }

    func dismissTemplate(
        animated: Bool
    ) async throws -> Bool {
        if interfaceController.presentedTemplate == nil {
            return false
        }

        try await interfaceController.dismissTemplate(
            animated: animated
        )

        return true
    }

    // MARK: CPInterfaceControllerDelegate
    func templateWillAppear(
        _ aTemplate: CPTemplate,
        animated: Bool
    ) {
        guard let templateId = aTemplate.autoPlayId else {
            return
        }

        try? RootModule.withAutoPlayTemplate(templateId: templateId) {
            (template: AutoPlayTemplate) in
            template.onWillAppear(
                animated: animated
            )
        }
    }

    func templateDidAppear(
        _ aTemplate: CPTemplate,
        animated: Bool
    ) {
        guard let templateId = aTemplate.autoPlayId else {
            return
        }

        if rootTemplateId == templateId {
            // this makes sure we purge outdated CPSearchTemplate since that one can be popped on with a CarPlay native button we can not intercept
            try? RootModule.withTemplateStore { templateStore in
                templateStore.purge()
            }
        }

        try? RootModule.withAutoPlayTemplate(
            templateId: templateId,
            perform: { (template: AutoPlayTemplate) in
                template.onDidAppear(
                    animated: animated
                )
            }
        )
    }

    func templateWillDisappear(
        _ aTemplate: CPTemplate,
        animated: Bool
    ) {
        guard let templateId = aTemplate.autoPlayId else {
            return
        }

        try? RootModule.withAutoPlayTemplate(
            templateId: templateId,
            perform: {
                (template: AutoPlayTemplate)
                in
                template.onWillDisappear(
                    animated: animated
                )
            }
        )
    }

    func templateDidDisappear(
        _ aTemplate: CPTemplate,
        animated: Bool
    ) {
        guard let templateId = aTemplate.autoPlayId else {
            return
        }

        try? RootModule.withAutoPlayTemplate(
            templateId: templateId,
            perform: { (template: AutoPlayTemplate) in
                template.onDidDisappear(
                    animated: animated
                )
            }
        )

        if aTemplate is CPAlertTemplate {
            removePoppedTemplate(templateId: templateId)
            return
        }

        // CarPlay may call this delegate before its templates array reflects a native back action.
        // Reconcile on the next main-actor turn so onPopped is emitted for removed templates, while
        // templates merely covered by a push remain registered.
        Task { @MainActor [weak self, weak aTemplate] in
            await Task.yield()

            guard let self else { return }

            if aTemplate.map({ self.isTemplateRetained($0) }) != true {
                self.removePoppedTemplate(templateId: templateId)
            }
        }
    }

    private func isTemplateRetained(_ template: CPTemplate) -> Bool {
        return interfaceController.templates.contains { retainedTemplate in
            retainedTemplate === template
                || (retainedTemplate as? CPTabBarTemplate)?
                    .templates.contains(where: { $0 === template }) == true
        } || interfaceController.presentedTemplate === template
    }

    private func removePoppedTemplate(templateId: String) {
        try? RootModule.withTemplateStore { templateStore in
            templateStore.removeTemplate(templateId: templateId)
        }

        HybridAutoPlay.removeListeners(
            templateId: templateId
        )
    }
}
