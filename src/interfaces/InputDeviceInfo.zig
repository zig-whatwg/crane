//! Generated from: mediacapture-streams.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InputDeviceInfoImpl = @import("../impls/InputDeviceInfo.zig");
const MediaDeviceInfo = @import("MediaDeviceInfo.zig");

pub const InputDeviceInfo = struct {
    pub const Meta = struct {
        pub const name = "InputDeviceInfo";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *MediaDeviceInfo;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(InputDeviceInfo, .{
        .deinit_fn = &deinit_wrapper,

        .get_deviceId = &get_deviceId,
        .get_groupId = &get_groupId,
        .get_kind = &get_kind,
        .get_label = &get_label,

        .call_getCapabilities = &call_getCapabilities,
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
        InputDeviceInfoImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        InputDeviceInfoImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_deviceId(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return InputDeviceInfoImpl.get_deviceId(state);
    }

    pub fn get_kind(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return InputDeviceInfoImpl.get_kind(state);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return InputDeviceInfoImpl.get_label(state);
    }

    pub fn get_groupId(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return InputDeviceInfoImpl.get_groupId(state);
    }

    pub fn call_getCapabilities(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return InputDeviceInfoImpl.call_getCapabilities(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return InputDeviceInfoImpl.call_toJSON(state);
    }

};
