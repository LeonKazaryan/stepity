import SwiftUI

/// The app after onboarding: three tabs, three scales — today up close, the week, the whole
/// journey on the globe.
struct MainView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch model.tab {
                case .today: TodayScreen(model: model)
                case .week: WeekScreen(model: model)
                case .journey: JourneyScreen(model: model)
                }
            }
            .transition(.opacity)

            if !(model.tab == .journey && model.pendingScene != nil) {
                FloatingTabBar(
                    tabs: [
                        FloatingTab(id: AppModel.Tab.today, title: "Today", systemImage: "figure.walk"),
                        FloatingTab(id: AppModel.Tab.week, title: "Week", systemImage: "calendar"),
                        FloatingTab(id: AppModel.Tab.journey, title: "Journey", systemImage: "globe.europe.africa.fill"),
                    ],
                    selection: $model.tab
                )
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.smooth, value: model.tab)
        .animation(Motion.smooth, value: model.pendingScene == nil)
    }
}
