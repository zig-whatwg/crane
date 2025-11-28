//! Generated from: dom.idl
//! Generated at: 2025-11-28T19:51:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NonElementParentNodeImpl = @import("impls").NonElementParentNode;
const mixins = @import("mixins");
const Element = @import("interfaces").Element;
const DOMString = @import("typedefs").DOMString;

pub const NonElementParentNode = struct {
    pub const Meta = struct {
        pub const name = "NonElementParentNode";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getElementById", "call_getElementById", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getElementById",
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
        struct {
            _internal: ?*NonElementParentNodeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_getElementById = &call_getElementById,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NonElementParentNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NonElementParentNodeImpl.deinit(instance);
    }

    pub fn call_getElementById(instance: *runtime.Instance, elementId: DOMString) anyerror!?*runtime.Instance {
        
        return try NonElementParentNodeImpl.call_getElementById(instance, elementId);
    }

};
