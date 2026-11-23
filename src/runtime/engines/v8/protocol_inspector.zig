//! The agent's inspector on V8 (engine_protocol.zig section 4.2b
//! [inspector_protocol]; tmp/plans/cdp-part1-design.md 3.4; the user's ruling
//! D3, 2026-11-21): V8's own v8_inspector, as Chrome's - Blink's
//! MainThreadDebugger owns its isolate's V8Inspector and is its client, and
//! DevToolsSession hands every method V8InspectorSession::canDispatchMethod
//! accepts to V8 (third_party/blink/renderer/core/inspector/
//! main_thread_debugger.cc, devtools_session.cc; BSD-3 - reproduced, not
//! copied).
//!
//! - ONE inspector per agent (V8 allows one per isolate): `Inspector`, on the
//!   agent's record (protocol_agents.inspectorOf), made on the first need -
//!   the console's first REPL evaluation (protocol_repl.zig) or a host's
//!   first session or registration - and ended in the agent's end's two
//!   steps: `end` (every host session disconnected, every registered context
//!   forgotten while the contexts exist), then `destroy` (the V8Inspector
//!   deleted, after the agent's last microtask checkpoints, before its
//!   isolate is disposed).
//! - CONTEXTS are registered by the HOST (`register`, engine.
//!   inspectorContextCreated), never by the adapter at a realm's making: a
//!   realm is made before its document commits, and CDP clients drop a
//!   context reported before executionContextsCleared (lane cdph's notes,
//!   tmp/plans/cdph-inspector-notes.md: the host registers at commit). Each
//!   registration is on its realm's finalizer list, so the realm's end tells
//!   V8 while the context exists. A context belongs to one group: registering
//!   it in another moves it.
//! - HOST SESSIONS (`Session`, engine.inspectorConnect): a V8InspectorSession
//!   in the host's group whose messages go to the host's channel as UTF-8.
//!   -Dcdp=false compiles them out (the capability is unsupported, so no
//!   operation of this file but the REPL's `inspectorOf` is referenced; the
//!   C++ session machinery behind them is reached only from here, and the
//!   linker drops it); the REPL's use of the inspector stays.
//! - WRAP without V8's generated protocol types (the prebuilt does not ship
//!   inspector/Runtime.h): the value is the session's inspected object, and
//!   Runtime.evaluate of the command line API's `$0` in its context answers
//!   its RemoteObject (v8_wrapper.cpp CraneInspectorSession::Wrap).
//! - CONSOLE: Crane's console is the Console Standard's namespace, not V8's,
//!   so V8 never sees a console call. Each realm keeps V8's own console object
//!   (interface_bindings.registerNamespacesGeneric, -Dcdp), and the Logger
//!   step calls its method with the same arguments (`consoleMessage`): V8's
//!   console delegate - the inspector's V8Console - stores and reports the
//!   message exactly as Chrome's does.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const support = @import("protocol_support.zig");
const realm_finalizers = @import("realm_finalizers.zig");
const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
const context_manager = @import("context_manager.zig");
const protocol_agents = @import("protocol_agents.zig");
const realm_entry = @import("realm_entry.zig");

const Context = engine.Context;
const JSValue = engine.JSValue;
const Error = engine.Error;

const log = std.log.scoped(.protocol_inspector);

/// The console's own group: realms the console evaluates in that no host
/// registered (protocol_repl.zig). Above every group a host numbers (CDP
/// numbers its tabs from 1).
pub const repl_group: c_int = 0x7fff_fff0;

