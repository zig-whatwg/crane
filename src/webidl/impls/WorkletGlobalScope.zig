//! Implementation for the WorkletGlobalScope interface (HTML 11.3.1).
//!
//! A WorkletGlobalScope is a realm's global object, made by the engine for
//! html.worklet_host (engine.createWorkletRealm). It has no members of its
//! own; its module map and settings are the worklet host's, and each
//! subclass keeps its definitions map.

const runtime = @import("runtime");
const interfaces = @import("interfaces");
const WorkletGlobalScope = interfaces.WorkletGlobalScope;

pub const State = WorkletGlobalScope.State;

/// No state of its own (the generated State names it).
pub const InternalState = struct {};
