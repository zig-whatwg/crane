//! Generated from: html.idl
//! Generated at: 2025-11-28T22:33:20Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CustomElementRegistryImpl = @import("impls").CustomElementRegistry;
const mixins = @import("mixins");
const ElementDefinitionOptions = @import("dictionaries").ElementDefinitionOptions;
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;
const CustomElementConstructor = @import("callbacks").CustomElementConstructor;

pub const CustomElementRegistry = struct {
    pub const Meta = struct {
        pub const name = "CustomElementRegistry";
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "define", "call_define", 2 },
            .{ "get", "call_get", 1 },
            .{ "getName", "call_getName", 1 },
            .{ "whenDefined", "call_whenDefined", 1 },
            .{ "upgrade", "call_upgrade", 1 },
            .{ "initialize", "call_initialize", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "define",
            "get",
            "getName",
            "whenDefined",
            "upgrade",
            "initialize",
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
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*CustomElementRegistryImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_define = &call_define,
        .call_get = &call_get,
        .call_getName = &call_getName,
        .call_initialize = &call_initialize,
        .call_upgrade = &call_upgrade,
        .call_whenDefined = &call_whenDefined,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CustomElementRegistryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CustomElementRegistryImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CustomElementRegistryImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_define(instance: *runtime.Instance, name: DOMString, constructor: CustomElementConstructor, options: webidl.Opt(ElementDefinitionOptions)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CustomElementRegistryImpl.call_define(instance, name, constructor, options);
    }

    pub fn call_get(instance: *runtime.Instance, name: DOMString) anyerror!*const anyopaque {
        
        return try CustomElementRegistryImpl.call_get(instance, name);
    }

    pub fn call_getName(instance: *runtime.Instance, constructor: CustomElementConstructor) anyerror!?DOMString {
        
        return try CustomElementRegistryImpl.call_getName(instance, constructor);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_upgrade(instance: *runtime.Instance, root: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CustomElementRegistryImpl.call_upgrade(instance, root);
    }

    pub fn call_initialize(instance: *runtime.Instance, root: *runtime.Instance) anyerror!void {
        
        return try CustomElementRegistryImpl.call_initialize(instance, root);
    }

    pub fn call_whenDefined(instance: *runtime.Instance, name: DOMString) anyerror!*const anyopaque {
        
        return try CustomElementRegistryImpl.call_whenDefined(instance, name);
    }

};
