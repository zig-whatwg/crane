//! Implementation for ReportBody interface
//!
//! The base of the report body interfaces (specs/supplementary/
//! reporting-interfaces.idl; the user's ruling of 2026-11-05): no state and
//! no attribute of its own. Each body interface keeps its own members
//! (dom.reporting.BodyImpl).

const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const ReportBody = interfaces.ReportBody;

pub const State = ReportBody.State;

/// No state of its own (the generated State asks for the type).
pub const InternalState = struct {};

/// Operation: toJSON - an object with no member: ReportBody has no
/// attribute, and its toJSON writes none (Chromium ReportBody::toJSON over
/// BuildJSONValue, WebKit's [Custom] toJSON). A body interface's own
/// [Default] toJSON writes its attributes.
pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const object = try engine.createDictionaryObject(engine.currentRealm() orelse instance.ctx, &.{});
    return object.take();
}
