//
//  HFRecordReport.swift: readable renderings of a processing record (.hfrec.json), the sidecar
//  HelioFITS Studio and pyHelioFITS write beside an export.
//
//  A port of pyHelioFITS src/heliofits/core/report.py (and the display() rows of record.py
//  it reads), whose text layout is the contract: a plain text report, a methods paragraph, the
//  same as LaTeX, and a Python script that opens the same sources. HelioFITS Peek cannot run
//  Python (App Store sandbox), so the port is checked line for line against output of
//  `python -m heliofits.core record show FILE --format text|methods|tex|python [--full]` in
//  HFRecordReportTests (fixtures in HelioFITSCore/Tests/hfrecord/).
//
//  Foundation only, so the Spotlight importer can compile it beside HFRecordJSON.swift.
//

import Foundation

public struct HFRecord {
    public let root: HFJSON

    public static let sidecarSuffix = ".hfrec.json"
    public static let width = 100

    public init(root: HFJSON) { self.root = root }

    /// Parse a record. Throws for text that is not JSON or not a JSON object.
    public init(data: Data) throws {
        let v = try HFJSON.parse(data)
        guard v.isObject else { throw HFJSON.ParseError(offset: 0, message: "a processing record is a JSON object") }
        root = v
    }

    /// Larger files are refused unread, so a stray huge JSON cannot stall Quick Look or Spotlight.
    public static let maxBytes = 256 << 20

    public init(contentsOf url: URL) throws {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= Self.maxBytes else {
            throw HFJSON.ParseError(offset: 0, message: "\(size) bytes is larger than a processing record reader accepts")
        }
        try self.init(data: try Data(contentsOf: url))
    }

    /// A name Peek treats as a processing record: `<export>.hfrec.json` or `<export>.hfrec`.
    public static func isRecordName(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.hasSuffix(sidecarSuffix) || n.hasSuffix(".hfrec")
    }

    // MARK: facts for headers, thumbnails and Spotlight

    var producerObj: HFJSON { root["producer"].flatMap { $0.isObject ? $0 : nil } ?? .object([]) }
    var outputObj: HFJSON { root["output"].flatMap { $0.isObject ? $0 : nil } ?? .object([]) }
    var sceneObj: HFJSON { root["scene"].flatMap { $0.isObject ? $0 : nil } ?? .object([]) }
    /// The record's layers that are objects, in drawing order (bottom first).
    var rawLayers: [HFJSON] { (root["layers"]?.arrayValue ?? []).filter(\.isObject) }

    /// The exported file's name (output.file_name), when the record names one.
    public var outputFileName: String? {
        guard let n = outputObj["file_name"]?.stringValue, !n.isEmpty, !n.contains("/") else { return nil }
        return n
    }
    public var layerCount: Int { rawLayers.count }
    /// "HelioFITS Studio 0.9.1": producer program and version.
    public var program: String? {
        let p = ["program", "version"].compactMap { producerObj[$0] }.filter(\.truthy).map(\.pyStr)
        return p.isEmpty ? nil : p.joined(separator: " ")
    }
    /// The scene time, else the start of its time range, else when the record was made.
    public var date: String? {
        if let t = sceneObj["time"]?.stringValue, !t.isEmpty { return t }
        if let r = sceneObj["time_range"]?.arrayValue, let t = r.first?.stringValue { return t }
        return root["created"]?.stringValue
    }
    /// Per layer, top first: "PUNCH WFI+NFI Mosaic" style instrument names (observatory, instrument).
    public var instruments: [String] {
        rawLayers.reversed().map { layer -> String in
            let ds = Self.dataset(layer)
            let head = [ds["observatory"], ds["instrument"]].compactMap { $0 }.filter(\.truthy).map(\.pyStr)
            if !head.isEmpty { return head.joined(separator: " ") }
            return (ds["label"].flatMap { $0.truthy ? $0 : nil } ?? layer["name"])?.pyStr ?? "layer"
        }
    }
    /// Per layer, top first: the dataset label the report uses as the layer's title.
    public var layerLabels: [String] { display().layers.map { $0.title } }
    /// Every source time in the record, first and last.
    public var timeRange: (start: String, end: String)? {
        let t = rawLayers.flatMap { Self.sources($0) }.compactMap { $0["date_obs"] }.filter(\.truthy).map(\.pyStr)
            .sorted(by: Self.pyLess)
        guard let a = t.first, let b = t.last else { return nil }
        return (a, b)
    }
    /// Every source file name the record lists.
    public var sourceFileNames: [String] {
        rawLayers.flatMap { Self.sources($0) }.compactMap { $0["original_name"]?.stringValue }
    }

