//! Harness-based test selection over the WPT testharness corpus.
//!
//! The runner used to discover tests by walking the filesystem and guessing
//! which files were tests from their names (`-ref.html` is a reftest, `.html`
//! is a test, and so on). MANIFEST.json already answers that question
//! authoritatively: it partitions every file in the tree by harness type, so
//! `items.testharness` *is* the set of tests we are trying to pass.
//!
//! Selecting from the manifest gives the scoreboard a real denominator. The
//! filesystem walk could only ever report "tests we happened to find"; this
//! reports "tests that exist, of which we ran N".

const std = @import("std");
const Allocator = std.mem.Allocator;

const config = @import("config.zig");
const wpt_manifest = @import("manifest.zig");

/// The set of tests a run intends to execute.
pub const Selection = struct {
    allocator: Allocator,
    /// Distinct source files to execute, sorted for a stable run order.
    ///
    /// Sources rather than URLs because the runner executes a source once and
    /// fans out over the global contexts named in its metadata - a single
    /// `.any.js` covers its `.any.html` and `.any.worker.html` URLs.
    sources: [][]const u8,
    /// Number of manifest test URLs this selection covers.
    url_count: usize,

    pub fn deinit(self: *Selection) void {
        for (self.sources) |s| self.allocator.free(s);
        self.allocator.free(self.sources);
    }
};

/// True when `url` sits under one of `dirs` (each given without a trailing
/// slash, e.g. "dom" or "html/dom"). An empty `dirs` accepts everything.
fn matchesAnyDir(url: []const u8, dirs: []const []const u8) bool {
    if (dirs.len == 0) return true;
    for (dirs) |raw| {
        const dir = std.mem.trim(u8, raw, "/");
        if (dir.len == 0) continue;
        if (url.len > dir.len and
            std.mem.startsWith(u8, url, dir) and
            url[dir.len] == '/')
        {
            return true;
        }
    }
    return false;
}

/// Select every in-scope testharness source in `manifest`.
///
/// `dir_filters` optionally narrows the selection to URLs under those
/// directories; an empty slice selects all in-scope categories.
///
/// A source is selected when *any* of its URLs is in scope. That matters for
/// generated tests, where the manifest may list variants that are individually
/// excluded (worker globals, for instance) alongside ones that are not.
pub fn selectInScope(
    allocator: Allocator,
    manifest: *const wpt_manifest.Manifest,
    dir_filters: []const []const u8,
) !Selection {
    var seen: std.StringHashMap(void) = std.StringHashMap(void).init(allocator);
    defer {
        var it = seen.keyIterator();
        while (it.next()) |k| allocator.free(k.*);
        seen.deinit();
    }

    var url_count: usize = 0;

    var iter = manifest.url_to_source.iterator();
    while (iter.next()) |entry| {
        const url = entry.key_ptr.*;
        if (!matchesAnyDir(url, dir_filters)) continue;
        if (!config.isInScope(url)) continue;

        url_count += 1;

        const source = entry.value_ptr.*;
        if (seen.contains(source)) continue;
        const owned = try allocator.dupe(u8, source);
        errdefer allocator.free(owned);
        try seen.put(owned, {});
    }

    // Move the keys out of the set rather than duplicating them again.
    var sources = try allocator.alloc([]const u8, seen.count());
    errdefer allocator.free(sources);

    var i: usize = 0;
    var key_iter = seen.keyIterator();
    while (key_iter.next()) |k| : (i += 1) sources[i] = k.*;
    seen.clearRetainingCapacity();

    // Hash map order is not stable across runs, and a baseline diff is only
    // readable if the run order is.
    std.mem.sort([]const u8, sources, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);

    return .{
        .allocator = allocator,
        .sources = sources,
        .url_count = url_count,
    };
}

// ============================================================================
// Worklist
// ============================================================================

