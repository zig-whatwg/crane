//! Generated from: SVG.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GetSVGDocumentImpl = @import("impls").GetSVGDocument;
const Document = @import("interfaces").Document;

pub const GetSVGDocument = struct {
    pub const Meta = struct {
        pub const name = "GetSVGDocument";
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

    pub const vtable = runtime.buildVTable(GetSVGDocument, .{
        .deinit_fn = &deinit_wrapper,

        .call_getSVGDocument = &call_getSVGDocument,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return GetSVGDocumentImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GetSVGDocumentImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getSVGDocument(instance: *runtime.Instance) anyerror!Document {
        return try GetSVGDocumentImpl.call_getSVGDocument(instance);
    }

};
