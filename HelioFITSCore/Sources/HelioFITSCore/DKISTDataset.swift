//
//  DKISTDataset.swift: the Finder thumbnail and Quick Look card of a DKIST dataset .asdf.
//
//  A dataset ASDF is a YAML tree followed by binary blocks. Only the YAML before the first
//  binary block (the bytes D3 "BLK") is read, capped at `readLimit`, and only the flat
//  `inventory:` map inside it is used (datasetId, instrumentName, startTime, endTime,
//  frameCount, spectralLines, stokesParameters, targetTypes, wavelengthMin/Max). This is
//  not a YAML parser: it reads `key: value` lines one indent level below `inventory:`, and
//  returns nil for a file with no such map. Values are shown as the file states them.
//

import Foundation
import CoreGraphics
import CoreText

public struct DKISTDataset: Equatable {
    public var datasetID: String
    public var instrument: String?
    public var start: String?
    public var end: String?
    public var frameCount: Int?
    public var spectralLines: [String] = []
    public var stokes: [String] = []
    public var targets: [String] = []
    public var waveMinNM: Double?
    public var waveMaxNM: Double?

    /// Most YAML bytes read: the DKIST datasets seen so far keep it under 0.5 MB; the cap
    /// keeps a huge or malformed file from costing a Quick Look extension its memory limit.
    public static let readLimit = 4 << 20

    public static func isASDFName(_ name: String) -> Bool { name.lowercased().hasSuffix(".asdf") }

    /// The dataset described by the file's `inventory:` map, or nil when the file is not an
    /// ASDF, cannot be read, or has no inventory with a datasetId.
    public static func read(url: URL) -> DKISTDataset? {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fh.close() }
        let marker = Data([0xD3, 0x42, 0x4C, 0x4B])
        var buf = Data()
        while buf.count < readLimit, let chunk = try? fh.read(upToCount: 256 << 10), !chunk.isEmpty {
            buf.append(chunk)
            if let r = buf.range(of: marker) { buf = buf.prefix(r.lowerBound); break }
        }
        guard buf.starts(with: Data("#ASDF".utf8)) else { return nil }
        return parse(yaml: String(decoding: buf, as: UTF8.self))
    }

    /// Parse the `inventory:` map out of ASDF YAML text.
    public static func parse(yaml: String) -> DKISTDataset? {
        let lines = yaml.split(separator: "\n", omittingEmptySubsequences: false)
        func indent(_ l: Substring) -> Int { l.prefix { $0 == " " }.count }
        guard let at = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "inventory:" }) else { return nil }
        let base = indent(lines[at])
        var kv: [String: String] = [:]
        var child: Int?   // indent of the map's own keys, taken from its first line
        for l in lines[(at + 1)...] {
            if l.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            if indent(l) <= base { break }
            child = child ?? indent(l)
            guard indent(l) == child, let colon = l.firstIndex(of: ":") else { continue }
            let key = l[..<colon].trimmingCharacters(in: .whitespaces)
            kv[key] = l[l.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        func scalar(_ k: String) -> String? {
            guard var v = kv[k], v != "null", v != "~", !v.isEmpty else { return nil }
            if v.count >= 2, let f = v.first, f == "'" || f == "\"", v.last == f { v = String(v.dropFirst().dropLast()) }
            return v
        }
        func list(_ k: String) -> [String] {
            guard let v = scalar(k) else { return [] }
            let inner = v.hasPrefix("[") && v.hasSuffix("]") ? String(v.dropFirst().dropLast()) : v
            return inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        guard let id = scalar("datasetId") else { return nil }
        return DKISTDataset(
            datasetID: id, instrument: scalar("instrumentName"), start: scalar("startTime"), end: scalar("endTime"),
            frameCount: scalar("frameCount").flatMap { Int($0) }, spectralLines: list("spectralLines"),
            stokes: list("stokesParameters"), targets: list("targetTypes"),
            waveMinNM: scalar("wavelengthMin").flatMap { Double($0) },
            waveMaxNM: scalar("wavelengthMax").flatMap { Double($0) })
    }

    // MARK: text

    /// "2025-03-25 19:24 UT" from an ISO time, to the minute.
    static func shortTime(_ t: String) -> String { String(t.replacingOccurrences(of: "T", with: " ").prefix(16)) + " UT" }

    /// The header line: "CRYO-NIRSP DRMSEL".
    public var title: String { [instrument, datasetID].compactMap { $0 }.joined(separator: " ") }

    /// The card's body lines, top to bottom; a line is left out when the file does not state it.
    public var lines: [String] {
        var out: [String] = []
        if let s = start {
            // Same-day end shown as time only: "2025-03-25 19:24–20:44 UT".
            if let e = end {
                let a = Self.shortTime(s), b = Self.shortTime(e)
                out.append(a.prefix(10) == b.prefix(10) ? "\(a.dropLast(3))\u{2013}\(b.dropFirst(11))" : "\(a) to \(b)")
            } else { out.append(Self.shortTime(s)) }
        }
        if let n = frameCount { out.append("\(n) frames") }
        if !spectralLines.isEmpty { out.append(spectralLines.joined(separator: ", ")) }
        if !stokes.isEmpty { out.append("Stokes " + stokes.joined(separator: ", ")) }
        if !targets.isEmpty { out.append(targets.joined(separator: ", ")) }
        if let lo = waveMinNM, let hi = waveMaxNM, hi > lo { out.append(String(format: "%.2f to %.2f nm", lo, hi)) }
        return out
    }

    /// Quick Look body text.
    public var summaryText: String { ([title] + lines).joined(separator: "\n") }

    // MARK: thumbnail

    /// Draw the card filling `pixels` of `ctx` (CoreGraphics, y up): the charcoal card and gold
    /// band of the processing-record card, the title on the band, then the lines.
    public func drawCard(in ctx: CGContext, pixels: CGSize) {
        let w = pixels.width, h = pixels.height, s = min(w, h)
        ctx.saveGState()
        defer { ctx.restoreGState() }
        let card = CGPath(roundedRect: CGRect(x: 0, y: 0, width: w, height: h),
                          cornerWidth: s * 0.12, cornerHeight: s * 0.12, transform: nil)
        ctx.addPath(card)
        ctx.setFillColor(CGColor(srgbRed: 0.11, green: 0.11, blue: 0.13, alpha: 1))
        ctx.fillPath()
        ctx.addPath(card)
        ctx.clip()
        let band = h * 0.2
        ctx.setFillColor(CGColor(srgbRed: 0.98, green: 0.75, blue: 0.20, alpha: 1))
        ctx.fill(CGRect(x: 0, y: h - band, width: w, height: band))
        let size = s * 0.075
        guard size >= 4 else { return }   // too small to read: the band and card say enough
        let pad = s * 0.08
        let ink = CGColor(srgbRed: 0.11, green: 0.11, blue: 0.13, alpha: 1)
        HFRecord.drawLine(title, in: ctx, x: pad, y: h - band + (band - size) / 2 + size * 0.15,
                          width: w - 2 * pad, size: size * 0.9, color: ink, bold: true)
        var y = h - band - pad - size
        for l in lines where y > pad * 0.5 {
            HFRecord.drawLine(l, in: ctx, x: pad, y: y, width: w - 2 * pad, size: size * 0.9,
                              color: CGColor(gray: 0.86, alpha: 1))
            y -= size * 1.3
        }
    }
}
