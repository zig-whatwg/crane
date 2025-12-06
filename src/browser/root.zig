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

pub const Context = @import("Context.zig").Context;
pub const ContextType = @import("Context.zig").ContextType;

pub const storage = @import("storage/Storage.zig");
pub const Storage = storage.Storage;
pub const CookieStore = storage.CookieStore;
pub const Cookie = storage.Cookie;
pub const LocalStorage = storage.LocalStorage;
pub const SessionStorage = storage.SessionStorage;

test {
    _ = @import("Browser.zig");
    _ = @import("Context.zig");
    _ = @import("storage/Storage.zig");
}
