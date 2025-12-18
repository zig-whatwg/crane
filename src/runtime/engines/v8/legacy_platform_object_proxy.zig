const v8 = @import("ffi.zig");

pub fn wrapInProxy(target: *v8.Object, isolate: *v8.Isolate, context: *v8.Context) *v8.Object {
    _ = isolate;
    return v8.v8_CreateLegacyPlatformObjectProxy(context, target) orelse target;
}
