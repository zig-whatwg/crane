//! Holding nodes costs no wrapper per node (lane nodeholds,
//! tmp/plans/lane-nodeholds-handoff.md, "Cost model").
//!
//! Lane edges first kept a static list's and a record's nodes alive by
//! tracing each from the holder's wrapper, which wraps every node at the
//! moment the holder is filled - and tree edges then keep those wrappers for
//! the document's life: querySelectorAll('*').length over 10,000 elements went
//! 8.7x, a parse under a subtree observer 2.55x
//! (docs/lessons/architecture-tracing-a-holders-nodes-makes-a-wrapper-per-node.md).
//! Holds are native; a wrapper is made only for the root of a tree that leaves
//! the document while something holds a node in it.
//!
//! The counts are the engine's own diagnostics (`wrapper_cache_entries`)
//! read through the protocol, after two collections.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn collect(browser: *browser_mod.Browser) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const realm = browser.getRealm() orelse return error.NoRealm;
    const agent = browser.getAgent() orelse return error.NoAgent;
    try engine.runInRealm(realm, Collect.steps, agent);
    try engine.runInRealm(realm, Collect.steps, agent);
}

fn wrapperEntries(browser: *browser_mod.Browser) !i64 {
    try collect(browser);
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |counter| {
        if (std.mem.eql(u8, counter.name, "wrapper_cache_entries")) return counter.value;
    }
    return error.NoWrapperCounter;
}

const small = 1_000;
const large = 10_000;
/// Fewer wrappers than this between the two sizes: the page's own objects,
/// never one per node.
const wrapper_slack: i64 = 8;

fn openPage(markup: []const u8) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(markup, .{ .base_url = "about:blank" });
    return browser;
}

fn expectScript(browser: *browser_mod.Browser, script: []const u8, expected: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    const result = try page.evaluateScriptToString(script, testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings(expected, result);
}

/// Wrapper entries after `querySelectorAll('*')` over `count` parsed
/// elements, the list kept by script and its length read.
fn querySample(count: usize) !i64 {
    var markup: std.ArrayListUnmanaged(u8) = .empty;
    defer markup.deinit(testing.allocator);
    try markup.appendSlice(testing.allocator, "<!doctype html><body><div id=root>");
    for (0..count) |_| try markup.appendSlice(testing.allocator, "<p></p>");
    try markup.appendSlice(testing.allocator, "</div></body>");
    const browser = try openPage(markup.items);
    defer browser.deinit();
    var buffer: [64]u8 = undefined;
    const expected = try std.fmt.bufPrint(&buffer, "{d}", .{count});
    try expectScript(browser, "globalThis.kept = document.getElementById('root').querySelectorAll('p'); String(kept.length)", expected);
    return wrapperEntries(browser);
}

fn noWrapperPerQueriedNode() !void {
    _ = try querySample(small);
    const before = try querySample(small);
    const after = try querySample(large);
    if (after - before >= wrapper_slack) {
        std.debug.print("querySelectorAll: {d} wrappers after {d} matches, {d} after {d}\n", .{ before, small, after, large });
        return error.WrapperPerQueriedNode;
    }
}

test "querySelectorAll's static list holds its nodes without a wrapper per node" {
    try onFreshThread(noWrapperPerQueriedNode);
}

/// Wrapper entries after a parse of `count` paragraphs observed by a
/// subtree MutationObserver from the first script; the records are delivered
/// to a callback that reads nothing.
fn observedParseSample(count: usize) !i64 {
    var markup: std.ArrayListUnmanaged(u8) = .empty;
    defer markup.deinit(testing.allocator);
    try markup.appendSlice(testing.allocator,
        \\<!doctype html><html><head><script>
        \\globalThis.seen = 0;
        \\new MutationObserver(records => { seen += records.length; }).observe(document.documentElement, { childList: true, subtree: true });
        \\</script></head><body>
    );
    for (0..count) |_| try markup.appendSlice(testing.allocator, "<p>a</p>");
    try markup.appendSlice(testing.allocator, "<script>window.parsed = true;</script></body></html>");
    const browser = try openPage(markup.items);
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    _ = try browser.runEventLoopBlocking(20);
    const result = try page.evaluateScriptToString("String(seen > 0 && window.parsed)", testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("true", result);
    return wrapperEntries(browser);
}

fn noWrapperPerObservedNode() !void {
    _ = try observedParseSample(small);
    const before = try observedParseSample(small);
    const after = try observedParseSample(large);
    if (after - before >= wrapper_slack) {
        std.debug.print("observed parse: {d} wrappers after {d} paragraphs, {d} after {d}\n", .{ before, small, after, large });
        return error.WrapperPerObservedNode;
    }
}

test "a parse under a subtree MutationObserver makes no wrapper per inserted node" {
    try onFreshThread(noWrapperPerObservedNode);
}

/// Wrapper entries after removing, and letting go of, a subtree whose
/// `count` paragraphs a kept static list holds: the list rescues the subtree's
/// root - one wrapper - not each node.
fn removedHeldSubtreeSample(count: usize) !i64 {
    var markup: std.ArrayListUnmanaged(u8) = .empty;
    defer markup.deinit(testing.allocator);
    try markup.appendSlice(testing.allocator, "<!doctype html><body><div id=root><section>");
    for (0..count) |_| try markup.appendSlice(testing.allocator, "<p></p>");
    try markup.appendSlice(testing.allocator, "</section></div></body>");
    const browser = try openPage(markup.items);
    defer browser.deinit();
    var buffer: [64]u8 = undefined;
    const expected = try std.fmt.bufPrint(&buffer, "{d}", .{count});
    try expectScript(browser,
        \\globalThis.kept = document.getElementById('root').querySelectorAll('p');
        \\document.getElementById('root').innerHTML = '';
        \\String(kept.length)
    , expected);
    return wrapperEntries(browser);
}

fn oneWrapperPerRescuedTree() !void {
    _ = try removedHeldSubtreeSample(small);
    const before = try removedHeldSubtreeSample(small);
    const after = try removedHeldSubtreeSample(large);
    if (after - before >= wrapper_slack) {
        std.debug.print("rescue: {d} wrappers after {d} held nodes, {d} after {d}\n", .{ before, small, after, large });
        return error.WrapperPerRescuedNode;
    }
}

test "removing a subtree a static list holds rescues its root alone" {
    try onFreshThread(oneWrapperPerRescuedTree);
}
