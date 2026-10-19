//! The navigation API keeps no JavaScript handle when one of its methods
//! throws or returns an early error (lane leaks6, item 2).
//!
//! navigation-api/ left 16 Globals under leaks --atExit (lane leaks5's
//! follow-up 2), in three families:
//!
//! - navigate() and reload() with a state that cannot be serialized: the
//!   thrown value engine.completionOf hands back (v8_RunCatching) became
//!   the early error result's reason and was never released - 10;
//! - NavigationPrecommitController.addHandler() that throws: the handler
//!   argument (v8_FunctionCallbackInfo_GetArgument) the binding hands over
//!   was taken only on success - 4;
//! - NavigateEvent.intercept() that throws: the handler and precommitHandler
//!   the options dictionary hands over (v8_Object_Get) likewise - 2.
//!
//! Each test runs a statement 64 times in a Browser's page and reads V8's own
//! count of global handle bytes before and after (a first round makes what
//! later ones reuse; a collection between), against a control that takes the
//! same path with nothing to keep. One kept Global per call is 64 handles,
//! at least 1 KiB.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const Browser = @import("browser").Browser;

const page_url = "https://leaks6.test/page.html";

fn ignoreReport(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

const Page = struct {
    browser: *Browser,

    fn open(allocator: std.mem.Allocator) !Page {
        const browser = try Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
        _ = try browser.runEventLoopBlocking(10);
        return .{ .browser = browser };
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
            var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
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

test "leaks6 navigation API: navigate() with an unserializable state keeps no handle" {
    try withPage(struct {
        fn body(page: Page) !void {
            // The early error result: both promises rejected with the
            // DataCloneError.
            try page.expect(
                \\(() => { const r = navigation.navigate('#a', { state: () => {} }); r.committed.catch(() => {}); r.finished.catch(() => {}); return 'ok'; })()
            , "ok");
            // The control: a navigate() that fails before serializing.
            try expectNoHandlesLeft(page, "navigate('javascript:')",
                \\{ const r = navigation.navigate('javascript:void 0', { info: 1 }); r.committed.catch(() => {}); r.finished.catch(() => {}); }
            );
            try expectNoHandlesLeft(page, "navigate(url, { state: function })",
                \\{ const r = navigation.navigate('#a', { state: () => {} }); r.committed.catch(() => {}); r.finished.catch(() => {}); }
            );
        }
    }.body);
}

test "leaks6 navigation API: reload() with an unserializable state keeps no handle" {
    try withPage(struct {
        fn body(page: Page) !void {
            try expectNoHandlesLeft(page, "reload({ state: function })",
                \\{ const r = navigation.reload({ state: () => {} }); r.committed.catch(() => {}); r.finished.catch(() => {}); }
            );
        }
    }.body);
}

test "leaks6 navigation API: a throwing NavigationPrecommitController.addHandler() keeps no handle" {
    try withPage(struct {
        fn body(page: Page) !void {
            // A precommit controller, kept past its navigation.
            try page.expect(
                \\navigation.addEventListener('navigate', e => {
                \\  if (e.cancelable) e.intercept({ precommitHandler: c => { globalThis.ctl = c; } });
                \\}, { once: true });
                \\navigation.navigate('#p').finished.catch(() => {});
                \\'ok'
            , "ok");
            try page.settle();
            try page.expect("typeof globalThis.ctl", "object");
            try page.expect("(() => { try { ctl.addHandler(() => {}); return 'no throw'; } catch (e) { return e.name; } })()", "InvalidStateError");
            // The control: the same throw, given no function.
            try expectNoHandlesLeft(page, "addHandler(undefined)", "try { ctl.addHandler(undefined); } catch (e) {}");
            try expectNoHandlesLeft(page, "addHandler(function)", "try { ctl.addHandler(() => {}); } catch (e) {}");
        }
    }.body);
}

test "leaks6 navigation API: a throwing NavigateEvent.intercept() keeps no handle" {
    try withPage(struct {
        fn body(page: Page) !void {
            // A navigate event, kept past its dispatch.
            try page.expect(
                \\navigation.addEventListener('navigate', e => { globalThis.ev = e; }, { once: true });
                \\navigation.navigate('#q').finished.catch(() => {});
                \\'ok'
            , "ok");
            try page.settle();
            try page.expect("typeof globalThis.ev", "object");
            try page.expect("(() => { try { ev.intercept({ handler() {} }); return 'no throw'; } catch (e) { return e.name; } })()", "InvalidStateError");
            try expectNoHandlesLeft(page, "intercept({})", "try { ev.intercept({}); } catch (e) {}");
            try expectNoHandlesLeft(page, "intercept({ handler })", "try { ev.intercept({ handler() {} }); } catch (e) {}");
            try expectNoHandlesLeft(page, "intercept({ precommitHandler })", "try { ev.intercept({ precommitHandler() {} }); } catch (e) {}");
        }
    }.body);
}
