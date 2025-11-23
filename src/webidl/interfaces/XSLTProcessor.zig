//! Generated from: dom.idl
//! Generated at: 2025-11-23T01:22:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XSLTProcessorImpl = @import("impls").XSLTProcessor;
const DocumentFragment = @import("interfaces").DocumentFragment;
const Document = @import("interfaces").Document;
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;

pub const XSLTProcessor = struct {
    pub const Meta = struct {
        pub const name = "XSLTProcessor";
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
            .{ "importStylesheet", "call_importStylesheet", 1 },
            .{ "transformToFragment", "call_transformToFragment", 2 },
            .{ "transformToDocument", "call_transformToDocument", 1 },
            .{ "setParameter", "call_setParameter", 3 },
            .{ "getParameter", "call_getParameter", 2 },
            .{ "removeParameter", "call_removeParameter", 2 },
            .{ "clearParameters", "call_clearParameters", 0 },
            .{ "reset", "call_reset", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "importStylesheet",
            "transformToFragment",
            "transformToDocument",
            "setParameter",
            "getParameter",
            "removeParameter",
            "clearParameters",
            "reset",
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
        struct {},
    );

    const delegates = .{

        .call_clearParameters = &call_clearParameters,
        .call_getParameter = &call_getParameter,
        .call_importStylesheet = &call_importStylesheet,
        .call_removeParameter = &call_removeParameter,
        .call_reset = &call_reset,
        .call_setParameter = &call_setParameter,
        .call_transformToDocument = &call_transformToDocument,
        .call_transformToFragment = &call_transformToFragment,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XSLTProcessorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XSLTProcessorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XSLTProcessorImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_transformToDocument(instance: *runtime.Instance, source: Node) anyerror!Document {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try XSLTProcessorImpl.call_transformToDocument(instance, source);
    }

    pub fn call_getParameter(instance: *runtime.Instance, namespaceURI: DOMString, localName: DOMString) anyerror!*const anyopaque {
        
        return try XSLTProcessorImpl.call_getParameter(instance, namespaceURI, localName);
    }

    pub fn call_removeParameter(instance: *runtime.Instance, namespaceURI: DOMString, localName: DOMString) anyerror!void {
        
        return try XSLTProcessorImpl.call_removeParameter(instance, namespaceURI, localName);
    }

    pub fn call_setParameter(instance: *runtime.Instance, namespaceURI: DOMString, localName: DOMString, value: *const anyopaque) anyerror!void {
        
        return try XSLTProcessorImpl.call_setParameter(instance, namespaceURI, localName, value);
    }

    pub fn call_importStylesheet(instance: *runtime.Instance, style: Node) anyerror!void {
        
        return try XSLTProcessorImpl.call_importStylesheet(instance, style);
    }

    pub fn call_clearParameters(instance: *runtime.Instance) anyerror!void {
        return try XSLTProcessorImpl.call_clearParameters(instance);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try XSLTProcessorImpl.call_reset(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_transformToFragment(instance: *runtime.Instance, source: Node, output: Document) anyerror!DocumentFragment {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try XSLTProcessorImpl.call_transformToFragment(instance, source, output);
    }

};
