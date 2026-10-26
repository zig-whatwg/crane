//! The argument-grammar phase (lane vars1, Codex row 122 Q22): a
//! function's arguments() is called at parse time from the literal tokens
//! (.parse) and again at computed-value time after early invocation
//! (.substituted), and knows which - attr() rejects a literally malformed
//! header only at parse time. A recording row stands in for random-item().
const std = @import("std");
const css = @import("css");

const testing = std.testing;
const Allocator = std.mem.Allocator;
const substitution = css.substitution;

// The phases the recording row saw (test-only state).
var seen: [8]substitution.Phase = undefined;
var seen_count: usize = 0;

fn recordArguments(allocator: Allocator, contents: []const substitution.Node, phase: substitution.Phase) substitution.Error![]const []const substitution.Node {
    seen[seen_count] = phase;
    seen_count += 1;
    const out = try allocator.alloc([]const substitution.Node, 1);
    out[0] = substitution.trim(contents);
    return out;
}

fn recordReplace(_: *substitution.Resolver, _: substitution.Node, args: []const []const substitution.Node) substitution.Error!substitution.Replacement {
    return .{ .nodes = args[0] };
}

const table = [_]substitution.Function{
    substitution.function(.@"var"),
    substitution.function(.env),
    .{ .id = .random_item, .arguments = recordArguments, .replace = recordReplace },
};

fn customValue(_: *anyopaque, name: []const u8) substitution.Error!?substitution.Computed {
    if (std.mem.eql(u8, name, "--x")) return .{ .text = "a, b" };
    return null;
}

fn run(text: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const nodes = try substitution.parseWith(arena.allocator(), text, substitution.max_nodes, &table);
    var marker: u8 = 0;
    var resolver: substitution.Resolver = .{ .allocator = arena.allocator(), .host = .{ .context = &marker, .custom_value = customValue }, .property = "width", .table = &table };
    const result = try resolver.substituteWithTaint(nodes, false);
    return testing.allocator.dupe(u8, (try substitution.render(arena.allocator(), result.nodes)).text);
}

test "a plain call is split at parse time, then again after early invocation" {
    seen_count = 0;
    const text = try run("random-item(a b)");
    defer testing.allocator.free(text);
    try testing.expectEqualStrings("a b", text);
    try testing.expectEqual(@as(usize, 2), seen_count);
    try testing.expectEqual(substitution.Phase.parse, seen[0]);
    try testing.expectEqual(substitution.Phase.substituted, seen[1]);
}

test "a spread call is split only after early invocation, with what it brought in" {
    seen_count = 0;
    const text = try run("random-item(...var(--x))");
    defer testing.allocator.free(text);
    try testing.expectEqualStrings("a, b", text);
    try testing.expectEqual(@as(usize, 1), seen_count);
    try testing.expectEqual(substitution.Phase.substituted, seen[0]);
}
