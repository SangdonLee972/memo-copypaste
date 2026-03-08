import WidgetKit
import SwiftUI

struct SnippetEntry: TimelineEntry {
    let date: Date
    let snippets: [(String, String)] // title, content
}

struct MemoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnippetEntry {
        SnippetEntry(date: Date(), snippets: [("메모복붙", "자주 쓰는 문구를 빠르게 복사")])
    }

    func getSnapshot(in context: Context, completion: @escaping (SnippetEntry) -> Void) {
        let entry = SnippetEntry(date: Date(), snippets: loadSnippets())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnippetEntry>) -> Void) {
        let entry = SnippetEntry(date: Date(), snippets: loadSnippets())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadSnippets() -> [(String, String)] {
        guard let dbPath = getDBPath() else { return [] }
        guard let db = openDatabase(at: dbPath) else { return [] }
        defer { sqlite3_close(db) }

        var snippets: [(String, String)] = []
        var stmt: OpaquePointer?
        let query = "SELECT title, content FROM snippets ORDER BY isPinned DESC, copyCount DESC LIMIT 10"

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let title = String(cString: sqlite3_column_text(stmt, 0))
                let content = String(cString: sqlite3_column_text(stmt, 1))
                snippets.append((title, content))
            }
        }
        sqlite3_finalize(stmt)
        return snippets
    }

    private func getDBPath() -> String? {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.copynote.memoCopypaste"
        ) else {
            // Fallback: try app's documents directory
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let dbPath = paths[0].appendingPathComponent("memo_copypaste.db").path
            return FileManager.default.fileExists(atPath: dbPath) ? dbPath : nil
        }
        let dbPath = groupURL.appendingPathComponent("memo_copypaste.db").path
        return FileManager.default.fileExists(atPath: dbPath) ? dbPath : nil
    }

    private func openDatabase(at path: String) -> OpaquePointer? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        return db
    }
}

struct MemoWidgetEntryView: View {
    var entry: SnippetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(Color(red: 0.29, green: 0.56, blue: 0.85))
                    .font(.system(size: 14, weight: .bold))
                Text("메모복붙")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.18))
                Spacer()
            }
            .padding(.bottom, 4)

            if entry.snippets.isEmpty {
                Text("스니펫을 추가해보세요")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            } else {
                let maxItems = family == .systemSmall ? 3 : 6
                ForEach(0..<min(entry.snippets.count, maxItems), id: \.self) { index in
                    let (title, content) = entry.snippets[index]
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title.isEmpty ? String(content.prefix(30)) : title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.18))
                            .lineLimit(1)
                        Text(content)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .cornerRadius(6)
                }
            }

            Spacer()
        }
        .padding(12)
    }
}

@main
struct MemoAppWidget: Widget {
    let kind: String = "MemoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                MemoWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                MemoWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("메모복붙")
        .description("자주 쓰는 문구를 빠르게 확인")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
