//! Generated from: ua-client-hints.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorUADataImpl = @import("../impls/NavigatorUAData.zig");

pub const NavigatorUAData = struct {
    pub const Meta = struct {
        pub const name = "NavigatorUAData";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            brands: FrozenArray<NavigatorUABrandVersion> = undefined,
            mobile: bool = undefined,
            platform: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigatorUAData, .{
        .deinit_fn = &deinit_wrapper,

        .get_brands = &get_brands,
        .get_mobile = &get_mobile,
        .get_platform = &get_platform,

        .call_getHighEntropyValues = &call_getHighEntropyValues,
        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        NavigatorUADataImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NavigatorUADataImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_brands(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorUADataImpl.get_brands(state);
    }

    pub fn get_mobile(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigatorUADataImpl.get_mobile(state);
    }

    pub fn get_platform(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigatorUADataImpl.get_platform(state);
    }

    pub fn call_getHighEntropyValues(instance: *runtime.Instance, hints: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorUADataImpl.call_getHighEntropyValues(state, hints);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorUADataImpl.call_toJSON(state);
    }

};
