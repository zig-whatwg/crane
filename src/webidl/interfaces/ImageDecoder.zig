//! Generated from: webcodecs.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ImageDecoderImpl = @import("impls").ImageDecoder;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
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
        pub const BaseType = null;
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
            .{ "isTypeSupported", "call_static_isTypeSupported", 1 },
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
            @"type": typedefs.DOMString = undefined,
            complete: bool = undefined,
            completed: runtime.JSValue = undefined,
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
        .call_reset = &call_reset,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ImageDecoderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ImageDecoderImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ImageDecoderImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, init_data: ImageDecoderInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ImageDecoderImpl.call_constructor(ctx, init_data);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try ImageDecoderImpl.get_type(instance);
    }

    pub fn get_complete(instance: *runtime.Instance) anyerror!bool {
        return try ImageDecoderImpl.get_complete(instance);
    }

    pub fn get_completed(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ImageDecoderImpl.get_completed(instance);
    }

    pub fn get_tracks(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ImageDecoderImpl.get_tracks(instance);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try ImageDecoderImpl.call_reset(instance);
    }

    pub fn call_decode(instance: *runtime.Instance, options: webidl.Opt(ImageDecodeOptions)) anyerror!runtime.JSValue {
        
        return try ImageDecoderImpl.call_decode(instance, options);
    }

    pub fn call_static_isTypeSupported(instance: *runtime.Instance, @"type": DOMString) anyerror!runtime.JSValue {
        
        return try ImageDecoderImpl.call_static_isTypeSupported(instance, @"type");
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try ImageDecoderImpl.call_close(instance);
    }

};
