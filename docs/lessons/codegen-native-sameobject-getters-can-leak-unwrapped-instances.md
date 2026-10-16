# Codegen: Native SameObject getters can leak unwrapped instances

**Date**: 2026-10-16
**Lesson**: Calling an object-valued getter from native code can allocate a cached instance whose lifetime the generated cache does not own.

**Why**: SVGAElement's generated SameObject getter caches a bare
SVGAnimatedString pointer. A script call wraps the result; a native call that
only reads its scalar value does not. Keeping a pointer is not an ownership
mechanism for the unwrapped object's allocations.

**What Happened**: Origin extraction initially called
interfaces.SVGAElement.get_href and then SVGAnimatedString.get_animVal. The
upstream origin-from-hyperlinkelementutils.window.js file passed its 104
supported subtests, but leaked three allocations in each of 25 xlink-only
cases. Matched Debug runs with CRANE_LEAK_TRACES=1 measured BASE 0 and the
candidate 75 Zig leak markers. The stacks named SVGAnimatedString.initOwn:
25 attribute strings, 25 deprecated-namespace strings and 25 InternalStates.
The OS leaks report stayed at two pre-existing V8 snapshot leaks, so it alone
would have missed this regression.

The same Debug WPT after sharing the scalar read returned to zero Zig leaks,
with the OS count unchanged. The native before-fix regression separately
reported exactly three leaked allocations for one xlink-only anchor.

**Fix**:

1. Move the existing SVG 2 4.6.7 attribute/fallback read into the pure
   dom.reflected_with_fallback helper. Preserve the difference between an
   absent primary attribute and a present empty one.
2. Have both SVGAnimatedString.get_baseVal and SVG origin extraction use
   that scalar read. Extraction never acquires the animated object.
3. Pin native extraction under std.testing.allocator and rerun the same
   upstream WPT with Debug allocation traces, then ReleaseSafe leak checks.
4. Route ownership of unwrapped generated-cache entries to the binding
   owner. Do not dispose, wrap or retain someone else's cached object as a
   local workaround.

**Takeaway**: **When a native caller needs only a scalar, share the underlying read before acquiring a wrapper object. Measure both Zig and C++ allocations.**