/// THE agent's inspector.
pub const Inspector = struct {
    allocator: std.mem.Allocator,
    isolate: *ffi.Isolate,
    native: *ffi.Inspector,
    /// What V8's client asks the host (v8_wrapper.cpp CraneInspectorHooks),
    /// at a stable address: the C++ side copies it.
    hooks: ffi.InspectorHooks = undefined,
    /// engine.installInspectorClient; null: none.
    client: ?*const engine.InspectorClient = null,
    /// The realms registered and not forgotten, each on its realm's list.
    realms: std.ArrayListUnmanaged(*Registered) = .empty,
    /// The host sessions connected.
    sessions: std.ArrayListUnmanaged(*Session) = .empty,
    /// The host's groups (engine.InspectorGroup, a tab's id) as V8's int
    /// group ids, numbered from 1 in the order the host first names them
    /// (`v8Group`); never `repl_group`.
    groups: std.AutoHashMapUnmanaged(engine.InspectorGroup, c_int) = .empty,
    next_group: c_int = 1,
    /// `end` ran: nothing is registered or connected any more.
    ended: bool = false,
    /// How many stacks `inspectorCaptureStack` asked V8 to capture (tests
    /// read it: tests/v8/inspector_bridge_test.zig).
    capture_asks: u64 = 0,

    pub fn create(allocator: std.mem.Allocator, isolate: *ffi.Isolate) Error!*Inspector {
        const self = try allocator.create(Inspector);
        errdefer allocator.destroy(self);
        const native = ffi.v8_Inspector_New(isolate) orelse return error.OperationFailed;
        self.* = .{ .allocator = allocator, .isolate = isolate, .native = native };
        self.hooks = .{
            .host = self,
            .run_if_waiting = runIfWaiting,
            .run_message_loop_on_pause = runMessageLoopOnPause,
            .quit_message_loop_on_pause = quitMessageLoopOnPause,
            .default_context = defaultContext,
            .value_subtype = valueSubtype,
            .description = description,
        };
        ffi.v8_Inspector_SetHooks(native, &self.hooks);
        return self;
    }

    /// The agent's end, step 1 (protocol_agents.endAgent, before its record
    /// is forgotten): every host session's V8 session goes - a host that did
    /// not disconnect its own hears nothing more, and its later
    /// `inspectorDisconnect` frees only the record - and every registered
    /// context is forgotten while it exists.
    pub fn end(self: *Inspector) void {
        if (self.ended) return;
        self.ended = true;
        for (self.sessions.items) |session| session.endNative();
        while (self.realms.pop()) |registered| {
            unlinkRegistered(registered);
            self.allocator.destroy(registered);
        }
        ffi.v8_Inspector_DetachContexts(self.native);
        ffi.v8_Inspector_SetHooks(self.native, null);
    }

    /// The agent's end, step 2 (after its last microtask checkpoints, before
    /// its isolate is disposed, with the isolate entered): the V8Inspector
    /// goes - the console's sessions went before it (protocol_repl) - then
    /// this.
    pub fn destroy(self: *Inspector) void {
        if (!self.ended) self.end();
        // Sessions a host never disconnected: their records go with the agent.
        while (self.sessions.pop()) |session| session.free();
        ffi.v8_Inspector_Delete(self.native);
        self.realms.deinit(self.allocator);
        self.sessions.deinit(self.allocator);
        self.groups.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// V8's group id for the host's `group`, numbered on first use.
    pub fn v8Group(self: *Inspector, group: engine.InspectorGroup) Error!c_int {
        if (self.groups.get(group)) |known| return known;
        if (self.next_group >= repl_group) return error.OperationFailed;
        const id = self.next_group;
        try self.groups.put(self.allocator, group, id);
        self.next_group += 1;
        return id;
    }

    /// The host's group of V8's `id`, if it is one (not the console's).
    fn hostGroup(self: *const Inspector, id: c_int) ?engine.InspectorGroup {
        var it = self.groups.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.* == id) return entry.key_ptr.*;
        }
        return null;
    }

    fn registeredOf(self: *Inspector, realm: Context) ?*Registered {
        for (self.realms.items) |registered| {
            if (registered.realm == realm) return registered;
        }
        return null;
    }

    fn registeredById(self: *Inspector, id: c_int) ?*Registered {
        for (self.realms.items) |registered| {
            if (registered.id == id) return registered;
        }
        return null;
    }

    /// Make `realm` known in `group` (`InspectorContext`); its context id. A
    /// realm known in another group is forgotten there first.
    pub fn register(self: *Inspector, info: RegisterInfo) Error!c_int {
        if (self.ended) return error.OperationFailed;
        const realm = info.realm;
        if (self.registeredOf(realm)) |known| {
            if (known.group == info.group) return known.id;
            self.forget(known);
        }
        const list = realm_finalizers.listOf(realm);
        if (list) |l| if (l.ended) return error.OperationFailed;
        const engine_ctx = realm.engine_ctx orelse return error.OperationFailed;
        const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
        const registered = try self.allocator.create(Registered);
        errdefer self.allocator.destroy(registered);
        try self.realms.ensureUnusedCapacity(self.allocator, 1);
        const id = ffi.v8_Inspector_ContextCreated(self.native, context, info.group, info.name.ptr, info.name.len, info.origin.ptr, info.origin.len, info.aux_data.ptr, info.aux_data.len);
        if (id == 0) return error.OperationFailed;
        registered.* = .{ .inspector = self, .realm = realm, .id = id, .group = info.group, .is_default = info.is_default };
        if (list) |l| {
            l.add(&registered.node) catch {
                ffi.v8_Inspector_ContextDestroyed(self.native, id);
                return error.OperationFailed;
            };
            registered.cache = cacheOfList(l);
            registered.cache.?.inspector_registrations += 1;
        }
        self.realms.appendAssumeCapacity(registered);
        return id;
    }

    /// Forget `registered`: contextDestroyed, off its realm's list.
    fn forget(self: *Inspector, registered: *Registered) void {
        unlinkRegistered(registered);
        self.remove(registered);
        const id = registered.id;
        self.allocator.destroy(registered);
        ffi.v8_Inspector_ContextDestroyed(self.native, id);
    }

    fn remove(self: *Inspector, registered: *Registered) void {
        for (self.realms.items, 0..) |item, i| {
            if (item != registered) continue;
            _ = self.realms.swapRemove(i);
            return;
        }
    }

    /// Every realm of `group` forgotten, and V8's resetContextGroup:
    /// Runtime.executionContextsCleared.
    pub fn resetGroup(self: *Inspector, group: c_int) void {
        var i: usize = self.realms.items.len;
        while (i > 0) {
            i -= 1;
            const registered = self.realms.items[i];
            if (registered.group != group) continue;
            unlinkRegistered(registered);
            _ = self.realms.swapRemove(i);
            self.allocator.destroy(registered);
        }
        ffi.v8_Inspector_ResetGroup(self.native, group);
    }
};

