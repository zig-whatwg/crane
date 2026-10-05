//! HTML §4.13.6: select the relevant agent and invoke its queued reactions.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const interfaces = @import("interfaces");
const core = @import("html_core");
const ce = dom.custom_elements;
pub const AgentState = ce.AgentState;
pub const Definition = ce.Definition;
pub const Reaction = ce.Reaction;
pub const CallbackType = ce.CallbackType;

pub fn stateForRealm(realm: runtime.Context) ?*AgentState {
    const agent = realm.agent orelse return null;
    const host: *core.agent_host.AgentHost = @ptrCast(@alignCast(engine.agentHost(agent) orelse return null));
    return &host.custom_elements;
}

pub fn hasDefinitions(realm: runtime.Context) bool {
    return (stateForRealm(realm) orelse return false).definition_count != 0;
}

pub fn pushConstructor(realm: runtime.Context, definition: *Definition) !*AgentState {
    const state = stateForRealm(realm) orelse return error.InvalidStateError;
    const registry = definition.registry orelse return error.InvalidStateError;
    const constructor = try engine.retainValue(realm, definition.constructor.function.value);
    errdefer constructor.release();
    const registry_root = try engine.retainValue(realm, .{ .instance = registry });
    errdefer registry_root.release();
    try state.pushConstructor(.{ .constructor = constructor, .registry = registry, .registry_root = registry_root, .realm = realm });
    return state;
}

pub fn activeRegistry(realm: runtime.Context, constructor: runtime.JSValue) ?*runtime.Instance {
    const state = stateForRealm(realm) orelse return null;
    var index = state.active_constructors.len;
    while (index != 0) {
        index -= 1;
        const entry = state.active_constructors.get(index).?;
        const held = entry.constructor orelse continue;
        if (engine.sameValue(realm, held.value, constructor)) return entry.registry;
    }
    return null;
}

fn relevantRealm(instance: ?*runtime.Instance) ?runtime.Context {
    return if (instance) |object| object.ctx else engine.currentRealm();
}

pub fn begin(instance: ?*runtime.Instance) void {
    const state = stateForRealm(relevantRealm(instance) orelse return) orelse return;
    state.begin();
}

pub fn end(instance: ?*runtime.Instance) void {
    const realm = relevantRealm(instance) orelse return;
    const state = stateForRealm(realm) orelse return;
    // [CEReactions] step 3 invokes even after abrupt completion. Empty queues
    // make no exception operation, which is the common no-definition path.
    if (!state.hasCurrentQueue()) {
        state.end({}, invokeReaction);
        return;
    }
    const pending = engine.takePendingException(realm) catch null;
    defer if (pending) |exception| exception.release();
    state.end({}, invokeReaction);
    if (pending) |exception| engine.throwValue(realm, exception.value) catch {};
}

fn acquireRoot(_: void, element: *runtime.Instance) !engine.Owned {
    return engine.retainValue(element.ctx, .{ .instance = element });
}

fn enqueue(state: *AgentState, element: *runtime.Instance, reaction: Reaction) !void {
    const schedule = try state.enqueue({}, element, element.ctx, reaction, acquireRoot);
    if (!schedule) return;
    const agent = element.ctx.agent orelse unreachable;
    engine.queueMicrotask(agent, runBackup, state) catch {
        // No microtask was accepted. Drop the queued work; it must not stay
        // held on a queue that no future checkpoint will visit.
        state.cancelBackup();
    };
}

fn runBackup(data: ?*anyopaque) void {
    const state: *AgentState = @ptrCast(@alignCast(data orelse return));
    state.invokeBackup({}, invokeReaction);
}

/// An Instance return is not a wrapper root. Bridge the owned constructor
/// result across CEReactions.end and the binding's return conversion. Takes
/// value on EVERY exit. A separate Owned cannot end a built-in's activity hold.
pub fn takeReturnedValue(realm: runtime.Context, value: engine.Owned) !void {
    var accepted = false;
    defer if (!accepted) value.release();
    const state = stateForRealm(realm) orelse return error.InvalidStateError;
    const agent = realm.agent orelse return error.InvalidStateError;
    const schedule = try state.returns.append(realm, value);
    accepted = true;
    if (schedule) engine.queueMicrotask(agent, releaseReturns, state) catch |err| {
        // No callback can release this list. Drop every accepted root now and
        // reject the operation instead of exposing an unrooted Instance result.
        state.returns.releaseAll();
        return err;
    };
}

fn releaseReturns(data: ?*anyopaque) void {
    const state: *AgentState = @ptrCast(@alignCast(data orelse return));
    state.returns.releaseAll();
}

pub fn clearRealm(realm: runtime.Context) void {
    const state = stateForRealm(realm) orelse return;
    state.clearRealm(realm);
}

