//! Implementation for History interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-history-interface
//!
//! A History reads and changes the session history of its window's
//! navigable's traversable (`html_core` JointHistory, kept on the top-level
//! BrowsingContext): length and index from the traversable's used steps,
//! state from the navigable's current entry, pushState/replaceState as "the
//! URL and history update steps", and back/forward/go as "traverse the
//! history by a delta".
//!
//! Traversal runs here: every navigable of the traversable whose entry at the
//! target step differs from its current one changes. One that stays on its
//! document - a pushState or fragment entry - has its URL and state restored
//! and hears popstate (and hashchange); one that changes documents is
//! navigated to its entry's URL by the navigation engine
//! (dom.navigables.traverseNavigable), since Crane keeps no document for
//! traversal (no bfcache).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const History = interfaces.History;
const html_core = @import("html_core");
const BrowsingContext = html_core.window.BrowsingContext;
const joint_history = html_core.navigation.joint_history;
const navigate_steps = html_core.navigation.navigate_steps;
const basic_parser = @import("basic_parser");
const url_serializer = @import("url_serializer");

pub const State = History.State;

pub const ImplError = error{
    NotImplemented,
    SecurityError,
    InvalidStateError,
    DataCloneError,
    OutOfMemory,
};

/// Internal state for History implementation
pub const InternalState = struct {
    /// Allocator for history resources
    allocator: Allocator,

    /// The window whose History this is.
    window: ?*runtime.Instance = null,

    /// That window's navigable, when the window was made for it.
    browsing_context: ?*BrowsingContext = null,

    /// history.state for the entry it was deserialized from: HTML "restore
    /// the history object state" keeps one value per entry, so reading it
    /// twice gives the same object.
    state_entry: u64 = 0,
    state_value: ?runtime.JSValue = null,
    /// Every deserialized state's Global, released with the History: an
    /// event or script may hold one past the entry that made it.
    state_handles: std.ArrayListUnmanaged(*anyopaque) = .empty,

    pub fn deinit(self: *InternalState) void {
        const v8 = @import("v8");
        for (self.state_handles.items) |handle| v8.ffi.v8_Global_Dispose(@ptrCast(@alignCast(handle)));
        self.state_handles.deinit(self.allocator);
    }
};

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    // Initialize internal state
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .allocator = allocator,
    };

    // Store internal state
    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const instance_lifecycle = @import("runtime").instance_lifecycle;
    const is_first = instance_lifecycle.markCleanupStarted(instance);

    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }

    if (is_first) {
        instance_lifecycle.markCleanupComplete(instance);
    }
}

// =============================================================================
// The navigable, its document and its traversable's history
// =============================================================================

/// The History's navigable, when its document is fully active: the window is
/// still the navigable's active window.
fn activeNavigable(internal: *InternalState) ?*BrowsingContext {
    const bc = internal.browsing_context orelse return null;
    const window = internal.window orelse return null;
    if (bc.getActiveWindow() != @as(?*anyopaque, @ptrCast(window))) return null;
    return bc;
}

/// The URL of `document`, owned by `allocator`; "about:blank" when it has
/// none.
fn documentUrl(document: *runtime.Instance, allocator: Allocator) ![]u8 {
    const url = interfaces.Document.get_URL(document) catch return allocator.dupe(u8, "about:blank");
    defer document.ctx.allocator.free(url);
    return allocator.dupe(u8, if (url.len == 0) "about:blank" else url);
}

/// BrowsingContext.ensureHistoryEntries's `url_of`.
fn documentUrlOf(document: *anyopaque, allocator: Allocator) anyerror![]u8 {
    return documentUrl(@ptrCast(@alignCast(document)), allocator);
}

/// The traversable's history, with entries for `bc` and its ancestors.
fn ensureEntries(bc: *BrowsingContext) !*joint_history.JointHistory {
    return bc.ensureHistoryEntries(&documentUrlOf);
}

// =============================================================================
// Property Getters/Setters
// =============================================================================

