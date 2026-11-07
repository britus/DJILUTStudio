import SwiftUI
import SQLite3

struct ExportHistoryEntry: Identifiable, Hashable {
    let id: Int64
    let date: Date
    let sourcePath: String
    let sourceType: String
    let device: String
    let conversionLUT: String
    let destinationPath: String
    let destinationType: String
    let colorGrade: String
}

@MainActor
final class ExportHistoryStore: ObservableObject {
    static let shared = ExportHistoryStore()
    @Published private(set) var entries: [ExportHistoryEntry] = []
    private var database: OpaquePointer?
    private let databaseURL: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let directory = support.appendingPathComponent("DJILUTStudio/History", isDirectory: true)
        databaseURL = directory.appendingPathComponent("ExportHistory.sqlite")
    }

    func prepare() {
        do {
            try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        catch {
            NSLog("Could not create export history directory: %@", error.localizedDescription)
            return
        }
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else { return }
        let sql = "CREATE TABLE IF NOT EXISTS exports (id INTEGER PRIMARY KEY AUTOINCREMENT, date REAL NOT NULL, source_path TEXT NOT NULL, source_type TEXT NOT NULL, device TEXT NOT NULL, conversion_lut TEXT NOT NULL, destination_path TEXT NOT NULL, destination_type TEXT NOT NULL, color_grade TEXT NOT NULL)"
        sqlite3_exec(database, sql, nil, nil, nil)
        refresh()
    }

    func record(source: URL, destination: URL, device: String, lut: String, codec: CodecType, look: String, sharpen: Bool) {
        guard let database else { return }
        let sql = "INSERT INTO exports (date, source_path, source_type, device, conversion_lut, destination_path, destination_type, color_grade) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return
        }

        defer {
            sqlite3_finalize(statement)
        }

        let values = [source.path,
                      source.pathExtension.uppercased(),
                      device,
                      lut,
                      destination.path,
                      destination.pathExtension.uppercased(),
                      "\(look), \(sharpen ? "Sharpen on" : "Sharpen off"), \(codec.title)"
        ]
        sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
        for (offset, value) in values.enumerated() {
            sqlite3_bind_text(statement, Int32(offset + 2), (value as NSString).utf8String, -1, SQLITE_TRANSIENT)
        }
        if sqlite3_step(statement) == SQLITE_DONE {
            refresh()
        }
    }

    func refresh() {
        guard let database else {
            entries = []
            return
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT id,date,source_path,source_type,device,conversion_lut,destination_path,destination_type,color_grade FROM exports ORDER BY date DESC", -1, &statement, nil) == SQLITE_OK else {
            return
        }
        defer {
            sqlite3_finalize(statement)
        }
        var rows: [ExportHistoryEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            func string(_ index: Int32) -> String {
                sqlite3_column_text(statement, index).map {
                    String(cString: $0)
                } ?? ""
            }
            rows.append(ExportHistoryEntry(id: sqlite3_column_int64(statement, 0), date: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)), sourcePath: string(2), sourceType: string(3), device: string(4), conversionLUT: string(5), destinationPath: string(6), destinationType: string(7), colorGrade: string(8)))
        }
        entries = rows
    }

    func delete(ids: Set<Int64>) {
        guard let database, !ids.isEmpty else { return }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "DELETE FROM exports WHERE id = ?", -1, &statement, nil) == SQLITE_OK else {
            return
        }
        defer {
            sqlite3_finalize(statement)
        }
        for id in ids {
            sqlite3_bind_int64(statement, 1, id)
            sqlite3_step(statement)
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
        }
        refresh()
    }

    func delete(from start: Date, through end: Date) {
        guard let database else {
            return
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "DELETE FROM exports WHERE date >= ? AND date < ?", -1, &statement, nil) == SQLITE_OK else {
            return
        }
        defer {
            sqlite3_finalize(statement)
        }
        sqlite3_bind_double(statement, 1, start.timeIntervalSince1970)
        sqlite3_bind_double(statement, 2, end.addingTimeInterval(86_400).timeIntervalSince1970)
        sqlite3_step(statement); refresh()
    }

    func deleteAll() {
        guard let database else { return }
        sqlite3_exec(database, "DELETE FROM exports", nil, nil, nil)
        refresh()
    }
}

struct ExportHistoryWorkspace: View {
    @ObservedObject private var history = ExportHistoryStore.shared
    @State private var selection = Set<Int64>()
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
    @State private var endDate = Date.now

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader(title: String(localized: "Export History"),
                            subtitle: String(localized: "Review completed exports and clean up records."),
                            icon: "clock.arrow.circlepath") {
                Spacer()
            }
            HStack(spacing: 12) {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                Text("to")
                    .foregroundStyle(DS.textSecondary)
                DatePicker("Through", selection: $endDate, displayedComponents: .date)
                    .labelsHidden()
                Button("Delete Range") {
                    history.delete(from: min(startDate, endDate), through: max(startDate, endDate))
                }
                Button("Delete Selected", role: .destructive) {
                    history.delete(ids: selection)
                    selection.removeAll()
                }
                .disabled(selection.isEmpty)
                Spacer()
                Button("Delete All", systemImage: "trash", role: .destructive) {
                    history.deleteAll()
                    selection.removeAll()
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)

            if history.entries.isEmpty {
                ContentUnavailableView("No exports yet",
                                       systemImage: "clock",
                                       description: Text("Completed exports will appear here."))
            } else {
                Table(history.entries, selection: $selection) {
                    TableColumn("Date / Time") { entry in
                        Text(entry.date, format: .dateTime.year().month().day().hour().minute()).lineLimit(1)
                    }
                    .width(min: 130, ideal: 150)

                    TableColumn("Source") { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.sourcePath)
                                .lineLimit(1)
                                .help(entry.sourcePath)
                            Text("\(entry.sourceType), \(entry.device), \(entry.conversionLUT)")
                                .font(.caption)
                                .foregroundStyle(DS.textSecondary).lineLimit(1)
                        }
                    }
                    .width(min: 230, ideal: 300)

                    TableColumn("Destination") { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(URL(fileURLWithPath: entry.destinationPath)
                                .lastPathComponent).lineLimit(1)
                            Text(entry.destinationPath)
                                .font(.caption)
                                .foregroundStyle(DS.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .width(min: 230, ideal: 300)

                    TableColumn("Color Grade") { entry in
                        Text(entry.colorGrade)
                            .lineLimit(1)
                    }
                    .width(min: 150, ideal: 190)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .padding(.horizontal, 20)
            }
            Spacer()
        }
        .background(DS.chatBg)
        .onAppear {
            history.refresh()
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
