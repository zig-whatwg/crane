//! WebIDL 2.5.6 special operations as script sees them through the binding,
//! which installs a legacy platform object's handlers (3.9) from codegen's
//! Meta.special_operations - not from function names:
//!
//! - which interfaces get which handlers (the table, pinned at comptime);
//! - NamedNodeMap's named properties are read-only: its regular
//!   `setNamedItem(Attr)` is no named setter (3.9.3 step 2.2.1);
//! - an HTMLOptionsCollection has the named properties it inherits;
//! - a named setter takes every string (3.9.2 [[Set]] step 1.2), a definer
//!   runs it (3.9.3 step 2.2.2), a deleter deletes (3.9.4), and a named
//!   property's descriptor is enumerable unless
//!   [LegacyUnenumerableNamedProperties] (3.9.1 step 2.1.8);
//! - an interface with named properties and no indexed ones takes an array
//!   index as a name (Blink's bind_gen forwards the same way);
//! - the named property visibility algorithm (3.9.7) on a read: an own
//!   property of O hides a named property, under [LegacyOverrideBuiltIns]
//!   too, which skips only the prototype chain (step 3);
//! - [[OwnPropertyKeys]] (3.9.6) lists the visible named properties unless
//!   codegen records the browsers' exception (HTMLFormElement,
//!   Meta.special_operations.named_properties_in_own_keys), which keeps
//!   named lookup.
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
const webidl = @import("webidl");
const specialBinding = @import("v8").interface_mod.specialBinding;
const SpecialBinding = @import("v8").interface_mod.SpecialBinding;

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
    // [[OwnPropertyKeys]] step 3 lists the visible named properties: the
    // default, in the table and in the binding, and every interface's but
    // the browsers' exception, HTMLFormElement (whatwg/html#1731).
    std.debug.assert((webidl.SpecialOperations{}).named_properties_in_own_keys);
    std.debug.assert((SpecialBinding{}).named_properties_in_own_keys);
    std.debug.assert(specialBinding(interfaces.Storage).named_properties_in_own_keys);
    std.debug.assert(specialBinding(interfaces.NamedNodeMap).named_properties_in_own_keys);
    std.debug.assert(specialBinding(interfaces.DOMStringMap).named_properties_in_own_keys);
    std.debug.assert(specialBinding(interfaces.HTMLCollection).named_properties_in_own_keys);
    std.debug.assert(specialBinding(interfaces.HTMLFormControlsCollection).named_properties_in_own_keys);
    std.debug.assert(specialBinding(interfaces.HTMLOptionsCollection).named_properties_in_own_keys);
    std.debug.assert(specialBinding(interfaces.Document).named_properties_in_own_keys);
    std.debug.assert(!interfaces.HTMLFormElement.Meta.special_operations.named_properties_in_own_keys);
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

test "NamedNodeMap: named properties are read-only - setNamedItem is a regular operation, no setter" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  const { body } = html();
        \\  body.setAttribute('title', 't');
        \\  const attrs = body.attributes;
        \\  const attr = attrs.getNamedItem('title');
        \\  check('attrs.title', attrs.title, attr);
        \\  const desc = Object.getOwnPropertyDescriptor(attrs, 'title');
        \\  check('desc', desc !== undefined, true);
        \\  if (desc) {
        \\    check('desc.value', desc.value, attr);
        \\    check('desc.writable', desc.writable, false);
        \\    check('desc.enumerable', desc.enumerable, false);
        \\    check('desc.configurable', desc.configurable, true);
        \\  }
        \\  check('strict set throws', throwsTypeError(() => { 'use strict'; attrs.title = 1; }), true);
        \\  attrs.title = 1;
        \\  check('sloppy set changes nothing', attrs.title, attr);
        \\  check('defineProperty throws', throwsTypeError(() => Object.defineProperty(attrs, 'title', { value: 1 })), true);
        \\  check('still the attr', attrs.title, attr);
        \\  check('no own expando', Object.getOwnPropertyNames(attrs).filter(k => k === 'title').length, 1);
    );
}

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

