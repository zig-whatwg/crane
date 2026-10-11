//! What script sees of a collection's indexed properties through the binding:
//! WebIDL 3.9 legacy platform objects ([[GetOwnProperty]], [[Set]],
//! [[DefineOwnProperty]], [[OwnPropertyKeys]]) on a static NodeList
//! (querySelectorAll), a live one (childNodes), an HTMLCollection (children,
//! which also has named properties) and a DOMTokenList (string items).
//!
//! These pin the behaviour the indexed property interceptors and the legacy
//! platform object wrapper give today, so that making `list[i]` cheaper
//! changes how fast it is and nothing else. The NodeList-static-length-
//! getter-tampered-*.html files read `list[i]` ~1e8 times; what they check is
//! the last test here: a `length` redefined on the instance changes what
//! Array.prototype.indexOf sees and not what `list[i]` answers.
//!
//! The attribute getter `list.length` is the other half of those files'
//! reads: the last tests pin what a number or boolean attribute answers and
//! that a read makes no handle for its receiver.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agents.

const std = @import("std");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const ffi = @import("v8").ffi;

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

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
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

    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        const got = try self.eval(source);
        defer std.testing.allocator.free(got);
        try std.testing.expectEqualStrings(expected, got);
    }
};

/// Script defining `lists()`: a fresh document's `root` with three element
/// children a, b, c (ids x, y, z) and the collections over them.
const fixture =
    \\function lists() {
    \\  const doc = new Document();
    \\  const root = doc.createElement('root');
    \\  doc.appendChild(root);
    \\  for (const [name, id] of [['a', 'x'], ['b', 'y'], ['c', 'z']]) {
    \\    const el = doc.createElement(name);
    \\    el.id = id;
    \\    el.className = 'k';
    \\    root.appendChild(el);
    \\  }
    \\  return { doc, root, qsa: root.querySelectorAll('.k'), childNodes: root.childNodes, children: root.children };
    \\}
    \\
;

/// Script answering "ok", or each way `list_expr` (over `root`'s three
/// element children a, b, c) differs from WebIDL's indexed [[Get]] and
/// [[GetOwnProperty]].
fn indexedGets(comptime list_expr: []const u8) []const u8 {
    return fixture ++
        \\(() => {
        \\  const { root } = lists();
        \\  const list =
    ++ " " ++ list_expr ++ ";\n" ++
        \\  const problems = [];
        \\  const check = (what, got, want) => { if (got !== want) problems.push(what + ': ' + String(got)); };
        \\  check('[0]', list[0], root.firstChild);
        \\  check('[2]', list[2], root.lastChild);
        \\  check("['1']", list['1'], root.firstChild.nextSibling);
        \\  check('[0] === item(0)', list[0] === list.item(0), true);
        \\  check('[3]', list[3], undefined);
        \\  check('item(3)', list.item(3), null);
        \\  check('[-1]', list[-1], undefined);
        \\  check("['01']", list['01'], undefined);
        \\  check('[4294967294]', list[4294967294], undefined);
        \\  check('[4294967295]', list[4294967295], undefined);
        \\  check('0 in', 0 in list, true);
        \\  check('2 in', 2 in list, true);
        \\  check('3 in', 3 in list, false);
        \\  check('hasOwnProperty(1)', Object.prototype.hasOwnProperty.call(list, 1), true);
        \\  check('hasOwnProperty(3)', Object.prototype.hasOwnProperty.call(list, 3), false);
        \\  check('hasOwnProperty(length)', Object.prototype.hasOwnProperty.call(list, 'length'), false);
        \\  const desc = Object.getOwnPropertyDescriptor(list, '1');
        \\  if (!desc) problems.push('no descriptor for 1');
        \\  else {
        \\    check('desc.value', desc.value, list[1]);
        \\    check('desc.writable', desc.writable, false);
        \\    check('desc.enumerable', desc.enumerable, true);
        \\    check('desc.configurable', desc.configurable, true);
        \\    check('desc.get', 'get' in desc, false);
        \\  }
        \\  check('descriptor of 3', Object.getOwnPropertyDescriptor(list, '3'), undefined);
        \\  check('propertyIsEnumerable(0)', Object.prototype.propertyIsEnumerable.call(list, 0), true);
        \\  return problems.length ? problems.join('; ') : 'ok';
        \\})()
    ;
}

