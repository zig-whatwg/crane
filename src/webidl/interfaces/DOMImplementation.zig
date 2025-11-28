//! Generated from: dom.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMImplementationImpl = @import("impls").DOMImplementation;
const Document = @import("interfaces").Document;
const DocumentType = @import("interfaces").DocumentType;
const XMLDocument = @import("interfaces").XMLDocument;
const DOMString = @import("typedefs").DOMString;

pub const DOMImplementation = struct {
    pub const Meta = struct {
        pub const name = "DOMImplementation";
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
            .{ "createDocumentType", "call_createDocumentType", 3 },
            .{ "createDocument", "call_createDocument", 2 },
            .{ "createHTMLDocument", "call_createHTMLDocument", 0 },
            .{ "hasFeature", "call_hasFeature", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createDocumentType",
            "createDocument",
            "createHTMLDocument",
            "hasFeature",
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
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*DOMImplementationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_createDocument = &call_createDocument,
        .call_createDocumentType = &call_createDocumentType,
        .call_createHTMLDocument = &call_createHTMLDocument,
        .call_hasFeature = &call_hasFeature,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DOMImplementationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMImplementationImpl.deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createDocument(instance: *runtime.Instance, namespace: DOMString, qualifiedName: DOMString, doctype: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMImplementationImpl.call_createDocument(instance, namespace, qualifiedName, doctype);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createDocumentType(instance: *runtime.Instance, name: DOMString, publicId: DOMString, systemId: DOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMImplementationImpl.call_createDocumentType(instance, name, publicId, systemId);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createHTMLDocument(instance: *runtime.Instance, title: DOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMImplementationImpl.call_createHTMLDocument(instance, title);
    }

    pub fn call_hasFeature(instance: *runtime.Instance) anyerror!bool {
        return try DOMImplementationImpl.call_hasFeature(instance);
    }

};
