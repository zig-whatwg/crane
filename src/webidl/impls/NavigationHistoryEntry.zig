//! Implementation for NavigationHistoryEntry interface
//!
//! HTML Standard §7.2.6.5 - The NavigationHistoryEntry interface
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-navigationhistoryentry-interface
//!
//! A NavigationHistoryEntry stands for one session history entry of its
//! window's navigable (html_core JointHistory), which it names by the entry's
//! id. The entry's navigation API key and ID and its URL are recorded when
//! the object is made - a session history entry never changes them, and an
//! entry a "replace" or a pruning disposes of is gone from the history while
//! this object can still be read. The navigation API state is read live:
//! updateCurrentEntry() changes it in place.
//!
//! Its window is held by address and slab generation: script can keep an
//! entry after its window is gone, and every getter then answers as for a
//! document that is not fully active.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigationHistoryEntry = interfaces.NavigationHistoryEntry;
const EventTargetImpl = @import("EventTarget.zig");
const navigation_entries = @import("navigation_entries.zig");
const engine = @import("engine");
const joint_history = @import("html_core").navigation.joint_history;

pub const State = NavigationHistoryEntry.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

pub const InternalState = struct {
    allocator: Allocator,
    /// The relevant global object - the Window whose navigation API made
    /// this - and its slab generation.
    window: ?*runtime.Instance = null,
    window_generation: u64 = 0,
    /// The session history entry: its id in the traversable's history.
    entry_id: u64 = 0,
    /// What the entry had when this was made.
    key: [36]u8 = undefined,
    id: [36]u8 = undefined,
    url: []u8 = &.{},
    document: ?*anyopaque = null,
    /// The entry's document hid its URL when it left (joint_history
    /// Entry.protect_url).
    protect_url: bool = false,

    fn deinit(self: *InternalState) void {
        self.allocator.free(self.url);
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    @import("dom").navigation_history_entries.install(.{ .create = &createForEntry, .entry_id = &entryIdOf });
}

/// Initialize instance (creates the instance): an EventTarget, which the
/// dispose event is fired at.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try EventTargetImpl.init(allocator, StateType, vtable, ctx);
    errdefer EventTargetImpl.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    EventTargetImpl.deinit(instance);
}

/// dom.navigation_history_entries: a new NavigationHistoryEntry in
/// `window`'s realm for `entry_ptr`, a session history entry of `window`'s
/// navigable. For the navigation API, which keeps the object.
fn createForEntry(window: *runtime.Instance, entry_ptr: *const anyopaque) anyerror!*runtime.Instance {
    const entry: *const joint_history.Entry = @ptrCast(@alignCast(entry_ptr));
    const instance = try interfaces.NavigationHistoryEntry.init(window.ctx.allocator, window.ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.url = try internal.allocator.dupe(u8, entry.url);
    internal.window = window;
    internal.window_generation = runtime.SlabAllocator.generationOf(window);
    internal.entry_id = entry.id;
    internal.key = entry.api_key;
    internal.id = entry.api_id;
    internal.document = entry.document;
    internal.protect_url = entry.protect_url;
    return instance;
}

/// dom.navigation_history_entries: the session history entry id this
/// object stands for.
fn entryIdOf(instance: *runtime.Instance) u64 {
    const internal = getInternal(instance) orelse return 0;
    return internal.entry_id;
}

/// The window's scope, when its document is fully active.
fn scopeOf(internal: *InternalState) ?navigation_entries.Scope {
    const window = internal.window orelse return null;
    return navigation_entries.scopeOf(window, internal.window_generation);
}

// ============================================================================
// Attributes
// ============================================================================

/// "1. Let document be this's relevant global object's associated Document.
/// 2. If document is not fully active, then return the empty string. 3. Let
/// she be this's session history entry. 4. If she's document does not equal
/// document, and she's document state's request referrer policy is
/// "no-referrer" or "origin", then return null. 5. Return she's URL,
/// serialized."
///
/// Deviation from the spec text in step 4, stated (golden rule 2): the
/// policy read is not the document state's request referrer policy but
/// she's document's own referrer policy as it stood when that document
/// left - which a meta referrer element can change after load - as Chrome
/// and Safari do. Evidence and engine code: joint_history
/// forgetDocumentWithPolicy, which records it.
pub fn get_url(instance: *runtime.Instance) anyerror!?runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 2.
    const scope = scopeOf(internal) orelse return try instance.ctx.allocator.dupe(u8, "");
    // Step 4. The entry is read as the history has it now, while it is
    // there: this object may have been made before its document left.
    const live = scope.history.entryById(internal.entry_id);
    const she_document = if (live) |entry| entry.document else internal.document;
    const protect_url = if (live) |entry| entry.protect_url else internal.protect_url;
    const same_document = if (she_document) |d| d == @as(*anyopaque, @ptrCast(scope.document)) else false;
    if (!same_document and protect_url) return null;
    // Step 5.
    return try instance.ctx.allocator.dupe(u8, internal.url);
}

/// The key: "" when the document is not fully active, else the session
/// history entry's navigation API key.
pub fn get_key(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (scopeOf(internal) == null) return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, &internal.key);
}

/// The ID: "" when the document is not fully active, else the session
/// history entry's navigation API ID.
pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (scopeOf(internal) == null) return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, &internal.id);
}

/// The index: −1 when the document is not fully active; else "getting the
/// navigation API entry index" of the session history entry within the
/// navigation API - its position among entries(), or −1 when it is not
/// there (disposed, or entries and events are disabled).
pub fn get_index(instance: *runtime.Instance) anyerror!i64 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const scope = scopeOf(internal) orelse return -1;
    if (navigation_entries.disabled(scope)) return -1;
    var entries: std.ArrayListUnmanaged(*joint_history.Entry) = .empty;
    defer entries.deinit(internal.allocator);
    _ = scope.history.apiEntries(scope.navigable.id, internal.allocator, &entries) catch return -1;
    for (entries.items, 0..) |entry, i| {
        if (entry.id == internal.entry_id) return @intCast(i);
    }
    return -1;
}

/// "1. Let document be this's relevant global object's associated Document.
/// 2. If document is not fully active, then return false. 3. Return true if
/// this's session history entry's document equals document, and false
/// otherwise."
pub fn get_sameDocument(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const scope = scopeOf(internal) orelse return false;
    const document = internal.document orelse return false;
    return document == @as(*anyopaque, @ptrCast(scope.document));
}

/// Getter for ondispose
pub fn get_ondispose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "dispose");
}

/// Setter for ondispose
pub fn set_ondispose(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "dispose", value);
}

// ============================================================================
// Operations
// ============================================================================

/// "1. If this's relevant global object's associated Document is not fully
/// active, then return undefined. 2. Return StructuredDeserialize(this's
/// session history entry's navigation API state). Rethrow any exceptions."
/// An entry disposed of has no state left to read here, and answers
/// undefined.
pub fn call_getState(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const scope = scopeOf(internal) orelse return runtime.JSValue.jsUndefined;
    const entry = scope.history.entryById(internal.entry_id) orelse return runtime.JSValue.jsUndefined;
    // A fresh value each call, made in the current realm.
    return (try navigation_entries.deserialize(engine.currentRealm() orelse instance.ctx, entry.api_state)).take();
}