/// An ordered list of test sources, read back from a file.
///
/// A run that has to survive crashes cannot pass its test list on the command
/// line - there are thousands of paths, well past any argv limit - and it needs
/// the order to be identical across restarts, because the resume point is an
/// index into that order.
pub const Worklist = struct {
    allocator: Allocator,
    paths: [][]const u8,

    pub fn deinit(self: *Worklist) void {
        for (self.paths) |p| self.allocator.free(p);
        self.allocator.free(self.paths);
    }
};

/// Write one path per line.
pub fn writeWorklist(w: *std.Io.Writer, paths: []const []const u8) !void {
    for (paths) |p| try w.print("{s}\n", .{p});
}

/// Parse a worklist's bytes. Blank lines are ignored; everything else is a path.
pub fn parseWorklist(allocator: Allocator, bytes: []const u8) !Worklist {
    var paths: std.ArrayListUnmanaged([]const u8) = .empty;
    errdefer {
        for (paths.items) |p| allocator.free(p);
        paths.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0) continue;
        try paths.append(allocator, try allocator.dupe(u8, line));
    }

    return .{
        .allocator = allocator,
        .paths = try paths.toOwnedSlice(allocator),
    };
}

/// Read a worklist from disk.
pub fn readWorklist(allocator: Allocator, path: []const u8) !Worklist {
    const bytes = try std.fs.cwd().readFileAlloc(allocator, path, 64 * 1024 * 1024);
    defer allocator.free(bytes);
    return parseWorklist(allocator, bytes);
}

/// How many runners a run should actually use.
///
/// `requested` is `--parallel=N` as given, where 0 means "decide for me" and
/// resolves to one runner per core. Either way the count is capped at the
/// number of tests: a runner costs about nine seconds of process startup before
/// it opens a single file, so spawning more of them than there is work for is a
/// straight loss, and the surplus shards would have empty worklists anyway.
///
/// `cpu_count` is passed in rather than queried so this stays a pure function.
/// It can legitimately be 0 when the platform will not say, which is treated as
/// "one" rather than as an error - a serial run is the right fallback.
pub fn resolveShardCount(requested: usize, total: usize, cpu_count: usize) usize {
    if (total == 0) return 0;
    const want = if (requested == 0) @max(cpu_count, 1) else requested;
    return @min(want, total);
}

/// The positions of `total` worklist entries belonging to shard `shard` of
/// `shard_count`, in worklist order. Caller owns the returned slice.
///
/// Round robin, not contiguous blocks. Discovery yields paths in directory
/// order and cost tracks the directory hard - `html/` alone is 62% of the
/// in-scope corpus and its tests are the slow ones - so contiguous blocks would
/// hand one shard hours of work and another minutes. Interleaving spreads every
/// directory across every shard.
///
/// The result is a mapping from a shard-local index to a global one, which is
/// what lets each shard keep a private, contiguous worklist (and so a working
/// resume point) while its journal records can still be translated back onto
/// the run as a whole.
pub fn shardIndices(
    allocator: Allocator,
    total: usize,
    shard_count: usize,
    shard: usize,
) ![]usize {
    std.debug.assert(shard_count > 0);
    std.debug.assert(shard < shard_count);

    var out: std.ArrayListUnmanaged(usize) = .empty;
    errdefer out.deinit(allocator);

    var i = shard;
    while (i < total) : (i += shard_count) try out.append(allocator, i);

    return out.toOwnedSlice(allocator);
}

// ============================================================================
// Tests
// ============================================================================

