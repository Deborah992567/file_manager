import Foundation
import zlib

/// Errors raised while reading/writing ZIP archives.
enum ZipError: LocalizedError {
    case invalidArchive
    case truncated
    case corruptedEntry(String)
    case unsupportedMethod

    var errorDescription: String? {
        switch self {
        case .invalidArchive:    return "This doesn't look like a valid ZIP archive."
        case .truncated:         return "The archive appears to be cut off."
        case .corruptedEntry(let n): return "An entry (“\(n)”) is corrupted and couldn't be read."
        case .unsupportedMethod: return "This archive uses an unsupported compression method."
        }
    }
}

/// One logical member of an archive (file or empty folder).
struct ZipEntry {
    let name: String      // forward-slash separated, sanitized
    let data: Data
    let isDirectory: Bool
}

/// Minimal, dependency-free ZIP writer/reader over the system zlib.
///
/// Design notes:
///  - Entries are deflated with raw `deflate` (windowBits = -MAX_WBITS) so the
///    stream matches the ZIP spec exactly, then CRC-32 is stamped per member.
///  - Extraction accepts STORE (0) and DEFLATE (8) methods — the two any real
///    archiver produces. Paths are sanitized to defeat "zip-slip".
///  - 32-bit sizes/offsets keep the code tiny; plenty for a phone-scale archive.
enum ZipService {

    // MARK: - Entry model fixes

    static func zipData(from entries: [ZipEntry]) -> Data {
        var local = Data()
        var central = Data()
        var offset: UInt32 = 0

        for entry in entries {
            let rawName = entry.isDirectory ? entry.name + "/" : entry.name
            let nameData = Data(rawName.utf8)
            let payload = entry.isDirectory ? Data() : entry.data
            let compressed = rawDeflate(payload) ?? payload
            let crc = crc32(of: payload)
            let csize = UInt32(compressed.count)
            let usize = UInt32(payload.count)
            let nlen = UInt16(nameData.count)

            var hdr = Data()
            hdr.put32( 0x04034B50)          // local file header sig
            hdr.put16( 20)                  // version needed to extract
            hdr.put16( 0x0800)              // UTF-8 filename
            hdr.put16( 8)                   // deflate
            hdr.put16( 0)                   // mod time (fixed stamp)
            hdr.put16( 0x5821)              // mod date 2024-01-01
            hdr.put32( crc)
            hdr.put32( csize)
            hdr.put32( usize)
            hdr.put16( nlen)
            hdr.put16( 0)                   // extra length
            hdr.append(nameData)
            hdr.append(compressed)
            local.append(hdr)

            var cen = Data()
            cen.put32( 0x02014B50)          // central dir sig
            cen.put16( 0x031E)              // version made by (unix, 3.0)
            cen.put16( 20)                  // version needed
            cen.put16( 0x0800)
            cen.put16( 8)
            cen.put16( 0)
            cen.put16( 0x5821)
            cen.put32( crc)
            cen.put32( csize)
            cen.put32( usize)
            cen.put16( nlen)
            cen.put16( 0)
            cen.put16( 0)
            cen.put16( 0)
            cen.put16( 0)
            cen.put32( entry.isDirectory ? 0x10 : 0)  // MS-DOS dir attribute
            cen.put32( offset)
            cen.append(nameData)
            central.append(cen)

            offset += UInt32(hdr.count)
        }

        var zip = local
        let cdOffset = UInt32(local.count)
        zip.append(central)

        var eocd = Data()
        eocd.put32( 0x06054B50)
        eocd.put16( 0)
        eocd.put16( 0)
        eocd.put16( UInt16(entries.count))
        eocd.put16( UInt16(entries.count))
        eocd.put32( UInt32(central.count))
        eocd.put32( cdOffset)
        eocd.put16( 0)
        zip.append(eocd)
        return zip
    }

    // MARK: - Compression helpers

