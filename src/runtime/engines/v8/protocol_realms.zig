//! The engine protocol's realms on V8 (design 4.2): a Window's realm made and
//! ended, and the realms HTML names from the running script - entry,
//! incumbent - and ECMAScript's GetFunctionRealm.
//!
//! protocol.zig forwards these operations here. The host keeps the spec state
//! - the Window, its Document, its browsing context - and hands the engine the
//! Window through `create_global_object`; the engine makes the context, binds
//! the Window as its global object and gives it what a Window global has.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const context_manager = @import("context_manager.zig");
const interface_bindings = @import("interface_bindings.zig");
const window_properties = @import("window_properties.zig");
const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
const realm_v8 = @import("realm_v8.zig");
const realm_global = @import("realm_global.zig");
const template_registry = @import("template_registry.zig");
const page_realm = @import("page_realm.zig");
const protocol_agents = @import("protocol_agents.zig");
const support = @import("protocol_support.zig");
const conversions = @import("conversions.zig");
const namespaces = @import("namespaces");

const Context = engine.Context;
const JSValue = engine.JSValue;
const Error = engine.Error;

const log = std.log.scoped(.protocol_realms);

/// What the adapter keeps for a Window realm it made, until its end.
const WindowRealmState = struct {
    /// The agent - the isolate - and whether making the realm entered it.
    isolate: *ffi.Isolate,
    entered_isolate: bool,
    /// HTML IsPlatformObjectSameOrigin, as the host supplied it: asked by the
    /// access checks on this realm's WindowProxy and Locations
    /// (cross_origin.zig) on every access from another realm.
    is_platform_object_same_origin: ?*const fn (host: ?*anyopaque, current: Context, object: *engine.Instance) bool,
    /// HTML's access report check, as the host supplied it: asked by the
    /// bindings of this realm's Window (`reportWindowAccess`).
    report_window_access: ?*const fn (host: ?*anyopaque, accessor: Context, window: *engine.Instance, property: []const u8) void,
    host: ?*anyopaque,
    /// A later realm was built around this one's WindowProxy (a navigation
    /// that made a new Window): the proxy is that realm's now, so this one's
    /// end must not detach it again.
    window_proxy_handed_on: bool = false,
    /// The realm's context is entered for its life - until it ends, or until
    /// a realm that takes over its WindowProxy is entered in its place. Never
    /// for a realm with a parent (a frame's), which is made while its parent's
    /// script runs.
    context_entered: bool = true,
    /// The parent navigable's realm (WindowRealmOptions.parent), or null. A
    /// parentless (top-level) realm whose WindowProxy a later realm took over
    /// becomes that realm's child: its page is the later realm now, and it
    /// ends with it if the collector has not ended it first.
    parent: ?Context = null,
    /// An auxiliary navigable's realm (WindowRealmOptions.auxiliary): a realm
    /// built around its parent's WindowProxy adopts it.
    auxiliary: bool = false,
    /// The realm's Window is its page's top-level one - a top-level
    /// traversable's, an auxiliary one's included (a popup is the main frame
    /// of its own page) - never a child navigable's: Blink's
    /// LocalFrame::IsMainFrame. Fixed at the realm's making: a top-level
    /// realm a later realm adopts (`parent` is set then) stays one. It
    /// decides what the realm's end tells V8 (`endRealm` step 4).
    top_level: bool,
    /// The realms made with this one as their parent that have not ended:
    /// they end first when this one does.
    children: std.ArrayListUnmanaged(Context) = .empty,
    /// A realm made around this one's WindowProxy whose replacement has not
    /// committed yet: this realm's auxiliary children (window.open's popups)
    /// pass to it when this realm's document goes (`destroyWindowRealm`
    /// .global_detached, `passAuxiliaryChildren`), not when it is made - a
    /// navigation abandoned before its document exists ends only its new
    /// realm, and the popups stay with this one. Cleared when either ends.
    successor: ?Context = null,
    /// The realm whose WindowProxy this one was made around, while that
    /// realm's auxiliary children have not passed here yet (`successor`).
    predecessor: ?Context = null,
    /// Room in `children` kept, from this realm's making, for the
    /// predecessor's auxiliary children: an append of any other child
    /// leaves it, so their pass cannot fail.
    reserved_for_predecessor: usize = 0,
    /// The realm's Window, which the host made (create_global_object), and
    /// its slab generation then: the realm's end gives the Window's slot
    /// back only while it is still that Window's (`endRealm` step 5).
    window: ?*engine.Instance = null,
    window_generation: u64 = 0,
    /// The realm is detached (`detach`) - its navigable was destroyed, or a
    /// navigation replaced its document: it lives on for as long as script
    /// reaches it, and ends once the collector takes it.
    detached: ?*Detached = null,
    allocator: std.mem.Allocator,
};

/// What a Window realm whose navigable was destroyed keeps until its end
/// (`detach`). Its own allocation: the weak callback that announces the
/// collection, and the task that callback queues, hold it after the realm's
/// state may be gone.
const Detached = struct {
    realm: Context,
    /// The realm's context handle (`realm.engine_ctx` until the collection),
    /// weak since the detach, empty once collected. Disposed at the end.
    context: *ffi.Context,
    /// The context manager's key for the context, read while it lived.
    key: usize,
    /// A task to end the realm is queued (`realmCollected`); it frees this
    /// record when it runs or is dropped.
    task_queued: bool = false,
    /// The realm has ended - its page's end, or that task: only the record is
    /// left, for a task still queued.
    ended: bool = false,

    fn destroy(self: *Detached) void {
        std.heap.c_allocator.destroy(self);
    }
};

/// The private key of the array on a detached realm's retained store (the
/// store its global's GlobalAnchor traces, realm_global.retainedStore) that
/// keeps its callbacks (WrapperCache.detach keeps its wrappers in the same).
const retained_key = "crane:retained";

/// Whether `realm`'s navigable was destroyed, so its tasks are not run any
/// more (HTML "destroy a document" step 7: they are removed from the task
/// queues without running).
pub fn isDetached(realm: Context) bool {
    const state = stateOf(realm) orelse return false;
    return state.detached != null;
}

/// Whether `realm` is a frame's realm - made under a parent realm (an
/// iframe's, or a popup's under its opener's) - and not detached yet: the
/// realms whose document can be destroyed while they stay attached (a
/// removed frame's realm ends at a task of its own).
pub fn isAttachedFrame(realm: Context) bool {
    const state = stateOf(realm) orelse return false;
    return state.parent != null and state.detached == null;
}

/// The Window realms an agent made, by realm. Held on the agent's record
/// (protocol_agents.AgentRecord.window_realms) and freed with it, as Blink
/// keeps its per-isolate maps on V8PerIsolateData: it was a `threadlocal` on
/// c_allocator, whose entries every realm's end removed but whose capacity
/// nothing freed, so each thread that ever made a Window realm left its
/// storage behind when it ended (192 B a thread, Codex row 56's fresh-thread
/// test under leaks --atExit; docs/lessons/architecture-a-threadlocal-
/// container-outlives-its-thread-unless-its-capacity-goes.md). Read and
/// written on the agent's own thread only, as the record's other state is.
pub const WindowRealms = std.AutoHashMapUnmanaged(Context, *WindowRealmState);

/// The Window realms of the agent whose isolate this is; null for an isolate
/// createAgent did not make, which can make no Window realm.
fn realmsOfAgent(isolate: *ffi.Isolate) ?*WindowRealms {
    const record = protocol_agents.recordOf(isolate) orelse return null;
    return &record.window_realms;
}

/// The Window realms of `realm`'s agent.
fn realmsOf(realm: Context) ?*WindowRealms {
    const agent = realm.agent orelse return null;
    return realmsOfAgent(@ptrCast(@alignCast(agent)));
}

