//! Window & Global Environment - HTML Standard §7
//!
//! This module provides the core Window infrastructure per the HTML specification:
//!
//! - **Browsing Contexts** (§7.1) - Environment for presenting Documents
//! - **Window Interface** (§7.2) - Global object for web pages
//! - **UI Backend** (§8.8) - Pluggable user prompts (alert, confirm, prompt)
//! - **Animation Frames** (§8.14.2) - requestAnimationFrame scheduling
//!
//! Spec: https://html.spec.whatwg.org/multipage/window-object.html
//!
//! ## Architecture
//!
//! ```
//! src/html/window/
//! ├── browsing_context.zig   # BrowsingContext, BrowsingContextGroup
//! ├── window_proxy.zig       # a navigable's WindowProxy record (no access checks)
//! ├── iframe_integration.zig # IFrame ↔ BrowsingContext lifecycle
//! ├── ui_backend.zig         # Pluggable UI (alert, confirm, prompt, print)
//! └── root.zig               # Module exports (this file)
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const window = @import("html/window/root.zig");
//!
//! // Create a top-level browsing context
//! var navigables = window.Navigables.init(allocator);
//! defer navigables.deinit();
//! const ctx = try window.BrowsingContext.initTopLevel(allocator, &navigables);
//! defer ctx.deinit();
//!
//! // Create UI backend for prompts
//! var ui = window.StubUIBackend.init(.{});
//! ui.backend().showAlert("Hello!");
//! ```
//!
//! requestAnimationFrame is the Browser's frame clock (src/browser/rendering.zig).

const std = @import("std");

// Browsing Context (§7.1)
pub const browsing_context = @import("browsing_context.zig");
pub const BrowsingContext = browsing_context.BrowsingContext;
pub const Navigables = browsing_context.Navigables;
pub const BrowsingContextGroup = browsing_context.BrowsingContextGroup;
pub const SandboxingFlagSet = browsing_context.SandboxingFlagSet;

// WindowProxy (§7.4)
pub const window_proxy = @import("window_proxy.zig");
pub const WindowProxy = window_proxy.WindowProxy;
pub const Origin = window_proxy.Origin;
pub const WindowProxyError = window_proxy.WindowProxyError;

// IFrame Integration (§7.5)
pub const iframe_integration = @import("iframe_integration.zig");
pub const IFrameIntegration = iframe_integration.IFrameIntegration;
pub const IFrameState = iframe_integration.IFrameState;
pub const IFrameError = iframe_integration.IFrameError;

// UI Backend (§8.8 - Simple dialogs)
pub const ui_backend = @import("ui_backend.zig");
pub const UIBackend = ui_backend.UIBackend;
pub const StubUIBackend = ui_backend.StubUIBackend;
pub const StubUIBackendConfig = ui_backend.StubUIBackendConfig;
pub const ConsoleUIBackend = ui_backend.ConsoleUIBackend;
pub const CallbackUIBackend = ui_backend.CallbackUIBackend;

test {
    std.testing.refAllDecls(@This());
}
