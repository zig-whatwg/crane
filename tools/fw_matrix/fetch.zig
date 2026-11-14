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
//! A suite with `node` and `npm` (jQuery: its own test server runs under
//! Node) also gets the pinned Node and the project's own dependencies, `npm
//! ci` from its own lockfile, and the project's own npm scripts: the layout is
//! in the section "Node" below.
//!
//! Downloads go through curl, as tools/cldr/download.zig's do (a host tool
//! spawning a process, like perf_bench). Archives are gzip'd tar, read with
//! std.compress.flate and std.tar.

const std = @import("std");
const builtin = @import("builtin");
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

/// The hash of what makes a suite's tree - its directory's name, the
/// source, the dependencies, the generated files, Node, npm, Bazel and the
/// targets it builds - as JSON, sha256'd: a change to how pages run (a
/// budget, a reader) leaves the tree current, and every suite on a shared
/// tree finds the same stamp.
pub fn entryHash(gpa: Allocator, f: manifest.Suite) ![64]u8 {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var targets: std.ArrayList([]const u8) = .empty;
    if (f.bazel != null) for (f.pages) |p| if (p.target) |t| try targets.append(arena, t);
    var out: Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    // Absent when null, so that a tree made before Bazel was known keeps its
    // stamp.
    const Fields = struct { tree: []const u8, source: manifest.Archive, dependencies: []const manifest.Dependency, generated: []const manifest.Generated, node: ?manifest.Node, npm: ?manifest.Npm, bazel: ?manifest.Bazel, targets: ?[]const []const u8 };
    const fields: Fields = .{ .tree = try manifest.treeName(arena, f), .source = f.source, .dependencies = f.dependencies, .generated = f.generated, .node = f.node, .npm = f.npm, .bazel = f.bazel, .targets = if (targets.items.len > 0) targets.items else null };
    try std.json.Stringify.value(fields, .{ .emit_null_optional_fields = false }, &out.writer);
    return sha256Hex(out.written());
}

/// A TodoMVC app's directory, examples/<id>/, is the one its manifest entry
/// pins (dirHash). Its build is what the row measures.
pub fn checkApp(gpa: Allocator, io: Io, tree: Io.Dir, app: manifest.App) !void {
    const want = app.sha256 orelse return error.AppWithoutPin;
    const path = try std.fmt.allocPrint(gpa, "examples/{s}", .{app.id});
    defer gpa.free(path);
    var dir = tree.openDir(io, path, .{}) catch |err| {
        std.debug.print("fw_matrix: {s}: {t}\n", .{ path, err });
        return error.AppMissing;
    };
    defer dir.close(io);
    const got = try dirHash(gpa, io, dir);
    if (!std.mem.eql(u8, &got, want)) {
        std.debug.print("fw_matrix: {s}/ is sha256 {s}; the manifest pins {s}\n", .{ path, &got, want });
        return error.AppMismatch;
    }
}

pub const stamp_name = ".fw_matrix-fetched";

/// Everything one suite's run needs, under `frameworks_dir`; `environ` is
/// the environment Node's tools start from (the tool's own).
pub fn fetchSuite(gpa: Allocator, io: Io, frameworks_dir: []const u8, f: manifest.Suite, environ: ?*const std.process.Environ.Map) !void {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const downloads = try std.fmt.allocPrint(gpa, "{s}/downloads", .{frameworks_dir});
    defer gpa.free(downloads);
    try Io.Dir.cwd().createDirPath(io, downloads);
    // Node is its own directory with its own stamp: made whenever it is
    // missing, even when the tree is current.
    const node_dir: ?[]const u8 = if (f.node) |n| try fetchNode(gpa, arena, io, frameworks_dir, n) else null;
    const tree = try std.fmt.allocPrint(gpa, "{s}/{s}", .{ frameworks_dir, try manifest.treeName(arena, f) });
    defer gpa.free(tree);
    try fetchTree(gpa, arena, io, f, tree, downloads, node_dir, environ);
    // An app's build is checked whether its tree was made now or before.
    if (f.app) |app| {
        var dir = try Io.Dir.cwd().openDir(io, tree, .{});
        defer dir.close(io);
        try checkApp(gpa, io, dir, app);
        std.debug.print("fw_matrix: {s}: examples/{s}/ is the pinned build\n", .{ f.id, app.id });
    }
}

