import AVFoundation
import CarPlay
import MediaPlayer
import NitroModules

struct StateListener {
    let id: UUID
    let callback: () -> Void
}

struct RenderStateListener {
    let id: UUID
    let callback: (VisibilityState) -> Void
}

struct SafeAreaListener {
    let id: UUID
    let callback: (SafeAreaInsets) -> Void
}

private class NowPlayingTemplateObserver: NSObject, CPNowPlayingTemplateObserver {
    var onUpNextButtonPress: (() -> Void)?
    var onAlbumArtistButtonPress: (() -> Void)?

    func nowPlayingTemplateUpNextButtonTapped(
        _ nowPlayingTemplate: CPNowPlayingTemplate
    ) {
        onUpNextButtonPress?()
    }

    func nowPlayingTemplateAlbumArtistButtonTapped(
        _ nowPlayingTemplate: CPNowPlayingTemplate
    ) {
        onAlbumArtistButtonPress?()
    }
}

class HybridAutoPlay: HybridAutoPlaySpec {
    private static var listeners = [EventName: [StateListener]]()
    private static var renderStateListeners = [String: [RenderStateListener]]()
    private static var safeAreaInsetsListeners = [String: [SafeAreaListener]]()
    private static let nowPlayingTemplateObserver = NowPlayingTemplateObserver()
    private static var nowPlayingTemplateObserverRegistered = false
    private static let nowPlayingButtonSelectedFlag = 1.0
    private static let nowPlayingButtonTypeAddToLibrary = "addToLibrary"
    private static let nowPlayingButtonTypeImage = "image"
    private static let nowPlayingButtonTypeMore = "more"
    private static let nowPlayingButtonTypePlaybackRate = "playbackRate"
    private static let nowPlayingButtonTypeRepeat = "repeat"
    private static let nowPlayingButtonTypeShuffle = "shuffle"

