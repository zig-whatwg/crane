//! A Browser's live navigables - the IFrameIntegration of each iframe,
//! popup and host page it made content for - are on its own list
//! (`Navigables.integrations`, lane gstate4). They were one `threadlocal`
//! list (HTMLIFrameElement live_navigables), shared by every Browser on the
//! thread: an integration never deinit'd stayed listed past its Browser,
//! and the next Browser's iframe lookup read the freed block.
//!
//! Two Browsers on two threads, each allocating from a DebugAllocator of its
//! own, each with iframes: each list holds only its own navigables, and one
//! Browser's end leaves the other's list and frames as they were.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const dom = @import("dom");

fn startBrowser(allocator: std.mem.Allocator) !*browser_mod.Browser {
    return browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 500) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("timed out waiting for: {s}\n", .{source});
    return error.TimedOut;
}

/// How many live navigables `browser`'s list holds, each on that list.
fn integrationsOf(browser: *browser_mod.Browser) !usize {
    const list = dom.browser_state.existingNavigablesIn(browser.scope) orelse return 0;
    for (list.integrations.items) |integration| {
        if (integration.navigables != list) return error.IntegrationOnAnotherList;
    }
    return list.integrations.items.len;
}

/// Show a page, then add `frames` srcdoc iframes to it and wait for them:
/// the number of navigables the frames added to the Browser's list.
fn openFrames(browser: *browser_mod.Browser, url: []const u8, frames: usize) !usize {
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = url });
    const before = try integrationsOf(browser);
    var buffer: [512]u8 = undefined;
    _ = try truthy(browser, try std.fmt.bufPrint(&buffer,
        \\for (let i = 0; i < {d}; i++) {{
        \\  const frame = document.createElement('iframe');
        \\  frame.srcdoc = '<p id=p>frame ' + i + '</p>';
        \\  document.body.appendChild(frame);
        \\}}
        \\true
    , .{frames}));
    try waitFor(browser, try std.fmt.bufPrint(&buffer, "frames.length === {d} && [...document.querySelectorAll('iframe')].every((f) => f.contentDocument && f.contentDocument.getElementById('p'))", .{frames}));
    return (try integrationsOf(browser)) - before;
}

const Shared = struct {
    arrived: std.atomic.Value(u32) = .init(0),

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
    frames: usize,
    ends_first: bool,
    failure: ?anyerror = null,
    debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            _ = self.shared.arrived.fetchAdd(1000, .acq_rel);
        };
        if (self.debug_allocator.deinit() == .leak and self.failure == null) self.failure = error.Leaked;
    }

    fn steps(self: *Side) !void {
        const browser = try startBrowser(self.debug_allocator.allocator());
        var ended = false;
        defer if (!ended) browser.deinit();
        const added = try openFrames(browser, self.url, self.frames);
        try testing.expectEqual(self.frames, added);
        const own = try integrationsOf(browser);
        try self.shared.meet(1);
        // Each Browser's list holds its own navigables only.
        try testing.expectEqual(own, try integrationsOf(browser));
        try self.shared.meet(2);
        if (self.ends_first) {
            browser.deinit();
            ended = true;
        }
        try self.shared.meet(3);
        if (!self.ends_first) {
            try testing.expectEqual(own, try integrationsOf(browser));
            // Its frames still answer through their navigables.
            var buffer: [160]u8 = undefined;
            try waitFor(browser, try std.fmt.bufPrint(&buffer, "[...document.querySelectorAll('iframe')].every((f, i) => f.contentDocument.getElementById('p').textContent === 'frame ' + i) && frames.length === {d}", .{self.frames}));
            // A frame removed leaves the Browser's list.
            _ = try truthy(browser, "document.querySelector('iframe').remove(), true");
            try testing.expectEqual(own - 1, try integrationsOf(browser));
        }
    }
};

test "two Browsers on two threads each list only their own navigables, and one's end leaves the other's" {
    var shared: Shared = .{};
    var sides = [_]Side{
        .{ .shared = &shared, .url = "http://gs4-a.test/page.html", .frames = 2, .ends_first = true },
        .{ .shared = &shared, .url = "http://gs4-b.test/page.html", .frames = 3, .ends_first = false },
    };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
