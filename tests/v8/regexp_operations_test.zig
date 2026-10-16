//! engine.regExpCreateCheck and engine.regExpBuiltinExecCaptures: ECMAScript
//! RegExpCreate(pattern, "v" or "vi") and RegExpBuiltinExec, the two steps
//! URLPattern's "compile a component" (step 6) and "match" (steps 14-21) take
//! (specs/whatwg/urlpattern.md:953-964, :797-832; the result read by index,
//! :1000ff).
//!
//! The contract pinned here:
//! - the pattern is compiled in UnicodeSets mode ("v"): set operations and
//!   string disjunctions exist, `[(]` is a SyntaxError, and a throw is
//!   InvalidPattern; "vi" adds ignore case and nothing else;
//! - RegExpBuiltinExec is not anchored (URLPattern's generated regexps anchor
//!   themselves), starts at lastIndex 0 every call, and answers null or the
//!   result's elements 0..n, OWNED, with an undefined group (null) kept apart
//!   from an empty one (""), WTF-8 both ways;
//! - built-in intrinsics only: what the page did to RegExp,
//!   RegExp.prototype.exec, lastIndex or Symbol.match does not matter, and
//!   the page's legacy RegExp statics do not see the input (Blink's
//!   ScriptRegexp context, V8PerIsolateData::EnsureScriptRegexpContext);
//! - native code with no script on the stack: no microtask checkpoint;
//! - a match past the backtrack limit is no match (Blink's ScriptRegexp,
//!   kBacktrackLimit = 1'000'000, which URLPattern's regexps use too:
//!   third_party/blink/renderer/core/url_pattern/url_pattern_component.cc
//!   makes a ScriptRegexp with UnicodeMode::kUnicodeSets);
//! - only the realm's agent is used: a realm retired since (a detached
//!   frame's, urlpattern/urlpattern-detached-frame-regexp.html) answers too.
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
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

const no_hooks: protocol.HostHooks = .{};

const A = std.testing.allocator;

/// The captures, OWNED, freed by `free`.
const Captures = []?[]u8;

fn free(captures: ?Captures) void {
    const list = captures orelse return;
    for (list) |capture| if (capture) |bytes| A.free(bytes);
    A.free(list);
}

/// An agent and a Window realm of it, without a snapshot.
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

    fn run(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        try protocol.runClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        try std.testing.expectEqual(@as(usize, 0), reports.count);
    }

    fn holds(self: Page, source: []const u8) !bool {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        return protocol.toBoolean(self.realm, held.value);
    }

    fn check(self: Page, pattern: []const u8, ignore_case: bool) !void {
        return protocol.regExpCreateCheck(self.realm, pattern, ignore_case);
    }

    fn exec(self: Page, pattern: []const u8, ignore_case: bool, input: []const u8) !?Captures {
        return protocol.regExpBuiltinExecCaptures(self.realm, pattern, ignore_case, input, A);
    }

    /// `pattern` matches `input` with exactly the captures `expected`
    /// (null: an undefined group).
    fn expectCaptures(self: Page, pattern: []const u8, ignore_case: bool, input: []const u8, expected: []const ?[]const u8) !void {
        const captures = try self.exec(pattern, ignore_case, input) orelse {
            std.debug.print("/{s}/ on \"{s}\": no match\n", .{ pattern, input });
            return error.TestExpectedMatch;
        };
        defer free(captures);
        try std.testing.expectEqual(expected.len, captures.len);
        for (expected, captures) |want, got| {
            if (want) |bytes| {
                try std.testing.expect(got != null);
                try std.testing.expectEqualSlices(u8, bytes, got.?);
            } else {
                try std.testing.expect(got == null);
            }
        }
    }

    fn expectNoMatch(self: Page, pattern: []const u8, ignore_case: bool, input: []const u8) !void {
        const captures = try self.exec(pattern, ignore_case, input);
        defer free(captures);
        try std.testing.expect(captures == null);
    }
};