/// Getter for length: "1. If this's relevant global object's associated
/// Document is not fully active, then throw a SecurityError DOMException.
/// 2. Return this's length."
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const bc = activeNavigable(internal) orelse return error.SecurityError;
    const history = try ensureEntries(bc);
    return history.lengthAndIndex().length;
}

/// Getter for scrollRestoration: the active entry's scroll restoration mode.
pub fn get_scrollRestoration(instance: *runtime.Instance) anyerror!enums.ScrollRestoration {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const bc = activeNavigable(internal) orelse return error.SecurityError;
    const history = try ensureEntries(bc);
    const entry = history.currentEntry(bc.id) orelse return ._auto_;
    return if (entry.scroll_restoration_manual) ._manual_ else ._auto_;
}

/// Setter for scrollRestoration: sets the active entry's mode.
pub fn set_scrollRestoration(instance: *runtime.Instance, value: enums.ScrollRestoration) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const bc = activeNavigable(internal) orelse return error.SecurityError;
    const history = try ensureEntries(bc);
    const entry = history.currentEntry(bc.id) orelse return;
    entry.scroll_restoration_manual = value == ._manual_;
}

/// Getter for state: "1. If this's relevant global object's associated
/// Document is not fully active, then throw a SecurityError DOMException.
/// 2. Return this's state" - the navigable's current entry's classic history
/// API state, deserialized once per entry.
pub fn get_state(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const bc = activeNavigable(internal) orelse return error.SecurityError;
    const history = try ensureEntries(bc);
    const entry = history.currentEntry(bc.id) orelse return runtime.JSValue.jsNull;
    return stateValue(internal, entry);
}

/// The deserialized state of `entry`, cached for as long as it is the entry.
fn stateValue(internal: *InternalState, entry: *joint_history.Entry) !runtime.JSValue {
    if (internal.state_value) |value| {
        if (internal.state_entry == entry.id) return value;
    }
    const value = try deserialize(internal, entry.state);
    internal.state_entry = entry.id;
    internal.state_value = value;
    return value;
}

// =============================================================================
// StructuredSerializeForStorage / StructuredDeserialize
// =============================================================================

/// StructuredSerializeForStorage(`value`): a primitive or string as it is,
/// an object through V8's serializer (which throws the DataCloneError).
fn serialize(allocator: Allocator, value: runtime.JSValue) !joint_history.SerializedState {
    return switch (value) {
        .undefined => .undefined,
        .null => .null,
        .boolean => |b| .{ .boolean = b },
        .number => |n| .{ .number = n },
        .string => |s| .{ .string = try allocator.dupe(u8, s.data) },
        .handle => |h| blk: {
            const v8 = @import("v8");
            var no_transfer: [1]*v8.ffi.Value = undefined;
            var no_buffers: [1]v8.ffi.ArrayBufferTransferData = undefined;
            var size: usize = 0;
            var code: c_int = 0;
            const bytes = v8.ffi.v8_Value_StructuredSerializeWithTransfer(
                @ptrCast(@alignCast(h.ptr)),
                &no_transfer,
                0,
                &size,
                &no_buffers,
                &code,
            ) orelse return if (code == 3) error.ExceptionPending else error.DataCloneError;
            defer v8.ffi.v8_Free_SerializedBuffer(bytes);
            break :blk .{ .bytes = try allocator.dupe(u8, bytes[0..size]) };
        },
        // A platform object the binding handed over unwrapped: none is
        // [Serializable] here yet.
        .instance => error.DataCloneError,
    };
}

/// StructuredDeserialize(`state`) in the current realm. An object's Global
/// is kept by the History (`state_handles`); a string is copied.
fn deserialize(internal: *InternalState, state: joint_history.SerializedState) !runtime.JSValue {
    return switch (state) {
        .undefined => runtime.JSValue.jsUndefined,
        .null => runtime.JSValue.jsNull,
        .boolean => |b| runtime.JSValue.fromBoolean(b),
        .number => |n| runtime.JSValue.fromNumber(n),
        .string => |s| .{ .string = .{ .data = s, .owned = false } },
        .bytes => |b| blk: {
            const v8 = @import("v8");
            const no_buffers: [1]v8.ffi.ArrayBufferTransferData = undefined;
            var code: c_int = 0;
            const value = v8.ffi.v8_Value_DeserializeWithTransfer_CrossIsolate(b.ptr, b.len, &no_buffers, 0, &code) orelse
                return error.DataCloneError;
            internal.state_handles.append(internal.allocator, @ptrCast(value)) catch {
                v8.ffi.v8_Global_Dispose(value);
                return error.OutOfMemory;
            };
            break :blk runtime.JSValue.fromHandleNonOwning(@ptrCast(value));
        },
    };
}

