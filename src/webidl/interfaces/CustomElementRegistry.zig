//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CustomElementRegistryImpl = @import("impls").CustomElementRegistry;
const ElementDefinitionOptions = @import("dictionaries").ElementDefinitionOptions;
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;
const CustomElementConstructor = @import("callbacks").CustomElementConstructor;

pub const CustomElementRegistry = struct {
    pub const Meta = struct {
        pub const name = "CustomElementRegistry";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CustomElementRegistry, .{
        .deinit_fn = &deinit_wrapper,

        .call_define = &call_define,
        .call_get = &call_get,
        .call_getName = &call_getName,
        .call_initialize = &call_initialize,
        .call_upgrade = &call_upgrade,
        .call_whenDefined = &call_whenDefined,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return CustomElementRegistryImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CustomElementRegistryImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CustomElementRegistryImpl.constructor(instance);
        
        return instance;
    }

    /// Extended attributes: [CEReactions]
    pub fn call_define(instance: *runtime.Instance, name: DOMString, constructor: CustomElementConstructor, options: ElementDefinitionOptions) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CustomElementRegistryImpl.call_define(instance, name, constructor, options);
    }

    pub fn call_get(instance: *runtime.Instance, name: DOMString) anyerror!anyopaque {
        
        return try CustomElementRegistryImpl.call_get(instance, name);
    }

    pub fn call_getName(instance: *runtime.Instance, constructor: CustomElementConstructor) anyerror!DOMString {
        
        return try CustomElementRegistryImpl.call_getName(instance, constructor);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_upgrade(instance: *runtime.Instance, root: Node) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try CustomElementRegistryImpl.call_upgrade(instance, root);
    }

    pub fn call_initialize(instance: *runtime.Instance, root: Node) anyerror!void {
        
        return try CustomElementRegistryImpl.call_initialize(instance, root);
    }

    pub fn call_whenDefined(instance: *runtime.Instance, name: DOMString) anyerror!anyopaque {
        
        return try CustomElementRegistryImpl.call_whenDefined(instance, name);
    }

};
