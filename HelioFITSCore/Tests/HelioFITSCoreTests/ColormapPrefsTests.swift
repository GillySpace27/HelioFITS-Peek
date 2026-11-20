//
//  ColormapPrefsTests.swift: the user's colortable choices (resolution order, storage,
//  schema safety) and that they change the colours only, never the data kind or the stretch.
//

import Testing
import Foundation
@testable import HelioFITSCore

@Suite("Colormap preferences")
struct ColormapPrefsTests {
    static let scratch = "HF.ColormapPrefsTests"

    private func suite(_ name: String) throws -> UserDefaults {
        let d = try #require(UserDefaults(suiteName: Self.scratch + "." + name))
        d.removePersistentDomain(forName: Self.scratch + "." + name)
        return d
    }

    @Test("the key is pinned")
    func keyPinned() {
        #expect(SharedSettings.colormapPrefsKey == "colormapPrefs")
    }

    @Test("no choices: every file keeps the header's table")
    func automatic() {
        let p = ColormapPrefs()
        #expect(p.isEmpty)
        #expect(p.resolve(autoKey: "sdoaia171") == "sdoaia171")
        #expect(p.resolve(autoKey: nil) == nil)
    }

    @Test("channel beats family beats automatic")
    func order() {
        var p = ColormapPrefs()
        p.family["sdoaia"] = "sdoaia304"
        #expect(p.resolve(autoKey: "sdoaia171") == "sdoaia304")
        #expect(p.resolve(autoKey: "sdoaia193") == "sdoaia304")
        p.channel["sdoaia171"] = "sdoaia94"
        #expect(p.resolve(autoKey: "sdoaia171") == "sdoaia94")
        #expect(p.resolve(autoKey: "sdoaia193") == "sdoaia304")
        // another family is untouched
        #expect(p.resolve(autoKey: "goes-rsuvi195") == "goes-rsuvi195")
    }

    @Test("gray forces grayscale; a fallback colours a file with no table")
    func grayAndFallback() {
        var p = ColormapPrefs()
        p.channel["sdoaia171"] = ColormapPrefs.gray
        #expect(p.resolve(autoKey: "sdoaia171") == nil)
        p.fallback = "sdoaia193"
        #expect(p.resolve(autoKey: nil) == "sdoaia193")
        p.fallback = ColormapPrefs.gray
        #expect(p.resolve(autoKey: nil) == nil)
    }

    @Test("a table name this build does not know is ignored")
    func unknownName() {
        var p = ColormapPrefs()
        p.channel["sdoaia171"] = "no-such-table"
        p.family["sdoaia"] = "also-missing"
        p.fallback = "nope"
        #expect(p.resolve(autoKey: "sdoaia171") == "sdoaia171")
        #expect(p.resolve(autoKey: nil) == nil)
    }

    @Test("families derive from the key prefix")
    func families() {
        #expect(ColormapPrefs.family(of: "sdoaia171") == "sdoaia")
        #expect(ColormapPrefs.family(of: "goes-rsuvi195") == "goes-rsuvi")
        #expect(ColormapPrefs.family(of: "sswidlsoholasco2") == "sswidlsoholasco")
        #expect(ColormapPrefs.family(of: "hmimag") == "hmimag")
        // every shipped table lands in exactly one listed family
        let listed = ColormapPrefs.families.flatMap { $0.tables }
        #expect(Set(listed) == Set(FITSColormaps.tables.keys))
        #expect(listed.count == FITSColormaps.tables.count)
    }

    @Test("save and load round trip; an empty set removes the key")
    func roundTrip() throws {
        let d = try suite("rt")
        #expect(ColormapPrefs.load(from: d).status == .none)
        var p = ColormapPrefs()
        p.channel["sdoaia171"] = "sdoaia304"
        p.family["goes-rsuvi"] = "sdoaia193"
        p.fallback = "sdoaia94"
        #expect(p.save(to: d))
        let r = ColormapPrefs.load(from: d)
        #expect(r.status == .ok && r.prefs == p)
        #expect(ColormapPrefs().save(to: d))
        #expect(d.data(forKey: SharedSettings.colormapPrefsKey) == nil)
    }

