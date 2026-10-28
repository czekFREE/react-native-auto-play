import CarPlay

extension Parser {
    static func parseSearchResults(
        section: NitroSection?,
        traitCollection: UITraitCollection
    ) -> [CPListItem] {
        guard let section else { return [] }

        return section.items.enumerated().map { itemIndex, item in
            let listItem = CPListItem(text: nil, detailText: nil)
            configureListItem(
                currentItem: nil,
                item: item,
                itemIndex: itemIndex,
                listItem: listItem,
                section: section,
                sectionIndex: 0,
                selectedIndex: nil,
                traitCollection: traitCollection,
                updateSection: { _, _ in }
            )
            return listItem
        }
    }
}