test "DOMStringMap: the named setter takes every string, not only the names it has" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  const { body } = html();
        \\  const ds = body.dataset;
        \\  ds.fooBar = 'x';
        \\  check('attribute', body.getAttribute('data-foo-bar'), 'x');
        \\  check('read back', ds.fooBar, 'x');
        \\  ds.fooBar = 'y';
        \\  check('replaced', body.getAttribute('data-foo-bar'), 'y');
        \\  const desc = Object.getOwnPropertyDescriptor(ds, 'fooBar');
        \\  check('enumerable', desc && desc.enumerable, true);
        \\  check('writable', desc && desc.writable, true);
        \\  Object.defineProperty(ds, 'viaDefine', { value: 'z' });
        \\  check('defined', body.getAttribute('data-via-define'), 'z');
        \\  check('accessor throws', throwsTypeError(() => Object.defineProperty(ds, 'acc', { get() { return 1; } })), true);
        \\  check('no accessor attribute', body.hasAttribute('data-acc'), false);
    );
}

test "[[Delete]]: a named deleter deletes; a visible named property or a supported index without one is not deletable" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  const { doc, body } = html();
        \\  body.setAttribute('data-gone', '1');
        \\  check('delete dataset.gone', delete body.dataset.gone, true);
        \\  check('attribute removed', body.hasAttribute('data-gone'), false);
        \\  check('delete of nothing', delete body.dataset.never, true);
        \\  const a = doc.createElement('a');
        \\  a.id = 'named';
        \\  body.appendChild(a);
        \\  const children = body.children;
        \\  check('delete children.named', delete children.named, false);
        \\  check('still there', children.named, a);
        \\  check('strict delete throws', throwsTypeError(() => { 'use strict'; delete children.named; }), true);
        \\  check('delete children[0]', delete children[0], false);
        \\  check('delete children[5]', delete children[5], true);
        \\  check('strict delete [0] throws', throwsTypeError(() => { 'use strict'; delete children[0]; }), true);
        \\  check('delete attributes.id', delete a.attributes.id, false);
    );
}

test "a named property's descriptor is enumerable unless [LegacyUnenumerableNamedProperties]" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  const { doc, body } = html();
        \\  const a = doc.createElement('a');
        \\  a.id = 'n';
        \\  body.appendChild(a);
        \\  const desc = Object.getOwnPropertyDescriptor(body.children, 'n');
        \\  check('HTMLCollection enumerable', desc && desc.enumerable, false);
        \\  check('HTMLCollection writable', desc && desc.writable, false);
        \\  body.dataset.k = 'v';
        \\  const ddesc = Object.getOwnPropertyDescriptor(body.dataset, 'k');
        \\  check('DOMStringMap enumerable', ddesc && ddesc.enumerable, true);
        \\  check('Object.keys', Object.keys(body.dataset).join(), 'k');
    );
}

test "named properties and no indexed ones: an array index is a name" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  const { body } = html();
        \\  const ds = body.dataset;
        \\  ds[0] = 'zero';
        \\  check('attribute', body.getAttribute('data-0'), 'zero');
        \\  check('read', ds[0], 'zero');
        \\  check('in', 0 in ds, true);
        \\  check('keys', Object.keys(ds).join(), '0');
        \\  check('delete', delete ds[0], true);
        \\  check('deleted', body.hasAttribute('data-0'), false);
    );
}

test "a named property's name may be long, and keeps its lone surrogates" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  const { body } = html();
        \\  const ds = body.dataset;
        \\  const long = 'a'.repeat(300);
        \\  ds[long] = 'v';
        \\  check('long attribute', body.getAttribute('data-' + long), 'v');
        \\  check('long read', ds[long], 'v');
        \\  check('long in', long in ds, true);
        \\  check('long delete', delete ds[long], true);
        \\  check('long gone', body.hasAttribute('data-' + long), false);
    );
}

