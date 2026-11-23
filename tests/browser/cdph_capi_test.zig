//! The host API's C ABI (include/crane.h, src/browser/capi.zig; lane cdph),
//! called as a C embedder calls it: two Browsers on two threads, each with
//! its tabs and events, sharing nothing (the instances design's B6 measure:
//! "a C test runs two Browsers on two threads through the C ABI").
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const capi = @import("browser").capi;

const Events = struct {
    created: std.atomic.Value(u32) = .init(0),
    destroyed: std.atomic.Value(u32) = .init(0),

    fn onEvent(context: ?*anyopaque, event: *const capi.Event) callconv(.c) void {
        const self: *Events = @ptrCast(@alignCast(context.?));
        switch (event.kind) {
            @backingInt(capi.EventKind.tab_created) => _ = self.created.fetchAdd(1, .acq_rel),
            @backingInt(capi.EventKind.tab_destroyed) => _ = self.destroyed.fetchAdd(1, .acq_rel),
            else => {},
        }
    }
};

/// What one Browser's thread ended with: empty when every step passed, else
/// the step that did not and what it got - so a failure names itself (it
/// failed once on chat2 with no more said than a flag; lane flk4,
/// 2026-11-22). Each thread has its own; the test reads it after the join.
const Outcome = struct {
    buffer: [512]u8 = undefined,
    len: usize = 0,

    fn note(self: *Outcome, comptime format: []const u8, args: anytype) void {
        const written = std.fmt.bufPrint(&self.buffer, format, args) catch self.buffer[0..];
        self.len = written.len;
    }

    fn fail(self: *Outcome, comptime format: []const u8, args: anytype) error{StepFailed} {
        self.note(format, args);
        return error.StepFailed;
    }

    fn text(self: *const Outcome) []const u8 {
        return self.buffer[0..self.len];
    }
};

/// One embedder thread's whole use of a Browser.
fn useOneBrowser(outcome: *Outcome, marker: []const u8) void {
    run(outcome, marker) catch |err| {
        if (outcome.len == 0) outcome.note("browser {s}: {t}", .{ marker, err });
    };
}

fn run(outcome: *Outcome, marker: []const u8) !void {
    var events: Events = .{};
    var handle: ?*capi.Handle = null;
    const options: capi.BrowserOptions = .{ .struct_size = @sizeOf(capi.BrowserOptions), .on_event = Events.onEvent, .event_context = &events };
    const created = capi.crane_browser_create(&options, &handle);
    if (created != .ok) return outcome.fail("browser {s}: crane_browser_create: {t}", .{ marker, created });
    defer capi.crane_browser_destroy(handle);

    var tab: u64 = 0;
    const tab_status = capi.crane_tab_create(handle, "data:text/html,<title>c</title>", false, &tab);
    if (tab_status != .ok) return outcome.fail("browser {s}: crane_tab_create: {t}", .{ marker, tab_status });
    var navigated: capi.NavigateResult = .{};
    const navigate_status = capi.crane_tab_navigate(handle, tab, "data:text/html,<title>c2</title>", @backingInt(capi.Readiness.complete), &navigated);
    if (navigate_status != .ok) return outcome.fail("browser {s}: crane_tab_navigate: {t}", .{ marker, navigate_status });
    capi.crane_navigate_result_free(&navigated);

    var buffer: [128]u8 = undefined;
    const source = try std.fmt.bufPrint(&buffer, "globalThis.marker = '{s}'; document.title + ':' + marker", .{marker});
    var result: capi.EvaluateResult = .{};
    const evaluate_status = capi.crane_tab_evaluate(handle, tab, source.ptr, source.len, 0, &result);
    if (evaluate_status != .ok) return outcome.fail("browser {s}: crane_tab_evaluate: {t}", .{ marker, evaluate_status });
    defer capi.crane_evaluate_result_free(&result);
    const json: []const u8 = if (result.json) |j| std.mem.span(j) else "(null)";
    if (result.exception) return outcome.fail("browser {s}: the evaluation threw: {s}", .{ marker, json });
    var expected: [128]u8 = undefined;
    const want = try std.fmt.bufPrint(&expected, "{{\"type\":\"string\",\"value\":\"c2:{s}\"}}", .{marker});
    if (!std.mem.eql(u8, want, json)) return outcome.fail("browser {s}: the evaluation answered {s}, expected {s}", .{ marker, json, want });

    var infos: ?[*]capi.TabInfo = null;
    var count: usize = 0;
    const list_status = capi.crane_tab_list(handle, &infos, &count);
    if (list_status != .ok) return outcome.fail("browser {s}: crane_tab_list: {t}", .{ marker, list_status });
    defer capi.crane_tab_info_free(infos, count);
    if (count != 2) return outcome.fail("browser {s}: crane_tab_list listed {d} tabs, expected 2", .{ marker, count });

    const close_status = capi.crane_tab_close(handle, tab, false);
    if (close_status != .ok) return outcome.fail("browser {s}: crane_tab_close: {t}", .{ marker, close_status });
    const again = capi.crane_tab_close(handle, tab, false);
    if (again != .no_such_tab) return outcome.fail("browser {s}: crane_tab_close again: {t}, expected no_such_tab", .{ marker, again });
    const created_events = events.created.load(.acquire);
    const destroyed_events = events.destroyed.load(.acquire);
    if (created_events != 1 or destroyed_events != 1) return outcome.fail("browser {s}: events: {d} tab_created, {d} tab_destroyed, expected 1 and 1", .{ marker, created_events, destroyed_events });
}