    private static func rawDeflate(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        var stream = z_stream()
        guard deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { deflateEnd(&stream) }

        let input = UnsafeMutablePointer<Bytef>.allocate(capacity: data.count)
        defer { input.deallocate() }
        data.copyBytes(to: input, count: data.count)

        let chunk = 65_536
        let output = UnsafeMutablePointer<Bytef>.allocate(capacity: chunk)
        defer { output.deallocate() }

        var result = Data()
        stream.next_in = input
        stream.avail_in = uInt(data.count)

        var done = false
        while !done {
            stream.next_out = output
            stream.avail_out = uInt(chunk)
            let status = deflate(&stream, Z_FINISH)
            guard status != Z_STREAM_ERROR else { return nil }
            let produced = chunk - Int(stream.avail_out)
            if produced > 0 { result.append(output, count: produced) }
            done = (status == Z_STREAM_END)
            if status == Z_BUF_ERROR || (done && produced == 0) { break }
        }
        return result
    }

    private static func rawInflate(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }
        var stream = z_stream()
        guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { inflateEnd(&stream) }

        let input = UnsafeMutablePointer<Bytef>.allocate(capacity: data.count)
        defer { input.deallocate() }
        data.copyBytes(to: input, count: data.count)

        var capacity = 65_536
        var output = UnsafeMutablePointer<Bytef>.allocate(capacity: capacity)
        var producedTotal = 0

        stream.next_in = input
        stream.avail_in = uInt(data.count)

        while true {
            stream.next_out = output.advanced(by: producedTotal)
            stream.avail_out = uInt(capacity - producedTotal)
            let status = inflate(&stream, Z_NO_FLUSH)
            let produced = (capacity - producedTotal) - Int(stream.avail_out)
            producedTotal += produced
            if status == Z_STREAM_END { break }
            if status == Z_STREAM_ERROR || status == Z_DATA_ERROR { output.deallocate(); return nil }
            if stream.avail_out == 0 {
                let newCapacity = capacity * 2
                let newOutput = UnsafeMutablePointer<Bytef>.allocate(capacity: newCapacity)
                newOutput.update(from: output, count: producedTotal)
                output.deallocate()
                output = newOutput
                capacity = newCapacity
            } else if status == Z_BUF_ERROR {
                break
            }
        }

