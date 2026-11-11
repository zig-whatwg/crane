//! `fw_matrix fetch`: every file a framework's run needs, downloaded and
//! checked against the manifest's sha256 (and the project's lockfile
//! integrity where the manifest gives it) into the frameworks directory on
//! the run host (~/crane-frameworks/), never into the Crane tree (ruling
//! R8). A mismatch is an error and the file is deleted, never a warning.
//!
//!   <dir>/downloads/<sha256>          each archive, kept to skip a refetch
//!   <dir>/<name>-<version>/           the tree the server serves: the tag's
//!                                     tarball (its top directory stripped,
//!                                     the manifest's `skip` paths left out),
//!                                     the dependencies' mapped files, and the
//!                                     generated files (ruling R3)
//!   <dir>/<name>-<version>/.fw_matrix-fetched   the manifest entry's hash:
//!                                     an unchanged entry is not re-extracted
//!
//! Downloads go through curl, as tools/cldr/download.zig's do (a host tool
//! spawning a process, like perf_bench). Archives are gzip'd tar, read with
//! std.compress.flate and std.tar.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const manifest = @import("manifest.zig");
const generated = @import("generated.zig");

pub const max_archive = 1024 * 1024 * 1024;

pub fn sha256Hex(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

/// npm's integrity form: "sha512-" and the base64 of the SHA-512 digest.
pub fn sha512Integrity(bytes: []const u8, buf: *[7 + 88]u8) []const u8 {
    var digest: [64]u8 = undefined;
    std.crypto.hash.sha2.Sha512.hash(bytes, &digest, .{});
    @memcpy(buf[0..7], "sha512-");
    _ = std.base64.standard.Encoder.encode(buf[7..], &digest);
    return buf[0 .. 7 + std.base64.standard.Encoder.calcSize(64)];
}

pub const VerifyError = error{ ChecksumMismatch, IntegrityMismatch };

pub fn verify(bytes: []const u8, sha256: []const u8, integrity: ?[]const u8) VerifyError!void {
    const got = sha256Hex(bytes);
    if (!std.mem.eql(u8, &got, sha256)) return error.ChecksumMismatch;
    if (integrity) |want| {
        var buf: [7 + 88]u8 = undefined;
        if (!std.mem.eql(u8, sha512Integrity(bytes, &buf), want)) return error.IntegrityMismatch;
    }
}

/// gunzip into memory (the largest archive, htmx's tag tarball, is ~0.2 GB
/// compressed).
pub fn gunzip(gpa: Allocator, data: []const u8) ![]u8 {
    var in: Io.Reader = .fixed(data);
    var out: Io.Writer.Allocating = .init(gpa);
    errdefer out.deinit();
    var d: std.compress.flate.Decompress = .init(&in, .gzip, &.{});
    _ = try d.reader.streamRemaining(&out.writer);
    return out.toOwnedSlice();
}

pub const Extracted = struct {
    files: usize = 0,
    skipped: usize = 0,
    links: usize = 0,
};

/// The path with its first component removed ("jquery-4.0.0/test/x" ->
/// "test/x"), or null for the top directory itself.
pub fn stripTop(name: []const u8) ?[]const u8 {
    const slash = std.mem.indexOfScalar(u8, name, '/') orelse return null;
    const rest = name[slash + 1 ..];
    return if (rest.len == 0) null else rest;
}

fn underAny(path: []const u8, prefixes: []const []const u8) bool {
    for (prefixes) |p| {
        if (std.mem.eql(u8, path, p)) return true;
        if (std.mem.startsWith(u8, path, p) and (p[p.len - 1] == '/' or (path.len > p.len and path[p.len] == '/'))) return true;
    }
    return false;
}

fn writeFileAt(io: Io, dir: Io.Dir, path: []const u8, bytes: []const u8) !void {
    if (std.fs.path.dirname(path)) |d| try dir.createDirPath(io, d);
    try dir.writeFile(io, .{ .sub_path = path, .data = bytes });
}

/// A source tarball into `dir`: the top directory stripped, `skip` paths
/// left out, symbolic links not made (counted).
pub fn extractTree(gpa: Allocator, io: Io, tgz: []const u8, dir: Io.Dir, skip: []const []const u8) !Extracted {
    const tar_bytes = try gunzip(gpa, tgz);
    defer gpa.free(tar_bytes);
    var in: Io.Reader = .fixed(tar_bytes);
    var name_buf: [Io.Dir.max_path_bytes]u8 = undefined;
    var link_buf: [Io.Dir.max_path_bytes]u8 = undefined;
    var it: std.tar.Iterator = .init(&in, .{ .file_name_buffer = &name_buf, .link_name_buffer = &link_buf });
    var stats: Extracted = .{};
    var content: Io.Writer.Allocating = .init(gpa);
    defer content.deinit();
    while (try it.next()) |file| {
        const rel = stripTop(file.name) orelse continue;
        if (!manifest.isRelativePath(std.mem.trimEnd(u8, rel, "/"))) return error.BadArchivePath;
        if (underAny(rel, skip)) {
            if (file.kind == .file) stats.skipped += 1;
            continue;
        }
        switch (file.kind) {
            .directory => try dir.createDirPath(io, std.mem.trimEnd(u8, rel, "/")),
            .sym_link => stats.links += 1,
            .file => {
                content.clearRetainingCapacity();
                try it.streamRemaining(file, &content.writer);
                try writeFileAt(io, dir, rel, content.written());
                stats.files += 1;
            },
        }
    }
    return stats;
}

/// The named files of a dependency's archive into `dir` at their mapped
/// paths; every one must be found.
pub fn extractFiles(gpa: Allocator, io: Io, tgz: []const u8, dir: Io.Dir, files: []const manifest.FileMap) !void {
    const tar_bytes = try gunzip(gpa, tgz);
    defer gpa.free(tar_bytes);
    var in: Io.Reader = .fixed(tar_bytes);
    var name_buf: [Io.Dir.max_path_bytes]u8 = undefined;
    var link_buf: [Io.Dir.max_path_bytes]u8 = undefined;
    var it: std.tar.Iterator = .init(&in, .{ .file_name_buffer = &name_buf, .link_name_buffer = &link_buf });
    const found = try gpa.alloc(bool, files.len);
    defer gpa.free(found);
    @memset(found, false);
    var content: Io.Writer.Allocating = .init(gpa);
    defer content.deinit();
    while (try it.next()) |file| {
        if (file.kind != .file) continue;
        for (files, 0..) |fm, i| {
            if (found[i] or !std.mem.eql(u8, fm.from, file.name)) continue;
            content.clearRetainingCapacity();
            try it.streamRemaining(file, &content.writer);
            try writeFileAt(io, dir, fm.to, content.written());
            found[i] = true;
            break;
        }
    }
    for (found) |f| if (!f) return error.FileNotInArchive;
}

/// `url` to `dest` with curl (redirects followed, failure on an HTTP error).
pub fn download(gpa: Allocator, io: Io, url: []const u8, dest: []const u8) !void {
    const result = try std.process.run(gpa, io, .{
        .argv = &.{ "curl", "-fsSL", "--retry", "3", "--retry-delay", "2", "-o", dest, url },
    });
    defer gpa.free(result.stdout);
    defer gpa.free(result.stderr);
    switch (result.term) {
        .exited => |code| if (code == 0) return,
        else => {},
    }
    std.debug.print("fw_matrix: curl {s}: {s}\n", .{ url, result.stderr });
    return error.DownloadFailed;
}

/// The bytes of `url`, from the downloads cache when a file of its sha256 is
/// there, else downloaded; checked either way. Caller frees.
pub fn obtain(gpa: Allocator, io: Io, downloads: []const u8, url: []const u8, sha256: []const u8, integrity: ?[]const u8) ![]u8 {
    const path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ downloads, sha256 });
    defer gpa.free(path);
    const cached = Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(max_archive)) catch null;
    if (cached) |bytes| {
        if (verify(bytes, sha256, integrity)) return bytes else |_| gpa.free(bytes);
    }
    const partial = try std.fmt.allocPrint(gpa, "{s}.part", .{path});
    defer gpa.free(partial);
    try download(gpa, io, url, partial);
    const bytes = try Io.Dir.cwd().readFileAlloc(io, partial, gpa, .limited(max_archive));
    errdefer gpa.free(bytes);
    verify(bytes, sha256, integrity) catch |err| {
        Io.Dir.cwd().deleteFile(io, partial) catch {};
        std.debug.print("fw_matrix: {s}: {t} (the manifest pins sha256 {s}; got {s})\n", .{ url, err, sha256, &sha256Hex(bytes) });
        return err;
    };
    try Io.Dir.cwd().rename(partial, Io.Dir.cwd(), path, io);
    return bytes;
}

