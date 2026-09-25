//! Which JSValue handles the binding may release after returning them.
//!
//! A method's JSValue result is set as the call's return value (which copies
//! it) and then released by the binding if the value says it owns the handle.
//! Getting that wrong one way leaks a Global per call - and a Global to an
//! object keeps the object's whole page alive, which is what the promise every
//! `fetch()`, `cookieStore.get()` or `blob.text()` returned was doing. Getting
//! it wrong the other way frees a handle the impl still holds.

const std = @import("std");
const runtime = @import("runtime");
const JSValue = runtime.JSValue;

test "a promise an impl returns is handed over, not kept" {
    // `fromPromise` wraps a promise the impl just created and holds nowhere
    // else, so the binding owns it once it is returned.
    var dummy: u8 = 0;
    try std.testing.expect(JSValue.fromPromise(&dummy).needsDisposal());
}

test "a handle the impl keeps is never released by the binding" {
    var dummy: u8 = 0;
    try std.testing.expect(!JSValue.fromHandleNonOwning(&dummy).needsDisposal());
    try std.testing.expect(!JSValue.fromLocalHandle(&dummy).needsDisposal());
}

test "a fresh global handle is handed over" {
    var dummy: u8 = 0;
    try std.testing.expect(JSValue.fromHandle(&dummy).needsDisposal());
    try std.testing.expect(JSValue.fromGlobalHandle(&dummy).needsDisposal());
}