/// What the adapter keeps for `realm`, a Window realm it made and that has
/// not ended; null for any other realm.
fn stateOf(realm: Context) ?*WindowRealmState {
    const realms = realmsOf(realm) orelse return null;
    return realms.get(realm);
}

fn contextOf(realm: Context) ?*ffi.Context {
    const engine_ctx = realm.engine_ctx orelse return null;
    return @ptrCast(@alignCast(engine_ctx));
}

/// Whether `context` is the one most recently entered in `isolate`: V8 exits
/// contexts only in the reverse of the order they were entered.
fn isLastEntered(isolate: *ffi.Isolate, context: *ffi.Context) bool {
    const entered = ffi.v8_Isolate_GetEnteredOrMicrotaskContext(isolate) orelse return false;
    defer ffi.v8_Context_Dispose(entered);
    const address = ffi.v8_Context_GetRawAddress(context) orelse return false;
    return ffi.v8_Context_GetRawAddress(entered) == address;
}

/// The runtime realm a V8 context is, releasing the context handle.
fn realmOfOwnedContext(context: ?*ffi.Context) ?Context {
    const ctx = context orelse return null;
    defer ffi.v8_Context_Dispose(ctx);
    return context_manager.get(ctx);
}

// ============================================================================
// createWindowRealm / destroyWindowRealm
// ============================================================================

