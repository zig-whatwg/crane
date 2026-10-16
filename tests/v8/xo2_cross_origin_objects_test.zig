//! HTML 7.2.1 cross-origin objects on V8 [cross_origin_objects]: a frame's
//! WindowProxy and its Location, reached from its parent's realm, run the
//! cross-origin internal methods whenever the host's
//! IsPlatformObjectSameOrigin (WindowRealmOptions.is_platform_object_same_origin)
//! says the two realms are not same origin-domain - and are ordinary objects
//! when it says they are. The adapter asks on every access from another
//! realm: a document's domain changes at any time, so no answer is kept.
//!
//! The host here is the test's: `Host.same_origin` is the answer, flipped
//! between scripts. The realms are made as a page's and its frame's are
//! (createWindowRealm with the frame's parent).
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agent per test.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const cross_origin = @import("v8").cross_origin;
const v8_engine = @import("v8").engine;

/// The test's IsPlatformObjectSameOrigin: one answer for every pair, and a
/// count of the times the adapter asked.
const Host = struct {
    same_origin: bool = true,
    asked: usize = 0,

    fn isPlatformObjectSameOrigin(host: ?*anyopaque, current: runtime.Context, object: *runtime.Instance) bool {
        _ = current;
        _ = object;
        const self: *Host = @ptrCast(@alignCast(host.?));
        self.asked += 1;
        return self.same_origin;
    }

    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
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

fn ignoreReport(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
    _ = host;
    _ = info;
}

/// A page and one frame of it, with `w` in the page bound to the frame's
/// WindowProxy.
const Pair = struct {
    agent: *protocol.Agent,
    page: runtime.Context,
    frame: runtime.Context,
    host: *Host,

    fn open(host: *Host) !Pair {
        try setup();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const page = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = Host.createGlobalObject,
            .is_platform_object_same_origin = Host.isPlatformObjectSameOrigin,
            .host = host,
        });
        errdefer protocol.destroyWindowRealm(page, .global_detached);
        const frame = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://other.test",
            .parent = page,
            .create_global_object = Host.createGlobalObject,
            .is_platform_object_same_origin = Host.isPlatformObjectSameOrigin,
            .host = host,
        });
        const pair: Pair = .{ .agent = agent, .page = page, .frame = frame, .host = host };
        // The frame's WindowProxy, as the page's `w`: defined while the two
        // are same origin-domain.
        const saved = host.same_origin;
        host.same_origin = true;
        defer host.same_origin = saved;
        const proxy = try protocol.evaluateClassicScript(frame, .{ .utf8 = "globalThis" }, "", null, .{ .report = ignoreReport });
        defer proxy.release();
        const global = try protocol.evaluateClassicScript(page, .{ .utf8 = "globalThis" }, "", null, .{ .report = ignoreReport });
        defer global.release();
        try protocol.defineOwnProperty(page, global.value, "w", proxy.value, .{ .writable = true, .enumerable = false, .configurable = true });
        return pair;
    }

    fn close(self: Pair) void {
        protocol.destroyWindowRealm(self.frame, .navigable_destroyed);
        protocol.destroyWindowRealm(self.page, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn expect(self: Pair, realm: runtime.Context, source: []const u8, expected: []const u8) !void {
        const got = protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = ignoreReport }) catch |err| {
            std.debug.print("evaluating failed ({s}): {s}\n", .{ @errorName(err), source });
            return err;
        };
        _ = self;
        defer testing.allocator.free(got);
        testing.expectEqualStrings(expected, got) catch |err| {
            std.debug.print("source: {s}\n", .{source});
            return err;
        };
    }

    fn inPage(self: Pair, source: []const u8, expected: []const u8) !void {
        return self.expect(self.page, source, expected);
    }

    fn inFrame(self: Pair, source: []const u8, expected: []const u8) !void {
        return self.expect(self.frame, source, expected);
    }
};

/// `f()`'s value as a string, or the name of what it threw - with
/// ":current" when that is a DOMException of the realm the script runs in.
const outcome =
    \\function outcome(f) {
    \\  try { return String(f()); }
    \\  catch (e) { return e.name + (e instanceof DOMException ? ":current" : ""); }
    \\}
