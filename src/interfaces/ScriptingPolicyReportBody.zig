//! Generated from: csp-next.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ScriptingPolicyReportBodyImpl = @import("../impls/ScriptingPolicyReportBody.zig");
const ReportBody = @import("ReportBody.zig");

pub const ScriptingPolicyReportBody = struct {
    pub const Meta = struct {
        pub const name = "ScriptingPolicyReportBody";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ReportBody;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            violationType: runtime.DOMString = undefined,
            violationURL: ?runtime.USVString = null,
            violationSample: ?runtime.USVString = null,
            lineno: u32 = undefined,
            colno: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ScriptingPolicyReportBody, .{
        .deinit_fn = &deinit_wrapper,

        .get_colno = &get_colno,
        .get_lineno = &get_lineno,
        .get_violationSample = &get_violationSample,
        .get_violationType = &get_violationType,
        .get_violationURL = &get_violationURL,

        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ScriptingPolicyReportBodyImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ScriptingPolicyReportBodyImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_violationType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ScriptingPolicyReportBodyImpl.get_violationType(state);
    }

    pub fn get_violationURL(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ScriptingPolicyReportBodyImpl.get_violationURL(state);
    }

    pub fn get_violationSample(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ScriptingPolicyReportBodyImpl.get_violationSample(state);
    }

    pub fn get_lineno(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return ScriptingPolicyReportBodyImpl.get_lineno(state);
    }

    pub fn get_colno(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return ScriptingPolicyReportBodyImpl.get_colno(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ScriptingPolicyReportBodyImpl.call_toJSON(state);
    }

};
