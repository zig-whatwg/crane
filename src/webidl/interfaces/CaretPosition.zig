//! Generated from: cssom-view.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CaretPositionImpl = @import("impls").CaretPosition;
const DOMRect = @import("interfaces").DOMRect;
const Node = @import("interfaces").Node;

pub const CaretPosition = struct {
    pub const Meta = struct {
        pub const name = "CaretPosition";
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
            offsetNode: Node = undefined,
            offset: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CaretPosition, .{
        .deinit_fn = &deinit_wrapper,

        .get_offset = &get_offset,
        .get_offsetNode = &get_offsetNode,

        .call_getClientRect = &call_getClientRect,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CaretPositionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CaretPositionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_offsetNode(instance: *runtime.Instance) anyerror!Node {
        return try CaretPositionImpl.get_offsetNode(instance);
    }

    pub fn get_offset(instance: *runtime.Instance) anyerror!u32 {
        return try CaretPositionImpl.get_offset(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getClientRect(instance: *runtime.Instance) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        return try CaretPositionImpl.call_getClientRect(instance);
    }

};
