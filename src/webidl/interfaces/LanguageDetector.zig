//! Generated from: translation-api.idl
//! Generated at: 2025-11-28T22:33:18Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const LanguageDetectorImpl = @import("impls").LanguageDetector;
const mixins = @import("mixins");
const DestroyableModel = @import("interfaces").DestroyableModel;
const LanguageDetectorDetectOptions = @import("dictionaries").LanguageDetectorDetectOptions;
const Availability = @import("enums").Availability;
const LanguageDetectorCreateOptions = @import("dictionaries").LanguageDetectorCreateOptions;
const LanguageDetectorCreateCoreOptions = @import("dictionaries").LanguageDetectorCreateCoreOptions;
const DOMString = @import("typedefs").DOMString;

pub const LanguageDetector = struct {
    pub const Meta = struct {
        pub const name = "LanguageDetector";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
            DestroyableModel,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "expectedInputLanguages", "get_expectedInputLanguages", null },
            .{ "inputQuota", "get_inputQuota", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "detect", "call_detect", 1 },
            .{ "measureInputUsage", "call_measureInputUsage", 1 },
            .{ "destroy", "call_destroy", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "create", "call_create", 0 },
            .{ "availability", "call_availability", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "create",
            "availability",
            "detect",
            "measureInputUsage",
            "destroy",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "expectedInputLanguages", "get_expectedInputLanguages", null },
            .{ "inputQuota", "get_inputQuota", null },
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
            expectedInputLanguages: ?runtime.FrozenArray(runtime.DOMString) = null,
            inputQuota: f64 = undefined,
            _internal: ?*LanguageDetectorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_expectedInputLanguages = &get_expectedInputLanguages,
        .get_inputQuota = &get_inputQuota,

        .call_availability = &call_availability,
        .call_create = &call_create,
        .call_destroy = &call_destroy,
        .call_detect = &call_detect,
        .call_measureInputUsage = &call_measureInputUsage,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return LanguageDetectorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LanguageDetectorImpl.deinit(instance);
    }

    pub fn get_expectedInputLanguages(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try LanguageDetectorImpl.get_expectedInputLanguages(instance);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) anyerror!f64 {
        return try LanguageDetectorImpl.get_inputQuota(instance);
    }

    pub fn call_availability(instance: *runtime.Instance, options: webidl.Opt(LanguageDetectorCreateCoreOptions)) anyerror!*const anyopaque {
        
        return try LanguageDetectorImpl.call_availability(instance, options);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: DOMString, options: webidl.Opt(LanguageDetectorDetectOptions)) anyerror!*const anyopaque {
        
        return try LanguageDetectorImpl.call_measureInputUsage(instance, input, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try LanguageDetectorImpl.call_destroy(instance);
    }

    pub fn call_detect(instance: *runtime.Instance, input: DOMString, options: webidl.Opt(LanguageDetectorDetectOptions)) anyerror!*const anyopaque {
        
        return try LanguageDetectorImpl.call_detect(instance, input, options);
    }

    pub fn call_create(instance: *runtime.Instance, options: webidl.Opt(LanguageDetectorCreateOptions)) anyerror!*const anyopaque {
        
        return try LanguageDetectorImpl.call_create(instance, options);
    }

};
