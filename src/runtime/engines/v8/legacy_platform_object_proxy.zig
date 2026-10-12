const v8 = @import("ffi.zig");

/// `target` in a legacy platform object Proxy (v8_wrapper.cpp); `named_setter`:
/// its interface has a named property setter (template_registry.hasNamedPropertySetter),
/// which the set trap's WebIDL 3.9.2 [[Set]] step 1.2 sends every String to.
pub fn wrapInProxy(target: *v8.Object, isolate: *v8.Isolate, context: *v8.Context, named_setter: bool) *v8.Object {
    _ = isolate;
    return v8.v8_CreateLegacyPlatformObjectProxy(context, target, named_setter) orelse target;
}