test "a static NodeList answers indexed [[Get]] and [[GetOwnProperty]] as WebIDL says" {
    const page = try Page.open();
    defer page.close();
    try page.expect(indexedGets("root.querySelectorAll('.k')"), "ok");
}

test "a live NodeList answers indexed [[Get]] and [[GetOwnProperty]] as WebIDL says" {
    const page = try Page.open();
    defer page.close();
    try page.expect(indexedGets("root.childNodes"), "ok");
}

test "an HTMLCollection answers indexed [[Get]] and [[GetOwnProperty]] as WebIDL says" {
    const page = try Page.open();
    defer page.close();
    try page.expect(indexedGets("root.children"), "ok");
}

test "a live NodeList's indices follow the tree" {
    const page = try Page.open();
    defer page.close();
    try page.expect(fixture ++
        \\(() => {
        \\  const { doc, root, childNodes } = lists();
        \\  const before = [childNodes.length, childNodes[3] === undefined].join();
        \\  const d = doc.createElement('d');
        \\  root.appendChild(d);
        \\  const added = [childNodes.length, childNodes[3] === d, 3 in childNodes, Reflect.ownKeys(childNodes).join(' ')].join();
        \\  root.removeChild(root.firstChild);
        \\  const removed = [childNodes.length, childNodes[0] === root.firstChild, childNodes[3], 3 in childNodes].join();
        \\  return before + ' | ' + added + ' | ' + removed;
        \\})()
    , "3,true | 4,true,true,0 1 2 3 | 3,true,,false");
}

test "a static NodeList does not follow the tree" {
    const page = try Page.open();
    defer page.close();
    try page.expect(fixture ++
        \\(() => {
        \\  const { root, qsa } = lists();
        \\  const first = root.firstChild;
        \\  root.removeChild(first);
        \\  return [qsa.length, qsa[0] === first, qsa[2] === root.lastChild].join();
        \\})()
    , "3,true,true");
}

test "indexed properties come first in [[OwnPropertyKeys]], then expandos, then symbols" {
    const page = try Page.open();
    defer page.close();
    // WebIDL 3.9.6: supported indices ascending, supported names (an
    // HTMLCollection's: ids, then names), own string keys in creation order,
    // own symbols.
    try page.expect(fixture ++
        \\(() => {
        \\  const { qsa, childNodes, children } = lists();
        \\  const s = Symbol('s');
        \\  const keys = (list) => {
        \\    list.expando = 1;
        \\    list[s] = 2;
        \\    list.another = 3;
        \\    return Reflect.ownKeys(list).map(String).join(' ') + ' / ' + Object.keys(list).join(' ') + ' / ' + Object.getOwnPropertyNames(list).join(' ');
        \\  };
        \\  return [keys(qsa), keys(childNodes), keys(children)].join(' | ');
        \\})()
    , "0 1 2 expando another Symbol(s) / 0 1 2 expando another / 0 1 2 expando another" ++
        " | 0 1 2 expando another Symbol(s) / 0 1 2 expando another / 0 1 2 expando another" ++
        " | 0 1 2 x y z expando another Symbol(s) / 0 1 2 expando another / 0 1 2 x y z expando another");
}

