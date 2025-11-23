//! Generated from: SVG.idl
//! Generated at: 2025-11-23T19:47:43Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGUnitTypesImpl = @import("impls").SVGUnitTypes;

pub const SVGUnitTypes = struct {
    pub const Meta = struct {
        pub const name = "SVGUnitTypes";
        pub const is_mixin = false;
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "SVG_UNIT_TYPE_UNKNOWN", "get_SVG_UNIT_TYPE_UNKNOWN" },
            .{ "SVG_UNIT_TYPE_USERSPACEONUSE", "get_SVG_UNIT_TYPE_USERSPACEONUSE" },
            .{ "SVG_UNIT_TYPE_OBJECTBOUNDINGBOX", "get_SVG_UNIT_TYPE_OBJECTBOUNDINGBOX" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short SVG_UNIT_TYPE_UNKNOWN = 0;
    pub fn get_SVG_UNIT_TYPE_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_UNIT_TYPE_USERSPACEONUSE = 1;
    pub fn get_SVG_UNIT_TYPE_USERSPACEONUSE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_UNIT_TYPE_OBJECTBOUNDINGBOX = 2;
    pub fn get_SVG_UNIT_TYPE_OBJECTBOUNDINGBOX() u16 {
        return 2;
    }

    const delegates = .{

        .get_SVG_UNIT_TYPE_OBJECTBOUNDINGBOX = &get_SVG_UNIT_TYPE_OBJECTBOUNDINGBOX,
        .get_SVG_UNIT_TYPE_UNKNOWN = &get_SVG_UNIT_TYPE_UNKNOWN,
        .get_SVG_UNIT_TYPE_USERSPACEONUSE = &get_SVG_UNIT_TYPE_USERSPACEONUSE,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGUnitTypesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGUnitTypesImpl.deinit(instance);
    }

};
