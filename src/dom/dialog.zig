//! HTML dialog algorithms with a command source and modal focus exclusion.
//! IDL methods use the same algorithms; callers never reach the impl.
//! lint-impls: hook for HTMLDialogElement
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const layer = @import("top_layer.zig");
const process_start = @import("process_start.zig");
const Instance = runtime.Instance;

pub const Implementation = struct {
    show_modal: *const fn (*Instance, ?*Instance) anyerror!void,
    close: *const fn (*Instance, webidl.Opt(runtime.DOMString), ?*Instance) anyerror!void,
    inert: *const fn (*Instance) ?bool,
};
// process-wide: immutable dialog hook function pointers installed at process start, identical for every Browser and thread
var implementation: ?Implementation = null;

pub fn install(steps: Implementation) void {
    process_start.assertInstalling();
    implementation = steps;
}

/// "Show a modal dialog", with the invoker supplied by command activation.
pub fn showModal(subject: *Instance, source: ?*Instance) !void {
    try (implementation orelse return error.NotSupported).show_modal(subject, source);
}

/// "Close the dialog", retaining absence of the invoker's value attribute.
pub fn close(subject: *Instance, result: webidl.Opt(runtime.DOMString), source: ?*Instance) !void {
    try (implementation orelse return error.NotSupported).close(subject, result, source);
}

/// Membership is independent of open, shared by selectors and popovers.
pub fn isModal(subject: *Instance) bool {
    if (subject.stateAs(interfaces.HTMLDialogElement.State) == null) return false;
    const state = (layer.ofElement(subject, false) catch null) orelse return false;
    return state.findModal(subject) != null;
}

/// Null means there is no modal, so focus keeps its existing ancestor walk.
pub fn inertness(node: *Instance) ?bool {
    return (implementation orelse return null).inert(node);
}
