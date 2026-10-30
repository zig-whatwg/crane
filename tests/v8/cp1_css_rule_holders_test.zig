//! CSSOM holders use the existing Rule refs and objects' traced parent slots.
//! Every body has its own thread and leak-checked Window realm, as the
//! existing tests/v8 style_engine and bf1 engine-task tests do.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");

fn createGlobal(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(realm.allocator, realm) catch null;
}

const Reports = struct {
    count: usize = 0,
    fn report(context: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *@This() = @ptrCast(@alignCast(context.?));
        self.count += 1;
        std.debug.print("cp1 CSS holder script: {s}\n", .{info.message});
    }
};

fn run(realm: runtime.Context, source: []const u8) !void {
    var reports: Reports = .{};
    try engine.runClassicScript(realm, .{ .utf8 = source }, "cp1-css-rule-holders.js", null, .{ .report = Reports.report, .host = &reports });
    try std.testing.expectEqual(@as(usize, 0), reports.count);
}

const setup =
    \\globalThis.check = (value, message) => { if (!value) throw new Error(message); };
    \\globalThis.makeSheet = text => {
    \\  const doc = new Document().implementation.createHTMLDocument('cp1');
    \\  const owner = doc.createElement('style');
    \\  owner.textContent = text;
    \\  doc.head.appendChild(owner);
    \\  const sheet = owner.sheet;
    \\  check(sheet !== null, 'style sheet exists');
    \\  void sheet.cssRules.length;
    \\  sheet.cp1Marker = 'sheet';
    \\  owner.remove();
    \\  return sheet;
    \\};
;

const Case = enum { nested_style, container_parent, scope_parent, conditions };

fn exercise(comptime case: Case) !void {
    try engine.initializeEngine(.{});
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    const hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = std.testing.allocator });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{ .agent = agent, .allocator = std.testing.allocator, .from_snapshot = false, .timer = null, .origin = "https://cp1.test", .create_global_object = createGlobal });
    defer engine.destroyWindowRealm(realm, .global_detached);
    try run(realm, setup);
    if (case == .nested_style) {
        try run(realm,
            \\globalThis.kept = (() => {
            \\  const sheet = makeSheet('.outer { & .child {} color: red; }');
            \\  const outer = sheet.cssRules[0];
            \\  check(outer.cssRules.length === 2, 'nested declaration exists');
            \\  const declaration = outer.cssRules[1];
            \\  outer.cp1Marker = 'outer';
            \\  declaration.cp1Marker = 'declaration';
            \\  return declaration.style;
            \\})();
        );
        // Separate script jobs leave no stack reference to any rule/sheet.
        try run(realm, "TestUtils.gc(); TestUtils.gc();");
        try run(realm,
            \\check(kept.parentRule instanceof CSSNestedDeclarations, 'parent type');
            \\check(kept.parentRule.cp1Marker === 'declaration', 'parent wrapper kept');
            \\check(kept.parentRule.style === kept, 'SameObject style kept');
            \\check(kept.parentRule.parentRule.cp1Marker === 'outer', 'outer wrapper kept');
            \\check(kept.parentRule.parentStyleSheet.cp1Marker === 'sheet', 'sheet wrapper kept');
            \\kept.color = 'purple';
            \\check(kept.parentRule.cssText === 'color: purple;', 'live declaration');
            \\kept.parentRule.parentRule.deleteRule(1);
        );
        try run(realm, "TestUtils.gc(); TestUtils.gc();");
        try run(realm,
            \\check(kept.parentRule.cp1Marker === 'declaration', 'detached parent wrapper kept');
            \\check(kept.parentRule.parentRule === null, 'detached parent cleared');
            \\check(kept.parentRule.parentStyleSheet === null, 'detached sheet cleared');
            \\check(kept.color === 'purple', 'detached value kept');
            \\kept.width = '12px';
            \\check(kept.parentRule.cssText === 'color: purple; width: 12px;', 'detached declaration live');
        );
    } else if (case == .conditions) {
        try run(realm,
            \\globalThis.kept = (() => {
            \\  const sheet = makeSheet('@container wide (width>10px), style(--flag) {}');
            \\  const rule = sheet.cssRules[0];
            \\  const result = rule.conditions;
            \\  check(rule.containerName === '' && rule.containerQuery === '', 'multiple conditions accessors');
            \\  sheet.deleteRule(0);
            \\  return result;
            \\})();
        );
        try run(realm, "TestUtils.gc(); TestUtils.gc();");
        try run(realm,
            \\check(Object.isFrozen(kept) && kept.length === 2, 'frozen conditions');
            \\check(kept[0].name === 'wide' && kept[0].query === '(width > 10px)', 'first dictionary owns strings');
            \\check(kept[1].name === '' && kept[1].query === 'style(--flag)', 'second dictionary owns strings');
        );
    } else {
        const text = if (case == .container_parent) "@container (width > 0px) { .child { color: red } }" else "@scope (.root) { .child { color: red } }";
        try run(realm, "globalThis.kept = (() => { const sheet = makeSheet('" ++ text ++ "'); const parent = sheet.cssRules[0]; parent.cp1Marker = 'group'; return parent.cssRules[0]; })();");
        try run(realm, "TestUtils.gc(); TestUtils.gc();");
        try run(realm,
            \\check(kept.parentRule.cp1Marker === 'group', 'group wrapper kept');
            \\check(kept.parentStyleSheet.cp1Marker === 'sheet', 'group sheet wrapper kept');
            \\check(kept.parentRule.cssRules[0] === kept, 'child wrapper identity');
            \\check(kept.style.color === 'red', 'child data kept');
            \\kept.parentStyleSheet.deleteRule(0);
        );
        try run(realm, "TestUtils.gc(); TestUtils.gc();");
        try run(realm,
            \\check(kept.parentRule.cp1Marker === 'group', 'detached group kept');
            \\check(kept.parentRule.parentRule === null, 'group parent remains null');
            \\check(kept.parentStyleSheet === null && kept.parentRule.parentStyleSheet === null, 'removed sheet cleared');
            \\check(kept.style.color === 'red', 'detached group child data kept');
        );
    }
    try run(realm, "globalThis.kept = null;");
    try run(realm, "TestUtils.gc(); TestUtils.gc();");
}

