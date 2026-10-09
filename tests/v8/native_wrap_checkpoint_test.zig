//! Making a platform object's wrapper from native code - no script on the
//! stack - performs no microtask checkpoint.
//!
//! HTML performs a microtask checkpoint in "clean up after running script"
//! (when the JavaScript execution context stack is empty) and at the event
//! loop's own points, and nowhere else. V8's kAuto policy performs one
//! whenever an API call entered with do_callback=true returns to call depth 0
//! (api-inl.h, CallDepthScope; isolate.cc,
//! FireCallCompletedCallbackInternal). That is "clean up after running a
//! callback" when the call invoked a callback, and a checkpoint HTML does not
//! have when it did not: v8_CreateLegacyPlatformObjectProxy set its handler's
//! traps with v8::Object::Set (ENTER_V8, 13.1 api.cc:4469), so the first wrap
//! of any NodeList, HTMLCollection, DOMTokenList or other legacy platform
//! object from native code ran every queued microtask - from inside whatever
//! DOM algorithm was wrapping it (edges: MutationRecord.create during a
//! parse delivered each mutation record on its own).
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

/// An agent - V8's default kAuto microtask policy, the browser's - and a
/// Window realm of it.
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

    /// The platform object `source` evaluates to; nothing reported.
    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        return protocol.convertToPlatformObject(self.realm, held.value) orelse error.NotAPlatformObject;
    }
};

/// A microtask the test queues natively, and whether it has run.
const Marker = struct {
    ran: bool = false,

    fn steps(data: ?*anyopaque) void {
        const self: *Marker = @ptrCast(@alignCast(data.?));
        self.ran = true;
    }
};

/// Wrap `object` - which has no wrapper yet - from native code, with a
/// microtask queued: the microtask must still be queued after the wrap, and
/// run at the next real checkpoint.
fn expectWrapRunsNoCheckpoint(page: Page, object: *runtime.Instance) !void {
    try std.testing.expect(!protocol.hasWrapper(object));
    var marker: Marker = .{};
    try protocol.queueMicrotask(page.agent, Marker.steps, &marker);

    const wrapper = try protocol.retainValue(page.realm, .{ .instance = object });
    defer wrapper.release();
    try std.testing.expect(protocol.hasWrapper(object));
    try std.testing.expect(!marker.ran);

    try protocol.performMicrotaskCheckpoint(page.agent);
    try std.testing.expect(marker.ran);
}

/// An element whose collections script has never touched, and whose last
/// child - a Text node `append` made from a string - script has never seen.
const element_source =
    \\(() => {
    \\  const doc = new Document();
    \\  const root = doc.createElement('root');
    \\  root.setAttribute('class', 'a b');
    \\  root.setAttribute('id', 'r');
    \\  root.append(doc.createElement('p'), 'text');
    \\  return root;
    \\})()
;

test "wrapping a NodeList from native code runs no microtask checkpoint" {
    const page = try Page.open();
    defer page.close();
    const root = try page.instance(element_source);
    try expectWrapRunsNoCheckpoint(page, try interfaces.Node.get_childNodes(root));
}

test "wrapping a DOMTokenList from native code runs no microtask checkpoint" {
    const page = try Page.open();
    defer page.close();
    const root = try page.instance(element_source);
    try expectWrapRunsNoCheckpoint(page, try interfaces.Element.get_classList(root));
}

test "wrapping an HTMLCollection from native code runs no microtask checkpoint" {
    const page = try Page.open();
    defer page.close();
    const root = try page.instance(element_source);
    try expectWrapRunsNoCheckpoint(page, try interfaces.Element.get_children(root));
}

test "wrapping a NamedNodeMap from native code runs no microtask checkpoint" {
    const page = try Page.open();
    defer page.close();
    const root = try page.instance(element_source);
    try expectWrapRunsNoCheckpoint(page, try interfaces.Element.get_attributes(root));
}

test "wrapping a node from native code runs no microtask checkpoint" {
    const page = try Page.open();
    defer page.close();
    const root = try page.instance(element_source);
    const text = (try interfaces.Node.get_lastChild(root)) orelse return error.NoChild;
    try expectWrapRunsNoCheckpoint(page, text);
}

// The audit of v8_wrapper.cpp's do_callback=true entries (see NativeStepScope
// there): the other native steps WPT runs reach with no script on the stack
// - a promise resolved from a task, a property set by a DOM algorithm (an
// event handler content attribute), a realm made for a new navigable - run
// no checkpoint either. Measured with a call-completed callback over 1,255
// worklist files; each case below is one of the sites it named.

/// Run `steps(page)` from native code with a microtask queued: the microtask
/// must still be queued after them, and run at the next real checkpoint.
fn expectStepsRunNoCheckpoint(page: Page, comptime steps: fn (Page) anyerror!void) !void {
    var marker: Marker = .{};
    try protocol.queueMicrotask(page.agent, Marker.steps, &marker);
    try steps(page);
    try std.testing.expect(!marker.ran);
    try protocol.performMicrotaskCheckpoint(page.agent);
    try std.testing.expect(marker.ran);
}

test "resolving and rejecting a promise from native code runs no microtask checkpoint" {
    const page = try Page.open();
    defer page.close();
    const Steps = struct {
        fn run(p: Page) !void {
            var resolved = try protocol.createPromise(p.realm);
            defer protocol.releasePromiseCapability(&resolved);
            try protocol.resolvePromise(&resolved, .{ .number = 1 });
            var rejected = try protocol.createPromise(p.realm);
            defer protocol.releasePromiseCapability(&rejected);
            try protocol.rejectPromise(&rejected, .{ .number = 2 });
            const settled = try protocol.createResolvedPromise(p.realm, .{ .number = 3 });
            settled.release();
        }
    };
    try expectStepsRunNoCheckpoint(page, Steps.run);
}

test "setting a property from native code runs no microtask checkpoint" {
    const page = try Page.open();
    defer page.close();
    const root = try page.instance(element_source);
    const Steps = struct {
        var element: *runtime.Instance = undefined;
        fn run(p: Page) !void {
            // What an event handler content attribute's change does: the IDL
            // attribute set through its setter.
            try protocol.setProperty(p.realm, .{ .instance = element }, "onclick", .null);
            try protocol.setProperty(p.realm, .{ .instance = element }, "expando", .{ .number = 4 });
        }
    };
    Steps.element = root;
    try expectStepsRunNoCheckpoint(page, Steps.run);
}

test "creating a Window realm from native code runs no microtask checkpoint" {
    const page = try Page.open();
    defer page.close();
    const Steps = struct {
        fn run(p: Page) !void {
            // A second realm of the agent, as a new navigable's is made from
            // inside the DOM insertion of its iframe.
            const realm = try protocol.createWindowRealm(&.{
                .agent = p.agent,
                .allocator = std.heap.c_allocator,
                .from_snapshot = false,
                .timer = null,
                .origin = "https://example.test",
                .create_global_object = WindowHost.createGlobalObject,
            });
            protocol.destroyWindowRealm(realm, .global_detached);
        }
    };
    try expectStepsRunNoCheckpoint(page, Steps.run);
}
