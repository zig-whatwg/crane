//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBRecordImpl = @import("../impls/IDBRecord.zig");

pub const IDBRecord = struct {
    pub const Meta = struct {
        pub const name = "IDBRecord";
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
            key: anyopaque = undefined,
            primaryKey: anyopaque = undefined,
            value: anyopaque = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IDBRecord, .{
        .deinit_fn = &deinit_wrapper,

        .get_key = &get_key,
        .get_primaryKey = &get_primaryKey,
        .get_value = &get_value,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        IDBRecordImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        IDBRecordImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_key(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBRecordImpl.get_key(state);
    }

    pub fn get_primaryKey(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBRecordImpl.get_primaryKey(state);
    }

    pub fn get_value(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBRecordImpl.get_value(state);
    }

};
