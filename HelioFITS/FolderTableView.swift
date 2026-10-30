// The folder table: a sortable list of the FITS files in an opened folder, one row of
// header facts each (FITSFolderIndex, HelioFITSCore). Shown by the List side of the
// List/Movie switch in a folder's viewer window (HF-14), which holds the folder's
// sandbox grant while it is open. Non-recursive and not remembered across launches:
// the app has no app-scope bookmarks entitlement.

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import HelioFITSCore

/// Used on the main thread only; the scan's Task runs on the main actor.
final class FolderTableModel: ObservableObject {
    typealias Row = FITSFolderIndex.Row
    typealias Order = FITSFolderIndex.Order

    let folder: URL
    @Published private(set) var rows: [Row] = []
    @Published private(set) var done = 0
    @Published private(set) var total = 0
    @Published private(set) var finished = false
    @Published var sortOrder = [Order(.date), Order(.name)] {
        didSet { rows.sort(using: sortOrder) }
    }
    /// Double-click or Open: the file in a viewer window of its own.
    var onOpen: (String) -> Void = { _ in }
    /// Show in Movie: switch this window to the movie at that file.
    var onShowInMovie: (String) -> Void = { _ in }
    private var task: Task<Void, Never>?

    init(folder: URL) { self.folder = folder }

    /// Read the folder once; rows are merged in batches so a big folder neither
    /// re-sorts per file nor waits for the last one.
    func start() {
        guard task == nil else { return }
        let folder = folder
        task = Task { @MainActor [weak self] in
            var pending: [Row] = []
            var flushed = Date()
            for await step in FITSFolderIndex.rows(in: folder) {
                guard let self else { return }
                if let r = step.row { pending.append(r) }
                self.done = step.done
                self.total = step.total
                if step.done == step.total || Date().timeIntervalSince(flushed) > 0.25 {
                    self.rows = (self.rows + pending).sorted(using: self.sortOrder)
                    pending = []
                    flushed = Date()
                }
            }
            self?.finished = true
        }
    }

    func stop() { task?.cancel() }

    var status: String {
        if !finished { return total == 0 ? "Listing \(folder.lastPathComponent)…" : "Reading \(done.formatted()) of \(total.formatted())" }
        let skipped = total - rows.count
        let files = "\(rows.count.formatted()) FITS image file\(rows.count == 1 ? "" : "s")"
        return skipped > 0 ? "\(files) (\(skipped.formatted()) skipped: no image HDU, or not FITS)" : files
    }

    func reveal(_ ids: Set<String>) {
        NSWorkspace.shared.activateFileViewerSelecting(ids.sorted().map { URL(fileURLWithPath: $0) })
    }

    /// Export CSV: the rows in the table's current order. The save panel confers the write grant.
    func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = folder.lastPathComponent + ".csv"
        panel.message = "Header facts of the FITS files in \(folder.lastPathComponent), in the table's order."
        let text = FITSFolderIndex.csv(rows)
        let done: (NSApplication.ModalResponse) -> Void = { resp in
            guard resp == .OK, let url = panel.url else { return }
            do { try Data(text.utf8).write(to: url, options: .atomic) } catch { NSAlert(error: error).runModal() }
        }
        if let w = NSApp.keyWindow { panel.beginSheetModal(for: w, completionHandler: done) } else { panel.begin(completionHandler: done) }
    }
}

struct FolderTableView: View {
    typealias Order = FITSFolderIndex.Order
    @ObservedObject var model: FolderTableModel
    @State private var selection = Set<String>()

    private static let bytes: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            Table(model.rows, selection: $selection, sortOrder: $model.sortOrder) {
                TableColumn("File", sortUsing: Order(.name)) {
                    Text($0.name).lineLimit(1).truncationMode(.middle).help($0.name)
                }
                .width(min: 120, ideal: 280)
                TableColumn("Instrument", sortUsing: Order(.instrument)) { Text($0.instrument ?? "") }
                TableColumn("Telescope", sortUsing: Order(.telescope)) { Text($0.telescope ?? "") }
                TableColumn("Wavelength", sortUsing: Order(.wavelength)) { Text($0.wavelengthLabel ?? "").monospacedDigit() }
                TableColumn("Observed", sortUsing: Order(.date)) {
                    Text($0.dateLabel ?? "").monospacedDigit().help($0.date ?? "")
                }
                .width(min: 110, ideal: 120)
                TableColumn("Exposure", sortUsing: Order(.exposure)) { r in
                    Text(r.exposureLabel() ?? "").monospacedDigit().help(r.exposure.map { String($0) + " s" } ?? "")
                }
                TableColumn("Size", sortUsing: Order(.size)) { r in
                    Text(r.width.flatMap { w in r.height.map { "\(w) × \($0)" } } ?? "").monospacedDigit()
                }
                TableColumn("BITPIX", sortUsing: Order(.bitpix)) { Text($0.bitpix.map(String.init) ?? "").monospacedDigit() }
                TableColumn("Image HDUs", sortUsing: Order(.imageHDUs)) { Text("\($0.imageHDUs)").monospacedDigit() }
                TableColumn("File Size", sortUsing: Order(.fileBytes)) { r in
                    Text(r.fileBytes.map { Self.bytes.string(fromByteCount: Int64($0)) } ?? "").monospacedDigit()
                }
            }
            .contextMenu(forSelectionType: String.self) { ids in
                Button("Open") { ids.sorted().forEach(model.onOpen) }
                Button("Reveal in Finder") { model.reveal(ids) }
                Button("Show in Movie") { ids.first.map(model.onShowInMovie) }
                    .disabled(ids.count != 1)
            } primaryAction: { ids in
                ids.sorted().forEach(model.onOpen)
            }
            Divider()
            HStack {
                if !model.finished { ProgressView().controlSize(.small) }
                Text(model.status).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Button("Reveal in Finder") { model.reveal(selection) }
                    .disabled(selection.isEmpty)
                Button("Export CSV…") { model.exportCSV() }
                    .disabled(model.rows.isEmpty)
                    .help("Save the table, in its current order, as a CSV file")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { model.start() }
    }
}
