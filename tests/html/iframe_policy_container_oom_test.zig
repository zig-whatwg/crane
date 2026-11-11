//! An iframe's new document gets its policy container, or the navigation
//! that would make it stops: never a document with an empty one. And an
//! iframe src navigation that runs out of memory starts no navigation; it
//! never panics.
//!
//! HTMLIFrameElement made the clones a child navigation needs with
//! `clone(allocator) catch null` - the source snapshot params' container
//! ("navigate" step 4), "determine navigation params policy container"'s
//! inherited clones (`catch return null`), the one a session history entry
//! keeps, and a javascript: URL's String document's. On out of memory the
//! new document then kept the empty container it is created with: no CSP
//! (lane leaks2's fail-open table). Each failure now stops the navigation
//! (or does not start it), and the frame keeps the document it had.
//!
//! The sweeps: a page with an enforced `<meta>` CSP and two iframes - one
//! with a srcdoc, which inherits it (step 2: a clone of its container
//! document's), and one without. Each round fails the i-th allocation made
//! while a frame navigates again - the srcdoc frame to a new srcdoc; the
//! other to a javascript: URL whose String is a document, or to a data: URL
//! (a local scheme: step 3 inherits the initiator's container) - and then
//! checks the frame's active document: it must have the page's policy. A
//! navigation with memory to spare, before the sweep, is the control: the
//! frame shows a new document.
//!
//! Red on lane/int4 (lane leaks5): both src sweeps panicked in
//! HTMLIFrameElement.resolveSrc, whose every allocation was `catch
//! unreachable`. Lane leaks4's javascript: sweep set src on the srcdoc
//! frame, which changes nothing (HTML 4.8.5 processes src only for a frame
//! with no srcdoc attribute), so it navigated nothing and passed vacuously.
//! The Browser's allocator is a FailingAllocator over c_allocator, which
//! fails every allocation from the i-th on until the round ends (an
//! out-of-memory path elsewhere may leak; that is not this test's).
//!
//! Two sweeps more: the parent's policy also has upgrade-insecure-requests,
//! so every navigation inherits the parent's navigation upgrade tuples (UIR
//! 3.3), whose copy allocates; and a new iframe, whose initial about:blank
//! document inherits its creator's container ("create a new browsing
//! context and document" step 19.2), which out of memory left empty.
//! And a contentWindow read while memory is still out, after each failing
//! round of a srcdoc re-navigation (`sweepContentWindow`).
//!
//! Lane v8up b3e: that sweep used to REQUIRE a round that left the frame
//! with no Window (`NoRoundLeftTheFrameWithoutAWindow`), as proof that it
//! reached the out-of-memory path the null fallback was for. That state was
//! the bug: a navigation whose new realm could not be made released the
//! navigable's realm while its browsing context still answered the old
//! Window as active, kept (or, out of memory again, ended) the old realm,
//! and the next navigation's abort made a DOMException in the ended realm
//! ("a platform object made in a realm no Browser owns": FAIL on chat2,
//! FLAKY on server1). The fix keeps the old realm and Window - the
//! navigation fails, the old document stays - so the sweep now counts that
//! path itself (IFrameIntegration.realm_replacements_failed, at least one
//! round) and asserts more each round: the frame answers a Window, never
//! null; script reads it with memory to spare; and the frame navigates
//! again after the first such round and after the sweep. A round whose new
//! realm failed after the engine handed the WindowProxy on (V8 cannot attach
//! a detached global again) leaves script no Window through the proxy (a
//! TypeError on member reads: the engine detaches the failed context's
//! global too, so every such failure leaves the same proxy with no global):
//! the frame must then recover on its next navigation. And, unlike the other sweeps, this one checks memory: its
//! FailingAllocator sits on a counting allocator over c_allocator, and once
//! the Browser is torn down it holds nothing (`sweepContentWindow` says why
//! the check is per sweep, not per round).
//!
//! Lane leaks5 saw the frames stop navigating partway through these sweeps
//! - the srcdoc frame from failing allocation 102, the javascript: frame
//! from 91 - and took it for a navigable wedged by out of memory. Lane nav1
//! measured both (tests/html/navigable_failed_commit_oom_test.zig): the
//! srcdoc frame from round 102 is the navigation rate limiter ("allowed to
//! perform a navigation or history update", 200 per 10 s, which a sweep's
//! rounds outrun), not a wedge - with the count reset, every round's next
//! navigation succeeds; and the javascript: frame from 91 is a javascript:
//! URL running nothing in the destroyed document a round that failed after
//! the old document unloaded leaves showing (its script needs a fully
//! active document), which any other navigation replaces. So the rounds
//! after those test nothing new here, and the control is the navigation
//! before the sweep, which must show a new document.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const page_html =
    \\<!doctype html>
    \\<head><meta http-equiv="Content-Security-Policy" content="img-src 'none'; upgrade-insecure-requests"></head>
    \\<body><iframe id="s" srcdoc="<p>first</p>"></iframe><iframe id="n"></iframe></body>
;

/// What the frame's active document has.
const FrameDocument = union(enum) {
    /// No document: a navigation whose realm could not be made leaves the
    /// frame without one - closed: nothing runs in it.
    none,
    /// A Document with no internal state, so no policy container: what
    /// lane leaks4 saw the frame name after an out-of-memory path. Closed
    /// now - every CSP decision against such a document is Blocked
    /// (dom.csp_violations.documentCspList, the Window's settings answer
    /// PolicyContainer.unavailable) - and printed with the failing
    /// allocation's stack. Lane leaks5's sweeps on lane/int4 met none.
    no_container,
    /// Its CSP list's policies; maxInt for an unenforceable list.
    policies: usize,
};