/// HTML "create a new realm" (8.1.3.3) with a Window global:
///
/// 1. InitializeHostDefinedRealm() with the host's customizations - the
///    global object is a new Window (`create_global_object`), the global this
///    binding the browsing context's WindowProxy (`global_this`: a new one,
///    or the one a navigation keeps). V8 makes both in Context::New /
///    Context::FromSnapshot; the Window is bound to the global after.
/// 2-4. The realm is the context's; V8 never leaves a realm execution context
///    on the stack for it.
/// 5. Deleting SharedArrayBuffer when the agent cluster's cross-origin
///    isolation mode is "none" is NOT performed: Crane has no agent clusters
///    yet, and V8 exposes SharedArrayBuffer as it always has here.
///
/// The realm's context stays entered for the realm's life, so it is made
/// with no script running in the agent - as HTML makes a Window's realm, from
/// a navigation's task: a context entered above a running script's would
/// have to be exited before that script's.
pub fn createWindowRealm(options: *const engine.WindowRealmOptions) Error!Context {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(options.agent));
    const allocator = options.allocator;
    // The agent keeps its Window realms (`WindowRealms`): one createAgent
    // made, as WindowRealmOptions.agent says.
    const realms = realmsOfAgent(isolate) orelse {
        log.warn("createWindowRealm: the agent was not made by createAgent; it has no record to keep its Window realms in", .{});
        return error.OperationFailed;
    };

    // The agent stays entered while its realm lives: the page's context is
    // entered for its whole life, and a context can be entered only in its
    // own isolate.
    const entered_isolate = ffi.v8_Isolate_GetCurrent() != isolate;
    if (entered_isolate) ffi.v8_Isolate_Enter(isolate);
    errdefer if (entered_isolate) ffi.v8_Isolate_Exit(isolate);

    // [reuse_window_proxy]: the WindowProxy of the realm this one replaces.
    // Blink's LocalWindowProxy::DisposeContext(kFrameWillBeReused): the proxy
    // is detached from the old context, then the new context is built around
    // it, so every reference to it - contentWindow, open()'s result - now
    // reaches the new Window. The old realm's end must then leave it alone.
    var reused_proxy: ?*ffi.Object = null;
    defer if (reused_proxy) |proxy| ffi.v8_Object_Dispose(proxy);
    // The realm whose WindowProxy this one takes over, while it is still a
    // Window realm made here: its auxiliary children follow the proxy, and a
    // parentless one becomes this realm's child (lane newwin1, E1/E2).
    var predecessor: ?*WindowRealmState = null;
    var predecessor_realm: ?Context = null;
    // A parentless predecessor's entries pass to this realm: its context's
    // (exited below, this one entered in its place) and its isolate's. Its
    // end must not exit the isolate under the realm that lives on.
    var takes_isolate_entry = false;
    var exited_predecessor: ?*ffi.Context = null;
    errdefer if (predecessor) |state| {
        // No realm was made: what was handed over goes back, so that the
        // predecessor's end balances them as before.
        if (takes_isolate_entry) state.entered_isolate = true;
        if (exited_predecessor) |old_context| {
            ffi.v8_Context_Enter(old_context);
            state.context_entered = true;
        }
    };
    // ORDER (lane v8up b3e): the hand-on below - handOn and Context::DetachGlobal of the old realm - comes
    // BEFORE every fallible step that follows (the context, the realm record, the host's Window, its
    // binding, the realm state and lists), because V8's Context::New / FromSnapshot take a global proxy only
    // once it is detached, and V8 has no API that attaches a global to a context again. So a failure after
    // this point (out of memory) leaves the old realm alive and its Window active - the host keeps them
    // (HTMLIFrameElement replaceRealm) - but its WindowProxy reaching no Window until the next realm made
    // around it: script sees a proxy with no global (member reads throw V8's TypeError "no access": a detached
    // proxy has no access-check info; the errdefer below detaches a failed context's global so that every failure
    // point leaves this one state). Failure-atomic creation (every
    // fallible allocation before the detach) is queued as its own realm-lifetime work (the v8up handoff).
    switch (options.global_this) {
        .new_window_proxy => {},
        .window_proxy_of => |old| {
            const old_context = contextOf(old) orelse return error.OperationFailed;
            reused_proxy = ffi.v8_Context_Global(old_context) orelse return error.OperationFailed;
            const old_state = realms.get(old);
            if (old_state == null or !old_state.?.window_proxy_handed_on) {
                // Blink LocalWindowProxy::DisposeContext
                // (kGlobalObjectIsDetached, local_window_proxy.cc 171-235):
                // step 2, the proxy's native info is cleared - the old
                // hidden global object keeps its GlobalAnchor, and through it
                // the old Window's retained store, for as long as anything of
                // the old realm lives (no handle to it is kept: V8 >= 14 has
                // none to give, crbug.com/333672197) - then step 4, the
                // detach. This realm's attach wraps the proxy anew.
                realm_global.handOn(old_context);
                ffi.v8_Context_DetachGlobal(old_context);
            }
            if (old_state) |state| {
                state.window_proxy_handed_on = true;
                predecessor = state;
                predecessor_realm = old;
                // The new realm is entered in the old one's place: V8 exits
                // contexts only in reverse order, and the old realm ends
                // while the new one lives.
                if (state.context_entered and isLastEntered(isolate, old_context)) {
                    ffi.v8_Context_Exit(old_context);
                    state.context_entered = false;
                    exited_predecessor = old_context;
                }
                // A top-level page's realm entered its isolate for its life:
                // that entry is the new realm's now. Left with the old realm,
                // its end - at collection, or a detach that could not be made
                // - would exit the isolate under the page that lives on.
                if (state.parent == null and state.entered_isolate) {
                    state.entered_isolate = false;
                    takes_isolate_entry = true;
                }
            }
        },
    }

    // The context: restored from the snapshot, whose global already has the
    // WebIDL interfaces (~2 ms), or made afresh with them defined below
    // (~40 ms) - always on an engine without snapshots.
    var restored = false;
    const context: *ffi.Context = blk: {
        if (options.from_snapshot and @import("protocol.zig").capabilities.restores_snapshots != .unsupported) {
            const made = if (reused_proxy) |proxy|
                ffi.v8_Context_NewFromSnapshotWithGlobal(isolate, proxy)
            else
                ffi.v8_Context_NewFromSnapshot(isolate);
            if (made) |c| {
                restored = true;
                break :blk c;
            }
            log.debug("the snapshot's context could not be made; building the realm afresh", .{});
        }
        // The global object is an instance of the Window interface object's
        // template, as the snapshot generator makes it: its [[Prototype]] is
        // Window.prototype from the start (WebIDL 3.8), its two internal
        // fields hold the Window and its type info, and it is immutable-
        // prototype - Object.setPrototypeOf(globalThis, {}) throws. Setting
        // the prototype afterwards cannot work: an immutable [[Prototype]]
        // refuses the change.
        const global_template = ffi.v8_FunctionTemplate_InstanceTemplate(windowTemplate(isolate));
        // The context keeps what it needs of the template; the handle is ours.
        defer ffi.v8_ObjectTemplate_Dispose(global_template);
        const made = if (reused_proxy) |proxy|
            ffi.v8_Context_NewWithGlobalTemplateAndProxy(isolate, global_template, proxy)
        else
            ffi.v8_Context_NewWithGlobalTemplate(isolate, global_template);
        break :blk made orelse return error.OperationFailed;
    };
    // Every realm keeps its own security token - V8's default, its global
    // object - frames included [cross_origin_objects]. V8 then asks the
    // access check (cross_origin.zig) on every access to this realm's
    // WindowProxy from another realm, and the check asks the host's
    // IsPlatformObjectSameOrigin each time. A shared token would let V8 skip
    // the check - an answer kept across document.domain changes - as a
    // frame once took its parent's.
    if (options.parent) |parent| _ = contextOf(parent) orelse return error.OperationFailed;
    // [code_generation_checks]: eval and Function in it reach the agent's
    // host, when the host checks them.
    @import("protocol_agents.zig").restrictCodeGenerationFromStrings(isolate, context);
    // WebAssembly constructors use NewTarget's realm for prototype fallback;
    // Memory/Table also adapt V8 13.1's old `index` descriptor spelling.
    ffi.v8_WebAssembly_InstallAddressDescriptors(isolate, context);
    // The page's context stays entered while it lives; destroyWindowRealm
    // exits it. A frame's is entered only while it is made (below).
    ffi.v8_Context_Enter(context);
    var registered = false;
    errdefer {
        if (registered) context_manager.removeContext(context);
        // A context made around the handed-on WindowProxy holds it: detach its global, so the proxy is
        // left with no global, as after the hand-on alone (the ORDER comment above), and script holding it
        // never reaches this half-made global, whose realm record is gone - a call into a binding there would
        // make platform objects in a realm no Browser owns. Blink: a failed LocalWindowProxy::Initialize
        // disposes the context it made, and DisposeContext detaches the global of a reused frame
        // (local_window_proxy.cc). Before this, a failure after the context was made left the proxy on the
        // half-made global: member reads gave undefined or a SecurityError, by how far the realm got
        // (iframe_policy_container_oom_test, failing allocation 144 on chat2 and 143 on server1).
        if (reused_proxy != null) ffi.v8_Context_DetachGlobal(context);
        ffi.v8_Context_Exit(context);
        ffi.v8_Context_Dispose(context);
    }

    // The runtime's realm for the context, recording the host's timers and
    // event loop (never run here), on the agent's record of its realms.
    const realm = context_manager.getOrCreateWithExternalEventLoop(context, options.timer, options.event_loop, allocator) catch
        return error.OperationFailed;
    registered = true;
    // The realm's Browser, before any platform object of it exists - its
    // Window comes from that Browser's slab and arena.
    realm.browser_scope = options.browser_scope;
    // HTML 8.1.3.5, as the host determined it: recorded before any interface
    // object is made, since a realm that is not a secure context exposes no
    // [SecureContext] construct (WebIDL 3.3.13).
    realm.secure_context = options.secure_context;

    if (restored) {
        // The snapshot has the interfaces; the adapter's template registry
        // still has to learn them, or a wrapped Document gets the wrong
        // prototype. A frame's realm builds only the interface objects its
        // script reads (.lazy_follows, as context_manager's child contexts
        // did): every one of ~1,260 costs a frame ~25 ms and ~2.8 MB, and a
        // frame-heavy page makes dozens.
        interface_bindings.registerAllTemplatesOnly(isolate, context, if (options.parent != null) .lazy_follows else .eager);
    } else {
        interface_bindings.initializeBindingsWithGlobalTemplate(isolate, context);
    }
    // The namespaces (console, WebAssembly, CSS...) are not in the snapshot.
    interface_bindings.registerNamespacesGeneric(namespaces, isolate, context);
    // A realm that is not a secure context: no [SecureContext] interface
    // object, whichever way they were installed above.
    interface_bindings.hideSecureContextInterfaceObjects(isolate, context, .Window);

    // Ours until the Window's wrapper-cache entry adopts it (bindWindowToGlobal),
    // which releases it at the realm's end; the host BORROWS it until then.
    const global = ffi.v8_Context_Global(context) orelse return error.OperationFailed;
    // No Window is bound until the host has made one - and a reused proxy
    // still names the Window it had. Undoing the realm reads field 0
    // (removeContext's Window), which must not find another realm's Window,
    // nor a field never set, which V8 refuses to read as a pointer.
    ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, null);

    // HTML "create a new realm", the customization for the global object:
    // the host's new Window, bound to `global` (BORROWED by the host).
    const window = options.create_global_object(realm, .{ .handle = .{ .ptr = global } }, options.host) orelse {
        ffi.v8_Object_Dispose(global);
        return error.OperationFailed;
    };
    bindWindowToGlobal(isolate, context, realm, global, window, allocator);

    const state = allocator.create(WindowRealmState) catch return error.OutOfMemory;
    errdefer allocator.destroy(state);
    state.* = .{
        .isolate = isolate,
        .entered_isolate = entered_isolate or takes_isolate_entry,
        .is_platform_object_same_origin = options.is_platform_object_same_origin,
        .report_window_access = options.report_window_access,
        .host = options.host,
        .parent = options.parent,
        .auxiliary = options.auxiliary and options.parent != null,
        .top_level = options.parent == null or options.auxiliary,
        .window = window,
        .window_generation = runtime.SlabAllocator.generationOf(window),
        .allocator = allocator,
    };
    errdefer state.children.deinit(std.heap.c_allocator);
    // Room for what follows the proxy (below, and E2 at the replacement's
    // commit), taken before the realm is recorded: nothing fails once it is.
    var auxiliary_following: usize = 0;
    if (predecessor) |old_state| {
        for (old_state.children.items) |child| {
            const child_state = realms.get(child) orelse continue;
            if (child_state.auxiliary and child_state.detached == null) auxiliary_following += 1;
        }
        const following = auxiliary_following + @as(usize, if (old_state.parent == null) 1 else 0);
        state.children.ensureTotalCapacity(std.heap.c_allocator, following) catch return error.OutOfMemory;
    }
    const parent_state: ?*WindowRealmState = if (options.parent) |parent| realms.get(parent) else null;
    if (parent_state) |ps| appendChild(ps, realm) catch return error.OutOfMemory;
    errdefer if (parent_state) |ps| removeChild(ps, realm);
    realms.put(std.heap.c_allocator, realm, state) catch return error.OutOfMemory;

    if (predecessor) |old_state| {
        // E2: the auxiliary navigables' realms - window.open's popups - the
        // predecessor parented follow its WindowProxy here, but only once
        // the replacement commits: the predecessor's document goes
        // (`destroyWindowRealm` .global_detached, `passAuxiliaryChildren`).
        // HTML's top-level traversables are the user agent's, not their
        // opener's Window: a popup outlives its opener's navigation ("close a
        // top-level traversable" and "discard" end it; nothing in "navigate",
        // "create and initialize a Document object" or "unload a document"
        // does), and a navigation abandoned before its document exists ends
        // only its own new realm (HTMLIFrameElement settleRealmReplacement),
        // so moving them when this realm was made let that end take them too.
        // Frames stay: they are destroyed with the predecessor's document.
        state.reserved_for_predecessor = auxiliary_following;
        state.predecessor = predecessor_realm;
        // A successor an earlier replacement left (it ended, or never
        // committed) has let go of this predecessor already (`endRealm`);
        // one still recorded lets go now.
        if (old_state.successor) |earlier| if (realms.get(earlier)) |earlier_state| {
            earlier_state.predecessor = null;
            earlier_state.reserved_for_predecessor = 0;
        };
        old_state.successor = realm;
        // E1: a top-level predecessor's page is this realm now: detached by
        // its navigation (destroyWindowRealm .global_detached, as a frame's),
        // it ends when the collector takes it or when this realm ends.
        if (old_state.parent == null) {
            old_state.parent = realm;
            state.children.appendAssumeCapacity(predecessor_realm.?);
        }
    }

    if (options.parent) |parent| {
        // A frame's window gets the window operations its parent's has.
        page_realm.defineOnFrame(isolate, context, realm, parent);
        // Made while the parent's script runs: its context leaves the stack
        // now, and is entered for each call that runs in it.
        ffi.v8_Context_Exit(context);
        state.context_entered = false;
        if (entered_isolate) {
            ffi.v8_Isolate_Exit(isolate);
            state.entered_isolate = false;
        }
    }
    return realm;
}