const test_manifest_json =
    \\{
    \\  "version": 8,
    \\  "url_base": "/",
    \\  "items": {
    \\    "testharness": {
    \\      "dom": {
    \\        "nodes": {
    \\          "Node-appendChild.html": ["hash", [null, {}]]
    \\        },
    \\        "abort": {
    \\          "AbortSignal.any.js": [
    \\            "hash",
    \\            ["dom/abort/AbortSignal.any.html", {}],
    \\            ["dom/abort/AbortSignal.any.worker.html", {}]
    \\          ]
    \\        }
    \\      },
    \\      "domparsing": {
    \\        "xmlserializer.html": ["hash", [null, {}]]
    \\      },
    \\      "css": {
    \\        "selectors": {
    \\          "focus-visible.html": ["hash", [null, {}]]
    \\        }
    \\      },
    \\      "html": {
    \\        "rendering": {
    \\          "replaced-elements.html": ["hash", [null, {}]]
    \\        },
    \\        "dom": {
    \\          "reflection.html": ["hash", [null, {}]]
    \\        }
    \\      }
    \\    }
    \\  }
    \\}
;

fn indexOfSource(sel: Selection, want: []const u8) ?usize {
    for (sel.sources, 0..) |s, i| {
        if (std.mem.eql(u8, s, want)) return i;
    }
    return null;
}

test "selectInScope keeps in-scope tests and drops out-of-scope ones" {
    const allocator = std.testing.allocator;

    var manifest = try wpt_manifest.parseManifestBytes(allocator, test_manifest_json);
    defer manifest.deinit();

    var sel = try selectInScope(allocator, &manifest, &.{});
    defer sel.deinit();

    // dom/ and html/dom/ are in scope.
    try std.testing.expect(indexOfSource(sel, "dom/nodes/Node-appendChild.html") != null);
    try std.testing.expect(indexOfSource(sel, "dom/abort/AbortSignal.any.js") != null);
    try std.testing.expect(indexOfSource(sel, "html/dom/reflection.html") != null);

    // css/ is not an in-scope category; html/rendering/ is explicitly excluded;
    // domparsing only shares a prefix with dom.
    try std.testing.expect(indexOfSource(sel, "css/selectors/focus-visible.html") == null);
    try std.testing.expect(indexOfSource(sel, "html/rendering/replaced-elements.html") == null);
    try std.testing.expect(indexOfSource(sel, "domparsing/xmlserializer.html") == null);

    try std.testing.expectEqual(@as(usize, 3), sel.sources.len);
}

test "selectInScope counts URLs, not sources" {
    const allocator = std.testing.allocator;

    var manifest = try wpt_manifest.parseManifestBytes(allocator, test_manifest_json);
    defer manifest.deinit();

    var sel = try selectInScope(allocator, &manifest, &.{});
    defer sel.deinit();

    // AbortSignal.any.js is one source but two URLs, so the denominator is 4
    // over 3 sources.
    try std.testing.expectEqual(@as(usize, 4), sel.url_count);
}

test "selectInScope orders sources deterministically" {
    const allocator = std.testing.allocator;

    var manifest = try wpt_manifest.parseManifestBytes(allocator, test_manifest_json);
    defer manifest.deinit();

    var sel = try selectInScope(allocator, &manifest, &.{});
    defer sel.deinit();

    try std.testing.expectEqualStrings("dom/abort/AbortSignal.any.js", sel.sources[0]);
    try std.testing.expectEqualStrings("dom/nodes/Node-appendChild.html", sel.sources[1]);
    try std.testing.expectEqualStrings("html/dom/reflection.html", sel.sources[2]);
}

test "selectInScope honours directory filters" {
    const allocator = std.testing.allocator;

    var manifest = try wpt_manifest.parseManifestBytes(allocator, test_manifest_json);
    defer manifest.deinit();

    // Both "dom" and "dom/" should work, and neither should pull in domparsing.
    for ([_][]const u8{ "dom", "dom/" }) |filter| {
        var sel = try selectInScope(allocator, &manifest, &.{filter});
        defer sel.deinit();

        try std.testing.expectEqual(@as(usize, 2), sel.sources.len);
        try std.testing.expectEqual(@as(usize, 3), sel.url_count);
        try std.testing.expect(indexOfSource(sel, "html/dom/reflection.html") == null);
    }

    // A nested filter selects only below that path.
    var nested = try selectInScope(allocator, &manifest, &.{"html/dom"});
    defer nested.deinit();
    try std.testing.expectEqual(@as(usize, 1), nested.sources.len);
    try std.testing.expectEqualStrings("html/dom/reflection.html", nested.sources[0]);
}

