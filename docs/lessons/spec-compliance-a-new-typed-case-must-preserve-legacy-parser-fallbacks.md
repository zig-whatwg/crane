# Spec Compliance: A new typed case must preserve legacy parser fallbacks

**Date**: 2026-10-26
**Lesson**: Adding one typed grammar alternative must preserve the existing parser's guards and recovery for every other alternative.

**Why**: A shared value parser may accept or preserve raw syntax differently from its caller. Routing an entire function family through it can change existing behavior even when the new typed alternative is correct.

**What Happened**: Adding sole-color `image()` values moved all content `image()` functions through the typed image parser. The existing content parser rejected an empty `image()` and closed open functions at EOF. The new route accepted the empty form and omitted the closing parenthesis from raw URL forms. Native tests and four script cases reproduced both regressions before the fix; the original 400 new-feature script cases still passed.

**Fix**: Try only the new sole-color grammar on a local stream. On success, adopt its owned value through the established image bridge. On a non-match, retain the caller's original post-parenthesis state and use its existing raw-function path. That path parses the legacy form once, including its URL resolution, empty-body guard and CSS Syntax EOF closure. Keep allocation-failure tests around both alternatives.

**Takeaway**: **Share the newly added alternative without silently replacing the caller's established fallback behavior.**
