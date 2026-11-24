//! High Resolution Time Module
//!
//! WHATWG/W3C HR-Time Spec: https://w3c.github.io/hr-time/
//!
//! This module provides the implementation for the High Resolution Time
//! specification, which defines APIs for sub-millisecond time resolution.
//!
//! ## Components
//!
//! - **clock**: Monotonic and wall clock implementations
//! - **coarsen**: Time coarsening for security (timing attack mitigation)
//! - **time_origin**: Time origin management for contexts
//!
//! ## Usage
//!
//! ```zig
//! const hr_time = @import("hr_time");
//!
//! // Create a time origin for a new context (Window or Worker)
//! const origin = hr_time.TimeOrigin.init(false); // not cross-origin isolated
//!
//! // Get Performance.now() equivalent
//! const now_ms = origin.currentRelativeTimestampMs();
//!
//! // Get Performance.timeOrigin equivalent
//! const time_origin_ms = origin.getTimeOriginTimestampMs();
//! ```
//!
//! ## Spec Compliance
//!
//! This implementation follows the W3C High Resolution Time specification:
//! - Monotonic clock for performance measurements
//! - Time coarsening (100μs default, 5μs cross-origin isolated)
//! - Time origin per environment settings object
//! - Wall clock for epoch-relative timestamps

const std = @import("std");

// Re-export all sub-modules
pub const clock = @import("clock.zig");
pub const coarsen = @import("coarsen.zig");
pub const time_origin = @import("time_origin.zig");

// Re-export commonly used types at top level
pub const MonotonicClock = clock.MonotonicClock;
pub const WallClock = clock.WallClock;
pub const Nanoseconds = clock.Nanoseconds;
pub const TimeOrigin = time_origin.TimeOrigin;

// Re-export commonly used functions at top level
pub const coarsenTime = coarsen.coarsenTime;
pub const toMilliseconds = clock.toMilliseconds;
pub const fromMilliseconds = clock.fromMilliseconds;
pub const currentCoarsenedWallTime = time_origin.currentCoarsenedWallTime;
pub const coarsenedSharedCurrentTime = time_origin.coarsenedSharedCurrentTime;

// Constants
pub const DEFAULT_RESOLUTION_NS = coarsen.DEFAULT_RESOLUTION_NS;
pub const CROSS_ORIGIN_ISOLATED_RESOLUTION_NS = coarsen.CROSS_ORIGIN_ISOLATED_RESOLUTION_NS;