test "RegExpCreate with \"v\": valid patterns pass, a SyntaxError is InvalidPattern" {
    const page = try Page.open();
    defer page.close();
    for ([_]bool{ false, true }) |ignore_case| {
        try page.check("^(.*)$", ignore_case);
        try page.check("^(?:\\/([^\\/]+?))$", ignore_case);
        try page.check("", ignore_case);
        // UnicodeSets mode: set operations and string disjunctions.
        try page.check("[[a-z]--[aeiou]]", ignore_case);
        try page.check("[\\d&&[0-1]]", ignore_case);
        try page.check("[\\q{abc|d}]", ignore_case);
        try std.testing.expectError(error.InvalidPattern, page.check("(", ignore_case));
        try std.testing.expectError(error.InvalidPattern, page.check("[", ignore_case));
        try std.testing.expectError(error.InvalidPattern, page.check("a{2,1}", ignore_case));
        // A v-mode class must escape its syntax characters; "u" allowed it.
        try std.testing.expectError(error.InvalidPattern, page.check("[(]", ignore_case));
        // An identity escape of a non-syntax character: an error with a
        // Unicode flag.
        try std.testing.expectError(error.InvalidPattern, page.check("\\a", ignore_case));
        // A lookbehind is fine; a lone quantifier is not.
        try page.check("(?<=a)b", ignore_case);
        try std.testing.expectError(error.InvalidPattern, page.check("*", ignore_case));
    }
}

test "RegExpBuiltinExec: null for no match, the elements 0..n for a match" {
    const page = try Page.open();
    defer page.close();
    try page.expectCaptures("^(?:\\/([^\\/]+?))$", false, "/foo", &.{ "/foo", "foo" });
    try page.expectNoMatch("^(?:\\/([^\\/]+?))$", false, "/foo/bar");
    try page.expectCaptures("^(.*)$", false, "", &.{ "", "" });
    try page.expectCaptures("^$", false, "", &.{""});
    try page.expectNoMatch("^$", false, "x");
    // Not anchored by the operation: RegExpBuiltinExec searches from
    // lastIndex 0.
    try page.expectCaptures("b(c)?", false, "abd", &.{ "b", null });
    // Every call starts at 0 again (the regexp has no "g" or "y").
    try page.expectCaptures("b(c)?", false, "abcb", &.{ "bc", "c" });
    try page.expectCaptures("b(c)?", false, "abcb", &.{ "bc", "c" });
    // Repetition and backtracking.
    try page.expectCaptures("^((?:[^\\/]+?)(?:\\/(?:[^\\/]+?))*)$", false, "a/b/c", &.{ "a/b/c", "a/b/c" });
    try page.expectCaptures("^(a|ab)(c|bcd)(d*)$", false, "abcd", &.{ "abcd", "a", "bcd", "" });
}

test "an undefined group is null, apart from an empty one" {
    const page = try Page.open();
    defer page.close();
    try page.expectCaptures("^(a)?(b)$", false, "b", &.{ "b", null, "b" });
    try page.expectCaptures("^(a*)(b)?$", false, "", &.{ "", "", null });
    try page.expectCaptures("^(?:\\/([^\\/]+?))?$", false, "", &.{ "", null });
    try page.expectCaptures("^(?:(x)|(y))$", false, "y", &.{ "y", null, "y" });
}

test "\"vi\" ignores case; \"v\" does not" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoMatch("^\\/hello$", false, "/HELLO");
    try page.expectCaptures("^\\/hello$", true, "/HELLO", &.{"/HELLO"});
    try page.expectCaptures("^(foo)$", true, "FoO", &.{ "FoO", "FoO" });
    // The same pattern string with each flag set, in turn: the adapter's
    // compiled regexps for "v" and "vi" are not the same one.
    for (0..3) |_| {
        try page.expectNoMatch("^abc$", false, "ABC");
        try page.expectCaptures("^abc$", true, "ABC", &.{"ABC"});
    }
}

test "UnicodeSets semantics: set operations and code points" {
    const page = try Page.open();
    defer page.close();
    try page.expectCaptures("^\\/([[a-z]--a])$", false, "/z", &.{ "/z", "z" });
    try page.expectNoMatch("^\\/([[a-z]--a])$", false, "/a");
    try page.expectCaptures("^\\/([\\d&&[0-1]])$", false, "/1", &.{ "/1", "1" });
    try page.expectNoMatch("^\\/([\\d&&[0-1]])$", false, "/2");
    // One astral character is one code point to "." in a Unicode mode.
    try page.expectCaptures("^(.)$", false, "\u{1F600}", &.{ "\u{1F600}", "\u{1F600}" });
    try page.expectNoMatch("^(..)$", false, "\u{1F600}");
    // Non-ASCII in and out, as UTF-8.
    try page.expectCaptures("^\\/caf(.)$", false, "/caf\u{E9}", &.{ "/caf\u{E9}", "\u{E9}" });
}

