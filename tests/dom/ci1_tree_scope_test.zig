//! CSS Shadow1 §4.2: serials identify live tree scopes without holding nodes.
//! DOM adopt §4.5 assigns the adopted roots serials from their new document.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;

const Fixture = struct {
    ctx: runtime.ContextData,
    document: ?*runtime.Instance = null,
    other: ?*runtime.Instance = null,
    container: *runtime.Instance = undefined,
    other_container: *runtime.Instance = undefined,
    shadows: [8]*runtime.Instance = undefined,
    shadow_count: usize = 0,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        self.* = .{ .ctx = runtime.ContextData.init(testing.allocator, .{}) catch |err| {
            runtime.deinitializeRuntime();
            return err;
        } };
        errdefer self.deinit();
        self.document = try interfaces.Document.init(testing.allocator, &self.ctx);
        self.other = try interfaces.Document.init(testing.allocator, &self.ctx);
        self.container = try element(self.document.?, self.document.?, "div");
        self.other_container = try element(self.other.?, self.other.?, "div");
    }

    fn deinit(self: *Fixture) void {
        // Hosts first, then roots from outermost to innermost. The generated
        // interface chain owns the actual teardown; this test owns no engine.
        if (self.document) |document| interfaces.Document.deinit(document);
        if (self.other) |document| interfaces.Document.deinit(document);
        for (self.shadows[0..self.shadow_count]) |shadow| interfaces.ShadowRoot.deinit(shadow);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    fn element(document: *runtime.Instance, parent: *runtime.Instance, name: []const u8) !*runtime.Instance {
        const result = try interfaces.Document.call_createElementNS(document, .initInterned("http://www.w3.org/1999/xhtml"), .initInterned(name), .notPassed());
        errdefer dom.node_creation.destroyUninserted(result);
        _ = try interfaces.Node.call_appendChild(parent, result);
        return result;
    }

    fn attach(self: *Fixture, host: *runtime.Instance) !*runtime.Instance {
        const result = try interfaces.Element.call_attachShadow(host, .{ .mode = ._closed_ });
        self.shadows[self.shadow_count] = result;
        self.shadow_count += 1;
        return result;
    }
};

fn creation() !void {
    if (comptime !@hasDecl(dom, "tree_scope")) return error.TreeScopeSerialNotImplemented;
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const host = try Fixture.element(f.document.?, f.container, "div");
    const outer = try f.attach(host);
    const inner_host = try Fixture.element(f.document.?, outer, "span");
    const inner = try f.attach(inner_host);
    const sibling = try f.attach(try Fixture.element(f.document.?, f.container, "div"));
    const outer_serial = dom.tree_scope.serialOf(outer);
    const inner_serial = dom.tree_scope.serialOf(inner);
    const sibling_serial = dom.tree_scope.serialOf(sibling);
    try testing.expectEqual(@as(u64, 0), dom.tree_scope.serialOf(f.document.?));
    try testing.expect(outer_serial != 0 and inner_serial != 0 and sibling_serial != 0);
    try testing.expect(outer_serial != inner_serial and outer_serial != sibling_serial and inner_serial != sibling_serial);

    _ = try interfaces.Node.call_removeChild(f.container, host);
    defer _ = interfaces.Node.call_appendChild(f.container, host) catch unreachable;
    // Detachment does not recycle an identity. Face availability is the
    // style engine's active-scope decision, tested by its owning row 117.
    try testing.expectEqual(outer_serial, dom.tree_scope.serialOf(outer));
    try testing.expectEqual(inner_serial, dom.tree_scope.serialOf(inner));
    _ = try interfaces.Document.call_adoptNode(f.document.?, host);
    try testing.expectEqual(outer_serial, dom.tree_scope.serialOf(outer));
    try testing.expectEqual(inner_serial, dom.tree_scope.serialOf(inner));
}

