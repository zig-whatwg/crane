//! Generated from: translation-api.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LanguageDetectorImpl = @import("impls").LanguageDetector;
const DestroyableModel = @import("interfaces").DestroyableModel;
const LanguageDetectorDetectOptions = @import("dictionaries").LanguageDetectorDetectOptions;
const Availability = @import("enums").Availability;
const LanguageDetectorCreateOptions = @import("dictionaries").LanguageDetectorCreateOptions;
const LanguageDetectorCreateCoreOptions = @import("dictionaries").LanguageDetectorCreateCoreOptions;
const DOMString = @import("typedefs").DOMString;

pub const LanguageDetector = struct {
    pub const Meta = struct {
        pub const name = "LanguageDetector";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            DestroyableModel,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            expectedInputLanguages: ?runtime.FrozenArray(runtime.DOMString) = null,
            inputQuota: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LanguageDetector, .{
        .deinit_fn = &deinit_wrapper,

        .get_expectedInputLanguages = &get_expectedInputLanguages,
        .get_inputQuota = &get_inputQuota,

        .call_availability = &call_availability,
        .call_create = &call_create,
        .call_destroy = &call_destroy,
        .call_detect = &call_detect,
        .call_measureInputUsage = &call_measureInputUsage,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return LanguageDetectorImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LanguageDetectorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_expectedInputLanguages(instance: *runtime.Instance) anyerror!anyopaque {
        return try LanguageDetectorImpl.get_expectedInputLanguages(instance);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) anyerror!f64 {
        return try LanguageDetectorImpl.get_inputQuota(instance);
    }

    pub fn call_availability(instance: *runtime.Instance, options: LanguageDetectorCreateCoreOptions) anyerror!anyopaque {
        
        return try LanguageDetectorImpl.call_availability(instance, options);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: DOMString, options: LanguageDetectorDetectOptions) anyerror!anyopaque {
        
        return try LanguageDetectorImpl.call_measureInputUsage(instance, input, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try LanguageDetectorImpl.call_destroy(instance);
    }

    pub fn call_detect(instance: *runtime.Instance, input: DOMString, options: LanguageDetectorDetectOptions) anyerror!anyopaque {
        
        return try LanguageDetectorImpl.call_detect(instance, input, options);
    }

    pub fn call_create(instance: *runtime.Instance, options: LanguageDetectorCreateOptions) anyerror!anyopaque {
        
        return try LanguageDetectorImpl.call_create(instance, options);
    }

};
