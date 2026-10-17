//! WebIDL [Exposed] for the worklet global scopes: each worklet's realm
//! installs what is exposed to its own global name and to "Worklet" (every
//! worklet global scope's [Global] lists "Worklet"), and nothing a worker or
//! a Window alone has. Pinned before installForScope relies on it - the
//! defaults included: an unknown identifier and the worker names expose
//! nothing to a worklet.

const std = @import("std");
const testing = std.testing;
const webidl = @import("webidl");
const GlobalScope = webidl.helpers.GlobalScope;

const worklet_scopes = [_]GlobalScope{ .PaintWorklet, .LayoutWorklet, .AnimationWorklet, .AudioWorklet };

test "every worklet global scope matches [Exposed=Worklet] and its own name, and no other" {
    for (worklet_scopes) |scope| {
        try testing.expect(scope.matchesExposure("Worklet"));
        try testing.expect(scope.matchesExposure(scope.toString()));
        try testing.expect(!scope.matchesExposure("Worker"));
        try testing.expect(!scope.matchesExposure("Window"));
        try testing.expect(!scope.matchesExposure("DedicatedWorker"));
        try testing.expect(!scope.matchesExposure("NoSuchGlobal"));
        for (worklet_scopes) |other| {
            if (other == scope) continue;
            try testing.expect(!scope.matchesExposure(other.toString()));
        }
    }
    try testing.expect(!GlobalScope.Window.matchesExposure("Worklet"));
    try testing.expect(!GlobalScope.DedicatedWorker.matchesExposure("Worklet"));
    try testing.expectEqual(GlobalScope.PaintWorklet, GlobalScope.fromString("PaintWorklet").?);
}
