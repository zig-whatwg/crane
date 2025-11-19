//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMParserImpl = @import("impls").DOMParser;
const Document = @import("interfaces").Document;
const TrustedHTML = @import("interfaces").TrustedHTML;
const DOMString = @import("typedefs").DOMString;
const DOMParserSupportedType = @import("enums").DOMParserSupportedType;

pub const DOMParser = struct {
    pub const Meta = struct {
        pub const name = "DOMParser";
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

    pub const vtable = runtime.buildVTable(DOMParser, .{
        .deinit_fn = &deinit_wrapper,

        .call_parseFromString = &call_parseFromString,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return DOMParserImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMParserImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try DOMParserImpl.constructor(instance);
        
        return instance;
    }

    /// Extended attributes: [NewObject]
    pub fn call_parseFromString(instance: *runtime.Instance, string: anyopaque, @"type": DOMParserSupportedType) anyerror!Document {
        // [NewObject] - Caller owns the returned object
        
        return try DOMParserImpl.call_parseFromString(instance, string, @"type");
    }

};
