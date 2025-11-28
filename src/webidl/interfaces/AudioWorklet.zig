//! Generated from: webaudio.idl
//! Generated at: 2025-11-28T19:11:19Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioWorkletImpl = @import("impls").AudioWorklet;
const mixins = @import("mixins");
const Worklet = @import("interfaces").Worklet;
const MessagePort = @import("interfaces").MessagePort;
const USVString = @import("interfaces").USVString;
const WorkletOptions = @import("dictionaries").WorkletOptions;

pub const AudioWorklet = struct {
    pub const Meta = struct {
        pub const name = "AudioWorklet";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Worklet;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "port", "get_port", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addModule",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "port", "get_port", null },
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
            port: *runtime.Instance = undefined,
            _internal: ?*AudioWorkletImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_port = &get_port,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioWorkletImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioWorkletImpl.deinit(instance);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioWorkletImpl.get_port(instance);
    }

};
