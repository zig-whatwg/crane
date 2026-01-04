//! Implementation for AnimationWorkletGlobalScope interface
//! CSS Animation Worklet API: https://drafts.css-houdini.org/css-animationworklet-1/

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const AnimationWorkletGlobalScope = interfaces.AnimationWorkletGlobalScope;

pub const State = AnimationWorkletGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    TypeError,
};

/// Registered animator definition
pub const AnimatorDefinition = struct {
    constructor: callbacks.AnimatorInstanceConstructor,
    state_constructor: ?callbacks.VoidFunction = null,
};

/// Internal state for AnimationWorkletGlobalScope
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Map of registered animator definitions by name
    registered_animators: std.StringHashMap(AnimatorDefinition),

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .registered_animators = std.StringHashMap(AnimatorDefinition).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        var it = self.registered_animators.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.registered_animators.deinit();
    }
};

/// Thread-safe registry for internal state (module-level static)
var registry: std.AutoHashMap(*runtime.Instance, InternalState) = undefined;
var registry_initialized: bool = false;

fn getRegistry(allocator: std.mem.Allocator) *std.AutoHashMap(*runtime.Instance, InternalState) {
    if (!registry_initialized) {
        registry = std.AutoHashMap(*runtime.Instance, InternalState).init(allocator);
        registry_initialized = true;
    }
    return &registry;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer instance.deinit();

    // Initialize internal state
    const internal = InternalState.init(allocator);
    try getRegistry(allocator).put(instance, internal);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const allocator = std.heap.page_allocator;
    if (getRegistry(allocator).get(instance)) |internal| {
        var state = internal;
        state.deinit();
    }
    _ = getRegistry(allocator).remove(instance);
}

/// Operation: registerAnimator
/// Registers an animator class for use with WorkletAnimation
pub fn call_registerAnimator(instance: *runtime.Instance, name: runtime.DOMString, animatorCtor: callbacks.AnimatorInstanceConstructor) anyerror!void {
    const allocator = std.heap.page_allocator;
    const internal = getRegistry(allocator).getPtr(instance) orelse return error.InvalidState;

    const name_slice = name.asSlice();

    // Check if name is already registered (per spec, this is an error)
    if (internal.registered_animators.contains(name_slice)) {
        return error.InvalidState;
    }

    // Duplicate the name for storage
    const name_copy = try internal.allocator.dupe(u8, name_slice);
    errdefer internal.allocator.free(name_copy);

    // Store the animator definition
    try internal.registered_animators.put(name_copy, .{
        .constructor = animatorCtor,
    });
}
