//
//  ListTemplate.swift
//  Pods
//
//  Created by Manuel Auer on 08.10.25.
//

import CarPlay

class ListTemplate: AutoPlayHeaderProviding {
    let template: CPListTemplate
    var config: ListTemplateConfig

    var sections: [NitroSection]?

    private static func createSectionsLogValue(sections: [NitroSection]?) -> String {
        let sectionCount = sections?.count ?? 0
        let itemCount =
            sections?.reduce(0) { count, section in
                count + section.items.count
            } ?? 0
        let selectedRows =
            sections?.enumerated().flatMap {
                (sectionIndex, section) in
                section.items.enumerated().compactMap { (itemIndex, item) in
                    item.selected == true ? "\(sectionIndex):\(itemIndex)" : nil
                }
            }.joined(separator: "|") ?? ""

        return
            "sections=\(sectionCount), items=\(itemCount), selectedRows=\(selectedRows)"
    }

    private static func canUpdateRowsInPlace(
        currentSections: [NitroSection]?,
        nextSections: [NitroSection]?
    ) -> Bool {
        guard let currentSections, let nextSections else { return false }
        guard currentSections.count == nextSections.count else { return false }

        for (sectionIndex, currentSection) in currentSections.enumerated() {
            let nextSection = nextSections[sectionIndex]

            if currentSection.title != nextSection.title
                || currentSection.type != nextSection.type
                || currentSection.items.count != nextSection.items.count
            {
                return false
            }

            if currentSection.items.contains(where: { $0.id == nil })
                || nextSection.items.contains(where: { $0.id == nil })
            {
                return false
            }

            if currentSection.items.map({ $0.id })
                != nextSection.items.map({
                    $0.id
                })
            {
                return false
            }
        }

        return true
    }

    override var autoDismissMs: Double? {
        return config.autoDismissMs
    }

    override func getTemplate() -> CPTemplate {
        return template
    }

    init(config: ListTemplateConfig) {
        self.config = config

        sections = config.sections

        template = CPListTemplate(
            title: Parser.parseText(text: config.title),
            sections: [],
            assistantCellConfiguration: nil,
            id: config.id
        )

        super.init()

        barButtons = config.headerActions
    }

    @MainActor
    override func _invalidate() {
        setBarButtons(template: template, barButtons: barButtons)

        guard let traitCollection = SceneStore.getRootTraitCollection() else {
            return
        }

        NSLog(
            "[AutoPlay] native list template CPListTemplate.updateSections begin templateId=\(config.id), currentItems=\(template.itemCount), \(Self.createSectionsLogValue(sections: sections))"
        )

        template.updateSections(
            Parser.parseSections(
                sections: sections,
                updateSection: self.updateSection(section:sectionIndex:),
                traitCollection: traitCollection
            )
        )

        NSLog(
            "[AutoPlay] native list template CPListTemplate.updateSections end templateId=\(config.id), currentItems=\(template.itemCount)"
        )
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
    private func updateSection(section: NitroSection, sectionIndex: Int) {
        NSLog(
            "[AutoPlay] native list template internal section update requested templateId=\(config.id), sectionIndex=\(sectionIndex)"
        )

        self.sections?[sectionIndex] = section
        invalidate()
    }

    @MainActor
    func updateSections(sections: [NitroSection]?) {
        NSLog(
            "[AutoPlay] native list template external sections update requested templateId=\(config.id), \(Self.createSectionsLogValue(sections: sections))"
        )

        // A full CPListTemplate.updateSections reload can move CarPlay's transient tap highlight
        // to a reused visible cell. Stable row ids let playback/image updates keep the existing
        // CPListItem instances and only mutate their display data.
        if Self.canUpdateRowsInPlace(
            currentSections: self.sections,
            nextSections: sections
        ), let currentSections = self.sections, let nextSections = sections,
            let traitCollection = SceneStore.getRootTraitCollection(),
            updateRowsInPlace(
                currentSections: currentSections,
                nextSections: nextSections,
                traitCollection: traitCollection
            )
        {
            self.sections = nextSections
            NSLog(
                "[AutoPlay] native list template rows updated in place templateId=\(config.id), \(Self.createSectionsLogValue(sections: sections))"
            )

            return
        }

        self.sections = sections
        invalidate()
    }

    @MainActor
    private func updateRowsInPlace(
        currentSections: [NitroSection],
        nextSections: [NitroSection],
        traitCollection: UITraitCollection
    ) -> Bool {
        for (sectionIndex, nextSection) in nextSections.enumerated() {
            guard sectionIndex < template.sections.count else { return false }

            let currentSection = currentSections[sectionIndex]
            let currentListSection = template.sections[sectionIndex]
            let selectedIndex = nextSection.items.firstIndex { item in
                item.selected == true
            }

            for (itemIndex, item) in nextSection.items.enumerated() {
                guard itemIndex < currentListSection.items.count,
                    let listItem = currentListSection.items[itemIndex]
                        as? CPListItem
                else {
                    return false
                }

                Parser.configureListItem(
                    currentItem: currentSection.items[itemIndex],
                    item: item,
                    itemIndex: itemIndex,
                    listItem: listItem,
                    section: nextSection,
                    sectionIndex: sectionIndex,
                    selectedIndex: selectedIndex,
                    traitCollection: traitCollection,
                    updateSection: self.updateSection(section:sectionIndex:)
                )
            }
        }

        return true
    }
}