/// What `Inspector.register` takes: engine.InspectorContext with the
/// adapter's group type.
pub const RegisterInfo = struct {
    realm: Context,
    group: c_int,
    name: []const u8 = "",
    origin: []const u8 = "",
    aux_data: []const u8 = "",
    is_default: bool = false,
};

/// The realm adapter state a realm's finalizer list belongs to
/// (WrapperCache.finalizers).
fn cacheOfList(list: *realm_finalizers.List) *WrapperCache {
    return @alignCast(@fieldParentPtr("finalizers", list));
}

/// Take `registered` off its realm's list, and out of the realm's count of
/// registrations (WrapperCache.inspector_registrations).
fn unlinkRegistered(registered: *Registered) void {
    if (registered.node.list != null) {
        if (registered.cache) |cache| cache.inspector_registrations -= 1;
        registered.cache = null;
    }
    registered.node.unlink();
}

/// Whether the agent's inspector may know `realm`, read from the realm's
/// own adapter state with no lock (WrapperCache.inspector_registrations):
/// false when no registration of it stands, so the caller returns before
/// the agent registry's locked lookup (protocol_agents.recordOf, about
/// 127 ns) that finding the inspector is. True - the lookup goes on, and
/// is counted (WrapperCache.inspector_lookups) - when one does, and for a
/// realm with no wrapper cache (a context a test made by hand, one already
/// retired), which has no count.
fn mayBeRegistered(realm: Context) bool {
    const list = realm_finalizers.listOf(realm) orelse return true;
    const cache = cacheOfList(list);
    if (cache.inspector_registrations == 0) return false;
    cache.inspector_lookups += 1;
    return true;
}

