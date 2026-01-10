//! Implementation for PaintWorkletGlobalScope interface
//! CSS Painting API Level 1: https://drafts.css-houdini.org/css-paint-api-1/

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const PaintWorkletGlobalScope = interfaces.PaintWorkletGlobalScope;

pub const State = PaintWorkletGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    TypeError,
};

/// Registered paint definition
pub const PaintDefinition = struct {
    constructor: callbacks.VoidFunction,
    input_properties: []const []const u8 = &.{},
    input_arguments: []const []const u8 = &.{},
    context_options: ?ContextOptions = null,

    pub const ContextOptions = struct {
        alpha: bool = true,
    };
};

/// Internal state for PaintWorkletGlobalScope
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Map of registered paint definitions by name
    registered_paints: std.StringHashMap(PaintDefinition),
    /// Device pixel ratio for this worklet context
    device_pixel_ratio: f64 = 1.0,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .registered_paints = std.StringHashMap(PaintDefinition).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        var it = self.registered_paints.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.registered_paints.deinit();
    }
};

/// Simple hashmap for internal state (same pattern as AudioWorkletGlobalScope)
var internal_state_map: ?std.AutoHashMap(*runtime.Instance, *InternalState) = null;

fn getRegistry(allocator: std.mem.Allocator) *std.AutoHashMap(*runtime.Instance, *InternalState) {
    if (internal_state_map == null) {
        internal_state_map = std.AutoHashMap(*runtime.Instance, *InternalState).init(allocator);
    }
    return &internal_state_map.?;
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

    // Store allocator for later use
    if (map_allocator == null) {
        map_allocator = allocator;
    }

    // Initialize internal state
    const internal_ptr = try allocator.create(InternalState);
    internal_ptr.* = InternalState.init(allocator);
    try getRegistry(allocator).put(instance, internal_ptr);

    return instance;
}

/// Module-level allocator for the registry (set during first init)
var map_allocator: ?std.mem.Allocator = null;

/// Cleanup all remaining internal state (for use during shutdown/testing)
/// This prevents memory leaks when the module-level registry isn't cleaned up
pub fn deinitRegistry() void {
    const allocator = map_allocator orelse return;
    if (internal_state_map) |*map| {
        var it = map.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            allocator.destroy(entry.value_ptr.*);
        }
        map.deinit();
        internal_state_map = null;
    }
    map_allocator = null;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const allocator = map_allocator orelse return;
    if (getRegistry(allocator).get(instance)) |internal| {
        internal.deinit();
        allocator.destroy(internal);
    }
    _ = getRegistry(allocator).remove(instance);
}

/// Getter for devicePixelRatio
pub fn get_devicePixelRatio(instance: *runtime.Instance) anyerror!f64 {
    const allocator = map_allocator orelse return 1.0;
    if (getRegistry(allocator).get(instance)) |internal| {
        return internal.device_pixel_ratio;
    }
    return 1.0; // Default fallback
}

/// Operation: registerPaint
/// Registers a paint class for use with CSS paint() function
pub fn call_registerPaint(instance: *runtime.Instance, name: typedefs.DOMString, paintCtor: callbacks.VoidFunction) anyerror!void {
    const allocator = map_allocator orelse return error.InvalidState;
    const internal = getRegistry(allocator).get(instance) orelse return error.InvalidState;

    const name_slice = name.asSlice();

    // Check if name is already registered (per spec, this is an error)
    if (internal.registered_paints.contains(name_slice)) {
        return error.InvalidState;
    }

    // Duplicate the name for storage
    const name_copy = try internal.allocator.dupe(u8, name_slice);
    errdefer internal.allocator.free(name_copy);

    // Store the paint definition
    try internal.registered_paints.put(name_copy, .{
        .constructor = paintCtor,
    });
}