test "two Browsers on two threads through the C ABI: tabs, navigation, evaluation, events, nothing shared" {
    try testing.expectEqual(capi.Status.ok, capi.crane_process_init(&.{ .struct_size = @sizeOf(capi.ProcessOptions) }));
    var outcomes: [2]Outcome = .{ .{}, .{} };
    const a = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, useOneBrowser, .{ &outcomes[0], "a" });
    const b = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, useOneBrowser, .{ &outcomes[1], "b" });
    a.join();
    b.join();
    try testing.expectEqualStrings("", outcomes[0].text());
    try testing.expectEqualStrings("", outcomes[1].text());
}

test "the C ABI refuses what it cannot do: a profile directory, a PAC proxy, null arguments" {
    try testing.expectEqual(capi.Status.ok, capi.crane_process_init(null));
    var handle: ?*capi.Handle = null;
    try testing.expectEqual(capi.Status.unsupported, capi.crane_browser_create(&.{ .struct_size = @sizeOf(capi.BrowserOptions), .profile_dir = "/tmp/crane-profile" }, &handle));
    const pac: capi.Proxy = .{ .kind = @backingInt(capi.ProxyKind.pac), .pac_url = "http://example.test/proxy.pac" };
    try testing.expectEqual(capi.Status.unsupported, capi.crane_browser_create(&.{ .struct_size = @sizeOf(capi.BrowserOptions), .proxy = &pac }, &handle));
    try testing.expectEqual(capi.Status.invalid_argument, capi.crane_browser_create(null, null));
    try testing.expectEqual(capi.Status.invalid_argument, capi.crane_tab_close(null, 1, false));
}

/// What one C embedder heard, in order (the callback runs on the Browser's
/// thread; the test reads after its blocking calls return, or after an
/// atomic it waits on).
const Heard = struct {
    mutex: std.Io.Mutex = .init,
    kinds: [64]u32 = undefined,
    tabs: [64]u64 = undefined,
    len: usize = 0,
    handle: ?*capi.Handle = null,
    /// dialog_opening: answer it from inside the callback with this text.
    answer_inside: ?[*:0]const u8 = null,
    dialogs_opened: std.atomic.Value(u32) = .init(0),
    dialog_closed_accepted: std.atomic.Value(bool) = .init(false),
    dialog_message: [64]u8 = undefined,
    dialog_message_len: usize = 0,
    window_url: [128]u8 = undefined,
    window_url_len: usize = 0,
    window_name: [32]u8 = undefined,
    window_name_len: usize = 0,
    window_features: [128]u8 = undefined,
    window_features_len: usize = 0,
    window_gesture: bool = false,

    fn copy(into: []u8, text: ?[*:0]const u8) usize {
        const t = std.mem.span(text orelse return 0);
        const n = @min(t.len, into.len);
        @memcpy(into[0..n], t[0..n]);
        return n;
    }

    fn onEvent(context: ?*anyopaque, event: *const capi.Event) callconv(.c) void {
        const self: *Heard = @ptrCast(@alignCast(context.?));
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        if (self.len < self.kinds.len) {
            self.kinds[self.len] = event.kind;
            self.tabs[self.len] = event.tab;
            self.len += 1;
        }
        switch (event.kind) {
            @backingInt(capi.EventKind.dialog_opening) => {
                self.dialog_message_len = copy(&self.dialog_message, event.message);
                _ = self.dialogs_opened.fetchAdd(1, .acq_rel);
                testing.io.futexWake(u32, &self.dialogs_opened.raw, std.math.maxInt(u32));
                if (self.answer_inside) |text| _ = capi.crane_tab_answer_dialog(self.handle, event.tab, true, text);
            },
            @backingInt(capi.EventKind.dialog_closed) => self.dialog_closed_accepted.store(event.flag, .release),
            @backingInt(capi.EventKind.window_open) => {
                self.window_url_len = copy(&self.window_url, event.url);
                self.window_name_len = copy(&self.window_name, event.message);
                self.window_features_len = copy(&self.window_features, event.extra);
                self.window_gesture = event.flag;
            },
            else => {},
        }
    }

    /// The position of the first `kind` heard for `tab` at or after `from`.
    fn indexOf(self: *Heard, kind: capi.EventKind, tab: u64, from: usize) ?usize {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        var i = from;
        while (i < self.len) : (i += 1) {
            if (self.kinds[i] == @backingInt(kind) and self.tabs[i] == tab) return i;
        }
        return null;
    }
};

