//
//  FolderIndexTests.swift: the folder table's rows (FITSFolderIndex) read the keywords
//  FITSMetadataImporter/fits_header.c reads, in the same order of precedence, so the
//  table and Spotlight agree about a file.
//

import Testing
import Foundation
@testable import HelioFITSCore

@Suite("FITS folder index")
struct FolderIndexTests {
    /// A tile-compressed image HDU (ZIMAGE = T) after a primary HDU that alone carries
    /// TELESCOP. Only the headers matter here: the one tile is empty. The raw table is
    /// 8 x 1 (NAXIS1, NAXIS2); the image is 200 x 100 (ZNAXIS1, ZNAXIS2). No DATE-OBS,
    /// only T_OBS.
    static func compressed() -> Data {
        func hdu(_ cards: [(String, String)]) -> String {
            var h = cards.map { TestFITS.card($0.0, $0.1) }.joined()
            h += "END".padding(toLength: 80, withPad: " ", startingAt: 0)
            return h + String(repeating: " ", count: (2880 - h.utf8.count % 2880) % 2880)
        }
        var d = Data(hdu([("SIMPLE", "T"), ("BITPIX", "8"), ("NAXIS", "0"), ("EXTEND", "T"),
                          ("TELESCOP", "'TEST PRIMARY'")]).utf8)
        d += Data(hdu([("XTENSION", "'BINTABLE'"), ("BITPIX", "8"), ("NAXIS", "2"), ("NAXIS1", "8"),
                       ("NAXIS2", "1"), ("PCOUNT", "0"), ("GCOUNT", "1"), ("TFIELDS", "1"),
                       ("TTYPE1", "'COMPRESSED_DATA'"), ("TFORM1", "'1PB(0)'"), ("ZIMAGE", "T"),
                       ("ZBITPIX", "16"), ("ZNAXIS", "2"), ("ZNAXIS1", "200"), ("ZNAXIS2", "100"),
                       ("ZTILE1", "200"), ("ZTILE2", "100"), ("ZCMPTYPE", "'GZIP_1'"),
                       ("INSTRUME", "'TEST ZIMAGE'"), ("WAVELNTH", "1700"), ("WAVEUNIT", "'angstrom'"),
                       ("T_OBS", "'2024-05-01T12:00:00'"), ("EXPTIME", "0.5")]).utf8)
        d += Data(repeating: 0, count: 2880)          // one empty tile descriptor, padded
        return d
    }

    /// The committed fixtures plus three made here: the compressed file above, a 9 x 7
    /// image with no INSTRUME, and a .fits file that is not FITS. A subfolder holds one
    /// more FITS file, which a non-recursive scan must not see.
    static func folder() throws -> URL {
        let fm = FileManager.default
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("heliofits_index_\(UUID())")
        try fm.createDirectory(at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)
        for f in ["synthetic_disk.fits", "synthetic_cube.fits", "table_only.fits",
                  "Real/aia_cutout.fits", "Real/punch_pam_cube_cutout.fits"] {
            let src = RepoPaths.fixture(f)
            try fm.copyItem(at: src, to: dir.appendingPathComponent(src.lastPathComponent))
        }
        try compressed().write(to: dir.appendingPathComponent("compressed.fz"))
        let small = try TestFITS.write(width: 9, height: 7, cards: [("TELESCOP", "'TEST'")]) { x, _, _ in Float(x) }
        try fm.moveItem(atPath: small, toPath: dir.appendingPathComponent("no_instrume.fits").path)
        try Data("not a FITS file".utf8).write(to: dir.appendingPathComponent("notes.fits"))
        try Data("text".utf8).write(to: dir.appendingPathComponent("readme.txt"))
        try fm.copyItem(at: RepoPaths.fixture("synthetic_disk.fits"),
                        to: dir.appendingPathComponent("sub/nested.fits"))
        return dir
    }

