//! Typed OM §§4.3.1 and6.4; Q81 Chrome156/Safari27 probe,2026-10-27.
//! Both preserve arithmetic overflow; 1-1 splits use the complete spec.
//! Probes: tmp/probe-q81/RULING.md and tmp/probe-q84/RULING.md.
//! Q84 grants full32-bit exponents, wrapping beyond; test files grantQ82.
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
        std.debug.print("om1 derived numeric script: {s}\n", .{info.message});
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

test "Q81 px multiplication overflow preserves the derived unit value and spec serialization" {
    try run(
        \\(() => {
        \\const v = CSS.px(1e308).mul(2);
        \\if (!(v instanceof CSSUnitValue)) throw new Error('class');
        \\if (!Object.is(v.value, Infinity) || v.unit !== 'px') throw new Error('value/unit');
        \\if (String(v) !== 'infinitypx') throw new Error('String: ' + String(v));
        \\return 'ok'; })()
    );
}

test "Q81 number addition overflow preserves the derived unit value and spec serialization" {
    try run(
        \\(() => {
        \\const v = CSS.number(1e308).add(1e308);
        \\if (!(v instanceof CSSUnitValue)) throw new Error('class');
        \\if (!Object.is(v.value, Infinity) || v.unit !== 'number') throw new Error('value/unit');
        \\if (String(v) !== 'infinity') throw new Error('String: ' + String(v));
        \\return 'ok'; })()
    );
}

test "Q81 number multiplication overflow preserves the derived unit value and spec serialization" {
    try run(
        \\(() => {
        \\const v = CSS.number(1e308).mul(2);
        \\if (!(v instanceof CSSUnitValue)) throw new Error('class');
        \\if (!Object.is(v.value, Infinity) || v.unit !== 'number') throw new Error('value/unit');
        \\if (String(v) !== 'infinity') throw new Error('String: ' + String(v));
        \\return 'ok'; })()
    );
}

test "Q81 zero times overflow preserves the derived unit value and spec serialization" {
    try run(
        \\(() => {
        \\const v = CSS.number(0).mul(CSS.number(1e308).mul(2));
        \\if (!(v instanceof CSSUnitValue)) throw new Error('class');
        \\if (!Object.is(v.value, NaN) || v.unit !== 'number') throw new Error('value/unit');
        \\if (String(v) !== 'NaN') throw new Error('String: ' + String(v));
        \\return 'ok'; })()
    );
}

test "Q81 absolute conversion overflow preserves the derived unit value and spec serialization" {
    try run(
        \\(() => {
        \\const v = CSS.cm(1e308).to('px');
        \\if (!(v instanceof CSSUnitValue)) throw new Error('class');
        \\if (!Object.is(v.value, Infinity) || v.unit !== 'px') throw new Error('value/unit');
        \\if (String(v) !== 'infinitypx') throw new Error('String: ' + String(v));
        \\return 'ok'; })()
    );
}

test "Q81 invert zero to unit preserves the derived unit value and spec serialization" {
    try run(
        \\(() => {
        \\const v = new CSSMathInvert(CSS.number(0)).to('number');
        \\if (!(v instanceof CSSUnitValue)) throw new Error('class');
        \\if (!Object.is(v.value, Infinity) || v.unit !== 'number') throw new Error('value/unit');
        \\if (String(v) !== 'infinity') throw new Error('String: ' + String(v));
        \\return 'ok'; })()
    );
}

test "Q81 negative dimension overflow preserves the derived unit value and spec serialization" {
    try run(
        \\(() => {
        \\const v = CSS.px(-1e308).mul(2);
        \\if (!(v instanceof CSSUnitValue)) throw new Error('class');
        \\if (!Object.is(v.value, -Infinity) || v.unit !== 'px') throw new Error('value/unit');
        \\if (String(v) !== '-infinitypx') throw new Error('String: ' + String(v));
        \\return 'ok'; })()
    );
}

test "Q81 negative number overflow preserves the derived unit value and spec serialization" {
    try run(
        \\(() => {
        \\const v = CSS.number(-1e308).mul(2);
        \\if (!(v instanceof CSSUnitValue)) throw new Error('class');
        \\if (!Object.is(v.value, -Infinity) || v.unit !== 'number') throw new Error('value/unit');
        \\if (String(v) !== '-infinity') throw new Error('String: ' + String(v));
        \\return 'ok'; })()
    );
}

test "Q81 numeric div zero throws RangeError unlike a constructed reciprocal" {
    try run(
        \\(() => {
        \\let caught; try { CSS.number(1).div(0); } catch (e) { caught = e; }
        \\if (!(caught instanceof RangeError)) throw new Error('div(0): ' + (caught?.name || 'accepted'));
        \\return 'ok'; })()
    );
}

test "Q83 positive infinity math String follows literal unit serialization" {
    try run(
        \\(() => {
        \\const v = CSS.px(1e308).mul(2);
        \\if (String(new CSSMathSum(v)) !== 'calc(infinitypx)') throw new Error('new CSSMathSum(v)');
        \\if (String(new CSSMathSum(v, CSS.px(1))) !== 'calc(infinitypx + 1px)') throw new Error('new CSSMathSum(v, CSS.px(1))');
        \\if (String(new CSSMathProduct(v, 2)) !== 'calc(infinitypx * 2)') throw new Error('new CSSMathProduct(v, 2)');
        \\if (String(new CSSMathNegate(v)) !== 'calc(-infinitypx)') throw new Error('new CSSMathNegate(v)');
        \\return 'ok'; })()
    );
}