fn adoption() !void {
    if (comptime !@hasDecl(dom, "tree_scope")) return error.TreeScopeSerialNotImplemented;
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const host = try Fixture.element(f.document.?, f.container, "div");
    const outer = try f.attach(host);
    const inner = try f.attach(try Fixture.element(f.document.?, outer, "span"));
    const old_outer = dom.tree_scope.serialOf(outer);
    const old_inner = dom.tree_scope.serialOf(inner);
    // Existing target scopes prove allocation uses that document's counter.
    var previous: [3]u64 = undefined;
    for (&previous) |*serial| serial.* = dom.tree_scope.serialOf(try f.attach(try Fixture.element(f.other.?, f.other_container, "div")));
    _ = try interfaces.Document.call_adoptNode(f.other.?, host);
    defer _ = interfaces.Node.call_appendChild(f.other_container, host) catch unreachable;
    try testing.expectEqual(f.other, try interfaces.Node.get_ownerDocument(outer));
    try testing.expectEqual(f.other, try interfaces.Node.get_ownerDocument(inner));
    const outer_serial = dom.tree_scope.serialOf(outer);
    const inner_serial = dom.tree_scope.serialOf(inner);
    try testing.expect(outer_serial != old_outer and inner_serial != old_inner);
    try testing.expect(outer_serial != 0 and inner_serial != 0 and outer_serial != inner_serial);
    for (previous) |serial| try testing.expect(serial != outer_serial and serial != inner_serial);
    const after = dom.tree_scope.serialOf(try f.attach(try Fixture.element(f.other.?, f.other_container, "span")));
    try testing.expect(after != outer_serial and after != inner_serial);
    for (previous) |serial| try testing.expect(after != serial);
}

fn isolated(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn main(failure: *?anyerror) void {
            body() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.main, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "tree scope serials are unique for nested roots and stable while detached" {
    try isolated(creation);
}

test "adoption reassigns every nested shadow root from the new document counter" {
    try isolated(adoption);
}

// Q89: observe token values through the existing document-state facade;
// no impl import, private-state cast, helper call, or new observation hook.
fn interleavedLoadTokens() !void {
    if (comptime !@hasDecl(dom, "tree_scope")) return error.TreeScopeSerialNotImplemented;
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const Queue = struct {
        tasks: [8]runtime.EventLoopTask = undefined,
        count: usize = 0,
        fn queue(context: *anyopaque, task: runtime.EventLoopTask) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            std.debug.assert(self.count < self.tasks.len);
            self.tasks[self.count] = task;
            self.count += 1;
        }
        fn microtask(_: *anyopaque, _: runtime.EventLoopMicrotask) void {}
        fn flush(_: *anyopaque) void {}
        fn once(_: *anyopaque) bool {
            return false;
        }
        fn allocator(_: *anyopaque) std.mem.Allocator {
            return testing.allocator;
        }
        const vtable: runtime.EventLoop.VTable = .{
            .queueTask = queue,
            .queueMicrotask = microtask,
            .runMicrotasks = flush,
            .runOnce = once,
            .promiseAllocator = allocator,
        };
    };
    var queue: Queue = .{};
    f.ctx.event_loop = .{ .ptr = &queue, .vtable = &Queue.vtable };
    defer {
        for (queue.tasks[0..queue.count]) |task| if (task.drop) |drop| drop(task.context);
        f.ctx.event_loop = null;
    }
    // Invoke the existing loading algorithm, rather than the serial helper.
    // Its DOMContentLoaded/load tasks remain queued so the pending token can
    // be read before completion clears it. Scope creation uses real roots.
    dom.document_lifecycle.finishLoading(f.document.?);
    const state = dom.document_internals.getInternal(f.document.?) orelse return error.NoDocumentState;
    const first_load = state.pending_load_token;
    try testing.expect(first_load != 0);
    const a = dom.tree_scope.serialOf(try f.attach(try Fixture.element(f.document.?, f.container, "div")));
    const b = dom.tree_scope.serialOf(try f.attach(try Fixture.element(f.document.?, f.container, "span")));
    dom.document_lifecycle.finishLoading(f.document.?);
    const second_load = state.pending_load_token;
    const c = dom.tree_scope.serialOf(try f.attach(try Fixture.element(f.document.?, f.container, "div")));
    try testing.expect(first_load < a and a < b and b < second_load and second_load < c);
    try testing.expectEqual(@as(u64, 0), state.early_load_token);
    try testing.expectEqual(@as(usize, 4), queue.count); // Two DCL/load pairs.
}

test "load tokens stay nonzero and unique when shadow scope serials interleave" {
    try isolated(interleavedLoadTokens);
}