test "for-in visits the indices first" {
    const page = try Page.open();
    defer page.close();
    try page.expect(fixture ++
        \\(() => {
        \\  const { qsa, childNodes, children } = lists();
        \\  const firstKeys = (list) => { const seen = []; for (const k in list) { seen.push(k); if (seen.length === 4) break; } return seen.slice(0, 3).join(' ') + (/^[0-9]/.test(seen[3]) ? ' +index' : ''); };
        \\  return [firstKeys(qsa), firstKeys(childNodes), firstKeys(children)].join(' | ');
        \\})()
    , "0 1 2 | 0 1 2 | 0 1 2");
}

test "an index cannot be assigned or defined on a NodeList or a DOMTokenList" {
    const page = try Page.open();
    defer page.close();
    // WebIDL 3.9.3 [[DefineOwnProperty]] step 1: an array index on an object
    // with no indexed property setter is rejected, in or out of range. So
    // [[Set]] returns false - a TypeError in strict mode, nothing in sloppy
    // mode - and Object.defineProperty throws a TypeError
    // (webidl/ecmascript-binding/legacy-platform-object/DefineOwnProperty.html
    // checks the same on a DOMTokenList). Neither has named properties, so
    // neither is wrapped in a proxy (template_registry.zig): V8 runs the
    // indexed setter and definer interceptors itself. (Reflect.defineProperty
    // still answers true, and `delete list[0]` true: the definer signals no
    // failure and there is no deleter - gaps not pinned here.)
    try page.expect(fixture ++
        \\(() => {
        \\  const { root, qsa, childNodes } = lists();
        \\  const span = root.ownerDocument.createElement('span');
        \\  span.className = 'p q r';
        \\  const strictSet = (list, i) => { 'use strict'; try { list[i] = 'v'; return 'set'; } catch (e) { return e.constructor.name; } };
        \\  const sloppySet = new Function('list', 'i', "try { list[i] = 'v'; return String(list[i] === 'v'); } catch (e) { return e.constructor.name; }");
        \\  const define = (list, i, desc) => { try { Object.defineProperty(list, i, desc); return 'defined'; } catch (e) { return e.constructor.name; } };
        \\  const one = (list) => {
        \\    const first = list[0];
        \\    return [strictSet(list, 0), strictSet(list, 7), sloppySet(list, 0), sloppySet(list, 7),
        \\      define(list, 0, { value: 'v' }), define(list, 7, { value: 'v', writable: true }), define(list, 0, { get() { return 1; } }),
        \\      list[0] === first, list[7], list.length].join();
        \\  };
        \\  return [one(qsa), one(childNodes), one(span.classList)].join(' | ');
        \\})()
    , "TypeError,TypeError,false,false,TypeError,TypeError,TypeError,true,,3 | TypeError,TypeError,false,false,TypeError,TypeError,TypeError,true,,3 | TypeError,TypeError,false,false,TypeError,TypeError,TypeError,true,,3");
}

test "an object inheriting from a collection reads its indices through it" {
    const page = try Page.open();
    defer page.close();
    // ES OrdinaryGet on the heir finds no own "0" and asks its prototype -
    // the collection - with the heir as receiver: WebIDL's [[GetOwnProperty]]
    // of the collection (O, not the receiver) answers the item. So does a
    // Reflect.get with another receiver. (`heir.length` is a TypeError: the
    // getter's `this` is the heir - dom/collections/HTMLCollection-as-
    // prototype.html.)
    try page.expect(fixture ++
        \\(() => {
        \\  const { root, qsa, childNodes, children } = lists();
        \\  const one = (list) => { const heir = Object.create(list); return [heir[0] === root.firstChild, heir[2] === root.lastChild, heir[3], 0 in heir, 3 in heir, Reflect.get(list, 1, {}) === root.firstChild.nextSibling].join(); };
        \\  return [one(qsa), one(childNodes), one(children)].join(' | ');
        \\})()
    , "true,true,,true,false,true | true,true,,true,false,true | true,true,,true,false,true");
}

