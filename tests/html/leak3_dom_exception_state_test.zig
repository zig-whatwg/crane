//! Lane leak3, item 1: a DOMException's internal state lives as long as its
//! object, not as long as its Browser.
//!
//! DOMException's impl made its InternalState with the Browser arena's
//! `create` and its name and message with the arena's `dupe` - the bump
//! path, which never frees - and its teardown freed neither ("the arena will
//! handle cleanup"; it is reset only when the Browser ends). So every
//! exception a page made - `new DOMException(...)`, every one the platform
//! threw, every structured clone of one - kept its state and both strings
//! until its Browser ended, and a page that made exceptions in a loop grew
//! without bound (lane alloc1's inventory, allocator-hardening design 10.1
//! item 1).
//!
//! The figure read is the Browser arena's `bytes_in_use`: what the live
//! platform objects' states hold. A collected exception gives its State
//! block back (runtime.gc), and its internal state with it; its strings are
//! the Browser allocator's (std.testing.allocator here, so a missed free is
//! a leak at the test's end).

const std = @import("std");
const testing = std.testing;
const helpers = @import("edges_node_holders_helpers.zig");

/// The bytes the Browser's live platform objects' states hold.
fn arenaInUse(page: helpers.Page) usize {
    return page.browser.scope.arena.stats().bytes_in_use;
}

/// One round: exceptions of every making, each dropped at once - script's,
/// the platform's (a thrown DOMException), a structured clone's (DOMException
/// is [Serializable]) - each with a message long enough that a kept one shows.
const round =
    \\(() => {
    \\  const message = 'm'.repeat(1024);
    \\  for (let i = 0; i < 300; ++i) {
    \\    const made = new DOMException(message, 'NotFoundError');
    \\    if (made.code !== 8 || made.message.length !== 1024) globalThis.failed = 'constructed: ' + made.name + ' ' + made.code;
    \\    const cloned = structuredClone(made);
    \\    if (cloned.name !== 'NotFoundError' || cloned.message !== message || cloned.code !== 8) globalThis.failed = 'cloned: ' + cloned.name + ' ' + cloned.code;
    \\    try { document.createElement('1 not a name'); globalThis.failed = 'no throw'; } catch (e) {
    \\      if (!(e instanceof DOMException) || e.name !== 'InvalidCharacterError' || e.code !== 5) globalThis.failed = 'thrown: ' + e;
    \\    }
    \\  }
    \\})();
;

fn collect(page: helpers.Page) !void {
    try page.run("TestUtils.gc(); TestUtils.gc();");
    try page.settle();
    try page.run("TestUtils.gc();");
}

fn expectNoFailure(page: helpers.Page) !void {
    const failed = try page.evaluate("String(globalThis.failed || '')");
    defer testing.allocator.free(failed);
    if (failed.len != 0) {
        std.debug.print("page check failed: {s}\n", .{failed});
        return error.PageCheckFailed;
    }
}

fn exceptionsGiveTheirStateBack() !void {
    const page = try helpers.Page.open();
    defer page.close();

    // A first round settles what the page makes once (the bindings' own
    // objects, the arena's first blocks of each class).
    try page.run(round);
    try collect(page);
    try expectNoFailure(page);
    const settled = arenaInUse(page);

    // Four more rounds: 3,600 exceptions, each with a 1 KiB message. Kept,
    // they would hold over 4 MB of the arena (each made one's state and two
    // strings, its clone's the same); given back, the figure stays where the
    // first round left it.
    for (0..4) |_| {
        try page.run(round);
        try collect(page);
    }
    try expectNoFailure(page);
    const after = arenaInUse(page);
    const grown = after -| settled;
    if (grown > 64 * 1024) {
        std.debug.print("the Browser arena grew {d} bytes over 3,600 collected DOMExceptions ({d} -> {d})\n", .{ grown, settled, after });
        return error.ExceptionStateKept;
    }
}

test "collected DOMExceptions give their internal state and strings back to the Browser" {
    try helpers.onFreshThread(exceptionsGiveTheirStateBack);
}
