import Foundation

// Standalone service verification (run via scripts/verify_services.sh).
// Compiles ZipService.swift + this harness on the host and exercises archive
// writing/reading, size accounting and zip-slip defense — no device needed.

@main
struct VerifyServices {

    static func main() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nova-verify-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // 1. Large repetitive text (highly compressible).
        let bigText = String(repeating: "Nova Files round-trip verification. ", count: 5000)
        let txtURL = dir.appendingPathComponent("big.txt")
        try bigText.data(using: .utf8)!.write(to: txtURL)

        // 2. Binary garbage (incompressible) — must survive deflate untouched.
        let binary = (0..<65_536).map { _ in UInt8.random(in: 0...255) }
        let binURL = dir.appendingPathComponent("random.bin")
        try Data(binary).write(to: binURL)

        // 3. Nested folder with its own file — path depth must round-trip.
        let nested = dir.appendingPathComponent("Nested/Sub")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let noteText = "hello nested"
        try noteText.data(using: .utf8)!.write(to: nested.appendingPathComponent("note.txt"))

        let archiveURL = dir.appendingPathComponent("out.zip")
        try ZipService.compress(items: [txtURL, binURL, dir.appendingPathComponent("Nested")], to: archiveURL)
        let archive = try Data(contentsOf: archiveURL)

        Check.ok(archive.count > 100, "archive written (\(archive.count) bytes)")
        Check.ok(archive.count < bigText.count, "text was actually compressed")

        let entries = try ZipService.entries(from: archive)
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0.data) })

        Check.ok(byName["big.txt"] == bigText.data(using: .utf8)!, "big.txt round-trip")
        Check.ok(byName["random.bin"] == Data(binary), "random.bin round-trip")
        Check.ok(byName["Nested/Sub/note.txt"] == noteText.data(using: .utf8)!, "nested note round-trip")

        // 4. Zip-slip: hostile "../" paths must be stripped, never written up-tree.
        let hostile = ZipService.zipData(from: [
            ZipEntry(name: "safe.txt", data: Data("ok".utf8), isDirectory: false),
            ZipEntry(name: "../evil.txt", data: Data("evil".utf8), isDirectory: false)
        ])
        let hostileEntries = try ZipService.entries(from: hostile)
        let hostileNames = hostileEntries.map(\.name)
        Check.ok(hostileNames.count == 2, "two entries present after de-escaping")
        Check.ok(!hostileNames.contains("../evil.txt"), "raw traversal path rejected")
        Check.ok(hostileNames.contains("evil.txt"), "zip-slip path sanitized")

        try? FileManager.default.removeItem(at: dir)
        print("All \(Check.count) checks passed.")
    }
}

enum Check {
    static var count = 0
    static func ok(_ condition: Bool, _ name: String) {
        count += 1
        if condition {
            print("PASS  \(name)")
        } else {
            print("FAIL  \(name)")
            exit(1)
        }
    }
}