/// The hash of a manifest entry: its fields as JSON, sha256'd.
pub fn entryHash(gpa: Allocator, f: manifest.Suite) ![64]u8 {
    var out: Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    try std.json.Stringify.value(f, .{}, &out.writer);
    return sha256Hex(out.written());
}

pub const stamp_name = ".fw_matrix-fetched";

/// Everything one suite's run needs, under `frameworks_dir`.
pub fn fetchSuite(gpa: Allocator, io: Io, frameworks_dir: []const u8, f: manifest.Suite) !void {
    const downloads = try std.fmt.allocPrint(gpa, "{s}/downloads", .{frameworks_dir});
    defer gpa.free(downloads);
    try Io.Dir.cwd().createDirPath(io, downloads);
    const tree = try std.fmt.allocPrint(gpa, "{s}/{s}-{s}", .{ frameworks_dir, f.id, f.version });
    defer gpa.free(tree);
    const stamp_path = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ tree, stamp_name });
    defer gpa.free(stamp_path);
    const want = try entryHash(gpa, f);

    // The live loads are checked every time (ruling R6): what the page will
    // load is what the manifest pins, today.
    for (f.remote) |r| {
        const bytes = try obtain(gpa, io, downloads, r.url, r.sha256, null);
        gpa.free(bytes);
        std.debug.print("fw_matrix: {s}: {s} ok ({s})\n", .{ f.id, r.url, r.sha256[0..12] });
    }

    if (Io.Dir.cwd().readFileAlloc(io, stamp_path, gpa, .limited(256))) |have| {
        defer gpa.free(have);
        if (std.mem.eql(u8, std.mem.trim(u8, have, " \n"), &want)) {
            std.debug.print("fw_matrix: {s}: {s} is current\n", .{ f.id, tree });
            return;
        }
    } else |_| {}

    Io.Dir.cwd().deleteTree(io, tree) catch {};
    try Io.Dir.cwd().createDirPath(io, tree);
    var dir = try Io.Dir.cwd().openDir(io, tree, .{});
    defer dir.close(io);

    const source = try obtain(gpa, io, downloads, f.source.url, f.source.sha256, null);
    defer gpa.free(source);
    const stats = try extractTree(gpa, io, source, dir, f.source.skip);
    std.debug.print("fw_matrix: {s}: {s} -> {d} files ({d} skipped, {d} links not made)\n", .{ f.id, f.source.url, stats.files, stats.skipped, stats.links });

    for (f.dependencies) |d| {
        const bytes = try obtain(gpa, io, downloads, d.url, d.sha256, d.integrity);
        defer gpa.free(bytes);
        try extractFiles(gpa, io, bytes, dir, d.files);
        std.debug.print("fw_matrix: {s}: {s}@{s} -> {d} files\n", .{ f.id, d.name, d.version, d.files.len });
    }

    for (f.generated) |g| {
        const src = try dir.readFileAlloc(io, g.from, gpa, .limited(max_archive));
        defer gpa.free(src);
        const bytes = try generated.generate(gpa, g.kind, src);
        defer gpa.free(bytes);
        try writeFileAt(io, dir, g.to, bytes);
        std.debug.print("fw_matrix: {s}: generated {s} from {s} ({t}, sha256 {s})\n", .{ f.id, g.to, g.from, g.kind, &sha256Hex(bytes) });
    }

    try dir.writeFile(io, .{ .sub_path = stamp_name, .data = &want });
}

