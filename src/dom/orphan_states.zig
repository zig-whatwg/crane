//! A node type's own state block, with both of its exits.
//!
//! A node removed from its tree while script held no wrapper of it - an
//! `innerHTML = ''` or `replaceChildren()` over an unwrapped subtree, a
//! sanitizer's removal - or whose wrapper was collected while it was in its
//! tree and which was then removed, is an ORPHAN: no tree teardown and no
//! collector reaches it before reference counting lands, so its deinit never
//! runs (docs/lessons/architecture-an-element-alive-at-teardown-is-swept-not-deinitd.md).
//! What its state owns is then freed only by its type's sweep at its
//! Browser's end (dom.teardown_sweeps), and a block outside every registry
//! has no exit at all
//! (docs/lessons/architecture-an-orphan-s-state-needs-a-sweep-or-the-arena.md).
//!
//! `Swept(tag, T)` gives a node type's state both exits at once:
//!
//! - the block is the Browser's runtime arena's, registered in the
//!   Browser's side table `tag` (`runtime.InstanceRegistry`);
//! - the type's deinit hands it back with `destroy` - `T.deinit`, then the
//!   block to the arena;
//! - `installSweep`, from the type's installHooks, puts a sweep in
//!   `.element_types` that runs `T.deinit` on every entry no deinit reached,
//!   at its Browser's end; the arena takes the blocks.
//!
//! A type that already keeps such a registry of its own gives it the sweep
//! with `installRegistrySweep`.
//!
//! `T.deinit` is therefore what the state OWNS, freed without its instance:
//! at the Browser's end the instance's realm is gone, and the sweep must not
//! read it. Steps that need the instance (an edge to forget, a child to
//! sever, a load to end) stay in the type's deinit, before `destroy`.
//!
//! A state that owns nothing beyond its block needs no registry and no
//! sweep: take it from `runtime.arenaOf(instance)` and give it back there in
//! the deinit; an orphan's block then goes with the arena.
//!
//! A state that may outlive its instance (a queued task still holding it)
//! cannot be the arena's through the registry, whose `remove` returns the
//! block at once; such a type keeps its block and writes its own sweep
//! (HTMLMediaElement, HTMLTrackElement).

const std = @import("std");
const runtime = @import("runtime");
const teardown_sweeps = @import("teardown_sweeps.zig");

/// The state `T` of a node type, in its Browser's side table `tag` (one tag
/// per type), with an exit for every instance: its deinit's (`destroy`) and,
/// for an orphan, its Browser's end (`installSweep`).
pub fn Swept(comptime tag: runtime.BrowserScope.Table, comptime T: type) type {
    comptime {
        if (!@hasDecl(T, "deinit")) @compileError(@typeName(T) ++
            " owns nothing beyond its block: take it from runtime.arenaOf(instance), with no registry and no sweep");
    }
    return struct {
        const Registry = runtime.InstanceRegistry(tag, T);

        /// `instance`'s state, made: a block of its Browser's arena holding
        /// `value`, registered so that the sweep reaches it if no deinit
        /// does. Once per instance - in its init, or when the state is
        /// first needed.
        pub fn create(instance: *const runtime.Instance, value: T) !*T {
            const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
            internal.* = value;
            return internal;
        }

        /// `instance`'s state, or null when it has none (not made yet, or
        /// destroyed).
        pub fn get(instance: *const runtime.Instance) ?*T {
            return Registry.get(instance);
        }

        /// The deinit's exit: what `instance`'s state owns (`T.deinit`), then
        /// its block, back to the arena. Nothing when it has no state.
        pub fn destroy(instance: *const runtime.Instance) void {
            if (Registry.get(instance)) |internal| internal.deinit();
            Registry.remove(instance);
        }

        /// The orphan's exit: install the type's sweep. Once, at process
        /// start, from the type's installHooks.
        pub fn installSweep() void {
            installRegistrySweep(Registry);
        }

        /// How many of `scope`'s instances have a state (tests).
        pub fn count(scope: *runtime.BrowserScope) usize {
            return Registry.count(scope);
        }
    };
}

/// The orphan's exit for a type that keeps its state in a
/// `runtime.InstanceRegistry` of its own (`Registry`), registry-owned blocks
/// of the arena whose `deinit` frees what they own without their instance:
/// a sweep in `.element_types` that runs that `deinit` on every entry no
/// deinit reached, at its Browser's end. Once, at process start, from the
/// type's installHooks.
pub fn installRegistrySweep(comptime Registry: type) void {
    teardown_sweeps.install(.element_types, &Registry.deinitAllAndClear);
}
