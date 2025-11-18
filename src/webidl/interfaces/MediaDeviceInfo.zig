//! Generated from: mediacapture-streams.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaDeviceInfoImpl = @import("impls").MediaDeviceInfo;
const MediaDeviceKind = @import("enums").MediaDeviceKind;

pub const MediaDeviceInfo = struct {
    pub const Meta = struct {
        pub const name = "MediaDeviceInfo";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            deviceId: runtime.DOMString = undefined,
            kind: MediaDeviceKind = undefined,
            label: runtime.DOMString = undefined,
            groupId: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaDeviceInfo, .{
        .deinit_fn = &deinit_wrapper,

        .get_deviceId = &get_deviceId,
        .get_groupId = &get_groupId,
        .get_kind = &get_kind,
        .get_label = &get_label,

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
        MediaDeviceInfoImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaDeviceInfoImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_deviceId(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaDeviceInfoImpl.get_deviceId(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!MediaDeviceKind {
        return try MediaDeviceInfoImpl.get_kind(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaDeviceInfoImpl.get_label(instance);
    }

    pub fn get_groupId(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaDeviceInfoImpl.get_groupId(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try MediaDeviceInfoImpl.call_toJSON(instance);
    }

};
