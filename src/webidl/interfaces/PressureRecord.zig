//! Generated from: compute-pressure.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PressureRecordImpl = @import("impls").PressureRecord;
const PressureSource = @import("enums").PressureSource;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const PressureState = @import("enums").PressureState;

pub const PressureRecord = struct {
    pub const Meta = struct {
        pub const name = "PressureRecord";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "SharedWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .SharedWorker = true,
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            source: PressureSource = undefined,
            state: PressureState = undefined,
            time: DOMHighResTimeStamp = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PressureRecord, .{
        .deinit_fn = &deinit_wrapper,

        .get_source = &get_source,
        .get_state = &get_state,
        .get_time = &get_time,

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
        PressureRecordImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PressureRecordImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_source(instance: *runtime.Instance) anyerror!PressureSource {
        return try PressureRecordImpl.get_source(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!PressureState {
        return try PressureRecordImpl.get_state(instance);
    }

    pub fn get_time(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try PressureRecordImpl.get_time(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try PressureRecordImpl.call_toJSON(instance);
    }

};
