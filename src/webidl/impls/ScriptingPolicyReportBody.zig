//! Implementation for ScriptingPolicyReportBody interface
//!
//! Scripting Policy's report body (Crane makes no scripting policy report).
//! One of the report body interfaces of specs/supplementary/
//! reporting-interfaces.idl (the user's ruling of 2026-11-05): its members are
//! read from the native report record it was made from
//! (dom.reporting.makeBody, dom.reporting.BodyImpl).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const reporting = @import("dom").reporting;
const ScriptingPolicyReportBody = interfaces.ScriptingPolicyReportBody;

pub const State = ScriptingPolicyReportBody.State;

const Body = reporting.BodyImpl(State);
pub const construction_args = Body.construction_args;
pub const InternalState = reporting.BodyInternal;
pub const initOwn = Body.initOwn;
pub const deinitOwn = Body.deinitOwn;

/// Getter for violationType
pub fn get_violationType(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try Body.fields(instance)).string("violationType") orelse "");
}

/// Getter for violationURL
pub fn get_violationURL(instance: *runtime.Instance) anyerror!?runtime.USVString {
    return if ((try Body.fields(instance)).string("violationURL")) |value| try instance.ctx.allocator.dupe(u8, value) else null;
}

/// Getter for violationSample
pub fn get_violationSample(instance: *runtime.Instance) anyerror!?runtime.USVString {
    return if ((try Body.fields(instance)).string("violationSample")) |value| try instance.ctx.allocator.dupe(u8, value) else null;
}

/// Getter for lineno
pub fn get_lineno(instance: *runtime.Instance) anyerror!u32 {
    return (try Body.fields(instance)).unsigned("lineno") orelse 0;
}

/// Getter for colno
pub fn get_colno(instance: *runtime.Instance) anyerror!u32 {
    return (try Body.fields(instance)).unsigned("colno") orelse 0;
}

/// Operation: toJSON ([Default]: every attribute, ReportBody's none)
pub fn call_toJSON(instance: *runtime.Instance) anyerror!ScriptingPolicyReportBody.ScriptingPolicyReportBodyToJSON {
    const fields = try Body.fields(instance);
    return .{
        .violationType = runtime.DOMString.initInterned(fields.string("violationType") orelse ""),
        .violationURL = fields.string("violationURL"),
        .violationSample = fields.string("violationSample"),
        .lineno = fields.unsigned("lineno") orelse 0,
        .colno = fields.unsigned("colno") orelse 0,
    };
}
