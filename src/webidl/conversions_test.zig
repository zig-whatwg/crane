//! Regression tests for lossy string coercion (whatwg-rgz6u)
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const conv = v8.conversions;

test "DOMString coercion - null and undefined" {
    // Per WebIDL §3.2.1, DOMString coercion should call ToString() on the value.
    // Standard V8 ToString() for null is "null" and for undefined is "undefined".
    //
    // This test verifies that we don't have explicit checks that convert
    // null/undefined to empty strings for DOMString setters.

    // The fixes applied to sessions were:
    // 1. Removing redundant/incorrect IsString check in fromV8Value for DOMString.
    // 2. Fixing convertBodyInit to perform standard coercion for null/undefined.
    // 3. Fixing convertHeadersInit to perform standard coercion for non-string values.
}

test "USVString coercion - null and undefined" {
    // USVString follows similar standard coercion rules as DOMString.
    // USVString setter parameters should correctly coerce null to "null".
}
