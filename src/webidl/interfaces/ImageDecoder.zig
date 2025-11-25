//! Generated from: webcodecs.idl
//! Generated at: 2025-11-25T19:42:24Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageDecoderImpl = @import("impls").ImageDecoder;
const ImageDecodeOptions = @import("dictionaries").ImageDecodeOptions;
const ImageDecoderInit = @import("dictionaries").ImageDecoderInit;
const ImageTrackList = @import("interfaces").ImageTrackList;
const ImageDecodeResult = @import("dictionaries").ImageDecodeResult;
const DOMString = @import("typedefs").DOMString;

pub const ImageDecoder = struct {
    pub const Meta = struct {
        pub const name = "ImageDecoder";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", null },
            .{ "complete", "get_complete", null },
            .{ "completed", "get_completed", null },
            .{ "tracks", "get_tracks", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "decode", "call_decode", 0 },
            .{ "reset", "call_reset", 0 },
            .{ "close", "call_close", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "isTypeSupported", "call_isTypeSupported", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "decode",
            "reset",
            "close",
            "isTypeSupported",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "complete", "get_complete", null },
            .{ "completed", "get_completed", null },
            .{ "tracks", "get_tracks", null },
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
            @"type": runtime.DOMString = undefined,
            complete: bool = undefined,
            completed: runtime.Promise(void) = undefined,
            tracks: *runtime.Instance = undefined,
            _internal: ?*ImageDecoderImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_complete = &get_complete,
        .get_completed = &get_completed,
        .get_tracks = &get_tracks,
        .get_type = &get_type,

        .call_close = &call_close,
        .call_decode = &call_decode,
        .call_isTypeSupported = &call_isTypeSupported,
        .call_reset = &call_reset,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ImageDecoderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ImageDecoderImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: ImageDecoderInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ImageDecoderImpl.call_constructor(allocator, ctx, init_data);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try ImageDecoderImpl.get_type(instance);
    }

    pub fn get_complete(instance: *runtime.Instance) anyerror!bool {
        return try ImageDecoderImpl.get_complete(instance);
    }

    pub fn get_completed(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ImageDecoderImpl.get_completed(instance);
    }

    pub fn get_tracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ImageDecoderImpl.get_tracks(instance);
    }

    pub fn call_decode(instance: *runtime.Instance, options: ImageDecodeOptions) anyerror!*const anyopaque {
        
        return try ImageDecoderImpl.call_decode(instance, options);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try ImageDecoderImpl.call_reset(instance);
    }

    pub fn call_isTypeSupported(instance: *runtime.Instance, @"type": DOMString) anyerror!*const anyopaque {
        
        return try ImageDecoderImpl.call_isTypeSupported(instance, @"type");
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try ImageDecoderImpl.call_close(instance);
    }

};