    private static func logNowPlayingState(reason: String) {
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        let nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo
        let remoteCommandCenter = MPRemoteCommandCenter.shared()

        let snapshot: [String: Any] = [
            "reason": reason,
            "title": nowPlayingInfo?[MPMediaItemPropertyTitle] ?? "nil",
            "artist": nowPlayingInfo?[MPMediaItemPropertyArtist] ?? "nil",
            "album": nowPlayingInfo?[MPMediaItemPropertyAlbumTitle] ?? "nil",
            "duration":
                nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] ?? "nil",
            "elapsedTime":
                nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime]
                ?? "nil",
            "playbackRate":
                nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] ?? "nil",
            "playbackState": nowPlayingInfoCenter.playbackState.rawValue,
            "hasArtwork":
                nowPlayingInfo?[MPMediaItemPropertyArtwork] != nil,
            "commands": [
                "play": remoteCommandCenter.playCommand.isEnabled,
                "pause": remoteCommandCenter.pauseCommand.isEnabled,
                "togglePlayPause":
                    remoteCommandCenter.togglePlayPauseCommand.isEnabled,
                "stop": remoteCommandCenter.stopCommand.isEnabled,
                "seek":
                    remoteCommandCenter.changePlaybackPositionCommand.isEnabled,
                "next": remoteCommandCenter.nextTrackCommand.isEnabled,
                "previous": remoteCommandCenter.previousTrackCommand.isEnabled,
                "skipForward":
                    remoteCommandCenter.skipForwardCommand.isEnabled,
                "skipBackward":
                    remoteCommandCenter.skipBackwardCommand.isEnabled,
            ],
        ]

        print("[AutoPlay][NowPlaying][iOS] snapshot \(snapshot)")
    }

    override init() {
        HybridAutoPlay.listeners.removeAll()
        HybridAutoPlay.renderStateListeners.removeAll()
        HybridAutoPlay.safeAreaInsetsListeners.removeAll()
        super.init()
    }

    func addListener(eventType: EventName, callback: @escaping () -> Void)
        throws -> () -> Void
    {
        let listener = StateListener(id: UUID(), callback: callback)

        HybridAutoPlay.listeners[eventType, default: []].append(listener)

        if eventType == .didconnect && SceneStore.isRootModuleConnected() {
            callback()
        }

        return {
            HybridAutoPlay.listeners[eventType]?.removeAll {
                $0.id == listener.id
            }
            if HybridAutoPlay.listeners[eventType]?.isEmpty ?? false {
                HybridAutoPlay.listeners.removeValue(forKey: eventType)
            }
        }
    }

    func addListenerRenderState(
        moduleName: String,
        callback: @escaping (VisibilityState) -> Void
    ) throws -> () -> Void {
        let listener = RenderStateListener(id: UUID(), callback: callback)

        HybridAutoPlay.renderStateListeners[moduleName, default: []].append(
            listener
        )

        if let state = SceneStore.getState(moduleName: moduleName) {
            callback(state)
        }

        return {
            HybridAutoPlay.renderStateListeners[moduleName]?.removeAll {
                $0.id == listener.id
            }
            if HybridAutoPlay.renderStateListeners[moduleName]?.isEmpty
                ?? false
            {
                HybridAutoPlay.renderStateListeners.removeValue(
                    forKey: moduleName
                )
            }
        }
    }

    func isConnected() throws -> Bool {
        return SceneStore.isRootModuleConnected()
    }

    func isCarServiceRunning() throws -> Bool {
        return SceneStore.isRootModuleConnected()
    }

    func addSafeAreaInsetsListener(
        moduleName: String,
        callback: @escaping (SafeAreaInsets) -> Void
    ) throws -> () -> Void {
        let listener = SafeAreaListener(id: UUID(), callback: callback)

        HybridAutoPlay.safeAreaInsetsListeners[moduleName, default: []].append(
            listener
        )

        if let safeAreaInsets = SceneStore.getScene(moduleName: moduleName)?
            .safeAreaInsets
        {
            let insets = HybridAutoPlay.getSafeAreaInsets(
                safeAreaInsets: safeAreaInsets
            )
            callback(insets)
        }

        return {
            HybridAutoPlay.safeAreaInsetsListeners[moduleName]?.removeAll {
                $0.id == listener.id
            }
            if HybridAutoPlay.safeAreaInsetsListeners[moduleName]?.isEmpty
                ?? false
            {
                HybridAutoPlay.safeAreaInsetsListeners.removeValue(
                    forKey: moduleName
                )
            }
        }
    }

    func addListenerVoiceInput(
        callback: @escaping (Location?, String?) -> Void
    ) throws -> () -> Void {
        // iOS does not use the OS-triggered voice input path — use HybridVoice instead.
        return {}
    }

    // MARK: CPNowPlayingTemplate
    func configureNowPlayingTemplate(
        onUpNextButtonPress: @escaping () -> Void,
        onAlbumArtistButtonPress: @escaping () -> Void,
        upNextButtonEnabled: Bool?,
        upNextTitle: String?,
        albumArtistButtonEnabled: Bool?,
        buttons: [NitroAction]?
    ) throws -> Promise<Void> {
        return Promise.async {
            await MainActor.run {
                let nowPlayingTemplate = CPNowPlayingTemplate.shared

                nowPlayingTemplate.isUpNextButtonEnabled =
                    upNextButtonEnabled ?? false
                nowPlayingTemplate.upNextTitle = upNextTitle ?? ""
                nowPlayingTemplate.isAlbumArtistButtonEnabled =
                    albumArtistButtonEnabled ?? false

                HybridAutoPlay.nowPlayingTemplateObserver
                    .onUpNextButtonPress = onUpNextButtonPress
                HybridAutoPlay.nowPlayingTemplateObserver
                    .onAlbumArtistButtonPress = onAlbumArtistButtonPress

                if !HybridAutoPlay.nowPlayingTemplateObserverRegistered {
                    nowPlayingTemplate.add(
                        HybridAutoPlay.nowPlayingTemplateObserver
                    )
                    HybridAutoPlay.nowPlayingTemplateObserverRegistered = true
                }

                nowPlayingTemplate.updateNowPlayingButtons(
                    HybridAutoPlay.parseNowPlayingButtons(buttons: buttons)
                )
            }
        }
    }

    func showNowPlayingTemplate(animated: Bool?) throws -> Promise<Void> {
        return Promise.async {
            try await RootModule.withInterfaceController {
                interfaceController in

                let nowPlayingTemplate = await CPNowPlayingTemplate.shared
                HybridAutoPlay.logNowPlayingState(reason: "before-show")

                if let topTemplate = await interfaceController.topTemplate,
                    topTemplate === nowPlayingTemplate
                {
                    HybridAutoPlay.logNowPlayingState(
                        reason: "show-skipped-already-top"
                    )
                    return
                }

                let _ = try await interfaceController.pushTemplate(
                    nowPlayingTemplate,
                    animated: animated ?? true
                )
                HybridAutoPlay.logNowPlayingState(reason: "after-show")
            }
        }
    }

    // MARK: set/push/pop templates
    func setRootTemplate(templateId: String) throws -> Promise<Void> {
        return Promise.async {
            try await RootModule.withSceneAndInterfaceController {
                scene,
                interfaceController in

                let template = try await scene.templateStore.getTemplate(
                    templateId: templateId
                )

                let carPlayTemplate = template.getTemplate()

                if carPlayTemplate is CPMapTemplate {
                    try await MainActor.run {
                        try scene.initRootView()
                    }
                }

                let _ = try await interfaceController.setRootTemplate(
                    carPlayTemplate,
                    animated: false
                )

                await template.invalidate()
            }
        }
    }

    func pushTemplate(templateId: String) throws
        -> Promise<Void>
    {
        return Promise.async {
            try await RootModule.withSceneAndInterfaceController {
                scene,
                interfaceController in

                let template = try await scene.templateStore.getTemplate(
                    templateId: templateId
                )

                await template.invalidate()

                let carPlayTemplate = template.getTemplate()

                if carPlayTemplate is CPAlertTemplate {
                    let animated = try await !interfaceController.dismissTemplate(
                        animated: false
                    )

                    let _ = try await interfaceController.presentTemplate(
                        carPlayTemplate,
                        animated: animated
                    )
                }
                else {
                    let _ = try await interfaceController.pushTemplate(
                        carPlayTemplate,
                        animated: true
                    )
                }

                if let autoDismissMs = template.autoDismissMs {
                    Task { @MainActor in
                        try await Task.sleep(
                            nanoseconds: UInt64(autoDismissMs) * 1_000_000
                        )

                        if interfaceController.topTemplateId == templateId
                            || interfaceController.interfaceController
                                .presentedTemplate?.autoPlayId == templateId
                        {
                            try await self.popTemplate(animate: true).await()
                        }
                    }
                }
            }
        }
    }

    func popTemplate(animate: Bool?) throws -> Promise<Void> {
        return Promise.async {
            try await RootModule.withInterfaceController {
                interfaceController in

                if try await interfaceController.dismissTemplate(
                    animated: animate ?? true
                ) {
                    return
                }

                guard
                    let templateId = try await interfaceController.popTemplate(
                        animated: true
                    )
                else { return }
                HybridAutoPlay.removeListeners(templateId: templateId)
            }
        }
    }

    func popToRootTemplate(animate: Bool?) throws -> Promise<Void> {
        return Promise.async {
            try await RootModule.withInterfaceController {
                interfaceController in

                let hasPresentedTemplate =
                    try await interfaceController.dismissTemplate(
                        animated: false
                    )

                let templateIds =
                    try await interfaceController.popToRootTemplate(
                        animated: !hasPresentedTemplate && (animate ?? true)
                    )
                for templateId in templateIds {
                    HybridAutoPlay.removeListeners(templateId: templateId)
                }
            }
        }
    }

    func popToTemplate(templateId: String, animate: Bool?) throws -> Promise<
        Void
    > {
        return Promise.async {
            try await RootModule.withInterfaceController {
                interfaceController in

                let _ = try await interfaceController.dismissTemplate(
                    animated: animate ?? true
                )

                let templateIds = try await interfaceController.popToTemplate(
                    templateId: templateId,
                    animated: true
                )
                templateIds.forEach { templateId in
                    HybridAutoPlay.removeListeners(templateId: templateId)
                }
            }
        }
    }

    // MARK: generic template updates
    func setTemplateHeaderActions(
        templateId: String,
        headerActions: [NitroAction]?
    ) throws -> Promise<Void> {
        return Promise.async {
            try await RootModule.withScene { rootScene in
                try await MainActor.run {
                    let template = try rootScene.templateStore.getTemplate(
                        templateId: templateId
                    )

                    guard let template = template as? AutoPlayHeaderProviding
                    else {
                        throw AutoPlayError.invalidTemplateType(
                            "\(templateId) does not support header actions"
                        )
                    }

                    template.barButtons = headerActions
                    template.invalidate()
                }
            }
        }
    }

    // MARK: events
    static func emit(event: EventName) {
        HybridAutoPlay.listeners[event]?.forEach { listener in
            listener.callback()
        }
    }

    static func emitRenderState(moduleName: String, state: VisibilityState) {
        HybridAutoPlay.renderStateListeners[moduleName]?.forEach {
            listener in
            listener.callback(state)
        }
    }

    static func emitSafeAreaInsets(
        moduleName: String,
        safeAreaInsets: UIEdgeInsets
    ) {
        let insets = HybridAutoPlay.getSafeAreaInsets(
            safeAreaInsets: safeAreaInsets
        )
        HybridAutoPlay.safeAreaInsetsListeners[moduleName]?.forEach {
            listener in listener.callback(insets)
        }
    }

    static func removeListeners(templateId: String) {
        HybridAutoPlay.renderStateListeners.removeValue(forKey: templateId)
        HybridAutoPlay.safeAreaInsetsListeners.removeValue(forKey: templateId)
    }

    static func getSafeAreaInsets(safeAreaInsets: UIEdgeInsets)
        -> SafeAreaInsets
    {
        return SafeAreaInsets(
            top: safeAreaInsets.top,
            left: safeAreaInsets.left,
            bottom: safeAreaInsets.bottom,
            right: safeAreaInsets.right,
            isLegacyLayout: nil
        )
    }

    @MainActor
    private static func parseNowPlayingButtons(buttons: [NitroAction]?)
        -> [CPNowPlayingButton]
    {
        guard let buttons else { return [] }

        return buttons.prefix(5).compactMap { button in
            parseNowPlayingButton(button: button)
        }
    }

    @MainActor
    private static func parseNowPlayingButton(button: NitroAction)
        -> CPNowPlayingButton?
    {
        let handler: (CPNowPlayingButton) -> Void = { _ in
            button.onPress()
        }

        let nowPlayingButton: CPNowPlayingButton?

        switch button.title {
        case nowPlayingButtonTypeShuffle:
            nowPlayingButton = CPNowPlayingShuffleButton(handler: handler)
        case nowPlayingButtonTypeAddToLibrary:
            nowPlayingButton = CPNowPlayingAddToLibraryButton(handler: handler)
        case nowPlayingButtonTypeMore:
            nowPlayingButton = CPNowPlayingMoreButton(handler: handler)
        case nowPlayingButtonTypePlaybackRate:
            nowPlayingButton = CPNowPlayingPlaybackRateButton(handler: handler)
        case nowPlayingButtonTypeRepeat:
            nowPlayingButton = CPNowPlayingRepeatButton(handler: handler)
        case nowPlayingButtonTypeImage:
            nowPlayingButton = parseNowPlayingImageButton(
                button: button,
                handler: handler
            )
        default:
            nowPlayingButton = nil
        }

        nowPlayingButton?.isEnabled = button.enabled ?? true
        nowPlayingButton?.isSelected =
            button.flags == nowPlayingButtonSelectedFlag

        return nowPlayingButton
    }

    @MainActor
    private static func parseNowPlayingImageButton(
        button: NitroAction,
        handler: @escaping (CPNowPlayingButton) -> Void
    ) -> CPNowPlayingImageButton? {
        guard
            let image = Parser.parseNitroImage(
                image: button.image,
                traitCollection: SceneStore.getRootTraitCollection()
                    ?? UITraitCollection.current
            )
        else { return nil }

        return CPNowPlayingImageButton(image: image, handler: handler)
    }
}
