//! WebIDL 3.7.9 "define the iteration methods", step 2, through the binding:
//! a pair iterator's %Symbol.iterator% and entries are ONE function, F, named
//! "entries" (DefineMethodProperty and CreateDataPropertyOrThrow of the same
//! F); keys, values and forEach are named for themselves; forEach has length
//! 1. Each steps' "If jsValue does not implement definition, then throw a
//! TypeError" - a receiver of another interface was read as this one's state
//! (Instance.getState falls back to an unchecked cast) - and forEach invokes
//! its callback with "invoke a callback function", whose exception
//! propagates: the old forEach called it through v8_Function_Call, which
//! printed the exception and went on to the next pair.
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

/// Script that answers "ok", or what differs from WebIDL 3.7.9 step 2 for
/// the interface object named `name`.
fn pairIteratorMembers(comptime name: []const u8) []const u8 {
    return "(() => { const proto = " ++ name ++ ".prototype;" ++
        \\  const problems = [];
        \\  for (const [key, length] of [['entries', 0], ['keys', 0], ['values', 0], ['forEach', 1]]) {
        \\    const desc = Object.getOwnPropertyDescriptor(proto, key);
        \\    if (!desc || typeof desc.value !== 'function') { problems.push(key + ' missing'); continue; }
        \\    if (desc.value.name !== key) problems.push(key + ' named ' + JSON.stringify(desc.value.name));
        \\    if (desc.value.length !== length) problems.push(key + ' length ' + desc.value.length);
        \\    if (!desc.writable || !desc.enumerable || !desc.configurable) problems.push(key + ' descriptor');
        \\  }
        \\  const iter = Object.getOwnPropertyDescriptor(proto, Symbol.iterator);
        \\  if (!iter) problems.push('@@iterator missing');
        \\  else {
        \\    if (iter.value !== proto.entries) problems.push('@@iterator is not entries');
        \\    if (!iter.writable || iter.enumerable || !iter.configurable) problems.push('@@iterator descriptor');
        \\  }
        \\  return problems.length ? problems.join('; ') : 'ok';
        \\})()
    ;
}

test "Headers' pair iterator members: @@iterator is entries, each method named" {
    const page = try Page.open();
    defer page.close();
    try page.expect(pairIteratorMembers("Headers"), "ok");
}

test "URLSearchParams' pair iterator members: @@iterator is entries, each method named" {
    const page = try Page.open();
    defer page.close();
    try page.expect(pairIteratorMembers("URLSearchParams"), "ok");
}

test "FormData's pair iterator members: @@iterator is entries, each method named" {
    const page = try Page.open();
    defer page.close();
    try page.expect(pairIteratorMembers("FormData"), "ok");
}

test "a pair iterator's methods throw a TypeError for a receiver of another interface" {
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\(() => {
        \\  const results = [];
        \\  const attempt = (f) => { try { f(); results.push('no throw'); } catch (e) { results.push(e.constructor.name); } };
        \\  const params = new URLSearchParams('a=b');
        \\  const headers = new Headers({ x: 'y' });
        \\  attempt(() => Headers.prototype.forEach.call(params, () => {}));
        \\  attempt(() => Headers.prototype.entries.call(params));
        \\  attempt(() => Headers.prototype.keys.call({}));
        \\  attempt(() => URLSearchParams.prototype.values.call(headers));
        \\  attempt(() => URLSearchParams.prototype[Symbol.iterator].call(undefined));
        \\  attempt(() => URLSearchParams.prototype.forEach.call(new FormData(), () => {}));
        \\  return results.join();
        \\})()
    , "TypeError,TypeError,TypeError,TypeError,TypeError,TypeError");
}

test "a pair iterator's forEach rethrows what its callback throws and stops" {
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\(() => {
        \\  const params = new URLSearchParams('a=1&b=2&c=3');
        \\  let calls = 0;
        \\  try {
        \\    params.forEach(() => { calls++; throw new RangeError('stop'); });
        \\    return 'did not throw ' + calls;
        \\  } catch (e) {
        \\    return e.constructor.name + ' ' + calls;
        \\  }
        \\})()
    , "RangeError 1");
}

test "a pair iterator's forEach invokes its callback with value, key, the object and thisArg" {
    const page = try Page.open();
    defer page.close();
    try page.expect(
        \\(() => {
        \\  const params = new URLSearchParams('a=1&b=2');
        \\  const thisArg = {};
        \\  const seen = [];
        \\  params.forEach(function (value, key, object) {
        \\    seen.push(key + '=' + value + (object === params) + (this === thisArg));
        \\  }, thisArg);
        \\  return seen.join();
        \\})()
    , "a=1truetrue,b=2truetrue");
}
