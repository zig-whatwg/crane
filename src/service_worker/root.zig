//! Service Workers (W3C), for one Browser at a time.
//!
//! - scope.zig: Start Register's URL checks, scope strings, registration
//!   matching and the maximum scope (`Service-Worker-Allowed`).
//! - registry.zig: the registration map, the job queues, the service worker
//!   records and the algorithms that change them - engine-free, run under
//!   the owner's lock, resumed by the answers to what they wait for.
//! - manager.zig: a Browser's registry under its lock (a BrowserScope
//!   supplement), its job thread, and the service worker threads it starts.
//! - update_fetch.zig: the Update algorithm's fetch and byte-for-byte check.
//! - run.zig: the manager's production host - Fetch, and Run Service Worker
//!   over html's worker threads, with the install and activate events.
//! - realm.zig: what a realm keeps of service workers (its environment, its
//!   object maps, its promises) and the steps of the API members script
//!   calls; objects.zig: the ServiceWorker and ServiceWorkerRegistration
//!   objects' state; extend_lifetime.zig: an ExtendableEvent's extended
//!   lifetime; fetch_event.zig: Create Fetch Event and Dispatch on the
//!   worker's thread, respondWith(), and a response body read for the
//!   fetching thread; navigation_preload.zig: the navigation preload's fetch
//!   (Handle Fetch step 15) on the worker's thread; router.zig: static
//!   routing's rules and algorithms, engine-free; add_routes.zig:
//!   InstallEvent.addRoutes() in the worker's realm.
//!
//! - cache/: Cache Storage - a Browser's caches in its store, and the
//!   steps of CacheStorage's and Cache's members.
//!
//! Spec: https://w3c.github.io/ServiceWorker/

pub const scope = @import("scope.zig");
pub const registry = @import("registry.zig");
pub const manager = @import("manager.zig");
pub const update_fetch = @import("update_fetch.zig");
pub const run = @import("run.zig");
pub const realm = @import("realm.zig");
pub const objects = @import("objects.zig");
pub const fetch_event = @import("fetch_event.zig");
pub const navigation_preload = @import("navigation_preload.zig");
pub const router = @import("router.zig");
pub const add_routes = @import("add_routes.zig");
pub const cache = @import("cache/root.zig");

pub const Registry = registry.Registry;
pub const Manager = manager.Manager;
pub const ServiceWorkerObject = objects.ServiceWorkerObject;
pub const RegistrationObject = objects.RegistrationObject;
pub const ExtendLifetime = @import("extend_lifetime.zig").ExtendLifetime;
