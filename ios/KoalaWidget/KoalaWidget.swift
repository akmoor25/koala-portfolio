import SwiftUI
import WidgetKit

private let appGroupId = "group.io.akmoor25.koala-portfolio"
private let dataKey = "koala_trip"

/// 端末の最優先の言語が日本語か。ウィジェットの文言を、日本語か英語に決める。
private let isJapanese = Locale.preferredLanguages.first?.hasPrefix("ja") == true

private enum WidgetText {
    static var open: String { isJapanese ? "旅のしおりを開いてください" : "Open Trip Itinerary" }
    static var now: String { isJapanese ? "いま" : "Now" }
    static var done: String { isJapanese ? "おつかれさまでした" : "That's a wrap!" }
    static var free: String { isJapanese ? "移動・自由時間" : "Travel or free time" }
    static func next(_ time: String) -> String { isJapanese ? "次  \(time)" : "Next  \(time)" }
    static func about(_ time: String) -> String { isJapanese ? "\(time) 頃" : "\(time) ≈" }
    static var name: String { isJapanese ? "旅のしおり" : "Trip Itinerary" }
    static var summary: String {
        isJapanese ? "いまの予定とつぎの予定を表示します" : "Shows the current and the next plans of your trip"
    }
}

struct TripStep: Decodable {
    let title: String
    let remark: String?
    let start: TimeInterval
    let end: TimeInterval?
    let isAbout: Bool
    /// 開始時刻を現地時刻にするタイムゾーン ID。無い（旧データ）ときは端末のタイムゾーン
    let tz: String?

    var startDate: Date { Date(timeIntervalSince1970: start) }
}

struct TripSnapshot: Decodable {
    let leaflet: String
    let steps: [TripStep]

    static func load() -> TripSnapshot? {
        guard let json = UserDefaults(suiteName: appGroupId)?.string(forKey: dataKey),
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TripSnapshot.self, from: data)
    }

    /// Dart の resolveCurrentStep と同じ判定
    func resolve(at now: Date) -> (current: TripStep?, next: TripStep?) {
        let t = now.timeIntervalSince1970
        let nextIndex = steps.firstIndex { $0.start > t }
        let next = nextIndex.map { steps[$0] }
        let candidate: TripStep?
        switch nextIndex {
        case nil: candidate = steps.last
        case 0?: candidate = nil
        case let i?: candidate = steps[i - 1]
        }
        if let c = candidate, let end = c.end, end <= t { return (nil, next) }
        return (candidate, next)
    }

    /// タイムラインに入れる、表示の切り替えの最大数。アプリが渡す工程は 20 件まで
    /// （`widgetMaxSteps`）で、開始と終了で最大 40 の時刻になるので、それをすべて入れられる数にする。
    static let maxBoundaries = 40

    func boundaries(after now: Date) -> [Date] {
        let t = now.timeIntervalSince1970
        let times = steps.flatMap { [$0.start, $0.end].compactMap { $0 } }.filter { $0 > t }
        return Array(Set(times)).sorted().prefix(Self.maxBoundaries).map { Date(timeIntervalSince1970: $0) }
    }
}

struct TripEntry: TimelineEntry {
    let date: Date
    let snapshot: TripSnapshot?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TripEntry {
        TripEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TripEntry) -> Void) {
        completion(TripEntry(date: Date(), snapshot: TripSnapshot.load()))
    }

    // 工程の開始・終了時刻ごとにエントリを用意し、アプリを起動しなくても表示を切り替える
    func getTimeline(in context: Context, completion: @escaping (Timeline<TripEntry>) -> Void) {
        let now = Date()
        let snapshot = TripSnapshot.load()
        let dates = [now] + (snapshot?.boundaries(after: now) ?? [])
        let entries = dates.map { TripEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct KoalaWidgetView: View {
    let entry: TripEntry

    /// 表記は端末の言語に連動させない。時刻は、旅程のタイムゾーン（現地時刻）で表示する。
    private static func formatter(timeZoneId: String?) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "M/d HH:mm"
        f.timeZone = timeZoneId.flatMap { TimeZone(identifier: $0) } ?? .current
        return f
    }

    var body: some View {
        content
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(Color.white, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = entry.snapshot, !snapshot.steps.isEmpty {
            let (current, next) = snapshot.resolve(at: entry.date)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.leaflet).font(.caption2).lineLimit(1)
                badge(WidgetText.now, foreground: .white, background: .red).padding(.top, 2)
                Text(current?.title ?? (next == nil ? WidgetText.done : WidgetText.free))
                    .font(.headline)
                    .layoutPriority(1)
                if let remark = current?.remark {
                    Text(remark).font(.caption).layoutPriority(1)
                }
                if let next {
                    badge(WidgetText.next(label(next)), foreground: .black, background: .yellow).padding(.top, 4)
                    Text(next.title).font(.subheadline)
                    if let remark = next.remark {
                        Text(remark).font(.caption)
                    }
                }
            }
        } else {
            Text(WidgetText.open).font(.footnote)
        }
    }

    private func badge(_ text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(foreground)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(background, in: RoundedRectangle(cornerRadius: 3))
    }

    private func label(_ step: TripStep) -> String {
        let text = Self.formatter(timeZoneId: step.tz).string(from: step.startDate)
        return step.isAbout ? WidgetText.about(text) : text
    }
}

@main
struct KoalaWidget: Widget {
    // Flutter 側 TripWidgetSync.iOSName と一致させる
    let kind = "KoalaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            KoalaWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetText.name)
        .description(WidgetText.summary)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
