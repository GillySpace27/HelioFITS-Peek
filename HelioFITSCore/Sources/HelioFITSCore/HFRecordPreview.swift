//
//  HFRecordPreview.swift: the small picture of the export a processing record (.hfrec) carries
//  as its top-level `preview` object (pyHelioFITS hfrecord-1.schema.json): media_type
//  image/png or image/jpeg, width and height of at most 320 px, base64 `data` of at most 64 KB
//  of image bytes, and an optional movie `frame`. It is embedded because the sandboxed Quick
//  Look and thumbnail extensions cannot read the export beside the record.
//
//  Read defensively: anything off (another media type, absurd dimensions, too many bytes, bytes
//  that are not the declared format, an image ImageIO cannot decode) means no preview, never a
//  throw. The text report never reads `preview`.
//

import Foundation
import CoreGraphics
import ImageIO

public struct HFRecordPreview {
    public let mediaType: String
    public let width: Int
    public let height: Int
    /// The image file's bytes, decoded from base64 and checked against `mediaType`'s signature.
    public let data: Data
    public let frame: Int?

    public static let mediaTypes: Set<String> = ["image/png", "image/jpeg"]
    public static let maxSide = 320
    public static let maxBytes = 64 << 10

    /// The preview a record's `preview` value describes, or nil when it is missing or off spec.
    public init?(_ v: HFJSON?) {
        guard let v, v.isObject,
              let type = v["media_type"]?.stringValue, Self.mediaTypes.contains(type),
              case .int(let ws)? = v["width"], case .int(let hs)? = v["height"],
              let w = Int(ws), let h = Int(hs),
              (1...Self.maxSide).contains(w), (1...Self.maxSide).contains(h),
              let b64 = v["data"]?.stringValue,
              b64.utf8.count <= (Self.maxBytes + 2) / 3 * 4 + 4096,   // slack for line breaks
              let bytes = Data(base64Encoded: b64, options: .ignoreUnknownCharacters),
              !bytes.isEmpty, bytes.count <= Self.maxBytes,
              Self.signatureMatches(bytes, type)
        else { return nil }
        mediaType = type; width = w; height = h; data = bytes
        frame = v["frame"]?.intValue
    }

    static func signatureMatches(_ d: Data, _ type: String) -> Bool {
        let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let jpeg: [UInt8] = [0xFF, 0xD8, 0xFF]
        let sig = type == "image/png" ? png : jpeg
        return d.count > sig.count && Array(d.prefix(sig.count)) == sig
    }

    /// The decoded picture, or nil. ImageIO's header is checked before any pixel is decoded, so a
    /// small file that claims a huge raster is refused unread.
    public var image: CGImage? {
        let uti = mediaType == "image/png" ? "public.png" : "public.jpeg"
        let opts = [kCGImageSourceTypeIdentifierHint: uti, kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, opts),
              let type = CGImageSourceGetType(src) as String?, type == uti,
              CGImageSourceGetCount(src) >= 1,
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let pw = props[kCGImagePropertyPixelWidth] as? Int, let ph = props[kCGImagePropertyPixelHeight] as? Int,
              (1...Self.maxSide).contains(pw), (1...Self.maxSide).contains(ph)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
}

extension HFRecord {

    /// The record's embedded preview, when it carries one that passes the checks.
    public var preview: HFRecordPreview? { HFRecordPreview(root["preview"]) }

    /// Files beside the record larger than this are not opened for a preview.
    public static let maxSiblingBytes = 256 << 20

    /// The picture to show for this record: the embedded preview, else the export output.file_name
    /// names beside `sidecar` when it is a PNG or JPEG that can be read (a sandboxed extension
    /// usually cannot, which is fine), scaled to at most `maxSide` pixels. Nil, never a throw.
    public func previewImage(sidecar: URL?, maxSide: Int = HFRecordPreview.maxSide) -> CGImage? {
        if let img = preview?.image { return img }
        guard let sidecar, let name = outputFileName,
              ["png", "jpg", "jpeg"].contains((name as NSString).pathExtension.lowercased())
        else { return nil }
        let url = sidecar.deletingLastPathComponent().appendingPathComponent(name)
        guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
              size > 0, size <= Self.maxSiblingBytes,
              let src = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(src) as String?, ["public.png", "public.jpeg"].contains(type)
        else { return nil }
        let opts = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: max(1, maxSide)] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts)
    }
}
