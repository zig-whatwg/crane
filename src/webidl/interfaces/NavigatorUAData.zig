//! Generated from: ua-client-hints.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorUADataImpl = @import("impls").NavigatorUAData;
const FrozenArray<NavigatorUABrandVersion> = @import("interfaces").FrozenArray<NavigatorUABrandVersion>;
const Promise<UADataValues> = @import("interfaces").Promise<UADataValues>;
const UALowEntropyJSON = @import("dictionaries").UALowEntropyJSON;

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
        
        // Initialize the instance (Impl receives full instance)
        NavigatorUADataImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorUADataImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_brands(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigatorUADataImpl.get_brands(instance);
    }

    pub fn get_mobile(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorUADataImpl.get_mobile(instance);
    }

    pub fn get_platform(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorUADataImpl.get_platform(instance);
    }

    pub fn call_getHighEntropyValues(instance: *runtime.Instance, hints: anyopaque) anyerror!anyopaque {
        
        return try NavigatorUADataImpl.call_getHighEntropyValues(instance, hints);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyerror!UALowEntropyJSON {
        return try NavigatorUADataImpl.call_toJSON(instance);
    }

};
