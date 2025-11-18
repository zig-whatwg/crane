//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XSLTProcessorImpl = @import("../impls/XSLTProcessor.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        XSLTProcessorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XSLTProcessorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try XSLTProcessorImpl.constructor(state);
        
        return instance;
    }

    /// Extended attributes: [CEReactions]
    pub fn call_transformToDocument(instance: *runtime.Instance, source: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return XSLTProcessorImpl.call_transformToDocument(state, source);
    }

    pub fn call_getParameter(instance: *runtime.Instance, namespaceURI: runtime.DOMString, localName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return XSLTProcessorImpl.call_getParameter(state, namespaceURI, localName);
    }

    pub fn call_removeParameter(instance: *runtime.Instance, namespaceURI: runtime.DOMString, localName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return XSLTProcessorImpl.call_removeParameter(state, namespaceURI, localName);
    }

    pub fn call_setParameter(instance: *runtime.Instance, namespaceURI: runtime.DOMString, localName: runtime.DOMString, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XSLTProcessorImpl.call_setParameter(state, namespaceURI, localName, value);
    }

    pub fn call_importStylesheet(instance: *runtime.Instance, style: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XSLTProcessorImpl.call_importStylesheet(state, style);
    }

    pub fn call_clearParameters(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XSLTProcessorImpl.call_clearParameters(state);
    }

    pub fn call_reset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XSLTProcessorImpl.call_reset(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_transformToFragment(instance: *runtime.Instance, source: anyopaque, output: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return XSLTProcessorImpl.call_transformToFragment(state, source, output);
    }

};
