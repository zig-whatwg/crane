//! HTML Storage Module
//!
//! This module provides Web Storage API implementations for localStorage
//! and sessionStorage as defined in the HTML Standard.
//!
//! ## Components
//!
//! - **web_storage**: Storage interface, StorageEvent, localStorage/sessionStorage getters
//!
//! ## Specification References
//!
//! - HTML Standard § 12: Web storage
//!   https://html.spec.whatwg.org/multipage/webstorage.html
//! - Storage Standard
//!   https://storage.spec.whatwg.org/

pub const web_storage = @import("web_storage.zig");

// Re-export main types
pub const Storage = web_storage.Storage;
pub const StorageEvent = web_storage.StorageEvent;
pub const StorageEventData = web_storage.StorageEventData;
pub const StorageEventBroadcaster = web_storage.StorageEventBroadcaster;
pub const StorageType = web_storage.StorageType;
pub const StorageError = web_storage.StorageError;

// Re-export getter functions
pub const getLocalStorage = web_storage.getLocalStorage;
pub const getSessionStorage = web_storage.getSessionStorage;

test {
    _ = web_storage;
}
