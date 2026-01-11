//! Crane Version
//!
//! IMPORTANT: This is the single source of truth for Crane's version.
//! When updating the version, change ONLY this file - build.zig.zon
//! will be updated automatically by the release process.
//!
//! The version follows semantic versioning (MAJOR.MINOR.PATCH).

/// The current Crane version
pub const version = "0.0.0";

/// Full version string with name (e.g., "Crane/0.0.0")
pub const full = "Crane/" ++ version;
