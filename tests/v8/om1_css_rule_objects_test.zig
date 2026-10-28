//! CSSOM rule families through generated interfaces and native rule models.
//! Liaison Q53–Q55; every body uses its own thread and leak-checking allocator.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const a = std.testing.allocator;

fn onThread(comptime body: fn () anyerror!void) !void {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(out: *anyerror!void) void {
            out.* = body();
        }
    }.run, .{&result});
    thread.join();
    try result;
}

const Host = struct {
    fn window(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(a, realm) catch null;
    }
    fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
        std.debug.print("om1 rule script: {s}\n", .{info.message});
    }
};

fn script(source: []const u8) !void {
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

fn measureRuleSize() !void {
    // Q55, BASE helper 64584: Rule=216, Data=144, FontRule=136.
    // New rare rule payloads must not enlarge ordinary style rules.
    try std.testing.expectEqual(@as(usize, 216), @sizeOf(dom.style.Rule));
    try std.testing.expectEqual(@as(usize, 144), @sizeOf(dom.style.rules.Data));
    try std.testing.expectEqual(@as(usize, 136), @sizeOf(@FieldType(dom.style.rules.Data, "font_face")));
    std.debug.print("OM1 RULE SIZE: Rule={d}, Data={d}, FontRule={d}\n", .{
        @sizeOf(dom.style.Rule),
        @sizeOf(dom.style.rules.Data),
        @sizeOf(@FieldType(dom.style.rules.Data, "font_face")),
    });
}

test "ordinary Rule allocation size BASE receipt" {
    try onThread(measureRuleSize);
}

fn fontRuleAllocation(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasField(dom.style.rules.Data, "font_feature_values")) return std.testing.expect(false);
    var rules: std.ArrayList(*dom.style.Rule) = .empty;
    defer {
        for (rules.items) |rule| rule.unref();
        rules.deinit(allocator);
    }
    try dom.style.rules.parseSheet(.{ .parse = .{ .allocator = allocator } }, "@font-feature-values Foo { font-display: swap; @swash { Camel: 2; } @styleset { code: 3 4; } }", &rules, null);
    try std.testing.expectEqual(@as(usize, 1), rules.items.len);
    const rule = rules.items[0];
    try std.testing.expectEqual(dom.style.rules.Kind.font_feature_values, rule.kind());
    const text = try rule.serialize(allocator);
    defer allocator.free(text);
    try std.testing.expectEqualStrings("@font-feature-values Foo { font-display: swap; @swash { Camel: 2; } @styleset { code: 3 4; } }", text);
    rule.ref();
    defer rule.unref();
    _ = rules.pop();
    rule.unref();
    try std.testing.expect(rule.parent_rule == null);
    const detached = try rule.serialize(allocator);
    defer allocator.free(detached);
    try std.testing.expectEqualStrings(text, detached);
}

fn fontRuleAllocationFailures() !void {
    try std.testing.checkAllAllocationFailures(a, fontRuleAllocation, .{});
}

test "font feature rare rule payload and retained model unwind every allocation failure" {
    try onThread(fontRuleAllocationFailures);
}

fn fontRuleObjects() !void {
    try script(
        \\(() => {
        \\const d = new Document().implementation.createHTMLDocument('om1');
        \\const style = d.createElement('style');
        \\style.textContent = '@font-feature-values Foo { @swash { Camel: 2; } @styleset { code: 3 4; } }';
        \\d.head.appendChild(style);
        \\const sheet = style.sheet, rule = sheet.cssRules[0];
        \\if (!(rule instanceof CSSFontFeatureValuesRule) || rule.type !== 14) return 'rule class';
        \\if (rule.fontFamily !== 'Foo' || rule.parentStyleSheet !== sheet) return 'rule metadata';
        \\for (const name of ['swash', 'stylistic', 'ornaments', 'annotation', 'characterVariant', 'styleset']) {
        \\  const map = rule[name];
        \\  if (!(map instanceof CSSFontFeatureValuesMap) || map !== rule[name]) return name + ':map identity';
        \\}
        \\if (rule.swash === rule.styleset) return 'distinct blocks aliased';
        \\const swash = rule.swash;
        \\if (swash.set('Camel', [8, 9]) !== undefined) return 'set return';
        \\if (rule.cssText !== '@font-feature-values Foo { @swash { Camel: 8 9; } @styleset { code: 3 4; } }') return rule.cssText;
        \\rule.fontFamily = '"serif", "Foo Bar"';
        \\if (rule.fontFamily !== '"serif", Foo Bar' || rule.swash !== swash) return 'family replacement';
        \\rule.fontFamily = 'serif';
        \\if (rule.fontFamily !== '"serif", Foo Bar') return 'invalid family mutated';
        \\sheet.deleteRule(0);
        \\if (rule.parentStyleSheet !== null || swash !== rule.swash) return 'detached identity';
        \\swash.set('After', 6);
        \\if (!rule.cssText.includes('Camel: 8 9; After: 6;')) return 'detached map mutation';
        \\return 'ok';
        \\})()
    );
}

test "font feature rule map identity family setters and detached mutation use generated interfaces" {
    try onThread(fontRuleObjects);
}

fn fontMapConversion() !void {
    try script(
        \\(() => {
        \\const d = new Document().implementation.createHTMLDocument('om1');
        \\const style = d.createElement('style');
        \\style.textContent = '@font-feature-values Foo { @swash { Keep: 1; } }';
        \\d.head.appendChild(style);
        \\const sheet = style.sheet, rule = sheet.cssRules[0], map = rule.swash;
        \\const unchanged = rule.cssText;
        \\const sentinel = {};
        \\let thrown;
        \\try { map.set('Fail', { *[Symbol.iterator]() { yield 4; throw sentinel; } }); } catch (e) { thrown = e; }
        \\if (thrown !== sentinel || rule.cssText !== unchanged) return 'failed conversion mutated';
        \\let coercions = 0;
        \\map.set('After', { valueOf() { ++coercions; sheet.deleteRule(0); return 4294967297; } });
        \\if (coercions !== 1 || rule.parentStyleSheet !== null) return 'reentrant conversion';
        \\if (rule.cssText !== '@font-feature-values Foo { @swash { Keep: 1; After: 1; } }') return rule.cssText;
        \\map.set('Empty', []);
        \\if (!rule.cssText.includes('Empty:;')) return 'empty sequence';
        \\return 'ok';
        \\})()
    );
}

test "font feature map conversion is atomic and reentrant through the public engine boundary" {
    try onThread(fontMapConversion);
}
