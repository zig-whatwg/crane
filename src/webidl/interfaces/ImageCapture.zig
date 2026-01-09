//! Generated from: image-capture.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ImageCaptureImpl = @import("impls").ImageCapture;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PhotoSettings = @import("dictionaries").PhotoSettings;
const MediaStreamTrack = @import("MediaStreamTrack.zig").MediaStreamTrack;
const PhotoCapabilities = @import("dictionaries").PhotoCapabilities;
const Blob = @import("Blob.zig").Blob;
const ImageBitmap = @import("ImageBitmap.zig").ImageBitmap;

pub const ImageCapture = struct {
    pub const Meta = struct {
        pub const name = "ImageCapture";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "track", "get_track", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "takePhoto", "call_takePhoto", 0 },
            .{ "getPhotoCapabilities", "call_getPhotoCapabilities", 0 },
            .{ "getPhotoSettings", "call_getPhotoSettings", 0 },
            .{ "grabFrame", "call_grabFrame", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "takePhoto",
            "getPhotoCapabilities",
            "getPhotoSettings",
            "grabFrame",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "track", "get_track", null },
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
            track: *runtime.Instance = undefined,
            _internal: ?*ImageCaptureImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_track = &get_track,

        .call_getPhotoCapabilities = &call_getPhotoCapabilities,
        .call_getPhotoSettings = &call_getPhotoSettings,
        .call_grabFrame = &call_grabFrame,
        .call_takePhoto = &call_takePhoto,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ImageCaptureImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ImageCaptureImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ImageCaptureImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, videoTrack: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ImageCaptureImpl.call_constructor(ctx, videoTrack);
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ImageCaptureImpl.get_track(instance);
    }

    pub fn call_takePhoto(instance: *runtime.Instance, photoSettings: webidl.Opt(PhotoSettings)) anyerror!runtime.JSValue {
        
        return try ImageCaptureImpl.call_takePhoto(instance, photoSettings);
    }

    pub fn call_getPhotoCapabilities(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ImageCaptureImpl.call_getPhotoCapabilities(instance);
    }

    pub fn call_getPhotoSettings(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ImageCaptureImpl.call_getPhotoSettings(instance);
    }

    pub fn call_grabFrame(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ImageCaptureImpl.call_grabFrame(instance);
    }

};