test "an own property hides a named property; the prototype chain does not, without [LegacyOverrideBuiltIns]" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  const { doc, body } = html();
        \\  const children = body.children;
        \\  children.later = 5;
        \\  const a = doc.createElement('a');
        \\  a.id = 'later';
        \\  body.appendChild(a);
        \\  check('expando hides the named property', children.later, 5);
        \\  check('delete the expando', delete children.later, true);
        \\  check('then the named property', children.later, a);
        \\  const b = doc.createElement('a');
        \\  b.id = 'item';
        \\  body.appendChild(b);
        \\  check('the prototype hides it', typeof children.item, 'function');
    );
}

test "the default: a named getter's names are in [[OwnPropertyKeys]] (3.9.6 step 3)" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  const { doc, body } = html();
        \\  body.setAttribute('data-x', '1');
        \\  check('dataset', Object.getOwnPropertyNames(body.dataset).join(), 'x');
        \\  check('attributes', Object.getOwnPropertyNames(body.attributes).join(), '0,data-x');
        \\  const a = doc.createElement('a');
        \\  a.id = 'n';
        \\  body.appendChild(a);
        \\  check('children', Object.getOwnPropertyNames(body.children).join(), '0,n');
    );
}

/// HTMLFormElement's named getter is its impl's to implement (Codex row 23);
/// until it does, the binding installs none and these two have nothing to
/// test.
const form_named_getter_bound = specialBinding(interfaces.HTMLFormElement).named_getter != null;

test "[LegacyOverrideBuiltIns]: an own property hides a named property (visibility step 2), the prototype chain does not (step 3)" {
    if (!form_named_getter_bound) return error.SkipZigTest;
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  const { doc, body } = html();
        \\  const form = doc.createElement('form');
        \\  body.appendChild(form);
        \\  const add = (name) => { const input = doc.createElement('input'); input.name = name; form.appendChild(input); return input; };
        \\  form.later = 5;
        \\  const later = add('later');
        \\  check('expando hides the named property', form.later, 5);
        \\  const desc = Object.getOwnPropertyDescriptor(form, 'later');
        \\  check('its descriptor', desc && desc.value, 5);
        \\  check('delete the expando', delete form.later, true);
        \\  check('then the named property', form.later, later);
        \\  Object.defineProperty(form, 'fixed', { value: 6, configurable: false, writable: false });
        \\  add('fixed');
        \\  check('a non-configurable expando hides it', form.fixed, 6);
        \\  check('and stays', delete form.fixed, false);
        \\  check('still the expando', form.fixed, 6);
        \\  const submit = add('submit');
        \\  check('over the prototype chain', form.submit, submit);
    );
}

test "HTMLFormElement: no names in [[OwnPropertyKeys]], as in every browser - and named lookup unchanged" {
    if (!form_named_getter_bound) return error.SkipZigTest;
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\  const { doc, body } = html();
        \\  const form = doc.createElement('form');
        \\  body.appendChild(form);
        \\  const alpha = doc.createElement('input');
        \\  alpha.name = 'alpha';
        \\  form.appendChild(alpha);
        \\  const beta = doc.createElement('input');
        \\  beta.id = 'beta';
        \\  form.appendChild(beta);
        \\  form.expando = 1;
        \\  check('getOwnPropertyNames', Object.getOwnPropertyNames(form).join(), '0,1,expando');
        \\  check('Reflect.ownKeys', Reflect.ownKeys(form).filter(k => typeof k === 'string').join(), '0,1,expando');
        \\  check('Object.keys', Object.keys(form).join(), '0,1,expando');
        \\  const seen = [];
        \\  for (const k in form) if (k === 'alpha' || k === 'beta') seen.push(k);
        \\  check('for-in', seen.join(), '');
        \\  check('alpha', form.alpha, alpha);
        \\  check('beta', form.beta, beta);
        \\  check('in', 'alpha' in form, true);
        \\  check('hasOwnProperty', Object.prototype.hasOwnProperty.call(form, 'alpha'), true);
        \\  const desc = Object.getOwnPropertyDescriptor(form, 'alpha');
        \\  check('descriptor value', desc && desc.value, alpha);
        \\  check('descriptor enumerable', desc && desc.enumerable, false);
        \\  check('descriptor configurable', desc && desc.configurable, true);
    );
}
