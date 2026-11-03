//! The selectedcontent element's stored HTML disabled flag.
//! lint-impls: hook for HTMLSelectedContentElement
const runtime = @import("runtime");
const Hook = @import("hook.zig").Hook;

// process-wide: immutable selectedcontent disabledness reader installed at process start, identical for every Browser and thread
var read_disabled: Hook(?*const fn (*runtime.Instance) bool) = .init(null);

pub fn install(reader: *const fn (*runtime.Instance) bool) void {
    read_disabled.install(reader);
}

pub fn isDisabled(element: *runtime.Instance) bool {
    return (read_disabled.get() orelse return true)(element);
}
