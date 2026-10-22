# Spec Compliance: XML Navigation and XHR Decode Differently

**Date**: 2026-10-21
**Lesson**: XML navigation must reject malformed encoded bytes without changing XHR's replacement decoding.

**Why**: XML 1.0 §4.3.3 requires fatal byte errors. Once replacement decoding has inserted U+FFFD, the XML parser cannot distinguish an encoding error from a legitimate replacement character in the source.

**What Happened**: Crane navigation and XHR shared an XML byte decoder using HTML's replacement mode. Chrome navigation produced a parsererror for malformed UTF-8, while XHR.responseXML preserved a document with U+FFFD for invalid UTF-8, truncated UTF-8, lone UTF-16 surrogates and invalid Shift_JIS. WebKit XMLDocumentParser::doWrite checks decoder.sawError; Gecko nsScanner::Append uses DecodeToUTF16WithoutReplacement for XML. Native navigation tests reproduced all four errors, alongside passing XHR controls.

**Fix**: Extract common encoding selection unchanged, then add a separate strict document decoder using the existing Encoding.Decoder.decodeToUtf8 fatal status. Navigation and runner metadata use it. XHR keeps the original decoder. Test valid multibyte text across output-buffer boundaries and allocation cleanup after a late fatal error.

**Takeaway**: **Share encoding selection while preserving each consumer's required error mode.**
