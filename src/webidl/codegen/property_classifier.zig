//! Property classification: whether the binding defines an attribute's
//! accessor up front ("eager") or through the prototype's named interceptor on
//! first access ("lazy"). Every attribute is eager now - see
//! `classifyProperty` - and `Meta.lazy_properties` is always empty.

const std = @import("std");

/// Classification result for a property
pub const PropertyClass = enum {
    /// Eager properties: defined immediately, frequently accessed
    eager,

    /// Lazy properties: defined on first access, rarely used
    lazy,
};

/// Classify an attribute. Every attribute is eager.
///
/// WebIDL 3.7.6 makes an attribute an accessor property on the interface
/// prototype object, and only a real accessor is one. A "lazy" property was
/// served by a named property interceptor on the prototype template, and V8
/// calls a named SETTER interceptor only when the interceptor's holder is the
/// receiver (objects.cc, Object::SetPropertyInternal,
/// LookupIterator::INTERCEPTOR, V8 13.1). For an instance the holder is its
/// prototype, so V8 asked the getter whether the property existed and then
/// stored an own data property on the instance: `div.lang = "x"` never ran
/// the setter, never changed the content attribute, and shadowed the getter
/// for good (2,142 reflection subtests each for lang and accessKey, and
/// tabIndex, inert, dir, hidden, ... likewise). A read-only one was no better:
/// assigning to it shadowed it the same way, and
/// `Object.getOwnPropertyDescriptor(HTMLElement.prototype, "offsetWidth")` ran
/// the getter with the prototype as `this` and threw. Deferring 65 accessor
/// definitions was never worth that.
pub fn classifyProperty(
    property_name: []const u8,
    extended_attrs: []const []const u8,
) PropertyClass {
    _ = property_name;
    _ = extended_attrs;
    return .eager;
}

// =============================================================================
// Tests (tests/codegen/eager_attributes_test.zig pins what the writer emits)
// =============================================================================

test "every property is eager" {
    try std.testing.expectEqual(PropertyClass.eager, classifyProperty("lang", &.{}));
    try std.testing.expectEqual(PropertyClass.eager, classifyProperty("offsetWidth", &.{}));
    try std.testing.expectEqual(PropertyClass.eager, classifyProperty("id", &.{"CEReactions"}));
}
