//! Generated from: speech-api.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SpeechGrammarImpl = @import("impls").SpeechGrammar;
const mixins = @import("mixins");
const DOMString = @import("typedefs").DOMString;

pub const SpeechGrammar = struct {
    pub const Meta = struct {
        pub const name = "SpeechGrammar";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "src", "get_src", "set_src" },
            .{ "weight", "get_weight", "set_weight" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "src", "get_src", "set_src" },
            .{ "weight", "get_weight", "set_weight" },
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
            src: runtime.DOMString = undefined,
            weight: f32 = undefined,
            _internal: ?*SpeechGrammarImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_src = &get_src,
        .get_weight = &get_weight,

        .set_src = &set_src,
        .set_weight = &set_weight,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SpeechGrammarImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechGrammarImpl.deinit(instance);
    }

    pub fn get_src(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechGrammarImpl.get_src(instance);
    }

    pub fn set_src(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SpeechGrammarImpl.set_src(instance, value);
    }

    pub fn get_weight(instance: *runtime.Instance) anyerror!f32 {
        return try SpeechGrammarImpl.get_weight(instance);
    }

    pub fn set_weight(instance: *runtime.Instance, value: f32) anyerror!void {
        try SpeechGrammarImpl.set_weight(instance, value);
    }

};