test "Q83 negative infinity math String follows literal unit serialization" {
    try run(
        \\(() => {
        \\const v = CSS.px(-1e308).mul(2);
        \\if (String(new CSSMathSum(v)) !== 'calc(-infinitypx)') throw new Error('new CSSMathSum(v)');
        \\if (String(new CSSMathSum(v, CSS.px(1))) !== 'calc(-infinitypx + 1px)') throw new Error('new CSSMathSum(v, CSS.px(1))');
        \\if (String(new CSSMathProduct(v, 2)) !== 'calc(-infinitypx * 2)') throw new Error('new CSSMathProduct(v, 2)');
        \\if (String(new CSSMathNegate(v)) !== 'calc(--infinitypx)') throw new Error('new CSSMathNegate(v)');
        \\return 'ok'; })()
    );
}

test "Q83 NaN dimension math String follows literal unit serialization" {
    try run(
        \\(() => {
        \\const v = CSS.px(0).mul(CSS.number(1e308).mul(2));
        \\if (String(new CSSMathSum(v)) !== 'calc(NaNpx)') throw new Error('new CSSMathSum(v)');
        \\if (String(new CSSMathSum(v, CSS.px(1))) !== 'calc(NaNpx + 1px)') throw new Error('new CSSMathSum(v, CSS.px(1))');
        \\if (String(new CSSMathProduct(v, 2)) !== 'calc(NaNpx * 2)') throw new Error('new CSSMathProduct(v, 2)');
        \\if (String(new CSSMathNegate(v)) !== 'calc(-NaNpx)') throw new Error('new CSSMathNegate(v)');
        \\return 'ok'; })()
    );
}

test "Q84 numeric type and inverse at repeated product 15" {
    try run(
        \\(() => {
        \\let v = CSS.px(1);
        \\for (let i = 0; i < 15; i++) v = new CSSMathProduct(v, v);
        \\const type = v.type(), inverse = new CSSMathInvert(v).type();
        \\if ((type.length ?? 0) !== 32768) throw new Error('type exponent');
        \\if ((inverse.length ?? 0) !== -32768) throw new Error('inverse exponent');
        \\if (32768 === 0 && (Object.hasOwn(type, 'length') || Object.hasOwn(inverse, 'length'))) throw new Error('zero entry');
        \\return 'ok'; })()
    );
}

test "Q84 numeric type and inverse at repeated product 16" {
    try run(
        \\(() => {
        \\let v = CSS.px(1);
        \\for (let i = 0; i < 16; i++) v = new CSSMathProduct(v, v);
        \\const type = v.type(), inverse = new CSSMathInvert(v).type();
        \\if ((type.length ?? 0) !== 65536) throw new Error('type exponent');
        \\if ((inverse.length ?? 0) !== -65536) throw new Error('inverse exponent');
        \\if (65536 === 0 && (Object.hasOwn(type, 'length') || Object.hasOwn(inverse, 'length'))) throw new Error('zero entry');
        \\return 'ok'; })()
    );
}

test "Q84 numeric type and inverse at repeated product 30" {
    try run(
        \\(() => {
        \\let v = CSS.px(1);
        \\for (let i = 0; i < 30; i++) v = new CSSMathProduct(v, v);
        \\const type = v.type(), inverse = new CSSMathInvert(v).type();
        \\if ((type.length ?? 0) !== 1073741824) throw new Error('type exponent');
        \\if ((inverse.length ?? 0) !== -1073741824) throw new Error('inverse exponent');
        \\if (1073741824 === 0 && (Object.hasOwn(type, 'length') || Object.hasOwn(inverse, 'length'))) throw new Error('zero entry');
        \\return 'ok'; })()
    );
}

test "Q84 numeric type and inverse at repeated product 31" {
    try run(
        \\(() => {
        \\let v = CSS.px(1);
        \\for (let i = 0; i < 31; i++) v = new CSSMathProduct(v, v);
        \\const type = v.type(), inverse = new CSSMathInvert(v).type();
        \\if ((type.length ?? 0) !== -2147483648) throw new Error('type exponent');
        \\if ((inverse.length ?? 0) !== -2147483648) throw new Error('inverse exponent');
        \\if (-2147483648 === 0 && (Object.hasOwn(type, 'length') || Object.hasOwn(inverse, 'length'))) throw new Error('zero entry');
        \\return 'ok'; })()
    );
}

test "Q84 numeric type and inverse at repeated product 32" {
    try run(
        \\(() => {
        \\let v = CSS.px(1);
        \\for (let i = 0; i < 32; i++) v = new CSSMathProduct(v, v);
        \\const type = v.type(), inverse = new CSSMathInvert(v).type();
        \\if ((type.length ?? 0) !== 0) throw new Error('type exponent');
        \\if ((inverse.length ?? 0) !== 0) throw new Error('inverse exponent');
        \\if (0 === 0 && (Object.hasOwn(type, 'length') || Object.hasOwn(inverse, 'length'))) throw new Error('zero entry');
        \\return 'ok'; })()
    );
}
