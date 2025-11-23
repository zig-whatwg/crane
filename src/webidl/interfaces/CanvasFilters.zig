//! Generated from: html.idl
//! Generated at: 2025-11-23T14:26:30Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasFiltersImpl = @import("impls").CanvasFilters;
const DOMString = @import("typedefs").DOMString;

pub const CanvasFilters = struct {
    pub const Meta = struct {
        pub const name = "CanvasFilters";
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "filter", "get_filter", "set_filter" },
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
            .{ "filter", "get_filter", "set_filter" },
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
            filter: runtime.DOMString = undefined,
            _internal: ?*CanvasFiltersImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_filter = &get_filter,

        .set_filter = &set_filter,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasFiltersImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasFiltersImpl.deinit(instance);
    }

    pub fn get_filter(instance: *runtime.Instance) anyerror!DOMString {
        return try CanvasFiltersImpl.get_filter(instance);
    }

    pub fn set_filter(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CanvasFiltersImpl.set_filter(instance, value);
    }

};