    /// The report a person sees: the record's own `report` lines when it carries them, else the
    /// generated text report (record.py read(): `view["report"]`).
    public var reportLines: [String] {
        if let stored = root["report"]?.arrayValue { return stored.compactMap(\.stringValue) }
        return block()
    }

    /// The export this sidecar describes, beside it: output.file_name, else the sidecar's name
    /// without `.hfrec.json`, else the one file that starts with that stem (record.py _export_beside).
    public func exportBeside(sidecar: URL) -> URL? {
        let dir = sidecar.deletingLastPathComponent()
        let fm = FileManager.default
        func isFile(_ u: URL) -> Bool {
            var d: ObjCBool = false
            return fm.fileExists(atPath: u.path, isDirectory: &d) && !d.boolValue
        }
        if let n = outputFileName, isFile(dir.appendingPathComponent(n)) { return dir.appendingPathComponent(n) }
        let name = sidecar.lastPathComponent
        let lower = name.lowercased()
        let suffix = lower.hasSuffix(Self.sidecarSuffix) ? Self.sidecarSuffix : (lower.hasSuffix(".hfrec") ? ".hfrec" : "")
        guard !suffix.isEmpty else { return nil }
        let stem = String(name.dropLast(suffix.count))
        if isFile(dir.appendingPathComponent(stem)) { return dir.appendingPathComponent(stem) }
        let names = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
        let matches = names.filter { $0.hasPrefix(stem + ".") && $0 != name && !Self.isRecordName($0) }
            .map { dir.appendingPathComponent($0) }.filter(isFile)
        return matches.count == 1 ? matches[0] : nil
    }

    // MARK: display rows (record.py display())

    struct Step {
        var index: Int, op: String, knownOp: Bool
        var stage: String?, algorithm: String?, implementation: String?
        var automatic: Bool
        var params: [(String, String)], resolved: [(String, String)], units: [(String, String)]
        var varies: Bool, variesParams: [String]
        var reference: String?, caveat: String?, citation: String?
    }

    struct Row {
        var drawn: Int, name: String?, enabled: Bool
        var datasetKey: String?, datasetLabel: String?
        var frames: Int, shortened: Bool, sourceSpec: String?
        var steps: [Step], caveats: [String], acknowledgement: String?
        /// `dataset_label or name`, as Python prints it (None when both are missing).
        var title: String { datasetLabel.flatMap { $0.isEmpty ? nil : $0 } ?? name ?? "None" }
    }

    struct View {
        var summary: String, producer: String, dirty: Bool, created: String?
        var recordID: String?, format: String?
        var scene: [(String, String)], layers: [Row]
        var caveats: [String], citations: [String], acknowledgements: [String], rebuild: [String]
    }

    static let knownOps: Set<String> = [
        "instrument_correction", "select_plane", "clip", "stretch", "image_filter", "sequence_filter", "levels",
        "radial_gain", "difference", "sharpen", "rhef_upsilon", "colormap", "channel_mask", "geometric_mask",
        "pointing", "opacity_blend", "radial_transform", "reproject", "feather",
    ]

