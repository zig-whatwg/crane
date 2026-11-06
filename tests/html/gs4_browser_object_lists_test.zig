//! A Browser's IntersectionObservers, Navigation objects and
//! ProcessingInstructions are listed in lists of its own
//! (dom.browser_object_lists, side tables of its scope; lane gstate4): each
//! Browser sees only its own objects, and a Browser's end - which sweeps the
//! ProcessingInstructions no deinit reached - empties only its own lists.
//! They were one `threadlocal` list each, shared by every Browser a thread
//! ran: one Browser's end swept the ProcessingInstruction list away under
//! another's (docs/instances.md - state has an owner, never a thread).
//!
//! Two Browsers on two threads, each allocating from a DebugAllocator of its
//! own (a shared std.testing.allocator makes the threads take turns), and two
//! Browsers on one thread.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const dom = @import("dom");
const lists = dom.browser_object_lists;

fn startBrowser(allocator: std.mem.Allocator) !*browser_mod.Browser {
    return browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn expectScript(browser: *browser_mod.Browser, source: []const u8) !void {
    if (!try truthy(browser, source)) {
        std.debug.print("false: {s}\n", .{source});
        return error.ScriptAnsweredFalse;
    }
}

/// The objects of each kind a Browser makes.
const Made = struct { observers: usize, instructions: usize };

/// Show a page and make `made.observers` observers observing its body, its
/// Navigation object and `made.instructions` ProcessingInstructions, every
/// one held by script.
fn makeObjects(browser: *browser_mod.Browser, url: []const u8, made: Made) !void {
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><div id=root></div></body>", .{ .base_url = url });
    var buffer: [512]u8 = undefined;
    try expectScript(browser, try std.fmt.bufPrint(&buffer,
        \\globalThis.observers = [];
        \\for (let i = 0; i < {d}; i++) {{
        \\  const observer = new IntersectionObserver(() => {{}});
        \\  observer.observe(document.body);
        \\  observers.push(observer);
        \\}}
        \\globalThis.entry = navigation.currentEntry;
        \\globalThis.instructions = [];
        \\for (let i = 0; i < {d}; i++) instructions.push(document.createProcessingInstruction('gs4', 'n' + i));
        \\observers.length === {d} && instructions.length === {d} && entry !== null
    , .{ made.observers, made.instructions, made.observers, made.instructions }));
}

fn countOf(browser: *browser_mod.Browser, comptime tag: @import("runtime").BrowserScope.Table) usize {
    const list = lists.existingIn(browser.scope, tag) orelse return 0;
    return switch (tag) {
        .processing_instructions => list.count(),
        else => list.slice().len,
    };
}

/// `browser`'s lists hold exactly its own objects.
fn expectOwn(browser: *browser_mod.Browser, made: Made) !void {
    try testing.expectEqual(made.observers, countOf(browser, .intersection_observers));
    try testing.expectEqual(@as(usize, 1), countOf(browser, .navigations));
    try testing.expectEqual(made.instructions, countOf(browser, .processing_instructions));
}

const a_made: Made = .{ .observers = 2, .instructions = 3 };
const b_made: Made = .{ .observers = 5, .instructions = 7 };

fn twoBrowsersOnOneThread() !void {
    const a = try startBrowser(testing.allocator);
    defer a.deinit();
    try makeObjects(a, "http://gs4-a.test/page.html", a_made);
    {
        const b = try startBrowser(testing.allocator);
        defer b.deinit();
        try makeObjects(b, "http://gs4-b.test/page.html", b_made);
        try expectOwn(a, a_made);
        try expectOwn(b, b_made);
    }
    // B's end swept and freed B's lists only.
    try expectOwn(a, a_made);
    try expectScript(a, "observers.length === 2 && instructions.every((pi) => pi.target === 'gs4') && navigation.currentEntry !== null");
}

test "two Browsers on one thread each list their own observers, Navigation and processing instructions, and one's end leaves the other's" {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            twoBrowsersOnOneThread() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

const Shared = struct {
    arrived: std.atomic.Value(u32) = .init(0),

    /// Wait until both threads have arrived at meeting point `point` (1, 2..).
    fn meet(self: *Shared, point: u32) !void {
        _ = self.arrived.fetchAdd(1, .acq_rel);
        var spins: usize = 0;
        while (self.arrived.load(.acquire) < 2 * point) : (spins += 1) {
            if (spins > 50_000_000) return error.TheOtherBrowserNeverArrived;
            std.Thread.yield() catch {};
        }
    }
};

const Side = struct {
    shared: *Shared,
    url: []const u8,
    made: Made,
    /// Whether this side's Browser ends first, while the other's lives.
    ends_first: bool,
    failure: ?anyerror = null,
    debug_allocator: @import("root").poisoning.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            // Never leave the other side waiting.
            _ = self.shared.arrived.fetchAdd(1000, .acq_rel);
        };
        if (self.debug_allocator.deinit() == .leak and self.failure == null) self.failure = error.Leaked;
    }

    fn steps(self: *Side) !void {
        const browser = try startBrowser(self.debug_allocator.allocator());
        var ended = false;
        defer if (!ended) browser.deinit();
        try makeObjects(browser, self.url, self.made);
        // Both Browsers have made their objects.
        try self.shared.meet(1);
        try expectOwn(browser, self.made);
        try self.shared.meet(2);
        if (self.ends_first) {
            browser.deinit();
            ended = true;
        }
        // The first Browser has ended: the other's lists are untouched.
        try self.shared.meet(3);
        if (!self.ends_first) try expectOwn(browser, self.made);
    }
};

test "two Browsers on two threads each list only their own objects, and one's end empties only its own lists" {
    var shared: Shared = .{};
    var sides = [_]Side{
        .{ .shared = &shared, .url = "http://gs4-a.test/page.html", .made = a_made, .ends_first = true },
        .{ .shared = &shared, .url = "http://gs4-b.test/page.html", .made = b_made, .ends_first = false },
    };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