;

test "a frame same origin-domain with its page is an ordinary object to it" {
    var host: Host = .{};
    const pair = try Pair.open(&host);
    defer pair.close();
    try pair.inPage("w.expando = 5; [w.expando, Object.getPrototypeOf(w) !== null].join()", "5,true");
}

test "the page's own window never asks the host" {
    var host: Host = .{ .same_origin = false };
    const pair = try Pair.open(&host);
    defer pair.close();
    host.asked = 0;
    try pair.inPage("window.mine = 1; String(window.mine + self.mine)", "2");
    try testing.expectEqual(@as(usize, 0), host.asked);
}

test "cross-origin [[Get]] of a property outside CrossOriginProperties throws the current realm's SecurityError" {
    var host: Host = .{};
    const pair = try Pair.open(&host);
    defer pair.close();
    try pair.inFrame("globalThis.secret = 1; 'set'", "set");
    host.same_origin = false;
    try pair.inPage(outcome ++ "[outcome(() => w.secret), outcome(() => w.document), outcome(() => w.name)].join()", "SecurityError:current,SecurityError:current,SecurityError:current");
}

test "every access asks again: no answer is kept" {
    var host: Host = .{};
    const pair = try Pair.open(&host);
    defer pair.close();
    try pair.inPage(outcome ++ "w.kept = 7; outcome(() => w.kept)", "7");
    host.same_origin = false;
    try pair.inPage(outcome ++ "outcome(() => w.kept)", "SecurityError:current");
    host.same_origin = true;
    try pair.inPage(outcome ++ "outcome(() => w.kept)", "7");
}

test "cross-origin [[Get]] answers the cross-origin attributes" {
    var host: Host = .{ .same_origin = false };
    const pair = try Pair.open(&host);
    defer pair.close();
    try pair.inPage("[w.window === w, w.self === w, w.frames === w, typeof w.closed, w.length].join()", "true,true,true,boolean,0");
}

test "cross-origin then and the three well-known symbols read undefined; other symbols throw" {
    var host: Host = .{ .same_origin = false };
    const pair = try Pair.open(&host);
    defer pair.close();
    try pair.inPage(outcome ++
        \\[w.then, w[Symbol.toStringTag], w[Symbol.hasInstance], w[Symbol.isConcatSpreadable]].map(String).join() +
        \\  ';' + outcome(() => w[Symbol.iterator]) + ';' + ({}).toString.call(w)
    , "undefined,undefined,undefined,undefined;SecurityError:current;[object Object]");
}

test "cross-origin [[GetPrototypeOf]] is null and [[IsExtensible]] true" {
    var host: Host = .{ .same_origin = false };
    const pair = try Pair.open(&host);
    defer pair.close();
    try pair.inPage("[Object.getPrototypeOf(w) === null, Object.isExtensible(w)].join()", "true,true");
}

test "cross-origin expandos are refused" {
    var host: Host = .{};
    const pair = try Pair.open(&host);
    defer pair.close();
    try pair.inPage("w.existing = 1; 'ok'", "ok");
    host.same_origin = false;
    try pair.inPage(outcome ++
        \\[outcome(() => { w.foo = 1; }), outcome(() => Object.defineProperty(w, 'foo', { value: 1 })),
        \\ outcome(() => delete w.existing), outcome(() => { w.close = 1; })].join()
    , "SecurityError:current,SecurityError:current,SecurityError:current,SecurityError:current");
    host.same_origin = true;
    try pair.inPage("[w.existing, 'foo' in w].join()", "1,false");
}

test "cross-origin [[OwnPropertyKeys]] are CrossOriginProperties, then and the three symbols" {
    var host: Host = .{ .same_origin = false };
    const pair = try Pair.open(&host);
    defer pair.close();
    try pair.inPage("Reflect.ownKeys(w).map(String).join()", "window,self,location,close,closed,focus,blur,frames,length,top,opener,parent,postMessage,then,Symbol(Symbol.toStringTag),Symbol(Symbol.hasInstance),Symbol(Symbol.isConcatSpreadable)");
    try pair.inPage("[Object.keys(w).length, (() => { let n = 0; for (const k in w) n++; return n; })()].join()", "0,0");
}

