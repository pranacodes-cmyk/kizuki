import WidgetKit
import SwiftUI

enum WidgetTokens {
    static let surface = Color(red: 20/255, green: 20/255, blue: 20/255)
    static let foreground = Color(red: 237/255, green: 237/255, blue: 237/255)
    static let primary = Color(red: 1, green: 138/255, blue: 61/255)
    static let muted = Color(red: 163/255, green: 163/255, blue: 163/255)
}
struct LearningWord: Decodable {
    let key: String, word: String, reading: String, meaning: String, clipId: String, example: String
    static let empty = LearningWord(key: "", word: "気づき", reading: "きづき", meaning: "Open Kizuki to discover a word", clipId: "", example: "")
    var url: URL? {
        var c = URLComponents(string: "kizuki://widget/word")
        c?.queryItems = [URLQueryItem(name: "clip", value: clipId)]
        return c?.url
    }
}
struct LearningSnapshot: Decodable {
    let base: Double, expires: Double
    let personal: Bool, reading: Bool, meaning: Bool
    let due: Int, streak: Int
    let words: [LearningWord], fallback: [LearningWord]
    static func load() -> LearningSnapshot? {
        guard let raw = UserDefaults(suiteName: "group.com.kizukijapan.app.widgets")?.string(forKey: "snapshot"), let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}
struct LearningEntry: TimelineEntry {
    let date: Date, word: LearningWord, reading: Bool, meaning: Bool, due: Int, streak: Int
}
struct LearningProvider: TimelineProvider {
    func placeholder(in context: Context) -> LearningEntry { entry(Date(), nil) }
    func getSnapshot(in context: Context, completion: @escaping (LearningEntry) -> Void) { completion(entry(Date(), LearningSnapshot.load())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LearningEntry>) -> Void) {
        let now = Date(), snapshot = LearningSnapshot.load()
        var entries = [entry(now, snapshot)]
        let boundary = (floor(now.timeIntervalSince1970 / 7200) + 1) * 7200
        for i in 0..<12 { entries.append(entry(Date(timeIntervalSince1970: boundary + Double(i) * 7200), snapshot)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
    private func entry(_ date: Date, _ snapshot: LearningSnapshot?) -> LearningEntry {
        let ms = date.timeIntervalSince1970 * 1000
        let expired = ms >= (snapshot?.expires ?? 0)
        let words = expired ? snapshot?.fallback ?? [] : snapshot?.words ?? []
        let index = words.isEmpty ? 0 : Int(max(0, floor((ms - (snapshot?.base ?? ms)) / 7200000))) % words.count
        return LearningEntry(date: date, word: words.isEmpty ? .empty : words[index], reading: snapshot?.reading ?? true, meaning: snapshot?.meaning ?? true,
            due: expired ? 0 : snapshot?.due ?? 0, streak: expired ? 0 : snapshot?.streak ?? 0)
    }
}
struct LearningWidgetView: View {
    let entry: LearningEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        content.widgetURL(entry.word.url).modifier(WidgetBackground())
    }
    @ViewBuilder private var content: some View {
        if family == .accessoryRectangular {
            HStack(spacing: 10) {
                Text(entry.word.word).font(.system(size: 32, weight: .semibold)).minimumScaleFactor(0.45).lineLimit(1)
                VStack(alignment: .leading, spacing: 2) {
                    if entry.reading { Text(entry.word.reading).font(.caption2).lineLimit(1) }
                    if entry.meaning { Text(entry.word.meaning).font(.caption).fontWeight(.semibold).lineLimit(2) }
                }
            }.privacySensitive()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("🦊"); Text("kizuki").font(.system(size: 13, weight: .heavy)).foregroundStyle(WidgetTokens.primary); Spacer(); if family != .systemSmall { Image(systemName: "sparkles").foregroundStyle(WidgetTokens.primary) } }
                Spacer(minLength: 0)
                if family == .systemSmall {
                    Text(entry.word.word).font(.system(size: 34, weight: .bold)).lineLimit(1).minimumScaleFactor(0.4)
                    labels
                } else {
                    HStack(spacing: 18) {
                        Text(entry.word.word).font(.system(size: 44, weight: .bold)).lineLimit(1).minimumScaleFactor(0.4).frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) { labels }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if family == .systemLarge && !entry.word.example.isEmpty {
                    Text(entry.word.example).font(.body).foregroundStyle(WidgetTokens.muted).lineLimit(3)
                }
                Spacer(minLength: 0)
                if family != .systemSmall {
                    HStack {
                        Link(destination: URL(string: "kizuki://widget/review") ?? entry.word.url ?? URL(fileURLWithPath: "/")) {
                            Text(entry.due > 0 ? "\(entry.due) to review →" : "Discover more →").font(.caption).foregroundStyle(WidgetTokens.muted)
                        }
                        Spacer()
                        if entry.streak > 0 { Text("🔥 \(entry.streak)").font(.caption) }
                    }
                }
            }.foregroundStyle(WidgetTokens.foreground).privacySensitive()
        }
    }
    @ViewBuilder private var labels: some View {
        if entry.reading { Text(entry.word.reading).font(.caption).foregroundStyle(WidgetTokens.primary).lineLimit(1) }
        if entry.meaning { Text(entry.word.meaning).font(family == .systemSmall ? .caption : .headline).lineLimit(2).minimumScaleFactor(0.8) }
    }
}
struct ReviewWidgetView: View {
    let entry: LearningEntry
    var body: some View {
        VStack(spacing: 0) { Image(systemName: "rectangle.stack"); Text("\(entry.due)").font(.headline) }
            .widgetURL(URL(string: "kizuki://widget/review")).privacySensitive().modifier(WidgetBackground())
    }
}
struct WidgetBackground: ViewModifier {
    @Environment(\.widgetFamily) private var family
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) { if family != .accessoryRectangular && family != .accessoryCircular { WidgetTokens.surface } }
        } else {
            content.padding(family == .accessoryRectangular || family == .accessoryCircular ? 0 : 16)
                .background(family == .accessoryRectangular || family == .accessoryCircular ? Color.clear : WidgetTokens.surface)
        }
    }
}
struct KizukiWordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KizukiWordWidget", provider: LearningProvider()) { LearningWidgetView(entry: $0) }
            .configurationDisplayName("A little Japanese")
            .description("A word, its reading and meaning. A moment of discovery, every time you look.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}
struct KizukiReviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KizukiReviewWidget", provider: LearningProvider()) { ReviewWidgetView(entry: $0) }
            .configurationDisplayName("Review moment").description("Your next Japanese review.")
            .supportedFamilies([.accessoryCircular])
    }
}
@main struct KizukiWidgetsBundle: WidgetBundle {
    var body: some Widget { KizukiWordWidget(); KizukiReviewWidget() }
}