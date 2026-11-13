//! The process a tests/v8 test runs in.
//!
//! tools/test_launcher runs this directory's tests in any order: a process
//! per test, a few to a process, or the whole suite in one shuffled process.
//! So a test may assume only what `start` makes, and must leave the process
//! as it found it (the approved test plan, tmp/plans/test-architecture-
//! recommendation.md section 3: Blink gives each test a fresh isolate,
//! SpiderMonkey's jsapi-tests assert no runtime is alive at exit). Lane
//! v8order1 found five ways tests/v8 broke that, each a test changing state
//! that later tests of the same process read (docs/testing/
//! tests-v8-order-findings-2026-11-01.tsv):
//!
//! - the standalone runtime: a test that ended it (runtime.deinitializeRuntime)
//!   took it from every later test whose helper had cached "started" in a
//!   once-flag - "a platform object made in a realm no Browser owns, with no
//!   standalone runtime" (`start`, `OwnRuntime`);
//! - V8's flags: a test whose first act was a bare `v8_Isolate_New` started
//!   V8 without the runtime's flags (ShadowRealm, JSPI, Float16Array), which
//!   V8 freezes when it starts (`start`);
//! - an isolate left entered: a file's helper that entered its isolate for
//!   the process made it the current isolate of every later test
//!   (`TestAgent`);
//! - a realm kept for the process: a file's realm, registered with the
//!   thread's context manager, was freed under the file by the first later
//!   test whose own agent was its thread's host agent - whose end took the
//!   thread's context manager down (`TestAgent`; the context manager is each
//!   agent's own since lane engown1, so no agent's end frees another's
//!   realms);
//! - process hooks installed lazily: a test that swapped a hook before its
//!   helper's first call had the helper's start-up overwrite the swap, and
//!   then restored "no hooks" over the real ones (`start` first).
//!
//! Not a test file: the tests of this directory import it.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const ffi = @import("v8").ffi;

/// Start what every test may assume, as crane.Process starts a host
/// (src/browser/process.zig): the engine - V8's platform with the runtime's
/// flags, and the process's dispatchers - then every src/dom hook, once, by
/// whichever test asks first, recorded in the process's own start-up state
/// (dom.process_start); and the standalone runtime (runtime.initializeRuntime),
/// the scope every realm no Browser owns allocates from, when none is
/// running, made with the C allocator - the one this directory's realms and
/// Windows are made with (`.allocator = std.heap.c_allocator`,
/// `Window.init(std.heap.c_allocator, ...)`): a node or EventTarget is made
/// with the allocator its scope frees with, as in a Browser, and Node's and
/// EventTarget's init assert it (lane perf2 batch 6). It was page_allocator,
/// which no realm used. Call it before anything that starts V8 - a bare
/// `ffi.v8_Isolate_New` included - and before swapping a hook. Nothing a test
/// does may end what this starts; a test that needs a standalone runtime of
/// its own, or makes its realms with another allocator, takes one with
/// `OwnRuntime` (or `TestAgent.Options.realm_allocator`).
pub fn start() void {
    if (dom.process_start.begin()) {
        engine.initializeEngine(.{}) catch @panic("tests/v8: the engine did not start");
        interfaces.process_hooks.startHooksForTest();
        dom.process_start.finish(false);
    } else switch (dom.process_start.waitUntilStarted()) {
        .running => {},
        else => @panic("tests/v8: the process did not start"),
    }
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.c_allocator);
}

/// The engine restoring agents from `snapshot` (stamped, as the snapshot
/// generator writes it), for a test whose subject is the snapshot: the
/// process first (`start`, which starts the engine with no snapshot), then the
/// snapshot, until `endSnapshot` - which every such test calls before it
/// returns, once the agents it restored have ended (they read the bytes in
/// place). The engine is started and ended only here: a tests/v8 file that
/// calls engine.initializeEngine or deinitializeEngine itself fails
/// test_process_test's check, unless the engine's start is its subject (lane
/// testfix3: 86 helpers started the engine themselves, each writing the
/// process's engine state again beside the many-Browsers variant's busy
/// Browser).
pub fn startSnapshot(snapshot: []const u8) !void {
    start();
    try engine.initializeEngine(.{ .snapshot = snapshot });
}