const testing = std.testing;

/// One ustar header block (POSIX.1-1988: name, mode, uid, gid, size, mtime,
/// checksum, typeflag, magic), written by hand so the tests do not read
/// archives through the code that wrote them.
fn ustarHeader(out: *Io.Writer, name: []const u8, size: usize, typeflag: u8) !void {
    var h: [512]u8 = @splat(0);
    @memcpy(h[0..name.len], name);
    _ = try std.fmt.bufPrint(h[100..108], "{o:0>7}", .{@as(u32, 0o644)});
    _ = try std.fmt.bufPrint(h[108..116], "{o:0>7}", .{@as(u32, 0)});
    _ = try std.fmt.bufPrint(h[116..124], "{o:0>7}", .{@as(u32, 0)});
    _ = try std.fmt.bufPrint(h[124..136], "{o:0>11}", .{size});
    _ = try std.fmt.bufPrint(h[136..148], "{o:0>11}", .{@as(u32, 0)});
    h[156] = typeflag;
    @memcpy(h[257..263], "ustar\x00");
    @memcpy(h[263..265], "00");
    @memset(h[148..156], ' ');
    var sum: u32 = 0;
    for (h) |b| sum += b;
    _ = try std.fmt.bufPrint(h[148..155], "{o:0>6}", .{sum});
    h[154] = 0;
    try out.writeAll(&h);
}