    /// _s(): a string field as it is, null as nil, anything else as JSON text.
    static func s(_ v: HFJSON?) -> String? {
        guard let v, v != .null else { return nil }
        return text(v)
    }
    /// _text(): a string as it is, anything else as JSON text.
    static func text(_ v: HFJSON) -> String { v.stringValue ?? v.jsonText }
    static func pairs(_ v: HFJSON?) -> [(String, String)] { (v?.objectPairs ?? []).map { ($0.0, text($0.1)) } }
    static func dataset(_ layer: HFJSON) -> HFJSON { layer["dataset"].flatMap { $0.isObject ? $0 : nil } ?? .object([]) }
    static func sources(_ layer: HFJSON) -> [HFJSON] { (layer["sources"]?.arrayValue ?? []).filter(\.isObject) }
    static func steps(_ layer: HFJSON) -> [HFJSON] { (layer["steps"]?.arrayValue ?? []).filter(\.isObject) }
    /// Python's string ordering: by code point.
    static func pyLess(_ a: String, _ b: String) -> Bool {
        a.unicodeScalars.lexicographicallyPrecedes(b.unicodeScalars)
    }
    /// `a or b`: a when truthy, else b.
    static func or(_ a: HFJSON?, _ b: HFJSON?) -> HFJSON? { (a?.truthy ?? false) ? a : b }

    static func frames(_ layer: HFJSON) -> Int {
        if case .int(let s)? = layer["source_count"], let n = Int(s) { return n }
        return layer["sources"]?.arrayValue?.count ?? 0
    }

    static func filterOf(_ layer: HFJSON) -> String {
        for step in steps(layer) where step["op"] == .string("image_filter") {
            let f = or(step["params"]?["filter"], step["algorithm"])
            if f == nil || f == .null || f == .string("None") { return "no filter" }
            return f!.pyStr
        }
        return "no filter"
    }

    static func lutOf(_ layer: HFJSON) -> String? {
        for step in steps(layer) where step["op"] == .string("colormap") {
            guard let lut = step["params"]?["lut"], lut != .null else { return nil }
            return lut.pyStr
        }
        return nil
    }

    /// generated_summary(): the plain text summary a writer would give, for a record that has none.
    func generatedSummary() -> String {
        let producer = producerObj, output = outputObj, scene = sceneObj
        var when = scene["time"]
        if !(when?.truthy ?? false) {
            let tr = (scene["time_range"]?.arrayValue ?? []).map(\.pyStr).joined(separator: " to ")
            when = tr.isEmpty ? (root["created"] ?? .string("")) : .string(tr)
        }
        let program = producer["program"] ?? .string("Unknown program")
        let version = producer["version"] ?? .string("")
        let head = "\(program.pyStr) \(version.pyStr)".trimmingCharacters(in: .whitespaces)
        var lines = ["\(head), \((output["kind"] ?? .string("export")).pyStr) at \(when!.pyStr)."]
        for (i, layer) in (root["layers"]?.arrayValue ?? []).enumerated() where layer.isObject {
            let n = Self.frames(layer)
            var bits = ["\(n) frame\(n != 1 ? "s" : "")", Self.filterOf(layer)]
            if let lut = Self.lutOf(layer), !lut.isEmpty { bits.append("LUT \(lut)") }
            let label = Self.or(Self.dataset(layer)["label"], layer["name"] ?? .string("layer \(i + 1)"))!
            lines.append("\(i + 1). \(label.pyStr): " + bits.joined(separator: ", "))
        }
        let cites = (root["citations"]?.arrayValue ?? []).compactMap(\.stringValue)
            .map { String($0.split(separator: ",", omittingEmptySubsequences: false)[0]) }
        if !cites.isEmpty { lines.append("Cite: " + cites.joined(separator: "; ") + ".") }
        return lines.joined(separator: "\n")
    }

