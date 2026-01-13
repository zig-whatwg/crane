//! Generated from: trusted-types.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TrustedTypePolicyImpl = @import("impls").TrustedTypePolicy;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const TrustedHTML = @import("TrustedHTML.zig").TrustedHTML;
const TrustedScript = @import("TrustedScript.zig").TrustedScript;
const TrustedScriptURL = @import("TrustedScriptURL.zig").TrustedScriptURL;
const DOMString = @import("typedefs").DOMString;

pub const TrustedTypePolicy = struct {
    pub const Meta = struct {
        pub const name = "TrustedTypePolicy";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createHTML", "call_createHTML", 1 },
            .{ "createScript", "call_createScript", 1 },
            .{ "createScriptURL", "call_createScriptURL", 1 },
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: typedefs.DOMString = undefined,
            _internal: ?*TrustedTypePolicyImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_name = &get_name,

        .call_createHTML = &call_createHTML,
        .call_createScript = &call_createScript,
        .call_createScriptURL = &call_createScriptURL,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TrustedTypePolicyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return TrustedTypePolicyImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TrustedTypePolicyImpl.deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try TrustedTypePolicyImpl.get_name(instance);
    }

    pub fn call_createHTML(instance: *runtime.Instance, input: DOMString, arguments: []const runtime.JSValue) anyerror!*runtime.Instance {
        
        return try TrustedTypePolicyImpl.call_createHTML(instance, input, arguments);
    }

    pub fn call_createScript(instance: *runtime.Instance, input: DOMString, arguments: []const runtime.JSValue) anyerror!*runtime.Instance {
        
        return try TrustedTypePolicyImpl.call_createScript(instance, input, arguments);
    }

    pub fn call_createScriptURL(instance: *runtime.Instance, input: DOMString, arguments: []const runtime.JSValue) anyerror!*runtime.Instance {
        
        return try TrustedTypePolicyImpl.call_createScriptURL(instance, input, arguments);
    }

};
