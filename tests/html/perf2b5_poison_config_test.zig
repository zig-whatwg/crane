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

test "a Browser poisons freed state when its config asks, and in a Debug build either way" {
    for ([_]bool{ false, true }) |poison| {
        const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "", .poison_freed_state = poison });
        defer browser.deinit();
        // A Debug build poisons freed state blocks and released NodeBases
        // either way (the unit tests' poison-on-free; the blocks since lane
        // uaf1, so a read of a FREED node block finds the poison there); a
        // release build only when asked. The config turns it on, never off.
        const debug = @import("builtin").mode == .debug;
        try testing.expectEqual(debug or poison, browser.scope.arena.poison_freed);
        try testing.expectEqual(debug or poison, browser.scope.poisonsReleasedNodes());
        // The arena's quarantine - a freed block kept out of reuse - is the
        // config's alone: no default turns it on.
        try testing.expectEqual(poison, browser.scope.arena.quarantine_freed);
    }
    // The default is off.
    const default_config: browser_mod.BrowserConfig = .{};
    try testing.expect(!default_config.poison_freed_state);
}
