//! Implementation for DocumentFragment interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-documentfragment
//! WHATWG DOM Standard §4.8
//!
//! DocumentFragment is a lightweight container for DOM nodes.
//! It's commonly used to build up DOM structures before inserting them.
//!
//! Migrated from: webidl/src/dom/DocumentFragment.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DocumentFragment = interfaces.DocumentFragment;
const dom = @import("dom");
const engine = @import("engine");

// Import related impls
const NodeImpl = @import("Node.zig");

// Import mixins for shared interface methods
const mixins = @import("mixins");

pub const State = DocumentFragment.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
    SyntaxError,
};

/// Internal state for DocumentFragment implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The template that owns this fragment, null for ordinary fragments.
    /// ShadowRoot exposes its own host through the ShadowRoot interface.
    host: ?*runtime.Instance,
    host_generation: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .host = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        _ = self;
    }
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = runtime.InstanceRegistry(.document_fragment, InternalState);

pub fn installHooks() void {
    // Its states left at its Browser's end (Browser.deinit).
    @import("dom").teardown_sweeps.install(.node_types, &sweepRemaining);
    dom.template_contents.install(.{ .set_host = &setTemplateHost, .host = &templateHost, .clear_host = &clearTemplateHost });
}

/// The template whose contents this fragment is: a native pointer, checked by
/// generation on every read (`templateHost`). No edge is traced to the
/// template's wrapper: that made a wrapper for a template script had not seen
/// yet - from then on the collector's to free with it - and a constructor
/// binding the template to NewTarget's object would replace that wrapper
/// (PR-M1). The template owns the fragment natively instead
/// (`dom.template_contents.ownedByLiveTemplate`).
fn setTemplateHost(fragment: *runtime.Instance, host: *runtime.Instance) !void {
    const internal = Registry.get(fragment) orelse return error.InvalidStateError;
    internal.host = host;
    internal.host_generation = runtime.SlabAllocator.generationOf(host);
}

fn clearTemplateHost(fragment: *runtime.Instance) void {
    const internal = Registry.get(fragment) orelse return;
    internal.host = null;
    internal.host_generation = 0;
}

fn templateHost(fragment: *runtime.Instance) ?*runtime.Instance {
    const internal = Registry.get(fragment) orelse return null;
    const host = internal.host orelse return null;
    return if (runtime.SlabAllocator.generationOf(host) == internal.host_generation) host else null;
}

/// Public function to get internal state (for other impls that need it)
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// DocumentFragment's own construction steps: the generated chain runs Node's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    // Initialize DocumentFragment's own internal state and register it
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = InternalState.init(allocator);
}

/// DocumentFragment's own teardown: the generated chain runs Node's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // Get internal state from registry (where it was stored in init)
    if (Registry.get(instance)) |internal| {
        engine.forgetTracedChild(instance, .{ .name = "template owner document" });
        internal.deinit();
        // Remove from registry to prevent double-free
        Registry.remove(instance);
    }
}

/// Constructor implementation
/// DOM §4.8 - DocumentFragment()
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const realm = ctx.realm orelse return error.InvalidStateError;
    const global: *runtime.Instance = @ptrCast(@alignCast(realm.global_object orelse return error.InvalidStateError));
    const document = try interfaces.Window.get_document(global);
    const instance = try DocumentFragment.init(ctx.allocator, ctx);
    errdefer DocumentFragment.deinit(instance);
    // Constructor steps: node document is the current global's document.
    try dom.node_document.set(instance, document);
    return instance;
}

// =============================================================================
// ParentNode Mixin Getters
// =============================================================================

// =============================================================================
// ParentNode Mixin Operations
// =============================================================================

// =============================================================================
// NonElementParentNode Mixin Operations
// =============================================================================

/// dom.teardown_sweeps: at its Browser's end, every DocumentFragment state still in
/// `scope`'s table - an orphan's no teardown reached - frees what it owns.
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    Registry.deinitAllAndClear(scope);
}
