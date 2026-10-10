//! engine.matchesPatternAttribute: HTML 4.10.5.3.6, the compiled pattern
//! regular expression of an input's `pattern` attribute and "check if an
//! input value matches" it.
//!
//! The steps are RegExpCreate(pattern, "v") - an abrupt completion means the
//! element has no compiled pattern regular expression, InvalidPattern here -
//! then RegExpCreate("^(?:" + pattern + ")$", "v") and RegExpBuiltinExec. So
//! the pattern is validated standalone (")(" is invalid even though its
//! anchored form "^(?:)()$" is not), it is compiled in UnicodeSets mode ("v",
//! not "u": `[(]` is a SyntaxError there), it is anchored as a group (the
//! value "ab" does not match "a|b"), and its code points are matched as
//! code points: "." matches one astral character, and a lone surrogate in the
//! value is kept as itself.
//!
//! Built-in intrinsics only: what the page did to RegExp, RegExp.prototype.exec
//! or Symbol.match does not matter (Blink matches in a context of its own,
//! V8PerIsolateData::EnsureScriptRegexpContext; WebKit with Yarr directly;
//! Gecko in a junk scope), the page's legacy RegExp statics do not see the
//! value, and the call - native code with no script on the stack - is no
//! microtask checkpoint.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agents.

const std = @import("std");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const clock = @import("clock");

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    pools_ready = true;
}

const no_hooks: protocol.HostHooks = .{};

/// An agent - V8's default kAuto microtask policy, the browser's - and a
/// Window realm of it.
const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try setup();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    /// Run `source` in the page; nothing reported.
    fn run(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        try protocol.runClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        try std.testing.expectEqual(@as(usize, 0), reports.count);
    }

    /// Whether `source` evaluates to true in the page.
    fn holds(self: Page, source: []const u8) !bool {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        return protocol.toBoolean(self.realm, held.value);
    }

    fn matches(self: Page, pattern: []const u8, value: []const u8) !bool {
        return protocol.matchesPatternAttribute(self.realm, pattern, value);
    }
};

test "a value matches when the whole value matches the pattern" {
    const page = try Page.open();
    defer page.close();
    try std.testing.expect(try page.matches("[a-z]+", "abc"));
    try std.testing.expect(!try page.matches("[a-z]+", "abc1"));
    try std.testing.expect(!try page.matches("[a-z]+", "1abc"));
    try std.testing.expect(try page.matches("", ""));
    try std.testing.expect(!try page.matches("", "x"));
    try std.testing.expect(try page.matches("\\d{3}", "123"));
}

test "the pattern is anchored as one group: ^(?:pattern)$" {
    const page = try Page.open();
    defer page.close();
    // "^a|b$" would match "ab" through its first alternative.
    try std.testing.expect(try page.matches("a|b", "a"));
    try std.testing.expect(try page.matches("a|b", "b"));
    try std.testing.expect(!try page.matches("a|b", "ab"));
    try std.testing.expect(!try page.matches("abc|def", "abcdef"));
    // A pattern that anchors itself is anchored again, harmlessly.
    try std.testing.expect(try page.matches("^x$", "x"));
}

test "an invalid pattern is InvalidPattern, judged standalone" {
    const page = try Page.open();
    defer page.close();
    try std.testing.expectError(error.InvalidPattern, page.matches("(", "("));
    try std.testing.expectError(error.InvalidPattern, page.matches("[", "x"));
    try std.testing.expectError(error.InvalidPattern, page.matches("a{2,1}", "aa"));
    // Valid once wrapped ("^(?:)()$"), invalid on its own: step 3 compiles
    // the attribute's value by itself first.
    try std.testing.expectError(error.InvalidPattern, page.matches(")(", ""));
    try std.testing.expectError(error.InvalidPattern, page.matches(")(", ")("));
}