/// Where `window`'s traced edges hang (protocol_tracing.zig): its realm's
/// retained store, which its global's GlobalAnchor traces - so they live
/// exactly while its global object does - never the WindowProxy, which a
/// navigation hands to the next Window (Blink: LocalDOMWindow's members are
/// traced from the global's CppHeap pointer, design 2.2).
pub const TracedEdgeHolder = union(enum) {
    /// `window` is no Window of a realm made here: its wrapper is an
    /// ordinary one.
    not_a_realm_window,
    /// Its global object is gone (collected after its WindowProxy went on)
    /// or unreachable: no edge.
    gone,
    /// The retained store, as a Global the caller releases
    /// (v8_Global_Dispose).
    retained_store: *ffi.Value,
};

pub fn tracedEdgeHolderOfWindow(window: *engine.Instance) TracedEdgeHolder {
    // A Window with no realm made here (its realm not finished, or ended):
    // never wrap it as an ordinary object - its wrapper is a global object
    // or nothing.
    const is_window = std.mem.eql(u8, window.vtable.name, "Window");
    const state = stateOf(window.ctx) orelse return if (is_window) .gone else .not_a_realm_window;
    if (state.window != window) return if (is_window) .gone else .not_a_realm_window;
    // The store of this realm's own anchor - after a hand-on too: the
    // context's entry keeps the anchor the realm was attached with, which
    // reads gone once its global object is collected.
    return .{ .retained_store = realm_global.retainedStore(window.ctx) orelse return .gone };
}

fn removeChild(state: *WindowRealmState, child: Context) void {
    for (state.children.items, 0..) |c, i| {
        if (c != child) continue;
        _ = state.children.swapRemove(i);
        return;
    }
}

/// Add `child` to `state`'s children, leaving the room kept for the
/// predecessor's auxiliary children (`reserved_for_predecessor`).
fn appendChild(state: *WindowRealmState, child: Context) error{OutOfMemory}!void {
    try state.children.ensureUnusedCapacity(std.heap.c_allocator, 1 + state.reserved_for_predecessor);
    state.children.appendAssumeCapacity(child);
}

/// E2 at a realm replacement's commit (`createWindowRealm` says why): the
/// auxiliary children of `state`'s realm - its popups' realms - pass to the
/// realm made around its WindowProxy, before its document's end destroys
/// what stays (`detach`). Each pass takes the room kept for it; a popup
/// opened after the new realm was made, when the old Window was no longer
/// active, finds none kept, and passes only if an append succeeds.
fn passAuxiliaryChildren(realm: Context, state: *WindowRealmState) void {
    const successor = state.successor orelse return;
    state.successor = null;
    const realms = realmsOf(realm) orelse return;
    const next = realms.get(successor) orelse return;
    defer {
        next.predecessor = null;
        next.reserved_for_predecessor = 0;
    }
    if (next.detached != null) return;
    var i = state.children.items.len;
    while (i > 0) {
        i -= 1;
        const child = state.children.items[i];
        const child_state = realms.get(child) orelse continue;
        if (!child_state.auxiliary or child_state.detached != null) continue;
        if (next.reserved_for_predecessor > 0) {
            next.reserved_for_predecessor -= 1;
            next.children.appendAssumeCapacity(child);
        } else {
            next.children.append(std.heap.c_allocator, child) catch continue;
        }
        _ = state.children.swapRemove(i);
        child_state.parent = successor;
    }
}

/// A realm ending lets go of its replacement links (`successor`,
/// `predecessor`): an abandoned replacement's new realm ends with its
/// predecessor's popups still the predecessor's.
fn unlinkReplacement(realms: *WindowRealms, state: *WindowRealmState) void {
    if (state.successor) |successor| if (realms.get(successor)) |next| {
        next.predecessor = null;
        next.reserved_for_predecessor = 0;
    };
    if (state.predecessor) |predecessor| if (realms.get(predecessor)) |previous| {
        previous.successor = null;
    };
    state.successor = null;
    state.predecessor = null;
}

/// The agent's Window interface template, made and registered - EventTarget
/// first, so Window inherits the registered one - when no realm has made it
/// yet. A template made here gets the WindowProxy's indexed access
/// (`frames[i]`, HTML 7.2.3.1) on its instances, as the snapshot generator's
/// does; one an earlier realm made and used cannot change any more (V8 refuses
/// to alter an instantiated template).
fn windowTemplate(isolate: *ffi.Isolate) *ffi.FunctionTemplate {
    if (template_registry.getTemplateForIsolate("Window", isolate)) |made| return made;
    if (template_registry.getTemplateForIsolate("EventTarget", isolate) == null) {
        template_registry.register("EventTarget", interface_bindings.EventTarget.createTemplate(isolate), isolate);
    }
    const template = interface_bindings.Window.createTemplate(isolate);
    template_registry.register("Window", template, isolate);
    const instance_template = ffi.v8_FunctionTemplate_InstanceTemplate(template);
    defer ffi.v8_ObjectTemplate_Dispose(instance_template);
    ffi.v8_ObjectTemplate_SetIndexedPropertyHandlerFull(
        instance_template,
        context_manager.windowIndexedPropertyGetter,
        null,
        context_manager.windowIndexedPropertyQuery,
        context_manager.windowIndexedPropertyEnumerator,
        null,
    );
    return template;
}

/// What the access checks ask for `realm`'s WindowProxy and Locations: the
/// host's IsPlatformObjectSameOrigin and its host. Null for a realm made
/// without one (it is reached as a same-origin one is) or not made here.
pub const SameOriginCheck = struct {
    is_platform_object_same_origin: *const fn (host: ?*anyopaque, current: Context, object: *engine.Instance) bool,
    host: ?*anyopaque,
};

/// HTML 7.1.3.3 "check if an access between two browsing contexts should be
/// reported" [window_access_reporting]: script used `property` of `window`
/// - a Window this adapter made a realm for - which the binding of a
/// CrossOriginProperties(Window) member, the indexed or named getter or the
/// opener setter says before the member's steps (Chromium's
/// DOMWindow::ReportCoopAccess, which those bindings call: make_report_coop_access
/// in bind_gen/interface.py). The accessor is the incumbent realm, as
/// Chromium's IncumbentDOMWindow; a use from `window`'s own realm reports
/// nothing and asks no host. Runs no script.
pub fn reportWindowAccess(window: *engine.Instance, property: []const u8) void {
    // Chromium's DOMWindow::ReportCoopAccess returns at once for a window
    // with no CoopAccessMonitor ("Fast early return. Very likely true.",
    // dom_window.cc:882): a use of a Window of a Browser where no access can
    // be reported looks nothing up - no realm state, no incumbent realm
    // (runtime.BrowserScope.window_access_monitored, which
    // dom.coop_reporting.startMonitoring sets). A realm of no Browser (a unit
    // test's) is always asked.
    if (!windowAccessMonitored(window)) return;
    const state = stateOf(window.ctx) orelse return;
    const report = state.report_window_access orelse return;
    const accessor = incumbentRealm() orelse return;
    if (accessor == window.ctx) return;
    report(state.host, accessor, window, property);
}

