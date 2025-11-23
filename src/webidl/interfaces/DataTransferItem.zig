//! Generated from: html.idl
//! Generated at: 2025-11-23T16:59:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DataTransferItemImpl = @import("impls").DataTransferItem;
const FileSystemHandle = @import("interfaces").FileSystemHandle;
const FunctionStringCallback = @import("callbacks").FunctionStringCallback;
const FileSystemEntry = @import("interfaces").FileSystemEntry;
const File = @import("interfaces").File;
const DOMString = @import("typedefs").DOMString;

pub const DataTransferItem = struct {
    pub const Meta = struct {
        pub const name = "DataTransferItem";
        pub const is_mixin = false;
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
            .{ "kind", "get_kind", null },
            .{ "type", "get_type", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getAsString", "call_getAsString", 1 },
            .{ "getAsFile", "call_getAsFile", 0 },
            .{ "getAsFileSystemHandle", "call_getAsFileSystemHandle", 0 },
            .{ "webkitGetAsEntry", "call_webkitGetAsEntry", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getAsString",
            "getAsFile",
            "getAsFileSystemHandle",
            "webkitGetAsEntry",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "kind", "get_kind", null },
            .{ "type", "get_type", null },
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
            kind: runtime.DOMString = undefined,
            @"type": runtime.DOMString = undefined,
            _internal: ?*DataTransferItemImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_kind = &get_kind,
        .get_type = &get_type,

        .call_getAsFile = &call_getAsFile,
        .call_getAsFileSystemHandle = &call_getAsFileSystemHandle,
        .call_getAsString = &call_getAsString,
        .call_webkitGetAsEntry = &call_webkitGetAsEntry,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DataTransferItemImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DataTransferItemImpl.deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!DOMString {
        return try DataTransferItemImpl.get_kind(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try DataTransferItemImpl.get_type(instance);
    }

    pub fn call_getAsString(instance: *runtime.Instance, _callback: FunctionStringCallback) anyerror!void {
        
        return try DataTransferItemImpl.call_getAsString(instance, _callback);
    }

    pub fn call_getAsFileSystemHandle(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try DataTransferItemImpl.call_getAsFileSystemHandle(instance);
    }

    pub fn call_webkitGetAsEntry(instance: *runtime.Instance) anyerror!FileSystemEntry {
        return try DataTransferItemImpl.call_webkitGetAsEntry(instance);
    }

    pub fn call_getAsFile(instance: *runtime.Instance) anyerror!File {
        return try DataTransferItemImpl.call_getAsFile(instance);
    }

};
