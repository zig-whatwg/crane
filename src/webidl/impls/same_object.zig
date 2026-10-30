//! Moved to src/dom/same_object.zig (impls batch 7): a shared helper does not
//! live in src/webidl/impls/ (AGENTS.md, the impls boundary rule 3). These
//! aliases keep the impls that import this file by path compiling; each
//! imports `@import("dom").same_object` instead when it is next edited.
const same_object = @import("dom").same_object;

pub const Pin = same_object.Pin;
pub const Traced = same_object.Traced;
pub const Link = same_object.Link;
pub const KeptChild = same_object.KeptChild;
