//! Implementation for ProcessingInstruction interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-processinginstruction
//! WHATWG DOM Standard §4.13
//!
//! ProcessingInstruction nodes represent processing instructions in XML.
//! They extend CharacterData and have an associated target.
//! Node type is PROCESSING_INSTRUCTION_NODE (7).
//!
//! Migrated from: webidl/src/dom/ProcessingInstruction.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ProcessingInstruction = interfaces.ProcessingInstruction;

const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

pub const State = ProcessingInstruction.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Internal state for ProcessingInstruction implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The target of this processing instruction (e.g., "xml-stylesheet")
    target: []const u8,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .target = "",
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.target.len > 0) self.allocator.free(self.target);
    }
};

/// The ProcessingInstructions alive, for the final teardown's sweep.
///
/// A PI still alive when the browser ends is never deinit'd one by one:
/// the teardown sweeps free the node registries wholesale (dom.teardown_sweeps), and its
/// target - the PI's own, outside those registries - then leaked (17 over
/// dom/ranges/Range-surroundContents.html, the PIs in subtrees nothing tore
/// down). So the PI keeps its own list, taken on init and given up on deinit,
/// and installs a sweep (dom.teardown_sweeps) that frees what is left in it.
/// Keyed by address: the entry goes in the PI's deinit, before the slab can
/// reissue the address.
threadlocal var live: ?std.AutoHashMap(*runtime.Instance, void) = null;
threadlocal var live_guard: @import("webidl").utils.tombstones.TombstoneGuard = .{};

fn trackLive(instance: *runtime.Instance) void {
    if (live == null) live = .init(std.heap.c_allocator);
    const map = &live.?;
    live_guard.beforeInsert(map);
    map.put(instance, {}) catch {};
}

fn untrackLive(instance: *runtime.Instance) void {
    const map = if (live) |*m| m else return;
    if (map.remove(instance)) live_guard.noteRemoval(map);
}

/// dom.teardown_sweeps: free the state of every PI of `scope`'s Browser
/// still alive (the thread's set holds only its Browser's: a Browser's PIs
/// are made on its window thread).
fn sweepLive(scope: *runtime.BrowserScope) void {
    const map = if (live) |*m| m else return;
    var it = map.keyIterator();
    while (it.next()) |instance| {
        if (runtime.BrowserScope.ofInstance(instance.*) != scope) continue;
        if (getInternal(instance.*)) |internal| {
            internal.deinit();
            internal.target = "";
        }
    }
    map.deinit();
    live = null;
    live_guard.reset();
}

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    @import("dom").teardown_sweeps.install(.element_types, &sweepLive);
}

/// ProcessingInstruction's own construction steps: the generated chain runs CharacterData's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    // Initialize ProcessingInstruction internal state
    const state = instance.getState(State);
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;
    trackLive(instance);
}

/// ProcessingInstruction's own teardown: the generated chain runs CharacterData's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    untrackLive(instance);
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();

        // Return the block itself, not just what it points to.
        // `internal.deinit()` releases the strings and lists the state
        // OWNS; without this the state struct stays allocated for the
        // life of the process - measured at 208 bytes per discarded
        // element across the impls still doing it this way.
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
}

// =============================================================================
// Getters - DOM §4.13
// =============================================================================

/// Getter for target
/// DOM §4.13 - Returns this's target.
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_target(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.target);
}

/// Getter for sheet (from LinkStyle mixin - CSSOM)
/// Returns the associated stylesheet, if any
pub fn get_sheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // TODO: Return associated CSSStyleSheet if this is <?xml-stylesheet?>
    // Requires CSSOM integration
    return error.NotImplemented;
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Get the target string directly (for cloning)
pub fn getTarget(instance: *runtime.Instance) ?[]const u8 {
    const internal = getInternal(instance) orelse return null;
    return internal.target;
}

/// Create a ProcessingInstruction with the given target and data
pub fn createProcessingInstruction(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    target: []const u8,
    data: []const u8,
) !*runtime.Instance {
    // The data is CharacterData's construction argument.
    const instance = try ProcessingInstruction.initWith(allocator, ctx, .{ .data = data });
    errdefer ProcessingInstruction.deinit(instance);

    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Set the target
    internal.target = try allocator.dupe(u8, target);

    return instance;
}