test "cross-origin property descriptors" {
    var host: Host = .{ .same_origin = false };
    const pair = try Pair.open(&host);
    defer pair.close();
    try pair.inPage(
        \\// An accessor descriptor has no [[Writable]]: join() writes it as "".
        \\const d = (p) => { const x = Object.getOwnPropertyDescriptor(w, p);
        \\  return [typeof x.value, typeof x.get, typeof x.set, x.writable, x.enumerable, x.configurable].join('/'); };
        \\[d('close'), d('parent'), d('location'), d('then'), d(Symbol.toStringTag)].join(' ')
    , "function/undefined/undefined/false/false/true undefined/function/undefined//false/true undefined/function/function//false/true undefined/undefined/undefined/false/false/true undefined/undefined/undefined/false/false/true");
    try pair.inPage(outcome ++ "[outcome(() => Object.getOwnPropertyDescriptor(w, 'document')), outcome(() => Object.prototype.hasOwnProperty.call(w, 'document')), Object.prototype.hasOwnProperty.call(w, 'close')].join()", "SecurityError:current,SecurityError:current,true");
}

test "cross-origin functions are the current realm's, cached, and named as the members" {
    var host: Host = .{ .same_origin = false };
    const pair = try Pair.open(&host);
    defer pair.close();
    try pair.inPage(
        \\const pd = Object.getOwnPropertyDescriptor(w, 'parent'), ld = Object.getOwnPropertyDescriptor(w, 'location');
        \\[w.close === w.close, Object.getPrototypeOf(w.close) === Function.prototype, w.close !== close,
        \\ w.close.name, w.close.length, w.postMessage.length, pd.get.name, pd.get === Object.getOwnPropertyDescriptor(w, 'parent').get,
        \\ ld.set.name, ld.set.length, Object.getPrototypeOf(pd.get) === Function.prototype].join()
    , "true,true,true,close,0,1,get parent,true,set location,1,true");
}

test "a member that is not cross-origin throws SecurityError for a cross-origin this; a cross-origin one runs" {
    var host: Host = .{ .same_origin = false };
    const pair = try Pair.open(&host);
    defer pair.close();
    try pair.inPage(outcome ++
        \\[outcome(() => Object.getOwnPropertyDescriptor(window, 'name').get.call(w)),
        \\ outcome(() => EventTarget.prototype.addEventListener.call(w, 'x', () => {})),
        \\ outcome(() => focus.call(w))].join()
    , "SecurityError:current,SecurityError:current,undefined");
}

test "a window member called with another same-origin window's this acts on that window" {
    var host: Host = .{};
    const pair = try Pair.open(&host);
    defer pair.close();
    try pair.inFrame("name = 'inner'; name", "inner");
    try pair.inPage("name = 'outer'; Object.getOwnPropertyDescriptor(window, 'name').get.call(w)", "inner");
}

/// Window operations that do nothing, for a realm whose natively bound
/// timers and animation frames (installWindowOperations) a test calls. The
/// values they are handed are theirs to release.
const idle_window_operations = runtime.WindowOperations{
    .initializeTimer = struct {
        fn f(_: runtime.Context, handler: runtime.WindowTimerHandler, _: i32, arguments: []const runtime.JSValue, _: bool) i32 {
            switch (handler) {
                inline else => |h| v8_engine.v8ReleaseValue(h),
            }
            for (arguments) |argument| v8_engine.v8ReleaseValue(argument);
            return 0;
        }
    }.f,
    .clearTimer = struct {
        fn f(_: runtime.Context, _: i32) void {}
    }.f,
    .requestAnimationFrame = struct {
        fn f(_: runtime.Context, callback: runtime.JSValue) u32 {
            v8_engine.v8ReleaseValue(callback);
            return 0;
        }
    }.f,
    .cancelAnimationFrame = struct {
        fn f(_: runtime.Context, _: u32) void {}
    }.f,
    .windowDestroyed = struct {
        fn f(_: runtime.Context) void {}
    }.f,
};