test "selectInScope returns an empty selection when nothing matches" {
    const allocator = std.testing.allocator;

    var manifest = try wpt_manifest.parseManifestBytes(allocator, test_manifest_json);
    defer manifest.deinit();

    var sel = try selectInScope(allocator, &manifest, &.{"nonexistent"});
    defer sel.deinit();

    try std.testing.expectEqual(@as(usize, 0), sel.sources.len);
    try std.testing.expectEqual(@as(usize, 0), sel.url_count);
}

test "selectInScope over the real manifest reports a plausible denominator" {
    const allocator = std.testing.allocator;

    std.fs.cwd().access("tests/wpt/MANIFEST.json", .{}) catch return error.SkipZigTest;

    var manifest = try wpt_manifest.loadManifest(allocator, "tests/wpt");
    defer manifest.deinit();

    var sel = try selectInScope(allocator, &manifest, &.{});
    defer sel.deinit();

    // Floors rather than exact counts, because the vendored corpus grows.
    // The in-scope subset is a third of the ~36.5k testharness URLs, and must
    // be strictly smaller than the whole corpus - if these ever converge, the
    // scope filter has stopped filtering.
    try std.testing.expect(sel.url_count > 5_000);
    try std.testing.expect(sel.url_count < manifest.urlCount());
    try std.testing.expect(sel.sources.len > 3_000);

    // Every selected source must be in scope and must not be excluded.
    for (sel.sources) |s| {
        try std.testing.expect(!config.isExcluded(s));
    }
}

test "a worklist survives a write/read round trip" {
    const allocator = std.testing.allocator;

    const paths = [_][]const u8{
        "dom/abort/AbortSignal.any.js",
        "dom/nodes/Node-appendChild.html",
        "html/dom/reflection.html",
    };

    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    try writeWorklist(&out.writer, &paths);

    var wl = try parseWorklist(allocator, out.written());
    defer wl.deinit();

    try std.testing.expectEqual(paths.len, wl.paths.len);
    for (paths, wl.paths) |want, got| {
        try std.testing.expectEqualStrings(want, got);
    }
}

test "parseWorklist ignores blank lines and preserves order" {
    const allocator = std.testing.allocator;

    var wl = try parseWorklist(allocator,
        \\dom/b.html
        \\
        \\dom/a.html
        \\
        \\html/c.html
        \\
    );
    defer wl.deinit();

    // Order is the run order and therefore the index space the journal resumes
    // against - it must not be normalised or sorted here.
    try std.testing.expectEqual(@as(usize, 3), wl.paths.len);
    try std.testing.expectEqualStrings("dom/b.html", wl.paths[0]);
    try std.testing.expectEqualStrings("dom/a.html", wl.paths[1]);
    try std.testing.expectEqualStrings("html/c.html", wl.paths[2]);
}

test "an empty worklist parses to no paths" {
    const allocator = std.testing.allocator;

    var wl = try parseWorklist(allocator, "\n\n");
    defer wl.deinit();

    try std.testing.expectEqual(@as(usize, 0), wl.paths.len);
}

test "a selection round-trips through a worklist file" {
    const allocator = std.testing.allocator;

    var manifest = try wpt_manifest.parseManifestBytes(allocator, test_manifest_json);
    defer manifest.deinit();

    var sel = try selectInScope(allocator, &manifest, &.{});
    defer sel.deinit();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const path = try std.fs.path.join(allocator, &.{ dir_path, "worklist.txt" });
    defer allocator.free(path);

    {
        var file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        var buf: [4096]u8 = undefined;
        var file_writer = file.writer(&buf);
        try writeWorklist(&file_writer.interface, sel.sources);
        try file_writer.interface.flush();
    }

    var wl = try readWorklist(allocator, path);
    defer wl.deinit();

    try std.testing.expectEqual(sel.sources.len, wl.paths.len);
    for (sel.sources, wl.paths) |want, got| {
        try std.testing.expectEqualStrings(want, got);
    }
}

