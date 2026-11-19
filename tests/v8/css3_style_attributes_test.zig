//! CSSOM 6.6.2: CSSStyleProperties' CSS property attributes - each supported
//! CSS property's camel-cased attribute, a -webkit- property's webkit-cased
//! one, and a dashed one for a property with a "-" - are attributes, so each
//! is an accessor property of CSSStyleProperties.prototype (WebIDL 3.7.6), not
//! a named property of the declaration (lane css3).
//!
//! css/cssom/cssstyledeclaration-properties.html checks `"color" in style`
//! and that it is no own property: Firefox 160 and Safari 27.2 pass it,
//! Chrome 157 fails it (its named interceptor) - wpt.fyi runs
//! 4877168468033536, 6479119966273536, 4786307730243584; golden rule 2 takes
//! the majority.
//!
//! The same checks run in a realm made without the snapshot, in one restored
//! from it, and in a frame's realm restored from it, which builds its
//! interface objects when script first reads them: the snapshot carries no
//! CSS property accessor (they are made once per isolate, at run time), so a
//! restored realm has them only through the runtime's template.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const ffi = @import("v8").ffi;
/// The snapshot this build generated (build.zig passes its path).
const snapshot_path = @import("test_snapshot").path;

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

const no_hooks: protocol.HostHooks = .{};

