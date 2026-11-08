import CarPlay

@available(iOS 26.0, *)
final class ImageRowPlaybackStateStore {
    struct Element {
        let id: String?
        let accessorySystemImage: String?
        let playbackTimes: PlaybackConfigurationTimes?
    }

    private final class State: NSObject {
        var elements: [Element] = []
        var playingItemId: String?

        func apply(to nativeElements: [CPListImageRowItemElement]) -> (changed: Bool, matchedCount: Int) {
            var changed = false
            var matchedCount = 0

            for (index, element) in nativeElements.enumerated() {
                guard elements.indices.contains(index) else { continue }
                let source = elements[index]
                let isPlaying =
                    source.playbackTimes != nil && source.id != nil
                    && source.id == playingItemId
                let accessory = isPlaying ? "waveform" : source.accessorySystemImage

                if let condensed = element as? CPListImageRowItemCondensedElement,
                    condensed.accessorySymbolName != accessory
                {
                    condensed.accessorySymbolName = accessory
                    changed = true
                }
                if let imageGrid = element as? CPListImageRowItemImageGridElement,
                    imageGrid.accessorySymbolName != accessory
                {
                    imageGrid.accessorySymbolName = accessory
                    changed = true
                }

                if #available(iOS 26.4, *) {
                    if source.playbackTimes == nil {
                        if element.playbackConfiguration != nil {
                            element.playbackConfiguration = nil
                            changed = true
                        }
                    }
                    else if let configuration = element.playbackConfiguration {
                        let action: CPPlaybackConfiguration.Action = isPlaying ? .pause : .play
                        if configuration.playbackAction != action {
                            element.playbackConfiguration = CPPlaybackConfiguration(
                                preferredPresentation: configuration.preferredPresentation,
                                playbackAction: action,
                                elapsedTime: configuration.elapsedTime,
                                duration: configuration.duration
                            )
                            changed = true
                        }
                    }
                }

                if isPlaying {
                    matchedCount += 1
                }
            }

            return (changed, matchedCount)
        }
    }

    private let states = NSMapTable<CPListImageRowItem, State>.weakToStrongObjects()

    func register(listItem: CPListImageRowItem, elements: [Element]) {
        state(for: listItem).elements = elements
    }

    func replaceElements(
        listItem: CPListImageRowItem,
        elements: [CPListImageRowItemElement],
        sourceElements: [Element]? = nil
    ) {
        let state = state(for: listItem)
        if let sourceElements {
            state.elements = sourceElements
        }
        _ = state.apply(to: elements)
        listItem.elements = elements
    }

    @discardableResult
    func updatePlayingItem(listItem: CPListImageRowItem, itemId: String?) -> Int {
        let state = state(for: listItem)
        state.playingItemId = itemId
        let elements = listItem.elements
        let result = state.apply(to: elements)
        if result.changed {
            listItem.elements = elements
        }
        return result.matchedCount
    }

    private func state(for listItem: CPListImageRowItem) -> State {
        if let state = states.object(forKey: listItem) {
            return state
        }
        let state = State()
        states.setObject(state, forKey: listItem)
        return state
    }
}
