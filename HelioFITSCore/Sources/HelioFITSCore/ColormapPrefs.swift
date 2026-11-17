import Foundation

/// The user's colortable choices (Settings, Colortables), shared with the Quick Look and
/// Thumbnail extensions through the app-group defaults.
///
/// Resolution, first hit wins: a per-channel override, then a per-family override, then the
/// table the header picked ("automatic"). A file the header gives no table (grey) takes
/// `fallback` when one is set. The value `"gray"` forces grayscale.
///
/// This changes the DISPLAY table only. The header-derived key stays the data kind, which
/// decides the HMI linear stretch and its symmetric clip (`FITSRenderer.levels`).
///
/// Storage is one append-only key, `SharedSettings.colormapPrefsKey`, holding versioned JSON.
/// Table names are stored, never indexes, and a name this build does not know is ignored, so
/// a table removed or added in another version never breaks a file.
public struct ColormapPrefs: Equatable, Codable, Sendable {
    public static let currentSchema = 1
    /// The value that forces a grayscale image.
    public static let gray = "gray"

    public var schema: Int = ColormapPrefs.currentSchema
    /// Automatic table key (for example `sdoaia171`) to the table to show instead.
    public var channel: [String: String] = [:]
    /// Family (for example `sdoaia`) to the table to show for every channel in it.
    public var family: [String: String] = [:]
    /// For files the header gives no table: the table to show instead of grey.
    public var fallback: String?

    public init() {}

    /// Every key optional, so a file that lacks one (an older, newer or hand-edited export) still
    /// reads instead of coming back unreadable and being overwritten.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? 0
        channel = try c.decodeIfPresent([String: String].self, forKey: .channel) ?? [:]
        family = try c.decodeIfPresent([String: String].self, forKey: .family) ?? [:]
        fallback = try c.decodeIfPresent(String.self, forKey: .fallback)
    }

    public var isEmpty: Bool { channel.isEmpty && family.isEmpty && fallback == nil }

    /// The table key to draw with, or nil for grayscale. `autoKey` is `colormapKey(fromHeader:)`.
    public func resolve(autoKey: String?) -> String? {
        if let k = autoKey {
            if let t = Self.usable(channel[k]) { return t == Self.gray ? nil : t }
            if let t = Self.usable(family[Self.family(of: k)]) { return t == Self.gray ? nil : t }
            return k
        }
        if let t = Self.usable(fallback), t != Self.gray { return t }
        return nil
    }

    private static func usable(_ t: String?) -> String? {
        guard let t else { return nil }
        return t == gray || FITSColormaps.tables[t] != nil ? t : nil
    }

    // MARK: Families

    private static let familyPrefixes = [
        "sswidlsoholasco", "soholasco", "sdoaia", "goes-rsuvi", "euvi", "sohoeit", "trace", "irissji",
        "aspiics", "stereocor", "stereohi", "suit_bb", "suit_nb", "hinodesot", "hinodexrt", "yohkohsxt", "euihri",
    ]

    /// The family a table key belongs to: its instrument prefix, else the key itself.
    public static func family(of key: String) -> String {
        familyPrefixes.first { key.hasPrefix($0) } ?? key
    }

    private static let familyLabels: [String: String] = [
        "sdoaia": "SDO AIA", "goes-rsuvi": "GOES SUVI", "euvi": "STEREO EUVI", "sohoeit": "SOHO EIT",
        "trace": "TRACE", "irissji": "IRIS SJI", "aspiics": "Proba-3 ASPIICS", "soholasco": "SOHO LASCO",
        "sswidlsoholasco": "SOHO LASCO (SSW IDL)", "stereocor": "STEREO COR", "stereohi": "STEREO HI",
        "suit_bb": "SUIT broadband", "suit_nb": "SUIT narrowband", "hinodesot": "Hinode SOT",
        "hinodexrt": "Hinode XRT", "yohkohsxt": "Yohkoh SXT", "euihri": "EUI HRI", "hmimag": "SDO HMI magnetogram",
        "kcor": "K-Cor", "punch": "PUNCH", "rhessi": "RHESSI", "std_gamma_2": "Standard gamma 2",
    ]

    /// A readable name for a family.
    public static func label(forFamily f: String) -> String { familyLabels[f] ?? f }

    /// A readable name for a table key: the family name plus what follows the prefix.
    public static func label(forTable key: String) -> String {
        let f = family(of: key)
        guard let name = familyLabels[f] else { return key }
        let rest = key.dropFirst(f.count)
        return rest.isEmpty ? name : "\(name) \(rest.replacingOccurrences(of: "_", with: " "))"
    }

    /// Every family with its table keys, sorted by label, for the Settings window.
    public static var families: [(id: String, label: String, tables: [String])] {
        var byFamily: [String: [String]] = [:]
        for k in FITSColormaps.tables.keys { byFamily[family(of: k), default: []].append(k) }
        return byFamily.map { (id: $0.key, label: label(forFamily: $0.key), tables: $0.value.sorted()) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    // MARK: Storage

    /// What `load` found, so a caller can tell an absent key from a newer one.
    public enum Stored: Equatable { case none, ok, newerSchema, unreadable }

    /// Decode stored bytes. A missing `schema` reads as 1; a schema above this build's still
    /// decodes the fields it knows, and `load` reports `.newerSchema` so nothing overwrites it.
    public static func decode(_ data: Data) -> (prefs: ColormapPrefs, status: Stored) {
        guard var p = try? JSONDecoder().decode(ColormapPrefs.self, from: data) else {
            return (ColormapPrefs(), .unreadable)
        }
        let newer = p.schema > currentSchema
        if p.schema < 1 { p.schema = currentSchema }
        return (p, newer ? .newerSchema : .ok)
    }

    public static func load(from d: UserDefaults? = SharedSettings.suite) -> (prefs: ColormapPrefs, status: Stored) {
        guard let data = d?.data(forKey: SharedSettings.colormapPrefsKey) else { return (ColormapPrefs(), .none) }
        return decode(data)
    }

    /// The saved choices, or none. The hot path for every render.
    public static func current(in d: UserDefaults? = SharedSettings.suite) -> ColormapPrefs { load(from: d).prefs }

    public func encoded() -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? e.encode(self)) ?? Data()
    }

    /// Write the choices. Returns false and writes nothing when the stored value comes from a
    /// newer version, so a downgrade never destroys it. An empty set removes the key.
    @discardableResult
    public func save(to d: UserDefaults? = SharedSettings.suite) -> Bool {
        guard let d else { return false }
        if Self.load(from: d).status == .newerSchema { return false }
        var p = self
        p.schema = Self.currentSchema
        if p.isEmpty { d.removeObject(forKey: SharedSettings.colormapPrefsKey) }
        else { d.set(p.encoded(), forKey: SharedSettings.colormapPrefsKey) }
        return true
    }

    /// Prefs from an exported file. Throws for bytes that are not prefs or come from a newer version.
    public static func importing(_ data: Data) throws -> ColormapPrefs {
        let r = decode(data)
        switch r.status {
        case .ok: return r.prefs
        case .newerSchema:
            throw NSError(domain: "ColormapPrefs", code: 2, userInfo: [NSLocalizedDescriptionKey:
                "These preferences come from a newer HelioFITS Peek. Update the app to read them."])
        default:
            throw NSError(domain: "ColormapPrefs", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "That file is not a HelioFITS Peek colortable preferences file."])
        }
    }
}