/// `source`'s completion value must be "ok" (else it is the list of failed
/// checks), and it must report nothing.
fn expectOk(r: runtime.Context, source: []const u8) !void {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScriptToString(r, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    defer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    if (!std.mem.eql(u8, got, "ok")) std.debug.print("failed checks: {s}\n", .{got});
    try testing.expectEqualStrings("ok", got);
}

/// The checks, in any Window realm: an element's style declaration and the
/// prototype's accessors.
const checks =
    \\const failures = [];
    \\function check(name, got, want) { if (got !== want) failures.push(name + ": " + String(got)); }
    \\const doc = new Document().implementation.createHTMLDocument('t');
    \\const div = doc.createElement('div');
    \\doc.body.appendChild(div);
    \\const s = div.style;
    \\const P = CSSStyleProperties.prototype;
    \\// cssstyledeclaration-properties.html
    \\check("'color' in style", 'color' in s, true);
    \\check("no own 'color'", Object.prototype.hasOwnProperty.call(s, 'color'), false);
    \\check("no own property names", Object.getOwnPropertyNames(s).length, 0);
    \\check("CSSStyleDeclaration.prototype has no 'color'", Object.getOwnPropertyDescriptor(CSSStyleDeclaration.prototype, 'color'), undefined);
    \\// Each attribute: an accessor on the prototype (WebIDL 3.7.6).
    \\for (const name of ['color', 'fontSize', 'font-size', 'cssFloat', 'webkitUserSelect', 'WebkitUserSelect', '-webkit-user-select', 'borderTopLeftRadius', 'margin']) {
    \\  const d = Object.getOwnPropertyDescriptor(P, name);
    \\  if (!d) { failures.push('no accessor ' + name); continue; }
    \\  check(name + ' get', typeof d.get, 'function');
    \\  check(name + ' set', typeof d.set, 'function');
    \\  check(name + ' enumerable', d.enumerable, true);
    \\  check(name + ' configurable', d.configurable, true);
    \\  check(name + ' get.name', d.get.name, 'get ' + name);
    \\  check(name + ' set.name', d.set.name, 'set ' + name);
    \\  check(name + ' get.length', d.get.length, 0);
    \\  check(name + ' set.length', d.set.length, 1);
    \\  check(name + ' the same getter on each read', Object.getOwnPropertyDescriptor(P, name).get, d.get);
    \\}
    \\check('distinct getters', Object.getOwnPropertyDescriptor(P, 'color').get === Object.getOwnPropertyDescriptor(P, 'fontSize').get, false);
    \\check('no dashed attribute without a dash', Object.getOwnPropertyDescriptor(P, 'Color'), undefined);
    \\// The getter is getPropertyValue(), the setter setProperty().
    \\s.fontSize = '12px';
    \\check('camel set', s.getPropertyValue('font-size'), '12px');
    \\check('dashed get', s['font-size'], '12px');
    \\s['margin-left'] = '3px';
    \\check('dashed set', s.marginLeft, '3px');
    \\s.webkitUserSelect = 'none';
    \\check('webkit-cased set', s.userSelect, 'none');
    \\check('the style attribute', div.getAttribute('style'), 'font-size: 12px; margin-left: 3px; user-select: none;');
    \\check('getter through call', Object.getOwnPropertyDescriptor(P, 'fontSize').get.call(s), '12px');
    \\// [LegacyNullToEmptyString]: null is the empty string, which removes it.
    \\s.fontSize = null;
    \\check('null removes', s.getPropertyValue('font-size'), '');
    \\// A receiver that is no CSSStyleProperties: TypeError (WebIDL 3.7.6 step 1.2).
    \\check('foreign receiver', (() => { try { Object.getOwnPropertyDescriptor(P, 'color').get.call({}); return 'no'; } catch (e) { return e.name; } })(), 'TypeError');
    \\check('declaration receiver', (() => { try { Object.getOwnPropertyDescriptor(P, 'color').set.call(Object.create(P), 'red'); return 'no'; } catch (e) { return e.name; } })(), 'TypeError');
    \\// An expando is an ordinary own property.
    \\s.myExpando = 7;
    \\check('expando', Object.getOwnPropertyNames(s).filter((n) => !/^[0-9]+$/.test(n)).join(), 'myExpando');
    \\// getComputedStyle's declaration has them too, read-only in effect.
    \\const cs = getComputedStyle(div);
    \\check("computed 'color' in", 'color' in cs, true);
    \\check('computed no own', Object.prototype.hasOwnProperty.call(cs, 'color'), false);
    \\failures.join('; ') || 'ok'
;

test "CSSStyleProperties' CSS property attributes are accessors on its prototype (a realm made without the snapshot)" {
    test_process.start();
    dom.style.ua_sheet.build();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://css3.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(realm, .global_detached);
    try expectOk(realm, checks);
}

const SnapshotPage = struct {
    bytes: []u8,
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !?SnapshotPage {
        // A realm restored from the snapshot needs a process whose V8 started
        // with it: tests-v8 runs each test alone (batch 1).
        if (ffi.v8_Platform_IsInitialized()) {
            std.log.warn("skipping: V8 was started in this process before this test; run it in a process of its own (tests-v8 runs at batch 1; -Dlaunch-batch=1 or -Dtest-file=)", .{});
            return null;
        }
        const io = std.testing.io;
        const file = try std.Io.Dir.cwd().openFile(io, snapshot_path, .{});
        defer file.close(io);
        const size = (try file.stat(io)).size;
        const bytes = try std.heap.c_allocator.alloc(u8, size);
        errdefer std.heap.c_allocator.free(bytes);
        _ = try file.readPositionalAll(io, bytes, 0);
        try test_process.startSnapshot(bytes);
        errdefer test_process.endSnapshot();
        dom.style.ua_sheet.build();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = true, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        if (!ffi.v8_Isolate_IsFromSnapshot(@ptrCast(@alignCast(agent)))) return error.AgentNotRestoredFromSnapshot;
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = true,
            .timer = null,
            .origin = "https://css3.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .bytes = bytes, .agent = agent, .realm = realm };
    }

    fn close(self: SnapshotPage) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
        test_process.endSnapshot();
        std.heap.c_allocator.free(self.bytes);
    }
};

