//! Generated from: css-highlight-api.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HighlightRegistryImpl = @import("../impls/HighlightRegistry.zig");

pub const HighlightRegistry = struct {
    pub const Meta = struct {
        pub const name = "HighlightRegistry";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const void _skipped = null;
    pub fn get__skipped() void {
        return null;
    }

    pub const vtable = runtime.buildVTable(HighlightRegistry, .{
        .deinit_fn = &deinit_wrapper,

        .get__skipped = &get__skipped,

        .call_highlightsFromPoint = &call_highlightsFromPoint,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        HighlightRegistryImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        HighlightRegistryImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_highlightsFromPoint(instance: *runtime.Instance, x: f32, y: f32, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HighlightRegistryImpl.call_highlightsFromPoint(state, x, y, options);
    }

};