fn onThread(comptime case: Case) !void {
    const Run = struct {
        fn body(result: *anyerror!void) void {
            result.* = exercise(case);
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.body, .{&result});
    thread.join();
    try result;
}

test "nested declaration style keeps its parent wrapper and chain across GC and detachment" {
    errdefer std.debug.print("CP1_RULE_HOLDER_CASE FAIL: nested declaration style keeps its parent wrapper and chain across GC and detachment\n", .{});
    try onThread(.nested_style);
    std.debug.print("CP1_RULE_HOLDER_CASE PASS: nested declaration style keeps its parent wrapper and chain across GC and detachment\n", .{});
}
test "a container child keeps the existing CSSOM parent trace across GC and detachment" {
    errdefer std.debug.print("CP1_RULE_HOLDER_CASE FAIL: a container child keeps the existing CSSOM parent trace across GC and detachment\n", .{});
    try onThread(.container_parent);
    std.debug.print("CP1_RULE_HOLDER_CASE PASS: a container child keeps the existing CSSOM parent trace across GC and detachment\n", .{});
}
test "a scope child keeps the existing CSSOM parent trace across GC and detachment" {
    errdefer std.debug.print("CP1_RULE_HOLDER_CASE FAIL: a scope child keeps the existing CSSOM parent trace across GC and detachment\n", .{});
    try onThread(.scope_parent);
    std.debug.print("CP1_RULE_HOLDER_CASE PASS: a scope child keeps the existing CSSOM parent trace across GC and detachment\n", .{});
}
test "container condition dictionaries own their strings after every rule is collected" {
    errdefer std.debug.print("CP1_RULE_HOLDER_CASE FAIL: container condition dictionaries own their strings after every rule is collected\n", .{});
    try onThread(.conditions);
    std.debug.print("CP1_RULE_HOLDER_CASE PASS: container condition dictionaries own their strings after every rule is collected\n", .{});
}