const TarEntry = struct { path: []const u8, content: []const u8 = "" };

/// A gzip'd tar of `entries` (a path ending in '/' a directory).
fn tarGz(gpa: Allocator, entries: []const TarEntry) ![]u8 {
    var tar_out: Io.Writer.Allocating = .init(gpa);
    defer tar_out.deinit();
    const w = &tar_out.writer;
    for (entries) |e| {
        const dir = std.mem.endsWith(u8, e.path, "/");
        try ustarHeader(w, e.path, if (dir) 0 else e.content.len, if (dir) '5' else '0');
        if (!dir) {
            try w.writeAll(e.content);
            const pad = (512 - e.content.len % 512) % 512;
            try w.splatByteAll(0, pad);
        }
    }
    try w.splatByteAll(0, 1024);
    // gzip (RFC 1952) of DEFLATE stored blocks (RFC 1951 BTYPE 00), written
    // by hand: the tests read archives through no code that wrote them.
    const data = tar_out.written();
    var out: Io.Writer.Allocating = .init(gpa);
    errdefer out.deinit();
    try out.writer.writeAll(&.{ 0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 0xff });
    var at: usize = 0;
    while (true) {
        const n = @min(data.len - at, 65535);
        const last = at + n == data.len;
        try out.writer.writeByte(if (last) 1 else 0);
        try out.writer.writeInt(u16, @intCast(n), .little);
        try out.writer.writeInt(u16, ~@as(u16, @intCast(n)), .little);
        try out.writer.writeAll(data[at..][0..n]);
        at += n;
        if (last) break;
    }
    try out.writer.writeInt(u32, std.hash.Crc32.hash(data), .little);
    try out.writer.writeInt(u32, @truncate(data.len), .little);
    return out.toOwnedSlice();
}

