//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XMLSerializerImpl = @import("impls").XMLSerializer;
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;

pub const XMLSerializer = struct {
    pub const Meta = struct {
        pub const name = "XMLSerializer";
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

    pub const vtable = runtime.buildVTable(XMLSerializer, .{
        .deinit_fn = &deinit_wrapper,

        .call_serializeToString = &call_serializeToString,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return XMLSerializerImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XMLSerializerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try XMLSerializerImpl.constructor(instance);
        
        return instance;
    }

    pub fn call_serializeToString(instance: *runtime.Instance, root: Node) anyerror!DOMString {
        
        return try XMLSerializerImpl.call_serializeToString(instance, root);
    }

};
