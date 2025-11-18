//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSColorImpl = @import("../impls/CSSColor.zig");
const CSSColorValue = @import("CSSColorValue.zig");

pub const CSSColor = struct {
    pub const Meta = struct {
        pub const name = "CSSColor";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSColorValue;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "PaintWorklet", "LayoutWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .PaintWorklet = true,
            .LayoutWorklet = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            colorSpace: CSSKeywordish = undefined,
            channels: ObservableArray<CSSColorPercent> = undefined,
            alpha: CSSNumberish = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSColor, .{
        .deinit_fn = &deinit_wrapper,

        .get_alpha = &get_alpha,
        .get_channels = &get_channels,
        .get_colorSpace = &get_colorSpace,

        .set_alpha = &set_alpha,
        .set_channels = &set_channels,
        .set_colorSpace = &set_colorSpace,

        .call_parse = &call_parse,
        .call_parse = &call_parse,
        .call_parseAll = &call_parseAll,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CSSColorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSColorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, colorSpace: anyopaque, channels: anyopaque, alpha: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSColorImpl.constructor(state, colorSpace, channels, alpha);
        
        return instance;
    }

    pub fn get_colorSpace(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSColorImpl.get_colorSpace(state);
    }

    pub fn set_colorSpace(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSColorImpl.set_colorSpace(state, value);
    }

    pub fn get_channels(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSColorImpl.get_channels(state);
    }

    pub fn set_channels(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSColorImpl.set_channels(state, value);
    }

    pub fn get_alpha(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSColorImpl.get_alpha(state);
    }

    pub fn set_alpha(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSColorImpl.set_alpha(state, value);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_parseAll(instance: *runtime.Instance, property: runtime.USVString, cssText: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return CSSColorImpl.call_parseAll(state, property, cssText);
    }

    /// Arguments for parse (WebIDL overloading)
    pub const ParseArgs = union(enum) {
        /// parse(property, cssText)
        USVString_USVString: struct {
            property: runtime.USVString,
            cssText: runtime.USVString,
        },
        /// parse(cssText)
        USVString: runtime.USVString,
    };

    pub fn call_parse(instance: *runtime.Instance, args: ParseArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .USVString_USVString => |a| return CSSColorImpl.USVString_USVString(state, a.property, a.cssText),
            .USVString => |arg| return CSSColorImpl.USVString(state, arg),
        }
    }

};