/// Whether a use of `window` may be reported: false only while its realm's
/// Browser has not started its access monitoring. Two loads, no lookup.
pub fn windowAccessMonitored(window: *engine.Instance) bool {
    const scope = window.ctx.browser_scope orelse return true;
    return scope.window_access_monitored.load(.monotonic);
}

pub fn sameOriginCheckOf(realm: Context) ?SameOriginCheck {
    const state = stateOf(realm) orelse return null;
    return .{
        .is_platform_object_same_origin = state.is_platform_object_same_origin orelse return null,
        .host = state.host,
    };
}

/// `window`'s WindowProxy - its realm's global proxy - as an owned handle
/// (v8_Object_Dispose), when `window` is the Window behind it; null for a
/// Window whose proxy went on to a later realm, or one not made here.
pub fn windowProxyOf(window: *engine.Instance) ?*ffi.Object {
    const state = stateOf(window.ctx) orelse return null;
    if (state.window != window or state.window_proxy_handed_on) return null;
    const context = contextOf(window.ctx) orelse return null;
    return ffi.v8_Context_Global(context);
}

/// Bind `window` as `global`'s platform object, and give the global what a
/// Window's global has.
fn bindWindowToGlobal(
    isolate: *ffi.Isolate,
    context: *ffi.Context,
    realm: Context,
    global: *ffi.Object,
    window: *engine.Instance,
    allocator: std.mem.Allocator,
) void {
    // THE attach function (realm_global.attach): the Window in the global
    // proxy's field 0 and a GlobalAnchor on the proxy and its hidden global
    // object (Object::WrapGlobal) - Blink's SetupWindowPrototypeChain
    // (local_window_proxy.cc 405-449), here for a fresh context and a
    // restored one alike, as Blink's LocalWindowProxy::Initialize does.
    realm_global.attach(context, window);

    // Cross-origin checks ask the context manager for an accessor's Window.
    context_manager.setWindowForContext(context, window) catch |err| {
        log.debug("the realm's Window was not recorded: {}", .{err});
    };

    // The global IS the Window's wrapper - and its cache entry takes the
    // handle over, releasing it when the realm ends (removeContext). Not
    // taken (no cache, out of memory), it is released once the global is
    // set up.
    const adopted = blk: {
        const storage = realm.getV8WrapperCacheStorage() orelse break :blk false;
        const cache: *WrapperCache = @ptrCast(@alignCast(storage));
        _ = cache.set(window, global, isolate) catch break :blk false;
        break :blk true;
    };
    defer if (!adopted) ffi.v8_Object_Dispose(global);

    // The realm record - context, agent, global object: cross-realm errors,
    // the realm's intrinsics, and "the realm's global object".
    if (realm.realm == null) {
        if (runtime.Realm.init(allocator, .{
            .engine_realm = @ptrCast(context),
            .agent = @ptrCast(isolate),
            .context_type = .window,
            .global_object = @ptrCast(window),
        })) |record| {
            // The realm's intrinsics (%TypeError%, %Object%, %Array%...), for
            // making objects and errors in this realm from another.
            _ = realm_v8.populateIntrinsics(record);
            realm.setRealm(record);
            context_manager.setRealmForContext(context, record) catch {};
        } else |err| log.debug("the realm record was not made: {}", .{err});
    }

    // WebIDL 3.7.6/3.7.7, [Global]: Window's regular attributes and
    // operations - its mixins' included - are own properties of the global
    // object, and Window.prototype has none (members_on_global_object in
    // interface.zig). EventTarget's are NOT the global's: Window only
    // inherits them, from EventTarget.prototype up the chain (global ->
    // Window.prototype -> WindowProperties -> EventTarget.prototype), so
    // `self.addEventListener === EventTarget.prototype.addEventListener`.
    interface_bindings.Window.registerPropertiesAsOwnOnObject(isolate, context, global);
    interface_bindings.Window.registerMethodsAsOwnOnObject(isolate, context, global);
    // Its [SecureContext] ones, in a realm that is not a secure context
    // (WebIDL 3.3.13): cookieStore, caches, showOpenFilePicker...
    interface_bindings.Window.hideSecureContextMembers(isolate, context, global);

    // HTML 7.3.3, named access on the Window: WindowProperties on the chain,
    // wrapped with the realm's anchor (Blink SetupWindowPrototypeChain 434-437).
    _ = window_properties.insertIntoPrototypeChain(isolate, context);

    // `self` and `frames` are [Replaceable]: own data properties whose value
    // is the global itself, as their setter's [[DefineOwnProperty]] makes them
    // - defined, never assigned, which would run the script-facing setter
    // (docs/lessons/architecture-engine-code-defines-a-realm-s-properties-it-
    // never-assigns-them.md). They keep `self === globalThis`, which
    // testharness.js's `(function (global_scope) { ... })(self)` needs.
    // (`window` is an own accessor, registered above.)
    inline for (.{ "self", "frames" }) |name| {
        if (ffi.v8_String_NewFromUtf8(isolate, name.ptr, name.len)) |key| {
            defer ffi.v8_String_Dispose(key);
            _ = ffi.v8_Object_DefineProperty(global, context, @ptrCast(key), @ptrCast(global), true, true, true);
        }
    }
}

/// A Window realm whose end is under way: a stack, one node per `endRealm`
/// frame, innermost first, kept on the realm's agent's record
/// (protocol_agents.AgentRecord.ending_window_realms). It was a
/// `threadlocal`; a realm's end, and any end it reaches again, runs on its
/// agent's thread, in that agent.
pub const EndingRealm = struct {
    realm: Context,
    next: ?*const EndingRealm,
};

/// The stack of `realm`'s agent's Window realms whose end is under way - its
/// agent's own, found while the agent ends too; null for a realm of no agent
/// createAgent made, which is no Window realm.
fn endingRealmsOf(realm: Context) ?*?*const EndingRealm {
    const agent = realm.agent orelse return null;
    return protocol_agents.endingWindowRealmsOf(@ptrCast(@alignCast(agent)));
}

fn isEnding(ending_realms: ?*const EndingRealm, realm: Context) bool {
    var node = ending_realms;
    while (node) |n| : (node = n.next) {
        if (n.realm == realm) return true;
    }
    return false;
}

/// The end of a Window realm (Blink's LocalWindowProxy::DisposeContext order),
/// as `how` says (engine.WindowRealmEnd).
///
/// A frame's realm does not end here when script may still reach it:
/// - its navigable was destroyed (`.navigable_destroyed`): HTML keeps its
///   Window - `closed` answers true, and `document` its document - for as
///   long as script holds its WindowProxy;
/// - a navigation replaced its document and its WindowProxy went on to the
///   new realm (`.global_detached`, `window_proxy_handed_on`): HTML unloads
///   and destroys the old document, and the old Window and its realm live on
///   for as long as script reaches anything of them - the old document, a
///   node, a function. Ending it here, as Crane once did when its iframe
///   went, kept every realm a navigation replaced until then: 200
///   navigations of one iframe kept 200 contexts (crane/td-frame-navigation-
///   churn.html), and html/webappapis/scripting/events/compile-event-handler-
///   settings-objects.html, which renavigates its iframe in a loop, ran V8
///   out of memory.
/// Each is detached (`detach`), and ends once the collector takes it, or
/// with its page, whichever comes first (`endRealm`).
pub fn destroyWindowRealm(realm: Context, how: engine.WindowRealmEnd) void {
    if (stateOf(realm)) |state| {
        // A navigation replaced this realm's document and committed: its
        // popups pass to the new realm first (E2, `passAuxiliaryChildren`).
        if (how == .global_detached) passAuxiliaryChildren(realm, state);
        if (state.parent != null and state.detached == null) switch (how) {
            .navigable_destroyed => return detach(realm, state),
            .global_detached => if (state.window_proxy_handed_on) return detach(realm, state),
        };
    }
    endRealm(realm, how);
}

