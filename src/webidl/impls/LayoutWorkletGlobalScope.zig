//! Implementation for LayoutWorkletGlobalScope interface
//! CSS Layout API Level 1: https://drafts.css-houdini.org/css-layout-api-1/

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const LayoutWorkletGlobalScope = interfaces.LayoutWorkletGlobalScope;

pub const State = LayoutWorkletGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    TypeError,
};

/// Registered layout definition
pub const LayoutDefinition = struct {
    constructor: callbacks.VoidFunction,
    input_properties: []const []const u8 = &.{},
    child_input_properties: []const []const u8 = &.{},
    layout_options: ?LayoutOptions = null,

    pub const LayoutOptions = struct {
        child_display: ChildDisplayType = .block,
        sizing: SizingMode = .block_like,

        pub const ChildDisplayType = enum { block, normal };
        pub const SizingMode = enum { block_like, manual };
    };
};

/// Internal state for LayoutWorkletGlobalScope
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Map of registered layout definitions by name
    registered_layouts: std.StringHashMap(LayoutDefinition),

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .registered_layouts = std.StringHashMap(LayoutDefinition).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        var it = self.registered_layouts.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.registered_layouts.deinit();
    }
};

/// Thread-safe registry for internal state
const Registry = std.AutoHashMap(*runtime.Instance, InternalState);
var registry: ?Registry = null;
var map_allocator: ?std.mem.Allocator = null;

fn getRegistry(allocator: std.mem.Allocator) *Registry {
    if (registry == null) {
        registry = Registry.init(allocator);
        map_allocator = allocator;
    }
    return &registry.?;
}

/// Cleanup all remaining internal state (for use during shutdown/testing)
/// This prevents memory leaks when the module-level registry isn't cleaned up
pub fn deinitRegistry() void {
    const allocator = map_allocator orelse return;
    _ = allocator; // Used for consistency with other worklets

    if (registry) |*reg| {
        var it = reg.iterator();
        while (it.next()) |entry| {
            var state = entry.value_ptr.*;
            state.deinit();
        }
        reg.deinit();
        registry = null;
    }
    map_allocator = null;
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
    const allocator = map_allocator orelse return;
    if (getRegistry(allocator).getPtr(instance)) |internal| {
        internal.deinit();
    }
    _ = getRegistry(allocator).remove(instance);
}

/// Operation: registerLayout
/// Registers a layout class for use with CSS display: layout(name)
pub fn call_registerLayout(instance: *runtime.Instance, name: runtime.DOMString, layoutCtor: callbacks.VoidFunction) anyerror!void {
    const allocator = map_allocator orelse return error.InvalidState;
    const internal = getRegistry(allocator).getPtr(instance) orelse return error.InvalidState;

    const name_slice = name.asSlice();

    // Check if name is already registered (per spec, this is an error)
    if (internal.registered_layouts.contains(name_slice)) {
        return error.InvalidState;
    }

    // Duplicate the name for storage
    const name_copy = try internal.allocator.dupe(u8, name_slice);
    errdefer internal.allocator.free(name_copy);

    // Store the layout definition
    try internal.registered_layouts.put(name_copy, .{
        .constructor = layoutCtor,
    });
}
