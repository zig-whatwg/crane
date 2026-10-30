//! WebIDL 3.2.25 steps 13/17 and 3.2.7 step 2; liaison Q78.
//! Exercise generated bindings, never duplicate conversion in an impl.
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
        std.debug.print("om1 numeric union binding script: {s}\n", .{info.message});
    }
};

fn check() !void {
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
    const source =
        \\(() => {
        \\const cases = [
        \\ ['sum', x => new CSSMathSum(3, x), 5],
        \\ ['product', x => new CSSMathProduct(3, x), 6],
        \\ ['min', x => new CSSMathMin(3, x), 2],
        \\ ['max', x => new CSSMathMax(3, x), 3],
        \\ ['clamp-lower', x => new CSSMathClamp(x, 3, 4), 3],
        \\ ['clamp-value', x => new CSSMathClamp(1, x, 3), 2],
        \\ ['clamp-upper', x => new CSSMathClamp(0, 1, x), 1],
        \\ ['negate', x => new CSSMathNegate(x), -2],
        \\ ['invert', x => new CSSMathInvert(x), 0.5],
        \\ ['add', x => CSS.number(8).add(3, x), 13],
        \\ ['sub', x => CSS.number(8).sub(3, x), 3],
        \\ ['mul', x => CSS.number(8).mul(3, x), 48],
        \\ ['div', x => CSS.number(8).div(4, x), 1],
        \\ ['method-min', x => CSS.number(8).min(3, x), 2],
        \\ ['method-max', x => CSS.number(8).max(3, x), 8],
        \\ ['equals', x => CSS.number(8).equals(8, x), false]
        \\];
        \\const failures = [];
        \\for (const [name, invoke, expected] of cases) {
        \\ for (const bad of [NaN, Infinity, -Infinity]) for (const boxed of [false, true]) {
        \\  let hits = 0;
        \\  const input = boxed ? {valueOf() { hits++; return bad; }} : bad;
        \\  let caught;
        \\  try { invoke(input); } catch (error) { caught = error; }
        \\  if (!(caught instanceof TypeError)) failures.push(name + ':' + bad + ':' + boxed + ':' + (caught?.name || 'accepted'));
        \\  if (boxed && hits !== 1) failures.push(name + ':conversion-count:' + hits);
        \\ }
        \\ for (const boxed of [false, true]) {
        \\  let hits = 0;
        \\  const input = boxed ? {valueOf() { hits++; return 2; }} : 2;
        \\  try {
        \\   const value = invoke(input);
        \\   const actual = name === 'equals' ? value : value.to('number').value;
        \\   if (actual !== expected) failures.push(name + ':finite:' + actual);
        \\  } catch (error) { failures.push(name + ':finite:' + error.name); }
        \\  if (boxed && hits !== 1) failures.push(name + ':finite-count:' + hits);
        \\ }
        \\}
        \\return failures.join(';') || 'ok';
        \\})()
    ;
    const result = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, a, .{ .report = Host.report, .host = null });
    defer a.free(result);
    try std.testing.expectEqualStrings("ok", result);
}

test "CSSNumberish union arms apply restricted double conversion in constructors and variadic methods" {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(out: *anyerror!void) void {
            out.* = check();
        }
    }.run, .{&result});
    thread.join();
    try result;
}
