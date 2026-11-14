//! The Document's shared attribute blocks and their timer, against timers
//! the test holds (lane nd2 batch 5; dom.attribute_block_cache). The cache's
//! 10 s are a BACKGROUND timer of its document's realm (runtime.
//! TimerVTable.setBackgroundTimeout), whose user data is the cache's own
//! block - so the block has three holders, and each path that ends one of
//! them must leave it to the others:
//!
//! - the timer fires: the cache ends, its blocks are their elements';
//! - the document ends first: the timer is cleared - and a clear the timers
//!   do NOT confirm leaves the block to the timer, which frees it when it
//!   fires or is dropped (lesson architecture-only-confirmed-cancellation-
//!   returns-payload-ownership);
//! - the timers end first (their manager's end drops what is armed): the
//!   cache stays its document's, with no timer;
//! - no background timer can be armed: the cache ends with its parser run.
//!
//! A real Browser's NativeTimerManager always confirms the clear of an armed
//! timer, so the unconfirmed path is reachable only here. Every page is on
//! std.testing.allocator: a block, a table or a cache no path freed fails
//! its test as a leak, and one freed twice or read after its free as such.
//!
//! These name only generated interfaces and src/dom: no impl (AGENTS.md "The
//! impls boundary").

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

/// Timers the test fires, drops and refuses by hand.
const Timers = struct {
    armed: std.ArrayListUnmanaged(Armed) = .empty,
    next_id: runtime.TimerId = 1,
    /// Whether a clear of an armed timer is confirmed (and takes it out).
    confirms_clear: bool = true,
    /// Whether a background timer can be armed at all.
    arms_background: bool = true,
    arms: usize = 0,
    clears: usize = 0,

    const Armed = struct {
        id: runtime.TimerId,
        ms: u64,
        callback: runtime.TimerCallback,
        data: ?*anyopaque,
        drop: runtime.TimerDrop,
    };

    fn deinit(self: *Timers) void {
        self.armed.deinit(testing.allocator);
    }

    fn plain(_: *anyopaque, _: u64, _: runtime.TimerCallback, _: ?*anyopaque) runtime.TimerId {
        return 0;
    }

    fn background(ctx: *anyopaque, ms: u64, callback: runtime.TimerCallback, data: ?*anyopaque, drop: runtime.TimerDrop) runtime.TimerId {
        const self: *Timers = @ptrCast(@alignCast(ctx));
        if (!self.arms_background) return 0;
        self.armed.append(testing.allocator, .{ .id = self.next_id, .ms = ms, .callback = callback, .data = data, .drop = drop }) catch return 0;
        self.next_id += 1;
        self.arms += 1;
        return self.next_id - 1;
    }

    fn clear(ctx: *anyopaque, id: runtime.TimerId) bool {
        const self: *Timers = @ptrCast(@alignCast(ctx));
        self.clears += 1;
        if (!self.confirms_clear) return false;
        for (self.armed.items, 0..) |timer, index| {
            if (timer.id != id) continue;
            _ = self.armed.orderedRemove(index);
            return true;
        }
        return false;
    }

    const vtable: runtime.TimerVTable = .{ .setTimeout = plain, .setBackgroundTimeout = background, .clearTimeout = clear };

    fn interface(self: *Timers) runtime.TimerInterface {
        return .{ .vtable = &vtable, .ctx = self };
    }

    /// Every armed timer comes due, oldest first: gone before its callback.
    fn fireAll(self: *Timers) void {
        while (self.armed.items.len != 0) {
            const timer = self.armed.orderedRemove(0);
            timer.callback(timer.data);
        }
    }

    /// The timers' end: what is armed is dropped, never fired.
    fn dropAll(self: *Timers) void {
        while (self.armed.items.len != 0) {
            const timer = self.armed.orderedRemove(0);
            timer.drop(timer.data);
        }
    }
};

const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,
    document_ended: bool = false,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page, timers: *Timers) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(testing.allocator), .ctx = try runtime.ContextData.init(testing.allocator, .{ .timer = timers.interface() }) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(testing.allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.div = try interfaces.Document.call_createElement(self.document, str("div"), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
    }

    /// The document's end, with its tree and whatever of its Browser's side
    /// tables a teardown did not reach: its cache ends with its state.
    fn endDocument(self: *Page) void {
        if (self.document_ended) return;
        self.document_ended = true;
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
    }

    fn close(self: *Page) void {
        self.endDocument();
        self.scope.deinit();
        self.ctx.deinit();
    }

    /// The div's children after `html` is parsed into it: one fragment
    /// parse, a parser run of the document.
    fn parse(self: *Page, html: []const u8, out: []*runtime.Instance) !void {
        try interfaces.Element.set_innerHTML(self.div, .{ .domstring = str(html) });
        var at = try interfaces.Element.get_firstElementChild(self.div);
        for (out) |*slot| {
            slot.* = at.?;
            at = try interfaces.Element.get_nextElementSibling(at.?);
        }
    }
};

/// The block `el`'s attributes are in.
fn blockOf(el: *runtime.Instance) *const dom.element_data.AttributeList {
    return dom.element_data.of(el).?.data.attrs.?;
}

const two = "<p class=k title=t></p><p class=k title=t></p>";

