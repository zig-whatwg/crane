//! The selectedcontent element's stored HTML disabled flag.
//! lint-impls: hook for HTMLSelectedContentElement
const runtime = @import("runtime");
const process_start = @import("process_start.zig");

// process-wide: immutable selectedcontent disabledness reader installed at process start, identical for every Browser and thread
var read_disabled: ?*const fn (*runtime.Instance) bool = null;

pub fn install(reader: *const fn (*runtime.Instance) bool) void {
    process_start.assertInstalling();
    read_disabled = reader;
}

pub fn isDisabled(element: *runtime.Instance) bool {
    return (read_disabled orelse return true)(element);
}