/// HTML "destroy a child navigable" - or "destroy a document" for a document
/// a navigation replaced - for the realm: script activity stops - its timers
/// and animation frames, the callbacks its script registered, its tasks
/// (`isDetached`) - and Crane keeps NO strong handle into its context.
/// The wrapper cache keeps from the global object what it held strongly
/// (WrapperCache.detach); the realm's intrinsics and its context handle go
/// weak. The Window, its Document and the wrapper cache stay: script that
/// holds the WindowProxy keeps reaching them, as in Blink, where
/// LocalWindowProxy::DisposeContext(kFrameIsDetached) disposes per-context
/// data and leaves the global attached, and the LocalDOMWindow lives as long
/// as its wrapper. When the collector takes the context, `realmCollected`
/// queues the rest of the end - never run inside the collector.
///
/// Its frames' navigables are destroyed with it: each is detached too, and
/// stays in this realm's children, so whichever end comes first ends them.
fn detach(realm: Context, state: *WindowRealmState) void {
    const stack = endingRealmsOf(realm);
    if (stack) |top| if (isEnding(top.*, realm)) return;
    const ending: EndingRealm = .{ .realm = realm, .next = if (stack) |top| top.* else null };
    if (stack) |top| top.* = &ending;
    defer if (stack) |top| {
        top.* = ending.next;
    };

    // A child already detached - its iframe was removed before this realm's
    // document went - is left as it is: it ends when the collector takes it,
    // or with its page, like this one. Ending it here freed a Window script
    // may still reach, and took it off this list mid-walk (removeChild's
    // swapRemove leaves the vacated slot undefined): the walk read that slot
    // as a realm, 0xaaaa... (joint-session-history-only-fully-active.html,
    // srcdoc-history-entries.html). Backwards, so that a child that does end
    // (its detach failed) moves only an already-visited child into its slot.
    var i = state.children.items.len;
    while (i > 0) {
        i -= 1;
        if (i >= state.children.items.len) continue;
        const child = state.children.items[i];
        if (stateOf(child)) |child_state| {
            if (child_state.detached != null) continue;
        }
        destroyWindowRealm(child, .navigable_destroyed);
    }

    const context = contextOf(realm) orelse return;
    const key = context_manager.keyOf(context) orelse return;
    // How the realm ends if it cannot be detached: as before - a replaced
    // realm's proxy is already another realm's.
    const end_now: engine.WindowRealmEnd = if (state.window_proxy_handed_on) .global_detached else .navigable_destroyed;
    // What keeps the realm's objects from now on: its retained store, which
    // its global object keeps through its GlobalAnchor. Gone already (a
    // replaced realm's global, collected), nothing reaches the realm.
    const global = realm_global.retainedStore(realm) orelse {
        if (stack) |top| top.* = ending.next;
        return endRealm(realm, end_now);
    };
    defer ffi.v8_Global_Dispose(global);
    const record = std.heap.c_allocator.create(Detached) catch {
        // No record to end it by later: end it now, as before.
        if (stack) |top| top.* = ending.next;
        return endRealm(realm, end_now);
    };
    record.* = .{ .realm = realm, .context = context, .key = key };

    // 1. Script activity stops: the window operations (timers, animation
    // frames) - the window's own, through which a realm with a parent (a
    // frame, or a top-level predecessor, whose parent is the realm that
    // replaced it) gives up its timers before they are forgotten; a page's
    // own realm ended them with its page - and the callbacks this realm's
    // script registered - each a strong handle into the context.
    if (state.parent != null) page_realm.frameWindowDestroyed(realm);
    page_realm.endWindowOperations(realm);
    @import("callback_registry.zig").cleanupForContext(@ptrFromInt(key));

    // 2. No strong handle into the context is left: what the wrapper cache
    // held strongly is kept from the retained store now, and the intrinsics
    // and the context handle are weak.
    if (realm.getV8WrapperCacheStorage()) |storage| {
        const cache: *WrapperCache = @ptrCast(@alignCast(storage));
        cache.detach(global);
    }
    if (realm.realm) |record_of_realm| realm_v8.weakenIntrinsics(record_of_realm);
    // The callbacks this realm's objects store - its targets' listeners and
    // event handlers, whatever realm their functions are of - are kept from
    // the retained store too: a listener a parent registered on a frame's
    // object, closing over the frame, would otherwise keep it forever. Blink
    // traces each listener from its target.
    _ = ffi.v8_Object_WeakenTaggedHandles(global, key, retained_key.ptr, retained_key.len);
    // The context is disposed, in Blink's sense, now: V8 is told while it is
    // alive, before its handle goes weak.
    notifyContextDisposed(state.isolate, context, state);
    ffi.v8_Context_SetWeak(context, record, realmCollected);
    state.detached = record;
    // A navigation gave a MAIN frame's navigable a new Window - this realm's
    // WindowProxy went on to it, so the frame is reused (Blink's
    // WindowProxy::kFrameWillBeReused): the agent's next engine-task step
    // collects the page that was left if it left much
    // (navigation_collection.zig). Not a frame's realm, and not a realm
    // whose navigable is gone - a closed page's ends in `endRealm`, a
    // destroyed navigable's has handed nothing on.
    if (state.top_level and state.window_proxy_handed_on) protocol_agents.oweNavigationCollection(state.isolate);
}

/// Tell V8 a Window realm's context is disposed, and whether it had
/// dependants, as Blink does from LocalWindowProxy::DisposeContext
/// (V8GCForContextDispose::NotifyContextDisposed, bindings/core/v8/
/// v8_gc_for_context_dispose.cc: `is_main_frame ? kNoDependants :
/// kSomeDependants`): a page's top-level realm has none - V8 takes its
/// allocation limits back to their initial values, tells its memory reducer
/// and aborts the context's WebAssembly compilations - and a child
/// navigable's has some, its page living on - V8 runs a young collection by
/// task. A realm with no state is told as a child's, which resets nothing.
/// The context is entered for the call (ffi.v8_Isolate_
/// ContextDisposedNotification): V8 takes the current context for the
/// disposed one. Neither collects here: that a page's memory comes back when
/// it goes is the host's memory-pressure notice (Browser,
/// engine.notifyMemoryPressure).
fn notifyContextDisposed(isolate: *ffi.Isolate, context: *ffi.Context, state: ?*WindowRealmState) void {
    const has_dependants = if (state) |s| !s.top_level else true;
    ffi.v8_Isolate_ContextDisposedNotification(isolate, context, has_dependants);
}

/// The collector took a detached realm's context (its weak handle's first
/// pass: no engine call may be made). Nothing may enter the realm from now
/// on, and the rest of its end runs from a task.
fn realmCollected(data: ?*anyopaque, _: usize) callconv(.c) void {
    const record: *Detached = @ptrCast(@alignCast(data orelse return));
    // Every liveness test reads "ended" from here.
    record.realm.engine_ctx = null;
    if (record.realm.realm) |r| r.engine_realm = null;
    if (record.ended) return;
    // Its page's event loop. With none, the page's end ends it.
    const loop = record.realm.getOptionalEventLoop() orelse return;
    record.task_queued = true;
    loop.queueTask(.{ .callback = endCollectedRealm, .context = record, .drop = dropCollectedRealm });
}

