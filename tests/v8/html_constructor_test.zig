//! [HTMLConstructor] across the engine seam, as the V8 binding runs it: HTML
//! 3.2.3 "HTML element constructors" with a test-installed
//! HostHooks.htmlConstructor standing in for the custom elements side.
//!
//! The engine does step 1 (NewTarget equal to the active function object is
//! a TypeError) and steps 10-11, 14 and 16; the host does 2-9, 12, 13 and 15
//! and answers `.created` - a new element the engine wraps in the object it
//! made for NewTarget - or `.upgrading` - the construction stack's element,
//! whose wrapper (the one it has, else that object) gets NewTarget's
//! prototype and is the result. No hook: an [HTMLConstructor] interface
//! constructs as it always has.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agents.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// The test's custom elements side: what it was asked, and what it answers.
const Host = struct {
    answer: Answer = .created,
    /// The element to answer `.upgrading` with (BORROWED: the test keeps it
    /// reachable, as a construction stack does).
    upgrading: ?*runtime.Instance = null,
    calls: usize = 0,
    interface_buffer: [64]u8 = undefined,
    interface_len: usize = 0,
    /// NewTarget as the hook saw it, retained to compare.
    new_target: ?protocol.Owned = null,

    const Answer = enum { created, upgrading, type_error };

    const hooks: protocol.HostHooks = .{ .htmlConstructor = construct };

    fn construct(host: ?*anyopaque, realm: runtime.Context, new_target: runtime.JSValue, interface: []const u8) protocol.Error!protocol.HTMLConstructed {
        const self: *Host = @ptrCast(@alignCast(host.?));
        self.calls += 1;
        self.interface_len = @min(interface.len, self.interface_buffer.len);
        @memcpy(self.interface_buffer[0..self.interface_len], interface[0..self.interface_len]);
        if (self.new_target) |held| held.release();
        self.new_target = try protocol.retainValue(realm, new_target);
        return switch (self.answer) {
            // 9.1: a new object implementing the interface - here the plain
            // element the interface's own constructor makes.
            .created => .{ .created = if (std.mem.eql(u8, interface, "HTMLParagraphElement"))
                try interfaces.HTMLParagraphElement.call_constructor(realm)
            else
                try interfaces.HTMLElement.call_constructor(realm) },
            .upgrading => .{ .upgrading = self.upgrading.? },
            .type_error => error.TypeError,
        };
    }

    fn seenInterface(self: *const Host) []const u8 {
        return self.interface_buffer[0..self.interface_len];
    }

    fn deinit(self: *Host) void {
        if (self.new_target) |held| held.release();
        self.new_target = null;
    }
};

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

/// An agent with `hooks` (and `host`) and a Window realm of it.
const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open(hooks: *const protocol.HostHooks, host: ?*anyopaque) !Page {
        try setup();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = hooks, .host = host });
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

    /// `source`'s completion value, as a string; nothing reported.
    fn eval(self: Page, source: []const u8) ![]u8 {
        var reports: Reports = .{};
        const result = try protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter());
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        return result;
    }

    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        const got = try self.eval(source);
        defer std.testing.allocator.free(got);
        try std.testing.expectEqualStrings(expected, got);
    }

    /// `source`'s completion value, OWNED.
    fn value(self: Page, source: []const u8) !protocol.Owned {
        var reports: Reports = .{};
        return protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
    }

    /// The platform object `source` evaluates to.
    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        const held = try self.value(source);
        defer held.release();
        return protocol.convertToPlatformObject(self.realm, held.value) orelse error.NotAPlatformObject;
    }

    /// V8's live global handle bytes, read inside the realm.
    fn globalHandleBytes(self: Page) !usize {
        const Read = struct {
            agent: *protocol.Agent,
            bytes: usize = 0,
            fn steps(data: ?*anyopaque) void {
                const read: *@This() = @ptrCast(@alignCast(data.?));
                read.bytes = ffi.v8_Isolate_GetGlobalHandleBytes(@ptrCast(@alignCast(read.agent)));
            }
        };
        var read: Read = .{ .agent = self.agent };
        try protocol.runInRealm(self.realm, Read.steps, &read);
        return read.bytes;
    }

    /// A full collection, inside the realm.
    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }
};

test "created: a custom element class constructs the host's new element, with NewTarget's prototype" {
    var host: Host = .{};
    defer host.deinit();
    const page = try Page.open(&Host.hooks, &host);
    defer page.close();

    try page.expect(
        \\globalThis.X = class X extends HTMLElement {};
        \\const made = new X();
        \\String(made instanceof X && made instanceof HTMLElement && Object.getPrototypeOf(made) === X.prototype)
    , "true");
    try std.testing.expectEqual(@as(usize, 1), host.calls);
    try std.testing.expectEqualStrings("HTMLElement", host.seenInterface());
    // NewTarget, BORROWED for the call: X itself.
    const x = try page.value("X");
    defer x.release();
    try std.testing.expect(protocol.sameValue(page.realm, x.value, host.new_target.?.value));

    // Reflect.construct names NewTarget directly: the same path.
    try page.expect("globalThis.Y = class Y extends HTMLElement {}; String(Object.getPrototypeOf(Reflect.construct(HTMLElement, [], Y)) === Y.prototype)", "true");
    try std.testing.expectEqual(@as(usize, 2), host.calls);
}