// =============================================================================
// Navigation Methods
// =============================================================================

/// Operation: go
/// HTML: "1. Let document be this's associated Document. 2. If document is
/// not fully active, then throw a SecurityError DOMException. 3. If delta is
/// 0, then reload document's node navigable, and return. 4. Traverse the
/// history by a delta given document's node navigable's traversable
/// navigable, delta, and with sourceDocument set to document."
pub fn call_go(instance: *runtime.Instance, delta: webidl.Opt(i32)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const bc = activeNavigable(internal) orelse return error.SecurityError;
    const delta_val: i32 = if (delta.wasPassed()) delta.getValue() else 0;
    if (delta_val == 0) {
        // Step 3: "reload document's node navigable" - its current entry,
        // repopulated from the entry's URL: a traversal of the navigable to
        // the entry it is on. Reload step 1: not while unloading. A
        // navigable the engine has no navigation for - the top-level page -
        // is not reloaded, stated.
        const window = internal.window orelse return;
        const document = try interfaces.Window.get_document(window);
        if (@import("dom").document_lifecycle.isUnloading(document)) return;
        const history = try ensureEntries(bc);
        const entry = history.currentEntry(bc.id) orelse return;
        @import("dom").navigables.traverseNavigable(@ptrCast(bc), entry.id, entry.url, entry.resource);
        return;
    }
    queueTraversal(internal, bc.getTop(), delta_val);
}

/// Operation: back - "go(-1)".
pub fn call_back(instance: *runtime.Instance) anyerror!void {
    return call_go(instance, webidl.Opt(i32).passed(-1));
}

/// Operation: forward - "go(1)".
pub fn call_forward(instance: *runtime.Instance) anyerror!void {
    return call_go(instance, webidl.Opt(i32).passed(1));
}

/// Operation: pushState
pub fn call_pushState(instance: *runtime.Instance, data: runtime.JSValue, unused: runtime.DOMString, url: webidl.Opt(?runtime.USVString)) anyerror!void {
    _ = unused;
    return sharedPushReplaceState(instance, data, url, .push);
}

/// Operation: replaceState
pub fn call_replaceState(instance: *runtime.Instance, data: runtime.JSValue, unused: runtime.DOMString, url: webidl.Opt(?runtime.USVString)) anyerror!void {
    _ = unused;
    return sharedPushReplaceState(instance, data, url, .replace);
}

/// HTML "shared history push/replace state steps". Not modelled, stated: the
/// navigate event (step 5) and rate limiting (step 2).
fn sharedPushReplaceState(instance: *runtime.Instance, data: runtime.JSValue, url: webidl.Opt(?runtime.USVString), handling: joint_history.HistoryHandling) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "Let document be history's associated Document. If document is
    // not fully active, then throw a SecurityError DOMException."
    const bc = activeNavigable(internal) orelse return error.SecurityError;
    const window = internal.window orelse return error.SecurityError;
    const document = try interfaces.Window.get_document(window);
    const allocator = internal.allocator;

    // Step 3: "Let serializedData be StructuredSerializeForStorage(data)."
    var serialized = try serialize(allocator, data);
    errdefer serialized.deinit(allocator);

    // Step 4: "Let newURL be document's URL."
    const document_url = try documentUrl(document, allocator);
    defer allocator.free(document_url);
    var new_url: []u8 = try allocator.dupe(u8, document_url);
    defer allocator.free(new_url);

    // Step 5: "If url is not null or the empty string" - parse it relative to
    // the relevant settings object; failure, or a URL document's URL cannot
    // be rewritten to, is a SecurityError.
    if (url.wasPassed()) {
        if (url.getValue()) |given| {
            if (given.len > 0) {
                const parsed = try parseRelativeTo(document, given, allocator);
                if (!canHaveUrlRewritten(allocator, document_url, parsed)) {
                    allocator.free(parsed);
                    return error.SecurityError;
                }
                allocator.free(new_url);
                new_url = parsed;
            }
        }
    }

    // Step 8: "Run the URL and history update steps given document and
    // newURL, with serializedData set to serializedData and historyHandling
    // set to historyHandling."
    try urlAndHistoryUpdate(internal, bc, window, new_url, serialized, handling);
}