/// A realm the inspector knows: on its realm's list until it ends.
const Registered = struct {
    inspector: *Inspector,
    realm: Context,
    id: c_int,
    group: c_int,
    is_default: bool,
    node: realm_finalizers.Node = .{ .drop = realmEnded },
    /// The realm adapter state whose list `node` is on, and whose count of
    /// registrations (WrapperCache.inspector_registrations) this is one of;
    /// null when it is on none.
    cache: ?*WrapperCache = null,

    /// The realm ended (realm_finalizers.List.drain; unlinked already): the
    /// inspector forgets its context now, while it exists.
    fn realmEnded(node: *realm_finalizers.Node) void {
        const self: *Registered = @fieldParentPtr("node", node);
        // The drain took it off the list (its `list` is null now): its
        // count, on the cache that is draining it - never through the realm,
        // which a cache's own end outlives.
        if (self.cache) |cache| cache.inspector_registrations -= 1;
        self.cache = null;
        const inspector = self.inspector;
        inspector.remove(self);
        const id = self.id;
        inspector.allocator.destroy(self);
        ffi.v8_Inspector_ContextDestroyed(inspector.native, id);
    }
};

/// A host's session (engine.InspectorSession).
pub const Session = struct {
    inspector: *Inspector,
    /// Null once the agent's end took V8's session (`Inspector.end`).
    native: ?*ffi.InspectorSession,
    channel: engine.InspectorChannel,
    group: c_int,

    /// V8's session goes: nothing more reaches the channel.
    fn endNative(self: *Session) void {
        const native = self.native orelse return;
        self.native = null;
        ffi.v8_InspectorSession_Delete(native);
    }

    /// The session goes: V8's first, then this.
    fn free(self: *Session) void {
        self.endNative();
        self.inspector.allocator.destroy(self);
    }
};

fn sessionOf(session: *engine.InspectorSession) *Session {
    return @ptrCast(@alignCast(session));
}

/// A session's message out (CraneInspectorSession's channel): to the host.
fn onSend(host: ?*anyopaque, utf8: [*]const u8, length: usize) callconv(.c) void {
    const session: *Session = @ptrCast(@alignCast(host orelse return));
    session.channel.send(session.channel.context, utf8[0..length]);
}

// ---- V8InspectorClient's answers (CraneInspectorHooks) ----

fn inspectorOfHost(host: ?*anyopaque) ?*Inspector {
    return @ptrCast(@alignCast(host orelse return null));
}

fn runIfWaiting(host: ?*anyopaque, group: c_int) callconv(.c) void {
    const inspector = inspectorOfHost(host) orelse return;
    const client = inspector.client orelse return;
    const steps = client.runIfWaitingForDebugger orelse return;
    steps(client.host, inspector.hostGroup(group) orelse return);
}

fn runMessageLoopOnPause(host: ?*anyopaque, group: c_int) callconv(.c) void {
    const inspector = inspectorOfHost(host) orelse return;
    const client = inspector.client orelse return;
    const steps = client.runMessageLoopOnPause orelse return;
    steps(client.host, inspector.hostGroup(group) orelse return);
}

fn quitMessageLoopOnPause(host: ?*anyopaque) callconv(.c) void {
    const inspector = inspectorOfHost(host) orelse return;
    const client = inspector.client orelse return;
    const steps = client.quitMessageLoopOnPause orelse return;
    steps(client.host);
}

/// V8InspectorClient::ensureDefaultContextInGroup: the realm the host
/// registered as `group`'s default, its record's own handle (BORROWED).
fn defaultContext(host: ?*anyopaque, group: c_int) callconv(.c) ?*ffi.Context {
    const inspector = inspectorOfHost(host) orelse return null;
    for (inspector.realms.items) |registered| {
        if (registered.group != group or !registered.is_default) continue;
        const engine_ctx = registered.realm.engine_ctx orelse return null;
        return @ptrCast(@alignCast(engine_ctx));
    }
    return null;
}

/// V8InspectorClient::valueSubtype for a platform object: the host's answer
/// (engine.InspectorClient.valueSubtype), NUL-terminated for the C++ side.
fn valueSubtype(host: ?*anyopaque, instance: *anyopaque) callconv(.c) ?[*:0]const u8 {
    const inspector = inspectorOfHost(host) orelse return null;
    const client = inspector.client orelse return null;
    const steps = client.valueSubtype orelse return null;
    const subtype = steps(client.host, @ptrCast(@alignCast(instance))) orelse return null;
    // The protocol's subtypes, as static NUL-terminated text.
    inline for (.{ "node", "array", "error", "blob", "trustedtype" }) |known| {
        if (std.mem.eql(u8, subtype, known)) return known;
    }
    return null;
}

