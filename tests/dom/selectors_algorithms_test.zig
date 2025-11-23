//! Tests migrated from src/dom/selectors.zig
//! Per WHATWG specifications

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
const runtime = @import("runtime");

const testing = std.testing;

test "selectors: scopeMatchSelectorsString with no matches" {
    const allocator = testing.allocator;

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    var doc = try dom.Document.init(allocator, ctx);
    defer doc.deinit();

    const root = try doc.call_createElement("div");
    defer {
        root.deinit();
        allocator.destroy(root);
    }

    // Query for "p" (but tree only has div)
    var matches = try dom.scopeMatchSelectorsString(allocator, "p", root);
    defer matches.deinit();

    try testing.expectEqual(@as(usize, 0), matches.size());
}
test "selectors: scopeMatchSelectorsString with syntax error" {
    const allocator = testing.allocator;

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    var doc = try dom.Document.init(allocator, ctx);
    defer doc.deinit();

    const root = try doc.call_createElement("div");
    defer {
        root.deinit();
        allocator.destroy(root);
    }

    // Invalid selector should return SyntaxError
    const result = dom.scopeMatchSelectorsString(allocator, ">>", root);
    try testing.expectError(error.SyntaxError, result);
}