/// `url` parsed relative to `document`'s base URL and serialized; owned.
fn parseRelativeTo(document: *runtime.Instance, url: []const u8, allocator: Allocator) ![]u8 {
    const base = interfaces.Node.get_baseURI(document) catch "";
    defer if (base.len > 0) document.ctx.allocator.free(base);
    var base_record = if (base.len > 0) basic_parser.parse(allocator, base, null) catch null else null;
    defer if (base_record) |*b| b.deinit();
    var parsed = basic_parser.parse(allocator, url, if (base_record) |*b| b else null) catch return error.SecurityError;
    defer parsed.deinit();
    return @constCast(try url_serializer.serialize(allocator, &parsed, false));
}

/// HTML "can have its URL rewritten": the target differs from the document's
/// URL only in path, query or fragment - and for a file: URL only in query or
/// fragment; for anything else but HTTP(S), only in fragment.
fn canHaveUrlRewritten(allocator: Allocator, document_url: []const u8, target_url: []const u8) bool {
    var doc = basic_parser.parse(allocator, document_url, null) catch return false;
    defer doc.deinit();
    var target = basic_parser.parse(allocator, target_url, null) catch return false;
    defer target.deinit();
    // Step 2: scheme, username, password, host and port.
    if (!std.mem.eql(u8, doc.scheme(), target.scheme())) return false;
    const doc_origin = originPart(document_url);
    const target_origin = originPart(target_url);
    if (!std.mem.eql(u8, doc_origin, target_origin)) return false;
    // Step 3: HTTP(S) may change path and query.
    const scheme = target.scheme();
    if (std.mem.eql(u8, scheme, "http") or std.mem.eql(u8, scheme, "https")) return true;
    // Step 4: file: may not change its path.
    if (std.mem.eql(u8, scheme, "file")) {
        return std.mem.eql(u8, pathPart(document_url), pathPart(target_url));
    }
    // Step 5: anything else may change only its fragment.
    return std.mem.eql(u8, navigate_steps.withoutFragment(document_url), navigate_steps.withoutFragment(target_url));
}

/// The scheme and authority of a serialized URL: everything before the path.
fn originPart(url: []const u8) []const u8 {
    const colon = std.mem.indexOfScalar(u8, url, ':') orelse return url;
    if (!std.mem.startsWith(u8, url[colon..], "://")) return url[0 .. colon + 1];
    const path = std.mem.indexOfAnyPos(u8, url, colon + 3, "/?#") orelse url.len;
    return url[0..path];
}

/// The path of a serialized URL: from the authority to the query or fragment.
fn pathPart(url: []const u8) []const u8 {
    const start = originPart(url).len;
    const end = std.mem.indexOfAnyPos(u8, url, start, "?#") orelse url.len;
    return url[start..end];
}

/// HTML "URL and history update steps" given the History's document and
/// `new_url`, taking `serialized`. The document's URL changes now; the entry
/// is pushed or replaced in the traversable's history. Step 3 - the initial
/// about:blank document always replaces - is the joint history's "replace"
/// of the navigable's only entry.
fn urlAndHistoryUpdate(
    internal: *InternalState,
    bc: *BrowsingContext,
    window: *runtime.Instance,
    new_url: []const u8,
    serialized: joint_history.SerializedState,
    handling: joint_history.HistoryHandling,
) !void {
    const history = try ensureEntries(bc);
    try history.commitSameDocument(bc.id, new_url, serialized, handling);
    // Step 7: "Restore the history object state" - the next read deserializes
    // the new entry's state.
    internal.state_value = null;
    // Step 8: "Set document's URL to newURL."
    setDocumentUrl(window, new_url);
}

