//! Generated from: json-ld-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RemoteDocumentImpl = @import("../impls/RemoteDocument.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        RemoteDocumentImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RemoteDocumentImpl.deinit(state);
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
        try RemoteDocumentImpl.constructor(state);
        
        return instance;
    }

    pub fn get_contentType(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return RemoteDocumentImpl.get_contentType(state);
    }

    pub fn get_contextUrl(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return RemoteDocumentImpl.get_contextUrl(state);
    }

    pub fn get_document(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RemoteDocumentImpl.get_document(state);
    }

    pub fn set_document(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RemoteDocumentImpl.set_document(state, value);
    }

    pub fn get_documentUrl(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return RemoteDocumentImpl.get_documentUrl(state);
    }

    pub fn get_profile(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return RemoteDocumentImpl.get_profile(state);
    }

};