fn fetchTree(gpa: Allocator, arena: Allocator, io: Io, f: manifest.Suite, tree: []const u8, downloads: []const u8, node_dir: ?[]const u8, environ: ?*const std.process.Environ.Map) !void {
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

    if (f.npm) |n| {
        const tree_abs = try Io.Dir.cwd().realPathFileAlloc(io, tree, arena);
        const npm_cache = try Io.Dir.cwd().realPathFileAlloc(io, downloads, arena);
        const env = try nodeEnviron(arena, environ, try std.fmt.allocPrint(arena, "{s}/bin", .{node_dir.?}), try std.fmt.allocPrint(arena, "{s}/npm-cache", .{npm_cache}));
        _ = try npmInstall(gpa, arena, io, &env, node_dir.?, tree_abs, n);
    }

    // The project's own Bazel builds every page's target (Angular: its
    // web-test-runner debug targets), so a run only starts them.
    if (f.bazel) |bz| {
        const frameworks_abs = try Io.Dir.cwd().realPathFileAlloc(io, std.fs.path.dirname(tree) orelse ".", arena);
        const bazelisk = try fetchBazelisk(gpa, arena, io, frameworks_abs, bz);
        const env = try bazelEnviron(arena, environ, frameworks_abs, bz);
        const start = try bazelArgv(arena, bazelisk, frameworks_abs);
        var argv: std.ArrayList([]const u8) = .empty;
        try argv.appendSlice(arena, &start);
        try argv.appendSlice(arena, &.{ "build", try std.fmt.allocPrint(arena, "--jobs={d}", .{bz.jobs}) });
        for (f.pages) |p| if (p.target) |t| try argv.append(arena, t);
        try runIn(gpa, io, &env, try Io.Dir.cwd().realPathFileAlloc(io, tree, arena), argv.items);
    }

    // Written last: a fetch that failed above is redone in full.
    try dir.writeFile(io, .{ .sub_path = stamp_name, .data = &want });
}

// ---------------------------------------------------------------------------
// Node, for a suite whose own tooling runs under it (the user, 2026-11-11
// 17:43 ET: "we can run node for the purposes of these tests" - the
// framework matrix only, never Crane's build, WPT or product).
//
//   <dir>/node-v<version>-<platform>/       nodejs.org's release archive for
//                                           the host, its top directory
//                                           stripped (links and the
//                                           executable bit kept)
//   <dir>/node-v.../.fw_matrix-fetched      the archive's sha256
//   <dir>/downloads/npm-cache/              npm's cache (never ~/.npm)
//   <tree>/node_modules/                    `npm ci` from the project's own
//                                           lockfile (its sha256 checked
//                                           first; npm checks each package's
//                                           integrity line)
//   <tree>/.fw_matrix-node-modules          dirHash of node_modules
//                                           as installed, which a run checks
// ---------------------------------------------------------------------------

/// Node's own name for a host, as its release archives spell it
/// ("node-v24.22.3-linux-x64.tar.gz"); null for a host it ships none for.
pub fn nodePlatform(os: std.Target.Os.Tag, arch: std.Target.Cpu.Arch) ?[]const u8 {
    return switch (os) {
        .linux => switch (arch) {
            .x86_64 => "linux-x64",
            .aarch64 => "linux-arm64",
            else => null,
        },
        .macos => switch (arch) {
            .x86_64 => "darwin-x64",
            .aarch64 => "darwin-arm64",
            else => null,
        },
        else => null,
    };
}

/// This host's (fw_matrix runs on the host it was built for).
pub fn hostNodePlatform() ?[]const u8 {
    return nodePlatform(builtin.os.tag, builtin.cpu.arch);
}

pub fn nodeDirPath(arena: Allocator, frameworks_dir: []const u8, version: []const u8, platform: []const u8) ![]const u8 {
    return std.fmt.allocPrint(arena, "{s}/node-v{s}-{s}", .{ frameworks_dir, version, platform });
}

/// Node's archive into `dir`: its top directory stripped, symbolic links made
/// (bin/npm and bin/npx are links into lib/) and the executable bit kept.
pub fn extractNode(gpa: Allocator, io: Io, tgz: []const u8, dir: Io.Dir) !void {
    const tar_bytes = try gunzip(gpa, tgz);
    defer gpa.free(tar_bytes);
    var in: Io.Reader = .fixed(tar_bytes);
    try std.tar.extract(io, dir, &in, .{ .strip_components = 1, .mode_mode = .executable_bit_only });
}

