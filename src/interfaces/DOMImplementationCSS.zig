//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMImplementationCSSImpl = @import("../impls/DOMImplementationCSS.zig");
const DOMImplementation = @import("DOMImplementation.zig");

pub const DOMImplementationCSS = struct {
    pub const Meta = struct {
        pub const name = "DOMImplementationCSS";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DOMImplementation;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DOMImplementationCSS, .{
        .deinit_fn = &deinit_wrapper,

        .call_createCSSStyleSheet = &call_createCSSStyleSheet,
        .call_createDocument = &call_createDocument,
        .call_createDocumentType = &call_createDocumentType,
        .call_createHTMLDocument = &call_createHTMLDocument,
        .call_hasFeature = &call_hasFeature,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        DOMImplementationCSSImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DOMImplementationCSSImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createDocument(instance: *runtime.Instance, namespace: anyopaque, qualifiedName: runtime.DOMString, doctype: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return DOMImplementationCSSImpl.call_createDocument(state, namespace, qualifiedName, doctype);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createDocumentType(instance: *runtime.Instance, name: runtime.DOMString, publicId: runtime.DOMString, systemId: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return DOMImplementationCSSImpl.call_createDocumentType(state, name, publicId, systemId);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createHTMLDocument(instance: *runtime.Instance, title: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return DOMImplementationCSSImpl.call_createHTMLDocument(state, title);
    }

    pub fn call_hasFeature(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return DOMImplementationCSSImpl.call_hasFeature(state);
    }

    pub fn call_createCSSStyleSheet(instance: *runtime.Instance, title: runtime.DOMString, media: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return DOMImplementationCSSImpl.call_createCSSStyleSheet(state, title, media);
    }

};
