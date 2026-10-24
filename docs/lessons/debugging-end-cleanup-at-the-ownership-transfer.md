# Debugging: End cleanup at the ownership transfer

**Date**: 2026-10-22
**Lesson**: A successful transfer must end the old owner's error cleanup before any later fallible work.

**Why**: An `errdefer` runs for every error that exits its enclosing scope, including errors after the value has moved into a container. Registering the container's cleanup does not cancel the earlier cleanup.

**What Happened**: All-allocation-failure tests for nested `@font-face` rules reached failures while building the children of media and layer rules. The rule already owned the media query list or layer name, but the builder's original `errdefer` remained active. The rule's `unref()` freed that value, and the original cleanup freed it again. Successful parsing did not expose the error.

**Fix**: Put allocation and transfer into an inner block. Its `errdefer` handles failures before the transfer; leaving the block successfully ends that obligation. Install the new owner's cleanup outside the block, before building children. The native regression checks both a media containing a layer and a standalone layer across every allocation failure.

**Takeaway**: **Cleanup scopes should follow ownership scopes, including on error paths after construction.**
