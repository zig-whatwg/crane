//! Generated from: json-ld-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RemoteDocumentImpl = @import("impls").RemoteDocument;

pub const RemoteDocument = struct {
    pub const Meta = struct {
        pub const name = "RemoteDocument";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "JsonLd" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .JsonLd = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            contentType: runtime.USVString = undefined,
            contextUrl: runtime.USVString = undefined,
            document: anyopaque = undefined,
            documentUrl: runtime.USVString = undefined,
            profile: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RemoteDocument, .{
        .deinit_fn = &deinit_wrapper,

        .get_contentType = &get_contentType,
        .get_contextUrl = &get_contextUrl,
        .get_document = &get_document,
        .get_documentUrl = &get_documentUrl,
        .get_profile = &get_profile,

        .set_document = &set_document,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        RemoteDocumentImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RemoteDocumentImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try RemoteDocumentImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_contentType(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RemoteDocumentImpl.get_contentType(instance);
    }

    pub fn get_contextUrl(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RemoteDocumentImpl.get_contextUrl(instance);
    }

    pub fn get_document(instance: *runtime.Instance) anyerror!anyopaque {
        return try RemoteDocumentImpl.get_document(instance);
    }

    pub fn set_document(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try RemoteDocumentImpl.set_document(instance, value);
    }

    pub fn get_documentUrl(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RemoteDocumentImpl.get_documentUrl(instance);
    }

    pub fn get_profile(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RemoteDocumentImpl.get_profile(instance);
    }

};
