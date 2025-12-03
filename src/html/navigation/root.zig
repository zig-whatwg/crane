//! Navigation Module - HTML Standard §7
//!
//! This module provides the navigation and history infrastructure for the HTML
//! browsing context model.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html
//!
//! ## Components
//!
//! - **Session History**: History entries with URL, document state, scroll position
//! - **History API**: pushState, replaceState, back, forward, go
//! - **Location API**: URL component access and navigation methods
//! - **Events**: popstate, hashchange, beforeunload, pageshow, pagehide
//! - **Navigable**: Document presentation context
//! - **Algorithms**: Navigate, fragment navigation, history traversal

pub const session_history = @import("session_history.zig");
pub const history = @import("history.zig");
pub const location = @import("location.zig");
pub const events = @import("events.zig");
pub const navigable = @import("navigable.zig");
pub const algorithms = @import("algorithms.zig");
pub const fetch_integration = @import("fetch_integration.zig");
pub const document_creation = @import("document_creation.zig");

// Re-export commonly used types

// Session History
pub const SessionHistoryEntry = session_history.SessionHistoryEntry;
pub const SessionHistoryList = session_history.SessionHistoryList;
pub const DocumentState = session_history.DocumentState;
pub const SerializedState = session_history.SerializedState;
pub const ScrollRestorationMode = session_history.ScrollRestorationMode;
pub const ScrollPosition = session_history.ScrollPosition;
pub const ScrollPositionData = session_history.ScrollPositionData;
pub const PostResource = session_history.PostResource;
pub const NestedHistory = session_history.NestedHistory;
pub const ReferrerPolicy = session_history.ReferrerPolicy;
pub const RequestReferrer = session_history.RequestReferrer;

// History API
pub const History = history.History;
pub const HistoryError = history.HistoryError;
pub const HistoryHandlingBehavior = history.HistoryHandlingBehavior;
pub const NavigationHistoryBehavior = history.NavigationHistoryBehavior;
pub const canRewriteUrl = history.canRewriteUrl;

// Location API
pub const Location = location.Location;
pub const LocationError = location.LocationError;
pub const UrlComponents = location.UrlComponents;

// Events
pub const PopStateEvent = events.PopStateEvent;
pub const PopStateEventInit = events.PopStateEventInit;
pub const HashChangeEvent = events.HashChangeEvent;
pub const HashChangeEventInit = events.HashChangeEventInit;
pub const PageTransitionEvent = events.PageTransitionEvent;
pub const PageTransitionEventInit = events.PageTransitionEventInit;
pub const BeforeUnloadEvent = events.BeforeUnloadEvent;
pub const NavigationCurrentEntryChangeEvent = events.NavigationCurrentEntryChangeEvent;
pub const NavigationType = events.NavigationType;
pub const NavigationEventDispatcher = events.NavigationEventDispatcher;

// Navigable
pub const Navigable = navigable.Navigable;
pub const NavigableState = navigable.NavigableState;
pub const TraversableNavigable = navigable.TraversableNavigable;
pub const TraversalTask = navigable.TraversalTask;
pub const UserInvolvement = navigable.UserInvolvement;
pub const VisibilityState = navigable.VisibilityState;
pub const LoadingMode = navigable.LoadingMode;
pub const getChildNavigables = navigable.getChildNavigables;
pub const getDescendantNavigables = navigable.getDescendantNavigables;
pub const getInclusiveAncestorNavigables = navigable.getInclusiveAncestorNavigables;

// Algorithms
pub const navigate = algorithms.navigate;
pub const navigateToFragment = algorithms.navigateToFragment;
pub const urlAndHistoryUpdateSteps = algorithms.urlAndHistoryUpdateSteps;
pub const applyHistoryStep = algorithms.applyHistoryStep;
pub const traverseHistoryByDelta = algorithms.traverseHistoryByDelta;
pub const unloadDocument = algorithms.unloadDocument;
pub const promptToUnload = algorithms.promptToUnload;
pub const NavigationError = algorithms.NavigationError;
pub const NavigationParams = algorithms.NavigationParams;
pub const NavigateOptions = algorithms.NavigateOptions;
pub const SourceSnapshotParams = algorithms.SourceSnapshotParams;
pub const TargetSnapshotParams = algorithms.TargetSnapshotParams;

// Fetch Integration
pub const fetchNavigationResource = fetch_integration.fetchNavigationResource;
pub const NavigationFetchResult = fetch_integration.NavigationFetchResult;
pub const NavigationFetchOptions = fetch_integration.NavigationFetchOptions;
pub const NavigationFetchError = fetch_integration.NavigationFetchError;
pub const isHtmlResponse = fetch_integration.isHtmlResponse;
pub const isXmlResponse = fetch_integration.isXmlResponse;
pub const shouldNavigationProceed = fetch_integration.shouldNavigationProceed;
pub const isCrossOrigin = fetch_integration.isCrossOrigin;

// Document Creation
pub const createDocumentFromResponse = document_creation.createDocumentFromResponse;
pub const createDocumentFromHtml = document_creation.createDocumentFromHtml;
pub const createAboutBlankDocument = document_creation.createAboutBlankDocument;
pub const replaceActiveDocument = document_creation.replaceActiveDocument;
pub const runDocumentLoadCompletionSteps = document_creation.runDocumentLoadCompletionSteps;
pub const DocumentCreationError = document_creation.DocumentCreationError;
pub const DocumentCreationOptions = document_creation.DocumentCreationOptions;
pub const CreatedDocument = document_creation.CreatedDocument;

// Tests
test {
    @import("std").testing.refAllDecls(@This());
}
