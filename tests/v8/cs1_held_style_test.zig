//! Lane cs1: a computed style a caller reads stays alive until the caller is
//! done with it, whatever style reads happen in between.
//!
//! The engine caches one ComputedStyle per element (src/dom/style/
//! element_style.zig) and replaces it - the old one destroyed - whenever a
//! read finds it stale: its key moved (a mutation, a sheet, focus/hover), or
//! it is VOLATILE, resolved again on every read because its cascade read
//! per-element state (selector_matching.readsVolatileState: a formish
//! element against :checked, :autofill, :placeholder-shown...; a dialog
//! against :modal; a [popover] against :popover-open) or its flat-tree
//! parent's style is volatile. A read of any descendant resolves every
//! volatile ancestor again. Lane a11y1's bug-finding crash
//! (hiddenViaStyle, f6ff67afb) was a style read across rendered().
//!
//! Each test reads a style, makes the read that replaces it, and then reads
//! the first style - on a realm allocated from std.testing.allocator, whose
//! free poisons (0x55), so a freed style faults on its first field.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const ComputedStyle = dom.style.css.computed_style.ComputedStyle;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(r.allocator, r) catch null;
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

/// A window realm on std.testing.allocator (so a freed style is poisoned),
/// with its own agent, holding `d`: an HTML document whose body is `body`.
const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,
    document: *runtime.Instance,

    fn open(body: []const u8) !Page {
        const no_hooks: protocol.HostHooks = .{};
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent_cluster_cross_origin_isolated = true,
            .agent = agent,
            .allocator = testing.allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        var page: Page = .{ .agent = agent, .realm = realm, .document = undefined };
        errdefer page.close();
        try page.eval("globalThis.d = new Document().implementation.createHTMLDocument('t');");
        // Every body here quotes with ' only.
        std.debug.assert(std.mem.indexOfAny(u8, body, "\"\\") == null);
        const source = try std.fmt.allocPrint(testing.allocator, "d.body.innerHTML = \"{s}\";", .{body});
        defer testing.allocator.free(source);
        try page.eval(source);
        page.document = try page.instance("d");
        return page;
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn eval(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
    }

    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        return protocol.convertToPlatformObject(self.realm, held.value) orelse error.NotAPlatformObject;
    }

    fn byId(self: Page, id: []const u8) !*runtime.Instance {
        return (try interfaces.Document.call_getElementById(self.document, runtime.DOMString.initInterned(id))) orelse error.NoElement;
    }
};

/// Run `body` on a thread of its own, with a standalone runtime of the
/// test's allocator (test_process.OwnRuntime), as every test here needs.
fn runIsolated(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            const own_scope = test_process.OwnRuntime.begin(testing.allocator);
            defer own_scope.end();
            dom.style.ua_sheet.build();
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

/// The resolved `color` of `style`, OWNED by std.testing.allocator.
fn colorOf(style: *const ComputedStyle) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(testing.allocator);
    try style.serializeResolved(.color, &out, testing.allocator);
    return out.toOwnedSlice(testing.allocator);
}

fn expectColor(style: *const ComputedStyle, expected: []const u8) !void {
    const got = try colorOf(style);
    defer testing.allocator.free(got);
    try testing.expectEqualStrings(expected, got);
}

/// Whether `element`'s cached style is volatile (resolved on every read).
fn isVolatile(element: *runtime.Instance) bool {
    const state = dom.style.element_style.existingOf(element) orelse return false;
    const cached = state.cached orelse return false;
    return cached.@"volatile";
}

fn volatileControl() !void {
    const page = try Page.open("<style>:checked { outline: 1px solid }</style><input id=i type=checkbox style='color: rgb(1, 2, 3)'>");
    defer page.close();
    const input = try page.byId("i");
    const first = (try dom.style.computedStyle(input, null)) orelse return error.NoStyle;
    try testing.expect(isVolatile(input));
    // The second read resolves the control again and replaces its cache.
    const second = (try dom.style.computedStyle(input, null)) orelse return error.NoStyle;
    try testing.expect(second != first);
    try expectColor(first, "rgb(1, 2, 3)");
}