test "a lone surrogate stays itself, in the pattern, the input and the captures (WTF-8)" {
    const page = try Page.open();
    defer page.close();
    // ED A0 BD: the lone high surrogate D83D.
    try page.expectCaptures("^(.)$", false, "\xED\xA0\xBD", &.{ "\xED\xA0\xBD", "\xED\xA0\xBD" });
    try page.expectCaptures("^(\\uD83D)$", false, "\xED\xA0\xBD", &.{ "\xED\xA0\xBD", "\xED\xA0\xBD" });
    try page.expectNoMatch("^(\\uD83D)$", false, "\u{FFFD}");
    try page.expectCaptures("^(\xED\xA0\xBD)$", false, "\xED\xA0\xBD", &.{ "\xED\xA0\xBD", "\xED\xA0\xBD" });
}

test "an invalid pattern is InvalidPattern from exec too, every time" {
    const page = try Page.open();
    defer page.close();
    for (0..3) |_| {
        try std.testing.expectError(error.InvalidPattern, page.exec("(", false, "("));
        try std.testing.expectError(error.InvalidPattern, page.exec("[(]", true, "("));
    }
}

test "what the page did to RegExp does not matter" {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.calls = 0;
        \\RegExp.prototype.exec = function () { calls++; return ['poisoned']; };
        \\RegExp.prototype.test = function () { calls++; return true; };
        \\RegExp.prototype[Symbol.match] = function () { calls++; return null; };
        \\Object.defineProperty(RegExp.prototype, 'flags', { get() { calls++; return ''; } });
        \\Object.defineProperty(RegExp.prototype, 'unicodeSets', { get() { calls++; return false; } });
        \\Object.defineProperty(RegExp.prototype, 'lastIndex', { set(v) { calls++; }, get() { calls++; return 5; } });
        \\Object.defineProperty(Array.prototype, '1', { set(v) { calls++; }, get() { calls++; return 'x'; }, configurable: true });
        \\Object.defineProperty(Object.prototype, 'groups', { set(v) { calls++; }, configurable: true });
        \\globalThis.RegExp = function () { calls++; throw new Error('poisoned'); };
    );
    try page.check("^(secret)$", false);
    try std.testing.expectError(error.InvalidPattern, page.check("(", false));
    try page.expectCaptures("^(secret)$", false, "secret", &.{ "secret", "secret" });
    try page.expectCaptures("^(a)?(b)$", false, "b", &.{ "b", null, "b" });
    try page.expectNoMatch("^(secret)$", false, "other");
    try std.testing.expect(try page.holds("calls === 0"));
}

