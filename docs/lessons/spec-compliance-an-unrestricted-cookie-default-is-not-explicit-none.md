# Spec Compliance: An unrestricted cookie default is not explicit None

**Date**: 2026-10-12
**Lesson**: Apply a browser's Default SameSite policy at retrieval and storage decisions while preserving whether the attribute was explicit.

**Why**: Default and explicit `SameSite=None` can both allow cross-site requests, but only the explicit attribute requires Secure. Converting the stored Default flag into None would silently reject ordinary HTTP cookies.

**What Happened**: Row 24 followed Chromium's Lax-by-default policy and the RFC draft. The follow-up checked Firefox's release preference, WebKit's attribute mapping and Chromium's effective policy. The integrator accepted the 2–1 None-by-default majority. A new native test showed cross-site HTTP storage rejected both omitted and invalid SameSite attributes before the policy change.

**Fix**:

1. Preserve the parser's `.unset` flag for omitted and unrecognized attributes.
2. Select `.unset_or_less` for cross-site retrieval, including aged cookies on unsafe navigation.
3. Restrict cross-site storage for explicit Strict and Lax; keep the Secure requirement limited to explicit None.
4. Test omitted, invalid, Strict, Lax, None and Secure independently. Record intentional WPT losses where its expectations assume Lax-by-default.

Evidence: Firefox release [StaticPrefList.yaml](https://github.com/mozilla-firefox/firefox/blob/release/modules/libpref/init/StaticPrefList.yaml) (`network.cookie.sameSite.laxByDefault=false`) and [CookieService.cpp](https://github.com/mozilla-firefox/firefox/blob/release/netwerk/cookie/CookieService.cpp) (`ProcessSameSiteCookieForForeignRequest`); WebKit [CookieCocoa.mm](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/platform/network/cocoa/CookieCocoa.mm) (`coreSameSitePolicy` maps nil to None); Chromium [cookie_base.cc](https://github.com/chromium/chromium/blob/main/net/cookies/cookie_base.cc) (`GetEffectiveSameSite` defaults to Lax). WebKit delegates request filtering to closed-source CFNetwork; its public mapping is the available source evidence. Browser privacy blocking is a separate policy.

**Takeaway**: **Equal cross-site behavior does not make Default and explicit None interchangeable. Preserve the parsed distinction.**

**Status (2026-10-20)**: the None-by-default policy this lesson describes was reverted on the user's ruling - Crane is Lax-by-default again (Chrome), so the cookies/samesite subtests the change lost pass. The point about keeping an unset SameSite distinct from explicit None (which requires Secure) still holds.
