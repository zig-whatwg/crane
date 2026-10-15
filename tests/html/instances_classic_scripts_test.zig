//! Two Browsers on two threads run classic scripts at the same time, and an
//! import() in each script still finds that script's own [[HostDefined]]:
//! neither Browser's scripts lose, unlink or free the other's records
//! (docs/instances.md - an agent owns what only its own realms reach).
//!
//! A classic script's [[HostDefined]] (html.script_execution
//! ClassicScriptRecord) is what an import() in it resolves against: its base
//! URL and its fetch options. The engine keeps only the record's address, so
//! the host reads a record only while it is in the list of records alive.
//! That list was one process-wide intrusive list, linked by every classic
//! script a document ran and unlinked by every document's teardown, from
//! every Browser's thread, with no lock. Two Browsers running classic scripts
//! at once could drop a record from it - an import() in that script then
//! resolves against the document's base URL instead of the script's - or
//! leave it pointing at a freed record, which the next walk reads.
//!
//! Each round both Browsers load a page whose import map maps "m" only in
//! the scope of the scripts' base URL, run many classic scripts with
//! distinct nonces (one record each), and move the document's base URL out
//! of that scope: "m" then resolves only through each script's own record.
//! The previous round's document is collected first, on both at once, so
//! its records are unlinked while the other Browser links and unlinks its
//! own.
//!
//! Each Browser allocates from a DebugAllocator of its own, without stack
//! traces, which still fails the test on a leak: std.testing.allocator is
//! one allocator behind one lock, capturing a stack trace per allocation, and
//! it kept the two Browsers taking turns - on main they ran 16,000 scripts
//! between them without one collision.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

const page_url = "http://liveclassic.test/page.html";
const page =
    \\<!doctype html><head>
    \\<base href="http://liveclassic.test/scripts/">
    \\<script type=importmap>{"scopes": {"http://liveclassic.test/scripts/": {"m": "data:text/javascript,export%20default%201"}}}</script>
    \\</head><body></body>
;
const rounds = 12;
const scripts_per_round = 2000;

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

/// Turn the Browser's event loop until `source` answers true.
fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 1000) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("timed out waiting for: {s}\n", .{source});
    return error.TimedOut;
}

/// Collect the agent's garbage: the documents no page shows any more go, and
/// their classic script records with them.
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

/// Load the page, free the one it replaced, run `count` classic scripts that
/// each keep a function calling import("m"), move the document's base URL out
/// of the import map's scope, call them all, and expect every import to load.
fn runRound(browser: *browser_mod.Browser, round: usize, count: usize, together: anytype) !void {
    var buffer: [1024]u8 = undefined;
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML(page, .{ .base_url = page_url });
    try waitFor(browser, "document.readyState === 'complete'");

    // Both Browsers free their previous pages' records, and then make new
    // ones, at the same time.
    try together.reached();
    try collect(browser);
    try expectScript(browser, try std.fmt.bufPrint(&buffer,
        \\{{
        \\globalThis.imports = [];
        \\for (let i = 0; i < {d}; i++) {{
        \\  const script = document.createElement('script');
        \\  script.setAttribute('nonce', 'r{d}s' + i);
        \\  script.textContent = 'imports.push(() => import("m"))';
        \\  document.body.appendChild(script);
        \\}}
        \\document.querySelector('base').href = 'http://liveclassic.test/elsewhere/';
        \\globalThis.loaded = -1;
        \\Promise.allSettled(imports.map((load) => load())).then((results) => {{
        \\  globalThis.loaded = results.filter((result) => result.status === 'fulfilled').length;
        \\  globalThis.failure = results.find((result) => result.status === 'rejected')?.reason?.message;
        \\}});
        \\}}
        \\imports.length === {d}
    , .{ count, round, count }));
    try waitFor(browser, "globalThis.loaded !== -1");
    if (!try truthy(browser, try std.fmt.bufPrint(&buffer, "globalThis.loaded === {d}", .{count}))) {
        const answer = try context.evaluateScriptToString("`${globalThis.loaded} loaded; the first failure: ${globalThis.failure}`", testing.allocator);
        defer testing.allocator.free(answer);
        std.debug.print("round {d}: {s} (of {d})\n", .{ round, answer, count });
        return error.AnImportLostItsScript;
    }
}

const Alone = struct {
    fn reached(_: Alone) !void {}
};

test "an import() in a classic script resolves against the script's own base URL after the document's moves" {
    const browser = try startBrowser(testing.allocator);
    defer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    try runRound(browser, 0, 20, Alone{});
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

/// Both Browsers start their round's scripts together.
const Meeting = struct {
    shared: *Shared,
    point: u32,

    fn reached(self: Meeting) !void {
        try self.shared.meet(self.point);
    }
};

const Side = struct {
    shared: *Shared,
    failure: ?anyerror = null,
    /// This Browser's alone (the file's comment says why).
    debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            // Whatever happened, never leave the other side waiting.
            _ = self.shared.arrived.fetchAdd(1000, .acq_rel);
        };
        if (self.debug_allocator.deinit() == .leak and self.failure == null) self.failure = error.Leaked;
    }

    fn steps(self: *Side) !void {
        const browser = try startBrowser(self.debug_allocator.allocator());
        defer browser.deinit();
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
        for (0..rounds) |round| {
            try runRound(browser, round, scripts_per_round, Meeting{ .shared = self.shared, .point = @intCast(round + 1) });
        }
    }
};

test "two Browsers on two threads run classic scripts at once, and each script's import() still finds its own record" {
    var shared: Shared = .{};
    var sides = [_]Side{ .{ .shared = &shared }, .{ .shared = &shared } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
