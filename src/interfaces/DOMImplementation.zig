//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMImplementationImpl = @import("../impls/DOMImplementation.zig");

pub const DOMImplementation = struct {
    pub const Meta = struct {
        pub const name = "DOMImplementation";
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

    pub const vtable = runtime.buildVTable(DOMImplementation, .{
        .deinit_fn = &deinit_wrapper,

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
        DOMImplementationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DOMImplementationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createDocument(instance: *runtime.Instance, namespace: anyopaque, qualifiedName: runtime.DOMString, doctype: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return DOMImplementationImpl.call_createDocument(state, namespace, qualifiedName, doctype);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createDocumentType(instance: *runtime.Instance, name: runtime.DOMString, publicId: runtime.DOMString, systemId: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return DOMImplementationImpl.call_createDocumentType(state, name, publicId, systemId);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createHTMLDocument(instance: *runtime.Instance, title: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return DOMImplementationImpl.call_createHTMLDocument(state, title);
    }

    pub fn call_hasFeature(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return DOMImplementationImpl.call_hasFeature(state);
    }

};