fn endCollectedRealm(data: ?*anyopaque) void {
    const record: *Detached = @ptrCast(@alignCast(data orelse return));
    record.task_queued = false;
    if (record.ended) return record.destroy();
    // Ends the realm, and frees the record.
    endRealm(record.realm, .navigable_destroyed);
}

fn dropCollectedRealm(data: ?*anyopaque) void {
    const record: *Detached = @ptrCast(@alignCast(data orelse return));
    record.task_queued = false;
    // Not ended yet: its page's end, still to come, ends it and frees this.
    if (record.ended) record.destroy();
}

/// A context handle that still reaches its context.
fn isLive(context: *ffi.Context) bool {
    return !ffi.v8_Global_IsEmpty(@ptrCast(context));
}

/// The end of a Window realm: its frames' realms first, then the Window,
/// its document and its wrapper cache (the context manager), then the
/// context. A detached realm (`detach`) ends here when the collector took it
/// or when its page ends, whichever is first; it keeps its global attached.
fn endRealm(realm: Context, how: engine.WindowRealmEnd) void {
    // A realm ends once, and its end can reach itself: the context manager's
    // teardown frees what the realm's wrapper cache holds, and a removed
    // iframe element wrapped only here (`frames[0].frameElement`) takes its
    // integration with it - whose cleanup is this realm's end. The inner call
    // does nothing; the outer one finishes. Blink's
    // LocalWindowProxy::DisposeContext likewise returns unless its lifecycle
    // is still kContextIsInitialized.
    const stack = endingRealmsOf(realm);
    if (stack) |top| if (isEnding(top.*, realm)) return;
    const ending: EndingRealm = .{ .realm = realm, .next = if (stack) |top| top.* else null };
    if (stack) |top| top.* = &ending;
    defer if (stack) |top| {
        top.* = ending.next;
    };

    // Its frames' realms that are still alive end first, the same way: a
    // removed frame's frames are destroyed navigables too.
    const realms = realmsOf(realm);
    if (stateOf(realm)) |s| {
        // Its replacement links go first: an abandoned replacement's new
        // realm ends with its predecessor's popups still the predecessor's.
        if (realms) |r| unlinkReplacement(r, s);
        while (s.children.pop()) |child| endRealm(child, how);
        s.children.deinit(std.heap.c_allocator);
    }
    const state = if (realms) |r| (if (r.fetchRemove(realm)) |kv| kv.value else null) else null;
    const detached: ?*Detached = if (state) |s| s.detached else null;
    defer if (state) |s| s.allocator.destroy(s);
    if (state) |s| if (s.parent) |parent| {
        if (realms.?.get(parent)) |ps| removeChild(ps, realm);
    };
    // A detached realm's context is its record's handle - `engine_ctx` reads
    // null once the collector took it.
    const context: *ffi.Context = if (detached) |d| d.context else contextOf(realm) orelse return;
    // The record outlives this call only for a task still queued to end it.
    defer if (detached) |d| {
        if (d.task_queued) d.ended = true else d.destroy();
    };
    const key = if (detached) |d| d.key else context_manager.keyOf(context) orelse return;
    const isolate: *ffi.Isolate = if (state) |s| s.isolate else @ptrCast(@alignCast(ffi.v8_Isolate_GetCurrent() orelse return));

    // The realm's window operations end with it: a frame's window gives up
    // its timers through them first - they are its own until then (a
    // detached realm did both at its detach).
    if (detached == null) {
        if (state) |s| if (s.parent != null) page_realm.frameWindowDestroyed(realm);
        page_realm.endWindowOperations(realm);
    }

    // Every engine object that still names the Window loses it BEFORE the
    // context manager frees it (lane winslot1, E1/E2; Blink's DisposeContext
    // clears the global's native info, V8DOMWrapper::ClearNativeInfo, before
    // DetachGlobalObject): the WindowProxy's field 0 while it still names this
    // Window - a proxy handed on names the later realm's, and keeps it - and
    // this realm's GlobalAnchor, which the hidden global object and the
    // WindowProperties object are wrapped with (realm_global.clearInstance;
    // the context manager clears the anchor again, by key, for a context the
    // collector took). A realm ended with .global_detached and no hand-on - a
    // top-level page, a retired frame realm - used to keep the Window there,
    // and a getter of Window.prototype called on the detached proxy unwrapped
    // it.
    if (state) |s| if (s.window) |window| {
        if (isLive(context)) realm_global.clearInstance(context, window);
    };

    // 1. The context manager first: it tears down the Window, its document and
    // its frames, and retires the realm - which from here on has no engine
    // context, and may only be compared.
    context_manager.removeContextByKey(key);
    // 2. The context and its global proxy - the WindowProxy, which outlives
    // them - unless the collector took them already. A realm whose proxy went
    // on has nothing left to detach or sever through its context: the proxy
    // is a later realm's (its own global object was severed above).
    const handed_on = if (state) |s| s.window_proxy_handed_on else false;
    if (isLive(context) and !(detached != null and handed_on)) switch (if (detached != null) .navigable_destroyed else how) {
        // Break the link, unless a later realm already took the proxy over.
        .global_detached => if (state == null or !state.?.window_proxy_handed_on) ffi.v8_Context_DetachGlobal(context),
        // Blink's DisposeContext(kFrameIsDetached) leaves the global
        // attached: script that holds a removed frame's WindowProxy still
        // reads its own properties - `self`, `frames`, `globalThis` - and
        // `window` (self-et-al.window.js). The global outlives the Window the
        // context manager just freed - its page ended first - so it was
        // severed from it before (above): a member that needs the Window
        // finds none and throws a TypeError, rather than reading freed memory.
        .navigable_destroyed => {},
    };
    // 3. Exit the context entered for the realm's life - unless a realm
    // that took over its WindowProxy was entered in its place. Only the last
    // entered context can be exited; one still under another is left entered
    // rather than exited out of order, which V8 does not survive.
    const entered = if (state) |s| s.context_entered else true;
    if (entered and isLive(context)) {
        if (isLastEntered(isolate, context))
            ffi.v8_Context_Exit(context)
        else
            log.warn("a Window realm ended under another entered context; its context stays entered", .{});
    }
    // 4. Tell V8 the context is disposed (`notifyContextDisposed`) - unless
    // the realm was detached, when V8 was told then, at the moment Blink
    // tells it (the navigation, the frame's removal), or the collector took
    // the context, which V8 did itself. Never from a detached realm's later
    // end: that runs from the collector's queue, with another page's context
    // entered. Then release the handle - a detached realm's weak arm with it.
    if (detached == null and isLive(context)) notifyContextDisposed(isolate, context, state);
    ffi.v8_Context_Dispose(context);
    if (state) |s| if (s.entered_isolate) ffi.v8_Isolate_Exit(isolate);
    // 5. The Window's storage goes back to its Browser's slab: its teardown
    // ran (step 1, which marks it), every engine object that named it was
    // severed (above) and its realm's sweep is over - now, or, when this
    // end runs inside another realm's teardown, after that teardown's last
    // phase (runtime.gc.releaseSevered). Only once every holder that can
    // outlive the realm reads it through a generation check
    // (runtime.window_holders.reusable); until then it stays issued, as it
    // always was, until its Browser ends.
    if (runtime.window_holders.reusable) if (state) |s| if (s.window) |window| {
        runtime.gc.releaseSevered(window, s.window_generation);
    };
}

// ============================================================================
// entryRealm / incumbentRealm / functionRealm
// ============================================================================

/// HTML 8.1.3.3.1: the entry realm is the realm of the most recently pushed
/// realm execution context - V8's entered context (Context::Enter, which
/// "prepare to run script" performs), or a running microtask's.
pub fn entryRealm() ?Context {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return null;
    return realmOfOwnedContext(ffi.v8_Isolate_GetEnteredOrMicrotaskContext(isolate));
}

