import SwiftUI

/// The week: one thing to walk the length of, the seven days as bars, the streak that makes
/// the line glow, and the friends' race to come.
struct WeekScreen: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            if let snapshot = model.snapshot {
                VStack(spacing: 16) {
                    goalCard(snapshot)
                        .padding(.top, 12)
                    daysCard(snapshot)
                    streakCard(snapshot.streak)
                    raceTeaser
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func goalCard(_ snapshot: ProgressSnapshot) -> some View {
        let course = snapshot.goal.course
        let fill = snapshot.goalFill
        let left = max(0, course.km - snapshot.thisWeek.distanceKm)
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "This week's goal")
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle().fill(.white.opacity(0.06))
                    LiquidFill(level: fill, phase: 0, amplitude: 0)
                        .fill(Palette.sunriseGradient)
                        .clipShape(Circle())
                        .animation(.spring(duration: 1.4, bounce: 0.1), value: fill)
                    Image(systemName: course.symbol)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                }
                .frame(width: 84, height: 84)
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name)
                        .font(Typography.title)
                        .foregroundStyle(.white)
                    Text("\(Format.km(course.km)) km")
                        .font(Typography.label)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(fill, format: .percent.precision(.fractionLength(0)))
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .foregroundStyle(Palette.gold)
                }
            }
            SunriseBar(progress: fill, height: 10)
            Text(left > 0 ? "\(Format.km(left)) km to go — a little more than your usual week" : "Done! The rest of the week is a bonus")
                .font(Typography.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(18)
        .glassCard()
    }

    private func daysCard(_ snapshot: ProgressSnapshot) -> some View {
        let days = snapshot.weekDays
        let best = days.map(\.distanceKm).max() ?? 0
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Day by day")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(days, id: \.date) { day in
                    let isToday = calendar.isDateInToday(day.date)
                    let isBest = day.distanceKm > 0 && day.distanceKm == best
                    VStack(spacing: 6) {
                        Text(day.distanceKm > 0 ? Format.km(day.distanceKm) : " ")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(isToday ? 0.95 : 0.55))
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(day.distanceKm > 0 ? AnyShapeStyle(Palette.sunriseGradient) : AnyShapeStyle(.white.opacity(0.08)))
                            .frame(height: max(6, 110 * (best > 0 ? day.distanceKm / best : 0)))
                            .overlay(alignment: .top) {
                                if isBest {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.white)
                                        .padding(.top, 4)
                                }
                            }
                            .shadow(color: isToday ? Palette.accent.opacity(0.7) : .clear, radius: 8)
                        Text(verbatim: symbols[(calendar.component(.weekday, from: day.date) - 1) % 7])
                            .font(Typography.caption.weight(isToday ? .heavy : .medium))
                            .foregroundStyle(isToday ? .white : .white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150, alignment: .bottom)
        }
        .padding(18)
        .glassCard()
    }

    private func streakCard(_ streak: WeekStreak) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.system(size: 36))
                .foregroundStyle(streak.weeks > 0 ? AnyShapeStyle(Palette.sunriseGradient) : AnyShapeStyle(.white.opacity(0.25)))
                .shadow(color: Palette.accent.opacity(streak.weeks > 0 ? 0.8 : 0), radius: 12)
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: "Streak")
                Text("\(streak.weeks) weeks in a row")
                    .font(Typography.title)
                    .foregroundStyle(.white)
                Text("Every week you close, your line on the globe glows brighter. Miss a day — nothing burns; miss a week — the glow fades, the kilometres stay.")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var raceTeaser: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 26))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text("Race your friends")
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                Text("Soon: the week's goal becomes a race, with everyone's dot on the same route.")
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .glassCard()
        .opacity(0.75)
    }
}