    @Test("a newer schema is read but never overwritten; garbage reads as none")
    func schemaSafety() throws {
        let d = try suite("schema")
        let newer = Data(#"{"schema": 99, "channel": {"sdoaia171": "sdoaia304"}, "future": 1}"#.utf8)
        d.set(newer, forKey: SharedSettings.colormapPrefsKey)
        let r = ColormapPrefs.load(from: d)
        #expect(r.status == .newerSchema)
        #expect(r.prefs.resolve(autoKey: "sdoaia171") == "sdoaia304")
        var p = ColormapPrefs(); p.fallback = "sdoaia94"
        #expect(p.save(to: d) == false)
        #expect(d.data(forKey: SharedSettings.colormapPrefsKey) == newer)
        d.set(Data("not json".utf8), forKey: SharedSettings.colormapPrefsKey)
        #expect(ColormapPrefs.load(from: d).status == .unreadable)
        #expect(ColormapPrefs.current(in: d).isEmpty)
        // a stored value with no schema field (schema 0) reads as the current one
        let old = ColormapPrefs.decode(Data(#"{"schema": 0, "family": {"sdoaia": "sdoaia304"}}"#.utf8))
        #expect(old.status == .ok && old.prefs.schema == ColormapPrefs.currentSchema)
    }

    @Test("export and import")
    func exportImport() throws {
        var p = ColormapPrefs(); p.channel["sdoaia171"] = "sdoaia304"
        #expect(try ColormapPrefs.importing(p.encoded()) == p)
        #expect(throws: (any Error).self) { try ColormapPrefs.importing(Data("[]".utf8)) }
        #expect(throws: (any Error).self) { try ColormapPrefs.importing(Data(#"{"schema": 7}"#.utf8)) }
    }

    @Test("an override changes the colours only: data kind, limits and gamma stay")
    func renderKeepsStretch() throws {
        let path = RepoPaths.fixture("Real/aia_cutout.fits").path
        let base = try FITSRenderer.render(path: path, colormaps: ColormapPrefs())
        #expect(base.display == nil)
        var p = ColormapPrefs()
        p.family["sdoaia"] = "sdoaia304"
        let r = try FITSRenderer.render(path: path, colormaps: p)
        #expect(r.cmapKey == base.cmapKey)            // the data kind is the header's
        #expect(r.tableKey == "sdoaia304")
        #expect(r.lo == base.lo && r.hi == base.hi && r.gam == base.gam)
        #expect(r.header.contains("COLORMAP  sdoaia304"))
        #expect(try PixelBytes.rgba8(r.image) != PixelBytes.rgba8(base.image))
        // grayscale override
        var g = ColormapPrefs(); g.channel[base.cmapKey ?? ""] = ColormapPrefs.gray
        let gr = try FITSRenderer.render(path: path, colormaps: g)
        #expect(gr.tableKey == nil && gr.cmapKey == base.cmapKey)
    }

    @Test("a file with no table takes the fallback")
    func renderFallback() throws {
        let path = try TestFITS.write(width: 32, height: 32) { x, y, _ in Float(x + y) }
        defer { try? FileManager.default.removeItem(atPath: path) }
        let plain = try FITSRenderer.render(path: path, hdu: 0, colormaps: ColormapPrefs())
        #expect(plain.cmapKey == nil && plain.tableKey == nil)
        var p = ColormapPrefs(); p.fallback = "sdoaia171"
        let r = try FITSRenderer.render(path: path, hdu: 0, colormaps: p)
        #expect(r.cmapKey == nil && r.tableKey == "sdoaia171")
        #expect(try PixelBytes.rgba8(r.image) != PixelBytes.rgba8(plain.image))
    }
}