/// HTML 8.1.3.3.2: the incumbent realm - the topmost script-having execution
/// context's realm, or the backup incumbent settings object's when that
/// context is being skipped or there is none. V8's GetIncumbentContext is
/// those steps, with Context::BackupIncumbentScope as the backup stack
/// ("prepare to run a callback" pushes one).
pub fn incumbentRealm() ?Context {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return null;
    return realmOfOwnedContext(ffi.v8_Isolate_GetIncumbentContext(isolate));
}

/// ECMAScript GetFunctionRealm(`value`): its [[Realm]], through bound
/// functions and proxies. Null for a value that is no object, one whose realm
/// the context manager does not host, and at a revoked proxy (where the spec
/// throws a TypeError: the caller answers it). Deviation, as V8's own walk
/// makes it: an object that is no function answers its creation context
/// (a platform object: its relevant realm) where step 5 says the current
/// realm.
pub fn functionRealm(value: JSValue) ?Context {
    const handle: *ffi.Value = switch (value) {
        .handle => |h| @ptrCast(@alignCast(h.ptr)),
        .instance => |instance| return instance.ctx,
        else => return null,
    };
    var revoked = false;
    return realmOfOwnedContext(ffi.v8_Value_GetFunctionRealm(handle, &revoked));
}

// ============================================================================
// A global object's built-in functions
// ============================================================================

/// The engine protocol's globalBuiltinFunction: ECMAScript
/// CreateBuiltinFunction(steps, length, name, « », realm) for a function
/// `realm`'s global object is associated with (Streams 7.2.2 and 7.3.2, the
/// byte length and count queuing strategy size functions), made on the
/// first call for `key` and the same function on every later one.
///
/// Blink's GetCachedSizeFunction (core/streams/queuing_strategy_common.cc):
/// the function is kept under a private symbol on the realm's global - an
/// edge the collector traces from the global, never a root - so a realm
/// whose navigable is gone is still collected with it. Stored, as Blink
/// stores it, through the realm's global PROXY (`context->Global()`): V8
/// puts a private symbol set on an attached JSGlobalProxy on its global
/// OBJECT (LookupIterator::GetStoreTarget, lookup-inl.h), and a read through
/// the proxy finds it there - so a WindowProxy a navigation hands on reaches
/// the new realm's global object and never carries the old realm's function
/// into the new one. (V8 >= 14 gives no other path to the global object: the
/// V1 GetPrototype that did is Object.getPrototypeOf now, crbug.com/333672197,
/// and answered Window.prototype - design 2.6.) Function::New with ConstructorBehavior::kThrow
/// (v8_Function_NewWithData): no [[Construct]] and no "prototype", and not
/// cached in the context's template instantiation cache. OWNED: a hold of
/// the function.
pub fn globalBuiltinFunction(realm: Context, key: []const u8, function_name: []const u8, length: u32, function: *const engine.BuiltinFunction) Error!engine.Owned {
    const entered = try support.enter(realm);
    defer entered.leave();
    const isolate = entered.isolate;
    const context = entered.context();
    const global = ffi.v8_Context_Global(context) orelse return error.OperationFailed;
    defer ffi.v8_Object_Dispose(global);
    // The function made for `key` before: the global object keeps it.
    if (ffi.v8_Object_GetPrivateRef(global, key.ptr, @intCast(key.len))) |made| return support.owned(made);

    // 2. Let F be ! CreateBuiltinFunction(steps, length, name, « »,
    //    globalObject's relevant Realm). The steps reach `function` through
    //    the closure's [[data]], an External the function keeps.
    const external = ffi.v8_External_New(isolate, @ptrCast(@constCast(function))) orelse return error.OperationFailed;
    defer ffi.v8_External_Dispose(external);
    const made = try support.newClosure(entered, builtinFunctionSteps, @ptrCast(external), @intCast(length));
    errdefer ffi.v8_Global_Dispose(made);
    const name = try support.newString(isolate, function_name);
    defer ffi.v8_String_Dispose(name);
    ffi.v8_Function_SetName(@ptrCast(made), name);
    // 3. Set globalObject's ... function to F: kept by the global object.
    ffi.v8_Object_SetPrivateRef(global, key.ptr, @intCast(key.len), made);
    return support.owned(made);
}

/// A built-in function's argument as its steps see it (engine.BuiltinSteps):
/// a primitive as itself, a string as its UTF-8 (owned by `allocator`),
/// anything else a handle BORROWED for the call.
fn builtinArgument(isolate: *ffi.Isolate, context: *ffi.Context, value: *ffi.Value, allocator: std.mem.Allocator) !JSValue {
    if (ffi.v8_Value_IsUndefined(value)) return JSValue.jsUndefined;
    if (ffi.v8_Value_IsNull(value)) return JSValue.jsNull;
    if (ffi.v8_Value_IsBoolean(value)) return .{ .boolean = ffi.v8_Value_BooleanValue(value, isolate) };
    if (ffi.v8_Value_IsNumber(value)) return .{ .number = ffi.v8_Value_NumberValue(value, context) };
    if (ffi.v8_Value_IsString(value)) {
        const str: *ffi.String = @ptrCast(value);
        const len = ffi.v8_String_Utf8Length(str);
        if (len <= 0) return JSValue.fromStringRef("");
        const buffer = try allocator.alloc(u8, @intCast(len));
        _ = ffi.v8_String_WriteUtf8(str, buffer.ptr, len);
        return JSValue.fromStringOwned(buffer);
    }
    return .{ .handle = .{ .ptr = @ptrCast(value) } };
}

/// What a globalBuiltinFunction's function runs: its steps, given its
/// arguments; what they return is its result.
fn builtinFunctionSteps(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const data = info.getData();
    defer ffi.v8_Global_Dispose(data);
    const function: *const engine.BuiltinFunction = @ptrCast(@alignCast(ffi.v8_External_Value(@ptrCast(data)) orelse return));
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer ffi.v8_Context_Dispose(context);

    const allocator = std.heap.c_allocator;
    const argc: usize = @intCast(@max(info.length(), 0));
    var handles_buf: [4]*ffi.Value = undefined;
    var values_buf: [4]JSValue = undefined;
    const handles = if (argc <= handles_buf.len) handles_buf[0..argc] else allocator.alloc(*ffi.Value, argc) catch return;
    defer if (argc > handles_buf.len) allocator.free(handles);
    const values = if (argc <= values_buf.len) values_buf[0..argc] else allocator.alloc(JSValue, argc) catch return;
    defer if (argc > values_buf.len) allocator.free(values);
    var made: usize = 0;
    defer for (handles[0..made], values[0..made]) |handle, *value| {
        value.deinit(allocator);
        ffi.v8_Global_Dispose(handle);
    };
    while (made < argc) : (made += 1) {
        // An owned Global for each argument; its value borrows it.
        handles[made] = info.get(@intCast(made));
        values[made] = builtinArgument(isolate, context, handles[made], allocator) catch {
            ffi.v8_Global_Dispose(handles[made]);
            return;
        };
    }

    const result = function.steps(function.data, values) catch |err| switch (err) {
        // Already thrown: leave it in flight.
        error.ExceptionPending => return,
        else => {
            conversions.throwWebIDLErrorFromContext(isolate, context, @errorName(err));
            return;
        },
    };
    const returned = conversions.toV8Value(JSValue, isolate, context, result) catch return;
    info.setReturnValue(returned);
    // The result is the engine's (engine.BuiltinSteps): a value made for it,
    // or a handle the steps handed over, released now that V8 holds its own.
    // An instance's wrapper is the wrapper cache's.
    if (result != .instance) ffi.v8_Global_Dispose(returned);
}
