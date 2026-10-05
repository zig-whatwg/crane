//! The Web Locks API's engine-free parts (W3C Web Locks API).
//!
//! - `Registry`: a Browser's lock managers - one per storage key - and the
//!   environments using them; a supplement of the Browser's scope
//!   (runtime.BrowserScope), reached from every thread the Browser runs.
//! - `lock_objects`: the hook Lock installs, through which LockManager makes
//!   "a new Lock object associated with lock".
//! - `lock_managers`: the hook LockManager installs, through which the
//!   NavigatorLocks `locks` getter finds its environment's LockManager.
//!
//! The script-facing half is impls/LockManager.zig and impls/Lock.zig.
//!
//! Spec: https://w3c.github.io/web-locks/

const registry = @import("registry.zig");

pub const Registry = registry.Registry;
pub const Client = registry.Client;
pub const Delivery = registry.Delivery;
pub const Event = registry.Event;
pub const EventKind = registry.EventKind;
pub const Mode = registry.Mode;
pub const RequestOptions = registry.RequestOptions;
pub const Snapshot = registry.Snapshot;
pub const Info = registry.Info;
pub const Error = registry.Error;
pub const client_id_len = registry.client_id_len;

pub const lock_objects = @import("lock_objects.zig");
pub const lock_managers = @import("lock_managers.zig");