test "an expando and a redefined length are the instance's own" {
    const page = try Page.open();
    defer page.close();
    try page.expect(fixture ++
        \\(() => {
        \\  const { qsa } = lists();
        \\  qsa.foo = 'bar';
        \\  const ownFoo = Object.getOwnPropertyDescriptor(qsa, 'foo');
        \\  Object.defineProperty(qsa, 'length', { get() { return 1; }, configurable: true });
        \\  const ownLength = Object.getOwnPropertyDescriptor(qsa, 'length');
        \\  return [qsa.foo, ownFoo.writable && ownFoo.enumerable && ownFoo.configurable, qsa.length, typeof ownLength.get, Object.getPrototypeOf(qsa) === NodeList.prototype, qsa instanceof NodeList, Object.prototype.toString.call(qsa)].join();
        \\})()
    , "bar,true,1,function,true,true,[object NodeList]");
}

test "a length redefined on a NodeList changes Array.prototype.indexOf, not list[i]" {
    const page = try Page.open();
    defer page.close();
    // What dom/nodes/NodeList-static-length-getter-tampered-*.html check, at
    // a size a unit test runs in no time: a loop over list[j] bounded by
    // list.length, and Array.prototype.indexOf.call(list, el), before and
    // after `length` is redefined on the instance.
    try page.expect(fixture ++
        \\(() => {
        \\  const { doc } = lists();
        \\  const host = doc.createElement('div');
        \\  for (let i = 0; i < 100; i++) { const el = doc.createElement('span'); el.className = 'foo'; host.append(el); }
        \\  const nodeList = host.querySelectorAll('.foo');
        \\  const el = nodeList[50];
        \\  const loop = () => { for (let j = 0; j < nodeList.length; j++) if (nodeList[j] === el) return j; return -1; };
        \\  const before = [loop(), Array.prototype.indexOf.call(nodeList, el), Array.prototype.includes.call(nodeList, el)].join();
        \\  Object.defineProperty(nodeList, 'length', { get() { return 10; } });
        \\  const after = [loop(), Array.prototype.indexOf.call(nodeList, el), Array.prototype.includes.call(nodeList, el), nodeList[50] === el, nodeList[99] === host.lastChild, nodeList[100]].join();
        \\  return before + ' | ' + after;
        \\})()
    , "50,50,true | -1,-1,false,true,true,");
}

test "a DOMTokenList answers its tokens by index" {
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\(() => {
        \\  const el = new Document().createElement('span');
        \\  el.className = 'a b';
        \\  const list = el.classList;
        \\  const desc = Object.getOwnPropertyDescriptor(list, '1');
        \\  return [list[0], list[1], list[2], 1 in list, 2 in list, desc.value, desc.writable, desc.enumerable, desc.configurable, Reflect.ownKeys(list).join(' ')].join();
        \\})()
    , "a,b,,true,false,b,false,true,true,0 1");
}

/// The engine's counter `name`, now.
fn counter(name: []const u8) !i64 {
    const counters = try protocol.diagnosticCounters(std.testing.allocator);
    defer std.testing.allocator.free(counters);
    for (counters) |c| {
        if (std.mem.eql(u8, c.name, name)) return c.value;
    }
    return error.NoSuchCounter;
}

