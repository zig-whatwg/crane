//! Generated from: shape-detection-api.idl
//! Generated at: 2025-12-05T20:30:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BarcodeDetectorImpl = @import("impls").BarcodeDetector;
const mixins = @import("mixins");
const BarcodeDetectorOptions = @import("dictionaries").BarcodeDetectorOptions;
const ImageBitmapSource = @import("typedefs").ImageBitmapSource;

pub const BarcodeDetector = struct {
    pub const Meta = struct {
        pub const name = "BarcodeDetector";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "detect", "call_detect", 1 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "getSupportedFormats", "call_getSupportedFormats", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getSupportedFormats",
            "detect",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*BarcodeDetectorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_detect = &call_detect,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BarcodeDetectorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BarcodeDetectorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, barcodeDetectorOptions: webidl.Opt(BarcodeDetectorOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try BarcodeDetectorImpl.call_constructor(allocator, ctx, barcodeDetectorOptions);
    }

    pub fn call_getSupportedFormats(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BarcodeDetectorImpl.call_getSupportedFormats(instance);
    }

    pub fn call_detect(instance: *runtime.Instance, image: ImageBitmapSource) anyerror!*const anyopaque {
        return try BarcodeDetectorImpl.call_detect(instance, image);
    }
};