test "shards interleave rather than carve blocks" {
    // Contiguous blocks would put all of html/ - 62% of the corpus and the slow
    // end of it - in one shard, and the run would be as long as that shard.
    const allocator = std.testing.allocator;

    const s0 = try shardIndices(allocator, 10, 3, 0);
    defer allocator.free(s0);
    const s1 = try shardIndices(allocator, 10, 3, 1);
    defer allocator.free(s1);
    const s2 = try shardIndices(allocator, 10, 3, 2);
    defer allocator.free(s2);

    try std.testing.expectEqualSlices(usize, &.{ 0, 3, 6, 9 }, s0);
    try std.testing.expectEqualSlices(usize, &.{ 1, 4, 7 }, s1);
    try std.testing.expectEqualSlices(usize, &.{ 2, 5, 8 }, s2);
}

test "every entry lands in exactly one shard" {
    // A dropped index is a test that silently never runs; a duplicated one is a
    // test two browsers race on. Both would read as a scoreboard change.
    const allocator = std.testing.allocator;

    const total: usize = 97;
    const shard_count: usize = 8;

    var seen = try allocator.alloc(u8, total);
    defer allocator.free(seen);
    @memset(seen, 0);

    var shard: usize = 0;
    while (shard < shard_count) : (shard += 1) {
        const idx = try shardIndices(allocator, total, shard_count, shard);
        defer allocator.free(idx);
        for (idx) |i| {
            try std.testing.expect(i < total);
            seen[i] += 1;
        }
    }

    for (seen, 0..) |count, i| {
        if (count != 1) {
            std.debug.print("index {d} covered {d} times\n", .{ i, count });
            return error.TestUnexpectedResult;
        }
    }
}

test "shard sizes stay within one of each other" {
    const allocator = std.testing.allocator;

    const idx_a = try shardIndices(allocator, 10, 4, 0);
    defer allocator.free(idx_a);
    const idx_d = try shardIndices(allocator, 10, 4, 3);
    defer allocator.free(idx_d);

    try std.testing.expectEqual(@as(usize, 3), idx_a.len);
    try std.testing.expectEqual(@as(usize, 2), idx_d.len);
}

test "more shards than tests leaves the extras empty, not broken" {
    const allocator = std.testing.allocator;

    const busy = try shardIndices(allocator, 2, 5, 1);
    defer allocator.free(busy);
    try std.testing.expectEqualSlices(usize, &.{1}, busy);

    const idle = try shardIndices(allocator, 2, 5, 4);
    defer allocator.free(idle);
    try std.testing.expectEqual(@as(usize, 0), idle.len);
}

test "a requested shard count is honoured" {
    try std.testing.expectEqual(@as(usize, 4), resolveShardCount(4, 100, 8));
}

test "zero means auto, which means one shard per core" {
    try std.testing.expectEqual(@as(usize, 8), resolveShardCount(0, 100, 8));
}

test "shards never outnumber the tests they would run" {
    // Eight runners for three files would pay the ~9s process startup eight
    // times to save nothing; five of them would have no work at all.
    try std.testing.expectEqual(@as(usize, 3), resolveShardCount(0, 3, 8));
    try std.testing.expectEqual(@as(usize, 3), resolveShardCount(8, 3, 8));
}

test "an empty run needs no shards" {
    try std.testing.expectEqual(@as(usize, 0), resolveShardCount(8, 0, 8));
}

test "an unknown core count still yields a usable single shard" {
    try std.testing.expectEqual(@as(usize, 1), resolveShardCount(0, 100, 0));
}