/// V8InspectorClient::descriptionForValueSubtype: the host's answer into the
/// C++ side's buffer.
fn description(host: ?*anyopaque, instance: *anyopaque, buffer: [*]u8, capacity: usize) callconv(.c) usize {
    const inspector = inspectorOfHost(host) orelse return 0;
    const client = inspector.client orelse return 0;
    const steps = client.descriptionForValueSubtype orelse return 0;
    const written = steps(client.host, @ptrCast(@alignCast(instance)), buffer[0..capacity]) orelse return 0;
    return written.len;
}

// ============================================================================
// The operations
// ============================================================================

fn isolateOfAgent(agent: *engine.Agent) *ffi.Isolate {
    return @ptrCast(@alignCast(agent));
}

/// The inspector of `realm`'s agent if it has one (never made here).
fn existingOfRealm(realm: Context) ?*Inspector {
    const isolate = realm_entry.agentOf(realm) orelse return null;
    return protocol_agents.existingInspectorOf(isolate);
}

/// engine.installInspectorClient.
pub fn installInspectorClient(agent: *engine.Agent, client: ?*const engine.InspectorClient) void {
    const inspector = protocol_agents.inspectorOf(isolateOfAgent(agent)) orelse return;
    inspector.client = client;
}

/// engine.inspectorConnect.
pub fn inspectorConnect(agent: *engine.Agent, group: engine.InspectorGroup, channel: engine.InspectorChannel) Error!*engine.InspectorSession {
    if (group == 0) return error.OperationFailed;
    const inspector = protocol_agents.inspectorOf(isolateOfAgent(agent)) orelse return error.OperationFailed;
    if (inspector.ended) return error.OperationFailed;
    const session = try inspector.allocator.create(Session);
    errdefer inspector.allocator.destroy(session);
    try inspector.sessions.ensureUnusedCapacity(inspector.allocator, 1);
    const v8_group = try inspector.v8Group(group);
    session.* = .{ .inspector = inspector, .native = null, .channel = channel, .group = v8_group };
    session.native = ffi.v8_InspectorSession_New(inspector.native, v8_group, onSend, session) orelse return error.OperationFailed;
    inspector.sessions.appendAssumeCapacity(session);
    return @ptrCast(session);
}

/// engine.inspectorDisconnect.
pub fn inspectorDisconnect(opaque_session: *engine.InspectorSession) void {
    const session = sessionOf(opaque_session);
    const inspector = session.inspector;
    for (inspector.sessions.items, 0..) |item, i| {
        if (item != session) continue;
        _ = inspector.sessions.swapRemove(i);
        break;
    }
    session.free();
}

/// engine.inspectorDispatch.
pub fn inspectorDispatch(opaque_session: *engine.InspectorSession, message: []const u8) void {
    const session = sessionOf(opaque_session);
    if (message.len == 0) return;
    const native = session.native orelse return;
    ffi.v8_InspectorSession_Dispatch(native, message.ptr, message.len);
}

/// engine.inspectorCanDispatch.
pub fn inspectorCanDispatch(method: []const u8) bool {
    if (method.len == 0) return false;
    return ffi.v8_Inspector_CanDispatch(method.ptr, method.len);
}

/// engine.inspectorContextCreated.
pub fn inspectorContextCreated(context: *const engine.InspectorContext) Error!i64 {
    if (context.group == 0) return error.OperationFailed;
    const isolate = realm_entry.agentOf(context.realm) orelse return error.OperationFailed;
    const inspector = protocol_agents.inspectorOf(isolate) orelse return error.OperationFailed;
    const id = try inspector.register(.{
        .realm = context.realm,
        .group = try inspector.v8Group(context.group),
        .name = context.name,
        .origin = context.origin,
        .aux_data = context.aux_data,
        .is_default = context.is_default,
    });
    return id;
}

/// engine.inspectorContextDestroyed.
pub fn inspectorContextDestroyed(realm: Context) void {
    const inspector = existingOfRealm(realm) orelse return;
    const registered = inspector.registeredOf(realm) orelse return;
    inspector.forget(registered);
}