/// The frame's Window's document, or null.
fn frameWindowDocument(page: anytype, realm: runtime.Context, navigation: Navigation) !?*runtime.Instance {
    const owned = try page.evaluateScript(navigation.frame());
    defer owned.release();
    // No frame: a new one whose creation ran out of memory.
    const iframe = engine.convertToPlatformObject(realm, owned.value) orelse return null;
    // Through the frame's Window, not contentDocument: a data: document is
    // cross-origin, and Zig code runs no access check.
    const window = (try interfaces.HTMLIFrameElement.get_contentWindow(iframe)) orelse return null;
    return interfaces.Window.get_document(window) catch null;
}

fn frameDocument(page: anytype, realm: runtime.Context, navigation: Navigation) !FrameDocument {
    const document = (try frameWindowDocument(page, realm, navigation)) orelse return .none;
    const container = dom.policy_containers.of(document) orelse return .no_container;
    if (container.csp_list.unenforceable) return .{ .policies = std.math.maxInt(usize) };
    return .{ .policies = container.csp_list.policies.items.len };
}

const Navigation = enum {
    srcdoc,
    javascript_url,
    data_url,
    new_frame,

    /// The frame the navigation is of: the srcdoc frame, or the frame with
    /// no srcdoc attribute - a src set on a frame that has one changes
    /// nothing (HTML 4.8.5: "an iframe element ... with no srcdoc attribute
    /// specified has its src attribute set").
    fn frame(self: Navigation) []const u8 {
        return switch (self) {
            .srcdoc => "document.getElementById('s')",
            .javascript_url, .data_url => "document.getElementById('n')",
            .new_frame => "window.f",
        };
    }

    /// How far apart the allocations a sweep fails are: every one, except
    /// for a new frame, whose creation (a realm, a Window, a document and
    /// its elements) makes so many that a sweep of each takes minutes.
    fn stride(self: Navigation) usize {
        return switch (self) {
            .new_frame => 7,
            else => 1,
        };
    }

    /// Each round sets a new value (`window.k` counts them), so that each
    /// round's document is told apart from the last.
    fn script(self: Navigation) []const u8 {
        return switch (self) {
            .srcdoc => "document.getElementById('s').srcdoc = '<p>again ' + (window.k = (window.k || 0) + 1) + '</p>';",
            .javascript_url => "document.getElementById('n').src = 'javascript:\"<p>' + (window.k = (window.k || 0) + 1) + '</p>\"';",
            // A local-scheme URL: "determine navigation params policy
            // container" inherits the initiator's container (step 3).
            .data_url => "document.getElementById('n').src = 'data:text/html,<p>' + (window.k = (window.k || 0) + 1) + '</p>';",
            // A new iframe's initial about:blank document, which "create a
            // new browsing context and document" step 19.2 gives a clone of
            // its creator's container.
            // The last round's frame goes first: kept, each one's realm
            // stayed alive and V8 reached its heap limit.
            .new_frame => "if (window.f) window.f.remove(); window.f = undefined; window.f = document.createElement('iframe'); document.body.appendChild(window.f);",
        };
    }
};