test "created: a customized built-in's super() names its own interface" {
    var host: Host = .{};
    defer host.deinit();
    const page = try Page.open(&Host.hooks, &host);
    defer page.close();
    _ = try page.eval("class P extends HTMLParagraphElement {}; void new P()");
    try std.testing.expectEqualStrings("HTMLParagraphElement", host.seenInterface());
}

test "step 1: NewTarget equal to the active function object is a TypeError, and the host is never asked" {
    var host: Host = .{};
    defer host.deinit();
    const page = try Page.open(&Host.hooks, &host);
    defer page.close();
    try page.expect("try { new HTMLElement(); 'constructed' } catch (e) { e.constructor.name }", "TypeError");
    try page.expect("try { new HTMLParagraphElement(); 'constructed' } catch (e) { e.constructor.name }", "TypeError");
    try page.expect("try { Reflect.construct(HTMLElement, [], HTMLElement); 'constructed' } catch (e) { e.constructor.name }", "TypeError");
    // Called without new: a TypeError as before.
    try page.expect("try { HTMLElement(); 'called' } catch (e) { e.constructor.name }", "TypeError");
    try std.testing.expectEqual(@as(usize, 0), host.calls);
}

test "the host's TypeError is thrown by the construction" {
    var host: Host = .{ .answer = .type_error };
    defer host.deinit();
    const page = try Page.open(&Host.hooks, &host);
    defer page.close();
    try page.expect("class X extends HTMLElement {}; try { new X(); 'constructed' } catch (e) { e instanceof TypeError }", "true");
    try std.testing.expectEqual(@as(usize, 1), host.calls);
}

test "upgrading an element script never saw: the object made for NewTarget becomes its wrapper" {
    var host: Host = .{ .answer = .upgrading };
    defer host.deinit();
    const page = try Page.open(&Host.hooks, &host);
    defer page.close();
    // An element with no wrapper yet, as the parser makes one.
    const element = try interfaces.HTMLElement.call_constructor(page.realm);
    host.upgrading = element;
    try std.testing.expect(!protocol.hasWrapper(element));
    try page.expect("globalThis.X = class X extends HTMLElement {}; globalThis.made = new X(); String(Object.getPrototypeOf(made) === X.prototype)", "true");
    // The result is that element's wrapper.
    try std.testing.expectEqual(element, try page.instance("made"));
    try std.testing.expect(protocol.hasWrapper(element));
}

test "upgrading an element with a wrapper: that wrapper, its prototype set, is the result; the receiver is bound to nothing" {
    var host: Host = .{};
    defer host.deinit();
    const page = try Page.open(&Host.hooks, &host);
    defer page.close();
    // A wrapped element: one the host created and script holds.
    try page.expect("globalThis.X = class X extends HTMLElement {}; globalThis.first = new X(); 'ok'", "ok");
    const element = try page.instance("first");
    host.answer = .upgrading;
    host.upgrading = element;

    try page.expect(
        \\globalThis.Y = class Y extends HTMLElement { constructor() { super(); this.marked = true; } };
        \\const again = new Y();
        \\String(again === first && Object.getPrototypeOf(first) === Y.prototype && first.marked === true)
    , "true");

    // The receiver V8 made for Y is discarded: no handle of it is kept, and
    // nothing registered it for the element - a later wrap still answers the
    // original wrapper.
    try page.collect();
    const before = try page.globalHandleBytes();
    _ = try page.eval("for (let i = 0; i < 32; i++) { if (new Y() !== first) throw new Error('identity'); } 'ok'");
    try page.collect();
    try std.testing.expect(try page.globalHandleBytes() <= before);
    try page.expect("String(new Y() === first)", "true");
    try std.testing.expectEqual(element, try page.instance("first"));
}

test "no hook: an [HTMLConstructor] interface constructs as its own constructor does" {
    const no_hooks: protocol.HostHooks = .{};
    const page = try Page.open(&no_hooks, null);
    defer page.close();
    try page.expect("String(new HTMLElement() instanceof HTMLElement)", "true");
    try page.expect("class X extends HTMLElement {}; String(Object.getPrototypeOf(new X()) === X.prototype)", "true");
}

test "the legacy factory functions are their own constructors: Image, Audio and Option never reach the hook" {
    // Each runs its own steps - the same outcome with the hook installed as
    // without it. (This test's Window has no Document, which the factory
    // functions' "current global object's associated Document" needs, so
    // here that outcome is their own TypeError.)
    const sources = .{ "new Image()", "new Audio()", "new Option()", "class I extends Image {}; new I()" };
    var outcomes: [sources.len][]u8 = undefined;
    var host: Host = .{};
    defer host.deinit();
    {
        const page = try Page.open(&Host.hooks, &host);
        defer page.close();
        inline for (sources, 0..) |source, i| {
            outcomes[i] = try page.eval("try { const o = " ++ source ++ "; o.constructor.name } catch (e) { e.constructor.name }");
        }
    }
    defer for (outcomes) |o| std.testing.allocator.free(o);
    try std.testing.expectEqual(@as(usize, 0), host.calls);

    const no_hooks: protocol.HostHooks = .{};
    const page = try Page.open(&no_hooks, null);
    defer page.close();
    inline for (sources, 0..) |source, i| {
        const plain = try page.eval("try { const o = " ++ source ++ "; o.constructor.name } catch (e) { e.constructor.name }");
        defer std.testing.allocator.free(plain);
        try std.testing.expectEqualStrings(plain, outcomes[i]);
    }
}
