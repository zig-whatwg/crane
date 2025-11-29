//! Generated from: writing-assistance-apis.idl
//! Generated at: 2025-11-29T02:15:44Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RewriterImpl = @import("impls").Rewriter;
const mixins = @import("mixins");
const DestroyableModel = @import("interfaces").DestroyableModel;
const Availability = @import("enums").Availability;
const RewriterTone = @import("enums").RewriterTone;
const ReadableStream = @import("interfaces").ReadableStream;
const RewriterFormat = @import("enums").RewriterFormat;
const RewriterCreateCoreOptions = @import("dictionaries").RewriterCreateCoreOptions;
const RewriterRewriteOptions = @import("dictionaries").RewriterRewriteOptions;
const RewriterLength = @import("enums").RewriterLength;
const DOMString = @import("typedefs").DOMString;
const RewriterCreateOptions = @import("dictionaries").RewriterCreateOptions;

pub const Rewriter = struct {
    pub const Meta = struct {
        pub const name = "Rewriter";
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
            .{ "sharedContext", "get_sharedContext", null },
            .{ "tone", "get_tone", null },
            .{ "format", "get_format", null },
            .{ "length", "get_length", null },
            .{ "expectedInputLanguages", "get_expectedInputLanguages", null },
            .{ "expectedContextLanguages", "get_expectedContextLanguages", null },
            .{ "outputLanguage", "get_outputLanguage", null },
            .{ "inputQuota", "get_inputQuota", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "rewrite", "call_rewrite", 1 },
            .{ "rewriteStreaming", "call_rewriteStreaming", 1 },
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
            "rewrite",
            "rewriteStreaming",
            "measureInputUsage",
            "destroy",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sharedContext", "get_sharedContext", null },
            .{ "tone", "get_tone", null },
            .{ "format", "get_format", null },
            .{ "length", "get_length", null },
            .{ "expectedInputLanguages", "get_expectedInputLanguages", null },
            .{ "expectedContextLanguages", "get_expectedContextLanguages", null },
            .{ "outputLanguage", "get_outputLanguage", null },
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
            sharedContext: runtime.DOMString = undefined,
            tone: RewriterTone = undefined,
            format: RewriterFormat = undefined,
            length: RewriterLength = undefined,
            expectedInputLanguages: ?runtime.FrozenArray(runtime.DOMString) = null,
            expectedContextLanguages: ?runtime.FrozenArray(runtime.DOMString) = null,
            outputLanguage: ?runtime.DOMString = null,
            inputQuota: f64 = undefined,
            _internal: ?*RewriterImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_expectedContextLanguages = &get_expectedContextLanguages,
        .get_expectedInputLanguages = &get_expectedInputLanguages,
        .get_format = &get_format,
        .get_inputQuota = &get_inputQuota,
        .get_length = &get_length,
        .get_outputLanguage = &get_outputLanguage,
        .get_sharedContext = &get_sharedContext,
        .get_tone = &get_tone,

        .call_availability = &call_availability,
        .call_create = &call_create,
        .call_destroy = &call_destroy,
        .call_measureInputUsage = &call_measureInputUsage,
        .call_rewrite = &call_rewrite,
        .call_rewriteStreaming = &call_rewriteStreaming,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RewriterImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RewriterImpl.deinit(instance);
    }

    pub fn get_sharedContext(instance: *runtime.Instance) anyerror!DOMString {
        return try RewriterImpl.get_sharedContext(instance);
    }

    pub fn get_tone(instance: *runtime.Instance) anyerror!RewriterTone {
        return try RewriterImpl.get_tone(instance);
    }

    pub fn get_format(instance: *runtime.Instance) anyerror!RewriterFormat {
        return try RewriterImpl.get_format(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!RewriterLength {
        return try RewriterImpl.get_length(instance);
    }

    pub fn get_expectedInputLanguages(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try RewriterImpl.get_expectedInputLanguages(instance);
    }

    pub fn get_expectedContextLanguages(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try RewriterImpl.get_expectedContextLanguages(instance);
    }

    pub fn get_outputLanguage(instance: *runtime.Instance) anyerror!?DOMString {
        return try RewriterImpl.get_outputLanguage(instance);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) anyerror!f64 {
        return try RewriterImpl.get_inputQuota(instance);
    }

    pub fn call_availability(instance: *runtime.Instance, options: webidl.Opt(RewriterCreateCoreOptions)) anyerror!*const anyopaque {
        
        return try RewriterImpl.call_availability(instance, options);
    }

    pub fn call_rewrite(instance: *runtime.Instance, input: DOMString, options: webidl.Opt(RewriterRewriteOptions)) anyerror!*const anyopaque {
        
        return try RewriterImpl.call_rewrite(instance, input, options);
    }

    pub fn call_rewriteStreaming(instance: *runtime.Instance, input: DOMString, options: webidl.Opt(RewriterRewriteOptions)) anyerror!*runtime.Instance {
        
        return try RewriterImpl.call_rewriteStreaming(instance, input, options);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: DOMString, options: webidl.Opt(RewriterRewriteOptions)) anyerror!*const anyopaque {
        
        return try RewriterImpl.call_measureInputUsage(instance, input, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try RewriterImpl.call_destroy(instance);
    }

    pub fn call_create(instance: *runtime.Instance, options: webidl.Opt(RewriterCreateOptions)) anyerror!*const anyopaque {
        
        return try RewriterImpl.call_create(instance, options);
    }

};