    static func stepRow(_ i: Int, _ step: HFJSON) -> Step {
        let varies = step["varies"].flatMap { $0.isObject ? $0 : nil }
        var reference: String?
        if let ref = step["reference"], ref.isObject {
            switch ref["kind"] {
            case .string("running")?: reference = "previous frame (running difference)"
            case .string("base")?: reference = "base frame: source \((ref["source_index"] ?? .null).pyStr)"
            case .string("compare")?: reference = "compared with layer \((ref["layer_id"] ?? .null).pyStr)"
            default: reference = text(ref)
            }
        }
        let op = (step["op"] ?? .string("")).pyStr
        return Step(index: i, op: op, knownOp: knownOps.contains(op),
                    stage: s(step["stage"]), algorithm: s(step["algorithm"]), implementation: s(step["implementation"]),
                    automatic: step["automatic"]?.truthy ?? false,
                    params: pairs(step["params"]), resolved: pairs(step["resolved"]), units: pairs(step["units"]),
                    varies: varies != nil, variesParams: (varies?["params"]?.arrayValue ?? []).map(\.pyStr),
                    reference: reference, caveat: s(step["caveat"]), citation: s(step["citation"]))
    }

    func display() -> View {
        var layers: [Row] = []
        var acks: [String] = []
        for (drawn, layer) in rawLayers.enumerated() {
            let ds = Self.dataset(layer)
            let steps = Self.steps(layer)
            let ack = layer["acknowledgement"]?.stringValue
            if let ack, !ack.isEmpty { acks.append(ack) }
            let spec = layer["source_spec"].flatMap { $0.isObject ? $0 : nil } ?? .object([])
            layers.append(Row(
                drawn: drawn, name: Self.s(layer["name"]), enabled: layer["enabled"] != .bool(false),
                datasetKey: Self.s(ds["dataset_key"]), datasetLabel: Self.s(Self.or(ds["label"], layer["name"])),
                frames: Self.frames(layer), shortened: layer["source_count"] != nil, sourceSpec: Self.s(spec["kind"]),
                steps: steps.enumerated().map { Self.stepRow($0.offset + 1, $0.element) },
                caveats: steps.compactMap { $0["caveat"]?.stringValue }, acknowledgement: ack))
        }
        let producer = producerObj
        let head = ["program", "version"].compactMap { producer[$0] }.filter(\.truthy).map(\.pyStr)
            .joined(separator: " ")
        let build = [("build_id", "build"), ("commit", "commit")].compactMap { k, label -> String? in
            guard let v = producer[k], v.truthy else { return nil }
            return "\(label) \(v.pyStr)"
        }.joined(separator: ", ")
        var rebuild: [String] = []
        if producer["dirty"]?.truthy ?? false { rebuild.append("made by a build with uncommitted changes") }
        if rawLayers.contains(where: { $0["source_spec"]?["kind"] == .string("helioviewer_api") }) {
            rebuild.append("a Helioviewer layer cannot promise the same pixels")
        }
        return View(
            summary: root["summary"]?.stringValue ?? generatedSummary(),
            producer: head + (build.isEmpty ? "" : " (\(build))"),
            dirty: producer["dirty"]?.truthy ?? false,
            created: Self.s(root["created"]), recordID: Self.s(root["record_id"]), format: Self.s(root["hfrecord"]),
            scene: Self.pairs(sceneObj), layers: layers.reversed(),
            caveats: (root["caveats"]?.arrayValue ?? []).compactMap(\.stringValue),
            citations: (root["citations"]?.arrayValue ?? []).compactMap(\.stringValue),
            acknowledgements: acks, rebuild: rebuild)
    }

    // MARK: text report (report.py text())

    static let paramNoise: Set<String> = ["None", "null", ""]

    static func kv(_ pairs: [(String, String)]) -> String {
        pairs.filter { !paramNoise.contains($0.1) }.map { "\($0.0)=\($0.1)" }.joined(separator: ", ")
    }

    static func size(_ n: Int) -> String {
        var x = Double(n)
        for unit in ["B", "kB", "MB", "GB"] {
            if x < 1000 || unit == "GB" {
                return unit == "B" ? "\(n) B" : String(format: "%.1f %@", x, unit)
            }
            x /= 1000
        }
        return ""
    }

    static func len(_ s: String) -> Int { s.unicodeScalars.count }

    static func rstrip(_ s: String) -> String {
        var u = Substring(s).unicodeScalars
        while let l = u.last, l.properties.isWhitespace { u.removeLast() }
        return String(u)
    }

