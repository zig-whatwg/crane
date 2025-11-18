//! Generated from: resize-observer.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ResizeObserverSizeImpl = @import("impls").ResizeObserverSize;

pub const ResizeObserverSize = struct {
    pub const Meta = struct {
        pub const name = "ResizeObserverSize";
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
        struct {
            inlineSize: f64 = undefined,
            blockSize: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ResizeObserverSize, .{
        .deinit_fn = &deinit_wrapper,

        .get_blockSize = &get_blockSize,
        .get_inlineSize = &get_inlineSize,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ResizeObserverSizeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ResizeObserverSizeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_inlineSize(instance: *runtime.Instance) anyerror!f64 {
        return try ResizeObserverSizeImpl.get_inlineSize(instance);
    }

    pub fn get_blockSize(instance: *runtime.Instance) anyerror!f64 {
        return try ResizeObserverSizeImpl.get_blockSize(instance);
    }

};
