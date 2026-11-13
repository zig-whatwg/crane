//! The V8 adapter evaluates a script of its OWN in the listed places and
//! nowhere else - and each of those is a named defect with an owner. The
//! list only gets shorter; empty is the goal.
//!
//! Lane v8up b8 (2026-11-13). `v8_Script_Compile` is the adapter's call for a
//! script it wrote itself: no origin, no host-defined options. Two things are
//! wrong with reaching for it where a value is needed again and again:
//!
//! - It costs a compile every time. Crane starts V8 15.7 without its
//!   compilation cache (build.zig: the cache answers `new Function()` with
//!   another script's base URL and nonce), so an internal script that used to
//!   be a cache hit is parsed and compiled on each call.
//!   `engine.createAsyncIterator` did that to reach %AsyncIteratorPrototype%:
//!   21% of `new ReadableStream(...).values()`, and gc_bench's stream-values
//!   row at 1.128 of main's time after the port (protocol_support.zig's
//!   asyncIteratorPrototype, removed with this test, and realm_v8.zig's
//!   once-per-realm script with it: both ask V8 for the intrinsic by name
//!   now, ffi.v8_Context_AsyncIteratorPrototype).
//! - It runs in the PAGE's realm with the page's globals. A script that says
//!   `new Date()` gets whatever the page made of Date - intl_binding.zig's
//!   getLocalTimezoneOffset did, for Intl's local time, and left the list
//!   when it took the platform's (tests/v8/v8up_intl_local_time_test.zig).
//!   A browser reaches an
//!   intrinsic by name (v8::Intrinsic, include/v8-template.h; Blink's
//!   SetupIDLIteratorTemplate, Chromium 157.0.8103.50 third_party/blink/
//!   renderer/bindings/core/v8/generated_code_helper.cc:166-206), never by
//!   evaluating script.
//!
//! This check reads every Zig file of src/runtime/engines/v8/ and fails on a
//! call the list does not have, and on a listed file whose count changed -
//! so a fixed site leaves the list in the same change.

const std = @import("std");

const adapter_dir = "src/runtime/engines/v8";

/// The adapter's own script evaluations: the file, how many call sites it
/// has, and whose defect each is.
const listed = [_]struct { file: []const u8, sites: usize, why: []const u8 }{
    .{ .file = "interface.zig", .sites = 1, .why = "DEFECT, owner lane wr1 (queued by the integrator, 2026-11-13): an iterable's entries fallback compiles a forEach-collecting helper on every call" },
};

/// How many times `source` calls v8_Script_Compile - outside a comment, a
/// multiline string and its `extern fn` declaration.
fn compileSites(source: []const u8) usize {
    // Spelled in two pieces, so this file has none of its own.
    const needle = "v8_Script_" ++ "Compile(";
    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trimStart(u8, line, " \t");
        if (std.mem.startsWith(u8, trimmed, "\\\\")) continue;
        if (std.mem.indexOf(u8, line, "extern fn") != null) continue;
        var rest = line;
        if (std.mem.indexOf(u8, rest, "//")) |comment| rest = rest[0..comment];
        var from: usize = 0;
        while (std.mem.indexOfPos(u8, rest, from, needle)) |at| {
            count += 1;
            from = at + needle.len;
        }
    }
    return count;
}

test "the script-compile check counts calls, never a comment, a string or the declaration" {
    const call = "v8_Script_" ++ "Compile(";
    try std.testing.expectEqual(@as(usize, 3), compileSites(
        "    const script = ffi." ++ call ++ "context, text) orelse return;\n" ++
            "    // " ++ call ++ "context, text) in a comment\n" ++
            "    \\\\" ++ call ++ "x) in a string\n" ++
            "pub extern fn " ++ call ++ "context: *Context, source: *String) ?*Script;\n" ++
            "    a(v8." ++ call ++ "c, s)); b(v8." ++ call ++ "c, t)); // and " ++ call ++ "\n",
    ));
    try std.testing.expectEqual(@as(usize, 0), compileSites("const x = 1;\n"));
}

test "the V8 adapter evaluates a script of its own only where the list says, and each listed count is exact" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var dir = try std.Io.Dir.cwd().openDir(io, adapter_dir, .{ .iterate = true });
    defer dir.close(io);

    var seen: [listed.len]bool = @splat(false);
    var wrong: usize = 0;
    var files: usize = 0;
    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".zig")) continue;
        files += 1;
        const source = try dir.readFileAlloc(io, entry.name, gpa, .limited(16 * 1024 * 1024));
        defer gpa.free(source);
        const sites = compileSites(source);
        var expected: usize = 0;
        for (listed, 0..) |l, i| {
            if (!std.mem.eql(u8, l.file, entry.name)) continue;
            expected = l.sites;
            seen[i] = true;
        }
        if (sites == expected) continue;
        wrong += 1;
        if (expected == 0) {
            std.debug.print("{s}/{s}: {d} script evaluation(s) of the adapter's own, and the file is not listed. Reach the value the way a browser does (an intrinsic by name, a per-realm record), not by evaluating script in the page's realm.\n", .{ adapter_dir, entry.name, sites });
        } else {
            std.debug.print("{s}/{s}: {d} script evaluation(s), listed with {d}. A fixed site leaves the list in the same change; a new one is not added to it.\n", .{ adapter_dir, entry.name, sites, expected });
        }
    }
    for (listed, 0..) |l, i| {
        if (seen[i]) continue;
        wrong += 1;
        std.debug.print("{s}/{s} is listed and is not there: take it off the list.\n", .{ adapter_dir, l.file });
    }
    // The directory was read: an empty walk would pass everything.
    try std.testing.expect(files > 40);
    try std.testing.expectEqual(@as(usize, 0), wrong);
}
