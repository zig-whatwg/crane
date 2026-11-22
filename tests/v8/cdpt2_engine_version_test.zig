//! engine.engineVersion on V8 (lane cdpt2; CDP part 1 gap 7): the linked
//! V8's own version string - v8::V8::GetVersion, V8_VERSION_STRING - which
//! CDP's Browser.getVersion jsVersion and /json/version's V8-Version report
//! (Chrome: content/browser/devtools/protocol/browser_handler.cc,
//! devtools_http_handler.cc). Never the engine's name, never a string Crane
//! wrote: "major.minor.build.patch", numbers only, the same answer before and
//! after the engine starts and on any thread.
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const engine = @import("engine");
const test_process = @import("test_process.zig");

/// V8's version form: four dot-separated decimal numbers (v8-version.h's
/// V8_MAJOR_VERSION.V8_MINOR_VERSION.V8_BUILD_NUMBER.V8_PATCH_LEVEL; a
/// candidate build may add " (candidate)", which a release has not).
fn isV8Version(text: []const u8) bool {
    const release = if (std.mem.indexOfScalar(u8, text, ' ')) |space| text[0..space] else text;
    var parts: usize = 0;
    var it = std.mem.splitScalar(u8, release, '.');
    while (it.next()) |part| {
        if (part.len == 0) return false;
        for (part) |c| if (!std.ascii.isDigit(c)) return false;
        parts += 1;
    }
    return parts == 4;
}

test "engine.engineVersion is V8's own major.minor.build.patch, the same before and after the start and on another thread" {
    const before = try engine.engineVersion();
    try testing.expect(isV8Version(before));
    try testing.expect(!std.mem.eql(u8, before, engine.name));
    test_process.start();
    const after = try engine.engineVersion();
    try testing.expectEqualStrings(before, after);

    const Other = struct {
        seen: []const u8 = "",
        fn run(self: *@This()) void {
            self.seen = engine.engineVersion() catch "";
        }
    };
    var other: Other = .{};
    const thread = try std.Thread.spawn(.{}, Other.run, .{&other});
    thread.join();
    try testing.expectEqualStrings(before, other.seen);
}

test "isV8Version: V8's form only" {
    try testing.expect(isV8Version("13.1.203.24"));
    try testing.expect(isV8Version("15.7.1.0 (candidate)"));
    try testing.expect(!isV8Version("V8"));
    try testing.expect(!isV8Version("13.1.203"));
    try testing.expect(!isV8Version("13.1.x.24"));
}