/// engine.inspectorResetGroup.
pub fn inspectorResetGroup(agent: *engine.Agent, group: engine.InspectorGroup) void {
    const inspector = protocol_agents.existingInspectorOf(isolateOfAgent(agent)) orelse return;
    // A group the host never named has no context to clear.
    const v8_group = inspector.groups.get(group) orelse return;
    inspector.resetGroup(v8_group);
}

/// engine.inspectorContextId.
pub fn inspectorContextId(realm: Context) ?i64 {
    const inspector = existingOfRealm(realm) orelse return null;
    const registered = inspector.registeredOf(realm) orelse return null;
    return registered.id;
}

/// engine.inspectorRealmOfContextId.
pub fn inspectorRealmOfContextId(agent: *engine.Agent, id: i64) ?Context {
    const inspector = protocol_agents.existingInspectorOf(isolateOfAgent(agent)) orelse return null;
    const narrow = std.math.cast(c_int, id) orelse return null;
    const registered = inspector.registeredById(narrow) orelse return null;
    return registered.realm;
}

/// What CraneInspectorSession::Wrap hands back: the whole response, copied.
const Captured = struct {
    allocator: std.mem.Allocator,
    bytes: ?[]u8 = null,
    failed: bool = false,

    fn sink(host: ?*anyopaque, utf8: [*]const u8, length: usize) callconv(.c) void {
        const self: *Captured = @ptrCast(@alignCast(host orelse return));
        self.bytes = self.allocator.dupe(u8, utf8[0..length]) catch {
            self.failed = true;
            return;
        };
    }
};

/// engine.inspectorWrap: the value as the session's inspected object, its
/// RemoteObject from Runtime.evaluate of `$0` in `realm`'s context - the
/// response's `result.result`, re-serialized.
pub fn inspectorWrap(opaque_session: *engine.InspectorSession, realm: Context, value: JSValue, object_group: []const u8, allocator: std.mem.Allocator) Error![]u8 {
    const session = sessionOf(opaque_session);
    const registered = session.inspector.registeredOf(realm) orelse return error.OperationFailed;
    if (registered.group != session.group) return error.OperationFailed;
    const entered = try support.enter(realm);
    defer entered.leave();
    // A platform object as its wrapper in the realm's world (the realm is
    // entered: protocol_support.relevantWrapper reads its world).
    const held = try support.ownGlobal(entered, value);
    defer ffi.v8_Global_Dispose(held);
    const native = session.native orelse return error.OperationFailed;
    var captured: Captured = .{ .allocator = allocator };
    defer if (captured.bytes) |bytes| allocator.free(bytes);
    if (!ffi.v8_InspectorSession_Wrap(native, registered.id, held, object_group.ptr, object_group.len, Captured.sink, &captured)) return error.OperationFailed;
    if (captured.failed) return error.OutOfMemory;
    const response = captured.bytes orelse return error.OperationFailed;
    return remoteObjectOfResponse(allocator, response);
}

/// `result.result` of a Runtime.evaluate response, as JSON text OWNED by
/// `allocator`; OperationFailed for an error response or an exception.
fn remoteObjectOfResponse(allocator: std.mem.Allocator, response: []const u8) Error![]u8 {
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, response, .{}) catch return error.OperationFailed;
    defer parsed.deinit();
    const root = switch (parsed.value) {
        .object => |o| o,
        else => return error.OperationFailed,
    };
    const result = switch (root.get("result") orelse return error.OperationFailed) {
        .object => |o| o,
        else => return error.OperationFailed,
    };
    if (result.get("exceptionDetails") != null) return error.OperationFailed;
    const remote = result.get("result") orelse return error.OperationFailed;
    return std.json.Stringify.valueAlloc(allocator, remote, .{}) catch error.OutOfMemory;
}

/// engine.inspectorUnwrap.
pub fn inspectorUnwrap(opaque_session: *engine.InspectorSession, object_id: []const u8) Error!?engine.InspectorUnwrapped {
    const session = sessionOf(opaque_session);
    if (object_id.len == 0) return null;
    var key: ?*anyopaque = null;
    const native = session.native orelse return null;
    const value = ffi.v8_InspectorSession_Unwrap(native, object_id.ptr, object_id.len, &key) orelse return null;
    const realm = context_manager.getByKey(@intFromPtr(key orelse {
        ffi.v8_Global_Dispose(value);
        return null;
    })) orelse {
        ffi.v8_Global_Dispose(value);
        return null;
    };
    return .{ .value = support.owned(value), .realm = realm };
}