test "the page's legacy RegExp statics keep the page's own last match" {
    const page = try Page.open();
    defer page.close();
    try page.run("/(seen)/.exec('was seen');");
    try page.expectCaptures("(secret)", false, "a secret", &.{ "secret", "secret" });
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

test "a call from native code with no script on the stack is no microtask checkpoint" {
    const page = try Page.open();
    defer page.close();
    var marker: Marker = .{};
    try protocol.queueMicrotask(page.agent, Marker.steps, &marker);
    try page.check("^a$", false);
    try page.expectCaptures("^(a)$", false, "a", &.{ "a", "a" });
    try std.testing.expectError(error.InvalidPattern, page.exec("(", false, ""));
    try std.testing.expect(!marker.ran);
    try protocol.performMicrotaskCheckpoint(page.agent);
    try std.testing.expect(marker.ran);
}

test "a match past the backtrack limit is no match, and returns promptly" {
    const page = try Page.open();
    defer page.close();
    var buffer: [64]u8 = undefined;
    @memset(buffer[0..26], 'a');
    buffer[26] = 'c';
    // Under the limit the second alternative is reached; past it (~2^26
    // backtracks) the match fails as a whole, as Blink's ScriptRegexp does.
    try page.expectCaptures("^(?:(a+)+$|.*c)$", false, "aaaaaaaaaac", &.{ "aaaaaaaaaac", null });
    const start = clock.monotonicMillis();
    try page.expectNoMatch("^(?:(a+)+$|.*c)$", false, buffer[0..27]);
    try page.expectNoMatch("^((\\d+)*)$", false, "12345678901234567890123456789123456789z");
    const elapsed = clock.monotonicMillis() - start;
    if (elapsed > 2000) {
        std.debug.print("two limited matches took {d} ms\n", .{elapsed});
        return error.TooSlow;
    }
    try page.expectCaptures("^((\\d+)*)$", false, "1234", &.{ "1234", "1234", "1234" });
}

test "more patterns than the agent caches still compile and match, and pattern attributes do not collide" {
    const page = try Page.open();
    defer page.close();
    var pattern_buffer: [32]u8 = undefined;
    var input_buffer: [32]u8 = undefined;
    for (0..3) |_| {
        for (0..150) |i| {
            const pattern = try std.fmt.bufPrint(&pattern_buffer, "^x{d}(y*)$", .{i});
            const input = try std.fmt.bufPrint(&input_buffer, "x{d}yy", .{i});
            try page.check(pattern, i % 2 == 0);
            try page.expectCaptures(pattern, i % 2 == 0, input, &.{ input, "yy" });
            try page.expectNoMatch(pattern, i % 2 == 0, "x");
        }
        // The same string as a pattern attribute is anchored as one group:
        // "a|b" does not match "ab" there, and RegExpBuiltinExec finds "a".
        try std.testing.expect(!try protocol.matchesPatternAttribute(page.realm, "a|b", "ab"));
        try page.expectCaptures("a|b", false, "ab", &.{"a"});
        try std.testing.expect(!try protocol.matchesPatternAttribute(page.realm, "a|b", "ab"));
        try std.testing.expectError(error.InvalidPattern, page.exec("(", false, "("));
    }
}

test "compiling once per agent: first and repeat call cost" {
    const page = try Page.open();
    defer page.close();
    var timer = clock.Timer.start();
    try page.check("^(?:\\/([^\\/]+?))$", false);
    const first_ns = timer.read();
    const rounds = 2000;
    timer.reset();
    for (0..rounds) |i| {
        const captures = try page.exec("^(?:\\/([^\\/]+?))$", false, if (i % 2 == 0) "/abc" else "/a/b");
        defer free(captures);
        try std.testing.expectEqual(i % 2 == 0, captures != null);
    }
    const repeat_ns = timer.read() / rounds;
    std.debug.print("regExpBuiltinExecCaptures: first check {d} us (utility context + compile), repeat exec {d} ns\n", .{ first_ns / std.time.ns_per_us, repeat_ns });
    try std.testing.expect(repeat_ns < 50 * std.time.ns_per_us);
}

fn execUnderAllocationFailure(allocator: std.mem.Allocator, realm: runtime.Context) !void {
    const captures = try protocol.regExpBuiltinExecCaptures(realm, "^(a)?(b)(c*)$", false, "bcc", allocator) orelse return error.TestExpectedMatch;
    for (captures) |capture| if (capture) |bytes| allocator.free(bytes);
    allocator.free(captures);
}

test "an allocation failure while copying the captures leaks nothing" {
    const page = try Page.open();
    defer page.close();
    try std.testing.checkAllAllocationFailures(A, execUnderAllocationFailure, .{page.realm});
}

test "a realm whose engine context is gone still answers, in its agent" {
    const page = try Page.open();
    defer page.close();
    // A retired realm's record keeps its agent (engine.Context): what a
    // detached frame's URLPattern constructor and methods run with.
    var data = try runtime.ContextData.init(std.heap.page_allocator, .{ .engine_ctx = null });
    defer data.deinit();
    data.agent = page.agent;
    const retired: runtime.Context = &data;
    try std.testing.expect(!retired.hasEngine());
    try protocol.regExpCreateCheck(retired, "^\\/books\\/(\\d+)$", false);
    try std.testing.expectError(error.InvalidPattern, protocol.regExpCreateCheck(retired, "(", false));
    const captures = try protocol.regExpBuiltinExecCaptures(retired, "^\\/books\\/(\\d+)$", false, "/books/123", A) orelse return error.TestExpectedMatch;
    defer free(captures);
    try std.testing.expectEqualStrings("123", captures[1].?);
    try std.testing.expect(try protocol.regExpBuiltinExecCaptures(retired, "^\\/books\\/(\\d+)$", false, "/books/abc", A) == null);
}

test "compiling keeps no context per call" {
    const page = try Page.open();
    defer page.close();
    try page.check("a", false);
    protocol.requestGarbageCollection(page.agent);
    const before = protocol.heapStatistics(page.agent);
    var buffer: [32]u8 = undefined;
    for (0..200) |i| {
        const pattern = try std.fmt.bufPrint(&buffer, "^p{d}$", .{i});
        try page.check(pattern, false);
        free(try page.exec(pattern, true, "P1"));
    }
    protocol.requestGarbageCollection(page.agent);
    const after = protocol.heapStatistics(page.agent);
    try std.testing.expectEqual(before.realm_count, after.realm_count);
}
