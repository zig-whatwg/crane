//! Generated from: FileAPI.idl
//! Generated at: 2025-11-28T22:33:21Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FileImpl = @import("impls").File;
const mixins = @import("mixins");
const Blob = @import("interfaces").Blob;
const FilePropertyBag = @import("dictionaries").FilePropertyBag;
const BlobPart = @import("typedefs").BlobPart;
const ReadableStream = @import("interfaces").ReadableStream;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;
const BlobPropertyBag = @import("dictionaries").BlobPropertyBag;

pub const File = struct {
    pub const Meta = struct {
        pub const name = "File";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Blob;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "lastModified", "get_lastModified", null },
            .{ "webkitRelativePath", "get_webkitRelativePath", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "slice",
            "stream",
            "text",
            "arrayBuffer",
            "bytes",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "lastModified", "get_lastModified", null },
            .{ "webkitRelativePath", "get_webkitRelativePath", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: runtime.DOMString = undefined,
            lastModified: i64 = undefined,
            webkitRelativePath: runtime.USVString = undefined,
            _internal: ?*FileImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_lastModified = &get_lastModified,
        .get_name = &get_name,
        .get_webkitRelativePath = &get_webkitRelativePath,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, fileBits: *const anyopaque, fileName: runtime.USVString, options: webidl.Opt(FilePropertyBag)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FileImpl.call_constructor(allocator, ctx, fileBits, fileName, options);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try FileImpl.get_name(instance);
    }

    pub fn get_lastModified(instance: *runtime.Instance) anyerror!i64 {
        return try FileImpl.get_lastModified(instance);
    }

    pub fn get_webkitRelativePath(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileImpl.get_webkitRelativePath(instance);
    }

};
