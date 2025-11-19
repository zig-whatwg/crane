//! Generated from: dom.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XPathNSResolverImpl = @import("impls").XPathNSResolver;
const DOMString = @import("typedefs").DOMString;

pub const XPathNSResolver = struct {
    pub const Meta = struct {
        pub const name = "XPathNSResolver";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XPathNSResolver, .{
        .deinit_fn = &deinit_wrapper,

        .call_lookupNamespaceURI = &call_lookupNamespaceURI,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return XPathNSResolverImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XPathNSResolverImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: DOMString) anyerror!DOMString {
        
        return try XPathNSResolverImpl.call_lookupNamespaceURI(instance, prefix);
    }

};