/// Set the URL of `window`'s associated Document - which its context's
/// record holds, and its Location reads.
fn setDocumentUrl(window: *runtime.Instance, url: []const u8) void {
    const v8 = @import("v8");
    const engine_ctx = window.ctx.engine_ctx orelse return;
    v8.context_manager.setDocumentUrl(@ptrCast(@alignCast(engine_ctx)), url) catch {};
}

// =============================================================================
// Traversal
// =============================================================================

/// A traversal waiting on the traversable's session history traversal queue.
const Traversal = struct {
    top_id: u64,
    delta: i32,
    allocator: Allocator,
};

/// "Traverse the history by a delta": append session history traversal
/// steps - a task, here - that apply the step `delta` away.
fn queueTraversal(internal: *InternalState, top: *BrowsingContext, delta: i32) void {
    const window = internal.window orelse return;
    const task = internal.allocator.create(Traversal) catch return;
    task.* = .{ .top_id = top.id, .delta = delta, .allocator = internal.allocator };
    const loop = window.ctx.getOptionalEventLoop() orelse return runTraversal(task);
    loop.queueTask(.{ .callback = &runTraversal, .context = task, .drop = &dropTraversal });
}

fn dropTraversal(context: ?*anyopaque) void {
    const task: *Traversal = @ptrCast(@alignCast(context orelse return));
    task.allocator.destroy(task);
}

/// A navigable that changes entry in a traversal.
const Change = struct {
    navigable: *BrowsingContext,
    old_url: []u8,
    target_entry: u64,
    same_document: bool,
};

/// "Apply the traverse history step" (HTML 7.4.6), without bfcache: every
/// navigable whose target entry differs from its current one changes -
/// within its document when the entry shares the document state, else by a
/// navigation to the entry's URL. A navigable under one that changes
/// documents is not looked at: it goes with its parent's document.
/// Not modelled, stated: beforeunload across the traversal and the navigate
/// event (steps 3, 5, 12.7).
fn runTraversal(context: ?*anyopaque) void {
    const task: *Traversal = @ptrCast(@alignCast(context orelse return));
    const allocator = task.allocator;
    defer allocator.destroy(task);

    const top = BrowsingContext.byId(task.top_id) orelse return;
    var tree: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
    defer tree.deinit(allocator);
    top.collectDescendants(allocator, &tree) catch return;

    const history = top.jointHistory() catch return;
    for (tree.items) |bc| _ = ensureEntries(bc) catch {};

    // Steps 2-4: the target step.
    const target = history.stepByDelta(task.delta) orelse return;

    // Step 6: the navigables that change, parents first.
    var changes: std.ArrayListUnmanaged(Change) = .empty;
    defer {
        for (changes.items) |c| allocator.free(c.old_url);
        changes.deinit(allocator);
    }
    var skipped: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
    defer skipped.deinit(allocator);
    for (tree.items) |bc| {
        if (bc.parent) |parent| {
            if (std.mem.indexOfScalar(*BrowsingContext, skipped.items, parent) != null) {
                skipped.append(allocator, bc) catch return;
                continue;
            }
        }
        const current = history.currentEntry(bc.id) orelse continue;
        const target_entry = history.entryAt(bc.id, target) orelse continue;
        if (current == target_entry) continue;
        const same_document = current.document_state == target_entry.document_state and
            target_entry.document != null and target_entry.document == bc.getActiveDocument();
        const old_url = allocator.dupe(u8, current.url) catch return;
        changes.append(allocator, .{
            .navigable = bc,
            .old_url = old_url,
            .target_entry = target_entry.id,
            .same_document = same_document,
        }) catch {
            allocator.free(old_url);
            return;
        };
        if (!same_document) skipped.append(allocator, bc) catch return;
    }

    // Step 20: the traversable's current session history step.
    history.current_step = target;

    for (changes.items) |change| {
        const entry = history.entryById(change.target_entry) orelse continue;
        if (change.same_document) {
            sameDocumentTraversal(change.navigable, change.old_url, entry);
        } else {
            @import("dom").navigables.traverseNavigable(@ptrCast(change.navigable), entry.id, entry.url, entry.resource);
        }
    }
}