test "a volatile control's style read first is still readable after a second read of the control" {
    try runIsolated(volatileControl);
}

fn volatileAncestor() !void {
    const page = try Page.open("<style>:checked { outline: 1px solid }</style><select id=s style='color: rgb(4, 5, 6)'><option id=o>x</option></select>");
    defer page.close();
    const select = try page.byId("s");
    const option = try page.byId("o");
    const first = (try dom.style.computedStyle(select, null)) orelse return error.NoStyle;
    try testing.expect(isVolatile(select));
    // A read of a descendant resolves every volatile ancestor again.
    _ = (try dom.style.computedStyle(option, null)) orelse return error.NoStyle;
    try testing.expect(dom.style.element_style.existingOf(select).?.cached.?.style != first);
    try expectColor(first, "rgb(4, 5, 6)");
}

test "a volatile select's style read first is still readable after a read of its option (lineage)" {
    try runIsolated(volatileAncestor);
}

fn mutationThenRead() !void {
    const page = try Page.open("<div id=x style='color: rgb(7, 8, 9)'></div><div id=y></div>");
    defer page.close();
    const x = try page.byId("x");
    const y = try page.byId("y");
    const first = (try dom.style.computedStyle(x, null)) orelse return error.NoStyle;
    try testing.expect(!isVolatile(x));
    // A native mutation moves the tree version every cached style is keyed
    // on; the next read of x resolves it again.
    try interfaces.Element.call_setAttribute(y, runtime.DOMString.initInterned("data-x"), .{ .domstring = runtime.DOMString.initInterned("1") });
    const second = (try dom.style.computedStyle(x, null)) orelse return error.NoStyle;
    try testing.expect(second != first);
    try expectColor(first, "rgb(7, 8, 9)");
}

test "a plain element's style read first is still readable after a mutation and a second read" {
    try runIsolated(mutationThenRead);
}

fn placeholderRead() !void {
    // font_loading.selectControl's shape: the control's style, then its
    // ::placeholder's, then the control's again.
    const page = try Page.open("<style>:checked { outline: 1px solid }</style><input id=p placeholder=hint style='color: rgb(10, 11, 12)'>");
    defer page.close();
    const input = try page.byId("p");
    const first = (try dom.style.computedStyle(input, null)) orelse return error.NoStyle;
    try testing.expect(isVolatile(input));
    _ = (try dom.style.computedStyle(input, "placeholder")) orelse return error.NoStyle;
    try testing.expect(dom.style.element_style.existingOf(input).?.cached.?.style != first);
    try expectColor(first, "rgb(10, 11, 12)");
}

test "a control's style read first is still readable after a read of its ::placeholder" {
    try runIsolated(placeholderRead);
}

fn formWithoutAuthorRules() !void {
    // No author sheet: the UA sheet's universal `:autofill` rule
    // (src/dom/style/html.css) is evaluated on every element, and makes a
    // formish element's style - a form's - volatile, and with it every
    // style below it.
    const page = try Page.open("<form id=f><p id=q style='color: rgb(13, 14, 15)'>x</p></form><p id=out>y</p>");
    defer page.close();
    const form = try page.byId("f");
    const q = try page.byId("q");
    const out = try page.byId("out");
    const first = (try dom.style.computedStyle(q, null)) orelse return error.NoStyle;
    try testing.expect(isVolatile(form));
    try testing.expect(isVolatile(q));
    _ = (try dom.style.computedStyle(out, null)) orelse return error.NoStyle;
    try testing.expect(!isVolatile(out));
    const second = (try dom.style.computedStyle(q, null)) orelse return error.NoStyle;
    try testing.expect(second != first);
    try expectColor(first, "rgb(13, 14, 15)");
}

test "with the UA sheet alone, a style inside a form is volatile, and one read first is still readable after a second read" {
    try runIsolated(formWithoutAuthorRules);
}