test "the pattern is compiled with the v flag (UnicodeSets)" {
    const page = try Page.open();
    defer page.close();
    // Set subtraction, intersection and class string disjunctions exist
    // only in v mode.
    try std.testing.expect(try page.matches("[[a-z]--[aeiou]]+", "bcd"));
    try std.testing.expect(!try page.matches("[[a-z]--[aeiou]]+", "bad"));
    try std.testing.expect(try page.matches("[[a-z]&&[aeiou]]+", "aei"));
    try std.testing.expect(!try page.matches("[[a-z]&&[aeiou]]+", "abc"));
    try std.testing.expect(try page.matches("[\\q{abc|d}]", "abc"));
    try std.testing.expect(!try page.matches("[\\q{abc|d}]", "ab"));
    // Crane's V8 is built without i18n support (build.zig,
    // v8_enable_i18n_support = false), so a Unicode property escape is a
    // SyntaxError in every realm - `/\p{L}/v` in the page's own script too -
    // and the attribute imposes no constraint, as for any invalid pattern.
    try std.testing.expectError(error.InvalidPattern, page.matches("\\p{L}", "A"));
    // `[(]` is fine with "u" and a SyntaxError with "v": ( is a
    // ClassSetSyntaxCharacter that must be escaped in a v-mode class.
    try std.testing.expectError(error.InvalidPattern, page.matches("[(]", "("));
    try std.testing.expect(try page.matches("[\\(]", "("));
    // An identity escape of a non-syntax character is an error in unicode mode.
    try std.testing.expectError(error.InvalidPattern, page.matches("\\a", "a"));
}

test "code points are matched as code points, and a lone surrogate stays itself" {
    const page = try Page.open();
    defer page.close();
    // One astral character is one code point to ".".
    try std.testing.expect(try page.matches(".", "\u{1F600}"));
    try std.testing.expect(!try page.matches("..", "\u{1F600}"));
    // A lone high surrogate (WTF-8 ED A0 BD) in the value is the code unit
    // D83D, not U+FFFD: the escape matches it, and not a replacement character.
    try std.testing.expect(try page.matches("\\uD83D", "\xED\xA0\xBD"));
    try std.testing.expect(!try page.matches("\\uD83D", "\u{FFFD}"));
    try std.testing.expect(try page.matches(".", "\xED\xA0\xBD"));
    // And a lone surrogate in the pattern is itself.
    try std.testing.expect(try page.matches("\xED\xA0\xBD", "\xED\xA0\xBD"));
    try std.testing.expect(!try page.matches("\xED\xA0\xBD", "\u{FFFD}"));
}

test "what the page did to RegExp does not matter" {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.calls = 0;
        \\RegExp.prototype.exec = function () { calls++; return null; };
        \\RegExp.prototype.test = function () { calls++; return false; };
        \\RegExp.prototype[Symbol.match] = function () { calls++; return null; };
        \\Object.defineProperty(RegExp.prototype, 'flags', { get() { calls++; return ''; } });
        \\Object.defineProperty(RegExp.prototype, 'unicodeSets', { get() { calls++; return false; } });
        \\Object.defineProperty(RegExp.prototype, 'lastIndex', { set(v) { calls++; }, get() { calls++; return 0; } });
        \\Object.defineProperty(Array.prototype, 'index', { set(v) { calls++; }, configurable: true });
        \\Object.defineProperty(Object.prototype, 'groups', { set(v) { calls++; }, configurable: true });
        \\globalThis.RegExp = function () { calls++; throw new Error('poisoned'); };
    );
    try std.testing.expect(try page.matches("[a-z]+", "abc"));
    try std.testing.expect(!try page.matches("[a-z]+", "ABC"));
    try std.testing.expect(try page.matches("(?<word>[a-z]+)", "abc"));
    try std.testing.expectError(error.InvalidPattern, page.matches("(", "("));
    try std.testing.expect(try page.holds("calls === 0"));

    // An exec that claims every value matches changes nothing either.
    try page.run("Object.getPrototypeOf(/x/).exec = function () { calls++; return ['x']; };");
    try std.testing.expect(!try page.matches("a", "b"));
    try std.testing.expect(try page.holds("calls === 0"));
}

test "the page's legacy RegExp statics do not see the value" {
    const page = try Page.open();
    defer page.close();
    try page.run("/(seen)/.exec('was seen');");
    try std.testing.expect(try page.holds("RegExp.lastMatch === 'seen' && RegExp.$1 === 'seen'"));
    try std.testing.expect(try page.matches("(secret)", "secret"));
    try std.testing.expect(try page.holds("RegExp.lastMatch === 'seen' && RegExp.$1 === 'seen' && RegExp.input === 'was seen'"));
}

/// A microtask the test queues natively, and whether it has run.
const Marker = struct {
    ran: bool = false,

    fn steps(data: ?*anyopaque) void {
        const self: *Marker = @ptrCast(@alignCast(data.?));
        self.ran = true;
    }
};

