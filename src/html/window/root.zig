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
//! ├── window_proxy.zig       # WindowProxy with cross-origin restrictions
//! ├── ui_backend.zig         # Pluggable UI (alert, confirm, prompt, print)
//! ├── animation_frame.zig    # requestAnimationFrame scheduling
//! └── root.zig               # Module exports (this file)
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const window = @import("html/window/root.zig");
//!
//! // Create a top-level browsing context
//! const ctx = try window.BrowsingContext.initTopLevel(allocator);
//! defer ctx.deinit();
//!
//! // Create UI backend for prompts
//! var ui = window.StubUIBackend.init(.{});
//! ui.backend().showAlert("Hello!");
//!
//! // Animation frame scheduling
//! var timing = window.StubFrameTimingBackend.init();
//! var scheduler = try window.AnimationFrameScheduler.init(allocator, timing.backend());
//! defer scheduler.deinit();
//!
//! const handle = try scheduler.requestAnimationFrame(callback, context);
//! ```

const std = @import("std");

// Browsing Context (§7.1)
pub const browsing_context = @import("browsing_context.zig");
pub const BrowsingContext = browsing_context.BrowsingContext;
pub const BrowsingContextGroup = browsing_context.BrowsingContextGroup;

// WindowProxy (§7.4)
pub const window_proxy = @import("window_proxy.zig");
pub const WindowProxy = window_proxy.WindowProxy;
pub const Origin = window_proxy.Origin;
pub const CrossOriginProperty = window_proxy.CrossOriginProperty;
pub const WindowProxyError = window_proxy.WindowProxyError;

// UI Backend (§8.8 - Simple dialogs)
pub const ui_backend = @import("ui_backend.zig");
pub const UIBackend = ui_backend.UIBackend;
pub const StubUIBackend = ui_backend.StubUIBackend;
pub const StubUIBackendConfig = ui_backend.StubUIBackendConfig;
pub const ConsoleUIBackend = ui_backend.ConsoleUIBackend;
pub const CallbackUIBackend = ui_backend.CallbackUIBackend;

// Animation Frame (§8.14.2)
pub const animation_frame = @import("animation_frame.zig");
pub const AnimationFrameScheduler = animation_frame.AnimationFrameScheduler;
pub const FrameTimingBackend = animation_frame.FrameTimingBackend;
pub const StubFrameTimingBackend = animation_frame.StubFrameTimingBackend;
pub const MockFrameTimingBackend = animation_frame.MockFrameTimingBackend;
pub const FrameRequestCallback = animation_frame.FrameRequestCallback;
pub const DOMHighResTimeStamp = animation_frame.DOMHighResTimeStamp;

test {
    std.testing.refAllDecls(@This());
}
