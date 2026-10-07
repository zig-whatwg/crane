//! Post-connection callbacks must not follow a freed/reused static-list entry.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn makeElement(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
    const element = try interfaces.Element.init(testing.allocator, document.ctx);
    errdefer runtime.Instance.deinit(element);
    try dom.node_creation.setElementNames(element, "http://www.w3.org/1999/xhtml", name);
    try dom.node_document.set(element, document);
    return element;
}

const Fixture = struct {
    document: *runtime.Instance,
    host: *runtime.Instance,
    trigger: *dom.NodeBase,
    doomed: *runtime.Instance,
    replacement: ?*dom.NodeBase = null,
    replaced: bool = false,
    replacement_calls: usize = 0,
    failure: ?anyerror = null,

    fn replace(self: *Fixture) !void {
        self.replaced = true;
        const address = @intFromPtr(self.doomed);
        const generation = runtime.SlabAllocator.generationOf(self.doomed);
        _ = try interfaces.Node.call_removeChild(self.host, self.doomed);
        runtime.Instance.deinit(self.doomed);
        const fresh = try makeElement(self.document, "u");
        errdefer runtime.Instance.deinit(fresh);
        try testing.expectEqual(address, @intFromPtr(fresh));
        try testing.expect(runtime.SlabAllocator.generationOf(fresh) != generation);
        self.replacement = dom.instance_bridge.getNodeBase(fresh).?;
        _ = try interfaces.Node.call_appendChild(self.host, fresh);
    }
};

const Hook = struct {
    // The shared executable keeps the installed callback; outside this test
    // it does nothing. Zig runs tests serially, and this thread is joined.
    var current: ?*Fixture = null;
    fn run(node: *dom.NodeBase) void {
        const fixture = current orelse return;
        if (node == fixture.trigger and !fixture.replaced) {
            fixture.replace() catch |err| {
                fixture.failure = err;
            };
        } else if (node == fixture.replacement) {
            fixture.replacement_calls += 1;
        }
    }
};

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    try dom.mutation.registerPostConnectionStepsCallback(Hook.run);
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer dom.node_creation.destroyUninserted(document);
    const host = try makeElement(document, "div");
    var attached = false;
    defer if (!attached) runtime.Instance.deinit(host);
    const first = try makeElement(document, "b");
    const doomed = try makeElement(document, "i");
    _ = try interfaces.Node.call_appendChild(host, first);
    _ = try interfaces.Node.call_appendChild(host, doomed);
    var fixture = Fixture{
        .document = document,
        .host = host,
        .trigger = dom.instance_bridge.getNodeBase(first).?,
        .doomed = doomed,
    };
    Hook.current = &fixture;
    defer Hook.current = null;
    _ = try interfaces.Node.call_appendChild(document, host);
    attached = true;
    if (fixture.failure) |err| return err;
    try testing.expect(fixture.replaced);
    try testing.expectEqual(@as(usize, 1), fixture.replacement_calls);
}

test "CE post-connection: an entry freed and reused by an earlier callback is skipped" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
