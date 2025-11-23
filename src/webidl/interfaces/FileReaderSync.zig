//! Generated from: FileAPI.idl
//! Generated at: 2025-11-23T19:47:43Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileReaderSyncImpl = @import("impls").FileReaderSync;
const Blob = @import("interfaces").Blob;
const DOMString = @import("typedefs").DOMString;

pub const FileReaderSync = struct {
    pub const Meta = struct {
        pub const name = "FileReaderSync";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "SharedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .SharedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "readAsArrayBuffer", "call_readAsArrayBuffer", 1 },
            .{ "readAsBinaryString", "call_readAsBinaryString", 1 },
            .{ "readAsText", "call_readAsText", 1 },
            .{ "readAsDataURL", "call_readAsDataURL", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "readAsArrayBuffer",
            "readAsBinaryString",
            "readAsText",
            "readAsDataURL",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_readAsArrayBuffer = &call_readAsArrayBuffer,
        .call_readAsBinaryString = &call_readAsBinaryString,
        .call_readAsDataURL = &call_readAsDataURL,
        .call_readAsText = &call_readAsText,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileReaderSyncImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileReaderSyncImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FileReaderSyncImpl.call_constructor(allocator, ctx);
    }

    pub fn call_readAsArrayBuffer(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!*const anyopaque {
        
        return try FileReaderSyncImpl.call_readAsArrayBuffer(instance, blob);
    }

    pub fn call_readAsBinaryString(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!DOMString {
        
        return try FileReaderSyncImpl.call_readAsBinaryString(instance, blob);
    }

    pub fn call_readAsDataURL(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!DOMString {
        
        return try FileReaderSyncImpl.call_readAsDataURL(instance, blob);
    }

    pub fn call_readAsText(instance: *runtime.Instance, blob: *runtime.Instance, encoding: DOMString) anyerror!DOMString {
        
        return try FileReaderSyncImpl.call_readAsText(instance, blob, encoding);
    }

};
