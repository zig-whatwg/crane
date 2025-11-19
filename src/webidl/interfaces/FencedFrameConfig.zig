//! Generated from: fenced-frame.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FencedFrameConfigImpl = @import("impls").FencedFrameConfig;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const FencedFrameConfig = struct {
    pub const Meta = struct {
        pub const name = "FencedFrameConfig";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FencedFrameConfig, .{
        .deinit_fn = &deinit_wrapper,

        .call_setSharedStorageContext = &call_setSharedStorageContext,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return FencedFrameConfigImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FencedFrameConfigImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, url: runtime.USVString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try FencedFrameConfigImpl.constructor(instance, url);
        
        return instance;
    }

    pub fn call_setSharedStorageContext(instance: *runtime.Instance, contextString: DOMString) anyerror!void {
        
        return try FencedFrameConfigImpl.call_setSharedStorageContext(instance, contextString);
    }

};
