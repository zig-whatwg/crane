//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-28T22:33:21Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IDBRecordImpl = @import("impls").IDBRecord;
const mixins = @import("mixins");

pub const IDBRecord = struct {
    pub const Meta = struct {
        pub const name = "IDBRecord";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "key", "get_key", null },
            .{ "primaryKey", "get_primaryKey", null },
            .{ "value", "get_value", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "key", "get_key", null },
            .{ "primaryKey", "get_primaryKey", null },
            .{ "value", "get_value", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            key: *const anyopaque = undefined,
            primaryKey: *const anyopaque = undefined,
            value: *const anyopaque = undefined,
            _internal: ?*IDBRecordImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_key = &get_key,
        .get_primaryKey = &get_primaryKey,
        .get_value = &get_value,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IDBRecordImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBRecordImpl.deinit(instance);
    }

    pub fn get_key(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try IDBRecordImpl.get_key(instance);
    }

    pub fn get_primaryKey(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try IDBRecordImpl.get_primaryKey(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try IDBRecordImpl.get_value(instance);
    }

};
