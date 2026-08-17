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
