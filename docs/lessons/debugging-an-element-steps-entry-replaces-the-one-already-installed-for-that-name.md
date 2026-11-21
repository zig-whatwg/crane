# Debugging: An element-steps entry replaces the one already installed for that local name

**Date**: 2026-11-21
**Lesson**: `dom.attribute_change_steps.install(<local name>, ...)` keeps ONE entry per local name; a second interface installing for the same name silently replaces the first, and the element loses every attribute step the earlier one ran.

**Why**: An element's attribute change steps come from several interfaces in its chain: `<video>`'s `src` step is HTMLMediaElement's, installed under "video" (and "audio"); HTML 4.8.9's poster step is HTMLVideoElement's. The table is keyed by local name and its doc says so ("installing different ones replaces them"), so the last `installHooks` to run wins, in an order no one chose.

**What Happened**: Lane pscan1 gave `<video>` its poster fetch (1e0dc9ef5) with `install("video", &attributeChangeSteps)`. The unit tests passed: they set only `poster`. The red/green run on resource-timing/initiator-type/video.html turned '<video poster>' green and '<video src>' red - the video's media steps were gone, so `src` loaded nothing.

**Fix**: 9c3b957eb: the poster step is an attribute-level step, `installForAttribute(html namespace, "poster", ...)`, which checks the element's local name itself; "video"'s element entry stays HTMLMediaElement's.

**Takeaway**: **Before installing element steps for a local name, check whether another interface in the chain already installed them; add a step for one attribute with `installForAttribute` instead of replacing the element's entry - and test an attribute the earlier steps own, not only the new one.**
