# Spec Compliance: Cloned shadow roots preserve internals access

**Date**: 2026-10-18
**Lesson**: Preserve a cloned shadow root's existing internals-availability flag instead of recomputing it from the clone host's temporary state.

**Why**: Cloning creates a custom-element candidate before its upgrade reaction runs. Attaching its copied shadow root at that point sees an undefined host, so the normal attachment algorithm initializes availability to false.

**What Happened**: Three scoped-registry upgrade subtests failed because `clone.elementInternals.shadowRoot` was null. The original declarative closed root was available, but `ShadowRoot.cloneFlags` copied only its declarative and keep-registry-null flags. An isolated Crane test reproduced the lost availability; another pinned that a root originally unavailable must stay unavailable.

**Fix**: Copy the existing boolean alongside the other flags, without adding storage or changing upgrade timing. DOM's clone algorithm omits this step; Blink's [Element::Clone](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/dom/element.cc) explicitly notes the omission and preserves the flag. WebKit's [ShadowRoot::cloneNodeInternal](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/ShadowRoot.cpp) does the same. On 2026-10-18 both shipping scoped-registry browsers pass CustomElementRegistry-upgrade 5/5; Firefox does not yet ship scoped registries. The liaison approved that browser behavior under golden rule 2, with no newer spec step involved.

**Takeaway**: **An attachment default derived from a clone's intermediate state is not necessarily the state cloning must preserve.**