    @Test("rows carry fits_header.c's keywords and fallbacks; skipped files still count as read; sorts are numeric")
    func index() async throws {
        let dir = try Self.folder()
        defer { try? FileManager.default.removeItem(at: dir) }

        var steps: [FITSFolderIndex.Step] = []
        for await s in FITSFolderIndex.rows(in: dir) { steps.append(s) }
        // Eight candidate files (readme.txt and sub/ are not); notes.fits and table_only.fits are skipped.
        #expect(steps.map(\.done) == Array(1...8))
        #expect(steps.allSatisfy { $0.total == 8 })
        let rows = steps.compactMap(\.row)
        #expect(rows.map(\.name) == ["aia_cutout.fits", "compressed.fz", "no_instrume.fits",
                                     "punch_pam_cube_cutout.fits", "synthetic_cube.fits", "synthetic_disk.fits"])
        let by = Dictionary(uniqueKeysWithValues: rows.map { ($0.name, $0) })

        // AIA: everything in HDU 1; DATE-OBS wins over T_OBS (fits_header.c and main.c).
        let aia = try #require(by["aia_cutout.fits"])
        #expect(aia.telescope == "SDO/AIA" && aia.instrument == "AIA_2")
        #expect(aia.wavelength == 193 && aia.waveUnit == "angstrom")
        #expect(aia.date == "2023-10-11T00:00:04.843")
        #expect(aia.exposure == 2.000057)
        #expect(aia.width == 64 && aia.height == 64 && aia.bitpix == -32 && aia.imageHDUs == 1)

        // Tile-compressed: ZNAXISn over NAXISn, ZBITPIX over BITPIX, TELESCOP from the
        // primary HDU (first non-empty across HDUs), T_OBS when DATE-OBS is absent.
        let z = try #require(by["compressed.fz"])
        #expect(z.width == 200 && z.height == 100 && z.bitpix == 16)
        #expect(z.telescope == "TEST PRIMARY" && z.instrument == "TEST ZIMAGE")
        #expect(z.date == "2024-05-01T12:00:00")
        #expect(z.wavelength == 1700 && z.exposure == 0.5)

        // A cube's size is its first two axes.
        let cube = try #require(by["punch_pam_cube_cutout.fits"])
        #expect(cube.width == 64 && cube.height == 64 && cube.wavelength == 530 && cube.waveUnit == "nanometer")

        let bare = try #require(by["no_instrume.fits"])
        #expect(bare.instrument == nil && bare.telescope == "TEST" && bare.width == 9 && bare.height == 7)
        #expect(by.values.allSatisfy { ($0.fileBytes ?? 0) > 0 })

        func names(_ c: FITSFolderIndex.Column, _ o: SortOrder = .forward) -> [String] {
            rows.sorted(using: FITSFolderIndex.Order(c, order: o)).map(\.name)
        }
        // 9 x 7 = 63 pixels < 64 x 64 < 200 x 100, ties keep file-name order.
        #expect(names(.size) == ["no_instrume.fits", "aia_cutout.fits", "punch_pam_cube_cutout.fits",
                                 "synthetic_cube.fits", "synthetic_disk.fits", "compressed.fz"])
        // In one unit: 193 Å < 1700 Å < 530 nm = 5300 Å (by the number as written, 530 would
        // sort before 1700); files with no WAVELNTH last, both ways.
        #expect(names(.wavelength) == ["aia_cutout.fits", "compressed.fz", "punch_pam_cube_cutout.fits",
                                       "no_instrume.fits", "synthetic_cube.fits", "synthetic_disk.fits"])
        #expect(names(.wavelength, .reverse) == ["punch_pam_cube_cutout.fits", "compressed.fz", "aia_cutout.fits",
                                                 "no_instrume.fits", "synthetic_cube.fits", "synthetic_disk.fits"])
        #expect(names(.instrument, .reverse).last == "no_instrume.fits")

        let csv = FITSFolderIndex.csv([aia, bare]).components(separatedBy: "\r\n")
        #expect(csv[1].hasPrefix("aia_cutout.fits,AIA_2,SDO/AIA,193.0,angstrom,2023-10-11T00:00:04.843,2.000057,64,64,-32,1,"))
        #expect(csv[2].hasPrefix("no_instrume.fits,,TEST,,,,,9,7,-32,1,"))
    }

    @Test("wavelength sorts in one unit (Å); an unknown or missing unit sorts last, with no wavelength")
    func wavelengthUnits() {
        func row(_ name: String, _ w: Double?, _ unit: String?) -> FITSFolderIndex.Row {
            FITSFolderIndex.Row(path: "/x/" + name, wavelength: w, waveUnit: unit, imageHDUs: 1)
        }
        let rows = [row("a", 30.4, "nm"), row("b", 1700, "Angstrom"), row("c", 5.3e-7, "m"), row("d", 193, "angstrom"),
                    row("e", 2, "furlong"), row("f", nil, nil), row("g", 171, nil), row("h", 0.1, "nanometer")]
        let order = rows.sorted(using: FITSFolderIndex.Order(.wavelength)).map(\.name)
        // 0.1 nm = 1 Å, 193 Å, 30.4 nm = 304 Å, 1700 Å, 5.3e-7 m = 5300 Å; then the rest in name order.
        #expect(order == ["h", "d", "a", "b", "c", "e", "f", "g"])
        #expect(rows.sorted(using: FITSFolderIndex.Order(.wavelength, order: .reverse)).map(\.name)
                    == ["c", "b", "a", "d", "h", "e", "f", "g"])

        #expect(rows.map(\.wavelengthLabel) == ["30.4 nm", "1700 Å", "5.3e-07 m", "193 Å", "2 furlong", nil, "171",
                                                "0.1 nm"])
        var r = row("x", nil, nil)
        r.exposure = 2.000057
        r.date = "2023-10-11T00:00:04.843"
        #expect(r.exposureLabel(locale: Locale(identifier: "en_US_POSIX")) == "2.0 s")
        #expect(r.dateLabel == "2023-10-11 00:00")
        r.exposure = 0.0123456
        r.date = "11/10/23"
        #expect(r.exposureLabel(locale: Locale(identifier: "en_US_POSIX")) == "0.0123 s")
        #expect(r.dateLabel == "11/10/23")
    }
}