/// The pinned Node for this host under `frameworks_dir`, fetched unless its
/// stamp says it is there; its directory, absolute (arena-owned).
pub fn fetchNode(gpa: Allocator, arena: Allocator, io: Io, frameworks_dir: []const u8, node: manifest.Node) ![]const u8 {
    const platform = hostNodePlatform() orelse return error.NoNodeForHost;
    const archive = node.archiveFor(platform) orelse {
        std.debug.print("fw_matrix: the manifest pins no Node {s} archive for {s}\n", .{ node.version, platform });
        return error.NoNodeForHost;
    };
    const path = try nodeDirPath(arena, frameworks_dir, node.version, platform);
    const stamp_path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ path, stamp_name });
    if (Io.Dir.cwd().readFileAlloc(io, stamp_path, arena, .limited(256))) |have| {
        if (std.mem.eql(u8, std.mem.trim(u8, have, " \n"), archive.sha256)) {
            std.debug.print("fw_matrix: Node {s} ({s}) is current\n", .{ node.version, platform });
            return Io.Dir.cwd().realPathFileAlloc(io, path, arena);
        }
    } else |_| {}
    const downloads = try std.fmt.allocPrint(arena, "{s}/downloads", .{frameworks_dir});
    try Io.Dir.cwd().createDirPath(io, downloads);
    Io.Dir.cwd().deleteTree(io, path) catch {};
    try Io.Dir.cwd().createDirPath(io, path);
    var dir = try Io.Dir.cwd().openDir(io, path, .{});
    defer dir.close(io);
    const bytes = try obtain(gpa, io, downloads, archive.url, archive.sha256, null);
    defer gpa.free(bytes);
    try extractNode(gpa, io, bytes, dir);
    try dir.writeFile(io, .{ .sub_path = stamp_name, .data = archive.sha256 });
    std.debug.print("fw_matrix: Node {s} ({s}) from {s} (sha256 {s})\n", .{ node.version, platform, archive.url, archive.sha256[0..12] });
    return Io.Dir.cwd().realPathFileAlloc(io, path, arena);
}

/// The pinned Node for this host as a run finds it: fetched, for the
/// manifest's archive (arena-owned, absolute).
pub fn nodeDirChecked(arena: Allocator, io: Io, frameworks_dir: []const u8, node: manifest.Node) ![]const u8 {
    const platform = hostNodePlatform() orelse return error.NoNodeForHost;
    const archive = node.archiveFor(platform) orelse return error.NoNodeForHost;
    const path = try nodeDirPath(arena, frameworks_dir, node.version, platform);
    const have = Io.Dir.cwd().readFileAlloc(io, try std.fmt.allocPrint(arena, "{s}/{s}", .{ path, stamp_name }), arena, .limited(256)) catch {
        std.debug.print("fw_matrix: Node {s} is not fetched at {s} (run `fw_matrix fetch` first)\n", .{ node.version, path });
        return error.NotFetched;
    };
    if (!std.mem.eql(u8, std.mem.trim(u8, have, " \n"), archive.sha256)) return error.StaleFetch;
    return Io.Dir.cwd().realPathFileAlloc(io, path, arena);
}

// ---------------------------------------------------------------------------
// Bazel, for a suite the project builds and serves with it (Angular):
//
//   <frameworks>/bazelisk-<version>-<platform>/bazelisk   the pinned bazelisk
//   <frameworks>/bazelisk-home/                          the Bazel it fetches
//   <frameworks>/bazel-root/                             Bazel's output root
//
// bazelisk checks the Bazel binary it fetches against BAZELISK_VERIFY_SHA256
// (the manifest's pin for the host); Bazel's own downloads are the
// project's pins (its MODULE.bazel.lock).

pub fn bazelRoot(arena: Allocator, frameworks_abs: []const u8) ![]const u8 {
    return std.fmt.allocPrint(arena, "{s}/bazel-root", .{frameworks_abs});
}

