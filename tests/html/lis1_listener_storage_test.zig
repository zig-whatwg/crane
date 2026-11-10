//! Lane lis1 (plan-v2 N5; tmp/redesign/nodedata/framework-pages.md finding 3,
//! tables D and J): what a target's event listener list costs.
//!
//! Two elements in five on React, Vue and Preact pages carry exactly ONE
//! listener or event handler. Before this lane one `addEventListener`
//! listener cost 527-556 B (the 480-B inline-capacity list, the record's
//! type copy) and one event handler IDL attribute 1,216 B (the list, the
//! handler map with its 8-slot table, the type copy) - measured by site on
//! those pages. Now a target's list is one block made with its first
//! listener: a header and 32-byte listeners.
//!
//! Each case counts the bytes a Browser allocates from its own allocator
//! (every byte a target's list holds comes from it: runtime.allocatorOf) while
//! script gives 64 elements, made and wrapped beforehand, one listener each,
//! and divides by 64. "Rounded" counts each allocation at the 16-byte quantum
//! libc malloc hands out (macOS's tiny classes, glibc's chunks).
//!
//! - a target with no listener allocates nothing to be asked about one;
//! - one addEventListener listener: at most 64 B (rounded);
//! - one event handler IDL attribute: at most 64 B (rounded);
//! - one of each: at most 96 B (rounded): the second shares the block.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const h = @import("refcount_holders_helpers.zig");

/// Live bytes through a Browser's allocator: as requested, and rounded up to
/// malloc's 16-byte quantum. Atomic: a Browser's threads share its allocator.
const CountingAllocator = struct {
    child: std.mem.Allocator,
    live: std.atomic.Value(isize) = .init(0),
    rounded: std.atomic.Value(isize) = .init(0),

    fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn round(len: usize) isize {
        return @intCast(std.mem.alignForward(usize, @max(len, 1), 16));
    }
    fn note(self: *CountingAllocator, old_len: usize, new_len: usize) void {
        _ = self.live.fetchAdd(@as(isize, @intCast(new_len)) - @as(isize, @intCast(old_len)), .monotonic);
        const old_rounded: isize = if (old_len == 0) 0 else round(old_len);
        const new_rounded: isize = if (new_len == 0) 0 else round(new_len);
        _ = self.rounded.fetchAdd(new_rounded - old_rounded, .monotonic);
    }
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.child.rawAlloc(len, alignment, ra) orelse return null;
        self.note(0, len);
        return result;
    }
    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        if (!self.child.rawResize(memory, alignment, new_len, ra)) return false;
        self.note(memory.len, new_len);
        return true;
    }
    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.child.rawRemap(memory, alignment, new_len, ra) orelse return null;
        self.note(memory.len, new_len);
        return result;
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.child.rawFree(memory, alignment, ra);
        self.note(memory.len, 0);
    }
};

const Bytes = struct { live: isize, rounded: isize };

const Page = struct {
    counting: *CountingAllocator,
    browser: *browser_mod.Browser,

    fn open(counting: *CountingAllocator) !Page {
        const browser = try browser_mod.Browser.init(counting.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        // The initial about:blank's realm goes now, not inside a count
        // (refcount_holders_helpers.Page.open).
        for (0..3) |_| {
            try page.runScript("TestUtils.gc(); TestUtils.gc();");
            _ = try browser.runEventLoopBlocking(20);
        }
        return .{ .counting = counting, .browser = browser };
    }

    fn close(self: Page) void {
        self.browser.deinit();
    }

    fn run(self: Page, source: []const u8) !void {
        const page = self.browser.current_context orelse return error.NoPage;
        page.runScript(source) catch |err| {
            std.debug.print("script failed: {s}\n", .{source});
            return err;
        };
    }

    fn now(self: Page) Bytes {
        return .{ .live = self.counting.live.load(.monotonic), .rounded = self.counting.rounded.load(.monotonic) };
    }

    /// The bytes per element `script` leaves allocated, over `count`
    /// elements: the same loop run with `control` (the same calls into the
    /// engine and the binding, no listener) is subtracted, so what script
    /// itself keeps cancels.
    fn perElement(self: Page, count: isize, control: []const u8, script: []const u8) !Bytes {
        const before_control = self.now();
        try self.run(control);
        const after_control = self.now();
        try self.run(script);
        const after = self.now();
        const control_live = after_control.live - before_control.live;
        const control_rounded = after_control.rounded - before_control.rounded;
        return .{
            .live = @divTrunc(after.live - after_control.live - control_live, count),
            .rounded = @divTrunc(after.rounded - after_control.rounded - control_rounded, count),
        };
    }
};

const setup =
    \\globalThis.f = () => {};
    \\globalThis.g = () => {};
    \\globalThis.make = () => { const list = []; for (let i = 0; i < 64; i++) { const el = document.createElement('div'); document.body.appendChild(el); list.push(el); } return list; };
    \\globalThis.warm = make(); for (const el of warm) { el.addEventListener('click', f); el.onclick = g; el.addEventListener('input', f); }
    \\globalThis.a = make(); globalThis.b = make(); globalThis.c = make(); globalThis.d = make(); globalThis.e = make();
    \\0
;

/// Print a case's bytes, and count it over its limit: every case prints
/// before the test fails, so a red run records them all.
fn report(over: *usize, what: []const u8, bytes: Bytes, limit: isize) void {
    std.debug.print("lis1: {s}: {d} B requested, {d} B rounded per element (limit {d})\n", .{ what, bytes.live, bytes.rounded, limit });
    if (bytes.rounded > limit) over.* += 1;
}

fn costs() !void {
    var counting: CountingAllocator = .{ .child = testing.allocator };
    const page = try Page.open(&counting);
    defer page.close();
    try page.run(setup);
    var over: usize = 0;

    // Asking about a listener, removing one there is none of, reading a
    // handler that was never set: nothing for a target that has none.
    const asked = try page.perElement(64, "for (const el of a) el.hasAttribute('x'); 0", "for (const el of a) { el.removeEventListener('click', f); el.onclick; el.onclick = null; } 0");
    report(&over, "no listener", asked, 0);

    const listener = try page.perElement(64, "for (const el of b) el.hasAttribute('click'); 0", "for (const el of b) el.addEventListener('click', f); 0");
    report(&over, "one addEventListener listener", listener, 64);

    const handler = try page.perElement(64, "for (const el of c) el.hasAttribute('click'); 0", "for (const el of c) el.onclick = f; 0");
    report(&over, "one event handler IDL attribute", handler, 64);

    const both = try page.perElement(64, "for (const el of d) el.hasAttribute('click'); 0", "for (const el of d) { el.addEventListener('click', f); el.onclick = g; } 0");
    report(&over, "one listener and one event handler", both, 96);

    // A custom type keeps a copy of its name beside the block.
    const custom = try page.perElement(64, "for (const el of e) el.hasAttribute('click'); 0", "for (const el of e) el.addEventListener('lis1-custom', f); 0");
    report(&over, "one listener of a custom type", custom, 96);
    if (over != 0) return error.ListenerStorageTooLarge;
}

test "a target's listener storage: nothing without one, one block of at most 64 B for one listener or one event handler" {
    try h.onFreshThread(costs);
}
