// Spotlight attributes for a processing record (.hfrec, or legacy .hfrec.json), called from main.c.
//
// build.sh compiles this file together with HelioFITSCore's HFRecordJSON.swift and
// HFRecordReport.swift (Foundation only), so the importer reads a record exactly as the
// Quick Look preview and the app do. Indexed: the report text with every source file named,
// the layers' dataset labels and instruments, the time range of the sources, the producer.

import Foundation
import CoreServices

/// ISO 8601 UTC ("2025-09-21T20:32:04.840", with or without a trailing Z) as a Date.
private func isoDate(_ s: String) -> Date? {
    let t = s.hasSuffix("Z") ? String(s.dropLast()) : s
    let parts = t.split(whereSeparator: { "-T:".contains($0) }).map(String.init)
    guard parts.count >= 3, let y = Int(parts[0]), let mo = Int(parts[1]), let d = Int(parts[2]) else { return nil }
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d
    c.hour = parts.count > 3 ? Int(parts[3]) : 0
    c.minute = parts.count > 4 ? Int(parts[4]) : 0
    let sec = parts.count > 5 ? Double(parts[5]) ?? 0 : 0
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal.date(from: c).map { $0.addingTimeInterval(sec) }
}

@_cdecl("hfrec_get_metadata")
public func hfrecGetMetadata(_ attributes: CFMutableDictionary, _ path: CFString) -> Bool {
    guard let r = try? HFRecord(contentsOf: URL(fileURLWithPath: path as String)) else { return false }
    let d = attributes as NSMutableDictionary
    let labels = r.layerLabels, instruments = r.instruments
    // The report with every file listed, so a search for a source file finds the exports that used it.
    let stored = r.reportLines.joined(separator: "\n")
    let full = r.text(full: true)
    d[kMDItemTextContent as String] = stored + "\n" == full ? full : stored + "\n\n" + full
    d[kMDItemTitle as String] = r.outputFileName ?? (path as String as NSString).lastPathComponent
    d[kMDItemDescription as String] = "Processing record: \(r.layerCount) layer\(r.layerCount == 1 ? "" : "s"), "
        + labels.joined(separator: "; ")
    d[kMDItemKeywords as String] = Array(Set(labels + instruments)).sorted()
    if let p = r.program {
        d[kMDItemCreator as String] = p
        d["com_gillyspace27_hfrec_producer"] = p
    }
    if let o = r.outputFileName { d["com_gillyspace27_hfrec_output"] = o }
    d["com_gillyspace27_hfrec_labels"] = labels
    d["com_gillyspace27_hfrec_instruments"] = instruments
    d["com_gillyspace27_hfrec_layers"] = r.layerCount
    if let range = r.timeRange {
        if let a = isoDate(range.start) {
            d["com_gillyspace27_hfrec_start"] = a
            d[kMDItemContentCreationDate as String] = a
        }
        if let b = isoDate(range.end) { d["com_gillyspace27_hfrec_end"] = b }
    }
    return true
}
