//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBFactoryImpl = @import("impls").IDBFactory;
const IDBOpenDBRequest = @import("interfaces").IDBOpenDBRequest;
const DOMString = @import("typedefs").DOMString;

pub const IDBFactory = struct {
    pub const Meta = struct {
        pub const name = "IDBFactory";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IDBFactory, .{
        .deinit_fn = &deinit_wrapper,

        .call_cmp = &call_cmp,
        .call_databases = &call_databases,
        .call_deleteDatabase = &call_deleteDatabase,
        .call_open = &call_open,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return IDBFactoryImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBFactoryImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_open(instance: *runtime.Instance, name: DOMString, version: u64) anyerror!IDBOpenDBRequest {
        // [NewObject] - Caller owns the returned object
        // [EnforceRange] on version
        if (!runtime.isInRange(version)) return error.TypeError;
        
        return try IDBFactoryImpl.call_open(instance, name, version);
    }

    pub fn call_databases(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBFactoryImpl.call_databases(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_deleteDatabase(instance: *runtime.Instance, name: DOMString) anyerror!IDBOpenDBRequest {
        // [NewObject] - Caller owns the returned object
        
        return try IDBFactoryImpl.call_deleteDatabase(instance, name);
    }

    pub fn call_cmp(instance: *runtime.Instance, first: anyopaque, second: anyopaque) anyerror!i16 {
        
        return try IDBFactoryImpl.call_cmp(instance, first, second);
    }

};
