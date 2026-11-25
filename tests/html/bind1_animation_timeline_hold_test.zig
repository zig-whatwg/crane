//! animate()'s `timeline` member is held from conversion until the new
//! Animation keeps it, and released on every path (lane bind1, batch B5
//! group 3b).
//!
//! `options` is `(unrestricted double or KeyframeAnimationOptions)`. The
//! binding converts it (WebIDL 3.2.25) before any step of animate(), and
//! its timeline member is a bare instance: the handle the member was read
//! into is gone when conversion returns. animate() then runs "process a
//! keyframes argument" - the keyframes' getters and iterators, script that
//! may collect - before step 4 gives the timeline to the new Animation,
//! whose traced edge keeps it from then on. So dom.animations.options
//! holds the timeline (engine.retainValue) until EffectOptions.deinit.
//!
//! A hold that an early return forgets is one global handle per call, and no
//! Zig allocator sees it: the counted cases run a statement 64 times and
//! read V8's own count of global handle bytes before and after (a first
//! round makes what later ones reuse; a collection between) - on success
//! and when a later step throws. The form is
//! tests/html/leaks6_navigation_api_handles_test.zig's.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const Browser = @import("browser").Browser;

const page_url = "https://bind1-timeline.test/page.html";

const Page = struct {
    browser: *Browser,

    fn open(allocator: std.mem.Allocator) !Page {
        const browser = try Browser.init(allocator, .{ .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body><div id=t></div>", .{ .base_url = page_url });
        _ = try browser.runEventLoopBlocking(10);
        const self: Page = .{ .browser = browser };
        try self.expect("globalThis.t = document.getElementById('t'); globalThis.tl = new DocumentTimeline({ originTime: 1e9 }); 'ok'", "ok");
        return self;
    }

    fn close(self: Page) void {
        self.browser.deinit();
    }

    fn realm(self: Page) !runtime.Context {
        return self.browser.getRealm() orelse error.NoRealm;
    }

    fn run(self: Page, source: []const u8) ![]u8 {
        const page = self.browser.current_context orelse return error.NoPage;
        return page.evaluateScriptToString(source, self.browser.allocator);
    }

    fn expect(self: Page, source: []const u8, want: []const u8) !void {
        const got = try self.run(source);
        defer self.browser.allocator.free(got);
        if (!std.mem.eql(u8, want, got)) std.debug.print("{s}\n  answered {s}\n", .{ source, got });
        try testing.expectEqualStrings(want, got);
    }

    fn settle(self: Page) !void {
        for (0..10) |_| _ = try self.browser.runEventLoopBlocking(10);
    }

    /// Two full collections with the page's realm entered, then the event
    /// loop turns that free what they collected - three times.
    fn collect(self: Page) !void {
        const realm_now = try self.realm();
        const Collect = struct {
            realm: runtime.Context,

            fn run(data: ?*anyopaque) void {
                const collect_in: *@This() = @ptrCast(@alignCast(data.?));
                if (collect_in.realm.agent) |agent| {
                    engine.requestGarbageCollection(agent);
                    engine.requestGarbageCollection(agent);
                }
            }
        };
        var entered: Collect = .{ .realm = realm_now };
        for (0..3) |_| {
            try engine.runInRealm(realm_now, Collect.run, &entered);
            try self.settle();
        }
    }

    /// V8's own count of the bytes its global handles use, read with the
    /// page's realm entered, after two collections.
    fn globalHandleBytes(self: Page) !i64 {
        const realm_now = try self.realm();
        const Probe = struct {
            value: ?i64 = null,
            allocator: std.mem.Allocator,
            realm: runtime.Context,

            fn read(data: ?*anyopaque) void {
                const probe: *@This() = @ptrCast(@alignCast(data.?));
                if (probe.realm.agent) |agent| {
                    engine.requestGarbageCollection(agent);
                    engine.requestGarbageCollection(agent);
                }
                const counters = engine.diagnosticCounters(probe.allocator) catch return;
                defer probe.allocator.free(counters);
                for (counters) |counter| {
                    if (std.mem.eql(u8, counter.name, "global_handle_bytes")) probe.value = counter.value;
                }
            }
        };
        var probe: Probe = .{ .allocator = self.browser.allocator, .realm = realm_now };
        try engine.runInRealm(realm_now, Probe.read, &probe);
        return probe.value orelse error.NoCounter;
    }

    /// The global handle bytes 64 runs of `statement` leave once a first
    /// round has made what later ones reuse.
    fn handleBytesLeftBy(self: Page, comptime statement: []const u8) !i64 {
        const loop = "(() => { for (let k = 0; k < 64; k++) { " ++ statement ++ "; } return 'ok'; })()";
        try self.expect(loop, "ok");
        try self.settle();
        const before = try self.globalHandleBytes();
        try self.expect(loop, "ok");
        try self.settle();
        const after = try self.globalHandleBytes();
        return after - before;
    }
};

/// Under one global handle per eight calls; one per call is 64 * 16 B.
const margin = 128;

fn expectNoHandlesLeft(page: Page, comptime label: []const u8, comptime statement: []const u8) !void {
    const left = try page.handleBytesLeftBy(statement);
    if (left >= margin) std.debug.print("{s}: {d} global handle bytes left over 64 calls\n", .{ label, left });
    try testing.expect(left < margin);
}

fn withPage(comptime body: fn (Page) anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            runBody() catch |err| {
                failure.* = err;
            };
        }

        fn runBody() !void {
            var debug: @import("root").poisoning.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
            defer if (debug.deinit() == .leak) @panic("leaked");
            const page = try Page.open(debug.allocator());
            defer page.close();
            try body(page);
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "bind1 animate() timeline: the member given, missing, null and a number argument" {
    try withPage(struct {
        fn body(page: Page) !void {
            // Web Animations 1 6.8 step 3: the timeline member, or with it
            // missing the default document timeline; a present null is no
            // timeline (Chrome 157, Firefox 159, Safari 27 - probe
            // tmp/probes/bind1-nullmember/report-g3.txt).
            try page.expect(
                \\(() => {
                \\  const given = t.animate(null, { timeline: tl, duration: 1000 });
                \\  const missing = t.animate(null, { duration: 1000 });
                \\  const none = t.animate(null, { timeline: null, duration: 1000 });
                \\  const number = t.animate(null, 1000);
                \\  const out = [given.timeline === tl, missing.timeline === document.timeline, none.timeline, number.timeline === document.timeline, number.effect.getTiming().duration];
                \\  for (const a of [given, missing, none, number]) a.cancel();
                \\  return out.join(' ');
                \\})()
            , "true true  true 1000");
            // A timeline that is no AnimationTimeline is the binding's
            // TypeError (WebIDL 3.2.18 converts the member as its type).
            try page.expect("(() => { try { t.animate(null, { timeline: {} }); return 'returned'; } catch (e) { return e.name; } })()", "TypeError");
        }
    }.body);
}

test "bind1 animate() timeline: a keyframes getter that drops the member and collects does not take it" {
    try withPage(struct {
        fn body(page: Page) !void {
            // The keyframes are read in step 2, after the options converted:
            // the getter deletes the only reference script had and collects.
            // The timeline is still the one given when step 4 runs.
            try page.expect(
                \\(() => {
                \\  const options = { timeline: new DocumentTimeline({ originTime: 1e9 }), duration: 1000 };
                \\  const keyframes = { get opacity() { delete options.timeline; TestUtils.gc(); TestUtils.gc(); return ['0', '1']; } };
                \\  globalThis.held = t.animate(keyframes, options);
                \\  return 'made';
                \\})()
            , "made");
            try page.collect();
            // Its origin time sets it apart from the document's timeline.
            try page.expect("[held.timeline instanceof DocumentTimeline, held.timeline !== document.timeline, held.timeline.currentTime < -1e8].join(' ')", "true true true");
            try page.expect("held.cancel(); 'ok'", "ok");
        }
    }.body);
}

test "bind1 animate() timeline: the hold is released when animate() returns and when a later step throws" {
    try withPage(struct {
        fn body(page: Page) !void {
            // The control: no timeline member, nothing held.
            try expectNoHandlesLeft(page, "no timeline", "t.animate(null, { duration: 1 }).cancel()");
            try expectNoHandlesLeft(page, "a timeline", "t.animate(null, { timeline: tl, duration: 1 }).cancel()");
            // Step 2 throws after the hold was taken: a pseudoElement that
            // is no pseudo-element (6.6 step 3, a SyntaxError) and a keyframe
            // getter's throw (step 7).
            try page.expect("(() => { try { t.animate(null, { timeline: tl, pseudoElement: '::bogus' }); return 'returned'; } catch (e) { return e.name; } })()", "SyntaxError");
            try expectNoHandlesLeft(page, "a timeline, then a SyntaxError", "try { t.animate(null, { timeline: tl, pseudoElement: '::bogus' }); } catch (e) {}");
            try page.expect("(() => { try { t.animate({ get opacity() { throw new RangeError('x'); } }, { timeline: tl }); return 'returned'; } catch (e) { return e.name; } })()", "RangeError");
            try expectNoHandlesLeft(page, "a timeline, then a keyframe getter's throw", "try { t.animate({ get opacity() { throw new RangeError('x'); } }, { timeline: tl }); } catch (e) {}");
        }
    }.body);
}
