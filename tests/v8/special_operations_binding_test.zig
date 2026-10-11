//! WebIDL 2.5.6 special operations as script sees them through the binding,
//! which installs a legacy platform object's handlers (3.9) from codegen's
//! Meta.special_operations - not from function names:
//!
//! - which interfaces get which handlers (the table, pinned at comptime);
//! - an HTMLOptionsCollection has the named properties it inherits.
//!
//! Values are made the way the binding makes them: by script, in a Window
//! realm. Storage, which needs a Browser's storage shed, is
//! tests/html/storage_named_properties_test.zig.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agents.

const std = @import("std");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const specialBinding = @import("v8").interface_mod.specialBinding;

fn eqlOpt(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null or b == null) return a == null and b == null;
    return std.mem.eql(u8, a.?, b.?);
}

comptime {
    // Storage: getItem, setItem, removeItem - which no name guess knew.
    const storage = specialBinding(interfaces.Storage);
    std.debug.assert(eqlOpt(storage.named_getter, "call_getItem"));
    std.debug.assert(eqlOpt(storage.named_setter, "call_setItem"));
    std.debug.assert(eqlOpt(storage.named_deleter, "call_removeItem"));
    std.debug.assert(storage.indexed_getter == null);
    // NamedNodeMap: a named getter and no named setter (setNamedItem is
    // regular), no deleter.
    const attrs = specialBinding(interfaces.NamedNodeMap);
    std.debug.assert(eqlOpt(attrs.named_getter, "call_getNamedItem"));
    std.debug.assert(attrs.named_setter == null and attrs.named_deleter == null);
    std.debug.assert(attrs.legacy_unenumerable_named_properties);
    // DOMStringMap: all three anonymous ones, implemented.
    const dataset = specialBinding(interfaces.DOMStringMap);
    std.debug.assert(eqlOpt(dataset.named_getter, "call_getter"));
    std.debug.assert(eqlOpt(dataset.named_setter, "call_setter"));
    std.debug.assert(eqlOpt(dataset.named_deleter, "call_deleter"));
    std.debug.assert(dataset.legacy_override_built_ins);
    // SVGNumberList: its indexed getter is getItem.
    std.debug.assert(eqlOpt(specialBinding(interfaces.SVGNumberList).indexed_getter, "call_getItem"));
    // HTMLOptionsCollection inherits HTMLCollection's named getter.
    std.debug.assert(eqlOpt(specialBinding(interfaces.HTMLOptionsCollection).named_getter, "call_namedItem"));
    std.debug.assert(specialBinding(interfaces.HTMLOptionsCollection).legacy_unenumerable_named_properties);
    // HTMLSelectElement's regular namedItem is no named getter.
    std.debug.assert(specialBinding(interfaces.HTMLSelectElement).named_getter == null);
    std.debug.assert(eqlOpt(specialBinding(interfaces.HTMLSelectElement).indexed_setter, "call_setter"));
    // A [Global]'s named properties are its named properties object's.
    std.debug.assert(specialBinding(interfaces.Window).named_getter == null);
    std.debug.assert(eqlOpt(specialBinding(interfaces.Window).indexed_getter, "call_item"));
    // The browsers' exceptions: none for TouchEvent or XMLDocument.
    std.debug.assert(!@hasDecl(interfaces.TouchEvent.Meta, "special_operations"));
    std.debug.assert(!@hasDecl(interfaces.XMLDocument.Meta, "special_operations"));
    std.debug.assert(eqlOpt(specialBinding(interfaces.Document).named_getter, "call_getter"));
    // HTMLFormElement: both getters declared, neither implemented yet.
    std.debug.assert(specialBinding(interfaces.HTMLFormElement).indexed_getter == null);
    std.debug.assert(specialBinding(interfaces.HTMLFormElement).named_getter == null);
    // The default: no special operation, nothing installed.
    std.debug.assert(!@hasDecl(interfaces.Node.Meta, "special_operations"));
    const none = specialBinding(interfaces.Node);
    std.debug.assert(none.indexed_getter == null and none.named_getter == null);
}

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
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

const no_hooks: protocol.HostHooks = .{};

/// An agent and a Window realm of it.
const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try setup();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
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
        const result = protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter()) catch |err| {
            std.debug.print("evaluating failed ({s}, {d} reported): {s}\n", .{ @errorName(err), reports.count, source });
            return err;
        };
        errdefer std.testing.allocator.free(result);
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        return result;
    }

    fn expectOk(self: Page, comptime body: []const u8) !void {
        const got = try self.eval(fixture ++ "(() => {\n  const problems = [];\n  const check = (what, got, want) => { if (got !== want) problems.push(what + ': ' + String(got)); };\n" ++ body ++ "\n  return problems.length ? problems.join('; ') : 'ok';\n})()");
        defer std.testing.allocator.free(got);
        try std.testing.expectEqualStrings("ok", got);
    }
};

/// `html()`: an HTML document's body, made in this realm.
const fixture =
    \\function html() {
    \\  const doc = new Document().implementation.createHTMLDocument('');
    \\  return { doc, body: doc.body };
    \\}
    \\function throwsTypeError(f) {
    \\  try { f(); return false; } catch (e) { return e instanceof TypeError; }
    \\}
    \\
;

test "HTMLOptionsCollection: the named properties it inherits from HTMLCollection" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  const { doc, body } = html();
        \\  const select = doc.createElement('select');
        \\  const option = doc.createElement('option');
        \\  option.id = 'pick';
        \\  select.appendChild(option);
        \\  body.appendChild(select);
        \\  check('options.pick', select.options.pick, option);
        \\  check('in', 'pick' in select.options, true);
        \\  check('namedItem', select.options.namedItem('pick'), option);
        \\  check('missing', select.options.nothing, undefined);
    );
}
