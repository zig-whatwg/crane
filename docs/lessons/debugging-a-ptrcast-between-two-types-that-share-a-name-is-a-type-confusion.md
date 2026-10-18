# Debugging: A @ptrCast between two types that share a name is a type confusion

**Date**: 2026-10-18
**Lesson**: HTMLIFrameElement.get_contentWindow returned the integration's `*WindowProxy` - a Zig struct embedded in IFrameIntegration (html/window/window_proxy.zig) - through `@ptrCast` as the WebIDL WindowProxy typedef, which is `*runtime.Instance`: callers read the struct's bytes as a Window's state.

**Why**: Two unrelated types are both called WindowProxy: HTML's struct (a browsing context, an origin, an allocator) and the generated typedef for the IDL `WindowProxy`, an alias of `*runtime.Instance`. `@ptrCast` converts any pointer to any pointer, so the "fall back to old WindowProxy behavior" lines compiled and looked right. They ran only when the navigable had no window to answer: no realm context (a navigation whose new realm could not be made - replaceRealm releases the old one before attachRealm fails) and createChildNavigable failing too, or a realm with no Window.

**What Happened**: Lane leaks4's iframe OOM sweep reported a frame whose Window named "a Document with no internal state" (Registry entry gone), read through contentWindow. Lane leaks5 could not reproduce a container-less document on lane/int4, where the sweep reads contentWindow with memory to spare and createChildNavigable rebuilds the frame. A sweep that reads contentWindow while memory is still out reaches the fallback. Cited as the probable cause, not proven.

**Fix**: Both fallbacks answer null ("no content window"). tests/html/iframe_policy_container_oom_test.zig reads contentWindow out of memory right after each failing srcdoc navigation round: null or an instance whose vtable is Window's, never anything else, and at least one round must reach the no-window state.

**Takeaway**: **A @ptrCast between pointers to two different named types is a type confusion until proven otherwise - when two types share a name, grep for the casts between them.**
