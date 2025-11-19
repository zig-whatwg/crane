//! Generated from: savedata.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NetworkInformationSaveDataImpl = @import("impls").NetworkInformationSaveData;

pub const NetworkInformationSaveData = struct {
    pub const Meta = struct {
        pub const name = "NetworkInformationSaveData";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            saveData: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NetworkInformationSaveData, .{
        .deinit_fn = &deinit_wrapper,

        .get_saveData = &get_saveData,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return NetworkInformationSaveDataImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NetworkInformationSaveDataImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_saveData(instance: *runtime.Instance) anyerror!bool {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_saveData) |cached| {
            return cached;
        }
        const value = try NetworkInformationSaveDataImpl.get_saveData(instance);
        state.cached_saveData = value;
        return value;
    }

};
