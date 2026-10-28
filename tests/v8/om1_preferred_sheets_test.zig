//! CSSOM 6.2 add/remove/enable-sheet semantics through public DOM properties.
//! Q13/Q24: preferred addition order and actual disabled flags share one state.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
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
        std.debug.print("om1 preferred sheets: {s}\n", .{info.message});
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

const setup =
    \\(() => {
    \\const doc = new Document().implementation.createHTMLDocument('preferred sheets');
    \\function addSheet(title, before = null) {
    \\  const style = doc.createElement('style');
    \\  style.title = title;
    \\  style.textContent = 'body { color: green; }';
    \\  doc.head.insertBefore(style, before);
    \\  return style;
    \\}
;

fn additionOrder() !void {
    try script(setup ++
        \\const first = addSheet('first');
        \\const second = addSheet('second', first);
        \\if (doc.styleSheets[0] !== second.sheet || doc.styleSheets[1] !== first.sheet) return 'tree order setup';
        \\if (first.sheet.disabled) return 'first added sheet disabled';
        \\if (!second.sheet.disabled) return 'nonpreferred sheet not disabled';
        \\return 'ok';
        \\})()
    );
}

test "preferred sheet addition order survives reversed tree order in actual disabled flags" {
    try onThread(additionOrder);
}

fn removalKeepsPreferredName() !void {
    try script(setup ++
        \\const first = addSheet('first');
        \\const second = addSheet('second');
        \\first.remove();
        \\if (!second.sheet.disabled) return 'removal selected another name';
        \\const later = addSheet('first');
        \\if (later.sheet.disabled || !second.sheet.disabled) return 'preferred name was discarded';
        \\return 'ok';
        \\})()
    );
}

test "removing the establishing sheet preserves the preferred stylesheet name" {
    try onThread(removalKeepsPreferredName);
}

fn explicitEnableUsesActualFlag() !void {
    try script(setup ++
        \\const first = addSheet('first');
        \\first.sheet.disabled = true;
        \\const second = addSheet('second');
        \\if (!first.sheet.disabled || !second.sheet.disabled) return 'disabling changed the preferred name';
        \\second.sheet.disabled = false;
        \\if (second.sheet.disabled || !first.sheet.disabled) return 'explicit flags not preserved';
        \\return 'ok';
        \\})()
    );
}

test "disabled preferred sheets keep their name while another sheet can be explicitly enabled" {
    try onThread(explicitEnableUsesActualFlag);
}

fn defaultStyleUpdatesFlags() !void {
    try script(setup ++
        \\const meta = doc.createElement('meta');
        \\meta.httpEquiv = 'default-style';
        \\meta.content = 'second';
        \\doc.head.append(meta);
        \\const first = addSheet('first');
        \\const second = addSheet('second');
        \\if (!first.sheet.disabled || second.sheet.disabled) return 'pragma did not select second';
        \\meta.content = 'first';
        \\if (first.sheet.disabled || !second.sheet.disabled) return 'pragma change did not update existing flags';
        \\return 'ok';
        \\})()
    );
}

test "default-style pragma updates actual disabled flags of existing titled sheets" {
    try onThread(defaultStyleUpdatesFlags);
}