/// The pinned bazelisk for the host, downloaded once; its absolute path.
pub fn fetchBazelisk(gpa: Allocator, arena: Allocator, io: Io, frameworks_dir: []const u8, bz: manifest.Bazel) ![]const u8 {
    const platform = hostNodePlatform() orelse return error.NoBazelForHost;
    const archive = for (bz.bazelisk) |a| {
        if (std.mem.eql(u8, a.platform, platform)) break a;
    } else {
        std.debug.print("fw_matrix: the manifest pins no bazelisk for {s}\n", .{platform});
        return error.NoBazelForHost;
    };
    const dir_path = try std.fmt.allocPrint(arena, "{s}/bazelisk-{s}-{s}", .{ frameworks_dir, bz.bazelisk_version, platform });
    const path = try std.fmt.allocPrint(arena, "{s}/bazelisk", .{dir_path});
    const stamp_path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ dir_path, stamp_name });
    if (Io.Dir.cwd().readFileAlloc(io, stamp_path, arena, .limited(256))) |have| {
        if (std.mem.eql(u8, std.mem.trim(u8, have, " \n"), archive.sha256)) return Io.Dir.cwd().realPathFileAlloc(io, path, arena);
    } else |_| {}
    const downloads = try std.fmt.allocPrint(arena, "{s}/downloads", .{frameworks_dir});
    try Io.Dir.cwd().createDirPath(io, downloads);
    try Io.Dir.cwd().createDirPath(io, dir_path);
    const bytes = try obtain(gpa, io, downloads, archive.url, archive.sha256, null);
    defer gpa.free(bytes);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = bytes, .flags = .{ .permissions = .executable_file } });
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = stamp_path, .data = archive.sha256 });
    std.debug.print("fw_matrix: bazelisk {s} ({s}) from {s}\n", .{ bz.bazelisk_version, platform, archive.url });
    return Io.Dir.cwd().realPathFileAlloc(io, path, arena);
}

/// The environment bazelisk runs in: the parent's, its home under the
/// frameworks directory, and the Bazel binary's pin for the host.
pub fn bazelEnviron(arena: Allocator, parent: ?*const std.process.Environ.Map, frameworks_abs: []const u8, bz: manifest.Bazel) !std.process.Environ.Map {
    const platform = hostNodePlatform() orelse return error.NoBazelForHost;
    const pin = manifest.BinaryPin.find(bz.binaries, platform) orelse {
        std.debug.print("fw_matrix: the manifest pins no Bazel {s} binary for {s}\n", .{ bz.version, platform });
        return error.NoBazelForHost;
    };
    var env: std.process.Environ.Map = .init(arena);
    if (parent) |p| try env.putAll(p);
    try env.put("BAZELISK_HOME", try std.fmt.allocPrint(arena, "{s}/bazelisk-home", .{frameworks_abs}));
    try env.put("BAZELISK_VERIFY_SHA256", pin.sha256);
    return env;
}

/// The command line that starts the fetched Bazel: bazelisk and its output
/// root (a startup option, before the command).
pub fn bazelArgv(arena: Allocator, bazelisk: []const u8, frameworks_abs: []const u8) ![2][]const u8 {
    return .{ bazelisk, try std.fmt.allocPrint(arena, "--output_user_root={s}", .{try bazelRoot(arena, frameworks_abs)}) };
}

pub const node_modules_stamp = ".fw_matrix-node-modules";

