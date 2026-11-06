// RecordViewer.swift: the window for a processing record (.hfrec, or legacy .hfrec.json), the sidecar that
// HelioFITS Studio and pyHelioFITS write beside an export. It shows the readable report (the record's own
// `report` lines, else the one HFRecord generates as pyHelioFITS report.py does) beside the record's
// preview picture, and copies or saves it as a methods paragraph, LaTeX or a Python script, all
// generated in Swift: the sandboxed app cannot run Python.

import AppKit
import UniformTypeIdentifiers
import HelioFITSCore

final class RecordWindowController: NSObject, NSWindowDelegate {
    static let shared = RecordWindowController()

    /// The record type the app exports (Info.plist), when LaunchServices knows it.
    static let recordType = UTType("com.gillyspace27.hfrecord")

    private final class Ctx {
        let url: URL
        let record: HFRecord
        let view = HFRecordReportView()
        var full = false
        var scoped = false
        /// The record's preview, else the PNG or JPEG export beside it when the sandbox allows.
        lazy var preview: CGImage? = record.previewImage(sidecar: url)
        init(url: URL, record: HFRecord) { self.url = url; self.record = record }
        var lines: [String] { full ? Array(record.text(full: true).components(separatedBy: "\n").dropLast()) : record.reportLines }
    }

    private var ctx = [ObjectIdentifier: Ctx]()

    func present(fileURL url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        let record: HFRecord
        do {
            record = try HFRecord(contentsOf: url)
        } catch {
            if scoped { url.stopAccessingSecurityScopedResource() }
            let a = NSAlert()
            a.messageText = "\(url.lastPathComponent) is not a readable processing record"
            a.informativeText = "\(error)"
            a.runModal()
            return
        }
        HomeWindowController.shared.fileOpened()
        let c = Ctx(url: url, record: record)
        c.scoped = scoped

        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 820),
                           styleMask: [.titled, .closable, .resizable, .miniaturizable],
                           backing: .buffered, defer: false)
        win.title = url.lastPathComponent
        win.representedURL = url
        win.contentMinSize = NSSize(width: 560, height: 360)
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.appearance = NSAppearance(named: .darkAqua)

        func button(_ title: String, _ sel: Selector, _ help: String) -> NSButton {
            let b = NSButton(title: title, target: self, action: sel)
            b.bezelStyle = .rounded
            b.controlSize = .small
            b.toolTip = help
            return b
        }
        let full = NSButton(checkboxWithTitle: "Show every source file", target: self, action: #selector(toggleFull(_:)))
        full.controlSize = .small
        full.toolTip = "List every source file instead of the count, the first and the last"
        let bar = NSStackView(views: [
            button("Copy Report", #selector(copyReport(_:)), "Copy the report as plain text"),
            button("Copy Methods", #selector(copyMethods(_:)), "Copy a methods paragraph and the list of things to cite"),
            button("Copy LaTeX", #selector(copyTeX(_:)), "Copy the methods paragraph as LaTeX"),
            button("Copy Python", #selector(copyPython(_:)), "Copy a Python script that opens the same source files"),
            button("Save Python\u{2026}", #selector(savePython(_:)), "Save that Python script as a .py file"),
            full,
            button("Reveal Exported File", #selector(revealExport(_:)), "Show the exported file beside this record in Finder"),
        ])
        bar.orientation = .horizontal
        bar.spacing = 8
        bar.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        bar.setHuggingPriority(.defaultHigh, for: .vertical)

        let root = NSStackView(views: [bar, c.view])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 0
        c.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([c.view.widthAnchor.constraint(equalTo: root.widthAnchor)])
        win.contentView = root
        c.view.show(record, sidecarName: url.lastPathComponent, lines: c.lines, preview: c.preview)

        ctx[ObjectIdentifier(win)] = c
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func ctx(for sender: Any?) -> Ctx? {
        guard let w = (sender as? NSView)?.window else { return nil }
        return ctx[ObjectIdentifier(w)]
    }

    private func copy(_ text: String, _ sender: Any?) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        // Confirm on the button, since the clipboard is invisible.
        guard let b = sender as? NSButton else { return }
        let old = b.title
        b.title = "Copied"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { b.title = old }
    }

    @objc private func copyReport(_ sender: NSButton) {
        guard let c = ctx(for: sender) else { return }
        copy(c.lines.joined(separator: "\n") + "\n", sender)
    }
    @objc private func copyMethods(_ sender: NSButton) {
        guard let c = ctx(for: sender) else { return }
        copy(c.record.methodsText(), sender)
    }
    @objc private func copyTeX(_ sender: NSButton) {
        guard let c = ctx(for: sender) else { return }
        copy(c.record.texText(), sender)
    }
    @objc private func copyPython(_ sender: NSButton) {
        guard let c = ctx(for: sender) else { return }
        copy(c.record.pythonText(), sender)
    }

    @objc private func savePython(_ sender: NSButton) {
        guard let win = sender.window, let c = ctx(for: sender) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.pythonScript]
        var stem = c.url.lastPathComponent
        if let r = stem.range(of: ".hfrec", options: [.caseInsensitive, .backwards]) { stem = String(stem[..<r.lowerBound]) }
        panel.nameFieldStringValue = stem.replacingOccurrences(of: ".", with: "_") + ".py"
        let script = c.record.pythonText()
        panel.beginSheetModal(for: win) { resp in
            guard resp == .OK, let url = panel.url else { return }
            do { try Data(script.utf8).write(to: url) } catch { NSAlert(error: error).beginSheetModal(for: win) }
        }
    }

    @objc private func toggleFull(_ sender: NSButton) {
        guard let c = ctx(for: sender) else { return }
        c.full = sender.state == .on
        c.view.show(c.record, sidecarName: c.url.lastPathComponent, lines: c.lines, preview: c.preview)
    }

    /// The export sits beside its sidecar. The sandbox may hide the folder from the app, so when
    /// the file cannot be checked the record's own output.file_name is revealed, else the sidecar.
    @objc private func revealExport(_ sender: NSButton) {
        guard let c = ctx(for: sender) else { return }
        let target = c.record.exportBeside(sidecar: c.url)
            ?? c.record.outputFileName.map { c.url.deletingLastPathComponent().appendingPathComponent($0) }
            ?? c.url
        NSWorkspace.shared.activateFileViewerSelecting([target])
    }

    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? NSWindow, let c = ctx.removeValue(forKey: ObjectIdentifier(w)) else { return }
        if c.scoped { c.url.stopAccessingSecurityScopedResource() }
    }
}
