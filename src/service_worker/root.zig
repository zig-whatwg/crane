//! Service Workers (W3C), for one Browser at a time.
//!
//! - scope.zig: Start Register's URL checks, scope strings, registration
//!   matching and the maximum scope (`Service-Worker-Allowed`).
//! - registry.zig: the registration map, the job queues, the service worker
//!   records and the algorithms that change them - engine-free, run under
//!   the owner's lock, resumed by the answers to what they wait for.
//!
//! cache/ (and the types.zig and interfaces/types.zig it reads) is the
//! early-2026 Cache API model, not built yet: batch 2 reviews it when Cache
//! Storage lands.
//!
//! Spec: https://w3c.github.io/ServiceWorker/

pub const scope = @import("scope.zig");
pub const registry = @import("registry.zig");

pub const Registry = registry.Registry;
