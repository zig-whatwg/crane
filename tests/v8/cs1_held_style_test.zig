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
//! dom.style.computedStyle HOLDS what it answers (dom.style.HeldStyle, a
//! reference on the style: ComputedStyle.refs): each test reads a style,
//! makes the read that replaces its cache entry, and then reads the first
//! style - on a realm allocated from std.testing.allocator, whose free
//! poisons (0x55), so a freed style would fault on its first field (red
//! before the hold: e0c063b12). A hold is released before script runs
//! (runtime.native_holds), so every mutation here is native.

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
    defer first.release();
    try testing.expect(isVolatile(input));
    // The second read resolves the control again and replaces its cache.
    const second = (try dom.style.computedStyle(input, null)) orelse return error.NoStyle;
    defer second.release();
    try testing.expect(second.style != first.style);
    try expectColor(first.style, "rgb(1, 2, 3)");
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
    defer first.release();
    try testing.expect(isVolatile(select));
    // A read of a descendant resolves every volatile ancestor again.
    try dom.style.engine.resolveStyle(option, null);
    try testing.expect(dom.style.element_style.existingOf(select).?.cached.?.style != first.style);
    try expectColor(first.style, "rgb(4, 5, 6)");
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
    defer first.release();
    try testing.expect(!isVolatile(x));
    // A native mutation moves the tree version every cached style is keyed
    // on; the next read of x resolves it again.
    try interfaces.Element.call_setAttribute(y, runtime.DOMString.initInterned("data-x"), .{ .domstring = runtime.DOMString.initInterned("1") });
    const second = (try dom.style.computedStyle(x, null)) orelse return error.NoStyle;
    defer second.release();
    try testing.expect(second.style != first.style);
    try expectColor(first.style, "rgb(7, 8, 9)");
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
    defer first.release();
    try testing.expect(isVolatile(input));
    const hint = (try dom.style.computedStyle(input, "placeholder")) orelse return error.NoStyle;
    defer hint.release();
    try testing.expect(dom.style.element_style.existingOf(input).?.cached.?.style != first.style);
    try expectColor(first.style, "rgb(10, 11, 12)");
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
    defer first.release();
    try testing.expect(isVolatile(form));
    try testing.expect(isVolatile(q));
    try dom.style.engine.resolveStyle(out, null);
    try testing.expect(!isVolatile(out));
    const second = (try dom.style.computedStyle(q, null)) orelse return error.NoStyle;
    defer second.release();
    try testing.expect(second.style != first.style);
    try expectColor(first.style, "rgb(13, 14, 15)");
}

test "with the UA sheet alone, a style inside a form is volatile, and one read first is still readable after a second read" {
    try runIsolated(formWithoutAuthorRules);
}

fn holdsCounted() !void {
    const page = try Page.open("<div id=x></div>");
    defer page.close();
    const x = try page.byId("x");
    try testing.expectEqual(@import("builtin").mode == .debug, runtime.native_holds.enabled);
    try testing.expectEqual(@as(u32, 0), runtime.native_holds.count(page.agent));
    const held = (try dom.style.computedStyle(x, null)) orelse return error.NoStyle;
    // Debug counts the hold on the agent: a script entry or an event-loop
    // turn now would panic (runtime.native_holds.assertNone).
    try testing.expectEqual(@as(u32, if (runtime.native_holds.enabled) 1 else 0), runtime.native_holds.count(page.agent));
    held.release();
    try testing.expectEqual(@as(u32, 0), runtime.native_holds.count(page.agent));
}

test "a hold is counted on its agent while it lives (Debug), and no longer once released" {
    try runIsolated(holdsCounted);
}

fn fullCount() !void {
    const page = try Page.open("<div id=x style='color: rgb(1, 2, 3)'></div>");
    defer page.close();
    const x = try page.byId("x");
    var holds: [300]dom.style.HeldStyle = undefined;
    var taken: usize = 0;
    defer for (holds[0..taken]) |held| held.release();
    while (taken < holds.len) : (taken += 1) holds[taken] = (try dom.style.computedStyle(x, null)) orelse return error.NoStyle;
    // The cache's reference and 254 holds fill the one-byte count; every
    // later hold is on a clone of the style, a holder of its own, with the
    // same values.
    const cached = dom.style.element_style.existingOf(x).?.cached.?.style;
    try testing.expect(holds[253].style == cached);
    for (holds[254..]) |held| try testing.expect(held.style != cached);
    for (holds) |held| try expectColor(held.style, "rgb(1, 2, 3)");
}

test "past the one-byte count, a hold takes a clone: every hold reads the same values, and each is freed" {
    try runIsolated(fullCount);
}

/// Whether `T` - a return type, through its error union and optional - is a
/// bare computed style pointer.
fn isRawStyle(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |p| p.child == ComputedStyle,
        .optional => |o| isRawStyle(o.child),
        .error_union => |e| isRawStyle(e.payload),
        else => false,
    };
}

/// The public functions of `namespace` that return a bare style pointer.
fn rawStyleReturners(comptime namespace: type) []const []const u8 {
    comptime {
        var names: []const []const u8 = &.{};
        for (std.meta.declarations(namespace)) |name| {
            const T = @TypeOf(@field(namespace, name));
            const info = @typeInfo(T);
            if (info != .@"fn") continue;
            const returned = info.@"fn".return_type orelse continue;
            if (isRawStyle(returned)) names = names ++ .{name};
        }
        return names;
    }
}

test "no public function of the style engine answers a bare computed style: it is held (dom.style.HeldStyle) or kept private" {
    inline for (.{ dom.style, dom.style.engine }) |namespace| {
        const found = comptime rawStyleReturners(namespace);
        if (found.len != 0) {
            for (found) |name| std.debug.print("returns a bare *ComputedStyle: {s}\n", .{name});
            return error.TestUnexpectedResult;
        }
    }
}
