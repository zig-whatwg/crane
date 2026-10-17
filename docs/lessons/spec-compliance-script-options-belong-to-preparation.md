# Spec Compliance: Script Options Belong to Preparation

**Date**: 2026-10-17
**Lesson**: A script's descendant fetch options come from its preparation-time record, not from attributes reread when execution finally starts.

**Why**: Preparing an external script and running it are separate operations. Script can change the element's attributes while its response is pending. HTML prepare step 25 computes credentials mode before fetching; creating the script retains that value for later imports.

**What Happened**: Crane built a classic script's host-defined record at execution, and its fetch-options helper reread the element. Simply adding credentials to that helper would make a delayed script inherit a later crossorigin mutation. Equal-URL scripts also shared records whose keys did not distinguish credentials. The new sc2-module-credentials.sub.html fixture covers both include-to-anonymous and anonymous-to-include changes during a delayed fetch.

**Fix**: Capture credentials mode once at preparation, carry the enum through the existing classic result, fetch and SVG queue metadata, then pass it to the host-defined record. Include every retained option in that record's key. Copy the mode into module scripts and descendant requests. Keep actual classic request CORS handling separate: a no-CORS classic request can include credentials while its descendant module fetch options use same-origin.

**Takeaway**: **An attribute at execution time is not the fetch option of the script that was prepared earlier.** Apply the same reasoning to nonce and referrer policy; their remaining snapshot work needs owned strings and its own lifetime review.