fn startHeard(heard: *Heard, answers_dialogs: bool) !void {
    try testing.expectEqual(capi.Status.ok, capi.crane_process_init(null));
    const options: capi.BrowserOptions = .{
        .struct_size = @sizeOf(capi.BrowserOptions),
        .on_event = Heard.onEvent,
        .event_context = heard,
        .answers_dialogs = answers_dialogs,
    };
    try testing.expectEqual(capi.Status.ok, capi.crane_browser_create(&options, &heard.handle));
}

test "the C ABI tells each navigation milestone of a tab, in the spec's order" {
    var heard: Heard = .{};
    try startHeard(&heard, false);
    defer capi.crane_browser_destroy(heard.handle);
    var tab: u64 = 0;
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_create(heard.handle, null, false, &tab));
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_navigate(heard.handle, tab, "data:text/html,<title>n</title>", @backingInt(capi.Readiness.complete), null));
    const started = heard.indexOf(.navigation_started, tab, 0) orelse return error.NoStarted;
    const ready = heard.indexOf(.navigation_ready, tab, started) orelse return error.NoReady;
    const committed = heard.indexOf(.navigation_committed, tab, ready) orelse return error.NoCommitted;
    const dcl = heard.indexOf(.dom_content_loaded, tab, committed) orelse return error.NoDomContentLoaded;
    const load = heard.indexOf(.load, tab, dcl) orelse return error.NoLoad;
    _ = heard.indexOf(.stopped_loading, tab, load) orelse return error.NoStoppedLoading;
    // The new document's start is told between its commit and its load.
    const document_start = heard.indexOf(.document_start, tab, committed) orelse return error.NoDocumentStart;
    try testing.expect(document_start < load);
}

test "a C embedder that answers dialogs answers a prompt from another thread; the evaluation ends with the dialog open" {
    var heard: Heard = .{};
    try startHeard(&heard, true);
    defer capi.crane_browser_destroy(heard.handle);
    var tab: u64 = 0;
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_create(heard.handle, null, false, &tab));
    const source = "globalThis.answer = prompt('Name?', 'nobody')";
    var result: capi.EvaluateResult = .{};
    try testing.expectEqual(capi.Status.user_prompt_open, capi.crane_tab_evaluate(heard.handle, tab, source.ptr, source.len, 0, &result));
    // The callback wakes the count it bumps: no polling.
    var tries: u32 = 0;
    while (heard.dialogs_opened.load(.acquire) == 0 and tries < 50) : (tries += 1) {
        const timeout: std.Io.Timeout = .{ .duration = .{ .raw = .fromMilliseconds(100), .clock = .awake } };
        testing.io.futexWaitTimeout(u32, &heard.dialogs_opened.raw, 0, timeout) catch {};
    }
    try testing.expectEqual(@as(u32, 1), heard.dialogs_opened.load(.acquire));
    try testing.expectEqualStrings("Name?", heard.dialog_message[0..heard.dialog_message_len]);
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_answer_dialog(heard.handle, tab, true, "Crane"));
    try testing.expectEqual(capi.Status.no_such_dialog, capi.crane_tab_answer_dialog(heard.handle, tab, true, "again"));
    const read = "answer";
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_evaluate(heard.handle, tab, read.ptr, read.len, 0, &result));
    defer capi.crane_evaluate_result_free(&result);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"Crane\"}", std.mem.span(result.json.?));
    try testing.expect(heard.dialog_closed_accepted.load(.acquire));
}

