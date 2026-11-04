//! The process's start-up and the slots it writes: Crane's `process` module.
//!
//! - `start` (start.zig): the start-up phase word - not started, starting,
//!   running, ended - that `crane.Process` (src/browser/process.zig) moves
//!   through, and who may write a hook slot in each phase (`start.writer`).
//! - `Hook(T)` and `List(T, capacity)` (hook.zig): a process-wide slot an
//!   owner installs while the process starts, frozen after; a registration
//!   list is a `Hook(List(T, capacity))`.
//!
//! A LEAF module, with no dependency but std, like `clock`, `host` and
//! `memory` (build.zig): every layer declares hook slots - src/dom's hook
//! modules, but also the runtime tier, the V8 adapter, fetch and hr_time,
//! which sit BELOW dom in the module graph and cannot import it
//! (tmp/plans/hookfreeze-design.md, "How P-res fits"). A module that imports
//! nothing cannot be part of an import cycle. It is not `infra`: infra is the
//! WHATWG Infra Standard's data structures, imports clock and host, and the
//! start-up phase is an engine concern no spec defines (docs/instances.md).
//!
//! src/dom re-exports both (`dom.Hook`, `dom.hook`, `dom.process_start`), so
//! a src/dom hook module keeps `@import("hook.zig").Hook`; a module below dom
//! writes `const Hook = @import("process").Hook;`.

pub const start = @import("start.zig");
pub const hook = @import("hook.zig");
pub const Hook = hook.Hook;
pub const List = hook.List;

test {
    _ = start;
    _ = hook;
}
