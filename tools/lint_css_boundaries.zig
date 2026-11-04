//! lint-css: the CSS module's two import boundaries, checked outside the
//! compiler.
//!
//! Two cold Typed OM entries must stay off CSS's parsing and computation
//! paths, and each pinned that with a `comptime {}` block that @embedFile'd
//! the files it guards and searched them with std.mem.indexOf - 12.7 s and
//! 7.4 s of single-threaded Sema in every test binary that reached src/css
//! (lane onebin2's time report, 2026-11-04). The same rules - the same files,
//! the same patterns, the same messages - run here, once per `zig build test`
//! (lane compiletime1):
//!
//! - Q61 (src/css/animation_values.zig): the native animation-list
//!   concatenation entry (`List.concat(`, `List.slice(`) is not a
//!   parser/computation shortcut, so properties.zig, cascade.zig and
//!   computed_style.zig never call it.
//! - Q59 (src/css/typed_om/text_keywords.zig): the Typed OM canonical-text
//!   inspection is never imported by the CSS parsing/computation files.
//!
//! A rule's guarded file that is missing fails too: the comptime block's
//! @embedFile did.
//!
//!   zig build lint-css      (part of `zig build test`)

const std = @import("std");
const stdout_stream = @import("stdout_stream.zig");

pub const Rule = struct {
    /// The file whose boundary this is, named in the failure.
    owner: []const u8,
    /// The files that must not contain any of `patterns`, from the repo root.
    files: []const []const u8,
    patterns: []const []const u8,
    message: []const u8,
};

pub const rules = [_]Rule{
    .{
        .owner = "src/css/animation_values.zig",
        .files = &.{ "src/css/properties.zig", "src/css/cascade.zig", "src/css/computed_style.zig" },
        .patterns = &.{ "List.concat(", "List.slice(" },
        .message = "native animation-list concatenation is a cold Typed OM entry",
    },
    .{
        .owner = "src/css/typed_om/text_keywords.zig",
        .files = &.{
            "src/css/cascade.zig",
            "src/css/computed_style.zig",
            "src/css/properties.zig",
            "src/css/font_variants.zig",
            "src/css/font_shorthand.zig",
            "src/css/font_settings.zig",
            "src/css/decoration_values.zig",
        },
        .patterns = &.{ "typed_om/text_keywords.zig", "typed_om.text_keywords" },
        .message = "Typed OM canonical-text inspection must remain off the CSS parsing/computation path",
    },
};

/// The first of `rule.patterns` that `source` contains, or null.
pub fn breach(rule: Rule, source: []const u8) ?[]const u8 {
    for (rule.patterns) |pattern| {
        if (std.mem.indexOf(u8, source, pattern) != null) return pattern;
    }
    return null;
}

/// The 1-based line of `source` at byte `offset`.
fn lineOf(source: []const u8, offset: usize) usize {
    return std.mem.count(u8, source[0..offset], "\n") + 1;
}

/// Check every rule against the files under `dir`; print each breach and
/// each missing file to `out`. The number of failures.
pub fn check(io: std.Io, gpa: std.mem.Allocator, dir: std.Io.Dir, out: *std.Io.Writer, rule_set: []const Rule) !usize {
    var failures: usize = 0;
    for (rule_set) |rule| {
        for (rule.files) |path| {
            const source = dir.readFileAlloc(io, path, gpa, .limited(64 << 20)) catch |err| switch (err) {
                error.FileNotFound => {
                    try out.print("{s}: error: missing - {s} guards it ({s})\n", .{ path, rule.owner, rule.message });
                    failures += 1;
                    continue;
                },
                else => return err,
            };
            defer gpa.free(source);
            if (breach(rule, source)) |pattern| {
                const at = std.mem.indexOf(u8, source, pattern).?;
                try out.print("{s}:{d}: error: {s} (found \"{s}\"; the boundary of {s})\n", .{ path, lineOf(source, at), rule.message, pattern, rule.owner });
                failures += 1;
            }
        }
    }
    return failures;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = stdout_stream.writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    const failures = try check(io, init.gpa, std.Io.Dir.cwd(), out, &rules);
    if (failures > 0) {
        try out.print("\nlint-css: {d} breach(es) of the CSS boundaries above (tools/lint_css_boundaries.zig).\n", .{failures});
        try out.flush();
        std.process.exit(1);
    }
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "the two rules are the comptime blocks' own: files, patterns and messages" {
    try testing.expectEqual(@as(usize, 2), rules.len);
    try testing.expectEqualStrings("native animation-list concatenation is a cold Typed OM entry", rules[0].message);
    try testing.expectEqual(@as(usize, 3), rules[0].files.len);
    try testing.expectEqual(@as(usize, 2), rules[0].patterns.len);
    try testing.expectEqualStrings("Typed OM canonical-text inspection must remain off the CSS parsing/computation path", rules[1].message);
    try testing.expectEqual(@as(usize, 7), rules[1].files.len);
    try testing.expectEqualStrings("typed_om.text_keywords", rules[1].patterns[1]);
}

test "a source that calls the concatenation entry breaches Q61, and a clean one does not" {
    const fixture =
        \\const values = @import("animation_values.zig");
        \\fn shortcut(a: values.List, b: values.List) void {
        \\    _ = values.List.concat(a, b);
        \\}
    ;
    try testing.expectEqualStrings("List.concat(", breach(rules[0], fixture) orelse return error.TestExpectedBreach);
    try testing.expectEqualStrings("List.slice(", breach(rules[0], "x = List.slice(list, 1);") orelse return error.TestExpectedBreach);
    try testing.expectEqual(@as(?[]const u8, null), breach(rules[0], "const list = List.init(); // List.concat is not called"));
}

test "a source that imports the text-keyword inspection breaches Q59 either way it is named" {
    try testing.expect(breach(rules[1], "const tk = @import(\"typed_om/text_keywords.zig\");") != null);
    try testing.expect(breach(rules[1], "const k = css.typed_om.text_keywords.classify;") != null);
    try testing.expectEqual(@as(?[]const u8, null), breach(rules[1], "const tok = @import(\"tokenizer.zig\");"));
}

test "check reports each breach with its line and each missing file, and counts them" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = testing.io;
    try tmp.dir.createDirPath(io, "src/css");
    try tmp.dir.writeFile(io, .{ .sub_path = "src/css/properties.zig", .data = "const a = 1;\nconst b = List.concat(x, y);\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "src/css/cascade.zig", .data = "const clean = true;\n" });
    // computed_style.zig is missing.
    var buf: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    const failures = try check(io, testing.allocator, tmp.dir, &w, rules[0..1]);
    try testing.expectEqual(@as(usize, 2), failures);
    const text = w.buffered();
    try testing.expect(std.mem.indexOf(u8, text, "src/css/properties.zig:2: error: native animation-list concatenation is a cold Typed OM entry (found \"List.concat(\"") != null);
    try testing.expect(std.mem.indexOf(u8, text, "src/css/computed_style.zig: error: missing") != null);
    try testing.expect(std.mem.indexOf(u8, text, "cascade.zig") == null);
}
