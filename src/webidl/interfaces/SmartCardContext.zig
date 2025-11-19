//! Generated from: web-smart-card.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SmartCardContextImpl = @import("impls").SmartCardContext;
const SmartCardReaderStateIn = @import("dictionaries").SmartCardReaderStateIn;
const SmartCardGetStatusChangeOptions = @import("dictionaries").SmartCardGetStatusChangeOptions;
const SmartCardAccessMode = @import("enums").SmartCardAccessMode;
const SmartCardConnectOptions = @import("dictionaries").SmartCardConnectOptions;
const SmartCardConnectResult = @import("dictionaries").SmartCardConnectResult;
const DOMString = @import("typedefs").DOMString;

pub const SmartCardContext = struct {
    pub const Meta = struct {
        pub const name = "SmartCardContext";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "SharedWorker", "Window" } } },
            .{ .name = "SecureContext" },
            .{ .name = "IsolatedContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .SharedWorker = true,
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SmartCardContext, .{
        .deinit_fn = &deinit_wrapper,

        .call_connect = &call_connect,
        .call_getStatusChange = &call_getStatusChange,
        .call_listReaders = &call_listReaders,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return SmartCardContextImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SmartCardContextImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_listReaders(instance: *runtime.Instance) anyerror!anyopaque {
        return try SmartCardContextImpl.call_listReaders(instance);
    }

    pub fn call_getStatusChange(instance: *runtime.Instance, readerStates: anyopaque, options: SmartCardGetStatusChangeOptions) anyerror!anyopaque {
        
        return try SmartCardContextImpl.call_getStatusChange(instance, readerStates, options);
    }

    pub fn call_connect(instance: *runtime.Instance, readerName: DOMString, accessMode: SmartCardAccessMode, options: SmartCardConnectOptions) anyerror!anyopaque {
        
        return try SmartCardContextImpl.call_connect(instance, readerName, accessMode, options);
    }

};
