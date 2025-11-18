//! Generated from: csp-next.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ScriptingPolicyReportBodyImpl = @import("impls").ScriptingPolicyReportBody;
const ReportBody = @import("dictionaries").ReportBody;
const USVString = @import("interfaces").USVString;

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
        
        // Initialize the instance (Impl receives full instance)
        ScriptingPolicyReportBodyImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ScriptingPolicyReportBodyImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_violationType(instance: *runtime.Instance) anyerror!DOMString {
        return try ScriptingPolicyReportBodyImpl.get_violationType(instance);
    }

    pub fn get_violationURL(instance: *runtime.Instance) anyerror!anyopaque {
        return try ScriptingPolicyReportBodyImpl.get_violationURL(instance);
    }

    pub fn get_violationSample(instance: *runtime.Instance) anyerror!anyopaque {
        return try ScriptingPolicyReportBodyImpl.get_violationSample(instance);
    }

    pub fn get_lineno(instance: *runtime.Instance) anyerror!u32 {
        return try ScriptingPolicyReportBodyImpl.get_lineno(instance);
    }

    pub fn get_colno(instance: *runtime.Instance) anyerror!u32 {
        return try ScriptingPolicyReportBodyImpl.get_colno(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!anyopaque {
        return try ScriptingPolicyReportBodyImpl.call_toJSON(instance);
    }

};
