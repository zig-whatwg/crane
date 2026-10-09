//! WebIDL 3.7.9 "define the iteration methods", step 1, through the binding:
//! an interface with an indexed property getter takes the realm's
//! %Array.prototype.values% as its %Symbol.iterator% (DefineMethodProperty,
//! not enumerable), and one that also has a VALUE iterator
//! (`iterable<V>`) takes %Array.prototype.entries%, %Array.prototype.keys%,
//! %Array.prototype.values% and %Array.prototype.forEach% as its entries,
//! keys, values and forEach (CreateDataPropertyOrThrow: writable, enumerable,
//! configurable) - the same function objects, so forEach invokes its callback
//! as Array.prototype.forEach does and the iterators are array iterators.
//!
//! NodeList (`iterable<Node>`) and DOMTokenList (`iterable<DOMString>`) used to
//! bind forEach to impl stubs that never called the callback, and their
//! @@iterator, entries, keys and values to the adapter's own iterator objects.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agents.

const std = @import("std");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

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
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
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

    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        const got = try self.eval(source);
        defer std.testing.allocator.free(got);
        try std.testing.expectEqualStrings(expected, got);
    }
};

/// Script that answers "ok", or what differs from WebIDL 3.7.9 step 1 for
/// the interface object named `name`: the realm's Array.prototype functions,
/// with the descriptors DefineMethodProperty and CreateDataPropertyOrThrow
/// give, as the interface prototype object's own properties.
fn valueIteratorMembers(comptime name: []const u8) []const u8 {
    return
    \\(() => {
    \\  const proto =
    ++ name ++
        \\.prototype;
        \\  const problems = [];
        \\  for (const key of ['entries', 'keys', 'values', 'forEach']) {
        \\    const desc = Object.getOwnPropertyDescriptor(proto, key);
        \\    if (!desc) { problems.push(key + ' missing'); continue; }
        \\    if (desc.value !== Array.prototype[key]) problems.push(key + ' is not Array.prototype.' + key);
        \\    if (!desc.writable || !desc.enumerable || !desc.configurable) problems.push(key + ' descriptor ' + JSON.stringify(desc));
        \\  }
        \\  const iter = Object.getOwnPropertyDescriptor(proto, Symbol.iterator);
        \\  if (!iter) problems.push('@@iterator missing');
        \\  else {
        \\    if (iter.value !== Array.prototype[Symbol.iterator]) problems.push('@@iterator is not Array.prototype[@@iterator]');
        \\    if (iter.value !== Array.prototype.values) problems.push('@@iterator is not Array.prototype.values');
        \\    if (!iter.writable || iter.enumerable || !iter.configurable) problems.push('@@iterator descriptor');
        \\  }
        \\  return problems.length ? problems.join('; ') : 'ok';
        \\})()
    ;
}

test "NodeList's value iterator members are the realm's Array.prototype functions" {
    const page = try Page.open();
    defer page.close();
    try page.expect(valueIteratorMembers("NodeList"), "ok");
}

test "DOMTokenList's value iterator members are the realm's Array.prototype functions" {
    const page = try Page.open();
    defer page.close();
    try page.expect(valueIteratorMembers("DOMTokenList"), "ok");
}

test "RadioNodeList inherits NodeList's value iterator members" {
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\[RadioNodeList.prototype.forEach === Array.prototype.forEach,
        \\ RadioNodeList.prototype.entries === Array.prototype.entries,
        \\ RadioNodeList.prototype[Symbol.iterator] === Array.prototype.values,
        \\ !Object.prototype.hasOwnProperty.call(RadioNodeList.prototype, 'forEach')].join()
    , "true,true,true,true");
}

test "NodeList.forEach invokes its callback with each node, its index and the list, and thisArg" {
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\(() => {
        \\  const doc = new Document();
        \\  const root = doc.createElement('root');
        \\  root.append(doc.createElement('a'), doc.createElement('b'));
        \\  const list = root.childNodes;
        \\  const seen = [];
        \\  const thisArg = {};
        \\  list.forEach(function (node, index, object) {
        \\    seen.push(node.localName + index + (object === list) + (this === thisArg));
        \\  }, thisArg);
        \\  return seen.join();
        \\})()
    , "a0truetrue,b1truetrue");
}

test "DOMTokenList.forEach invokes its callback with each token, its index and the list" {
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\(() => {
        \\  const element = new Document().createElement('span');
        \\  element.setAttribute('class', '  a  a b ');
        \\  const list = element.classList;
        \\  const seen = [];
        \\  list.forEach((token, index, object) => seen.push(token + index + (object === list)));
        \\  return seen.join();
        \\})()
    , "a0true,b1true");
}

test "forEach rethrows what its callback throws and stops" {
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\(() => {
        \\  const element = new Document().createElement('span');
        \\  element.className = 'a b c';
        \\  let calls = 0;
        \\  try {
        \\    element.classList.forEach(() => { calls++; throw new RangeError('stop'); });
        \\    return 'did not throw';
        \\  } catch (e) {
        \\    return e.constructor.name + ' ' + calls;
        \\  }
        \\})()
    , "RangeError 1");
}

test "forEach requires a callable callback" {
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\(() => {
        \\  const list = new Document().childNodes;
        \\  try { list.forEach(); return 'did not throw'; } catch (e) { return e.constructor.name; }
        \\})()
    , "TypeError");
}

test "keys, values, entries and @@iterator return array iterators over the indexed properties" {
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\(() => {
        \\  const element = new Document().createElement('span');
        \\  element.className = 'x y';
        \\  const list = element.classList;
        \\  const arrayIteratorProto = Object.getPrototypeOf([].values());
        \\  return [
        \\    JSON.stringify([...list.keys()]),
        \\    JSON.stringify([...list.values()]),
        \\    JSON.stringify([...list.entries()]),
        \\    JSON.stringify([...list]),
        \\    Object.getPrototypeOf(list.values()) === arrayIteratorProto,
        \\    Object.getPrototypeOf(list[Symbol.iterator]()) === arrayIteratorProto,
        \\  ].join(' ');
        \\})()
    , "[0,1] [\"x\",\"y\"] [[0,\"x\"],[1,\"y\"]] [\"x\",\"y\"] true true");
}

test "a NodeList iterates its nodes through for-of, spread and entries" {
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\(() => {
        \\  const doc = new Document();
        \\  const root = doc.createElement('root');
        \\  root.append(doc.createElement('a'), doc.createTextNode('t'), doc.createElement('b'));
        \\  const name = (node) => node.localName || node.nodeName;
        \\  const names = [];
        \\  for (const node of root.childNodes) names.push(name(node));
        \\  const entries = [...root.childNodes.entries()].map(([i, n]) => i + name(n));
        \\  return names.join() + ' ' + entries.join();
        \\})()
    , "a,#text,b 0a,1#text,2b");
}

test "a [Global] interface's indexed getter defines no iteration methods" {
    // WebIDL "create an interface prototype object" step 12: the iteration
    // methods are defined only when the interface is not declared [Global].
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\[Object.getOwnPropertySymbols(Window.prototype).includes(Symbol.iterator),
        \\ Symbol.iterator in globalThis].join()
    , "false,false");
}