        let result = Data(bytes: output, count: producedTotal)
        output.deallocate()
        return result
    }

    private static func crc32(of data: Data) -> UInt32 {
        guard !data.isEmpty else { return 0 }
        return data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> UInt32 in
            let bound = raw.bindMemory(to: Bytef.self)
            return UInt32(truncating: zlib.crc32(0, bound.baseAddress, uInt(data.count)) as NSNumber)
        }
    }

    // MARK: - Extraction

    static func entries(from data: Data) throws -> [ZipEntry] {
        guard data.count > 22 else { throw ZipError.invalidArchive }
        let eocd = data.range(of: [0x50, 0x4B, 0x05, 0x06], options: .backwards)
        guard let eocd, eocd.count == 4 else { throw ZipError.invalidArchive }
        let cdOffset = Int(data.u32(eocd.lowerBound + 16))
        let entryCount = Int(data.u16(eocd.lowerBound + 10))
        guard cdOffset + 20 <= data.count, data.u32(cdOffset) == 0x02014B50 else { throw ZipError.invalidArchive }

        var cursor = cdOffset
        var entries: [ZipEntry] = []
        for _ in 0..<entryCount {
            guard cursor + 46 <= data.count else { throw ZipError.truncated }
            let method = Int(data.u16(cursor + 10))
            let csize = Int(data.u32(cursor + 20))
            let usizeRaw = Int(data.u32(cursor + 24))
            let nlen = Int(data.u16(cursor + 28))
            let elen = Int(data.u16(cursor + 30))
            let clen = Int(data.u16(cursor + 32))
            let externalAttrs = data.u32(cursor + 38)
            let localOffset = Int(data.u32(cursor + 42))

            let nameStart = cursor + 46
            let name = String(decoding: data.subdata(in: nameStart..<(nameStart + nlen)), as: UTF8.self)
            let isDir = (externalAttrs & 0x10) != 0 || name.hasSuffix("/")

            guard localOffset + 30 <= data.count else { throw ZipError.truncated }
            let localNameLen = Int(data.u16(localOffset + 26))
            let localExtra = Int(data.u16(localOffset + 28))
            let dataStart = localOffset + 30 + localNameLen + localExtra
            guard dataStart + csize <= data.count else { throw ZipError.truncated }

            let payload = data.subdata(in: dataStart..<(dataStart + csize))
            let decompressed: Data
            switch method {
            case 0: decompressed = payload
            case 8:
                guard let inflated = rawInflate(payload) else { throw ZipError.corruptedEntry(name) }
                decompressed = inflated
            default: throw ZipError.unsupportedMethod
            }
            _ = usizeRaw  // informational only

            entries.append(ZipEntry(name: sanitize(name), data: decompressed, isDirectory: isDir))
            cursor += 46 + nlen + elen + clen
        }
        return entries
    }

    /// Strips "." / ".." path components so a hostile archive can't write
    /// files outside the destination directory (zip-slip).
    private static func sanitize(_ name: String) -> String {
        let parts = name.split(separator: "/", omittingEmptySubsequences: true)
            .filter { $0 != "." && $0 != ".." }
        return parts.joined(separator: "/")
    }

    // MARK: - File-level conveniences

    /// Creates a zip of a folder (folder itself + recursive contents).
    static func compress(folderAt url: URL, to archiveURL: URL) throws {
        var entries: [ZipEntry] = []
        collect(url, base: url.deletingLastPathComponent(), into: &entries)
        let data = zipData(from: entries)
        try data.write(to: archiveURL)
    }

    /// Creates a zip from a flat list of items (their names are relative to
    /// the common root, e.g. "Folder A" or "readme.txt").
    static func compress(items: [URL], to archiveURL: URL) throws {
        let commonBase = items.first?.deletingLastPathComponent() ?? archiveURL.deletingLastPathComponent()
        var entries: [ZipEntry] = []
        for url in items {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                collect(url, base: commonBase, into: &entries)
            } else {
                entries.append(ZipEntry(name: url.lastPathComponent, data: (try? Data(contentsOf: url)) ?? Data(), isDirectory: false))
            }
        }
        let data = zipData(from: entries)
        try data.write(to: archiveURL)
    }

    static func extract(zip url: URL, into destination: URL) throws {
        let data = try Data(contentsOf: url)
        let entries = try entries(from: data)
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for entry in entries {
            guard !entry.name.isEmpty else { continue }
            let target = destination.appendingPathComponent(entry.name)
            if entry.isDirectory {
                try fm.createDirectory(at: target, withIntermediateDirectories: true)
            } else {
                let parent = target.deletingLastPathComponent()
                try fm.createDirectory(at: parent, withIntermediateDirectories: true)
                try entry.data.write(to: target)
            }
        }
    }

    private static func collect(_ url: URL, base: URL, into entries: inout [ZipEntry]) {
        let fm = FileManager.default
        let rel = relativeName(of: url, base: base)
        entries.append(ZipEntry(name: rel, data: Data(), isDirectory: true))
        guard let children = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return }
        for child in children {
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                collect(child, base: base, into: &entries)
            } else if let data = try? Data(contentsOf: child) {
                entries.append(ZipEntry(name: relativeName(of: child, base: base), data: data, isDirectory: false))
            }
        }
    }

    /// "Folder/Sub/Folder" style relative name using "/" separators.
    private static func relativeName(of url: URL, base: URL) -> String {
        let basePath = base.standardizedFileURL.path
        var path = url.standardizedFileURL.path
        if path.hasPrefix(basePath) { path.removeFirst(basePath.count) }
        while path.hasPrefix("/") { path.removeFirst() }
        return path
    }
}

// MARK: - Little-endian binary helpers

private extension Data {
    mutating func put16(_ value: UInt16) {
        append(UInt8(value & 0xFF)); append(UInt8((value >> 8) & 0xFF))
    }
    mutating func put32(_ value: UInt32) {
        for shift in stride(from: 0, through: 24, by: 8) {
            append(UInt8((value >> shift) & 0xFF))
        }
    }
    func u16(_ offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }
    func u32(_ offset: Int) -> UInt32 {
        UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }
    func range(of bytePattern: [UInt8], options: String.CompareOptions = [], in r: Range<Int>? = nil) -> Range<Int>? {
        let search = bytePattern
        guard search.count <= self.count else { return nil }
        let startIndex = r?.lowerBound ?? 0
        let endIndex = r?.upperBound ?? (self.count - search.count)
        var i = options == .backwards ? endIndex : startIndex
        while options == .backwards ? i >= startIndex : i <= endIndex {
            var match = true
            for (j, byte) in search.enumerated() where self[i + j] != byte {
                match = false; break
            }
            if match { return i..<(i + search.count) }
            i += options == .backwards ? -1 : 1
        }
        return nil
    }
}