//
//  FITSFolderIndex.swift: one row of header facts per FITS file in a folder, for the
//  viewer's sortable folder table.
//
//  Files are the ones FITSSequence plays: .fits, .fts, .fit and .fz directly in the
//  folder (not subfolders), skipping any file CFITSIO cannot open or that has no image
//  HDU. Rows are yielded one file at a time, so a large folder fills in while it is read.
//

import Foundation
import CFITSIO

public enum FITSFolderIndex {
    public struct Row: Identifiable, Hashable, Sendable {
        public let path: String
        public var id: String { path }
        public var name: String { (path as NSString).lastPathComponent }
        public var instrument: String?
        public var telescope: String?
        public var wavelength: Double?
        public var waveUnit: String?
        /// DATE-OBS as written, else T_OBS.
        public var date: String?
        public var exposure: Double?
        public var width: Int?
        public var height: Int?
        public var bitpix: Int?
        public var imageHDUs: Int
        public var fileBytes: Int?
        public var pixels: Int? { width.flatMap { w in height.map { w * $0 } } }
    }

    /// One step of a scan: `done` of `total` files read, and the row for the last one
    /// (nil when that file was skipped).
    public struct Step: Sendable {
        public let done: Int
        public let total: Int
        public let row: Row?
    }

    /// The candidate files directly in `folder`, by name.
    public static func files(in folder: URL) -> [String] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                                                 options: [.skipsHiddenFiles])) ?? []
        return urls.filter { FITSSequence.extensions.contains($0.pathExtension.lowercased()) }
            .map(\.path)
            .sorted { ($0 as NSString).lastPathComponent.localizedStandardCompare(($1 as NSString).lastPathComponent)
                == .orderedAscending }
    }

    /// Reads the files of `folder` off the main thread, one Step per file. Cancelling the
    /// consuming task stops the scan.
    public static func rows(in folder: URL) -> AsyncStream<Step> {
        AsyncStream { cont in
            let task = Task.detached(priority: .utility) {
                let paths = files(in: folder)
                for (i, p) in paths.enumerated() {
                    if Task.isCancelled { break }
                    cont.yield(Step(done: i + 1, total: paths.count, row: row(path: p)))
                }
                cont.finish()
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }

    /// The row for one file, or nil when it is not FITS or has no image HDU.
    ///
    /// Keywords follow FITSMetadataImporter/fits_header.c, so the table and Spotlight
    /// agree: TELESCOP, INSTRUME, WAVELNTH, WAVEUNIT, DATE-OBS (else T_OBS) and EXPTIME
    /// are the first non-empty value across all HDUs in file order; size and BITPIX come
    /// from the first image HDU, ZNAXIS1, ZNAXIS2 and ZBITPIX when it is tile-compressed
    /// (ZIMAGE = T), NAXIS1, NAXIS2 and BITPIX otherwise.
    public static func row(path: String) -> Row? {
        var idx = [Int](repeating: 0, count: 8)
        let n = Int(fitsshim_image_hdus(path, &idx, Int32(idx.count)))
        guard n > 0, let cards = FITSRenderer.cards(path: path, hdu: idx[0]) else { return nil }
        let lines = FITSHeader.dump(path: path).split(separator: "\n").map(String.init)
        func text(_ k: String) -> String? {
            lines.lazy.filter { $0.hasPrefix(k) }.compactMap { FITSRenderer.cardVal($0, k) }.first
        }
        func number(_ k: String) -> Double? {
            lines.lazy.filter { $0.hasPrefix(k) }.compactMap { FITSRenderer.cardNum($0, k) }.first
        }
        func int(_ k: String) -> Int? { FITSRenderer.cardNum(cards, k).map { Int($0) } }

        var w = int("NAXIS1"), h = int("NAXIS2"), bitpix = int("BITPIX")
        if FITSRenderer.cardVal(cards, "ZIMAGE") == "T", (int("ZNAXIS") ?? 0) >= 2,
           let zw = int("ZNAXIS1"), let zh = int("ZNAXIS2") {
            w = zw; h = zh; bitpix = int("ZBITPIX")
        }
        let bytes = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue
        return Row(path: path, instrument: text("INSTRUME"), telescope: text("TELESCOP"),
                   wavelength: number("WAVELNTH"), waveUnit: text("WAVEUNIT"),
                   date: text("DATE-OBS") ?? text("T_OBS"), exposure: number("EXPTIME"),
                   width: w, height: h, bitpix: bitpix, imageHDUs: n, fileBytes: bytes)
    }
}

extension FITSFolderIndex {
    /// The rows as CSV (RFC 4180 quoting), in the order given; a missing value is an empty field.
    public static func csv(_ rows: [Row]) -> String {
        func field(_ s: String?) -> String {
            guard let s else { return "" }
            return s.contains(where: { ",\"\n\r".contains($0) }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
        }
        func num(_ d: Double?) -> String { d.map { String($0) } ?? "" }
        func int(_ i: Int?) -> String { i.map(String.init) ?? "" }
        var out = "file,instrument,telescope,wavelength,waveunit,date_obs,exptime,width,height,bitpix,image_hdus,bytes,path\r\n"
        for r in rows {
            out += [field(r.name), field(r.instrument), field(r.telescope), num(r.wavelength), field(r.waveUnit),
                    field(r.date), num(r.exposure), int(r.width), int(r.height), int(r.bitpix), String(r.imageHDUs),
                    int(r.fileBytes), field(r.path)].joined(separator: ",") + "\r\n"
        }
        return out
    }

    /// WAVEUNIT spellings (lowercased) we can convert: the symbol shown and one unit in Å.
    static let waveUnits: [String: (symbol: String, angstroms: Double)] = [
        "angstrom": ("Å", 1), "angstroms": ("Å", 1), "å": ("Å", 1),
        "nm": ("nm", 10), "nanometer": ("nm", 10), "nanometers": ("nm", 10), "nanometre": ("nm", 10),
        "um": ("µm", 1e4), "µm": ("µm", 1e4), "micron": ("µm", 1e4), "microns": ("µm", 1e4),
        "micrometer": ("µm", 1e4), "m": ("m", 1e10), "meter": ("m", 1e10), "metre": ("m", 1e10),
    ]

    public enum Column: String, CaseIterable, Sendable {
        case name, instrument, telescope, wavelength, date, exposure, size, bitpix, imageHDUs, fileBytes
    }

    /// Sorts rows by one column. Numbers sort as numbers (size by width times height,
    /// wavelength converted to Å, so 530 nm sorts after 1700 Å). A missing value, or a
    /// wavelength whose WAVEUNIT we cannot convert, sorts last in either direction.
    public struct Order: SortComparator, Hashable, Sendable {
        public var column: Column
        public var order: SortOrder = .forward
        public init(_ column: Column, order: SortOrder = .forward) {
            self.column = column
            self.order = order
        }

        private enum Key { case text(String), number(Double) }

        private func key(_ r: Row) -> Key? {
            switch column {
            case .name: return .text(r.name)
            case .instrument: return r.instrument.map(Key.text)
            case .telescope: return r.telescope.map(Key.text)
            case .date: return r.date.map(Key.text)
            case .wavelength: return r.wavelengthInAngstroms.map(Key.number)
            case .exposure: return r.exposure.map(Key.number)
            case .size: return r.pixels.map { .number(Double($0)) }
            case .bitpix: return r.bitpix.map { .number(Double($0)) }
            case .imageHDUs: return .number(Double(r.imageHDUs))
            case .fileBytes: return r.fileBytes.map { .number(Double($0)) }
            }
        }

        public func compare(_ a: Row, _ b: Row) -> ComparisonResult {
            let r: ComparisonResult
            switch (key(a), key(b)) {
            case (nil, nil): return .orderedSame
            case (nil, _): return .orderedDescending
            case (_, nil): return .orderedAscending
            case let (.text(x)?, .text(y)?): r = x.localizedStandardCompare(y)
            case let (.number(x)?, .number(y)?): r = x < y ? .orderedAscending : x > y ? .orderedDescending : .orderedSame
            default: r = .orderedSame
            }
            guard order == .reverse else { return r }
            return r == .orderedAscending ? .orderedDescending : r == .orderedDescending ? .orderedAscending : r
        }
    }
}

extension FITSFolderIndex.Row {
    /// WAVELNTH in Å, when WAVEUNIT is a unit we know (nil otherwise, or with no WAVEUNIT).
    public var wavelengthInAngstroms: Double? {
        guard let w = wavelength, let u = waveUnit,
              let unit = FITSFolderIndex.waveUnits[u.trimmingCharacters(in: .whitespaces).lowercased()]
        else { return nil }
        return w * unit.angstroms
    }

    /// "193 Å", "530 nm": a known WAVEUNIT as its symbol, an unknown one as written.
    public var wavelengthLabel: String? {
        guard let w = wavelength else { return nil }
        let u = waveUnit.map { FITSFolderIndex.waveUnits[$0.trimmingCharacters(in: .whitespaces).lowercased()]?.symbol ?? $0 }
        return String(format: "%g", w) + (u.map { " " + $0 } ?? "")
    }

    /// "2.0 s": EXPTIME to two or three significant figures.
    public func exposureLabel(locale: Locale = .current) -> String? {
        exposure.map { $0.formatted(.number.precision(.significantDigits(2...3)).grouping(.never).locale(locale)) + " s" }
    }

    /// "2023-10-11 00:00" from an ISO 8601 date and time; anything else as written.
    public var dateLabel: String? {
        guard let d = date else { return nil }
        let c = Array(d)
        guard c.count >= 16, c[4] == "-", c[7] == "-", c[10] == "T" || c[10] == " ", c[13] == ":" else { return d }
        return String(c[0..<10]) + " " + String(c[11..<16])
    }
}
