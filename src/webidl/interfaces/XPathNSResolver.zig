//! Generated from: dom.idl
//! Generated at: 2025-12-05T20:30:48Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XPathNSResolverImpl = @import("impls").XPathNSResolver;
const mixins = @import("mixins");
const DOMString = @import("typedefs").DOMString;

pub const XPathNSResolver = struct {
    pub const Meta = struct {
        pub const name = "XPathNSResolver";
        pub const is_mixin = false;
        pub const is_callback_interface = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "lookupNamespaceURI", "call_lookupNamespaceURI", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "lookupNamespaceURI",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*XPathNSResolverImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_lookupNamespaceURI = &call_lookupNamespaceURI,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XPathNSResolverImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XPathNSResolverImpl.deinit(instance);
    }

    pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: ?DOMString) anyerror!?DOMString {
        return try XPathNSResolverImpl.call_lookupNamespaceURI(instance, prefix);
    }
};
