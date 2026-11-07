//! BrowserConfig.poison_freed_state (lane perf2 batch 5): the WPT correctness
//! runner poisons its allocator's frees, and since Z7 a node's NodeBase and
//! InternalStates are its State block's - released at teardown, freed with
//! the block - so the Browser poisons them itself when asked: the State block
//! as the arena frees it, the NodeBase as its teardown releases it. Off by
//! default: a product build never pays it. The fills are
//! tests/runtime/perf2b5_arena_classes_test.zig's.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");

test "a Browser poisons freed state only when its config asks" {
    for ([_]bool{ false, true }) |poison| {
        const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "", .poison_freed_state = poison });
        defer browser.deinit();
        try testing.expectEqual(poison, browser.scope.arena.poison_freed);
        // A Debug build poisons released NodeBases either way (the unit
        // tests' poison-on-free); a release build only when asked.
        try testing.expectEqual(@import("builtin").mode == .Debug or poison, browser.scope.poisonsReleasedNodes());
    }
    // The default is off.
    const default_config: browser_mod.BrowserConfig = .{};
    try testing.expect(!default_config.poison_freed_state);
}
