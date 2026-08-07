//
//  HeadunitSceneDelegate.swift
//
//  Created by Manuel Auer on 28.09.25.
//

import CarPlay
import Foundation

@objc(HeadUnitSceneDelegate)
class HeadUnitSceneDelegate: AutoPlayScene, CPTemplateApplicationSceneDelegate {
    override init() {
        super.init(moduleName: SceneStore.rootModuleName)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.window = window
        self.interfaceController = AutoPlayInterfaceController(
            interfaceController: interfaceController
        )

        let props: [String: Any] = [
            "colorScheme": interfaceController.carTraitCollection
                .userInterfaceStyle == .dark ? "dark" : "light",
            "window": [
                "height": window.bounds.size.height.rounded(),
                "width": window.bounds.size.width.rounded(),
                "scale": window.screen.scale.rounded(),
            ],
        ]

        connect(props: props)
        do {
            try initRootView()
            AutoPlayDevelopmentLogger.log(
                "[AutoPlay] HeadUnitSceneDelegate initRootView succeeded"
            )
        }
        catch {
            AutoPlayDevelopmentLogger.log(
                "[AutoPlay] HeadUnitSceneDelegate initRootView failed: \(error)"
            )
        }
        HybridAutoPlay.emit(event: .didconnect)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = AutoPlayInterfaceController(
            interfaceController: interfaceController
        )

        connect(props: [
            "colorScheme": interfaceController.carTraitCollection
                .userInterfaceStyle == .dark ? "dark" : "light"
        ])
        do {
            try initRootView()
            AutoPlayDevelopmentLogger.log(
                "[AutoPlay] HeadUnitSceneDelegate initRootView succeeded"
            )
        }
        catch {
            AutoPlayDevelopmentLogger.log(
                "[AutoPlay] HeadUnitSceneDelegate initRootView failed: \(error)"
            )
        }
        HybridAutoPlay.emit(event: .didconnect)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        if let mapTemplate = try? templateStore.getTemplate(
            templateId: SceneStore.rootModuleName
        ) as? MapTemplate {
            mapTemplate.stopNavigation()
        }

        disconnect()

        HybridAutoPlay.emit(event: .diddisconnect)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController:
            CPInterfaceController
    ) {
        disconnect()
        HybridAutoPlay.emit(event: .diddisconnect)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        setState(state: .willdisappear)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        setState(state: .diddisappear)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        setState(state: .willappear)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        restoreConnectionIfNeeded(reason: "sceneDidBecomeActive")
        setState(state: .didappear)
    }

    private func restoreConnectionIfNeeded(reason: String) {
        guard interfaceController != nil else { return }

        SceneStore.addScene(moduleName: moduleName, scene: self)

        guard !isConnected else { return }

        AutoPlayDevelopmentLogger.log(
            "[AutoPlay] restoring CarPlay connection, reason=\(reason)"
        )
        connect(props: [:])
        HybridAutoPlay.emit(event: .didconnect)
    }
}