/// "Update document for history step application" for a same-document
/// entry (step 6): the document's URL becomes the entry's, history.state its
/// state, and popstate fires at the window - then hashchange, as a task, if
/// the fragment changed.
fn sameDocumentTraversal(bc: *BrowsingContext, old_url: []const u8, entry: *joint_history.Entry) void {
    const window: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveWindow() orelse return));
    const history_instance = interfaces.Window.get_history(window) catch return;
    const internal = getInternal(history_instance) orelse return;
    const scope = @import("v8").JsScope.init(window.ctx) orelse return;
    defer scope.deinit();

    // Copied: popstate's handlers can push entries, which moves them.
    const allocator = internal.allocator;
    const new_url = allocator.dupe(u8, entry.url) catch return;
    defer allocator.free(new_url);

    setDocumentUrl(window, new_url);
    // 6.3: "Restore the history object state given document and entry."
    internal.state_value = null;
    const state = stateValue(internal, entry) catch runtime.JSValue.jsNull;
    // 6.4.3: popstate, with the state.
    const event = interfaces.PopStateEvent.call_constructor(
        window.ctx,
        runtime.DOMString.initInterned("popstate"),
        webidl.Opt(dictionaries.PopStateEventInit).passed(.{ .base = .{}, .state = state }),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = @import("dom").fire_event.dispatchTrusted(window, event) catch {};
    event.releaseIfUnwrapped(generation);

    // 6.4.5: hashchange, when the fragment changed.
    const old_fragment = navigate_steps.fragmentOf(old_url) orelse "";
    const new_fragment = navigate_steps.fragmentOf(new_url) orelse "";
    if (!std.mem.eql(u8, old_fragment, new_fragment)) queueHashChange(window, old_url, new_url);
}

/// A queued hashchange at a window, held with its slab generation.
const HashChange = struct {
    window: *runtime.Instance,
    generation: u64,
    old_url: []u8,
    new_url: []u8,
    allocator: Allocator,

    fn destroy(self: *HashChange) void {
        self.allocator.free(self.old_url);
        self.allocator.free(self.new_url);
        self.allocator.destroy(self);
    }
};

fn queueHashChange(window: *runtime.Instance, old_url: []const u8, new_url: []const u8) void {
    const allocator = window.ctx.allocator;
    const task = allocator.create(HashChange) catch return;
    const old_copy = allocator.dupe(u8, old_url) catch {
        allocator.destroy(task);
        return;
    };
    const new_copy = allocator.dupe(u8, new_url) catch {
        allocator.free(old_copy);
        allocator.destroy(task);
        return;
    };
    task.* = .{
        .window = window,
        .generation = runtime.SlabAllocator.generationOf(window),
        .old_url = old_copy,
        .new_url = new_copy,
        .allocator = allocator,
    };
    const loop = window.ctx.getOptionalEventLoop() orelse return runHashChange(task);
    loop.queueTask(.{ .callback = &runHashChange, .context = task, .drop = &dropHashChange });
}

fn dropHashChange(context: ?*anyopaque) void {
    const task: *HashChange = @ptrCast(@alignCast(context orelse return));
    task.destroy();
}

fn runHashChange(context: ?*anyopaque) void {
    const task: *HashChange = @ptrCast(@alignCast(context orelse return));
    defer task.destroy();
    if (runtime.SlabAllocator.generationOf(task.window) != task.generation) return;
    const scope = @import("v8").JsScope.init(task.window.ctx) orelse return;
    defer scope.deinit();
    const event = interfaces.HashChangeEvent.call_constructor(
        task.window.ctx,
        runtime.DOMString.initInterned("hashchange"),
        webidl.Opt(dictionaries.HashChangeEventInit).passed(.{ .base = .{}, .oldURL = task.old_url, .newURL = task.new_url }),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = @import("dom").fire_event.dispatchTrusted(task.window, event) catch {};
    event.releaseIfUnwrapped(generation);
}
