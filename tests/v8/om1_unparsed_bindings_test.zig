//! Q74: isolate indexed-binding ownership and exception behavior.
//! Every case uses a fresh thread and std.testing.allocator.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const a = std.testing.allocator;

const Host = struct {
    fn window(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(a, realm) catch null;
    }
    fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
        std.debug.print("om1 unparsed binding script: {s}\n", .{info.message});
    }
};

fn check(source: []const u8) !void {
    try engine.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var scope = runtime.BrowserScope.init(a);
    defer scope.deinit();
    const hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = a });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{ .agent = agent, .allocator = a, .from_snapshot = false, .timer = null, .origin = "https://om1.test", .browser_scope = &scope, .create_global_object = Host.window });
    defer engine.destroyWindowRealm(realm, .global_detached);
    const result = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, a, .{ .report = Host.report, .host = null });
    defer a.free(result);
    try std.testing.expectEqualStrings("ok", result);
}

fn run(source: []const u8) !void {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn body(out: *anyerror!void, text: []const u8) void {
            out.* = check(text);
        }
    }.body, .{ &result, source });
    thread.join();
    try result;
}

test "Unparsed constructor control releases retained string segments without indexed accesses" {
    try run(
        \\(() => {
        \\for (let i = 0; i < 12; ++i) {
        \\  const fallback = new CSSUnparsedValue(['fallback']);
        \\  const reference = new CSSVariableReferenceValue('--x', fallback);
        \\  const value = new CSSUnparsedValue(['prefix', reference, 'suffix']);
        \\  if (value.length !== 3) return 'length';
        \\}
        \\return 'ok';
        \\})()
    );
}

test "Unparsed indexed getter releases its owned USVString union results" {
    try run(
        \\(() => {
        \\const value = new CSSUnparsedValue(['owned getter string']);
        \\for (let i = 0; i < 12; ++i) if (value[0] !== 'owned getter string') return 'getter';
        \\return 'ok';
        \\})()
    );
}

test "Unparsed indexed setter releases converted USVString union arguments" {
    try run(
        \\(() => {
        \\const value = new CSSUnparsedValue(['original']);
        \\for (let i = 0; i < 12; ++i) value[0] = 'replacement ' + i;
        \\return value.length === 1 ? 'ok' : 'length';
        \\})()
    );
}

test "Unparsed indexed setter propagates RangeError and does not define an own property" {
    try run(
        \\(() => {
        \\const value = new CSSUnparsedValue(['original']);
        \\let thrown;
        \\try { value[2] = 'gap'; } catch (error) { thrown = error; }
        \\if (!(thrown instanceof RangeError)) return 'RangeError was swallowed';
        \\if (Object.hasOwn(value, '2') || value.length !== 1) return 'mutation after throw';
        \\return 'ok';
        \\})()
    );
}

test "Unparsed iteration releases each indexed string result" {
    try run(
        \\(() => {
        \\const value = new CSSUnparsedValue(['first owned', 'second owned']);
        \\for (let i = 0; i < 6; ++i) if (Array.from(value).join('|') !== 'first owned|second owned') return 'iterator';
        \\return 'ok';
        \\})()
    );
}
