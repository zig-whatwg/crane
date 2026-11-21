//! The Zig that builds Crane (AGENTS.md "Building", "The toolchain is Zig
//! 0.17, pinned"; .claude/rules/build-and-toolchain.md).
//!
//! build.zig's configure refuses every other Zig by name through `refusal`.
//! build.zig.zon's minimum_zig_version is not enforced, and an older Zig
//! fails on the tree's 0.17 code without saying why: GitHub CI on 0.16.0 (run
//! 44942720026, 2026-11-21) printed eight std.Build API errors and nothing
//! that named the toolchain. So this file is std-only and written in what
//! 0.16 also compiles, so that a refused Zig still reaches the message, and
//! `zig build test` pins it (tools-zig_toolchain).

const std = @import("std");

/// `zig version` of the pinned build: the 0.17.x branch at 77c319a0f00a (the
/// user, 2026-10-28), until 0.17.1 ships.
pub const pinned_version = "0.17.1-dev+77c319a0f0";
/// Where the pinned build lives, on the Mac and on every pool host.
pub const pinned_path = "~/crane-toolchains/zig-" ++ pinned_version ++ "/";

const use_pinned = "use the pinned 0.17.x-branch build " ++ pinned_version ++ " (77c319a0f00a, " ++ pinned_path ++ "), or 0.17.1 once it ships";

/// Why Zig `version` cannot build Crane, or null when it can.
pub fn refusal(version: std.SemanticVersion) ?[]const u8 {
    // Older than 0.17.0 (a 0.17.0-dev pre-release included): the tree is 0.17
    // code since the port (2c684d65b7c), and 0.16 was retired on 2026-11-21
    // (roadmap zig-017, lane z17f).
    if (version.order(.{ .major = 0, .minor = 17, .patch = 0 }) == .lt)
        return "Crane builds with Zig 0.17 only, and 0.16 was retired (2026-11-21, roadmap zig-017): " ++ use_pinned ++ ". The errors printed beside this one are this older Zig failing on 0.17 code.";
    // 0.17.0 itself cannot build Crane's mobile Apple target (ziglang/zig#37061,
    // fixed for 0.17.1), and its checkAllAllocationFailures lets resizes reach
    // SafeAllocator, so tests fail with NondeterministicMemoryUsage
    // (ziglang/zig#37142). (This file names no OS or target: it is one of the
    // files tools/lint_build_neutral.zig holds neutral.)
    if (version.major == 0 and version.minor == 17 and version.patch == 0)
        return "Crane does not build with Zig 0.17.0 (ziglang/zig#37061: the mobile Apple target; #37142: checkAllAllocationFailures resizes): " ++ use_pinned;
    return null;
}

const testing = std.testing;

fn parse(text: []const u8) !std.SemanticVersion {
    return std.SemanticVersion.parse(text);
}

test "Zig 0.16 is refused, naming the pinned build" {
    const why = refusal(try parse("0.16.0")) orelse return error.TestExpectedRefusal;
    try testing.expect(std.mem.indexOf(u8, why, pinned_version) != null);
    try testing.expect(std.mem.indexOf(u8, why, "0.16 was retired") != null);
}

test "every Zig older than 0.17 is refused" {
    for ([_][]const u8{ "0.15.2", "0.16.1-dev.42+abcdef012", "0.17.0-dev.203+073889523" }) |text| {
        const why = refusal(try parse(text)) orelse return error.TestExpectedRefusal;
        try testing.expect(std.mem.indexOf(u8, why, pinned_version) != null);
    }
}

test "Zig 0.17.0 is refused for #37061 and #37142" {
    const why = refusal(try parse("0.17.0")) orelse return error.TestExpectedRefusal;
    try testing.expect(std.mem.indexOf(u8, why, "#37061") != null);
    try testing.expect(std.mem.indexOf(u8, why, "#37142") != null);
    try testing.expect(std.mem.indexOf(u8, why, pinned_version) != null);
}

test "the pinned build and 0.17.1 build Crane" {
    try testing.expectEqual(@as(?[]const u8, null), refusal(try parse(pinned_version)));
    try testing.expectEqual(@as(?[]const u8, null), refusal(try parse("0.17.1")));
    try testing.expectEqual(@as(?[]const u8, null), refusal(try parse("0.17.2-dev.7+0123456789")));
}

test "the pinned path names the pinned version" {
    try testing.expectEqualStrings("~/crane-toolchains/zig-0.17.1-dev+77c319a0f0/", pinned_path);
}
