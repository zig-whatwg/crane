//! HTML's pragma-set default language, owned by the Document and retained
//! when a content-language meta element is removed. Language lookup uses
//! this only after exhausting lang attributes, including shadow hosts.
//!
//! lint-impls: hook for Document
const runtime = @import("runtime");
const Hook = @import("hook.zig").Hook;

pub const Error = error{ InvalidStateError, OutOfMemory };
pub const Implementation = struct {
    /// Borrowed until the next pragma assignment or Document teardown.
    get: *const fn (document: *runtime.Instance) ?[]const u8,
    set: *const fn (document: *runtime.Instance, language: []const u8) Error!void,
};

// process-wide: stateless functions installed once by Document at process start; language strings belong to Documents
var implementation: Hook(?Implementation) = .init(null);

pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

pub fn get(document: *runtime.Instance) ?[]const u8 {
    const impl = implementation.get() orelse return null;
    return impl.get(document);
}

pub fn set(document: *runtime.Instance, language: []const u8) Error!void {
    const impl = implementation.get() orelse return error.InvalidStateError;
    return impl.set(document, language);
}
