//! Location's exotic methods must preserve identity, brands and caller realms.
const std = @import("std");
const engine = @import("engine");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const Host = struct {
    same: bool = true,
    fn allowed(data: ?*anyopaque, _: runtime.Context, _: *runtime.Instance) bool {
        return @as(*Host, @ptrCast(@alignCast(data.?))).same;
    }
};
fn createGlobal(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(realm.allocator, realm) catch null;
}
fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
    std.debug.print("Location probe script error: {s}:{d}: {s}\n", .{ info.filename, info.lineno, info.message });
}
const reporter: engine.Reporter = .{ .report = report };
fn expect(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "bf1-location.js", null, std.testing.allocator, reporter);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}
fn check() !void {
    try engine.initializeEngine(.{});
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    const hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = std.testing.allocator });
    defer engine.destroyAgent(agent);
    var host: Host = .{};
    const page = try engine.createWindowRealm(&.{ .agent = agent, .allocator = std.testing.allocator, .from_snapshot = false, .timer = null, .origin = "https://one.test", .host = &host, .create_global_object = createGlobal, .is_platform_object_same_origin = Host.allowed });
    defer engine.destroyWindowRealm(page, .global_detached);
    const frame = try engine.createWindowRealm(&.{ .agent = agent, .allocator = std.testing.allocator, .from_snapshot = false, .timer = null, .origin = "https://two.test", .parent = page, .host = &host, .create_global_object = createGlobal, .is_platform_object_same_origin = Host.allowed });
    defer engine.destroyWindowRealm(frame, .navigable_destroyed);
    const window = try engine.evaluateClassicScript(frame, .{ .utf8 = "globalThis" }, "", null, reporter);
    defer window.release();
    const global = try engine.evaluateClassicScript(page, .{ .utf8 = "globalThis" }, "", null, reporter);
    defer global.release();
    try engine.defineOwnProperty(page, global.value, "w", window.value, .{ .writable = true, .enumerable = true, .configurable = true });
    try expect(page,
        \\globalThis.saved = w.location;
        \\globalThis.proto = Object.getPrototypeOf(saved);
        \\globalThis.borrowedProto = w.Reflect.getPrototypeOf;
        \\globalThis.borrowedDescriptor = w.Object.getOwnPropertyDescriptor;
        \\globalThis.hrefGetter = Object.getOwnPropertyDescriptor(saved, 'href').get;
        \\globalThis.localHrefGetter = Object.getOwnPropertyDescriptor(location, 'href').get;
        \\globalThis.localHrefSetter = Object.getOwnPropertyDescriptor(location, 'href').set;
        \\globalThis.localHashSetter = Object.getOwnPropertyDescriptor(location, 'hash').set;
        \\globalThis.foreignHashSetter = Object.getOwnPropertyDescriptor(saved, 'hash').set;
        \\globalThis.localAssign = location.assign;
        \\globalThis.localReplace = location.replace;
        \\[saved === w.location, Object.getOwnPropertyDescriptor(saved, 'href').configurable,
        \\ typeof saved.href, typeof saved.pathname, typeof hrefGetter.call(saved),
        \\ Reflect.setPrototypeOf(saved, proto), Reflect.setPrototypeOf(saved, null)].join()
    , "true,false,string,string,string,true,false");
    host.same = false;
    try expect(page,
        \\[Object.getPrototypeOf(saved) === null, borrowedProto(saved) === proto,
        \\ Object.getOwnPropertyDescriptor(saved, 'href').configurable,
        \\ borrowedDescriptor(saved, 'href').configurable,
        \\ Reflect.setPrototypeOf(saved, null), Reflect.setPrototypeOf(saved, {}),
        \\ Reflect.preventExtensions(saved), saved === w.location,
        \\ Object.keys(saved).length, (() => { let n=0; for (const key in saved) n++; return n; })()].join()
    , "true,true,true,false,true,false,false,true,0,0");
    try expect(page,
        \\function outcome(f) { try { f(); return 'accepted'; } catch(e) { return e.name; } }
        \\[outcome(() => saved.href), outcome(() => saved.hash), outcome(() => localHrefGetter.call(saved)),
        \\ outcome(() => localHashSetter.call(saved, Symbol())), outcome(() => localAssign.call(saved, Symbol())),
        \\ outcome(() => Object.defineProperty(saved, 'other', {value: 1})),
        \\ outcome(() => Object.preventExtensions(saved)),
        \\ outcome(() => Object.setPrototypeOf(saved, {})),
        \\ outcome(() => localHrefGetter.call({})), outcome(() => localHashSetter.call({}, '')),
        \\ outcome(() => localAssign.call({}, '')),
        \\ outcome(() => localHrefSetter.call(saved, Symbol())), outcome(() => localReplace.call(saved, Symbol())),
        \\ outcome(() => foreignHashSetter.call(saved, Symbol())), typeof hrefGetter.call(saved)].join()
    , "SecurityError,SecurityError,SecurityError,SecurityError,SecurityError,SecurityError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,string");
    engine.requestGarbageCollection(agent);
    host.same = true;
    try expect(page, "[saved === w.location, Object.getPrototypeOf(saved) === proto, typeof saved.href, typeof hrefGetter.call(saved)].join()", "true,true,string,string");
    try expect(page, "Reflect.ownKeys(saved).includes('pathname')", "true");
    try expect(page,
        \\[Reflect.deleteProperty(saved, 'href'),
        \\ Reflect.defineProperty(saved, 'href', {configurable: true}),
        \\ Reflect.preventExtensions(saved), Reflect.isExtensible(saved)].join()
    , "false,false,false,true");
}

test "Location internal methods keep identity, brands and the current builtin realm" {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = check();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    result catch |err| {
        std.debug.print("Location probe: {s}\n", .{@errorName(err)});
        return err;
    };
}
