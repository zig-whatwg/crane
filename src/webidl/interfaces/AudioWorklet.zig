//! Generated from: webaudio.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioWorkletImpl = @import("impls").AudioWorklet;
const Worklet = @import("interfaces").Worklet;
const MessagePort = @import("interfaces").MessagePort;
const USVString = @import("interfaces").USVString;
const WorkletOptions = @import("dictionaries").WorkletOptions;

pub const AudioWorklet = struct {
    pub const Meta = struct {
        pub const name = "AudioWorklet";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Worklet;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            port: MessagePort = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AudioWorklet, .{
        .deinit_fn = &deinit_wrapper,

        .get_port = &get_port,

        .call_addModule = &call_addModule,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return AudioWorkletImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioWorkletImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!MessagePort {
        return try AudioWorkletImpl.get_port(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_addModule(instance: *runtime.Instance, moduleURL: runtime.USVString, options: WorkletOptions) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try AudioWorkletImpl.call_addModule(instance, moduleURL, options);
    }

};