test "document cache: its 10 s are one background timer, armed when the run that made it ends; a later parse restarts nothing; fired, the blocks are their elements'" {
    var timers: Timers = .{};
    defer timers.deinit();
    var page: Page = undefined;
    try page.open(&timers);
    defer page.close();

    var els: [2]*runtime.Instance = undefined;
    try page.parse(two, &els);
    const block = blockOf(els[0]);
    try testing.expect(blockOf(els[1]) == block);
    // The two elements and the document's cache; one timer, for 10 s.
    try testing.expectEqual(@as(u8, 3), block.holders);
    try testing.expectEqual(@as(usize, 1), timers.armed.items.len);
    try testing.expectEqual(dom.attribute_block_cache.keep_ms, timers.armed.items[0].ms);

    // A second fragment parse shares through the same cache - its elements
    // take the block the cache kept - and is an access: no clear, no second
    // timer.
    var again: [2]*runtime.Instance = undefined;
    try page.parse(two, &again);
    try testing.expect(blockOf(again[0]) == block and blockOf(again[1]) == block);
    try testing.expectEqual(@as(usize, 1), timers.arms);
    try testing.expectEqual(@as(usize, 0), timers.clears);

    // The 10 s are over: the cache is gone - one holder fewer - and the
    // block is its elements' alone.
    const with_cache = block.holders;
    timers.fireAll();
    try testing.expectEqual(with_cache - 1, block.holders);
    try testing.expect(blockOf(again[0]) == block);

    // The next parse makes a new cache, with a timer of its own.
    var later: [2]*runtime.Instance = undefined;
    try page.parse(two, &later);
    try testing.expect(blockOf(later[0]) != block);
    try testing.expectEqual(@as(u8, 3), blockOf(later[0]).holders);
    try testing.expectEqual(@as(usize, 2), timers.arms);
    try testing.expectEqual(@as(usize, 1), timers.armed.items.len);
    // The page's end clears it: confirmed, so the block is freed there.
}

test "document cache: the document's end clears its timer; nothing is left armed" {
    var timers: Timers = .{};
    defer timers.deinit();
    var page: Page = undefined;
    try page.open(&timers);
    defer page.close();

    var els: [2]*runtime.Instance = undefined;
    try page.parse(two, &els);
    try testing.expectEqual(@as(usize, 1), timers.armed.items.len);
    page.endDocument();
    try testing.expectEqual(@as(usize, 1), timers.clears);
    try testing.expectEqual(@as(usize, 0), timers.armed.items.len);
}

test "document cache: a clear the timers do not confirm leaves the block to the timer - it frees it when it fires" {
    var timers: Timers = .{ .confirms_clear = false };
    defer timers.deinit();
    var page: Page = undefined;
    try page.open(&timers);
    defer page.close();

    var els: [2]*runtime.Instance = undefined;
    try page.parse(two, &els);
    // The document ends; its clear is refused, so the timer may still fire
    // with the cache's block as its data: the block must still be there.
    page.endDocument();
    try testing.expectEqual(@as(usize, 1), timers.clears);
    try testing.expectEqual(@as(usize, 1), timers.armed.items.len);
    // It fires into a cache with no document: it frees the block, and
    // touches nothing of the document (std.testing.allocator: a read of the
    // freed state, a second free or a block left behind fails here).
    timers.fireAll();
}

test "document cache: an unconfirmed clear, then the timers' end - the drop frees the block" {
    var timers: Timers = .{ .confirms_clear = false };
    defer timers.deinit();
    var page: Page = undefined;
    try page.open(&timers);
    defer page.close();

    var els: [2]*runtime.Instance = undefined;
    try page.parse(two, &els);
    page.endDocument();
    try testing.expectEqual(@as(usize, 1), timers.armed.items.len);
    timers.dropAll();
}

test "document cache: the timers end first - the cache stays its document's, and the document's end frees it with no timer to clear" {
    var timers: Timers = .{};
    defer timers.deinit();
    var page: Page = undefined;
    try page.open(&timers);
    defer page.close();

    var els: [2]*runtime.Instance = undefined;
    try page.parse(two, &els);
    const block = blockOf(els[0]);
    // The timer manager's end drops what is armed (Browser.deinit ends the
    // event loop before the teardown sweeps reach an orphaned document).
    timers.dropAll();
    try testing.expectEqual(@as(u8, 3), block.holders);
    // The cache has no timer now: the next run that leaves it arms one.
    var again: [2]*runtime.Instance = undefined;
    try page.parse(two, &again);
    try testing.expectEqual(@as(usize, 2), timers.arms);
    timers.dropAll();
    // The document's end: nothing to clear.
    page.endDocument();
    try testing.expectEqual(@as(usize, 0), timers.clears);
}

test "document cache: timers that arm no background timer - the cache ends with its parser run" {
    var timers: Timers = .{ .arms_background = false };
    defer timers.deinit();
    var page: Page = undefined;
    try page.open(&timers);
    defer page.close();

    var els: [2]*runtime.Instance = undefined;
    try page.parse(two, &els);
    const block = blockOf(els[0]);
    try testing.expect(blockOf(els[1]) == block);
    // No timer could end the cache later, so it ended with the run: the
    // block is its two elements' (batch 4's lifetime).
    try testing.expectEqual(@as(u8, 2), block.holders);
    try testing.expectEqual(@as(usize, 0), timers.armed.items.len);
    // Each run has its own, then: the next parse's elements share with
    // each other only.
    var kept: [2]*runtime.Instance = undefined;
    const other = try interfaces.Document.call_createElement(page.document, str("div"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(page.div, other);
    try interfaces.Element.set_innerHTML(other, .{ .domstring = str(two) });
    kept[0] = (try interfaces.Element.get_firstElementChild(other)).?;
    kept[1] = (try interfaces.Element.get_nextElementSibling(kept[0])).?;
    try testing.expect(blockOf(kept[0]) == blockOf(kept[1]));
    try testing.expectEqual(@as(u8, 2), blockOf(kept[0]).holders);
}
