//! Generated from: translation-api.idl
//! Generated at: 2025-11-23T16:59:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TranslatorImpl = @import("impls").Translator;
const DestroyableModel = @import("interfaces").DestroyableModel;
const TranslatorCreateOptions = @import("dictionaries").TranslatorCreateOptions;
const Availability = @import("enums").Availability;
const ReadableStream = @import("interfaces").ReadableStream;
const TranslatorCreateCoreOptions = @import("dictionaries").TranslatorCreateCoreOptions;
const TranslatorTranslateOptions = @import("dictionaries").TranslatorTranslateOptions;
const DOMString = @import("typedefs").DOMString;

pub const Translator = struct {
    pub const Meta = struct {
        pub const name = "Translator";
        pub const is_mixin = false;
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
            .{ "sourceLanguage", "get_sourceLanguage", null },
            .{ "targetLanguage", "get_targetLanguage", null },
            .{ "inputQuota", "get_inputQuota", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "create", "call_create", 1 },
            .{ "availability", "call_availability", 1 },
            .{ "translate", "call_translate", 1 },
            .{ "translateStreaming", "call_translateStreaming", 1 },
            .{ "measureInputUsage", "call_measureInputUsage", 1 },
            .{ "destroy", "call_destroy", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "create",
            "availability",
            "translate",
            "translateStreaming",
            "measureInputUsage",
            "destroy",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sourceLanguage", "get_sourceLanguage", null },
            .{ "targetLanguage", "get_targetLanguage", null },
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
            sourceLanguage: runtime.DOMString = undefined,
            targetLanguage: runtime.DOMString = undefined,
            inputQuota: f64 = undefined,
            _internal: ?*TranslatorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_inputQuota = &get_inputQuota,
        .get_sourceLanguage = &get_sourceLanguage,
        .get_targetLanguage = &get_targetLanguage,

        .call_availability = &call_availability,
        .call_create = &call_create,
        .call_destroy = &call_destroy,
        .call_measureInputUsage = &call_measureInputUsage,
        .call_translate = &call_translate,
        .call_translateStreaming = &call_translateStreaming,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TranslatorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TranslatorImpl.deinit(instance);
    }

    pub fn get_sourceLanguage(instance: *runtime.Instance) anyerror!DOMString {
        return try TranslatorImpl.get_sourceLanguage(instance);
    }

    pub fn get_targetLanguage(instance: *runtime.Instance) anyerror!DOMString {
        return try TranslatorImpl.get_targetLanguage(instance);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) anyerror!f64 {
        return try TranslatorImpl.get_inputQuota(instance);
    }

    pub fn call_availability(instance: *runtime.Instance, options: TranslatorCreateCoreOptions) anyerror!*const anyopaque {
        
        return try TranslatorImpl.call_availability(instance, options);
    }

    pub fn call_translate(instance: *runtime.Instance, input: DOMString, options: TranslatorTranslateOptions) anyerror!*const anyopaque {
        
        return try TranslatorImpl.call_translate(instance, input, options);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: DOMString, options: TranslatorTranslateOptions) anyerror!*const anyopaque {
        
        return try TranslatorImpl.call_measureInputUsage(instance, input, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try TranslatorImpl.call_destroy(instance);
    }

    pub fn call_translateStreaming(instance: *runtime.Instance, input: DOMString, options: TranslatorTranslateOptions) anyerror!ReadableStream {
        
        return try TranslatorImpl.call_translateStreaming(instance, input, options);
    }

    pub fn call_create(instance: *runtime.Instance, options: TranslatorCreateOptions) anyerror!*const anyopaque {
        
        return try TranslatorImpl.call_create(instance, options);
    }

};
