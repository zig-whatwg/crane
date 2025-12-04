//! Platform Abstraction Layer
//!
//! Provides platform-specific backend implementations for:
//! - Timer management (setTimeout, setInterval)
//! - Layout engine integration (for CSSOM View properties)
//! - Clipboard access (copy, cut, paste)
//!
//! These backends are designed to be replaceable by embedders.

pub const timer_backend = @import("timer_backend.zig");
pub const layout_backend = @import("layout_backend.zig");
pub const clipboard_backend = @import("clipboard_backend.zig");

// Re-export commonly used types
pub const TimerBackend = timer_backend.TimerBackend;
pub const RealTimerBackend = timer_backend.RealTimerBackend;
pub const MockTimerBackend = timer_backend.MockTimerBackend;

pub const LayoutBackend = layout_backend.LayoutBackend;
pub const StubLayoutBackend = layout_backend.StubLayoutBackend;

pub const ClipboardBackend = clipboard_backend.ClipboardBackend;
pub const StubClipboardBackend = clipboard_backend.StubClipboardBackend;
pub const DeniedClipboardBackend = clipboard_backend.DeniedClipboardBackend;
pub const ClipboardFormat = clipboard_backend.ClipboardFormat;
pub const ClipboardItem = clipboard_backend.ClipboardItem;
pub const ClipboardResult = clipboard_backend.ClipboardResult;
