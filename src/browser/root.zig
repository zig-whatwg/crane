//! Browser Module
//!
//! Implements a browser abstraction with:
//! - Single V8 isolate lifecycle
//! - Per-navigation V8 contexts
//! - Its web state's stores in the platform's storage engine, persisted
//!   under a profile directory when it has one (profile_stores.zig)
//! - WPT test harness integration
//!
//! ## Architecture
//!
//! ```
//! Browser (single V8 isolate)
//!     ├── Context (per navigation)
//!     │       ├── Window globals
//!     │       ├── Document
//!     │       └── WebIDL bindings
//!     └── scope supplements: cookie jar, user agent storage (localStorage),
//!         IndexedDB server, network context (HTTP cache), Cache Storage -
//!         their stores the platform's (kit/memory_store, or kit/sqlite
//!         under a profile directory)
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const browser = @import("browser");
//!
//! var b = try browser.Browser.init(allocator, .{});
//! defer b.deinit();
//!
//! // Navigate creates new context, preserves storage
//! try b.navigate("http://example.com/test.html");
//!
//! // Execute script in current context
//! const result = try b.evaluateScript("document.title");
//! ```

pub const Browser = @import("Browser.zig").Browser;
pub const BrowserConfig = @import("Browser.zig").BrowserConfig;
/// BrowserConfig.general_memory's choices (allocator-hardening batch B).
pub const GeneralMemory = @import("Browser.zig").GeneralMemory;

/// A Browser on a thread of its own, driven from other threads by commands
/// posted to its loop: the host API's thread-safe surface (lane cdph).
pub const BrowserHost = @import("BrowserHost.zig").BrowserHost;
/// What a Browser tells its host as it happens: tabs and frames.
pub const host_events = @import("host_events.zig");
/// A script value as the host API hands it out (BiDi's RemoteValue, JSON).
pub const remote_value = @import("remote_value.zig");
/// The host API's C ABI (include/crane.h): its `crane_*` symbols are
/// emitted only by an artifact that references this (src/lib_exports.zig).
pub const capi = @import("capi.zig");

/// What every Browser shares, started once before any (docs/instances.md).
pub const process = @import("process.zig");
pub const Process = process.Process;

/// When the allocator's free memory goes back to the OS: the idle rule and
/// the process's hold-off between releases.
pub const memory_release = @import("memory_release.zig");

/// A Browser's receiver for platform events (the platform protocol's
/// EventSink): a critical memory-pressure event becomes tasks.
pub const platform_events = @import("platform_events.zig");
/// A top-level traversable's viewport: the platform's window rect and a
/// host's override (CDP Emulation.setDeviceMetricsOverride).
pub const viewport = @import("viewport.zig");

pub const Context = @import("Context.zig").Context;
pub const back_forward_cache = @import("back_forward_cache.zig");
pub const ContextType = @import("Context.zig").ContextType;

/// The Browser's isolated worlds (CDP's Page.createIsolatedWorld): the
/// registry of world ids by navigable and name, and their realms.
pub const isolated_worlds = @import("isolated_worlds.zig");

test {
    _ = @import("Browser.zig");
    _ = @import("BrowserHost.zig");
    _ = @import("host_events.zig");
    _ = @import("remote_value.zig");
    _ = @import("process.zig");
    _ = @import("Context.zig");
    _ = @import("rendering.zig");
    _ = @import("viewport.zig");
    _ = @import("memory_release.zig");
    _ = @import("isolated_worlds.zig");
}