/// A directory as one sha256 (a tree's node_modules; a TodoMVC app's
/// examples/<id>/): a line per entry - "D <path>" for a directory, "F <path>
/// <sha256 of its bytes>" for a file, "L <path> <target>" for a symbolic
/// link (never followed) - sorted by path bytes and hashed together. The
/// same files give the same hash on any machine and in any order of
/// creation; the walk reads every file once.
pub fn dirHash(gpa: Allocator, io: Io, dir: Io.Dir) ![64]u8 {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const Line = struct { path: []const u8, text: []const u8 };
    var lines: std.ArrayList(Line) = .empty;
    var it = try dir.openDir(io, ".", .{ .iterate = true });
    defer it.close(io);
    var walker = try it.walk(arena);
    defer walker.deinit();
    var link_buf: [Io.Dir.max_path_bytes]u8 = undefined;
    while (try walker.next(io)) |e| {
        const path = try arena.dupe(u8, e.path);
        const text = switch (e.kind) {
            .directory => try std.fmt.allocPrint(arena, "D {s}\n", .{path}),
            .sym_link => blk: {
                const n = try e.dir.readLink(io, e.basename, &link_buf);
                break :blk try std.fmt.allocPrint(arena, "L {s} {s}\n", .{ path, link_buf[0..n] });
            },
            .file => blk: {
                const bytes = try e.dir.readFileAlloc(io, e.basename, gpa, .limited(max_archive));
                defer gpa.free(bytes);
                break :blk try std.fmt.allocPrint(arena, "F {s} {s}\n", .{ path, &sha256Hex(bytes) });
            },
            else => {
                std.debug.print("fw_matrix: {s}: a {t} in the tree hashed\n", .{ path, e.kind });
                return error.UnexpectedFileKind;
            },
        };
        try lines.append(arena, .{ .path = path, .text = text });
    }
    std.mem.sort(Line, lines.items, {}, struct {
        fn lt(_: void, a: Line, b: Line) bool {
            return std.mem.order(u8, a.path, b.path) == .lt;
        }
    }.lt);
    var h: std.crypto.hash.sha2.Sha256 = .init(.{});
    for (lines.items) |l| h.update(l.text);
    var digest: [32]u8 = undefined;
    h.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

/// The tree's package-lock.json is the one the manifest pins.
pub fn checkLockfile(gpa: Allocator, io: Io, tree: Io.Dir, sha256: []const u8) !void {
    const bytes = try tree.readFileAlloc(io, "package-lock.json", gpa, .limited(max_archive));
    defer gpa.free(bytes);
    const got = sha256Hex(bytes);
    if (!std.mem.eql(u8, &got, sha256)) {
        std.debug.print("fw_matrix: package-lock.json is sha256 {s}; the manifest pins {s}\n", .{ &got, sha256 });
        return error.LockfileMismatch;
    }
}

/// The environment Node's tools run in: the parent's, with the pinned Node's
/// bin leading PATH (a `#!/usr/bin/env node` command finds it), npm's cache
/// under the frameworks directory and its network chatter (update notifier,
/// funding, audit) off. Arena-owned.
pub fn nodeEnviron(arena: Allocator, parent: ?*const std.process.Environ.Map, node_bin: []const u8, npm_cache: []const u8) !std.process.Environ.Map {
    var env: std.process.Environ.Map = .init(arena);
    if (parent) |p| try env.putAll(p);
    const path = if (env.get("PATH")) |old| try std.fmt.allocPrint(arena, "{s}:{s}", .{ node_bin, old }) else node_bin;
    try env.put("PATH", path);
    try env.put("npm_config_cache", npm_cache);
    try env.put("npm_config_update_notifier", "false");
    try env.put("npm_config_fund", "false");
    try env.put("npm_config_audit", "false");
    return env;
}

/// `argv` in `cwd` with `environ`; its output is printed only when it fails.
pub fn runIn(gpa: Allocator, io: Io, environ: *const std.process.Environ.Map, cwd: []const u8, argv: []const []const u8) !void {
    const result = try std.process.run(gpa, io, .{ .argv = argv, .cwd = .{ .path = cwd }, .environ_map = environ });
    defer gpa.free(result.stdout);
    defer gpa.free(result.stderr);
    const ok = switch (result.term) {
        .exited => |code| code == 0,
        else => false,
    };
    const joined = try std.mem.join(gpa, " ", argv);
    defer gpa.free(joined);
    if (ok) {
        std.debug.print("fw_matrix: ran `{s}` in {s}\n", .{ joined, cwd });
        return;
    }
    const tail = result.stderr[result.stderr.len -| 4000..];
    std.debug.print("fw_matrix: `{s}` in {s}: {f}\n{s}\n", .{ joined, cwd, result.term, tail });
    return error.CommandFailed;
}

/// The project's own dependencies into `tree` (absolute): its lockfile
/// checked against the pin, `npm ci` (no install scripts: npm checks every
/// package's integrity line against the lockfile), the manifest's scripts in
/// order, then the hash of node_modules written beside it. Returns the hash.
pub fn npmInstall(gpa: Allocator, arena: Allocator, io: Io, environ: *const std.process.Environ.Map, node_dir: []const u8, tree: []const u8, npm: manifest.Npm) ![64]u8 {
    var dir = try Io.Dir.cwd().openDir(io, tree, .{});
    defer dir.close(io);
    try checkLockfile(gpa, io, dir, npm.lockfile_sha256);
    const npm_bin = try std.fmt.allocPrint(arena, "{s}/bin/npm", .{node_dir});
    try runIn(gpa, io, environ, tree, &.{ npm_bin, "ci", "--ignore-scripts", "--no-audit", "--no-fund" });
    for (npm.scripts) |s| try runIn(gpa, io, environ, tree, &.{ npm_bin, "run", s });
    var nm = try dir.openDir(io, "node_modules", .{});
    defer nm.close(io);
    const h = try dirHash(gpa, io, nm);
    try dir.writeFile(io, .{ .sub_path = node_modules_stamp, .data = &h });
    std.debug.print("fw_matrix: node_modules installed, sha256 {s}\n", .{&h});
    return h;
}

/// The tree's node_modules as a run finds it: hashed again and compared with
/// what `fw_matrix fetch` installed. Returns the hash.
pub fn checkNodeModules(gpa: Allocator, io: Io, tree: []const u8) ![64]u8 {
    var dir = try Io.Dir.cwd().openDir(io, tree, .{});
    defer dir.close(io);
    var buf: [128]u8 = undefined;
    const recorded = std.mem.trim(u8, dir.readFile(io, node_modules_stamp, &buf) catch {
        std.debug.print("fw_matrix: {s} has no {s} (run `fw_matrix fetch` first)\n", .{ tree, node_modules_stamp });
        return error.NotFetched;
    }, " \n");
    var nm = try dir.openDir(io, "node_modules", .{});
    defer nm.close(io);
    const h = try dirHash(gpa, io, nm);
    if (!std.mem.eql(u8, recorded, &h)) {
        std.debug.print("fw_matrix: {s}/node_modules is sha256 {s}; fetch installed {s}\n", .{ tree, &h, recorded });
        return error.NodeModulesChanged;
    }
    return h;
}

const testing = std.testing;

/// One ustar header block (POSIX.1-1988: name, mode, uid, gid, size, mtime,
/// checksum, typeflag, magic), written by hand so the tests do not read
/// archives through the code that wrote them.
fn ustarHeader(out: *Io.Writer, name: []const u8, size: usize, typeflag: u8, mode: u32, link: []const u8) !void {
    var h: [512]u8 = @splat(0);
    @memcpy(h[0..name.len], name);
    @memcpy(h[157..][0..link.len], link);
    _ = try std.fmt.bufPrint(h[100..108], "{o:0>7}", .{mode});
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

const TarEntry = struct {
    path: []const u8,
    content: []const u8 = "",
    mode: u32 = 0o644,
    /// A symbolic link to this target.
    link: ?[]const u8 = null,
};

/// A gzip'd tar of `entries` (a path ending in '/' a directory).
fn tarGz(gpa: Allocator, entries: []const TarEntry) ![]u8 {
    var tar_out: Io.Writer.Allocating = .init(gpa);
    defer tar_out.deinit();
    const w = &tar_out.writer;
    for (entries) |e| {
        const dir = std.mem.endsWith(u8, e.path, "/");
        if (e.link) |target| {
            try ustarHeader(w, e.path, 0, '2', 0o777, target);
            continue;
        }
        try ustarHeader(w, e.path, if (dir) 0 else e.content.len, if (dir) '5' else '0', if (dir) 0o755 else e.mode, "");
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

test "nodePlatform: Node's own names for the hosts it ships archives for" {
    try testing.expectEqualStrings("linux-x64", nodePlatform(.linux, .x86_64).?);
    try testing.expectEqualStrings("linux-arm64", nodePlatform(.linux, .aarch64).?);
    try testing.expectEqualStrings("darwin-arm64", nodePlatform(.macos, .aarch64).?);
    try testing.expectEqualStrings("darwin-x64", nodePlatform(.macos, .x86_64).?);
    try testing.expectEqual(@as(?[]const u8, null), nodePlatform(.windows, .x86_64));
    try testing.expectEqual(@as(?[]const u8, null), nodePlatform(.linux, .riscv64));
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    try testing.expectEqualStrings("/f/node-v24.22.3-linux-x64", try nodeDirPath(arena_state.allocator(), "/f", "24.22.3", "linux-x64"));
}

test "extractNode: the top directory stripped; bin/npm stays a link and bin/node executable" {
    const tgz = try tarGz(testing.allocator, &[_]TarEntry{
        .{ .path = "node-v24.22.3-linux-x64/" },
        .{ .path = "node-v24.22.3-linux-x64/bin/" },
        .{ .path = "node-v24.22.3-linux-x64/bin/node", .content = "ELF", .mode = 0o755 },
        .{ .path = "node-v24.22.3-linux-x64/bin/npm", .link = "../lib/node_modules/npm/bin/npm-cli.js" },
        .{ .path = "node-v24.22.3-linux-x64/lib/node_modules/npm/bin/npm-cli.js", .content = "#!/usr/bin/env node\n", .mode = 0o755 },
        .{ .path = "node-v24.22.3-linux-x64/README.md", .content = "Node" },
    });
    defer testing.allocator.free(tgz);
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try extractNode(testing.allocator, testing.io, tgz, tmp.dir);
    var buf: [Io.Dir.max_path_bytes]u8 = undefined;
    const n = try tmp.dir.readLink(testing.io, "bin/npm", &buf);
    try testing.expectEqualStrings("../lib/node_modules/npm/bin/npm-cli.js", buf[0..n]);
    const through = try tmp.dir.readFileAlloc(testing.io, "bin/npm", testing.allocator, .limited(100));
    defer testing.allocator.free(through);
    try testing.expectEqualStrings("#!/usr/bin/env node\n", through);
    if (Io.File.Permissions.has_executable_bit) {
        const node = try tmp.dir.statFile(testing.io, "bin/node", .{});
        try testing.expect(node.permissions.toMode() & 0o100 != 0);
        const readme = try tmp.dir.statFile(testing.io, "README.md", .{});
        try testing.expect(readme.permissions.toMode() & 0o100 == 0);
    }
}

/// The text dirHash hashes, written out by hand for the tests.
fn sha256Line(comptime kind: []const u8, path: []const u8, bytes: []const u8) ![]u8 {
    return std.fmt.allocPrint(testing.allocator, kind ++ " {s} {s}\n", .{ path, &sha256Hex(bytes) });
}

test "dirHash: every directory, file (by its sha256) and link (by its target), in path order" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "e");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "c.js", .data = "C" });
    try tmp.dir.createDirPath(testing.io, "a");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "a/b.js", .data = "B" });
    try tmp.dir.symLink(testing.io, "b.js", "a/link", .{});
    const got = try dirHash(testing.allocator, testing.io, tmp.dir);

    // The format, independently: one line per entry, sorted by path bytes.
    const b_line = try sha256Line("F", "a/b.js", "B");
    defer testing.allocator.free(b_line);
    const c_line = try sha256Line("F", "c.js", "C");
    defer testing.allocator.free(c_line);
    const text = try std.mem.concat(testing.allocator, u8, &.{ "D a\n", b_line, "L a/link b.js\n", c_line, "D e\n" });
    defer testing.allocator.free(text);
    try testing.expectEqualStrings(&sha256Hex(text), &got);

    // The same tree made in another order hashes the same; one changed
    // byte, or a link's target, does not.
    var other = testing.tmpDir(.{});
    defer other.cleanup();
    try other.dir.createDirPath(testing.io, "a");
    try other.dir.symLink(testing.io, "b.js", "a/link", .{});
    try other.dir.writeFile(testing.io, .{ .sub_path = "a/b.js", .data = "B" });
    try other.dir.writeFile(testing.io, .{ .sub_path = "c.js", .data = "C" });
    try other.dir.createDirPath(testing.io, "e");
    try testing.expectEqualStrings(&got, &(try dirHash(testing.allocator, testing.io, other.dir)));
    try other.dir.writeFile(testing.io, .{ .sub_path = "c.js", .data = "D" });
    try testing.expect(!std.mem.eql(u8, &got, &(try dirHash(testing.allocator, testing.io, other.dir))));
}

