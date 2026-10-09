# Spec Compliance: An intervention's exceptions are decided one by one

**Date**: 2026-10-08
**Lesson**: Two engines ship a check the spec lacks, and the third ships none. Take the check, then decide each of its exceptions by the 2-of-3 majority, counting the engine that never checks as allowing every case.

**Why**: Golden rule 2 follows the majority of Chrome, Firefox and Safari. For an intervention the majority decides more than "block or not": the two engines that block disagree on what they let through. An engine that does not block allows everything, so it sides with whichever blocking engine allows a given case.

**What Happened**: Audit row R10, blocking a cross-origin frame's top navigation without user activation. Firefox and Safari block it and Chrome stable does not. Gecko's BrowsingContext::CheckFramebusting allows transient activation only. WebKit's Document::isNavigationBlockedByThirdPartyIFrameRedirectBlocking allows any frame the user ever interacted with, and any destination same-site with top. With Chrome allowing both, sticky activation and a same-site destination are allowed (2 of 3). Exceptions both engines share - same origin with top, sandboxed with allow-top-navigation under an allowed parent, no source document, session history traversal - are allowed by all three. The integrator granted the call sites on condition that each exception is listed with its engines and pinned by a test (nf-top-navigation.sub: one blocked case per path, one allowed case per exception, and a traversal that is not checked).

**Fix**: c7261fe676, html.user_activation.topNavigationBlocked, its doc comment one line per exception and who allows it.

**Takeaway**: **For a behaviour the spec does not have, write down each exception the shipping engines make, mark who allows it - counting a non-blocking engine as allowing - and test every line; "Firefox and Safari block it" is only the first decision.**
