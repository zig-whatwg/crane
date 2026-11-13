//! The link between a non-node platform object's wrapper and its instance (lane wrap1 b2;
//! tmp/plans/object-wrap-design.md 3.4).
//!
//! A wrapper keeps its instance the way Blink's does: the interface's instance template reserves no internal
//! field, and the wrapper points at a C++-heap object through `v8::Object::Wrap` -
//! `V8DOMWrapper::SetNativeInfo(isolate, wrapper, wrappable)` is
//! `v8::Object::Wrap(isolate, wrapper, wrappable, ToWrapperTypeInfo(wrappable)->this_tag)`, `ClearNativeInfo`
//! wraps null, and `ToAnyScriptWrappable` is `v8::Object::Unwrap` under the bindings' tag range
//! (third_party/blink/renderer/platform/bindings/v8_dom_wrapper.h:103-118, wrapper_type_info.h:206-223; Chromium
//! 157.0.8103.51). Blink's wrappable is the DOM object itself; Crane's instances are Zig objects with their own
//! lifetime (reference counting, src/AGENTS.md "DOM lifetime"), so the wrappable is an anchor that names the
//! instance - v8_wrapper.cpp's PlatformAnchor, 24 bytes of the agent's C++ heap, or for a holder of nodes the
//! HolderAnchor that also traces what it holds (wr1's P6). A node's wrapper has had this shape since the wrapper
//! redesign's P4 (node_wrappers.zig: its NodeAnchor); a realm's global keeps internal field 0 beside its
//! GlobalAnchor (realm_global.zig, lane v8up).
//!
//! The tag is the kind, not the interface: Crane's brand check is the instance's state ancestry
//! (binding_plumbing `implements`, conversions.implements), so `Object::Unwrap` under the platform anchors' tags
//! answers "a platform object's wrapper, or null" and the ancestry says which interface (design 3.3).
//!
//! Before this, the instance was an aligned pointer in internal field 0. On V8 15.7 that is a cppgc object of
//! V8's own (EmbedderDataSlotWrapper, 24 B) and 8 B of the wrapper for the field; a holder paid for both that and
//! its HolderAnchor.

const ffi = @import("ffi.zig");
const runtime = @import("runtime");
const node_wrappers = @import("node_wrappers.zig");

/// `wrapper` - a fresh object the binding made from `instance`'s interface's template, or the receiver V8 made
/// for a constructor's NewTarget; a legacy platform object's proxy stands for its target - reaches `instance`
/// from here: its anchor is made on `isolate`'s C++ heap and the object Wrapped with it.
///
/// Nothing for a node: its wrapper gets its NodeAnchor when the wrapper cache takes it (WrapperCache.set ->
/// node_wrappers.adopt). False when `wrapper` cannot be bound - no API object, which no template's instance
/// is - and then it reaches nothing.
///
/// The caller holds `wrapper` strongly (its Global): the anchor's allocation may collect, and the instance is
/// the caller's until the wrapper cache takes it.
pub fn bind(isolate: *ffi.Isolate, wrapper: *ffi.Object, instance: *runtime.Instance) bool {
    if (instance.vtable.counted != null) return true;
    const holds_nodes = instance.vtable.trace_held_nodes != null;
    // A holder's anchor traces what it holds through its agent's walk (VTable.trace_held_nodes, the wrapper
    // redesign's P6): the agent's registry exists before its first holder's wrapper does.
    if (holds_nodes) node_wrappers.prepareHolderTracing(isolate);
    const generation: u64 = if (holds_nodes) runtime.SlabAllocator.generationOf(instance) else 0;
    return ffi.v8_PlatformObject_Bind(isolate, wrapper, instance, generation, holds_nodes);
}

/// `wrapper` reaches no instance from here - Blink's V8DOMWrapper::ClearNativeInfo: its instance is going while
/// script may still hold the wrapper (its realm's end), or the wrap that made it failed. One write on its
/// anchor; the binding's next read through it answers null, which every member turns into WebIDL's "not a
/// platform object that implements the interface" TypeError, and a holder's anchor traces nothing. Nothing for
/// an object that was never bound (a node's wrapper, which its own anchor severs). The isolate is the current
/// one.
pub fn sever(wrapper: *ffi.Object) void {
    ffi.v8_PlatformObject_Sever(wrapper);
}

/// The instance `object` reaches, or null: the binding's ONE read of a platform object's instance, whatever
/// kind of wrapper it is - a platform object's (its anchor), a legacy platform object's proxy (its target's),
/// a node's (its NodeAnchor's slot), a realm's global (internal field 0). Null for any other object, and for a
/// severed wrapper. It says nothing about which interface the instance implements.
pub fn instanceOf(object: *ffi.Object) ?*anyopaque {
    return ffi.v8_Object_Instance(object);
}
