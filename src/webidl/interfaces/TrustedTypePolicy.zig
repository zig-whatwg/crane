//! Generated from: trusted-types.idl
//! Generated at: 2025-11-23T16:59:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TrustedTypePolicyImpl = @import("impls").TrustedTypePolicy;
const TrustedHTML = @import("interfaces").TrustedHTML;
const TrustedScript = @import("interfaces").TrustedScript;
const TrustedScriptURL = @import("interfaces").TrustedScriptURL;
const DOMString = @import("typedefs").DOMString;

pub const TrustedTypePolicy = struct {
    pub const Meta = struct {
        pub const name = "TrustedTypePolicy";
        pub const is_mixin = false;
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
            .{ "name", "get_name", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "createHTML", "call_createHTML", 2 },
            .{ "createScript", "call_createScript", 2 },
            .{ "createScriptURL", "call_createScriptURL", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createHTML",
            "createScript",
            "createScriptURL",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
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
            name: runtime.DOMString = undefined,
            _internal: ?*TrustedTypePolicyImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_name = &get_name,

        .call_createHTML = &call_createHTML,
        .call_createScript = &call_createScript,
        .call_createScriptURL = &call_createScriptURL,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TrustedTypePolicyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TrustedTypePolicyImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try TrustedTypePolicyImpl.get_name(instance);
    }

    pub fn call_createScriptURL(instance: *runtime.Instance, input: DOMString, arguments: *const anyopaque) anyerror!TrustedScriptURL {
        
        return try TrustedTypePolicyImpl.call_createScriptURL(instance, input, arguments);
    }

    pub fn call_createHTML(instance: *runtime.Instance, input: DOMString, arguments: *const anyopaque) anyerror!TrustedHTML {
        
        return try TrustedTypePolicyImpl.call_createHTML(instance, input, arguments);
    }

    pub fn call_createScript(instance: *runtime.Instance, input: DOMString, arguments: *const anyopaque) anyerror!TrustedScript {
        
        return try TrustedTypePolicyImpl.call_createScript(instance, input, arguments);
    }

};
