//! Tests for Range Mutation Algorithms
//! Spec: https://dom.spec.whatwg.org/#interface-range (§4.10)
//!
//! Note: Full Range mutation tests are now in tests/v8/dom_test.js since they
//! require the complete runtime environment (Document, Text nodes, etc.)
//! that the V8 integration provides.
//!
//! The implementation is in src/webidl/impls/Range.zig.
//! The deprecated simplified version in src/dom/range_mutations.zig is no longer used.

const std = @import("std");
const dom = @import("dom");

// These tests verify only that the module compiles and types are accessible.
// Functional tests are in tests/v8/dom_test.js

test "Range - dom module accessible" {
    // This test ensures the dom module is accessible from tests.
    // Range mutations are tested via V8 integration tests since they
    // require the complete runtime environment (Document, Text nodes, etc.)
    _ = dom;
}