test "a TodoMVC app: its directory checked against its pin; the shared tree's stamp is every app's" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(testing.io, "examples/react/dist");
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "examples/react/dist/index.html", .data = "<h1>todos</h1>" });
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "examples/react/package.json", .data = "{}" });
    var app_dir = try tmp.dir.openDir(testing.io, "examples/react", .{});
    const pin = try dirHash(testing.allocator, testing.io, app_dir);
    app_dir.close(testing.io);

    const app: manifest.App = .{ .id = "react", .title = "React", .folder = "react/dist", .sha256 = &pin };
    try checkApp(testing.allocator, testing.io, tmp.dir, app);
    // One byte of the build changed: not the pinned build.
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "examples/react/dist/index.html", .data = "<h1>Todos</h1>" });
    try testing.expectError(error.AppMismatch, checkApp(testing.allocator, testing.io, tmp.dir, app));
    var gone = app;
    gone.id = "vue";
    try testing.expectError(error.AppMissing, checkApp(testing.allocator, testing.io, tmp.dir, gone));

    // Two apps on one tree find the same stamp; a suite of its own does not
    // share its stamp with another; how a page runs is not the tree's.
    const base: manifest.Suite = .{ .id = "react-todomvc", .framework = "react", .title = "React", .version = "19.2.5", .kind = .todomvc_port, .repository = "https://github.com/tastejs/todomvc", .tag = "examples/react/dist", .commit = "ff43b02e59df", .licence = "MIT", .runner = "QUnit", .reader = .qunit, .source = .{ .url = "https://x", .sha256 = "a" }, .pages = &.{.{ .id = "todomvc", .path = "p?framework=react" }}, .excluded = "x.txt", .tree = "todomvc-ff43b02e59df", .app = app };
    var other = base;
    other.id = "vue-todomvc";
    other.version = "3.5.33";
    other.pages = &.{.{ .id = "todomvc", .path = "p?framework=vue" }};
    other.app = gone;
    try testing.expectEqualStrings(&(try entryHash(testing.allocator, base)), &(try entryHash(testing.allocator, other)));
    var own = base;
    own.tree = null;
    var own2 = other;
    own2.tree = null;
    try testing.expect(!std.mem.eql(u8, &(try entryHash(testing.allocator, own)), &(try entryHash(testing.allocator, own2))));
    var slower = own;
    slower.page_budget_s += 100;
    slower.page_stall_s += 100;
    try testing.expectEqualStrings(&(try entryHash(testing.allocator, own)), &(try entryHash(testing.allocator, slower)));
    var other_source = own;
    other_source.source.sha256 = "c";
    try testing.expect(!std.mem.eql(u8, &(try entryHash(testing.allocator, own)), &(try entryHash(testing.allocator, other_source))));
}

