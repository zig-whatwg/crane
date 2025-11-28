//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-28T18:02:26Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBCursorWithValueImpl = @import("impls").IDBCursorWithValue;
const IDBCursor = @import("interfaces").IDBCursor;
const IDBRequest = @import("interfaces").IDBRequest;
const IDBIndex = @import("interfaces").IDBIndex;
const IDBCursorDirection = @import("enums").IDBCursorDirection;
const IDBObjectStore = @import("interfaces").IDBObjectStore;

pub const IDBCursorWithValue = struct {
    pub const Meta = struct {
        pub const name = "IDBCursorWithValue";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *IDBCursor;
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
            "advance",
            "continue",
            "continuePrimaryKey",
            "update",
            "delete",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            value: *const anyopaque = undefined,
            _internal: ?*IDBCursorWithValueImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_value = &get_value,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IDBCursorWithValueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBCursorWithValueImpl.deinit(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try IDBCursorWithValueImpl.get_value(instance);
    }

};