test "an indexed read and an `in` check make no handle for the list" {
    const page = try Page.open();
    defer page.close();
    // `list[i]` runs the indexed getter and `i in list` the query: ~1e8
    // times each in NodeList-static-length-getter-tampered-*.html. Neither
    // needs a Global for the list (the receiver or the holder): the instance
    // is read from the holder's internal field. Before, each made one
    // (v8_PropertyCallbackInfo_This) and disposed it.
    try page.expect(fixture ++
        \\globalThis.probe = lists();
        \\'ready'
    , "ready");
    const read_all =
        \\(() => {
        \\  let found = 0;
        \\  for (let n = 0; n < 64; n++) {
        \\    for (const list of [probe.qsa, probe.childNodes, probe.children]) {
        \\      if (list[n % 3] === probe.root.firstChild) found++;
        \\      if ((n % 4) in list) found++;
        \\    }
        \\  }
        \\  return String(found);
        \\})()
    ;
    try page.expect(read_all, "210");
    const this_before = try counter("object_globals_from.PropertyCallbackInfo_This");
    const contexts_before = try counter("live_context_globals");
    try page.expect(read_all, "210");
    const this_made = try counter("object_globals_from.PropertyCallbackInfo_This") - this_before;
    const contexts_left = try counter("live_context_globals") - contexts_before;
    if (this_made != 0 or contexts_left != 0) {
        std.debug.print("384 indexed reads and 384 `in` checks made {d} `this` Globals and left {d} Context Globals\n", .{ this_made, contexts_left });
        return error.HandlesMade;
    }
}

test "a number or boolean attribute answers its value" {
    const page = try Page.open();
    defer page.close();
    // Each primitive kind an attribute getter returns: unsigned long
    // (NodeList.length), unsigned short (Node.nodeType, Event.eventPhase),
    // boolean (Event.bubbles), unsigned long long (ProgressEvent.loaded),
    // long (UIEvent.detail), double (Event.timeStamp) - the values WebIDL's
    // conversions to ECMAScript give, and numbers, not objects.
    try page.expect(fixture ++
        \\(() => {
        \\  const { qsa, root } = lists();
        \\  const ev = new Event('x');
        \\  const bubbling = new Event('y', { bubbles: true });
        \\  const big = new ProgressEvent('p', { loaded: 9007199254740991 });
        \\  const ui = new UIEvent('u', { detail: -2 });
        \\  const wide = new UIEvent('w', { detail: 2147483647 });
        \\  const t = ev.timeStamp;
        \\  return [qsa.length, typeof qsa.length, root.nodeType, ev.eventPhase, ev.bubbles, bubbling.bubbles, typeof ev.bubbles,
        \\    big.loaded, ui.detail, wide.detail, typeof t === 'number' && t >= 0 && t === ev.timeStamp].join();
        \\})()
    , "3,number,1,0,false,true,boolean,9007199254740991,-2,2147483647,true");
}

test "an attribute read makes no handle for its receiver and leaves none" {
    const page = try Page.open();
    defer page.close();
    // `list.length` ran ~6e7 times per NodeList-static-length-getter-
    // tampered-[123].html, and each made a Global for `this` and one for the
    // Number, then released both. A number, a boolean, a string and a node
    // result: no `this` Global (object_globals_from.FunctionCallbackInfo_This
    // counts creations), and V8's live global handle bytes flat.
    try page.expect(fixture ++
        \\globalThis.attrs = lists();
        \\globalThis.attrEvent = new Event('x');
        \\'ready'
    , "ready");
    const reads =
        \\(() => {
        \\  let n = 0;
        \\  for (let k = 0; k < 64; k++) {
        \\    n += attrs.qsa.length + attrs.childNodes.length + attrs.root.nodeType;
        \\    if (attrEvent.bubbles === false) n++;
        \\    if (attrs.root.firstChild.localName === 'a') n++;
        \\    n += attrEvent.timeStamp >= 0 ? 1 : 0;
        \\  }
        \\  return String(n);
        \\})()
    ;
    try page.expect(reads, "640");
    try page.collect();
    const this_before = try counter("object_globals_from.FunctionCallbackInfo_This");
    const bytes_before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(page.isolate()));
    try page.expect(reads, "640");
    try page.collect();
    const this_made = try counter("object_globals_from.FunctionCallbackInfo_This") - this_before;
    const bytes_left = @as(i64, @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(page.isolate()))) - bytes_before;
    if (this_made != 0 or bytes_left > 0) {
        std.debug.print("64 rounds of attribute reads made {d} `this` Globals and left {d} global handle bytes\n", .{ this_made, bytes_left });
        return error.HandlesMade;
    }
}
