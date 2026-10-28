//! WebIDL restricted double; Typed OM numeric API; liaison Q48.
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
        std.debug.print("om1 numeric binding script: {s}\n", .{info.message});
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
        \\const factories = ["number", "percent", "cap", "ch", "em", "ex", "ic", "lh", "rcap", "rch", "rem", "rex", "ric", "rlh", "vw", "vh", "vi", "vb", "vmin", "vmax", "svw", "svh", "svi", "svb", "svmin", "svmax", "lvw", "lvh", "lvi", "lvb", "lvmin", "lvmax", "dvw", "dvh", "dvi", "dvb", "dvmin", "dvmax", "cqw", "cqh", "cqi", "cqb", "cqmin", "cqmax", "cm", "mm", "Q", "in", "pt", "pc", "px", "deg", "grad", "rad", "turn", "s", "ms", "Hz", "kHz", "dpi", "dpcm", "dppx", "fr"];
        \\const badNumbers = [NaN, Infinity, -Infinity];
        \\function rejected(operation) {
        \\  try { operation(); } catch (error) { return error instanceof TypeError; }
        \\  return false;
        \\}
        \\const failures = [];
        \\for (const name of factories) {
        \\  for (const value of badNumbers) if (!rejected(() => CSS[name](value))) failures.push(name + ":" + value);
        \\  const unit = CSS[name](1e40);
        \\  if (!(unit instanceof CSSUnitValue) || unit.value !== 1e40) failures.push(name + ":finite");
        \\}
        \\for (const value of badNumbers) if (!rejected(() => new CSSUnitValue(value, "px"))) failures.push("constructor:" + value);
        \\const unit = new CSSUnitValue(2, "px");
        \\for (const value of badNumbers) {
        \\  if (!rejected(() => { unit.value = value; })) failures.push("setter:" + value);
        \\  if (unit.value !== 2) failures.push("rollback:" + value);
        \\}
        \\unit.value = 1e40;
        \\if (unit.value !== 1e40 || new CSSUnitValue(1e40, "px").value !== 1e40) failures.push("finite");
        \\return failures.join(";") || "ok";
        \\})()
    ;
    const result = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, a, .{ .report = Host.report, .host = null });
    defer a.free(result);
    try std.testing.expectEqualStrings("ok", result);
}

test "Typed OM factories constructor and setter enforce restricted doubles in generated bindings" {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(out: *anyerror!void) void {
            out.* = check();
        }
    }.run, .{&result});
    thread.join();
    try result;
}
