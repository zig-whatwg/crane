//! A Sanitizer named by a parsing method's options is held for the method
//! and released on every path (lane bind1, batch B5 group 2b).
//!
//! `sanitizer` is `(Sanitizer or SanitizerConfig or SanitizerPresets)`. The
//! binding converts it (WebIDL 3.2.25) before any step of the method, and its
//! Sanitizer member is a bare instance: the handle the member was read into
//! is gone when conversion returns. Trusted Types then runs the default
//! policy's createParserOptions - script, a collection included - BEFORE the
//! method reads that Sanitizer's configuration (HTML "get a sanitizer config
//! from options"), so html.sanitizer.Converted holds the Sanitizer
//! (engine.retainValue) from conversion until its deinit.
//!
//! A hold that an early return forgets is one global handle per call, and no
//! Zig allocator sees it. Each case runs a statement 64 times in a Browser's
//! page whose `<meta>` CSP requires Trusted Types, and reads V8's own count
//! of global handle bytes before and after (a first round makes what later
//! ones reuse; a collection between) - on success, when the callback throws,
//! when it returns null (the sink blocks), when the value it returns does not
//! convert, and when the configuration it returns is not valid. Each test has
//! a control: the same statement with a SanitizerConfig, which takes the same
//! path and holds nothing. One kept Global per call is 64 handles, 1 KiB.
//!
//! The form is tests/html/leaks6_navigation_api_handles_test.zig's.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const Browser = @import("browser").Browser;

const page_url = "https://bind1-hold.test/page.html";
const page_html =
    \\<!doctype html><head><meta http-equiv="Content-Security-Policy" content="require-trusted-types-for 'script'"></head><body><div id="t"></div>
;

/// The page's policies: a default policy and a named one, both with the same
/// createParserOptions, which does what `mode` says after counting the call.
const setup =
    \\(() => {
    \\  globalThis.calls = 0;
    \\  globalThis.mode = 'throw';
    \\  globalThis.s = new Sanitizer();
    \\  globalThis.t = document.getElementById('t');
    \\  const make = (options) => {
    \\    calls++;
    \\    switch (mode) {
    \\      case 'throw': throw new Error('policy threw');
    \\      case 'null': return null;
    \\      case 'no-preset': return { sanitizer: 'nope' };
    \\      case 'invalid': return { sanitizer: { elements: ['a'], removeElements: ['b'] } };
    \\      default: return options;
    \\    }
    \\  };
    \\  trustedTypes.createPolicy('default', { createParserOptions: make, createHTML: (x) => x });
    \\  globalThis.p = trustedTypes.createPolicy('p', { createParserOptions: make });
    \\  return 'ok';
    \\})()
;

const Page = struct {
    browser: *Browser,

    fn open(allocator: std.mem.Allocator) !Page {
        const browser = try Browser.init(allocator, .{ .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML(page_html, .{ .base_url = page_url });
        _ = try browser.runEventLoopBlocking(10);
        const self: Page = .{ .browser = browser };
        try self.expect(setup, "ok");
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

/// `call` - an expression taking its options from `x` - in `mode`: first
/// what it does with the page's Sanitizer (whether the callback ran, and the
/// result or the thrown value's name), then the handles 64 such calls leave.
fn expectReleased(page: Page, comptime mode: []const u8, comptime call: []const u8, comptime outcome: []const u8) !void {
    try page.expect("mode = '" ++ mode ++ "'", mode);
    try page.expect("(() => { const before = calls; let x = { sanitizer: s }; let r; try { " ++ call ++ "; r = 'returned'; } catch (e) { r = e.name; } return r + (calls > before ? ', callback ran' : ', no callback'); })()", outcome);
    try expectNoHandlesLeft(page, call ++ " in mode " ++ mode ++ ", a Sanitizer", "{ let x = { sanitizer: s }; try { " ++ call ++ "; } catch (e) {} }");
}

/// The control: `call` with a SanitizerConfig, which takes the same path
/// and holds nothing.
fn expectControl(page: Page, comptime mode: []const u8, comptime call: []const u8) !void {
    try page.expect("mode = '" ++ mode ++ "'", mode);
    try expectNoHandlesLeft(page, call ++ " in mode " ++ mode ++ ", a SanitizerConfig", "{ let x = { sanitizer: { elements: [] } }; try { " ++ call ++ "; } catch (e) {} }");
}

/// `call` with a Sanitizer nothing but the options' getter ever named: the
/// hold is all that keeps it until the method reads its configuration.
fn expectReleasedFromGetter(page: Page, comptime mode: []const u8, comptime call: []const u8) !void {
    try page.expect("mode = '" ++ mode ++ "'", mode);
    try expectNoHandlesLeft(page, call ++ " in mode " ++ mode ++ ", a Sanitizer from a getter", "{ let x = { get sanitizer() { return new Sanitizer(); } }; try { " ++ call ++ "; } catch (e) {} }");
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

test "bind1 sanitizer hold: released when the default policy's createParserOptions throws" {
    try withPage(struct {
        fn body(page: Page) !void {
            const call = "t.setHTMLUnsafe('<b>x</b>', x)";
            try expectControl(page, "throw", call);
            // The hold is taken at conversion; the callback throws after it.
            try expectReleased(page, "throw", call, "Error, callback ran");
            try expectReleasedFromGetter(page, "throw", call);
            try expectReleased(page, "throw", "Document.parseHTMLUnsafe('<b>x</b>', x)", "Error, callback ran");
        }
    }.body);
}

test "bind1 sanitizer hold: released when the callback returns null and the sink blocks, when its value does not convert, and when it names no valid configuration" {
    try withPage(struct {
        fn body(page: Page) !void {
            const call = "t.setHTMLUnsafe('<b>x</b>', x)";
            try expectControl(page, "null", call);
            try expectReleased(page, "null", call, "TypeError, callback ran");
            // The return value's conversion throws: "nope" is no preset.
            try expectReleased(page, "no-preset", call, "TypeError, callback ran");
            // The sanitizer throws: elements and removeElements together.
            try expectReleased(page, "invalid", call, "TypeError, callback ran");
        }
    }.body);
}

test "bind1 sanitizer hold: released on success, with and without a Trusted Types callback" {
    try withPage(struct {
        fn body(page: Page) !void {
            const call = "t.setHTMLUnsafe('<b>x</b>', x)";
            try expectControl(page, "pass", call);
            // The callback returns its argument: a TrustedHTMLParserOptions
            // made from the Sanitizer the argument carries.
            try expectReleased(page, "pass", call, "returned, callback ran");
            try expectReleasedFromGetter(page, "pass", call);
            try expectReleased(page, "pass", "Document.parseHTMLUnsafe('<b>x</b>', x)", "returned, callback ran");
            // The safe methods run no createParserOptions.
            try expectReleased(page, "pass", "t.setHTML('<b>x</b>', x)", "returned, no callback");
            try expectReleased(page, "pass", "Document.parseHTML('<b>x</b>', x)", "returned, no callback");
        }
    }.body);
}

test "bind1 sanitizer hold: released by TrustedTypePolicy.createParserOptions, whether its callback returns or throws" {
    try withPage(struct {
        fn body(page: Page) !void {
            const call = "p.createParserOptions(x)";
            try expectControl(page, "pass", call);
            try expectReleased(page, "pass", call, "returned, callback ran");
            try expectReleased(page, "throw", call, "Error, callback ran");
            try expectReleased(page, "null", call, "TypeError, callback ran");
            try expectReleased(page, "invalid", call, "TypeError, callback ran");
        }
    }.body);
}
