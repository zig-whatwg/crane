//! The Phase 5 ownership instrument's counters (isolate_ownership.zig) are
//! counted on every agent's thread: a check from a worker's thread and one from
//! the page's can land at once, and a plain `+= 1` loses one of them - short
//! exactly when threads mix, which is what the instrument exists to catch.
//! They are process-wide atomics (a `// process-wide:` key of
//! lint-global-state), read by the WPT runner as per-file deltas.
const std = @import("std");
const testing = std.testing;
const v8 = @import("v8");

const ownership = v8.isolate_ownership;

const per_thread = 200_000;
const thread_count = 4;

fn countMany() void {
    for (0..per_thread) |i| ownership.countCheck(i % 2 == 0);
}

test "ownership checks and violations counted on many threads at once are all counted" {
    const checks_before = ownership.checks();
    const violations_before = ownership.violations();
    var threads: [thread_count]std.Thread = undefined;
    for (&threads) |*thread| thread.* = try std.Thread.spawn(.{}, countMany, .{});
    for (threads) |thread| thread.join();
    const checks_added = ownership.checks() - checks_before;
    const violations_added = ownership.violations() - violations_before;
    // Give back what the test took (the counters are the process's): only
    // its own counts, whatever another thread added meanwhile.
    ownership.uncountForTest(thread_count * per_thread, thread_count * per_thread / 2);
    try testing.expect(checks_added >= thread_count * per_thread);
    try testing.expect(violations_added >= thread_count * per_thread / 2);
}
