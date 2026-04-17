import Cocoa
import SQLite3

class ClipboardManager: NSObject {

    static let shared = ClipboardManager()

    private let pasteboard = NSPasteboard.general
    private var changeCount: Int = 0
    private var timer: Timer?
    private(set) var history: [ClipboardItem] = []
    private let maxItems = 200
    private var db: OpaquePointer?

    var onHistoryChanged: (() -> Void)?

    private override init() {
        super.init()
        openDatabase()
        loadFromDatabase()
        changeCount = pasteboard.changeCount
        startMonitoring()
    }

    // MARK: - SQLite

    private func openDatabase() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("bartool", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("clipboard.db")
        guard sqlite3_open(dbURL.path, &db) == SQLITE_OK else { return }
        let create = """
            CREATE TABLE IF NOT EXISTS items (
                id   TEXT PRIMARY KEY,
                content TEXT NOT NULL,
                date REAL NOT NULL
            );
            """
        sqlite3_exec(db, create, nil, nil, nil)
    }

    private func loadFromDatabase() {
        let sql = "SELECT id, content, date FROM items ORDER BY date DESC LIMIT \(maxItems);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        var loaded: [ClipboardItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idPtr      = sqlite3_column_text(stmt, 0),
                  let contentPtr = sqlite3_column_text(stmt, 1) else { continue }
            let idStr   = String(cString: idPtr)
            let content = String(cString: contentPtr)
            let ts      = sqlite3_column_double(stmt, 2)
            guard let uuid = UUID(uuidString: idStr) else { continue }
            loaded.append(ClipboardItem(id: uuid, content: content, date: Date(timeIntervalSince1970: ts)))
        }
        history = loaded
    }

    private func insertToDatabase(_ item: ClipboardItem) {
        let sql = "INSERT OR REPLACE INTO items (id, content, date) VALUES (?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let idStr = item.id.uuidString as NSString
        sqlite3_bind_text(stmt, 1, idStr.utf8String, -1, nil)
        let content = item.content as NSString
        sqlite3_bind_text(stmt, 2, content.utf8String, -1, nil)
        sqlite3_bind_double(stmt, 3, item.date.timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    private func deleteFromDatabase(id: UUID) {
        let sql = "DELETE FROM items WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let idStr = id.uuidString as NSString
        sqlite3_bind_text(stmt, 1, idStr.utf8String, -1, nil)
        sqlite3_step(stmt)
    }

    private func clearDatabase() {
        sqlite3_exec(db, "DELETE FROM items;", nil, nil, nil)
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func checkForChanges() {
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount
        guard let string = pasteboard.string(forType: .string), !string.isEmpty else { return }
        guard history.first?.content != string else { return }

        let item = ClipboardItem(content: string, date: Date())
        history.insert(item, at: 0)
        insertToDatabase(item)

        if history.count > maxItems {
            let removed = history.removeLast()
            deleteFromDatabase(id: removed.id)
        }
        onHistoryChanged?()
    }

    // MARK: - API

    func copyToClipboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        changeCount = pasteboard.changeCount
        if let idx = history.firstIndex(where: { $0.id == item.id }) {
            history.remove(at: idx)
            deleteFromDatabase(id: item.id)
        }
        let updated = ClipboardItem(id: item.id, content: item.content, date: Date())
        history.insert(updated, at: 0)
        insertToDatabase(updated)
        onHistoryChanged?()
    }

    func clearHistory() {
        history.removeAll()
        clearDatabase()
        onHistoryChanged?()
    }

    func removeItem(at index: Int) {
        guard history.indices.contains(index) else { return }
        let item = history.remove(at: index)
        deleteFromDatabase(id: item.id)
        onHistoryChanged?()
    }
}

struct ClipboardItem {
    let id: UUID
    let content: String
    let date: Date

    init(id: UUID = UUID(), content: String, date: Date) {
        self.id = id; self.content = content; self.date = date
    }

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: .newlines)
        let first = lines.first ?? trimmed
        return first.count > 80 ? String(first.prefix(80)) + "…" : first
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
