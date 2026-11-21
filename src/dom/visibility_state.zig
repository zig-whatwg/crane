//! HTML 6.2 "Page visibility": "update the visibility state" of a Document.
//!
//! A document's visibility state is the Document's own state, and no IDL
//! member sets it: the user agent does, when a top-level traversable's
//! system visibility state changes (a window is minimized or restored). So
//! Document installs this hook from its installHooks, and whoever changes a system
//! visibility state - the WebDriver remote end's "minimize window" today -
//! reaches it without importing Document.
//!
//! Spec: https://html.spec.whatwg.org/multipage/interaction.html#update-the-visibility-state
//!
//! lint-impls: hook for Document

const std = @import("std");
const process_start = @import("process_start.zig");
const Hook = @import("hook.zig").Hook;
const runtime = @import("runtime");

/// A visibility state.
pub const State = enum { visible, hidden };

/// What Document supplies.
pub const Implementation = struct {
    /// "Update the visibility state" of `document` to `state`: nothing when
    /// it is already that, else set it and fire visibilitychange.
    update: *const fn (document: *runtime.Instance, state: State) void,
    /// "Set the initial visibility state" of `document` to `state`: set it,
    /// firing nothing (the navigable initialization step 6 and "activate
    /// history entry" step 6 run it with the traversable's system visibility
    /// state).
    set_initial: ?*const fn (document: *runtime.Instance, state: State) void = null,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: Hook(?Implementation) = .init(null);

/// Called by Document's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// "Update the visibility state" of `document` to `state`. With no Document
/// made yet there is no document to update.
pub fn update(document: *runtime.Instance, state: State) void {
    const impl = implementation.get() orelse return;
    impl.update(document, state);
}

/// "Set the initial visibility state" of `document` to `state` (HTML 6.2):
/// the document's visibility state, with no event. A document a navigable
/// makes active starts with its traversable navigable's system visibility
/// state.
pub fn setInitial(document: *runtime.Instance, state: State) void {
    const impl = implementation.get() orelse return;
    const set_initial = impl.set_initial orelse return;
    set_initial(document, state);
}

/// HTML 6.2 "when a user agent determines that the system visibility state
/// for traversable navigable traversable has changed to newState", step 2.2
/// for one `document` (the active document of one of the traversable's
/// inclusive descendant navigables): the task "update the visibility state"
/// is queued as - `document` named by identity and slab generation, checked
/// when it runs. The caller queues it on the document's relevant global's
/// event loop (the user interaction task source).
pub const UpdateTask = struct {
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
    generation: u64,
    state: State,

    pub fn run(context: ?*anyopaque) void {
        const self: *UpdateTask = @ptrCast(@alignCast(context orelse return));
        defer self.allocator.destroy(self);
        if (runtime.SlabAllocator.generationOf(self.document) != self.generation) return;
        update(self.document, self.state);
    }

    pub fn drop(context: ?*anyopaque) void {
        const self: *UpdateTask = @ptrCast(@alignCast(context orelse return));
        self.allocator.destroy(self);
    }
};

test "without an installed implementation updating does nothing" {
    const override = implementation.overrideForTest(null);
    defer override.restore();
    // Never dereferenced: with no implementation nothing reads the document.
    var document: runtime.Instance = undefined;
    update(&document, .hidden);
}

test "update forwards to the installed implementation" {
    const override = implementation.overrideForTest(implementation.get());
    defer override.restore();
    const Fake = struct {
        var last: ?State = null;
        fn update(_: *runtime.Instance, state: State) void {
            last = state;
        }
    };
    install(.{ .update = &Fake.update });
    var document: runtime.Instance = undefined;
    update(&document, .hidden);
    try std.testing.expectEqual(@as(?State, .hidden), Fake.last);
}
