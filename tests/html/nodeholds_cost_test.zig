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

fn slabAllocated() !usize {
    const slab = try @import("runtime").SlabAllocator.tryGet();
    return slab.stats().total_allocated;
}

/// An observed mutation whose record script never reads makes no NodeList:
/// the record holds its nodes itself and makes its lists on first read
/// (Blink's RecordWithEmptyNodeLists, generalized). The carrier lists every
/// tree mutation used to build - two per record batch, never freed unless
/// script read them - are gone, and nodes of a document with a window are
/// held without a rescue (no wrapper).
fn unreadRecordsMakeNoListAndNoRescue() !void {
    const browser = try openPage("<!doctype html><body><div id=src></div><div id=dst></div><div id=dst2></div></body>");
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    try page.runScript(
        \\globalThis.src = document.getElementById('src');
        \\globalThis.dst = document.getElementById('dst');
        \\src.innerHTML = '<i></i>'.repeat(200);
        \\globalThis.nodes = [...src.childNodes];
        \\globalThis.mo = new MutationObserver(() => {});
        \\mo.observe(dst, { childList: true });
        \\mo.observe(document.getElementById('dst2'), { childList: true });
    );
    const before = try slabAllocated();
    try page.runScript("for (const node of nodes) dst.appendChild(node); mo.disconnect(); mo.observe(document.getElementById('dst2'), { childList: true });");
    const allocated = (try slabAllocated()) - before;
    // One record per mutation; each used to bring two NodeLists with it.
    if (allocated >= 300) {
        std.debug.print("200 observed mutations allocated {d} instances\n", .{allocated});
        return error.NodeListPerUnreadRecord;
    }
    // A parsed subtree inserted under an observer: its record holds 200 nodes
    // of the document - no rescue, so no wrapper - and is dropped unread.
    const wrappers_before = try wrapperEntries(browser);
    try page.runScript("document.getElementById('dst2').innerHTML = '<b></b>'.repeat(200); mo.disconnect();");
    const wrappers_after = try wrapperEntries(browser);
    if (wrappers_after - wrappers_before >= wrapper_slack) {
        std.debug.print("an unread record of 200 inserted nodes left {d} wrappers\n", .{wrappers_after - wrappers_before});
        return error.RescueForUnreadRecord;
    }
}

test "an observed mutation whose record script never reads makes no NodeList and takes no rescue" {
    try onFreshThread(unreadRecordsMakeNoListAndNoRescue);
}

/// Outstanding bytes of the allocator a Browser is given.
const CountingAllocator = struct {
    child: std.mem.Allocator,
    outstanding: usize = 0,

    fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.child.rawAlloc(len, alignment, ra) orelse return null;
        self.outstanding += len;
        return result;
    }
    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        if (!self.child.rawResize(memory, alignment, new_len, ra)) return false;
        self.outstanding = self.outstanding - memory.len + new_len;
        return true;
    }
    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.child.rawRemap(memory, alignment, new_len, ra) orelse return null;
        self.outstanding = self.outstanding - memory.len + new_len;
        return result;
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.child.rawFree(memory, alignment, ra);
        self.outstanding -= memory.len;
    }
};

const Retained = struct { instances: usize, wrappers: i64, native: usize, arena: usize };

/// 1,000 rounds of a tree replaced by innerHTML; with `lists`, a
/// querySelectorAll list over each tree is kept until every round is done,
/// so each list rescues the tree innerHTML takes from under it. Then every
/// list is dropped and the page collects twice.
fn retainedAfterDroppedLists(lists: bool) !Retained {
    var counting: CountingAllocator = .{ .child = testing.allocator };
    const browser = try browser_mod.Browser.init(counting.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><div id=host></div></body>", .{ .base_url = "about:blank" });
    try page.runScript("TestUtils.gc(); TestUtils.gc();");
    const slab = try @import("runtime").SlabAllocator.tryGet();
    const arena = @import("runtime").ArenaAllocator.tryGet() catch null;
    const instances_before = slab.stats().currently_allocated;
    const native_before = counting.outstanding;
    const arena_before = if (arena) |a| a.stats().bytes_in_use else 0;
    var buffer: [512]u8 = undefined;
    const script = try std.fmt.bufPrint(&buffer,
        \\globalThis.kept = [];
        \\const host = document.getElementById('host');
        \\const markup = '<section><p><b>x</b></p><ul><li>1</li><li>2</li></ul></section>'.repeat(5);
        \\for (let i = 0; i < 1000; i++) {{
        \\  host.innerHTML = markup;
        \\  if ({s}) kept.push(host.querySelectorAll('*'));
        \\}}
        \\host.innerHTML = '';
        \\kept = null;
    , .{if (lists) "true" else "false"});
    try page.runScript(script);
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript("TestUtils.gc(); TestUtils.gc();");
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript("TestUtils.gc(); TestUtils.gc();");
    const wrappers = try wrapperEntries(browser);
    // What the rounds left behind: the page's own growth over the run.
    return .{
        .instances = slab.stats().currently_allocated -| instances_before,
        .wrappers = wrappers,
        .native = counting.outstanding -| native_before,
        .arena = (if (arena) |a| a.stats().bytes_in_use else 0) -| arena_before,
    };
}

fn droppedListsRetainNothing() !void {
    _ = try retainedAfterDroppedLists(false);
    const without = try retainedAfterDroppedLists(false);
    const with = try retainedAfterDroppedLists(true);
    std.debug.print("dropped lists: instances {d} -> {d}, wrappers {d} -> {d}, native {d} -> {d} B, arena {d} -> {d} B\n", .{ without.instances, with.instances, without.wrappers, with.wrappers, without.native, with.native, without.arena, with.arena });
    // 1,000 lists of 35 nodes rescued 5,000 trees: none of it may outlive the
    // lists' collection.
    if (with.instances > without.instances + 64) return error.InstancesRetainedByDroppedLists;
    if (with.wrappers > without.wrappers + wrapper_slack) return error.WrappersRetainedByDroppedLists;
    if (with.native > without.native + 64 * 1024) return error.NativeHeapRetainedByDroppedLists;
    if (with.arena > without.arena + 64 * 1024) return error.ArenaRetainedByDroppedLists;
}

test "1,000 dropped querySelectorAll lists that rescued their trees retain nothing past two collections" {
    try onFreshThread(droppedListsRetainNothing);
}