test "a C embedder may answer a dialog from inside its event callback" {
    var heard: Heard = .{ .answer_inside = "inside" };
    try startHeard(&heard, true);
    defer capi.crane_browser_destroy(heard.handle);
    var tab: u64 = 0;
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_create(heard.handle, null, false, &tab));
    const source = "globalThis.answer = prompt('Name?')";
    var result: capi.EvaluateResult = .{};
    try testing.expectEqual(capi.Status.user_prompt_open, capi.crane_tab_evaluate(heard.handle, tab, source.ptr, source.len, 0, &result));
    const read = "answer";
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_evaluate(heard.handle, tab, read.ptr, read.len, 0, &result));
    defer capi.crane_evaluate_result_free(&result);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"inside\"}", std.mem.span(result.json.?));
}

test "window.open is told to a C embedder before the new tab: URL, name, features, user gesture" {
    var heard: Heard = .{};
    try startHeard(&heard, false);
    defer capi.crane_browser_destroy(heard.handle);
    var tab: u64 = 0;
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_create(heard.handle, "data:text/html,<p>o</p>", false, &tab));
    const source = "void window.open('about:blank#popup', 'named', 'width=300,height=200')";
    var result: capi.EvaluateResult = .{};
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_evaluate(heard.handle, tab, source.ptr, source.len, capi.eval_user_activation, &result));
    capi.crane_evaluate_result_free(&result);
    const asked = heard.indexOf(.window_open, tab, 0) orelse return error.NoWindowOpen;
    // tab_created of the popup comes after.
    std.Io.Threaded.mutexLockUncancelable(&heard.mutex);
    var created_after = false;
    for (heard.kinds[asked..heard.len]) |kind| {
        if (kind == @backingInt(capi.EventKind.tab_created)) created_after = true;
    }
    std.Io.Threaded.mutexUnlock(&heard.mutex);
    try testing.expect(created_after);
    try testing.expectEqualStrings("about:blank#popup", heard.window_url[0..heard.window_url_len]);
    try testing.expectEqualStrings("named", heard.window_name[0..heard.window_name_len]);
    try testing.expect(std.mem.startsWith(u8, heard.window_features[0..heard.window_features_len], "width=300,height=200"));
    try testing.expect(heard.window_gesture);
}

test "an embedder's older, shorter options struct keeps the newer fields' defaults" {
    try testing.expectEqual(capi.Status.ok, capi.crane_process_init(null));
    // The struct as it was before answers_dialogs: up to event_context.
    const options: capi.BrowserOptions = .{ .struct_size = @offsetOf(capi.BrowserOptions, "answers_dialogs"), .answers_dialogs = true };
    var handle: ?*capi.Handle = null;
    try testing.expectEqual(capi.Status.ok, capi.crane_browser_create(&options, &handle));
    defer capi.crane_browser_destroy(handle);
    // Not claimed: the platform's dialog answers (headless: prompt is null).
    // The tab stays on its initial about:blank: a URL to load raced the two
    // evaluations - the first ran in the initial document, its navigation
    // then committed, and the second read a new Window (lane tpg: flaky on
    // a loaded chat2). The dialog tests above do the same.
    var tab: u64 = 0;
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_create(handle, null, false, &tab));
    const source = "globalThis.answer = String(prompt('x'))";
    var result: capi.EvaluateResult = .{};
    // The dialog opens (the evaluation ends with it open) and the platform
    // answers it at once.
    try testing.expectEqual(capi.Status.user_prompt_open, capi.crane_tab_evaluate(handle, tab, source.ptr, source.len, 0, &result));
    // The Browser's thread runs this only after the dialog closed.
    const read = "answer";
    try testing.expectEqual(capi.Status.ok, capi.crane_tab_evaluate(handle, tab, read.ptr, read.len, 0, &result));
    defer capi.crane_evaluate_result_free(&result);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"null\"}", std.mem.span(result.json.?));
    try testing.expectEqual(capi.Status.no_such_dialog, capi.crane_tab_answer_dialog(handle, tab, true, null));
}
