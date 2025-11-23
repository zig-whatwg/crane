//! Generated from: speech-api.idl
//! Generated at: 2025-11-23T16:59:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechRecognitionResultImpl = @import("impls").SpeechRecognitionResult;
const SpeechRecognitionAlternative = @import("interfaces").SpeechRecognitionAlternative;

pub const SpeechRecognitionResult = struct {
    pub const Meta = struct {
        pub const name = "SpeechRecognitionResult";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
            .{ "isFinal", "get_isFinal", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
            .{ "isFinal", "get_isFinal", null },
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
            length: u32 = undefined,
            isFinal: bool = undefined,
            _internal: ?*SpeechRecognitionResultImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_isFinal = &get_isFinal,
        .get_length = &get_length,

        .call_item = &call_item,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SpeechRecognitionResultImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechRecognitionResultImpl.deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try SpeechRecognitionResultImpl.get_length(instance);
    }

    pub fn get_isFinal(instance: *runtime.Instance) anyerror!bool {
        return try SpeechRecognitionResultImpl.get_isFinal(instance);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!SpeechRecognitionAlternative {
        
        return try SpeechRecognitionResultImpl.call_item(instance, index);
    }

};
