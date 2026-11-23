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
//! ├── host_overrides.zig     # a host's per-tab overrides (CDP Emulation, BiDi emulation)
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
//! ```
//!
//! Simple dialogs (alert, confirm, prompt) and print are html.simple_dialogs'.
//!
//! requestAnimationFrame is the Browser's frame clock (src/browser/rendering.zig).

const std = @import("std");

// Browsing Context (§7.1)
pub const browsing_context = @import("browsing_context.zig");
/// A host's overrides of the platform's answers for a tab (CDP Emulation,
/// WebDriver BiDi emulation).
pub const host_overrides = @import("host_overrides.zig");
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

test {
    std.testing.refAllDecls(@This());
}
