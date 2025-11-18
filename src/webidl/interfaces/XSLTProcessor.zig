//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XSLTProcessorImpl = @import("impls").XSLTProcessor;
const DocumentFragment = @import("interfaces").DocumentFragment;
const Document = @import("interfaces").Document;
const Node = @import("interfaces").Node;

pub const XSLTProcessor = struct {
    pub const Meta = struct {
        pub const name = "XSLTProcessor";
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

    pub const vtable = runtime.buildVTable(XSLTProcessor, .{
        .deinit_fn = &deinit_wrapper,

        .call_clearParameters = &call_clearParameters,
        .call_getParameter = &call_getParameter,
        .call_importStylesheet = &call_importStylesheet,
        .call_removeParameter = &call_removeParameter,
        .call_reset = &call_reset,
        .call_setParameter = &call_setParameter,
        .call_transformToDocument = &call_transformToDocument,
        .call_transformToFragment = &call_transformToFragment,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        XSLTProcessorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XSLTProcessorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try XSLTProcessorImpl.constructor(instance);
        
        return instance;
    }

    /// Extended attributes: [CEReactions]
    pub fn call_transformToDocument(instance: *runtime.Instance, source: Node) anyerror!Document {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try XSLTProcessorImpl.call_transformToDocument(instance, source);
    }

    pub fn call_getParameter(instance: *runtime.Instance, namespaceURI: DOMString, localName: DOMString) anyerror!anyopaque {
        
        return try XSLTProcessorImpl.call_getParameter(instance, namespaceURI, localName);
    }

    pub fn call_removeParameter(instance: *runtime.Instance, namespaceURI: DOMString, localName: DOMString) anyerror!void {
        
        return try XSLTProcessorImpl.call_removeParameter(instance, namespaceURI, localName);
    }

    pub fn call_setParameter(instance: *runtime.Instance, namespaceURI: DOMString, localName: DOMString, value: anyopaque) anyerror!void {
        
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