/// The end of `startSnapshot`: the engine forgets the snapshot, and restores
/// no agent from it until the next `startSnapshot`.
pub fn endSnapshot() void {
    engine.deinitializeEngine();
}

/// A standalone runtime of the test's own, so that what it leaves in its
/// slab and arena is freed - through the test's allocator, which then reports
/// a leak - when the test ends: `begin` starts the process (`start`) and puts
/// a new standalone scope in the process's place; `end` ends it and puts the
/// process's back. Every later test then finds the runtime the earlier ones
/// made, which a bare `runtime.deinitializeRuntime` took from them.
pub const OwnRuntime = struct {
    previous: ?*runtime.BrowserScope,

    pub fn begin(allocator: std.mem.Allocator) OwnRuntime {
        start();
        const previous = runtime.BrowserScope.standalone();
        runtime.initializeRuntime(allocator);
        return .{ .previous = previous };
    }

    pub fn end(self: OwnRuntime) void {
        runtime.deinitializeRuntime();
        runtime.BrowserScope.setStandalone(self.previous);
    }
};

/// The host hooks of an agent whose host supplies none.
pub const no_hooks: engine.HostHooks = .{};

/// A test's own agent: made by the engine's createAgent on the test's first
/// call to `open`, ended by `close` through destroyAgent - the engine's own
/// path, as a Browser makes and ends its page agent (Blink gives each test a
/// fresh isolate: the approved test plan, tmp/plans/test-architecture-
/// recommendation.md section 3). Its end takes down what the adapter keeps
/// for the agent (protocol_agents.endAgent): its realms among it. So no
/// realm outlives its test - a file's realm kept for the process was freed
/// under it the first time a later test's own agent ended, when the context
/// manager was per thread and the thread's host agent's end took it down
/// (docs/lessons/testing-a-test-may-assume-only-what-the-process-start-
/// makes.md, the fifth mechanism).
///
/// A file declares one, `var test_agent: test_process.TestAgent = .{ .reset
/// = reset };`, its helper calls `open` (the isolate, current while the test
/// runs) and caches what it makes in the agent; every test of the file
/// starts with `defer test_agent.close();`, which ends the agent and calls
/// `reset` to clear the file's caches.
pub const TestAgent = struct {
    isolate: ?*ffi.Isolate = null,
    /// The context `open` made and entered: the test's realm.
    context: ?*ffi.Context = null,
    /// The handle scope `open` opened, for the test's whole life.
    scope: ?*ffi.HandleScope = null,
    /// The entries `enter` made that `close` (or `leave`) undoes.
    entries: u32 = 0,
    /// What ends with the agent, before it: run last first by `close`.
    ends: [16]End = undefined,
    end_count: usize = 0,
    /// The file's own reset of what it cached for the agent, called by
    /// `close` once the agent has ended.
    reset: ?*const fn () void = null,
    /// The agent's own Browser scope (`Options.realm_allocator`), the
    /// process's standalone one while the agent lives, and the one it
    /// replaced: `close` ends it AFTER the agent and puts the other back.
    own_scope: ?*runtime.BrowserScope = null,
    previous_scope: ?*runtime.BrowserScope = null,

    pub const Options = struct {
        /// The agent's host hooks, BORROWED for its life.
        hooks: *const engine.HostHooks = &no_hooks,
        /// [[CanBlock]]: false, as a similar-origin window agent's.
        can_block: bool = false,
        /// What the engine allocates for the agent itself - the isolate's
        /// allocator - BORROWED for its life.
        allocator: std.mem.Allocator = std.heap.c_allocator,
        /// A context of the agent, made and entered: `context`.
        context: bool = true,
        /// The allocator the test makes its realms with - their objects'
        /// creation allocator. The agent's realms with no Browser scope of
        /// their own make their objects in the agent's own scope, made with
        /// this allocator (lane perf2 batch 6): a node or EventTarget is made
        /// with the allocator its scope frees with, as in a Browser, whose
        /// realms are given the allocator its scope was made with - asserted
        /// in Node's and EventTarget's init
        /// (docs/lessons/architecture-a-nodes-creation-allocator-is-its-browsers-only-inside-a-browser.md).
        /// The C allocator by default, as the process's standalone scope's.
        realm_allocator: std.mem.Allocator = std.heap.c_allocator,
    };

    /// What ends before the agent does.
    pub const End = union(enum) {
        /// A Window realm engine.createWindowRealm made in the agent.
        window_realm: runtime.Context,
        /// A context of the agent the test made besides its own.
        context: *ffi.Context,
        /// Another agent the test made: a worker's, ended before its owner's.
        agent: *engine.Agent,
        /// A realm's runtime state the test made for a context of the agent
        /// (`contextData`): deinit, then its storage.
        context_data: struct { data: *runtime.ContextData, allocator: std.mem.Allocator },
        /// A realm record the test made for a context of the agent
        /// (`realmRecord`).
        realm: *runtime.Realm,
        /// Anything else: `call(data)`, with the agent's isolate current.
        call: struct { call: *const fn (?*anyopaque) void, data: ?*anyopaque },
    };

    /// The test's agent - made on its first call, with what every test may
    /// assume started (`start`) - and the current isolate from here on.
    pub fn open(self: *TestAgent, options: Options) !*ffi.Isolate {
        start();
        if (self.isolate) |isolate| {
            self.enter();
            return isolate;
        }
        // Nothing current: a test before this one that left an isolate
        // entered left the process changed (the third mechanism), and this
        // test's would run under it.
        if (ffi.v8_Isolate_GetCurrent() != null) return error.IsolateLeftEntered;
        // The agent's own scope first, so that it ends after the agent
        // (`close`), as a Browser's scope ends after its agent: the
        // standalone one for the agent's life - the scope of every realm of
        // the test that names none (ContextData.browserScope), with the
        // realm's `browser_scope` left null, so nothing that asks for a
        // Browser finds one.
        if (self.own_scope == null) {
            const own = try options.realm_allocator.create(runtime.BrowserScope);
            own.* = runtime.BrowserScope.init(options.realm_allocator);
            self.previous_scope = runtime.BrowserScope.standalone();
            runtime.BrowserScope.setStandalone(own);
            self.own_scope = own;
        }
        const made = try engine.createAgent(.{ .can_block = options.can_block, .from_snapshot = false, .hooks = options.hooks, .host = null, .allocator = options.allocator });
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(made));
        self.isolate = isolate;
        self.enter();
        self.scope = ffi.v8_HandleScope_New(isolate);
        if (options.context) {
            const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
            ffi.v8_Context_Enter(context);
            self.context = context;
        }
        return isolate;
    }

    /// The test's agent, as the engine names it.
    pub fn agent(self: *const TestAgent) *engine.Agent {
        return @ptrCast(self.isolate.?);
    }

    /// Make the agent's isolate the current one, unless it is.
    pub fn enter(self: *TestAgent) void {
        const isolate = self.isolate.?;
        if (ffi.v8_Isolate_GetCurrent() == isolate) return;
        ffi.v8_Isolate_Enter(isolate);
        self.entries += 1;
    }

    /// Undo every entry `enter` made: the current isolate is the one before.
    pub fn leave(self: *TestAgent) void {
        while (self.entries > 0) : (self.entries -= 1) ffi.v8_Isolate_Exit(self.isolate.?);
    }

    /// End `what` before the agent, last registered first.
    pub fn endWith(self: *TestAgent, what: End) void {
        if (self.end_count == self.ends.len) @panic("tests/v8: TestAgent.ends is full");
        self.ends[self.end_count] = what;
        self.end_count += 1;
    }

    /// A Window realm of the agent (`options.agent`), made by
    /// engine.createWindowRealm and destroyed before the agent ends.
    pub fn windowRealm(self: *TestAgent, options: *const engine.WindowRealmOptions) !runtime.Context {
        std.debug.assert(options.agent == self.agent());
        const realm = try engine.createWindowRealm(options);
        self.endWith(.{ .window_realm = realm });
        return realm;
    }

    /// A realm's runtime state for a context of the agent, freed before the
    /// agent ends.
    pub fn contextData(self: *TestAgent, allocator: std.mem.Allocator, options: runtime.ContextData.Options) !*runtime.ContextData {
        const data = try allocator.create(runtime.ContextData);
        errdefer allocator.destroy(data);
        data.* = try runtime.ContextData.init(allocator, options);
        self.endWith(.{ .context_data = .{ .data = data, .allocator = allocator } });
        return data;
    }

    /// A realm record for a context of the agent, freed before the agent ends.
    pub fn realmRecord(self: *TestAgent, allocator: std.mem.Allocator, options: runtime.Realm.InitOptions) !*runtime.Realm {
        const realm = try runtime.Realm.init(allocator, options);
        self.endWith(.{ .realm = realm });
        return realm;
    }

    /// Another context of the agent, not entered, disposed before it ends.
    pub fn newContext(self: *TestAgent) !*ffi.Context {
        const context = ffi.v8_Context_New(self.isolate.?) orelse return error.ContextCreationFailed;
        self.endWith(.{ .context = context });
        return context;
    }

    /// End the test's agent: what `endWith` registered, last first; its
    /// context, its handle scope; then the agent itself, through
    /// engine.destroyAgent, with no isolate current; then its own scope,
    /// putting the standalone scope it replaced back. Then the file's
    /// `reset`.
    pub fn close(self: *TestAgent) void {
        const reset = self.reset;
        defer {
            // The agent's scope ends after the agent, with what its realms
            // left in it, and the standalone scope it replaced is back.
            if (self.own_scope) |own| {
                runtime.BrowserScope.setStandalone(self.previous_scope);
                const allocator = own.allocator;
                own.deinit();
                allocator.destroy(own);
            }
            self.* = .{ .reset = reset };
            if (reset) |r| r();
        }
        const isolate = self.isolate orelse return;
        self.enter();
        while (self.end_count > 0) {
            self.end_count -= 1;
            switch (self.ends[self.end_count]) {
                .window_realm => |realm| engine.destroyWindowRealm(realm, .global_detached),
                .context => |context| ffi.v8_Context_Dispose(context),
                .agent => |other| engine.destroyAgent(other),
                .context_data => |made| {
                    made.data.deinit();
                    made.allocator.destroy(made.data);
                },
                .realm => |realm| realm.deinit(),
                .call => |c| c.call(c.data),
            }
        }
        if (self.context) |context| {
            ffi.v8_Context_Exit(context);
            ffi.v8_Context_Dispose(context);
        }
        if (self.scope) |scope| ffi.v8_HandleScope_Dispose(scope);
        self.leave();
        engine.destroyAgent(@ptrCast(isolate));
    }
};

/// An object made as the binding makes a node's wrapper since the wrapper
/// redesign's P4: an API object from a FunctionTemplate's instance template
/// with no internal field (a node interface's), which the node's anchor is
/// Wrapped onto (node_wrappers.adopt; v8::Object::Wrap needs an API object).
/// OWNED, like v8_Object_New's; `isolate` entered.
pub fn nodeWrapperObject(isolate: *ffi.Isolate, context: *ffi.Context) ?*ffi.Object {
    const template = ffi.v8_FunctionTemplate_New(isolate, null, null) orelse return null;
    defer ffi.v8_FunctionTemplate_Dispose(template);
    const instance_template = ffi.v8_FunctionTemplate_InstanceTemplate(template);
    defer ffi.v8_ObjectTemplate_Dispose(instance_template);
    return ffi.v8_ObjectTemplate_NewInstance(instance_template, context);
}
