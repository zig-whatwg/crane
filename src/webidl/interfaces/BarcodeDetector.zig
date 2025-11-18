//! Generated from: shape-detection-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BarcodeDetectorImpl = @import("impls").BarcodeDetector;
const BarcodeDetectorOptions = @import("dictionaries").BarcodeDetectorOptions;
const Promise<sequence<BarcodeFormat>> = @import("interfaces").Promise<sequence<BarcodeFormat>>;
const ImageBitmapSource = @import("typedefs").ImageBitmapSource;
const Promise<sequence<DetectedBarcode>> = @import("interfaces").Promise<sequence<DetectedBarcode>>;

pub const BarcodeDetector = struct {
    pub const Meta = struct {
        pub const name = "BarcodeDetector";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BarcodeDetector, .{
        .deinit_fn = &deinit_wrapper,

        .call_detect = &call_detect,
        .call_getSupportedFormats = &call_getSupportedFormats,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        BarcodeDetectorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BarcodeDetectorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, barcodeDetectorOptions: BarcodeDetectorOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try BarcodeDetectorImpl.constructor(instance, barcodeDetectorOptions);
        
        return instance;
    }

    pub fn call_getSupportedFormats(instance: *runtime.Instance) anyerror!anyopaque {
        return try BarcodeDetectorImpl.call_getSupportedFormats(instance);
    }

    pub fn call_detect(instance: *runtime.Instance, image: ImageBitmapSource) anyerror!anyopaque {
        
        return try BarcodeDetectorImpl.call_detect(instance, image);
    }

};