test "a match from native code with no script on the stack is no microtask checkpoint" {
    const page = try Page.open();
    defer page.close();
    var marker: Marker = .{};
    try protocol.queueMicrotask(page.agent, Marker.steps, &marker);
    try std.testing.expect(try page.matches("[a-z]+", "abc"));
    try std.testing.expectError(error.InvalidPattern, page.matches("(", "("));
    try std.testing.expect(!marker.ran);
    try protocol.performMicrotaskCheckpoint(page.agent);
    try std.testing.expect(marker.ran);
}

test "a pattern compiles once per agent: first and repeat call cost" {
    const page = try Page.open();
    defer page.close();
    // The first match of the agent makes its utility context and compiles.
    var timer = clock.Timer.start();
    try std.testing.expect(try page.matches("[0-9]*[02468]", "1234"));
    const first_ns = timer.read();
    // A second pattern: a compile, no new context.
    timer.reset();
    try std.testing.expect(try page.matches("[a-f0-9]{8}", "deadbeef"));
    const compile_ns = timer.read();
    // Repeats: cached.
    const rounds = 2000;
    timer.reset();
    for (0..rounds) |i| {
        try std.testing.expectEqual(i % 2 == 0, try page.matches("[0-9]*[02468]", if (i % 2 == 0) "1234" else "1235"));
    }
    const repeat_ns = timer.read() / rounds;
    std.debug.print("matchesPatternAttribute: first call {d} us (utility context + compile), new pattern {d} us, repeat {d} ns\n", .{
        first_ns / std.time.ns_per_us, compile_ns / std.time.ns_per_us, repeat_ns,
    });
    // A context per call was ~200 us; the cached path is a few us. Loose, so
    // a loaded machine does not fail it.
    try std.testing.expect(repeat_ns < 50 * std.time.ns_per_us);
}

test "more patterns than the cache holds still match, and an invalid one stays invalid" {
    const page = try Page.open();
    defer page.close();
    var buffer: [32]u8 = undefined;
    for (0..3) |_| {
        for (0..40) |i| {
            const pattern = try std.fmt.bufPrint(&buffer, "x{d}y*", .{i});
            var value_buffer: [32]u8 = undefined;
            const value = try std.fmt.bufPrint(&value_buffer, "x{d}yy", .{i});
            try std.testing.expect(try page.matches(pattern, value));
            try std.testing.expect(!try page.matches(pattern, "x"));
            try std.testing.expectError(error.InvalidPattern, page.matches("(", "("));
        }
    }
}

test "matching keeps no context per call" {
    const page = try Page.open();
    defer page.close();
    _ = try page.matches("a", "a");
    protocol.requestGarbageCollection(page.agent);
    const before = protocol.heapStatistics(page.agent);
    for (0..200) |i| {
        var buffer: [32]u8 = undefined;
        _ = try page.matches(try std.fmt.bufPrint(&buffer, "p{d}", .{i}), "p1");
    }
    protocol.requestGarbageCollection(page.agent);
    const after = protocol.heapStatistics(page.agent);
    try std.testing.expectEqual(before.realm_count, after.realm_count);
}

// An isolate the adapter's createAgent did not make has no agent record: it
// matches in a context made for the call, with the same answers. On a thread
// of its own, entered and torn down there: tests/v8 is one process.
const ffi = @import("v8").ffi;

fn bareIsolateMatches() !void {
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    defer ffi.v8_Isolate_Dispose(isolate);
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const scope = ffi.v8_HandleScope_New(isolate);
    defer ffi.v8_HandleScope_Dispose(scope);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    defer ffi.v8_Context_Dispose(context);
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);
    var data = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine_ctx = context });
    defer data.deinit();
    data.agent = @ptrCast(isolate);
    const realm: runtime.Context = &data;
    try std.testing.expect(try protocol.matchesPatternAttribute(realm, "a|b", "a"));
    try std.testing.expect(!try protocol.matchesPatternAttribute(realm, "a|b", "ab"));
    try std.testing.expectError(error.InvalidPattern, protocol.matchesPatternAttribute(realm, ")(", ""));
    try std.testing.expect(try protocol.matchesPatternAttribute(realm, "[[a-z]--[aeiou]]", "b"));
}

test "an isolate with no agent record matches in a context made for the call" {
    try setup();
    const Run = struct {
        fn run(result: *?anyerror) void {
            bareIsolateMatches() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
