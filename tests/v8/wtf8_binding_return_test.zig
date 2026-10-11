//! A DOMString the binding hands back to script keeps its lone surrogates on
//! every return path, not only the attribute getter's.
//!
//! A DOMString is WTF-8 (conversions.fromV8Value writes a lone surrogate as
//! its three bytes, ED A0..BF xx). conversions.newStringFromWtf8 turns those
//! back into the code unit; V8's UTF-8 decoder (String::NewFromUtf8) makes
//! each byte a U+FFFD. Attribute getters went through newStringFromWtf8, but
//! interface.zig's operation results, its stringifier and its named getter
//! called NewFromUtf8 directly, so `getAttribute`, `substringData` and
//! `String(range)` returned three U+FFFD for one lone surrogate (lane utf16).
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agents.

const std = @import("std");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

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

/// An agent and a Window realm of it.
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

    /// `source`'s completion value as a string, which must be `expected`;
    /// nothing reported.
    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        var reports: Reports = .{};
        const got = protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter()) catch |err| {
            std.debug.print("evaluating failed ({s}, {d} reported): {s}\n", .{ @errorName(err), reports.count, source });
            return err;
        };
        defer std.testing.allocator.free(got);
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        try std.testing.expectEqualStrings(expected, got);
    }
};

// Each case answers with the code units it got, in hex, so a failure shows
// what arrived instead (three U+FFFD for one lone surrogate).
const units_helper =
    \\const units = s => Array.from(s, c => c.length === 1 ? c.charCodeAt(0).toString(16) : [...c].map(u => u.charCodeAt(0).toString(16)).join('+')).join(' ');
;

test "an operation's DOMString result keeps a lone surrogate" {
    const page = try Page.open();
    defer page.close();
    try page.expect(units_helper ++
        \\(() => {
        \\  const doc = new Document();
        \\  const el = doc.createElement('x');
        \\  el.setAttribute('a', 'p\uD800q');
        \\  const text = doc.createTextNode('x\uDE00y');
        \\  return [units(el.getAttribute('a')), units(text.substringData(1, 1))].join(' | ');
        \\})()
    , "70 d800 71 | de00");
}

test "a stringifier's result keeps a lone surrogate" {
    const page = try Page.open();
    defer page.close();
    try page.expect(units_helper ++
        \\(() => {
        \\  const doc = new Document();
        \\  const el = doc.createElement('x');
        \\  el.classList.add('\uDBFF');
        \\  const text = doc.createTextNode('\uD800z');
        \\  const range = doc.createRange();
        \\  range.setStart(text, 0);
        \\  range.setEnd(text, 1);
        \\  return [units(String(el.classList)), units(String(range))].join(' | ');
        \\})()
    , "dbff | d800");
}

test "an indexed getter's and a named getter's DOMString keep a lone surrogate" {
    // Both already convert through conversions.toV8Value; pinned beside the
    // paths that did not. (The ?DOMString named-getter branch the commit
    // switches has no binder in the IDL Crane binds today.)
    const page = try Page.open();
    defer page.close();
    try page.expect(units_helper ++
        \\(() => {
        \\  const doc = new Document();
        \\  const el = doc.createElementNS('http://www.w3.org/1999/xhtml', 'div');
        \\  el.classList.add('\uDC00');
        \\  el.setAttribute('data-x', '\uDFFF!');
        \\  return [units(el.classList[0]), units(el.classList.item(0)), units(el.dataset.x)].join(' | ');
        \\})()
    , "dc00 | dc00 | dfff 21");
}

test "a pair iterable's USVString values still arrive as scalar values" {
    // URLSearchParams converts its arguments to USVString, so a lone
    // surrogate is U+FFFD before it is stored: newStringFromWtf8 changes
    // nothing for it, in forEach or the iterator.
    const page = try Page.open();
    defer page.close();
    try page.expect(units_helper ++
        \\(() => {
        \\  const params = new URLSearchParams();
        \\  params.append('k\uD800', 'v\uDC00');
        \\  let seen = '';
        \\  params.forEach((value, key) => { seen = units(key) + ' = ' + units(value); });
        \\  const [[key, value]] = [...params];
        \\  return seen + ' | ' + units(key) + ' = ' + units(value);
        \\})()
    , "6b fffd = 76 fffd | 6b fffd = 76 fffd");
}
