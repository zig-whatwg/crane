//! Platform Abstraction Layer
//!
//! Provides platform-specific backend implementations for:
//! - Timer management (setTimeout, setInterval)
//! - Layout engine integration (for CSSOM View properties)
//!
//! These backends are designed to be replaceable by embedders.

pub const timer_backend = @import("timer_backend.zig");
pub const layout_backend = @import("layout_backend.zig");

// Re-export commonly used types
pub const TimerBackend = timer_backend.TimerBackend;
pub const RealTimerBackend = timer_backend.RealTimerBackend;
pub const MockTimerBackend = timer_backend.MockTimerBackend;

pub const LayoutBackend = layout_backend.LayoutBackend;
pub const StubLayoutBackend = layout_backend.StubLayoutBackend;
