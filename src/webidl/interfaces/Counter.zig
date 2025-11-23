//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CounterImpl = @import("impls").Counter;
const DOMString = @import("typedefs").DOMString;

pub const Counter = struct {
    pub const Meta = struct {
        pub const name = "Counter";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "identifier", "get_identifier", null },
            .{ "listStyle", "get_listStyle", null },
            .{ "separator", "get_separator", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "identifier", "get_identifier", null },
            .{ "listStyle", "get_listStyle", null },
            .{ "separator", "get_separator", null },
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
            identifier: runtime.DOMString = undefined,
            listStyle: runtime.DOMString = undefined,
            separator: runtime.DOMString = undefined,
            _internal: ?*CounterImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_identifier = &get_identifier,
        .get_listStyle = &get_listStyle,
        .get_separator = &get_separator,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CounterImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CounterImpl.deinit(instance);
    }

    pub fn get_identifier(instance: *runtime.Instance) anyerror!DOMString {
        return try CounterImpl.get_identifier(instance);
    }

    pub fn get_listStyle(instance: *runtime.Instance) anyerror!DOMString {
        return try CounterImpl.get_listStyle(instance);
    }

    pub fn get_separator(instance: *runtime.Instance) anyerror!DOMString {
        return try CounterImpl.get_separator(instance);
    }

};
