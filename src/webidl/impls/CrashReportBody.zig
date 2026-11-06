//! Implementation for CrashReportBody interface
//!
//! Crash Reporting's report body (Crane makes no crash report).
//! One of the report body interfaces of specs/supplementary/
//! reporting-interfaces.idl (the user's ruling of 2026-11-05): its members are
//! read from the native report record it was made from
//! (dom.reporting.makeBody, dom.reporting.BodyImpl).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const reporting = @import("dom").reporting;
const CrashReportBody = interfaces.CrashReportBody;

pub const State = CrashReportBody.State;

const Body = reporting.BodyImpl(State);
pub const construction_args = Body.construction_args;
pub const InternalState = reporting.BodyInternal;
pub const initOwn = Body.initOwn;
pub const deinitOwn = Body.deinitOwn;

/// Getter for reason
pub fn get_reason(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try Body.fields(instance)).string("reason") orelse "");
}

/// Getter for stack
pub fn get_stack(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try Body.fields(instance)).string("stack") orelse "");
}

/// Getter for is_top_level
pub fn get_is_top_level(instance: *runtime.Instance) anyerror!bool {
    return (try Body.fields(instance)).boolean("is_top_level");
}

/// Getter for visibility_state
pub fn get_visibility_state(instance: *runtime.Instance) anyerror!enums.DocumentVisibilityState {
    return (try Body.fields(instance)).enumeration(enums.DocumentVisibilityState, "visibility_state");
}

/// Getter for crash_report_api
pub fn get_crash_report_api(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return blk: {
        _ = try Body.fields(instance);
        break :blk .null;
    };
}

/// Operation: toJSON ([Default]: every attribute, ReportBody's none)
pub fn call_toJSON(instance: *runtime.Instance) anyerror!CrashReportBody.CrashReportBodyToJSON {
    const fields = try Body.fields(instance);
    return .{
        .reason = runtime.DOMString.initInterned(fields.string("reason") orelse ""),
        .stack = runtime.DOMString.initInterned(fields.string("stack") orelse ""),
        .is_top_level = fields.boolean("is_top_level"),
        .visibility_state = fields.enumeration(enums.DocumentVisibilityState, "visibility_state"),
        .crash_report_api = .null,
    };
}