/// engine.inspectorConsoleMessage: V8's own console[method](...args) in
/// `realm` (the realm kept it at its making, -Dcdp), so V8's console delegate
/// - the inspector's - reports and stores the message as Chrome's does.
pub fn inspectorConsoleMessage(realm: Context, method: []const u8, args: []const JSValue) void {
    // Nothing - not even the agent registry's locked lookup - for a realm
    // no registration stands for (see below: V8 drops its call), read from
    // the realm itself (`mayBeRegistered`; lane tpc: the lookup was most of
    // what a console call cost a Browser with no session after daa01f91a).
    if (!mayBeRegistered(realm)) return;
    const inspector = existingOfRealm(realm) orelse return;
    if (inspector.ended or method.len == 0) return;
    // Nothing for a realm the inspector does not know (no contextCreated):
    // V8's console delegate drops such a call itself - ConsoleHelper::
    // reportCall returns when the calling context's group is 0
    // (src/inspector/v8-console.cc:124 at 15.7.112.43; V8InspectorImpl::
    // contextGroupId answers 0 for a context id contextCreated never named) -
    // so a call that cannot be reported or stored costs no handles, entry or
    // call into the engine's console (lane tpc: about a microsecond per
    // console call with -Dcdp, on every Browser with no session). Every
    // registration goes through Inspector.register (the host's
    // inspectorContextCreated, the console's replContextOf), so `realms` is
    // the inspector's whole list.
    if (inspector.registeredOf(realm) == null) return;
    const entered = support.enter(realm) catch return;
    defer entered.leave();
    // Each argument as a handle of the realm - a platform object as its
    // wrapper in the realm's world (protocol_support.relevantWrapper reads
    // the entered realm's world). At most 32: the console's own bound.
    var handles: [32]*ffi.Value = undefined;
    var count: usize = 0;
    defer for (handles[0..count]) |h| ffi.v8_Global_Dispose(h);
    for (args) |value| {
        if (count == handles.len) break;
        handles[count] = support.ownGlobal(entered, value) catch continue;
        count += 1;
    }
    ffi.v8_Context_EngineConsoleCall(entered.context(), method.ptr, method.len, &handles, count);
}

/// engine.inspectorExceptionThrown.
pub fn inspectorExceptionThrown(realm: Context, exception: JSValue, details: *const engine.InspectorExceptionDetails) u32 {
    // Nothing for a realm no registration stands for, read with no lock
    // (`mayBeRegistered`): V8 drops the report itself - V8InspectorImpl::
    // exceptionThrown returns 0 for context group 0 (v8-inspector-impl.cc:379
    // at 15.7.112.43) - and every reported exception of a Browser with no
    // session paid the agent registry's locked lookup for it.
    if (!mayBeRegistered(realm)) return 0;
    const inspector = existingOfRealm(realm) orelse return 0;
    if (inspector.ended) return 0;
    if (inspector.registeredOf(realm) == null) return 0;
    const entered = support.enter(realm) catch return 0;
    defer entered.leave();
    const held = support.ownGlobal(entered, exception) catch null;
    defer if (held) |h| ffi.v8_Global_Dispose(h);
    const stack: ?*const ffi.InspectorStack = if (details.stack) |captured| CapturedStack.of(captured).native else null;
    return ffi.v8_Inspector_ExceptionThrown(inspector.native, entered.context(), held, details.message.ptr, details.message.len, details.url.ptr, details.url.len, details.line, details.column, stack);
}

/// What engine.inspectorCaptureStack hands out: V8's stack (C++, freed by
/// v8_InspectorStack_Delete) in a record of the realm's allocator, so a
/// capture its holder never releases is the allocator's leak - the Browser's
/// leak-checking allocator in a test names it.
const CapturedStack = struct {
    allocator: std.mem.Allocator,
    native: *ffi.InspectorStack,

    fn of(stack: *const engine.InspectorStack) *const CapturedStack {
        return @ptrCast(@alignCast(stack));
    }
};

