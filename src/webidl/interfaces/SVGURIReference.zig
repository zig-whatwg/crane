//! Generated from: SVG.idl
//! Generated at: 2025-11-25T13:07:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGURIReferenceImpl = @import("impls").SVGURIReference;
const SVGAnimatedString = @import("interfaces").SVGAnimatedString;

pub const SVGURIReference = struct {
    pub const Meta = struct {
        pub const name = "SVGURIReference";
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "href", "get_href", null },
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
            .{ "href", "get_href", null },
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
            href: *runtime.Instance = undefined,
            cached_href: ?*runtime.Instance = null,
            _internal: ?*SVGURIReferenceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_href = &get_href,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGURIReferenceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGURIReferenceImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_href(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_href) |cached| {
            return cached;
        }
        const value = try SVGURIReferenceImpl.get_href(instance);
        state.own.cached_href = value;
        return value;
    }

};