pub fn clearElement(element: *runtime.Instance) void {
    const state = stateForRealm(element.ctx) orelse return;
    state.clearElement(element);
}

/// Mutation hooks enqueue callbacks only for custom elements. Upgrade's
/// pre-construction callbacks use enqueueCallback with the definition directly.
pub fn callbackFromMutation(element: *runtime.Instance, kind: CallbackType, args: Reaction.CallbackArgs) void {
    const data = ce.get(element) orelse return;
    if (data.state != .custom) return;
    enqueueCallback(element, data.definition orelse return, kind, args) catch {};
}

pub fn enqueueCallback(element: *runtime.Instance, definition: *Definition, kind: CallbackType, args: Reaction.CallbackArgs) !void {
    // Enqueue a callback reaction steps 1–2: select the callback, or for a
    // missing connectedMoveCallback enqueue disconnected then connected.
    if (kind == .connected_move and definition.lifecycle_callbacks.connectedMoveCallback == null) {
        try enqueueCallback(element, definition, .disconnected, .none);
        return enqueueCallback(element, definition, .connected, .none);
    }
    const callback = switch (kind) {
        .connected => definition.lifecycle_callbacks.connectedCallback,
        .disconnected => definition.lifecycle_callbacks.disconnectedCallback,
        .connected_move => definition.lifecycle_callbacks.connectedMoveCallback,
        .adopted => definition.lifecycle_callbacks.adoptedCallback,
        .attribute_changed => definition.lifecycle_callbacks.attributeChangedCallback,
        .form_associated => definition.lifecycle_callbacks.formAssociatedCallback,
        .form_reset => definition.lifecycle_callbacks.formResetCallback,
        .form_disabled => definition.lifecycle_callbacks.formDisabledCallback,
        .form_state_restore => definition.lifecycle_callbacks.formStateRestoreCallback,
    } orelse return;
    // Step 3: attributeChangedCallback observes local names, in every namespace.
    if (kind == .attribute_changed) {
        const attribute = args.attribute_changed;
        var observed = false;
        for (definition.observed_attributes) |name| {
            if (std.mem.eql(u8, name, attribute.local_name)) {
                observed = true;
                break;
            }
        }
        if (!observed) return;
    }
    const state = stateForRealm(element.ctx) orelse return;
    var reaction = try Reaction.initCallback(state.allocator, element.ctx, callback, kind, args);
    errdefer reaction.deinit();
    try enqueue(state, element, reaction);
}

pub fn enqueueUpgrade(element: *runtime.Instance, definition: *Definition) !void {
    const state = stateForRealm(element.ctx) orelse return;
    var reaction = try Reaction.initUpgrade(state.allocator, definition);
    errdefer reaction.deinit();
    try enqueue(state, element, reaction);
}

fn invokeReaction(_: void, element: *runtime.Instance, reaction: *Reaction) void {
    switch (reaction.reaction_type) {
        .upgrade => @import("../upgrade.zig").upgradeElement(element, reaction.definition orelse return),
        .callback => {
            const callback = reaction.callbackFunction() orelse return;
            var arguments: [4]runtime.JSValue = undefined;
            const args = switch (reaction.callback_args orelse .none) {
                .none => arguments[0..0],
                .adopted => |adopted| blk: {
                    arguments[0] = .{ .instance = adopted.old_document };
                    arguments[1] = .{ .instance = adopted.new_document };
                    break :blk arguments[0..2];
                },
                .attribute_changed => |attribute| blk: {
                    arguments = .{
                        runtime.JSValue.fromStringRef(attribute.local_name),
                        stringOrNull(attribute.old_value),
                        stringOrNull(attribute.new_value),
                        stringOrNull(attribute.namespace),
                    };
                    break :blk arguments[0..4];
                },
            };
            // Invoke reactions step 1.2.2: WebIDL invocation reports a callback
            // exception in its own realm and continues with the next reaction.
            const completion = engine.invokeCallbackFunction(element.ctx, callback, .{ .value = .{ .instance = element } }, args, .{
                .report = .{ .report = reportException, .host = element.ctx },
            }) catch return;
            switch (completion) {
                inline else => |value| value.release(),
            }
        },
    }
}

fn stringOrNull(value: ?[]const u8) runtime.JSValue {
    return if (value) |text| runtime.JSValue.fromStringRef(text) else .null;
}

pub fn reportException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const fallback: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse fallback;
    const record = realm.getRealm() orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("../report_exception.zig").reportErrorInfo(global, &extracted, .{});
}

pub fn reportThrown(realm: runtime.Context, value: runtime.JSValue) void {
    const allocator = realm.allocator;
    const info = engine.extractErrorInformation(realm, value, allocator) catch return;
    defer allocator.free(info.message);
    defer allocator.free(info.filename);
    reportException(realm, &info);
}
