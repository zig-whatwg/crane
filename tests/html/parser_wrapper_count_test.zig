//! Parsing with scripting on makes no wrapper, and no V8 object, for a node
//! no script touches (tmp/plans/parser-holds-design.md 6.1, cost tests C1-C3).
//!
//! Row 10's persistent parser wrapped every node it created, traced it from
//! the Document, and kept it for the document's life: a live parse of 2,500
//! sections went from 335.9 to 594.0 ms. The parser now holds its nodes
//! natively (its stack of open elements, head and form pointers), as Blink's
//! HTMLConstructionSite and WebKit's HTMLElementStack do, and wraps only the
//! root of a tree script detaches from under it.
//!
//! The counts are the engine's own diagnostics (`wrapper_cache_entries`, every
//! realm's wrapper cache on this thread) and its heap statistics, read through
//! the protocol. These files share tests/html's process; each test runs its
//! Browser on a thread of its own.
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

fn wrapperEntries() !i64 {
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |counter| {
        if (std.mem.eql(u8, counter.name, "wrapper_cache_entries")) return counter.value;
    }
    return error.NoWrapperCounter;
}

/// A page of `count` paragraphs, each an element and a text node, and a
/// script at the end that touches none of them: scripting is on.
fn page(allocator: std.mem.Allocator, count: usize) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, "<!doctype html><html><head><title>count</title></head><body>");
    for (0..count) |_| try out.appendSlice(allocator, "<p>a</p>");
    try out.appendSlice(allocator, "<script>window.parsed = true;</script></body></html>");
    return out.toOwnedSlice(allocator);
}

const small = 1_000;
const large = 10_000;
/// Fewer wrappers than this between the two parses: a handful the page's own
/// objects can account for, never one per node.
const wrapper_slack: i64 = 8;

const Sample = struct { wrappers: i64, used_heap: usize };

fn measure(browser: *browser_mod.Browser) !Sample {
    try collect(browser);
    const agent = browser.getAgent() orelse return error.NoAgent;
    return .{ .wrappers = try wrapperEntries(), .used_heap = engine.heapStatistics(agent).used };
}

/// The page's parse of `count` paragraphs, checked to have reached its end:
/// a parse that stopped early would make no wrappers either.
fn expectParsed(context: *browser_mod.Context, count: usize, comptime query: []const u8) !void {
    const parsed = try context.evaluateScriptToString(query, testing.allocator);
    defer testing.allocator.free(parsed);
    var expected: [32]u8 = undefined;
    try testing.expectEqualStrings(try std.fmt.bufPrint(&expected, "{d} true", .{count}), parsed);
}

/// A navigation parse into a fresh Browser's fresh document (one Browser per
/// sample, so both start from the same objects).
fn navigationSample(count: usize) !Sample {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const context = browser.current_context orelse return error.NoPage;
    const markup = try page(testing.allocator, count);
    defer testing.allocator.free(markup);
    try context.loadHTML(markup, .{ .base_url = "about:blank" });
    try expectParsed(context, count, "document.getElementsByTagName('p').length + ' ' + window.parsed");
    return measure(browser);
}

fn writtenParse(browser: *browser_mod.Browser, count: usize) !Sample {
    const context = browser.current_context orelse return error.NoPage;
    var buffer: [256]u8 = undefined;
    const script = try std.fmt.bufPrint(&buffer,
        \\document.open();
        \\document.write('<!doctype html><body>' + '<p>a</p>'.repeat({d}) + '<script>window.parsed = true;<\/script>');
        \\document.close();
    , .{count});
    try context.runScript(script);
    try expectParsed(context, count, "document.getElementsByTagName('p').length + ' ' + window.parsed");
    return measure(browser);
}

fn noWrapperPerParsedNode() !void {
    _ = try navigationSample(small);
    const before = try navigationSample(small);
    const after = try navigationSample(large);
    if (after.wrappers - before.wrappers >= wrapper_slack) {
        std.debug.print("C1 navigation: {d} wrappers after {d} nodes, {d} after {d}\n", .{ before.wrappers, small * 2, after.wrappers, large * 2 });
        return error.WrapperPerParsedNode;
    }
}

test "C1: a navigation parse with scripting on makes no wrapper per parsed node" {
    try onFreshThread(noWrapperPerParsedNode);
}

fn noWrapperPerWrittenNode() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    _ = try writtenParse(browser, small);
    const before = try writtenParse(browser, small);
    const after = try writtenParse(browser, large);
    if (after.wrappers - before.wrappers >= wrapper_slack) {
        std.debug.print("C1 document.write: {d} wrappers after {d} nodes, {d} after {d}\n", .{ before.wrappers, small * 2, after.wrappers, large * 2 });
        return error.WrapperPerParsedNode;
    }
}

test "C1: a document.write parse makes no wrapper per parsed node" {
    try onFreshThread(noWrapperPerWrittenNode);
}

/// The V8 heap a parse leaves after a full collection, per node, may not
/// exceed this many bytes: a wrapper, its private parent edge and its entry
/// in the parent's children Set cost well over a hundred.
const heap_bytes_per_node_limit: usize = 16;

fn noHeapPerParsedNode() !void {
    _ = try navigationSample(small);
    const before = try navigationSample(small);
    const after = try navigationSample(large);
    const nodes = (large - small) * 2;
    const grown = after.used_heap -| before.used_heap;
    if (grown > nodes * heap_bytes_per_node_limit) {
        std.debug.print("C2: used heap {d} after {d} nodes, {d} after {d} ({d} B per node)\n", .{ before.used_heap, small * 2, after.used_heap, large * 2, grown / nodes });
        return error.HeapPerParsedNode;
    }
}

test "C2: a parse leaves no V8 heap per parsed node after a full collection" {
    try onFreshThread(noHeapPerParsedNode);
}

/// The same parse into a frame's document, by the frame document's own
/// parser in the frame's realm: the parent opens it and writes the markup,
/// and nothing in either realm touches the frame's nodes.
fn frameParse(browser: *browser_mod.Browser, count: usize) !Sample {
    const context = browser.current_context orelse return error.NoPage;
    var buffer: [512]u8 = undefined;
    const script = try std.fmt.bufPrint(&buffer,
        \\{{
        \\  document.body.replaceChildren();
        \\  const frame = document.body.appendChild(document.createElement('iframe'));
        \\  const frameDocument = frame.contentDocument;
        \\  frameDocument.open();
        \\  frameDocument.write('<!doctype html><body>' + '<p>a</p>'.repeat({d}) + '<script>window.parsed = true;<\/script>');
        \\  frameDocument.close();
        \\}}
    , .{count});
    try context.runScript(script);
    _ = try browser.runEventLoopBlocking(20);
    try expectParsed(context, count, "(() => { const f = document.querySelector('iframe'); return f.contentDocument.getElementsByTagName('p').length + ' ' + f.contentWindow.parsed; })()");
    return measure(browser);
}

fn noWrapperPerFrameNode() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://example.test/frame-parse" });
    _ = try frameParse(browser, small);
    const before = try frameParse(browser, small);
    const after = try frameParse(browser, large);
    if (after.wrappers - before.wrappers >= wrapper_slack) {
        std.debug.print("C3 frame: {d} wrappers after {d} nodes, {d} after {d}\n", .{ before.wrappers, small * 2, after.wrappers, large * 2 });
        return error.WrapperPerParsedNode;
    }
}

test "C3: a frame document's parse makes no wrapper per parsed node" {
    try onFreshThread(noWrapperPerFrameNode);
}
