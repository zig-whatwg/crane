//! Generated from: body-tracking.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRBodyImpl = @import("impls").XRBody;
const XRBodyJoint = @import("enums").XRBodyJoint;
const XRBodySpace = @import("interfaces").XRBodySpace;

pub const XRBody = struct {
    pub const Meta = struct {
        pub const name = "XRBody";
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
            size: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRBody, .{
        .deinit_fn = &deinit_wrapper,

        .get_size = &get_size,

        .call_get = &call_get,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        XRBodyImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRBodyImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try XRBodyImpl.get_size(instance);
    }

    pub fn call_get(instance: *runtime.Instance, key: XRBodyJoint) anyerror!XRBodySpace {
        
        return try XRBodyImpl.call_get(instance, key);
    }

};
