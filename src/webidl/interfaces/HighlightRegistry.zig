//! Generated from: css-highlight-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HighlightRegistryImpl = @import("impls").HighlightRegistry;
const HighlightsFromPointOptions = @import("dictionaries").HighlightsFromPointOptions;

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
        
        // Initialize the instance (Impl receives full instance)
        HighlightRegistryImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HighlightRegistryImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_highlightsFromPoint(instance: *runtime.Instance, x: f32, y: f32, options: HighlightsFromPointOptions) anyerror!anyopaque {
        
        return try HighlightRegistryImpl.call_highlightsFromPoint(instance, x, y, options);
    }

};