test "checkLockfile: the tree's package-lock.json against the manifest's pin" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "package-lock.json", .data = "{\"lockfileVersion\":3}" });
    try checkLockfile(testing.allocator, testing.io, tmp.dir, &sha256Hex("{\"lockfileVersion\":3}"));
    try testing.expectError(error.LockfileMismatch, checkLockfile(testing.allocator, testing.io, tmp.dir, &sha256Hex("{}")));
    var empty = testing.tmpDir(.{});
    defer empty.cleanup();
    try testing.expectError(error.FileNotFound, checkLockfile(testing.allocator, testing.io, empty.dir, &sha256Hex("{}")));
}

test "nodeEnviron: the pinned Node's bin leads PATH; npm's cache and quiet settings; the rest inherited" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var parent: std.process.Environ.Map = .init(a);
    try parent.put("PATH", "/usr/bin:/bin");
    try parent.put("HOME", "/home/x");
    try parent.put("npm_config_cache", "/home/x/.npm");
    const env = try nodeEnviron(a, &parent, "/f/node-v24.22.3-linux-x64/bin", "/f/downloads/npm-cache");
    try testing.expectEqualStrings("/f/node-v24.22.3-linux-x64/bin:/usr/bin:/bin", env.get("PATH").?);
    try testing.expectEqualStrings("/home/x", env.get("HOME").?);
    try testing.expectEqualStrings("/f/downloads/npm-cache", env.get("npm_config_cache").?);
    try testing.expectEqualStrings("false", env.get("npm_config_update_notifier").?);
    try testing.expectEqualStrings("false", env.get("npm_config_fund").?);
    try testing.expectEqualStrings("false", env.get("npm_config_audit").?);
    // No parent: PATH is Node's bin alone.
    const bare = try nodeEnviron(a, null, "/n/bin", "/c");
    try testing.expectEqualStrings("/n/bin", bare.get("PATH").?);
}

test "runIn: a command in a directory with an environment; a failure is an error" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try tmp.dir.realPathFileAlloc(testing.io, ".", a);
    var env: std.process.Environ.Map = .init(a);
    try env.put("X", "y");
    try runIn(testing.allocator, testing.io, &env, dir, &.{ "/bin/sh", "-c", "test \"$X\" = y && echo here > made.txt" });
    const made = try tmp.dir.readFileAlloc(testing.io, "made.txt", testing.allocator, .limited(100));
    defer testing.allocator.free(made);
    try testing.expectEqualStrings("here\n", made);
    try testing.expectError(error.CommandFailed, runIn(testing.allocator, testing.io, &env, dir, &.{ "/bin/sh", "-c", "echo no >&2; exit 3" }));
}