    /// Python's str.split() with no argument.
    static func words(_ s: String) -> [String] {
        var out: [String] = [], cur = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            if u.properties.isWhitespace || (0x1C...0x1F).contains(u.value) {
                if !cur.isEmpty { out.append(String(cur)); cur = String.UnicodeScalarView() }
            } else {
                cur.append(u)
            }
        }
        if !cur.isEmpty { out.append(String(cur)) }
        return out
    }

    /// _wrap(): label then text on the first line; continuation lines hang under the text.
    static func wrap(_ label: String, _ text: String, _ indent: Int) -> [String] {
        let pad = String(repeating: " ", count: indent)
        let first = pad + label
        let start = max(len(first) + 1, indent + 11)
        var lines: [String] = []
        var cur = first + String(repeating: " ", count: max(0, start - len(first)))
        for w in words(text) {
            if len(cur) + len(w) + 1 > width && !cur.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append(rstrip(cur))
                cur = String(repeating: " ", count: start)
            }
            cur += (cur.hasSuffix(" ") ? "" : " ") + w
        }
        lines.append(rstrip(cur))
        return lines
    }

    static func datasetLine(_ ds: HFJSON) -> String {
        let head = [ds["observatory"], ds["instrument"], ds["detector"]].compactMap { $0 }.filter(\.truthy)
            .map(\.pyStr).joined(separator: " ")
        var extra: [String] = []
        if let p = ds["product"], p.truthy { extra.append("product \(p.pyStr)") }
        if let l = ds["level"], l.truthy { extra.append("level \(l.pyStr)") }
        if let w = ds["wavelength"]?.numberValue {
            let g = String(format: "%g", w)
            extra.append(w < 100 || ds["wavelength_unit"] == .string("nm") ? "\(g) nm" : "\(g) Å")
        }
        return ((head.isEmpty ? [] : [head]) + extra).joined(separator: ", ")
    }

    /// The plain text report: one block for the file, one for the scene, one per layer.
    public func text(full: Bool = false) -> String {
        let view = display()
        var out = ["HELIOFITS SUITE PROCESSING RECORD", ""]
        out += Self.wrap("Made by:", view.producer.isEmpty ? "unknown program" : view.producer, 0)
        if let c = view.created, !c.isEmpty { out += Self.wrap("Created:", c, 0) }
        if view.dirty { out += Self.wrap("Warning:", "made by a build with uncommitted changes", 0) }
        let output = outputObj
        if output.truthy {
            var bits: [HFJSON?] = [output["kind"], output["file_name"], output["media_type"]]
            if let w = output["width"], w.truthy, let h = output["height"], h.truthy {
                bits.append(.string("\(w.pyStr) x \(h.pyStr) px"))
            } else {
                bits.append(nil)
            }
            bits.append(output["bit_depth"].flatMap { $0.truthy ? .string("\($0.pyStr)-bit") : nil })
            bits.append(output["colorspace"])
            bits.append(output["display_referred"]?.truthy == true
                        ? .string("display-referred (pixel values are colours)") : nil)
            out += Self.wrap("Output:", bits.compactMap { $0 }.filter(\.truthy).map(\.pyStr).joined(separator: ", "), 0)
            if let sha = output["sha256"], sha.truthy { out += Self.wrap("SHA-256:", sha.pyStr, 0) }
        }
        if !view.scene.isEmpty { out += Self.wrap("Scene:", Self.kv(view.scene), 0) }
        let layers = view.layers
        out += ["", "LAYERS (\(layers.count), top layer first)", ""]
        let raw = rawLayers
        for (pos, row) in layers.enumerated() {
            let layer = row.drawn < raw.count ? raw[row.drawn] : .object([])
            let sources = Self.sources(layer)
            let title = [row.datasetLabel, row.name].compactMap { $0 }.first { !$0.isEmpty } ?? "unnamed layer"
            out.append("\(pos + 1). \(title)" + (row.enabled ? "" : "  [hidden]"))
            let dline = Self.datasetLine(Self.dataset(layer))
            if !dline.isEmpty { out += Self.wrap("Dataset:", dline, 4) }
            if let k = row.datasetKey, !k.isEmpty { out += Self.wrap("Key:", k, 4) }
            out += Self.wrap("Data:", Self.dataLine(row, sources), 4)
            out += Self.files(sources, layer, full)
            if !row.steps.isEmpty {
                out.append("    Processing, in order applied:")
                for s in row.steps { out += Self.stepLines(s) }
            }
            for c in row.caveats { out += Self.wrap("Caveat:", c, 4) }
            if let a = row.acknowledgement, !a.isEmpty { out += Self.wrap("Credit:", a, 4) }
            out.append("")
        }
        if !view.caveats.isEmpty {
            out.append("CAVEATS")
            for c in view.caveats { out += Self.wrap("-", c, 2) }
            out.append("")
        }
        if !view.citations.isEmpty {
            out.append("PLEASE CITE")
            for c in view.citations { out += Self.wrap("-", c, 2) }
            out.append("")
        }
        if !view.rebuild.isEmpty { out += Self.wrap("Rebuild:", view.rebuild.joined(separator: "; "), 0) }
        if let id = view.recordID, !id.isEmpty {
            out += Self.wrap("Record:", "\(id) (hfrecord \(view.format ?? "None"))", 0)
        }
        return Self.rstrip(out.joined(separator: "\n")) + "\n"
    }

    /// block(): the lines a writer stores as the record's top-level `report` (short file list).
    public func block() -> [String] {
        var t = text()
        while t.hasSuffix("\n") { t.removeLast() }
        return t.components(separatedBy: "\n")
    }

    static func dataLine(_ row: Row, _ sources: [HFJSON]) -> String {
        let n = row.frames
        var bits = ["\(n) frame\(n != 1 ? "s" : "")"]
        let times = sources.compactMap { $0["date_obs"] }.filter(\.truthy).map(\.pyStr).sorted(by: pyLess)
        if let a = times.first, let b = times.last { bits.append(a == b ? a : "\(a) to \(b)") }
        let versions = Set(sources.compactMap { $0["file_version"] }.filter(\.truthy).map(\.pyStr)).sorted(by: pyLess)
        if !versions.isEmpty { bits.append("file version " + versions.joined(separator: ", ")) }
        let total = sources.compactMap { $0["size"]?.intValue }.reduce(0, +)
        if total != 0 { bits.append(size(total)) }
        if row.shortened { bits.append("source list shortened in the record") }
        if let spec = row.sourceSpec, !spec.isEmpty { bits.append("source: \(spec)") }
        return bits.joined(separator: "; ")
    }

    static func fileName(_ s: HFJSON) -> String {
        if let v = or(s["original_name"], s["source_url"]), v.truthy { return v.pyStr }
        return String((s["sha256"]?.stringValue ?? "").unicodeScalars.prefix(12))
    }

    static func files(_ sources: [HFJSON], _ layer: HFJSON, _ full: Bool) -> [String] {
        if sources.isEmpty { return [] }
        if full || sources.count <= 3 {
            return ["    Files:"] + sources.map { s in
                var line = "      \(fileName(s))"
                if let h = s["sha256"], h.truthy { line += "  sha256 \(String((h.stringValue ?? h.pyStr).unicodeScalars.prefix(12)))" }
                return line
            }
        }
        let missing = sources.filter { $0["in_library"] == .bool(false) }.count
        var lines = wrap("Files:", "\(sources.count) files, first \(fileName(sources[0])), last \(fileName(sources[sources.count - 1]))"
                         + (missing != 0 ? "; \(missing) not found in the library" : "")
                         + " (hfcore record show --full lists every file)", 4)
        if let h = layer["source_set_sha256"], h.truthy { lines += wrap("Set hash:", "sha256 \(h.pyStr)", 4) }
        return lines
    }

    static func stepLines(_ s: Step) -> [String] {
        var head = "      \(s.index). \(s.op)"
        if let st = s.stage, !st.isEmpty { head += " (\(st))" }
        if let a = s.algorithm, !a.isEmpty { head += ": \(a)" }
        if let im = s.implementation, !im.isEmpty { head += " via \(im)" }
        if s.automatic { head += " [automatic]" }
        if !s.knownOp { head += " [step not known to this reader]" }
        var lines = [head]
        for (label, p) in [("parameters", s.params), ("resolved", s.resolved), ("units", s.units)] {
            let body = kv(p)
            if !body.isEmpty { lines += wrap("\(label):", body, 10) }
        }
        if let r = s.reference, !r.isEmpty { lines += wrap("reference:", r, 10) }
        if s.varies {
            let v = s.variesParams.joined(separator: ", ")
            lines += wrap("varies:", v.isEmpty ? "over the movie" : v, 10)
        }
        if let c = s.caveat, !c.isEmpty { lines += wrap("caveat:", c, 10) }
        if let c = s.citation, !c.isEmpty { lines += wrap("citation:", c, 10) }
        return lines
    }

    // MARK: methods paragraph and LaTeX

    /// A methods paragraph with the list of things to cite.
    public func methods() -> (paragraph: String, citations: [String]) {
        let view = display()
        let raw = rawLayers
        var parts: [String] = []
        let program = view.producer.isEmpty ? "an unknown program" : view.producer
        let when = Self.or(sceneObj["time"], view.created.map { .string($0) }).map(\.pyStr) ?? ""
        parts.append("The image was produced with \(program)" + (when.isEmpty ? "" : " for \(when)") + ".")
        for row in view.layers.reversed() {
            let layer = row.drawn < raw.count ? raw[row.drawn] : .object([])
            let times = Self.sources(layer).compactMap { $0["date_obs"] }.filter(\.truthy).map(\.pyStr).sorted(by: Self.pyLess)
            var span = ""
            if let a = times.first, let b = times.last { span = a == b ? " at \(a)" : " from \(a) to \(b)" }
            let n = row.frames
            var sentence = "\(row.title) (\(n) frame\(n != 1 ? "s" : "")\(span))"
            let applied = row.steps.compactMap { s -> String? in
                guard let a = s.algorithm, !a.isEmpty, a != "None" else { return nil }
                return "\(a) (\(s.op.replacingOccurrences(of: "_", with: " ")))"
            }
            sentence += applied.isEmpty ? " was shown without filtering" : " was processed with " + applied.joined(separator: ", ")
            parts.append(sentence + ".")
        }
        if !view.caveats.isEmpty {
            parts.append(view.caveats.map { $0.hasSuffix(".") ? $0 : $0 + "." }.joined(separator: " "))
        }
        parts += view.acknowledgements
        return (parts.joined(separator: " "), view.citations)
    }

    /// render(record, "methods"): the paragraph, then one "- " line per citation.
    public func methodsText() -> String {
        let m = methods()
        return m.paragraph + "\n" + m.citations.map { "\n- \($0)" }.joined() + (m.citations.isEmpty ? "" : "\n")
    }

    static let texSpecials: [Character: String] = [
        "\\": "\\textbackslash{}", "&": "\\&", "%": "\\%", "$": "\\$", "#": "\\#", "_": "\\_",
        "{": "\\{", "}": "\\}", "~": "\\textasciitilde{}", "^": "\\textasciicircum{}",
    ]

    static func tex(_ s: String) -> String {
        var out = ""
        for u in s.unicodeScalars {
            if let r = texSpecials[Character(u)] { out += r } else { out.unicodeScalars.append(u) }
        }
        return out
    }

    public func texText() -> String {
        let m = methods()
        var lines = ["% Generated by hfcore record show --format tex from a HelioFITS processing record.", "",
                     Self.tex(m.paragraph), ""]
        if !m.citations.isEmpty {
            lines.append("\\begin{itemize}")
            lines += m.citations.map { "  \\item \(Self.tex($0))" }
            lines.append("\\end{itemize}")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: a Python script

    /// Python's str.splitlines().
    static func splitlines(_ s: String) -> [String] {
        let breaks: Set<UInt32> = [0x0A, 0x0B, 0x0C, 0x0D, 0x1C, 0x1D, 0x1E, 0x85, 0x2028, 0x2029]
        var out: [String] = [], cur = String.UnicodeScalarView()
        var it = Array(s.unicodeScalars)[...]
        while let u = it.popFirst() {
            if breaks.contains(u.value) {
                out.append(String(cur)); cur = String.UnicodeScalarView()
                if u == "\r", it.first == "\n" { it.removeFirst() }
            } else {
                cur.append(u)
            }
        }
        if !cur.isEmpty { out.append(String(cur)) }
        return out
    }

    /// re.sub(r"\W+", "_", text.lower()).strip("_") or "layer", prefixed when it starts with a digit.
    static func varName(_ label: String) -> String {
        var out = String.UnicodeScalarView()
        var inGap = false
        for u in label.lowercased().unicodeScalars {
            let word = u == "_" || u.properties.isAlphabetic || u.properties.numericType != nil
            if word { out.append(u); inGap = false } else if !inGap { out.append("_"); inGap = true }
        }
        var v = String(out)
        while v.hasPrefix("_") { v.removeFirst() }
        while v.hasSuffix("_") { v.removeLast() }
        if v.isEmpty { v = "layer" }
        if let f = v.unicodeScalars.first, f.properties.numericType == .decimal { v = "layer_" + v }
        return v
    }

    /// A starting script: opens the same source files with sunpy and lists the processing steps.
    public func pythonText() -> String {
        let view = display()
        let raw = rawLayers
        var lines = ["\"\"\"Generated by hfcore record show --format python from a HelioFITS processing record.", ""]
        lines += Self.splitlines(view.summary)
        lines += ["", "This opens the same source files. It does not re-run the processing: the steps below are",
                  "what the record says was applied, in order.\"\"\"", "", "import sunpy.map", ""]
        for row in view.layers.reversed() {
            let layer = row.drawn < raw.count ? raw[row.drawn] : .object([])
            let sources = Self.sources(layer)
            let label = [row.datasetLabel, row.name].compactMap { $0 }.first { !$0.isEmpty } ?? "layer"
            let v = Self.varName(label)
            lines.append("# \(row.title)")
            lines.append("\(v)_files = [")
            lines += sources.compactMap { $0["original_name"] }.filter(\.truthy).map { "    \($0.pyRepr)," }
            lines.append("]  # find them by name or sha256 in your library: hfcore files --dataset "
                         + (row.datasetKey ?? "None"))
            lines.append("\(v)_sha256 = [")
            lines += sources.compactMap { $0["sha256"] }.filter(\.truthy).map { "    \($0.pyRepr)," }
            lines.append("]")
            lines.append("# \(v)_maps = [sunpy.map.Map(path) for path in \(v)_files]")
            lines.append("\(v)_steps = [")
            for s in row.steps {
                var seen: [String: Int] = [:]
                var params: [(String, String)] = []
                for (k, val) in s.params {
                    if let at = seen[k] { params[at].1 = val } else { seen[k] = params.count; params.append((k, val)) }
                }
                let p = "{" + params.map { "\(HFJSON.reprString($0.0)): \(HFJSON.reprString($0.1))" }
                    .joined(separator: ", ") + "}"
                let alg = s.algorithm.map(HFJSON.reprString) ?? "None"
                lines.append("    {'op': \(HFJSON.reprString(s.op)), 'algorithm': \(alg), 'params': \(p)},")
            }
            lines.append("]")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: headings

    /// Lines the viewers set as headings: the all-capital section titles and "N. layer" titles.
    public static func isHeading(_ line: String) -> Bool {
        guard let f = line.unicodeScalars.first, f != " " else { return false }
        if line == "HELIOFITS SUITE PROCESSING RECORD" || line == "CAVEATS" || line == "PLEASE CITE" { return true }
        if line.hasPrefix("LAYERS (") { return true }
        let digits = line.prefix { $0.isASCII && $0.isNumber }
        return !digits.isEmpty && line.dropFirst(digits.count).hasPrefix(". ")
    }
}
