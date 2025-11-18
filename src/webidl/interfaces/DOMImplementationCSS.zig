//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMImplementationCSSImpl = @import("impls").DOMImplementationCSS;
const DOMImplementation = @import("interfaces").DOMImplementation;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;

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
        
        // Initialize the instance (Impl receives full instance)
        DOMImplementationCSSImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMImplementationCSSImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createDocument(instance: *runtime.Instance, namespace: anyopaque, qualifiedName: DOMString, doctype: anyopaque) anyerror!XMLDocument {
        // [NewObject] - Caller owns the returned object
        
        return try DOMImplementationCSSImpl.call_createDocument(instance, namespace, qualifiedName, doctype);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createDocumentType(instance: *runtime.Instance, name: DOMString, publicId: DOMString, systemId: DOMString) anyerror!DocumentType {
        // [NewObject] - Caller owns the returned object
        
        return try DOMImplementationCSSImpl.call_createDocumentType(instance, name, publicId, systemId);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createHTMLDocument(instance: *runtime.Instance, title: DOMString) anyerror!Document {
        // [NewObject] - Caller owns the returned object
        
        return try DOMImplementationCSSImpl.call_createHTMLDocument(instance, title);
    }

    pub fn call_hasFeature(instance: *runtime.Instance) anyerror!bool {
        return try DOMImplementationCSSImpl.call_hasFeature(instance);
    }

    pub fn call_createCSSStyleSheet(instance: *runtime.Instance, title: DOMString, media: DOMString) anyerror!CSSStyleSheet {
        
        return try DOMImplementationCSSImpl.call_createCSSStyleSheet(instance, title, media);
    }

};
