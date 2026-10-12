//! An isolate's teardown steps (isolate_lifecycle.zig) are a constant table,
//! known when the program is compiled (instances B2; design 4.6).
//!
//! They were a registry of 32 optional slots that `registerBuiltinHandlers`
//! filled at run time - from initializeEngine, and from any createAgent that
//! found it empty, on whatever Browser or worker thread made that agent -
//! while every agent's end on every thread read it unlocked. Nothing about
//! the steps differs between agents, so nothing is installed: the table is
//! the program's, in the order an agent's end needs.

const std = @import("std");
const testing = std.testing;
const lifecycle = @import("v8").isolate_lifecycle;

test "the teardown steps are a constant table, in the order they depend on each other" {
    // Comptime: a table written at run time would not compile here.
    const names = comptime blk: {
        var list: [lifecycle.handlers.len][]const u8 = undefined;
        for (lifecycle.handlers, 0..) |handler, i| list[i] = handler.name;
        break :blk list;
    };
    try testing.expectEqual(@as(usize, 3), names.len);
    // The realms' wrapper caches before the templates their wrappers were
    // made from (the registry's are the isolate's template storage's), the
    // templates before the allocator their storage came from.
    try testing.expectEqualStrings("context_manager", names[0]);
    try testing.expectEqualStrings("isolate_templates", names[1]);
    try testing.expectEqualStrings("isolate_allocator", names[2]);
}
