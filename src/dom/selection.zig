//! A document associates its one Selection through its owner's startup hook.
//! lint-impls: hook for Selection
const runtime = @import("runtime");
const process_start = @import("process_start.zig");

/// Selection supplies the document-association step; Document never reaches
/// into another interface's state.
pub const Implementation = struct {
    bind_document: *const fn (*runtime.Instance, *runtime.Instance) void,
};

// process-wide: immutable Selection callbacks installed once before any Browser or worker starts.
var implementation: ?Implementation = null;

/// Called by Selection.installHooks during process initialization.
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Bind the wrapped selection to the document that keeps it.
pub fn bindDocument(selection: *runtime.Instance, document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.bind_document(selection, document);
}