/// A frame's Window realm restored from the snapshot, made inside its
/// parent's script as HTML makes a navigable's (protocol.runInRealm): a realm
/// with a parent gets its interface objects lazily.
const SnapshotFrame = struct {
    agent: *protocol.Agent,
    parent: runtime.Context,
    made: ?runtime.Context = null,
    failed: ?anyerror = null,

    fn make(self: *SnapshotFrame) !runtime.Context {
        try protocol.runInRealm(self.parent, steps, self);
        if (self.failed) |err| return err;
        return self.made.?;
    }

    fn steps(data: ?*anyopaque) void {
        const self: *SnapshotFrame = @ptrCast(@alignCast(data.?));
        self.made = protocol.createWindowRealm(&.{
            .agent = self.agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = true,
            .timer = null,
            .origin = "https://css3.test",
            .parent = self.parent,
            .create_global_object = WindowHost.createGlobalObject,
        }) catch |err| {
            self.failed = err;
            return;
        };
    }
};

test "CSSStyleProperties' CSS property attributes are accessors on its prototype in a realm restored from the snapshot, and in a frame's" {
    const page = (try SnapshotPage.open()) orelse return error.SkipZigTest;
    defer page.close();
    try expectOk(page.realm, checks);

    var frame_maker: SnapshotFrame = .{ .agent = page.agent, .parent = page.realm };
    const frame = try frame_maker.make();
    defer protocol.destroyWindowRealm(frame, .global_detached);
    try expectOk(frame, checks);
}

// The CSS property attributes are ~2,000 FunctionTemplates and their names
// (~300 KB of an isolate's heap): an isolate makes CSSStyleProperties'
// template only when a realm first needs it - its interface object read, or
// a style declaration wrapped - as Blink makes every interface's template on
// first use (V8PerIsolateData::FindV8Template). Until then the page's
// global has a lazy CSSStyleProperties, as a frame's has for every
// interface, and a wrapper made first still gets the whole interface
// prototype object (its @@toStringTag is put there when the interface
// object is built).
test "an isolate makes CSSStyleProperties' template only when a realm first needs it" {
    const page = (try SnapshotPage.open()) orelse return error.SkipZigTest;
    defer page.close();
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(page.agent));
    const template_registry = @import("v8").template_registry;

    try testing.expect(template_registry.getTemplateForIsolate("CSSStyleDeclaration", isolate) != null);
    try testing.expect(template_registry.getTemplateForIsolate("CSSStyleProperties", isolate) == null);

    // A realm that touches no style declaration makes none.
    try expectOk(page.realm,
        \\{
        \\  const plain = new Document().implementation.createHTMLDocument('t');
        \\  plain.body.setAttribute('style', 'color: red');
        \\  plain.body.getAttribute('style') === 'color: red' ? 'ok' : 'attribute';
        \\}
    );
    try testing.expect(template_registry.getTemplateForIsolate("CSSStyleProperties", isolate) == null);

    // The first wrapper: the interface object is built for it.
    try expectOk(page.realm,
        \\{
        \\const failures = [];
        \\function check(name, got, want) { if (got !== want) failures.push(name + ": " + String(got)); }
        \\const doc = new Document().implementation.createHTMLDocument('t');
        \\const s = doc.body.style;
        \\check('the class string, before the global is read', Object.prototype.toString.call(s), '[object CSSStyleProperties]');
        \\check("'color' in", 'color' in s, true);
        \\const g = Object.getOwnPropertyDescriptor(globalThis, 'CSSStyleProperties');
        \\check('the global is a data property', typeof g.value, 'function');
        \\check('writable', g.writable, true);
        \\check('not enumerable', g.enumerable, false);
        \\check('configurable', g.configurable, true);
        \\check('its prototype', Object.getPrototypeOf(s), CSSStyleProperties.prototype);
        \\check('inherits', Object.getPrototypeOf(CSSStyleProperties.prototype), CSSStyleDeclaration.prototype);
        \\check('the interface object inherits', Object.getPrototypeOf(CSSStyleProperties), CSSStyleDeclaration);
        \\check('getComputedStyle, the same prototype', Object.getPrototypeOf(getComputedStyle(doc.body)), CSSStyleProperties.prototype);
        \\failures.join('; ') || 'ok';
        \\}
    );
    try testing.expect(template_registry.getTemplateForIsolate("CSSStyleProperties", isolate) != null);
}
