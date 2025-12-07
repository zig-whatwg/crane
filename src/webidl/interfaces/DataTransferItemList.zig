//! Generated from: html.idl
//! Generated at: 2025-12-07T19:33:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const DataTransferItemListImpl = @import("impls").DataTransferItemList;
const mixins = @import("mixins");
const DataTransferItem = @import("interfaces").DataTransferItem;
const File = @import("interfaces").File;
const DOMString = @import("typedefs").DOMString;

pub const DataTransferItemList = struct {
    pub const Meta = struct {
        pub const name = "DataTransferItemList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "add", "call_add", 2 },
            .{ "add", "call_add", 1 },
            .{ "remove", "call_remove", 1 },
            .{ "clear", "call_clear", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "add",
            "add",
            "remove",
            "clear",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
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
            length: u32 = undefined,
            _internal: ?*DataTransferItemListImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,

        .call_add = &call_add,
        .call_clear = &call_clear,
        .call_remove = &call_remove,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DataTransferItemListImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DataTransferItemListImpl.deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try DataTransferItemListImpl.get_length(instance);
    }

    pub fn call_add(instance: *runtime.Instance, data: DOMString, @"type": DOMString) anyerror!?*runtime.Instance {
        
        return try DataTransferItemListImpl.call_add(instance, data, @"type");
    }

    pub fn call_remove(instance: *runtime.Instance, index: u32) anyerror!void {
        
        return try DataTransferItemListImpl.call_remove(instance, index);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try DataTransferItemListImpl.call_clear(instance);
    }

};