fn sweep(navigation: Navigation, rounds: usize) !void {
    var failing = std.testing.FailingAllocator.init(std.heap.c_allocator, .{});
    const browser = try browser_mod.Browser.init(failing.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    // Out-of-memory rounds may leave a tree held (an OOM path elsewhere may leak, which is not this test's).
    @import("dom").refcount_teardown.allowLiveNodesAtAgentEnd(&browser.agent_host.deferred_teardown, "out-of-memory rounds may leave a tree held");
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(page_html, .{ .base_url = "https://example.test/page.html" });
    _ = try browser.runEventLoopBlocking(50);
    const realm = browser.getRealm() orelse return error.NoRealm;
    // The control: a new frame made with memory to spare.
    if (navigation == .new_frame) {
        try page.runScript(navigation.script());
        _ = try browser.runEventLoopBlocking(50);
    }
    // The frame inherited the page's policy.
    try testing.expectEqual(FrameDocument{ .policies = 1 }, try frameDocument(page, realm, navigation));
    // The control: with memory to spare, the navigation runs - the frame
    // shows a new document with the page's policy. A src set on a frame
    // that has a srcdoc attribute changes nothing (HTML 4.8.5): lane
    // leaks4's javascript: sweep did that, navigated nothing, and passed
    // vacuously.
    if (navigation != .new_frame) {
        const shown = (try frameWindowDocument(page, realm, navigation)) orelse return error.NoFrameDocument;
        const shown_generation = runtime.SlabAllocator.generationOf(shown);
        try page.runScript(navigation.script());
        var navigated = false;
        for (0..40) |_| {
            _ = try browser.runEventLoopBlocking(50);
            const now = (try frameWindowDocument(page, realm, navigation)) orelse continue;
            if (now != shown or runtime.SlabAllocator.generationOf(now) != shown_generation) {
                navigated = true;
                break;
            }
        }
        if (!navigated) {
            std.debug.print("{s}: the control navigation navigated nothing\n", .{@tagName(navigation)});
            return error.NothingNavigated;
        }
        try testing.expectEqual(FrameDocument{ .policies = 1 }, try frameDocument(page, realm, navigation));
    }

    var round: usize = 0;
    while (round < rounds) : (round += 1) {
        const before = frameWindowDocument(page, realm, navigation) catch null;
        const before_generation: u64 = if (before) |d| runtime.SlabAllocator.generationOf(d) else 0;
        failing.has_induced_failure = false;
        failing.fail_index = failing.alloc_index + round * navigation.stride();
        page.runScript(navigation.script()) catch {};
        _ = browser.runEventLoopBlocking(50) catch {};
        failing.fail_index = std.math.maxInt(usize);
        const found = frameDocument(page, realm, navigation) catch |err| {
            std.debug.print("{s}: failing allocation {d}: the frame could not be read: {s}\n", .{ @tagName(navigation), round, @errorName(err) });
            return err;
        };
        const policies = switch (found) {
            // No document: the frame shows nothing, which runs nothing.
            // The sweep's end is still the round that failed nothing - a
            // navigation the rate limiter refused. It used to skip that
            // check, and the frame never showed .none for long: it went on
            // naming the destroyed document a failed commit left, until the
            // collector freed it under the navigable (lane nav2, item 0).
            // Now the Window's teardown clears it, the srcdoc frame shows
            // .none until a navigation commits, and once the limiter refused
            // them all the sweep ran its 4,000 rounds (SweepDidNotEnd).
            .none => {
                if (!failing.has_induced_failure) return;
                continue;
            },
            .no_container => {
                const after = frameWindowDocument(page, realm, navigation) catch null;
                std.debug.print("{s}: failing allocation {d}: the frame's document has no policy container; before {?*} gen {d}, after {?*} gen {d}\n", .{
                    @tagName(navigation), round, before, before_generation, after, if (after) |d| runtime.SlabAllocator.generationOf(d) else 0,
                });
                if (failing.has_induced_failure) std.debug.dumpStackTrace(&failing.getStackTrace());
                continue;
            },
            .policies => |count| count,
        };
        if (policies == 0) {
            std.debug.print("{s}: failing allocation {d} of the navigation left the frame's document with no policy\n", .{ @tagName(navigation), round });
            return error.FailedOpen;
        }
        // A sweep past the navigation's last allocation fails nothing.
        if (!failing.has_induced_failure) return;
    }
    return error.SweepDidNotEnd;
}

test "a srcdoc iframe's re-navigation never commits a document without its container document's policy" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            sweep(.srcdoc, 4000) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "a javascript: URL's String document never commits without the policies of the document it replaces" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            sweep(.javascript_url, 4000) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "an iframe's src navigation to a data: URL never panics on out of memory, and never commits without the initiator's policy" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            sweep(.data_url, 4000) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "a new iframe's initial about:blank document never starts without its creator's policy" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            sweep(.new_frame, 4000) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

/// `iframe.contentWindow` read while memory is still out, right after a
/// srcdoc re-navigation failed at the i-th allocation: null, or a Window.
///
/// HTMLIFrameElement.get_contentWindow fell back to the integration's
/// WindowProxy - a Zig struct inside IFrameIntegration, not a
/// runtime.Instance - cast to the WindowProxy typedef (*runtime.Instance)
/// when the navigable had no realm context and createChildNavigable failed,
/// or when its realm had no Window. A navigation whose new realm could not
/// be made leaves no realm context (replaceRealm: the old one is released,
/// and attachRealm fails); out of memory, createChildNavigable fails too.
/// Script and Zig callers then read the struct's bytes as a Window's state:
/// probably the "Document with no internal state" lane leaks4 saw through
/// contentWindow (not proven - lane/int4 reads it with memory to spare,
/// and rebuilds the frame).
/// What the Browser holds of c_allocator: its live blocks and bytes. It sits
/// under the FailingAllocator, so it counts only what was handed out; the
/// Browser may allocate from more than one thread, hence the atomics.
///
/// It also records where each live block was allocated - a short stack, and
/// the sweep round it was made in (`round`) - so that a leak names its sites
/// (`printSites`). The record lives in c_allocator directly, behind a spin
/// lock (the Browser's threads), and is not counted.
const CountingAllocator = struct {
    live_count: std.atomic.Value(usize) = .init(0),
    live_bytes: std.atomic.Value(usize) = .init(0),
    /// The round the test is in: each block records it.
    round: std.atomic.Value(u32) = .init(0),
    sites: std.AutoHashMapUnmanaged(usize, Site) = .empty,
    sites_lock: std.atomic.Value(bool) = .init(false),
    /// Each round's induced failure: the failing allocation's stack.
    failures: std.AutoHashMapUnmanaged(u32, [site_frames]usize) = .empty,

    /// Frames kept per block, from the caller of the allocator's interface.
    const site_frames = 12;
    const Site = struct { len: usize, round: u32, frames: [site_frames]usize };

    fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn deinit(self: *CountingAllocator) void {
        self.sites.deinit(std.heap.c_allocator);
        self.failures.deinit(std.heap.c_allocator);
    }

    /// The current round's failing allocation's stack, for `printSites`.
    fn noteFailure(self: *CountingAllocator, trace: std.debug.StackTrace) void {
        var frames: [site_frames]usize = @splat(0);
        const n = @min(site_frames, trace.return_addresses.len);
        @memcpy(frames[0..n], trace.return_addresses[0..n]);
        self.failures.put(std.heap.c_allocator, self.round.load(.monotonic), frames) catch {};
    }

    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    const backing = std.heap.c_allocator;

    fn lockSites(self: *CountingAllocator) void {
        while (self.sites_lock.cmpxchgWeak(false, true, .acquire, .monotonic) != null) std.atomic.spinLoopHint();
    }

    fn unlockSites(self: *CountingAllocator) void {
        self.sites_lock.store(false, .release);
    }

    fn record(self: *CountingAllocator, address: usize, len: usize, ret_addr: usize) void {
        var site: Site = .{ .len = len, .round = self.round.load(.monotonic), .frames = @splat(0) };
        const trace = std.debug.captureCurrentStackTrace(.{ .first_address = ret_addr }, &site.frames);
        if (trace.return_addresses.len == 0) site.frames[0] = ret_addr;
        self.lockSites();
        defer self.unlockSites();
        self.sites.put(std.heap.c_allocator, address, site) catch {};
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const result = backing.rawAlloc(len, alignment, ret_addr) orelse return null;
        _ = self.live_count.fetchAdd(1, .monotonic);
        _ = self.live_bytes.fetchAdd(len, .monotonic);
        self.record(@intFromPtr(result), len, ret_addr);
        return result;
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        if (!backing.rawResize(memory, alignment, new_len, ret_addr)) return false;
        self.moved(memory.len, new_len);
        self.lockSites();
        defer self.unlockSites();
        if (self.sites.getPtr(@intFromPtr(memory.ptr))) |site| site.len = new_len;
        return true;
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const result = backing.rawRemap(memory, alignment, new_len, ret_addr) orelse return null;
        self.moved(memory.len, new_len);
        self.lockSites();
        defer self.unlockSites();
        if (self.sites.fetchRemove(@intFromPtr(memory.ptr))) |entry| {
            var site = entry.value;
            site.len = new_len;
            self.sites.put(std.heap.c_allocator, @intFromPtr(result), site) catch {};
        }
        return result;
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        {
            self.lockSites();
            defer self.unlockSites();
            _ = self.sites.remove(@intFromPtr(memory.ptr));
        }
        backing.rawFree(memory, alignment, ret_addr);
        _ = self.live_count.fetchSub(1, .monotonic);
        _ = self.live_bytes.fetchSub(memory.len, .monotonic);
    }

    /// The kinds of block the queued traceChild wrap-failure leak leaves
    /// (sweepContentWindow): an object handed to a traced edge whose wrapper
    /// could not be made. Each is named by the impl file its allocation
    /// stack passes through.
    ///
    /// CustomElementRegistry (Document.ensureGlobalRegistry, under a new
    /// Window's setDocument) is the fifth: macOS under -Dsanitize-thread, 3
    /// runs of 3, round 229, whose failure was WrapperCache.set under
    /// Document.zig's traceChild (lane v8up b3i).
    const known_leak_kinds = [_][]const u8{
        "/impls/AbortController.zig:",
        "/impls/CustomElementRegistry.zig:",
        "/impls/NavigateEvent.zig:",
        "/impls/NavigationDestination.zig:",
        "/impls/Performance.zig:",
    };

    /// The list is CLOSED: a block of any other kind fails the sweep, until
    /// its kind is added here by name, with its round's failure stack in the
    /// commit that adds it (the integrator's ruling, lane v8up b3i).
    ///
    /// The known leak kind a block allocated at `frames` is of - the index in
    /// `known_leak_kinds` of the first its stack, symbolized, passes through -
    /// or null.
    fn knownLeakKind(frames: [site_frames]usize) ?usize {
        return stackPassesThrough(frames, &known_leak_kinds);
    }

    /// `known_leak_kinds[i]`'s interface name ("/impls/X.zig:" -> "X").
    fn kindName(i: usize) []const u8 {
        const kind = known_leak_kinds[i];
        return kind["/impls/".len .. kind.len - ".zig:".len];
    }

    /// Whether round `round`'s induced allocation failure was the queued
    /// leak's cause: the wrap of a traced child, failing under the engine's
    /// traceChild (protocol_tracing.traceChild -> support.relevantWrapper ->
    /// wrapInstanceAsV8Object -> WrapperCache.set).
    fn failedInTraceChild(self: *const CountingAllocator, round: u32) bool {
        const failed = self.failures.get(round) orelse return false;
        return stackPassesThrough(failed, &.{"/protocol_tracing.zig:"}) != null;
    }

    /// The index of the first of `needles` (file names) the stack `frames`,
    /// symbolized, passes through, or null.
    fn stackPassesThrough(frames: [site_frames]usize, needles: []const []const u8) ?usize {
        var len: usize = 0;
        while (len < site_frames and frames[len] != 0) len += 1;
        var addresses = frames;
        var buffer: [16 * 1024]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        std.debug.writeStackTrace(&.{ .return_addresses = addresses[0..len], .skipped = .none }, .{ .writer = &writer, .mode = .no_color }) catch {};
        const text = writer.buffered();
        for (needles, 0..) |needle, i| {
            if (std.mem.indexOf(u8, text, needle) != null) return i;
        }
        return null;
    }

    const Summary = struct {
        known: usize = 0,
        unknown: usize = 0,
        /// The known blocks by kind, `known_leak_kinds`' order.
        by_kind: [known_leak_kinds.len]usize = @splat(0),
    };

    /// Print the live blocks' allocation sites (every round's, or only
    /// `only_round`'s), grouped by stack, the most blocks first: each
    /// group's count, bytes and rounds, then its stack (the first `max`
    /// groups; with `classify`, every group of an unknown kind). With
    /// `classify`, also count the blocks of a known leak kind and the rest.
    fn printSites(self: *CountingAllocator, only_round: ?u32, max: usize, classify: bool) Summary {
        var summary: Summary = .{};
        const Group = struct { frames: [site_frames]usize, count: usize, bytes: usize, first_round: u32, last_round: u32 };
        var groups: std.AutoHashMapUnmanaged([site_frames]usize, Group) = .empty;
        defer groups.deinit(std.heap.c_allocator);
        {
            self.lockSites();
            defer self.unlockSites();
            var it = self.sites.valueIterator();
            while (it.next()) |site| {
                if (only_round) |r| if (site.round != r) continue;
                const entry = groups.getOrPut(std.heap.c_allocator, site.frames) catch return summary;
                if (!entry.found_existing) entry.value_ptr.* = .{ .frames = site.frames, .count = 0, .bytes = 0, .first_round = site.round, .last_round = site.round };
                entry.value_ptr.count += 1;
                entry.value_ptr.bytes += site.len;
                entry.value_ptr.first_round = @min(entry.value_ptr.first_round, site.round);
                entry.value_ptr.last_round = @max(entry.value_ptr.last_round, site.round);
            }
        }
        var list: std.ArrayListUnmanaged(Group) = .empty;
        defer list.deinit(std.heap.c_allocator);
        var it = groups.valueIterator();
        while (it.next()) |group| list.append(std.heap.c_allocator, group.*) catch return summary;
        std.mem.sort(Group, list.items, {}, struct {
            fn more(_: void, a: Group, b: Group) bool {
                return if (a.count != b.count) a.count > b.count else a.bytes > b.bytes;
            }
        }.more);
        std.debug.print("live blocks by allocation site ({d} sites):\n", .{list.items.len});
        for (list.items, 0..) |group, i| {
            // Of the queued leak: a known kind, allocated in rounds whose
            // induced failure was the wrap of a traced child (a group's first
            // and last round both).
            const kind: ?usize = if (!classify) null else if (knownLeakKind(group.frames)) |k|
                (if (self.failedInTraceChild(group.first_round) and self.failedInTraceChild(group.last_round)) k else null)
            else
                null;
            const known = kind != null;
            if (classify) {
                if (kind) |k| {
                    summary.known += group.count;
                    summary.by_kind[k] += group.count;
                } else summary.unknown += group.count;
            }
            if (i >= max and (!classify or known)) continue;
            std.debug.print("site {d}: {d} blocks, {d} bytes, rounds {d}-{d}{s}\n", .{ i, group.count, group.bytes, group.first_round, group.last_round, if (!classify) "" else if (known) " (known: the traceChild wrap-failure leak)" else " (NOT a known leak kind)" });
            var len: usize = 0;
            while (len < site_frames and group.frames[len] != 0) len += 1;
            var frames = group.frames;
            std.debug.dumpStackTrace(&.{ .return_addresses = frames[0..len], .skipped = .none });
            // Where round `first_round`'s allocation failed.
            if (self.failures.get(group.first_round)) |failed| {
                var failed_frames = failed;
                var failed_len: usize = 0;
                while (failed_len < site_frames and failed_frames[failed_len] != 0) failed_len += 1;
                std.debug.print("site {d}: round {d}'s allocation failed at:\n", .{ i, group.first_round });
                std.debug.dumpStackTrace(&.{ .return_addresses = failed_frames[0..failed_len], .skipped = .none });
            }
        }
        return summary;
    }

    fn moved(self: *CountingAllocator, old_len: usize, new_len: usize) void {
        if (new_len >= old_len) {
            _ = self.live_bytes.fetchAdd(new_len - old_len, .monotonic);
        } else {
            _ = self.live_bytes.fetchSub(old_len - new_len, .monotonic);
        }
    }

    const Live = struct { count: usize, bytes: usize };

    fn live(self: *const CountingAllocator) Live {
        return .{ .count = self.live_count.load(.monotonic), .bytes = self.live_bytes.load(.monotonic) };
    }
};

/// The contentWindow sweep, then its leak check. The check is per SWEEP,
/// after the Browser's teardown, and not per round, because one Browser runs
/// every round and a round legitimately leaves the Browser holding more than
/// it held at its start. Each navigation that commits (the sweep's last
/// round, and the navigation with memory to spare after a round whose new
/// realm failed) replaces the frame's session history entry and its
/// document state. A
/// navigated-away realm and its Window are freed only when V8 collects the
/// old global and the deferred teardown's slices run from the event loop; and
/// the frame's new document stays. All of it is the Browser's until
/// Browser.deinit. So every block the Browser took from c_allocator during
/// the whole sweep is back when it is torn down: live count and bytes equal
/// their values before Browser.init (zero) - but for one known, queued leak.
///
/// Lane v8up b3h named the 24 blocks (chat2; 26 on server1) left after the
/// teardown with the allocation sites CountingAllocator records:
/// - 10 (13 on server1) were LocationImpl.init's: a failed URL parse left its
///   internal state and URL record (a new Window's Location, made under
///   attachRealm). Fixed there with errdefers
///   (tests/html/v8up_location_init_oom_test.zig).
/// - The rest, 14 on chat2 and 13 on server1, are the TRACECHILD
///   WRAP-FAILURE LEAK, queued (lane-v8up-handoff.md, "QUEUE ENTRY:
///   traceChild drops a child whose wrap failed"; feature queue; lane wrap1).
///   engine.traceChild wraps the child in its relevant realm, and WrapperCache.set's
///   CacheEntry allocation fails (under protocol_tracing.traceChild ->
///   support.relevantWrapper -> wrapInstanceAsV8Object). traceChild then
///   returns with no edge and the child unwrapped, while its owner has handed it to the
///   edge: nothing frees it. Four kinds of block, by the impl their
///   allocation passes through: AbortController and NavigateEvent
///   (Navigation's innerFire), NavigationDestination (makeDestination) and
///   Performance (Window.settingsPerformance).
/// So after the teardown every live block must be one of those kinds AND
/// come from rounds whose induced failure was that wrap (its failure stack
/// passes through protocol_tracing.traceChild): a block from any other site,
/// or of a known kind left by a round that failed anywhere else, fails the
/// test with its stack (error.BrowserLeftMemory). When the queue entry is
/// fixed, this check is zero again.
///
/// Not a block count. b3h capped the known blocks at 14 (chat2's one
/// measurement), and the count is not a constant of the tree: which rounds'
/// failures land in a traceChild wrap depends on when collections and the
/// deferred teardown's slices run, which allocate too. The gate at b3i's tip
/// (chat2) left 15 in the full test run and 13-14 alone (FLAKY), 13 + the
/// fifth kind under -Dsanitize-thread, and 13 on server1. The cause check is
/// exact where the count was not (lane v8up b3i).
fn sweepContentWindow(rounds: usize) !void {
    var counting: CountingAllocator = .{};
    defer counting.deinit();
    const start = counting.live();
    try sweepContentWindowOn(&counting, rounds);
    const end = counting.live();
    var summary: CountingAllocator.Summary = .{};
    if (end.count != start.count or end.bytes != start.bytes) {
        std.debug.print("the sweep's Browser, torn down, still holds {d} blocks ({d} bytes) of c_allocator; it held {d} ({d}) before Browser.init\n", .{ end.count, end.bytes, start.count, start.bytes });
        summary = counting.printSites(null, 16, true);
    }
    // Every run, pass or fail: what the queued leak was allowed to leave, by
    // kind - not capped, so the debt shows in the log (the integrator's
    // ruling, lane v8up b3i).
    std.debug.print("allowed: {d} blocks of the queued traceChild wrap-failure leak (", .{summary.known});
    for (summary.by_kind, 0..) |count, i| std.debug.print("{s}{s} {d}", .{ if (i == 0) "" else ", ", CountingAllocator.kindName(i), count });
    std.debug.print("); {d} of no known kind or cause\n", .{summary.unknown});
    if (summary.unknown > 0) return error.BrowserLeftMemory;
}

fn sweepContentWindowOn(counting: *CountingAllocator, rounds: usize) !void {
    var failing = std.testing.FailingAllocator.init(counting.allocator(), .{});
    const browser = try browser_mod.Browser.init(failing.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    // Out-of-memory rounds may leave a tree held (an OOM path elsewhere may leak, which is not this test's).
    @import("dom").refcount_teardown.allowLiveNodesAtAgentEnd(&browser.agent_host.deferred_teardown, "out-of-memory rounds may leave a tree held");
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(page_html, .{ .base_url = "https://example.test/page.html" });
    _ = try browser.runEventLoopBlocking(50);
    const realm = browser.getRealm() orelse return error.NoRealm;
    // The element, read with memory to spare: it stays in the page.
    const owned = try page.evaluateScript(Navigation.srcdoc.frame());
    defer owned.release();
    const iframe = engine.convertToPlatformObject(realm, owned.value) orelse return error.NoIframe;
    // Its browsing context and navigable, which live as long as the element.
    const first_window = (try interfaces.HTMLIFrameElement.get_contentWindow(iframe)) orelse return error.NoWindow;
    const bc = dom.browser_state.browsingContextOf(first_window) orelse return error.NoBrowsingContext;
    const integration = dom.navigables.integrationOf(@ptrCast(bc)) orelse return error.NoNavigable;

    var round: usize = 0;
    var replacements_failed: usize = 0;
    // The bound on what one round that commits no navigation may leave the
    // Browser holding (sweepContentWindow says why the zero check is per
    // sweep). Measured by lane v8up: at most 59 blocks, at failing
    // allocation 121, on chat2 and on server1, before and after
    // settleRealmReplacement. The bound is twice that, so runaway growth
    // fails with its round's number. What those 59 are (b3h, by allocation
    // site): the navigation the round left in flight - its navigate record
    // (2,328 bytes), the three policy container clones a navigation makes
    // (the source snapshot's, "navigate" step 4; the navigation params',
    // "determine navigation params policy container"; the history entry's),
    // each with its CSP list's policies, the history step record
    // (apply_history_step), and the navigate event's destination. The next
    // round's navigation replaces that one and frees them all: at the
    // sweep's end one block of the round is live, the round's srcdoc value
    // in the attribute value table, which Browser.deinit frees.
    const round_growth_bound: usize = 2 * 59;
    var committed: usize = 0;
    const history_start = try historyLength(page, realm);
    var proxy_handed_on: usize = 0;
    var abandoned: usize = 0;
    while (round < rounds) : (round += 1) {
        counting.round.store(@intCast(round + 1), .monotonic);
        // "Allowed to perform a navigation" (200 per 10 s) would stop the
        // sweep's navigations partway (lane nav1): not this test's.
        bc.navigation_rate_count = 0;
        const failed_before = integration.realm_replacements_failed;
        const abandoned_before = integration.realm_replacements_abandoned;
        const live_before = counting.live();
        const shown_before = frameDocumentStamp(iframe);
        var extra_navigations: usize = 0;
        failing.has_induced_failure = false;
        failing.fail_index = failing.alloc_index + round;
        page.runScript(Navigation.srcdoc.script()) catch {};
        _ = browser.runEventLoopBlocking(50) catch {};
        const induced = failing.has_induced_failure;
        if (induced) counting.noteFailure(failing.getStackTrace());
        // Read with memory out still: the frame's document, through the browsing context's active window.
        const shown_after = frameDocumentStamp(iframe);
        // Still out of memory: what the frame answers now - a Window, never
        // null and never its WindowProxy struct. A navigation that failed
        // left the frame on the Window it had.
        const window = interfaces.HTMLIFrameElement.get_contentWindow(iframe) catch null;
        failing.fail_index = std.math.maxInt(usize);
        const w = window orelse {
            std.debug.print("failing allocation {d}: the frame answers no Window\n", .{round});
            return error.FrameLeftWithoutAWindow;
        };
        if (!std.mem.eql(u8, w.vtable.name, "Window")) {
            std.debug.print("failing allocation {d}: contentWindow answered something that is not a Window\n", .{round});
            return error.NotAWindow;
        }
        const replacement_failed = integration.realm_replacements_failed != failed_before;
        if (replacement_failed) replacements_failed += 1;
        if (integration.realm_replacements_abandoned != abandoned_before) abandoned += 1;
        // A navigation whose new realm could not be made, or whose new realm
        // was undone because it stopped before the new Window had its
        // document, leaves the navigable exactly as it was: the same Window
        // shows the same document (HTMLIFrameElement settleRealmReplacement).
        // A new Window with no document is never left behind: every Window
        // has its associated Document ("create and initialize a Document
        // object" step 10).
        if (replacement_failed and !std.meta.eql(shown_before, shown_after)) {
            std.debug.print("failing allocation {d}: a navigation whose new realm failed changed what the frame shows\n", .{round});
            return error.NavigableChanged;
        }
        // No realm is ended while the browsing context answers its Window as
        // its active window.
        if (bc.getActiveWindow()) |raw_active| {
            const active: *runtime.Instance = @ptrCast(@alignCast(raw_active));
            if (runtime.instance_lifecycle.isCleanupStarted(active)) {
                std.debug.print("failing allocation {d}: the active window's realm was ended\n", .{round});
                return error.ActiveWindowEnded;
            }
        }
        // With memory to spare: the Window works - script reads its document.
        if (!try frameWindowWorks(page, realm)) {
            // Only a round whose new realm failed AFTER the engine handed
            // the WindowProxy on (window_proxy_of detaches the old global
            // before the new context is made, and V8 cannot attach it
            // again): the frame keeps its old realm and Window, which its
            // own script still reaches, but the proxy reaches no Window
            // until the next navigation. That navigation must complete and
            // give script a Window that works.
            if (!replacement_failed) {
                std.debug.print("failing allocation {d}: the frame's Window does not answer script\n", .{round});
                return error.WindowDoesNotWork;
            }
            // What script observes then, exactly: a proxy with no global,
            // whose member reads throw a TypeError.
            if (!try frameProxyHasNoGlobal(page, realm)) {
                std.debug.print("failing allocation {d}: the handed-on proxy is not one with no global (a TypeError on member reads)\n", .{round});
                std.debug.dumpStackTrace(&failing.getStackTrace());
                return error.UnexpectedProxyState;
            }
            proxy_handed_on += 1;
            try navigatesWithMemoryToSpare(browser, page, iframe, bc);
            extra_navigations += 1;
            if (!try frameWindowWorks(page, realm)) {
                std.debug.print("failing allocation {d}: the frame's next Window does not answer script\n", .{round});
                return error.WindowDoesNotWork;
            }
        } else if (replacement_failed and replacements_failed == 1) {
            // The first round whose new realm could not be made: the frame
            // is on its old realm, and a navigation with memory to spare
            // completes.
            try navigatesWithMemoryToSpare(browser, page, iframe, bc);
            extra_navigations += 1;
        }
        const round_committed: usize = @intFromBool(!std.meta.eql(shown_before, shown_after)) + extra_navigations;
        committed += round_committed;
        if (round_committed == 0) {
            const live_after = counting.live();
            if (live_after.count > live_before.count + round_growth_bound) {
                std.debug.print("failing allocation {d}: a round that committed nothing left the Browser {d} blocks more ({d} -> {d})\n", .{ round, live_after.count - live_before.count, live_before.count, live_after.count });
                return error.RoundKeptTooMuch;
            }
        }
        if (!induced) break;
    }
    // The sweep reached the paths it is for. Each check counts the path,
    // not an effect of it. (It used to require a round that left the frame
    // with no Window at all, the state that path made, which was itself the
    // bug.) Two kinds, each at least once:
    // - a round whose new realm could not be made;
    // - a round that stopped after its new realm was made and before the
    //   new Window had its document (realm_replacements_abandoned).
    // Both failed after the WindowProxy hand-on. A counted failure BEFORE
    // the hand-on cannot happen on this path. createWindowRealm hands the
    // proxy on before its first fallible Crane allocation (its ORDER
    // comment). replaceRealm's one earlier allocation, the copy of the
    // creation origin, fails before the old realm is released, like any
    // earlier step of the navigation. That round counts nothing, and its
    // own checks cover it: the Window works (lane v8up b3g).
    if (proxy_handed_on == 0) return error.NoRoundFailedAfterTheHandOn;
    if (replacements_failed == abandoned) return error.NoRealmCreationFailed;
    if (abandoned == 0) return error.NoRoundStoppedBeforeTheDocument;
    std.log.info("rounds whose new realm failed: {d}, of which stopped before the document: {d}", .{ replacements_failed, abandoned });
    // And after the whole sweep, the frame still navigates.
    counting.round.store(9000, .monotonic);
    try navigatesWithMemoryToSpare(browser, page, iframe, bc);
    committed += 1;
    // Every navigation that committed replaced the frame's session history
    // entry. Each one goes to about:srcdoc, the URL of the frame's active
    // document, from the frame's own origin, so HTML "navigate" turns its
    // "auto" history handling into "replace". The page's history.length is
    // therefore what it was. Lane v8up b3g measured 123 committed
    // navigations on chat2, and the length stayed 1. (b3f expected one
    // pushed entry for each of them.)
    const history_end = try historyLength(page, realm);
    if (history_end != history_start) {
        std.debug.print("the joint session history changed from {d} to {d} entries over {d} committed srcdoc navigations, each of which replaces\n", .{ history_start, history_end, committed });
        return error.HistoryChanged;
    }
}

/// Whether script in the page reads the frame's Window: its document's body.
fn frameWindowWorks(page: anytype, realm: runtime.Context) !bool {
    const owned = try page.evaluateScript("(() => { try { const w = document.getElementById('s').contentWindow; return w !== null && w.document !== undefined && w.document.body !== undefined; } catch (e) { return false; } })()");
    defer owned.release();
    return engine.toBoolean(realm, owned.value);
}

/// Whether script sees the frame's WindowProxy with no global behind it:
/// an object whose member reads throw the accessing realm's TypeError, and
/// nothing else. V8 checks access to a global proxy detached from the
/// current global (JSObject::IsAccessCheckNeeded); a detached proxy's map
/// has no constructor, so no access-check info, and V8 then throws
/// TypeError "no access" itself (Isolate::ReportFailedAccessCheck) - the
/// host's check (cross_origin.zig) is never asked. Lane v8up b3f found two
/// other answers before protocol_realms.createWindowRealm detached a failed
/// context's global: a failure after Context::New left the proxy on the
/// half-made global, where reads gave a SecurityError or undefined
/// depending on how far the realm got (server1 b3e; chat2 and server1 at
/// failing allocations 144 and 143). Prints what script saw otherwise.
fn frameProxyHasNoGlobal(page: anytype, realm: runtime.Context) !bool {
    const owned = try page.evaluateScript(
        \\(() => {
        \\  const w = document.getElementById('s').contentWindow;
        \\  if (w === null) return 'contentWindow is null';
        \\  if (typeof w !== 'object') return 'contentWindow is a ' + typeof w;
        \\  try { const d = w.document; return 'w.document did not throw: ' + String(d); }
        \\  catch (e) { return (e instanceof DOMException ? 'DOMException ' : 'not a DOMException ') + (e && e.name) + ': ' + (e && e.message); }
        \\})()
    );
    defer owned.release();
    const seen = try engine.convertToDOMString(realm, owned.value, testing.allocator);
    defer testing.allocator.free(seen);
    if (std.mem.eql(u8, seen, "not a DOMException TypeError: no access")) return true;
    std.debug.print("script saw through the frame's proxy: {s}\n", .{seen});
    return false;
}

/// What the frame shows: its active document and that document's slab
/// generation (a freed and reused block is a new document), or null.
fn frameDocumentStamp(iframe: *runtime.Instance) ?struct { *runtime.Instance, u64 } {
    const window = (interfaces.HTMLIFrameElement.get_contentWindow(iframe) catch return null) orelse return null;
    const document = interfaces.Window.get_document(window) catch return null;
    return .{ document, runtime.SlabAllocator.generationOf(document) };
}

/// The page's `history.length`: the joint session history's entry count.
fn historyLength(page: anytype, realm: runtime.Context) !usize {
    const owned = try page.evaluateScript("String(history.length)");
    defer owned.release();
    const text = try engine.convertToDOMString(realm, owned.value, testing.allocator);
    defer testing.allocator.free(text);
    return std.fmt.parseInt(usize, text, 10);
}

/// The srcdoc frame navigates with memory to spare: it shows a new document
/// within two seconds.
fn navigatesWithMemoryToSpare(browser: anytype, page: anytype, iframe: *runtime.Instance, bc: anytype) !void {
    bc.navigation_rate_count = 0;
    const before_window = (try interfaces.HTMLIFrameElement.get_contentWindow(iframe)) orelse return error.NoWindow;
    const before = interfaces.Window.get_document(before_window) catch null;
    const before_generation: u64 = if (before) |d| runtime.SlabAllocator.generationOf(d) else 0;
    try page.runScript(Navigation.srcdoc.script());
    for (0..40) |_| {
        _ = try browser.runEventLoopBlocking(50);
        const window = (try interfaces.HTMLIFrameElement.get_contentWindow(iframe)) orelse continue;
        const now = interfaces.Window.get_document(window) catch continue;
        if (now != before or runtime.SlabAllocator.generationOf(now) != before_generation) return;
    }
    std.debug.print("the frame did not navigate with memory to spare after a failed round\n", .{});
    return error.NothingNavigated;
}

test "an iframe's contentWindow out of memory after a failed navigation is its Window, never its WindowProxy struct, and the frame navigates again" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            sweepContentWindow(4000) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
