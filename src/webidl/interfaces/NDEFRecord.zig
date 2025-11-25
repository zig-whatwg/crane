//! Generated from: web-nfc.idl
//! Generated at: 2025-11-25T13:07:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NDEFRecordImpl = @import("impls").NDEFRecord;
const USVString = @import("interfaces").USVString;
const NDEFRecordInit = @import("dictionaries").NDEFRecordInit;

pub const NDEFRecord = struct {
    pub const Meta = struct {
        pub const name = "NDEFRecord";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "recordType", "get_recordType", null },
            .{ "mediaType", "get_mediaType", null },
            .{ "id", "get_id", null },
            .{ "data", "get_data", null },
            .{ "encoding", "get_encoding", null },
            .{ "lang", "get_lang", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "toRecords", "call_toRecords", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toRecords",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "recordType", "get_recordType", null },
            .{ "mediaType", "get_mediaType", null },
            .{ "id", "get_id", null },
            .{ "data", "get_data", null },
            .{ "encoding", "get_encoding", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
            .{ "lang", "get_lang", null },
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            recordType: runtime.USVString = undefined,
            mediaType: ?runtime.USVString = null,
            id: ?runtime.USVString = null,
            data: ?runtime.DataView = null,
            encoding: ?runtime.USVString = null,
            lang: ?runtime.USVString = null,
            _internal: ?*NDEFRecordImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_data = &get_data,
        .get_encoding = &get_encoding,
        .get_id = &get_id,
        .get_lang = &get_lang,
        .get_mediaType = &get_mediaType,
        .get_recordType = &get_recordType,

        .call_toRecords = &call_toRecords,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NDEFRecordImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NDEFRecordImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, recordInit: NDEFRecordInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try NDEFRecordImpl.call_constructor(allocator, ctx, recordInit);
    }

    pub fn get_recordType(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try NDEFRecordImpl.get_recordType(instance);
    }

    pub fn get_mediaType(instance: *runtime.Instance) anyerror!?runtime.USVString {
        return try NDEFRecordImpl.get_mediaType(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!?runtime.USVString {
        return try NDEFRecordImpl.get_id(instance);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try NDEFRecordImpl.get_data(instance);
    }

    pub fn get_encoding(instance: *runtime.Instance) anyerror!?runtime.USVString {
        return try NDEFRecordImpl.get_encoding(instance);
    }

    pub fn get_lang(instance: *runtime.Instance) anyerror!?runtime.USVString {
        return try NDEFRecordImpl.get_lang(instance);
    }

    pub fn call_toRecords(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try NDEFRecordImpl.call_toRecords(instance);
    }

};
