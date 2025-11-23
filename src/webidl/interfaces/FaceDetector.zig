//! Generated from: shape-detection-api.idl
//! Generated at: 2025-11-23T14:26:29Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FaceDetectorImpl = @import("impls").FaceDetector;
const FaceDetectorOptions = @import("dictionaries").FaceDetectorOptions;
const ImageBitmapSource = @import("typedefs").ImageBitmapSource;

pub const FaceDetector = struct {
    pub const Meta = struct {
        pub const name = "FaceDetector";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "detect", "call_detect", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "detect",
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

        .call_detect = &call_detect,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FaceDetectorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FaceDetectorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, faceDetectorOptions: FaceDetectorOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FaceDetectorImpl.call_constructor(allocator, ctx, faceDetectorOptions);
    }

    pub fn call_detect(instance: *runtime.Instance, image: ImageBitmapSource) anyerror!*const anyopaque {
        
        return try FaceDetectorImpl.call_detect(instance, image);
    }

};
