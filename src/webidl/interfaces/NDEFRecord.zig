//! Generated from: web-nfc.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NDEFRecordImpl = @import("impls").NDEFRecord;
const sequence = @import("interfaces").sequence;
const DataView = @import("interfaces").DataView;
const USVString = @import("interfaces").USVString;
const NDEFRecordInit = @import("dictionaries").NDEFRecordInit;

pub const NDEFRecord = struct {
    pub const Meta = struct {
        pub const name = "NDEFRecord";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            recordType: runtime.USVString = undefined,
            mediaType: ?runtime.USVString = null,
            id: ?runtime.USVString = null,
            data: ?DataView = null,
            encoding: ?runtime.USVString = null,
            lang: ?runtime.USVString = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NDEFRecord, .{
        .deinit_fn = &deinit_wrapper,

        .get_data = &get_data,
        .get_encoding = &get_encoding,
        .get_id = &get_id,
        .get_lang = &get_lang,
        .get_mediaType = &get_mediaType,
        .get_recordType = &get_recordType,

        .call_toRecords = &call_toRecords,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        NDEFRecordImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NDEFRecordImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, recordInit: NDEFRecordInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try NDEFRecordImpl.constructor(instance, recordInit);
        
        return instance;
    }

    pub fn get_recordType(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try NDEFRecordImpl.get_recordType(instance);
    }

    pub fn get_mediaType(instance: *runtime.Instance) anyerror!anyopaque {
        return try NDEFRecordImpl.get_mediaType(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!anyopaque {
        return try NDEFRecordImpl.get_id(instance);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!anyopaque {
        return try NDEFRecordImpl.get_data(instance);
    }

    pub fn get_encoding(instance: *runtime.Instance) anyerror!anyopaque {
        return try NDEFRecordImpl.get_encoding(instance);
    }

    pub fn get_lang(instance: *runtime.Instance) anyerror!anyopaque {
        return try NDEFRecordImpl.get_lang(instance);
    }

    pub fn call_toRecords(instance: *runtime.Instance) anyerror!anyopaque {
        return try NDEFRecordImpl.call_toRecords(instance);
    }

};