test "the natively bound window operations run WebIDL's security check for a cross-origin this" {
    // setTimeout, clearTimeout, setInterval, clearInterval,
    // requestAnimationFrame and cancelAnimationFrame are bound by
    // installWindowOperations, not the generated binding; none is in
    // CrossOriginProperties, so each throws the current realm's
    // SecurityError for a cross-origin WindowProxy `this` - before its
    // arguments are looked at (html/browsers/origin/cross-origin-objects/
    // cross-origin-objects.html, "Only certain properties are usable as
    // cross-origin this objects").
    var host: Host = .{ .same_origin = false };
    const pair = try Pair.open(&host);
    defer pair.close();
    try protocol.installWindowOperations(pair.page, &idle_window_operations);
    try pair.inPage(outcome ++
        \\['setTimeout', 'clearTimeout', 'setInterval', 'clearInterval', 'requestAnimationFrame', 'cancelAnimationFrame']
        \\  .map((n) => outcome(() => globalThis[n].call(w))).join()
    , "SecurityError:current,SecurityError:current,SecurityError:current,SecurityError:current,SecurityError:current,SecurityError:current");
    // Same origin-domain, the operation runs on its own window.
    host.same_origin = true;
    try pair.inPage(outcome ++ "outcome(() => clearTimeout.call(w, 1))", "undefined");
}

test "a cross-origin Location exposes only href's setter and replace" {
    var host: Host = .{};
    const pair = try Pair.open(&host);
    defer pair.close();
    try pair.inPage("globalThis.l = w.location; String(Object.getPrototypeOf(l) !== null)", "true");
    host.same_origin = false;
    try pair.inPage(outcome ++
        \\const hd = Object.getOwnPropertyDescriptor(l, 'href'), rd = Object.getOwnPropertyDescriptor(l, 'replace');
        \\[outcome(() => l.href), outcome(() => l.host), outcome(() => { l.foo = 1; }), outcome(() => delete l.hash),
        \\ Object.getPrototypeOf(l) === null, w.location === l, typeof l.replace, l.replace === l.replace,
        \\ l.replace.name, l.replace.length, typeof hd.get, hd.set.name, typeof rd.value, rd.writable,
        \\ Reflect.ownKeys(l).map(String).join('|')].join()
    , "SecurityError:current,SecurityError:current,SecurityError:current,SecurityError:current,true,true,function,true,replace,1,undefined,set href,function,false,href|replace|then|Symbol(Symbol.toStringTag)|Symbol(Symbol.hasInstance)|Symbol(Symbol.isConcatSpreadable)");
}

test "a Location's own realm never asks the host" {
    var host: Host = .{ .same_origin = false };
    const pair = try Pair.open(&host);
    defer pair.close();
    host.asked = 0;
    try pair.inFrame("typeof location.href + typeof location.replace", "stringfunction");
    try testing.expectEqual(@as(usize, 0), host.asked);
}

test "WebIDL's security check is skipped only for the members CrossOriginProperties lists" {
    // The default - a member nobody listed - is the check, the safe answer.
    const accepts = cross_origin.acceptsAnyReceiver;
    try testing.expect(!accepts("Window", "document", .getter));
    try testing.expect(!accepts("Window", "name", .setter));
    try testing.expect(!accepts("Window", "alert", .operation));
    try testing.expect(!accepts("Window", "aMemberNobodyListed", .getter));
    try testing.expect(!accepts("EventTarget", "addEventListener", .operation));
    try testing.expect(!accepts("Location", "href", .getter));
    try testing.expect(!accepts("Location", "assign", .operation));
    // The table: a getter, a setter or an operation, as each entry says.
    try testing.expect(accepts("Window", "location", .getter));
    try testing.expect(accepts("Window", "location", .setter));
    try testing.expect(!accepts("Window", "parent", .setter));
    try testing.expect(accepts("Window", "postMessage", .operation));
    try testing.expect(!accepts("Window", "postMessage", .getter));
    try testing.expect(accepts("Location", "href", .setter));
    try testing.expect(accepts("Location", "replace", .operation));
    // Interfaces no Window or Location implements keep V8's default.
    try testing.expect(accepts("Node", "appendChild", .operation));
    try testing.expectEqual(@as(usize, 13), cross_origin.window_properties.len);
    try testing.expectEqual(@as(usize, 2), cross_origin.location_properties.len);
}
