//! HTML "abort a document" step 2, for the fetches script started: "Cancel
//! any instances of the fetch algorithm in the context of document,
//! discarding any tasks queued for them, and discarding any further data
//! received from the network for them." "Destroy a document" (§7.5.10) runs
//! it first, and then (step 7) removes the document's queued tasks without
//! running them - so a fetch of a destroyed document ends with no further
//! event at all.
//!
//! The fetches are the owners' state - XMLHttpRequest's in-flight request,
//! fetch()'s call - and no IDL member reaches them, so each kind of fetch
//! owner installs a canceler here and "destroy a child navigable"
//! (HTMLIFrameElement's removing steps) calls `abortAll` for each destroyed
//! document's realm. Canceling is also what lets a destroyed frame's realm
//! go: a fetch in flight holds its owner, and the owner its realm, until it
//! ends (Blink's HasPendingActivity), so it has to end.
//!
//! Only "abort a document" step 2 belongs here. Steps the spec puts in the
//! unloading document cleanup steps (a WebSocket's "make disappear") are
//! not fetches.
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-lifecycle.html#abort-a-document
//! Spec: https://html.spec.whatwg.org/multipage/document-lifecycle.html#destroy-a-document
//!
//! lint-impls: hook for XMLHttpRequest, WindowOrWorkerGlobalScope (fetch())
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// Cancels the installer's fetches whose relevant realm is `realm`, silently.
pub const Canceler = *const fn (realm: runtime.Context) void;

/// One slot per kind of fetch owner, with room to spare. Per thread, as the
/// fetches are.
const slot_count = 8;
var cancelers: [slot_count]?Canceler = .{null} ** slot_count;

/// Called by each owner's installHooks, once, at process start (process_start.zig).
pub fn install(canceler: Canceler) void {
    process_start.assertInstalling();
    for (&cancelers) |*slot| {
        if (slot.*) |existing| {
            if (existing == canceler) return;
            continue;
        }
        slot.* = canceler;
        return;
    }
}

/// "Abort a document" step 2 for the document whose realm is `realm`: every
/// installed owner cancels its fetches there, firing nothing.
pub fn abortAll(realm: runtime.Context) void {
    for (cancelers) |slot| {
        const canceler = slot orelse return;
        canceler(realm);
    }
}

test "install is idempotent and abortAll asks every owner" {
    const std = @import("std");
    const saved = cancelers;
    defer cancelers = saved;
    cancelers = .{null} ** slot_count;

    const Owner = struct {
        var calls: usize = 0;
        fn cancel(_: runtime.Context) void {
            calls += 1;
        }
        fn other(_: runtime.Context) void {
            calls += 10;
        }
    };
    Owner.calls = 0;
    // Never dereferenced: the owners here only count.
    const realm: runtime.Context = undefined;
    abortAll(realm);
    try std.testing.expectEqual(@as(usize, 0), Owner.calls);
    install(&Owner.cancel);
    install(&Owner.cancel);
    install(&Owner.other);
    abortAll(realm);
    try std.testing.expectEqual(@as(usize, 11), Owner.calls);
}