test "checksums: sha256 hex and npm's sha512 integrity; a mismatch is refused" {
    const h = sha256Hex("abc");
    try testing.expectEqualStrings("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", &h);
    var buf: [7 + 88]u8 = undefined;
    try testing.expectEqualStrings("sha512-3a81oZNherrMQXNJriBBMRLm+k6JqX6iCp7u5ktV05ohkpkqJ0/BqDa6PCOj/uu9RU1EI2Q86A4qmslPpUyknw==", sha512Integrity("abc", &buf));
    try verify("abc", &h, "sha512-3a81oZNherrMQXNJriBBMRLm+k6JqX6iCp7u5ktV05ohkpkqJ0/BqDa6PCOj/uu9RU1EI2Q86A4qmslPpUyknw==");
    try testing.expectError(error.ChecksumMismatch, verify("abd", &h, null));
    try testing.expectError(error.IntegrityMismatch, verify("abc", &h, "sha512-AAAA"));
}

test "extractTree: the top directory stripped, skip paths left out" {
    const tgz = try tarGz(testing.allocator, &[_]TarEntry{
        .{ .path = "htmx-4.0.1/", .content = "" },
        .{ .path = "htmx-4.0.1/src/htmx.js", .content = "var htmx;" },
        .{ .path = "htmx-4.0.1/test/test.html", .content = "<!doctype html>" },
        .{ .path = "htmx-4.0.1/www/index.html", .content = "site" },
        .{ .path = "htmx-4.0.1/www/big/x.bin", .content = "x" },
        .{ .path = "htmx-4.0.1/wwwx.txt", .content = "kept" },
    });
    defer testing.allocator.free(tgz);
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const stats = try extractTree(testing.allocator, testing.io, tgz, tmp.dir, &.{"www"});
    try testing.expectEqual(@as(usize, 3), stats.files);
    try testing.expectEqual(@as(usize, 2), stats.skipped);
    const js = try tmp.dir.readFileAlloc(testing.io, "src/htmx.js", testing.allocator, .limited(100));
    defer testing.allocator.free(js);
    try testing.expectEqualStrings("var htmx;", js);
    try testing.expectError(error.FileNotFound, tmp.dir.readFileAlloc(testing.io, "www/index.html", testing.allocator, .limited(100)));
    const kept = try tmp.dir.readFileAlloc(testing.io, "wwwx.txt", testing.allocator, .limited(100));
    defer testing.allocator.free(kept);
}

test "extractFiles: the mapped files only; a missing one fails" {
    const tgz = try tarGz(testing.allocator, &[_]TarEntry{
        .{ .path = "package/qunit/qunit.js", .content = "QUnit" },
        .{ .path = "package/qunit/qunit.css", .content = "css" },
        .{ .path = "package/LICENSE.txt", .content = "MIT" },
    });
    defer testing.allocator.free(tgz);
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try extractFiles(testing.allocator, testing.io, tgz, tmp.dir, &.{
        .{ .from = "package/qunit/qunit.js", .to = "external/qunit/qunit.js" },
        .{ .from = "package/LICENSE.txt", .to = "external/qunit/LICENSE.txt" },
    });
    const js = try tmp.dir.readFileAlloc(testing.io, "external/qunit/qunit.js", testing.allocator, .limited(100));
    defer testing.allocator.free(js);
    try testing.expectEqualStrings("QUnit", js);
    try testing.expectError(error.FileNotFound, tmp.dir.readFileAlloc(testing.io, "external/qunit/qunit.css", testing.allocator, .limited(100)));
    try testing.expectError(error.FileNotInArchive, extractFiles(testing.allocator, testing.io, tgz, tmp.dir, &.{.{ .from = "package/nope.js", .to = "x.js" }}));
}

test "stripTop and skip prefixes" {
    try testing.expectEqualStrings("test/x", stripTop("jquery-4.0.0/test/x").?);
    try testing.expectEqual(@as(?[]const u8, null), stripTop("jquery-4.0.0/"));
    try testing.expect(underAny("www/a", &.{"www"}));
    try testing.expect(underAny("www", &.{"www"}));
    try testing.expect(!underAny("wwwx", &.{"www"}));
}
