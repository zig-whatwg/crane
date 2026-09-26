# Codegen: Check generated data against a second copy

**Date**: 2026-09-22
**Lesson**: The index generator hardcoded each encoding index's last pointer; jis0208 stopped at 7,939 of 11,103 and euc-kr at 17,919 of 23,749, so ~5,800 hanja could be neither encoded nor decoded. WPT ships the spec's own index data - compare against it.
