//! A document associates its one Selection through its owner's startup hook.
//! lint-impls: hook for Selection, Range
const runtime = @import("runtime");
const process_start = @import("process_start.zig");

/// Each owner supplies its association or notification step; callers never
/// reach into another interface's state.
pub const Implementation = struct {
    bind_document: ?*const fn (*runtime.Instance, *runtime.Instance) void = null,
    associate_range: ?*const fn (*runtime.Instance, *runtime.Instance, bool) void = null,
    range_mutated: ?*const fn (*runtime.Instance, *runtime.Instance, bool) void = null,
};

// process-wide: immutable Selection/Range callbacks installed once before any Browser or worker starts.
var implementation: ?Implementation = null;

/// Called by Selection.installHooks and Range.installHooks at process startup.
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    var combined = implementation orelse Implementation{};
    if (impl.bind_document) |step| combined.bind_document = step;
    if (impl.associate_range) |step| combined.associate_range = step;
    if (impl.range_mutated) |step| combined.range_mutated = step;
    implementation = combined;
}

/// Bind the wrapped selection to the document that keeps it.
pub fn bindDocument(selection: *runtime.Instance, document: *runtime.Instance) void {
    const impl = implementation orelse return;
    const step = impl.bind_document orelse return;
    step(selection, document);
}

/// Selection alone sets/clears Range's weak link back to its selection.
pub fn associateRange(range: *runtime.Instance, selection: *runtime.Instance, associated: bool) void {
    const step = (implementation orelse return).associate_range orelse return;
    step(range, selection, associated);
}

/// A live selected Range changed: keep it associated while it stays in the
/// document, otherwise dissociate; queue the event without ever running script
/// inside the DOM mutation algorithm.
pub fn rangeMutated(selection: *runtime.Instance, range: *runtime.Instance, containers_changed: bool) void {
    const step = (implementation orelse return).range_mutated orelse return;
    step(selection, range, containers_changed);
}
