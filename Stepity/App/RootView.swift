import SwiftUI

/// Onboarding, then the app. On every return to the app Health is read again, and if the
/// user walked since last time, the scene queues up on the journey tab.
struct RootView: View {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            SpaceBackground()
            switch model.phase {
            case .loading:
                ProgressView().tint(.white)
            case .welcome:
                WelcomeScreen(model: model)
                    .transition(.opacity)
            case .prologue:
                PrologueScreen(model: model)
                    .transition(.opacity)
            case .newPath:
                NewPathScreen(model: model)
                    .transition(.opacity)
            case .main:
                MainView(model: model)
                    .transition(.opacity)
            }
        }
        .animation(Motion.smooth, value: model.phase)
        .task {
            model.globe.reduceMotion = reduceMotion
            await model.launch()
        }
        .onChange(of: reduceMotion) { _, value in model.globe.reduceMotion = value }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, model.phase == .main, model.pendingScene == nil else { return }
            Task {
                await model.refresh()
                model.prepareScene()
                if model.pendingScene != nil { model.tab = .journey }
            }
        }
    }
}