/// engine.inspectorCaptureStack: the running script's stack, as V8's
/// inspector captures one (V8Inspector::captureStackTrace) - for a report
/// made after the call returned, as Blink's V8Initializer::
/// PromiseRejectHandler captures its SourceLocation.
pub fn inspectorCaptureStack(realm: Context) ?*engine.InspectorStack {
    // Nothing for a realm the inspector does not know (no contextCreated):
    // V8 captures nothing for it - V8Debugger::captureStackTrace returns
    // nullptr when the current context's group is 0 (src/inspector/
    // v8-debugger.cc:1431 at 15.7.112.43; V8InspectorImpl::contextGroupId
    // answers 0 for a context id contextCreated never named) - and the
    // report the stack was for is dropped too (V8InspectorImpl::
    // exceptionThrown returns 0 for group 0, v8-inspector-impl.cc:379). The
    // realm is the current one (protocol_agents.onPromiseReject), the
    // context V8 asks about, and every registration goes through
    // Inspector.register. Blink's V8Initializer::PromiseRejectHandler
    // captures at every rejection because every Blink context is in a group
    // (MainThreadDebugger::ContextCreated); a Browser with no session
    // registers none. Read first from the realm itself, with no lock
    // (WrapperCache.inspector_registrations): finding the agent's inspector
    // is the agent registry's locked lookup (protocol_agents.recordOf,
    // about 127 ns), which every unhandled rejection paid for nothing (lane
    // tpc cost pairs: promises.unhandled 1.049x time before the guard, 1.039x
    // with the guard behind that lookup).
    if (!mayBeRegistered(realm)) return null;
    const inspector = existingOfRealm(realm) orelse return null;
    if (inspector.ended) return null;
    if (inspector.registeredOf(realm) == null) return null;
    inspector.capture_asks += 1;
    const native = ffi.v8_Inspector_CaptureStack(inspector.native) orelse return null;
    const captured = realm.allocator.create(CapturedStack) catch {
        ffi.v8_InspectorStack_Delete(native);
        return null;
    };
    captured.* = .{ .allocator = realm.allocator, .native = native };
    return @ptrCast(captured);
}

/// engine.inspectorReleaseStack.
pub fn inspectorReleaseStack(stack: *engine.InspectorStack) void {
    const captured: *CapturedStack = @ptrCast(@alignCast(stack));
    ffi.v8_InspectorStack_Delete(captured.native);
    captured.allocator.destroy(captured);
}

/// engine.inspectorExceptionRevoked.
pub fn inspectorExceptionRevoked(realm: Context, exception_id: u32, message: []const u8) void {
    if (exception_id == 0) return;
    const inspector = existingOfRealm(realm) orelse return;
    if (inspector.ended) return;
    const entered = support.enter(realm) catch return;
    defer entered.leave();
    ffi.v8_Inspector_ExceptionRevoked(inspector.native, entered.context(), exception_id, message.ptr, message.len);
}

/// engine.inspectorStackTrace.
pub fn inspectorStackTrace(agent: *engine.Agent, max_frames: u32, allocator: std.mem.Allocator) Error!?[]u8 {
    const inspector = protocol_agents.existingInspectorOf(isolateOfAgent(agent)) orelse return null;
    if (inspector.ended) return null;
    var captured: Captured = .{ .allocator = allocator };
    if (!ffi.v8_Inspector_StackTrace(inspector.native, max_frames, Captured.sink, &captured)) {
        if (captured.bytes) |bytes| allocator.free(bytes);
        return null;
    }
    if (captured.failed) return error.OutOfMemory;
    return captured.bytes;
}

// ============================================================================
// The console's REPL (protocol_repl.zig)
// ============================================================================

/// The context id and group the console evaluates `realm` in: the host's
/// registration when the realm has one, else the console's own group's,
/// made now (named "crane-console", as before the fold).
pub fn replContextOf(inspector: *Inspector, realm: Context) Error!struct { id: c_int, group: c_int } {
    if (inspector.registeredOf(realm)) |registered| return .{ .id = registered.id, .group = registered.group };
    const id = try inspector.register(.{ .realm = realm, .group = repl_group, .name = "crane-console" });
    return .{ .id = id, .group = repl_group };
}
