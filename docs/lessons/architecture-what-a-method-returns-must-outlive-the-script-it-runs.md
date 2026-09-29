# Architecture: What a method returns must outlive the script it runs

**Date**: 2026-09-29
**Lesson**: navigation.navigate() made an API method tracker, started the navigation, then read the tracker's promises - and the navigation's navigate event had already freed the tracker.

**Why**: The navigation runs script synchronously: a navigate handler that calls preventDefault() aborts the navigation, which rejects the tracker's promises and cleans the tracker up. Nothing else referred to it, so it was collected - while navigate() still had it.

**What Happened**: Eleven navigation-api files crashed with a misaligned load in `v8_Global_Clone` under `Navigation.derivedResult` - every one cancels the navigation it starts.

**Fix**: The method holds the tracker (`Tracker.held`) from making it until it has read its promises; the collector skips a held tracker.

**Takeaway**: **Anything a method creates, hands to code that can run script, and reads afterwards must be held by the method for that whole span.**
