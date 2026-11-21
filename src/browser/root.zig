//! Browser Module
//!
//! Implements a browser abstraction with:
//! - Single V8 isolate lifecycle
//! - Per-navigation V8 contexts
//! - Persistent storage (cookies, localStorage, IndexedDB, etc.)
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
//!     └── Storage (persisted)
//!             ├── Cookies
//!             ├── LocalStorage
//!             ├── SessionStorage
//!             ├── IndexedDB
//!             └── Cache
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

/// What every Browser shares, started once before any (docs/instances.md).
pub const process = @import("process.zig");
pub const Process = process.Process;

/// When the allocator's free memory goes back to the OS: the idle rule and
/// the process's hold-off between releases.
pub const memory_release = @import("memory_release.zig");

/// A Browser's receiver for platform events (the platform protocol's
/// EventSink): a critical memory-pressure event becomes tasks.
pub const platform_events = @import("platform_events.zig");

pub const Context = @import("Context.zig").Context;
pub const back_forward_cache = @import("back_forward_cache.zig");
pub const ContextType = @import("Context.zig").ContextType;

/// The Browser's isolated worlds (CDP's Page.createIsolatedWorld): the
/// registry of world ids by navigable and name, and their realms.
pub const isolated_worlds = @import("isolated_worlds.zig");

pub const storage = @import("storage/Storage.zig");
pub const Storage = storage.Storage;
pub const LocalStorage = storage.LocalStorage;
pub const SessionStorage = storage.SessionStorage;

test {
    _ = @import("Browser.zig");
    _ = @import("process.zig");
    _ = @import("Context.zig");
    _ = @import("rendering.zig");
    _ = @import("memory_release.zig");
    _ = @import("storage/Storage.zig");
    _ = @import("isolated_worlds.zig");
}
