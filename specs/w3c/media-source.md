
[![W3C](https://www.w3.org/StyleSheets/TR/2021/logos/W3C){crossorigin=""
height="48" width="72"}](https://www.w3.org/)

# Media Source Extensions™

[W3C Editor\'s Draft](https://www.w3.org/standards/types#ED) 04 November
2025

More details about this document

This version:
: [https://w3c.github.io/media-source/](https://w3c.github.io/media-source/)

Latest published version:
: <https://www.w3.org/TR/media-source-2/>

Latest editor\'s draft:
: <https://w3c.github.io/media-source/>

History:
: <https://www.w3.org/standards/history/media-source-2/>
: [Commit history](https://github.com/w3c/media-source/commits/)

Latest Recommendation:
: <https://www.w3.org/TR/2016/REC-media-source-20161117/>

Editors:
: [Jean-Yves Avenard](mailto:jya@apple.com) ([Apple Inc.](https://www.apple.com/))
: [Mark Watson] ([Netflix
 Inc.](https://www.netflix.com/))

Former editors:
: [Matthew Wolenetz](mailto:matt.wolenetz@gmail.com) ([W3C Invited Expert]) - Until 01 February 2024
: [Jerry Smith] ([Microsoft
 Corporation](https://www.microsoft.com/)) -
 Until 01 September 2017
: [Aaron Colwell] ([Google
 Inc.](https://www.google.com/)) - Until 01 April
 2015
: [Adrian Bateman] ([Microsoft
 Corporation](https://www.microsoft.com/)) -
 Until 01 April 2015

Feedback:
: [GitHub w3c/media-source](https://github.com/w3c/media-source/)
 ([pull requests](https://github.com/w3c/media-source/pulls/), [new
 issue](https://github.com/w3c/media-source/issues/new/choose), [open
 issues](https://github.com/w3c/media-source/issues/))
: [public-media-wg@w3.org](mailto:public-media-wg@w3.org?subject=%5Bmedia-source-2%5D%20YOUR%20TOPIC%20HERE)
 with subject line [\[media-source-2\] *... message topic ...*]
 ([archives](https://lists.w3.org/Archives/Public/public-media-wg){rel="discussion"})

Browser support:
: [caniuse.com](https://caniuse.com/mediasource)

[Copyright](https://www.w3.org/policies/#copyright) © 2025 [World Wide
Web Consortium](https://www.w3.org/). [W3C]^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document
license](https://www.w3.org/copyright/software-license-2023/ "W3C Software and Document Notice and License"){rel="license"}
rules apply.

------------------------------------------------------------------------

## Abstract

This specification extends
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) \[[HTML](#bib-html "HTML Standard")\] to allow JavaScript to generate media streams for
playback. Allowing JavaScript to generate streams facilitates a variety
of use cases like adaptive streaming and time shifting live streams.

## Status of This Document

*This section describes the status of this document at the time of its
publication. A list of current [W3C] publications and the latest revision
of this technical report can be found in the [[W3C] standards and drafts
index](https://www.w3.org/TR/).*

On top of editorial updates, substantive changes since publication as a
[W3C] Recommendation in
[November 2016](https://www.w3.org/TR/2016/REC-media-source-20161117/)
are:

- the addition of a
 [`changeType`](#dom-sourcebuffer-changetype)`()` method to switch
 among codecs or bytestreams
- the possibility to create and use
 [`MediaSource`](#dom-mediasource) objects off the main
 thread in dedicated workers
- the removal of the
 [`createObjectURL`](https://www.w3.org/TR/FileAPI/#dfn-createObjectURL)`()` extension to the
 [`URL`](https://url.spec.whatwg.org/#url) object following its integration in the File API
 \[[FILEAPI](#bib-fileapi "File API")\]
- the addition of
 [`ManagedMediaSource`](#dom-managedmediasource),
 [`ManagedSourceBuffer`](#dom-managedsourcebuffer), and
 [`BufferedChangeEvent`](#dom-bufferedchangeevent) interfaces
 supporting power-efficient streaming and active buffered media cleanup
 by the user agent

For a full list of changes made since the previous version, see the
[commits](https://github.com/w3c/media-source/commits/main).

The working group maintains [a list of all bug reports that the editors
have not yet tried to
address](https://github.com/w3c/media-source/issues).

Implementors should be aware that this specification is not stable.
**Implementors who are not taking part in the discussions are likely to
find the specification changing out from under them in incompatible
ways.** Vendors interested in implementing this specification before it
eventually reaches the Candidate Recommendation stage should track the
[GitHub repository](https://github.com/w3c/media-source) and take part
in the discussions.

This document was published by the [Media Working
Group](https://www.w3.org/groups/wg/media) as an Editor\'s Draft.

Publication as an Editor\'s Draft does not imply endorsement by
[W3C] and its Members.

This is a draft document and may be updated, replaced, or obsoleted by
other documents at any time. It is inappropriate to cite this document
as other than a work in progress.

This document was produced by a group operating under the [[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/). [W3C] maintains a [public list of any
patent
disclosures](https://www.w3.org/groups/wg/media/ipr){rel="disclosure"}
made in connection with the deliverables of the group; that page also
includes instructions for disclosing a patent. An individual who has
actual knowledge of a patent that the individual believes contains
[Essential
Claim(s)](https://www.w3.org/policies/patent-policy/#def-essential) must
disclose the information in accordance with [section 6 of the
[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/#sec-Disclosure).

This document is governed by the [18 August 2025 [W3C] Process
Document](https://www.w3.org/policies/process/20250818/).

## Table of Contents

1. [Abstract](#abstract)
2. [Status of This Document](#sotd)
3. [1. Introduction](#introduction)
 1. [1.1 Goals](#goals)
4. [2. Definitions](#definitions)
5. [3. [`MediaSource`]{ idl="interface"
 }
 interface](#mediasource)
 1. [3.1 [`handle`]{ idl="attribute"

 local-}
 attribute](#handle-attribute)
 2. [3.2 [`sourceBuffers`]{
 idl="attribute"

 local-}
 attribute](#sourcebuffers-attribute)
 3. [3.3 [`activeSourceBuffers`]{
 idl="attribute"

 local-}
 attribute](#activesourcebuffers-attribute)
 4. [3.4 [`readyState`]{
 idl="attribute"

 local-}
 attribute](#readystate-attribute)
 5. [3.5 [`duration`]{ idl="attribute"

 local-}
 attribute](#duration-attribute)
 6. [3.6 [`canConstructInDedicatedWorker`]{
 idl="attribute"

 local-}
 attribute](#canconstructindedicatedworker-attribute)
 7. [3.7 [`addSourceBuffer()`]{
 idl="operation"

 local-}
 method](#addsourcebuffer-method)
 8. [3.8 [`removeSourceBuffer()`]{
 idl="operation"

 local-}
 method](#removesourcebuffer-method)
 9. [3.9 [`endOfStream()`]{
 idl="operation"

 local-}
 method](#endofstream-method)
 10. [3.10 [`setLiveSeekableRange()`]{
 idl="operation"

 local-}
 method](#setliveseekablerange-method)
 11. [3.11 [`clearLiveSeekableRange()`]{
 idl="operation"

 local-}
 method](#clearliveseekablerange-method)
 12. [3.12 [`isTypeSupported()`]{
 idl="operation"

 local-}
 method](#istypesupported-method)
 13. [3.13 Event Summary](#mediasource-events)
 14. [3.14 Cross-context communication
 model](#mediasource-in-worker-communication-model)
 15. [3.15 Algorithms](#mediasource-algorithms)
 1. [3.15.1 Attaching to a media
 element](#mediasource-attach)
 2. [3.15.2 Detaching from a media
 element](#mediasource-detach)
 3. [3.15.3 Seeking](#mediasource-seeking)
 4. [3.15.4 SourceBuffer
 Monitoring](#buffer-monitoring)
 5. [3.15.5 Changes to selected/enabled track
 state](#active-source-buffer-changes)
 6. [3.15.6 Duration
 change](#duration-change-algorithm)
 7. [3.15.7 End of stream](#end-of-stream-algorithm)
 8. [3.15.8 Mirror if
 necessary](#mirror-if-necessary-algorithm)
6. [4. [`MediaSourceHandle`]{
 idl="interface" }
 interface](#mediasourcehandle)
 1. [4.1 Transfer](#transfer)
7. [5. [`SourceBuffer`]{ idl="interface"
 }
 interface](#sourcebuffer)
 1. [5.1 Attributes](#attributes)
 2. [5.2 Methods](#methods)
 3. [5.3 Track Buffers](#track-buffers)
 4. [5.4 Event Summary](#sourcebuffer-events)
 5. [5.5 Algorithms](#sourcebuffer-algorithms)
 1. [5.5.1 Segment Parser
 Loop](#sourcebuffer-segment-parser-loop)
 2. [5.5.2 Reset Parser
 State](#sourcebuffer-reset-parser-state)
 3. [5.5.3 [Append
 Error]](#sourcebuffer-append-error)
 4. [5.5.4 Prepare
 Append](#sourcebuffer-prepare-append)
 5. [5.5.5 Buffer Append](#sourcebuffer-buffer-append)
 6. [5.5.6 Range Removal](#sourcebuffer-range-removal)
 7. [5.5.7 Initialization Segment
 Received](#sourcebuffer-init-segment-received)
 8. [5.5.8 [Coded Frame
 Processing]](#sourcebuffer-coded-frame-processing)
 9. [5.5.9 Coded Frame
 Removal](#sourcebuffer-coded-frame-removal)
 10. [5.5.10 Coded Frame
 Eviction](#sourcebuffer-coded-frame-eviction)
 11. [5.5.11 Audio Splice
 Frame](#sourcebuffer-audio-splice-frame-algorithm)
 12. [5.5.12 Audio Splice
 Rendering](#sourcebuffer-audio-splice-rendering-algorithm)
 13. [5.5.13 Text Splice
 Frame](#sourcebuffer-text-splice-frame-algorithm)
8. [6. [`SourceBufferList`]{
 idl="interface" }
 interface](#sourcebufferlist)
 1. [6.1 Attributes](#attributes-0)
 2. [6.2 Methods](#methods-0)
 3. [6.3 Event Summary](#sourcebufferlist-events)
9. [7. [`ManagedMediaSource`]{
 idl="interface" }
 interface](#managedmediasource-interface)
 1. [7.1 Attributes](#attributes-1)
 2. [7.2 Event Summary](#event-summary)
 3. [7.3 Algorithms](#algorithms)
 1. [7.3.1 `ManagedSourceBuffer`
 Monitoring](#managedsourcebuffer-monitoring)
 2. [7.3.2 [Memory
 Cleanup]](#memory-cleanup)
10. [8. [`BufferedChangeEvent`]{
 idl="interface" }
 interface](#bufferedchangeevent-interface)
 1. [8.1 Attributes](#attributes-2)
11. [9. [`ManagedSourceBuffer`]{
 idl="interface" }
 interface](#managedsourcebuffer-interface)
 1. [9.1 Attributes](#attributes-3)
 2. [9.2 Event Summary](#event-summary-0)
 3. [9.3 Algorithms](#algorithms-0)
 1. [9.3.1 Buffered Change](#buffered-change)
 2. [9.3.2 [Memory
 cleanup]](#memory-cleanup-0)
12. [10. HTMLMediaElement
 Extensions](#htmlmediaelement-extensions)
 1. [10.1 [`HTMLMediaElement`]\'s
 [`seekable`]](#htmlmediaelement-extensions-seekable)
 2. [10.2 [`HTMLMediaElement`]\'s
 [`buffered`]](#htmlmediaelement-extensions-buffered)
 3. [10.3 [`HTMLMediaElement`]\'s
 [`srcObject`]](#htmlmediaelement-extensions-srcobject)
13. [11. `AudioTrack` extensions](#audio-track-extensions)
14. [12. `VideoTrack` extensions](#video-track-extensions)
15. [13. `TextTrack` extensions](#text-track-extensions)
16. [14. [Byte Stream
 Formats]](#byte-stream-formats)
17. [15. Conformance](#conformance)
18. [16. Examples](#examples)
 1. [16.1 Using Media Source
 Extensions](#using-media-source-extensions)
 2. [16.2 Using a Managed Media
 Source](#using-a-managed-media-source)
19. [17. Acknowledgments](#acknowledgements)
20. [A. VideoPlaybackQuality](#VideoPlaybackQuality)
21. [B. Issue summary](#issue-summary)
22. [C. References](#references)
 1. [C.1 Normative references](#normative-references)
 2. [C.2 Informative references](#informative-references)

::: header-wrapper
## 1. Introduction

*This section is non-normative.*

This specification allows JavaScript to dynamically construct media
streams for \<audio\> and \<video\>. It defines a MediaSource object
that can serve as a source of media data for an HTMLMediaElement.
MediaSource objects have one or more
[`SourceBuffer`](#dom-sourcebuffer) objects. Applications
append data segments to the
[`SourceBuffer`](#dom-sourcebuffer) objects, and can adapt
the quality of appended data based on system performance and other
factors. Data from the
[`SourceBuffer`](#dom-sourcebuffer) objects is managed as
track buffers for audio, video and text data that is decoded and played.
Byte stream specifications used with these extensions are available in
the byte stream format registry
\[[MSE-REGISTRY](#bib-mse-registry "Media Source Extensions™ Byte Stream Format Registry")\].

<figure id="fig-media-source-pipeline-model-diagram">
<a
href="https://w3c.github.io/media-source/pipeline_model_description.html#pipelinedesc"><img
src="pipeline_model.svg"
a /></a>
<figcaption><a href="#fig-media-source-pipeline-model-diagram"
class="self-link">Figure 1</a> <span class="fig-title"> Media Source
Pipeline Model Diagram </span></figcaption>
</figure>

::: header-wrapper
### 1.1 Goals

This specification was designed with the following goals in mind:

- Allow JavaScript to construct media streams independent of how the
 media is fetched.
- Define a splicing and buffering model that facilitates use cases like
 adaptive streaming, ad-insertion, time-shifting, and video editing.
- Minimize the need for media parsing in JavaScript.
- Leverage the browser cache as much as possible.
- Provide requirements for byte stream format specifications.
- Not require support for any particular media format or codec.

This specification defines:

- Normative behavior for user agents to enable interoperability between
 user agents and web applications when processing media data.
- Normative requirements to enable other specifications to define media
 formats to be used within this specification.

::: header-wrapper
## 2. Definitions

[Active Track Buffers]

: The [track buffers](#track-buffer) that provide [coded
 frames](#dfn-coded-frame) for the
 [`enabled`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-enabled)
 [`audioTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-audiotracks),
 the
 [`selected`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-selected)
 [`videoTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-videotracks),
 and the
 [`"showing"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-showing)
 or
 [`"hidden"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-hidden)
 [`textTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-texttracks).
 All these tracks are associated with
 [`SourceBuffer`](#dom-sourcebuffer) objects in the
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers) list.

[Append Window]

: A [presentation
 timestamp](#presentation-timestamp) range used to filter out
 [coded frames](#dfn-coded-frame) while appending. The
 append window represents a single continuous time range with a
 single start time and end time. Coded frames with [presentation
 timestamp](#presentation-timestamp) within this range are
 allowed to be appended to the
 [`SourceBuffer`](#dom-sourcebuffer) while coded frames
 outside this range are filtered out. The append window start and end
 times are controlled by the
 [`appendWindowStart`](#dom-sourcebuffer-appendwindowstart) and
 [`appendWindowEnd`](#dom-sourcebuffer-appendwindowend) attributes respectively.

[Coded Frame]

: A unit of media data that has a [presentation
 timestamp](#presentation-timestamp), a [decode
 timestamp](#dfn-decode-timestamp), and a [coded frame
 duration](#dfn-coded-frame-duration).

[Coded Frame Duration]

: The duration of a [coded
 frame](#dfn-coded-frame). For video and text, the duration
 indicates how long the video frame or text *SHOULD* be displayed.
 For audio, the duration represents the sum of all the samples
 contained within the coded frame. For example, if an audio frame
 contained 441 samples \@44100Hz the frame duration would be 10
 milliseconds.

[Coded Frame End Timestamp]

: The sum of a [coded
 frame](#dfn-coded-frame) [presentation
 timestamp](#presentation-timestamp) and its [coded frame
 duration](#dfn-coded-frame-duration). It represents the
 [presentation
 timestamp](#presentation-timestamp) that immediately follows
 the coded frame.

[Coded Frame Group]

: A group of [coded
 frames](#dfn-coded-frame) that are adjacent and have
 monotonically increasing [decode
 timestamps](#dfn-decode-timestamp) without any gaps.
 Discontinuities detected by the [coded frame
 processing](#dfn-coded-frame-processing) algorithm and
 [`abort`](#dom-sourcebuffer-abort)`()` calls trigger the
 start of a new coded frame group.

[Decode Timestamp]

: The decode timestamp indicates the latest time at which the frame
 needs to be decoded assuming instantaneous decoding and rendering of
 this and any dependant frames (this is equal to the [presentation
 timestamp](#presentation-timestamp) of the earliest frame, in
 [presentation
 order](#presentation-order), that is dependant on this
 frame). If frames can be decoded out of [presentation
 order](#presentation-order), then the decode timestamp
 *MUST* be present in or derivable from the byte stream. The user
 agent *MUST* run the [append
 error](#dfn-append-error) algorithm if this is not the case. If
 frames cannot be decoded out of [presentation
 order](#presentation-order) and a decode timestamp is
 not present in the byte stream, then the decode timestamp is equal
 to the [presentation
 timestamp](#presentation-timestamp).

[Initialization Segment]

: A sequence of bytes that contain all of the initialization
 information required to decode a sequence of [media
 segments](#dfn-media-segment). This includes codec
 initialization data, [Track
 ID](#dfn-track-id) mappings for multiplexed segments, and
 timestamp offsets (e.g., edit lists).

 ::::
 :::
 Note
 :::

 The [byte stream format
 specifications](#byte-stream-format-specs) in the byte stream format
 registry
 \[[MSE-REGISTRY](#bib-mse-registry "Media Source Extensions™ Byte Stream Format Registry")\] contain format specific examples.
 ::::

[Media Segment]

: A sequence of bytes that contain packetized & timestamped media data
 for a portion of the [media
 timeline](https://html.spec.whatwg.org/multipage/media.html#media-timeline).
 Media segments are always associated with the most recently appended
 [initialization
 segment](#dfn-initialization-segment).

 ::::
 :::
 Note
 :::

 The [byte stream format
 specifications](#byte-stream-format-specs) in the byte stream format
 registry
 \[[MSE-REGISTRY](#bib-mse-registry "Media Source Extensions™ Byte Stream Format Registry")\] contain format specific examples.
 ::::

[MediaSource object URL]

: A [`MediaSource`](#dom-mediasource) object URL is a
 unique [blob
 URL](https://www.w3.org/TR/FileAPI/#blob-url)
 created by
 [`createObjectURL`](https://www.w3.org/TR/FileAPI/#dfn-createObjectURL)`()`. It is used to attach a
 [`MediaSource`](#dom-mediasource) object to an
 HTMLMediaElement.

 These URLs are the same as a [blob
 URLs](https://www.w3.org/TR/FileAPI/#blob-url),
 except that anything in the definition of that feature that refers
 to
 [`File`](https://www.w3.org/TR/FileAPI/#dfn-file) and
 [`Blob`](https://www.w3.org/TR/FileAPI/#dfn-Blob) objects is hereby extended to also apply to
 [`MediaSource`](#dom-mediasource) objects.

 The
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)
 of the MediaSource object URL is the [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)
 of [this](https://webidl.spec.whatwg.org/#this)
 during the call to
 [`createObjectURL`](https://www.w3.org/TR/FileAPI/#dfn-createObjectURL)`()`.

 ::::
 :::
 Note
 :::

 For example, the
 [origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin)
 of the MediaSource object URL affects the way that the media element
 is [consumed by
 canvas](https://html.spec.whatwg.org/multipage/canvas.html#security-with-canvas-elements).
 ::::

[Parent Media Source]

: The parent media source of a
 [`SourceBuffer`](#dom-sourcebuffer) object is the
 [`MediaSource`](#dom-mediasource) object that created
 it.

[Presentation Start Time]

: The presentation start time is the earliest time point in the
 presentation and specifies the initial [playback
 position](https://html.spec.whatwg.org/multipage/media.html#) and
 [earliest possible
 position](https://html.spec.whatwg.org/multipage/media.html#). All
 presentations created using this specification have a presentation
 start time of 0.

 ::::
 :::
 Note
 :::

 For the purposes of determining if
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered)
 contains a
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) that includes the current playback position,
 implementations *MAY* choose to allow a current playback position at
 or after [presentation start
 time](#presentation-start-time) and before the first
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) to play the first
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) if that
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) starts within a reasonably short time, like 1
 second, after [presentation start
 time](#presentation-start-time). This allowance
 accommodates the reality that muxed streams commonly do not begin
 all tracks precisely at [presentation start
 time](#presentation-start-time). Implementations *MUST*
 report the actual buffered range, regardless of this allowance.
 ::::

[Presentation Interval]

: The presentation interval of a [coded
 frame](#dfn-coded-frame) is the time interval from its
 [presentation
 timestamp](#presentation-timestamp) to the [presentation
 timestamp](#presentation-timestamp) plus the [coded frame\'s
 duration](#dfn-coded-frame-duration).
 For example, if a coded frame has a presentation timestamp of 10
 seconds and a [coded frame
 duration](#dfn-coded-frame-duration) of 100 milliseconds, then
 the presentation interval would be \[10-10.1). Note that the start
 of the range is inclusive, but the end of the range is exclusive.

[Presentation Order]

: The order that [coded
 frames](#dfn-coded-frame) are rendered in the presentation. The
 presentation order is achieved by ordering [coded
 frames](#dfn-coded-frame) in monotonically increasing order by
 their [presentation
 timestamps](#presentation-timestamp).

[Presentation Timestamp]

: A reference to a specific time in the presentation. The presentation
 timestamp in a [coded
 frame](#dfn-coded-frame) indicates when the frame *SHOULD* be
 rendered.

[Random Access Point]

: A position in a [media
 segment](#dfn-media-segment) where decoding and
 continuous playback can begin without relying on any previous data
 in the segment. For video this tends to be the location of I-frames.
 In the case of audio, most audio frames can be treated as a random
 access point. Since video tracks tend to have a more sparse
 distribution of random access points, the location of these points
 are usually considered the random access points for multiplexed
 streams.

[SourceBuffer byte stream format specification]

: The specific [byte stream format
 specification](#byte-stream-format-specs) that describes the format
 of the byte stream accepted by a
 [`SourceBuffer`](#dom-sourcebuffer) instance. The [byte
 stream format
 specification](#byte-stream-format-specs), for a
 [`SourceBuffer`](#dom-sourcebuffer) object, is initially
 selected based on the `type` passed
 to the
 [`addSourceBuffer`](#dom-mediasource-addsourcebuffer)`()` call that
 created the object, and can be updated by
 [`changeType`](#dom-sourcebuffer-changetype)`()` calls on the
 object.

[`SourceBuffer` configuration]

: A specific set of tracks distributed across one or more
 [`SourceBuffer`](#dom-sourcebuffer) objects owned by a
 single [`MediaSource`](#dom-mediasource) instance.

 Implementations *MUST* support at least 1
 [`MediaSource`](#dom-mediasource) object with the
 following configurations:

 - A single SourceBuffer with 1 audio track and/or 1 video track.
 - Two SourceBuffers with one handling a single audio track and the
 other handling a single video track.

 MediaSource objects *MUST* support each of the configurations above,
 but they are only required to support one configuration at a time.
 Supporting multiple configurations at once or additional
 configurations is a quality of implementation issue.

[Track Description]

: A byte stream format specific structure that provides the [Track
 ID](#dfn-track-id), codec configuration, and other
 metadata for a single track. Each track description inside a single
 [initialization
 segment](#dfn-initialization-segment) has a unique [Track
 ID](#dfn-track-id). The user agent *MUST* run the [append
 error](#dfn-append-error) algorithm if the [Track
 ID](#dfn-track-id) is not unique within the
 [initialization
 segment](#dfn-initialization-segment).

[Track ID]

: A Track ID is a byte stream format specific identifier that marks
 sections of the byte stream as being part of a specific track. The
 Track ID in a [track
 description](#dfn-track-description) identifies which sections
 of a [media
 segment](#dfn-media-segment) belong to that track.

::: header-wrapper
## 3. [`MediaSource`] interface

The [`MediaSource`](#dom-mediasource) interface represents a
source of media data for an
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement). It keeps track of the
[`readyState`](#dom-mediasource-readystate) for this source as well as a list of
[`SourceBuffer`](#dom-sourcebuffer) objects that can be used to add media data
to the presentation. MediaSource objects are created by the web
application and then attached to an HTMLMediaElement. The application
uses the
[`SourceBuffer`](#dom-sourcebuffer) objects in
[`sourceBuffers`](#dom-mediasource-sourcebuffers) to add media data to this source. The
HTMLMediaElement fetches this media data from the
[`MediaSource`](#dom-mediasource) object when it is needed during playback.

Each [`MediaSource`](#dom-mediasource) object has a [\[\[live
seekable range\]\]] internal slot that stores a [normalized
TimeRanges
object](https://html.spec.whatwg.org/multipage/media.html#normalised-timeranges-object).
It is initialized to an empty
[`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) object when the
[`MediaSource`](#dom-mediasource) object is created, is
maintained by
[`setLiveSeekableRange`](#dom-mediasource-setliveseekablerange)`()` and
[`clearLiveSeekableRange`](#dom-mediasource-clearliveseekablerange)`()`, and is
used in [10. HTMLMediaElement
Extensions](#htmlmediaelement-extensions) to modify
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`seekable`](https://html.spec.whatwg.org/multipage/media.html#dom-media-seekable)
behavior.

Each [`MediaSource`](#dom-mediasource) object has a [\[\[has
ever been attached\]\]] internal slot that stores a
[`boolean`](https://webidl.spec.whatwg.org/#idl-boolean). It is initialized to false when the
[`MediaSource`](#dom-mediasource) object is created, and is
set true in the extended
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)
as described in the [attaching to a media
element](#dfn-attaching-to-a-media-element) algorithm. The extended
[resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)
uses this internal slot to conditionally fail attachment of a
[`MediaSource`](#dom-mediasource) using a
[`MediaSourceHandle`](#dom-mediasourcehandle) set on a
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject)
attribute.

```
WebIDLenum ReadyState {
 "closed",
 "open",
 "ended",
};
```

[`closed`]
: Indicates the source is not currently attached to a media element.

[`open`]
: The source has been opened by a media element and is ready for data
 to be appended to the
 [`SourceBuffer`](#dom-sourcebuffer) objects in
 [`MediaSource`](#dom-mediasource)\'s
 [`sourceBuffers`](#dom-mediasource-sourcebuffers).

[`ended`]
: The source is still attached to a media element, but
 [`MediaSource`](#dom-mediasource)\'s
 [`endOfStream`](#dom-mediasource-endofstream)`()` has been
 called.

[[Issue
276]](https://github.com/w3c/media-source/issues/276)[:
MSE-in-Workers: Consider adding a \"closing\" readyState to explain new
\`InvalidStateError\` exception when closing underway
[mse-in-workers](https://github.com/w3c/media-source/issues/?q=is%3Aissue+is%3Aopen+label%3A%22mse-in-workers%22)]

Consider adding a \"`closing`\"
[`ReadyState`](#dom-mediasource-readystate) to indicate the source is in the process
of being concurrently detached from a media element. This would be
useful for some implementations of
[`MediaSource`](#dom-mediasource) and
[`SourceBuffer`](#dom-sourcebuffer) in
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope).

```
WebIDLenum EndOfStreamError {
 "network",
 "decode",
};
```

[`network`]

: Terminates playback and signals that a network error has occurred.

 ::::
 :::
 Note
 :::

 JavaScript applications *SHOULD* use this status code to terminate
 playback with a network error. For example, if a network error
 occurs while fetching media data.
 ::::

[`decode`]

: Terminates playback and signals that a decoding error has occurred.

 ::::
 :::
 Note
 :::

 JavaScript applications *SHOULD* use this status code to terminate
 playback with a decode error. For example, if a parsing error occurs
 while processing out-of-band media data.
 ::::

```
WebIDL[Exposed=(Window,DedicatedWorker)]
interface MediaSource : EventTarget {
 constructor();

 [SameObject, Exposed=DedicatedWorker]
 readonly attribute MediaSourceHandle handle;
 readonly attribute SourceBufferList sourceBuffers;
 readonly attribute SourceBufferList activeSourceBuffers;
 readonly attribute ReadyState readyState;

 attribute unrestricted double duration;
 attribute EventHandler onsourceopen;
 attribute EventHandler onsourceended;
 attribute EventHandler onsourceclose;

 static readonly attribute boolean canConstructInDedicatedWorker;

 SourceBuffer addSourceBuffer(DOMString type);
 undefined removeSourceBuffer(SourceBuffer sourceBuffer);
 undefined endOfStream(optional EndOfStreamError error);
 undefined setLiveSeekableRange(double start, double end);
 undefined clearLiveSeekableRange();
 static boolean isTypeSupported(DOMString type);
};
```

::: header-wrapper
### 3.1 [`handle`] attribute

Contains a handle useful for attachment of a dedicated worker
[`MediaSource`](#dom-mediasource) object to an
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) via
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject).
The handle remains the same object for this
[`MediaSource`](#dom-mediasource) object across accesses of
this attribute, but it is distinct for each
[`MediaSource`](#dom-mediasource) object.

This specification may eventually enable visibility of this attribute on
[`MediaSource`](#dom-mediasource) objects on the main
Window context. If so, specification care will be necessary to prevent
potential backwards incompatible changes, such as could happen if
exceptions were thrown on accesses to this attribute.

On getting, run the following steps:

1. If the handle for this
 [`MediaSource`](#dom-mediasource) object has not yet
 been created, then run the following steps:
 1. Let `created handle` be
 the result of creating a new
 [`MediaSourceHandle`](#dom-mediasourcehandle) object and
 associated resources, linked internally to this
 [`MediaSource`](#dom-mediasource).
 2. Update the attribute to be `created handle`.
2. Return the
 [`MediaSourceHandle`](#dom-mediasourcehandle) object that is
 this attribute\'s value.

::: header-wrapper
### 3.2 [`sourceBuffers`] attribute

Contains the list of
[`SourceBuffer`](#dom-sourcebuffer) objects associated with
this [`MediaSource`](#dom-mediasource). When
[`MediaSource`](#dom-mediasource)\'s
[`readyState`](#dom-mediasource-readystate) equals
\"[`closed`](#dom-readystate-closed)\" this list will be empty. Once
[`readyState`](#dom-mediasource-readystate) transitions to
\"[`open`](#dom-readystate-open)\" SourceBuffer objects can be added to
this list by using
[`addSourceBuffer`](#dom-mediasource-addsourcebuffer)`()`.

::: header-wrapper
### 3.3 [`activeSourceBuffers`] attribute

Contains the subset of
[`sourceBuffers`](#dom-mediasource-sourcebuffers) that are providing the
[`selected`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-selected)
video track, the
[`enabled`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-enabled)
audio track(s), and the
[`"showing"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-showing)
or
[`"hidden"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-hidden)
text track(s).

[`SourceBuffer`](#dom-sourcebuffer) objects in this list
*MUST* appear in the same order as they appear in the
[`sourceBuffers`](#dom-mediasource-sourcebuffers) attribute; e.g., if only
sourceBuffers\[0\] and sourceBuffers\[3\] are in
[`activeSourceBuffers`](#dom-mediasource-activesourcebuffers), then activeSourceBuffers\[0\] *MUST*
equal sourceBuffers\[0\] and activeSourceBuffers\[1\] *MUST* equal
sourceBuffers\[3\].

Section [3.15.5 Changes to selected/enabled track
state](#active-source-buffer-changes) describes how this
attribute gets updated.

::: header-wrapper
### 3.4 [`readyState`] attribute

Indicates the current state of the
[`MediaSource`](#dom-mediasource) object. When the
[`MediaSource`](#dom-mediasource) is created
[`readyState`](#dom-mediasource-readystate) *MUST* be set to
\"[`closed`](#dom-readystate-closed)\".

::: header-wrapper
### 3.5 [`duration`] attribute

Allows the web application to set the presentation duration. The
duration is initially set to NaN when the
[`MediaSource`](#dom-mediasource) object is created.

On getting, run the following steps:

1. If the
 [`readyState`](#dom-mediasource-readystate) attribute is
 \"[`closed`](#dom-readystate-closed)\" then return NaN and abort these
 steps.
2. Return the current value of the attribute.

On setting, run the following steps:

1. If the value being set is negative or NaN then throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) exception and abort these steps.
2. If the
 [`readyState`](#dom-mediasource-readystate) attribute is not
 \"[`open`](#dom-readystate-open)\" then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
3. If the
 [`updating`](#dom-sourcebuffer-updating) attribute equals true on any
 [`SourceBuffer`](#dom-sourcebuffer) in
 [`sourceBuffers`](#dom-mediasource-sourcebuffers), then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
4. Run the [duration
 change](#dfn-duration-change) algorithm with
 `new duration` set to the
 value being assigned to this attribute.

 ::::
 :::
 Note
 :::

 The [duration
 change](#dfn-duration-change) algorithm will adjust
 `new duration` higher if
 there is any currently buffered coded frame with a higher end time.
 ::::

 ::::
 :::
 Note
 :::

 [`appendBuffer`](#dom-sourcebuffer-appendbuffer)`()` and
 [`endOfStream`](#dom-mediasource-endofstream)`()` can update the
 duration under certain circumstances.
 ::::

::: header-wrapper
### 3.6 [`canConstructInDedicatedWorker`] attribute

Returns true.

This attribute enables main thread and dedicated worker feature
detection of support for creating and using a
[`MediaSource`](#dom-mediasource) object in a dedicated
worker, and mitigates the need for higher latency detection polyfills
like attempting creation of a
[`MediaSource`](#dom-mediasource) object from a dedicated
worker, especially if the feature is not supported.

::: header-wrapper
### 3.7 [`addSourceBuffer()`] method

Adds a new
[`SourceBuffer`](#dom-sourcebuffer) to
[`sourceBuffers`](#dom-mediasource-sourcebuffers).

1. If `type` is an empty string then
 throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) exception and abort these steps.
2. If `type` contains a MIME type that
 is not supported or contains a MIME type that is not supported with
 the types specified for the other
 [`SourceBuffer`](#dom-sourcebuffer) objects in
 [`sourceBuffers`](#dom-mediasource-sourcebuffers), then throw a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception and abort these steps.
3. If the user agent can\'t handle any more SourceBuffer objects or if
 creating a SourceBuffer based on `type` would result in an unsupported [SourceBuffer
 configuration](#dfn-sourcebuffer-configuration), then throw a
 [`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror) exception and abort these steps.

 ::::
 :::
 Note
 :::

 For example, a user agent *MAY* throw a
 [`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror) exception if the media element has reached
 the
 [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata)
 readyState. This can occur if the user agent\'s media engine does
 not support adding more tracks during playback.
 ::::
4. If the
 [`readyState`](#dom-mediasource-readystate) attribute is not in the
 \"[`open`](#dom-readystate-open)\" state then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
5. Let `buffer` be a new instance of a
 [`ManagedSourceBuffer`](#dom-managedsourcebuffer) if
 [this](https://webidl.spec.whatwg.org/#this) is a
 [`ManagedMediaSource`](#dom-managedmediasource), or a
 [`SourceBuffer`](#dom-sourcebuffer) otherwise, with
 their respective associated resources.
6. Set `buffer`\'s
 [`[[generate timestamps flag]]`](#dfn-generate-timestamps-flag) to the value in the \"Generate
 Timestamps Flag\" column of the [Media Source Extensions™ Byte
 Stream Format
 Registry](https://w3c.github.io/mse-byte-stream-format-registry/){matched-text="[[[MSE-REGISTRY]]]"}
 entry that is associated with `type`.
7. If `buffer`\'s
 [`[[generate timestamps flag]]`](#dfn-generate-timestamps-flag) is true, set
 `buffer`\'s
 [`mode`](#dom-sourcebuffer-mode) to
 \"[`sequence`](#dom-appendmode-sequence)\". Otherwise, set
 `buffer`\'s
 [`mode`](#dom-sourcebuffer-mode) to
 \"[`segments`](#dom-appendmode-segments)\".
8. [Append](https://infra.spec.whatwg.org/#list-append)
 `buffer` to
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [`sourceBuffers`](#dom-mediasource-sourcebuffers).
9. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`addsourcebuffer`](#dfn-addsourcebuffer) at
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [`sourceBuffers`](#dom-mediasource-sourcebuffers).
10. Return `buffer`.

::: header-wrapper
### 3.8 [`removeSourceBuffer()`] method

Removes a
[`SourceBuffer`](#dom-sourcebuffer) from
[`sourceBuffers`](#dom-mediasource-sourcebuffers).

1. If `sourceBuffer` specifies an
 object that is not in
 [`sourceBuffers`](#dom-mediasource-sourcebuffers) then throw a
 [`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror) exception and abort these steps.
2. If the `sourceBuffer`.[`updating`](#dom-sourcebuffer-updating) attribute equals true, then run the
 following steps:
 1. Abort the [buffer
 append](#dfn-buffer-append) algorithm if it is
 running.
 2. Set the `sourceBuffer`.[`updating`](#dom-sourcebuffer-updating) attribute to false.
 3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named [`abort`](#dfn-abort) at `sourceBuffer`.
 4. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named [`updateend`](#dfn-updateend) at
 `sourceBuffer`.
3. Let `SourceBuffer audioTracks list` equal the
 [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist) object returned by `sourceBuffer`.[`audioTracks`](#dom-sourcebuffer-audiotracks).
4. If the `SourceBuffer audioTracks list` is not empty, then run the following
 steps:
 1. For each
 [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack) object in the
 `SourceBuffer audioTracks list`, run the following steps:
 1. Set the
 [`sourceBuffer`](#dom-audiotrack-sourcebuffer) attribute on the
 [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack) object to null.
 2. Remove the
 [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack) object from the
 `SourceBuffer audioTracks list`.

 ::::
 :::
 Note
 :::

 This should trigger
 [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [removetrack](https://html.spec.whatwg.org/multipage/media.html#event-media-removetrack)
 using
 [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent) with the
 [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track)
 attribute initialized to the
 [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack) object, at the
 `SourceBuffer audioTracks list`. If the
 [`enabled`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-enabled)
 attribute on the
 [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack) object was true at the beginning of this
 removal step, then this should also trigger
 [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [change](https://html.spec.whatwg.org/multipage/media.html#event-media-change)
 at the `SourceBuffer audioTracks list`.
 ::::
 3. Use the [mirror if
 necessary](#dfn-mirror-if-necessary) algorithm to run
 the following steps in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window), to remove the
 [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack) object (or instead, the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) mirror of it if the
 [`MediaSource`](#dom-mediasource) object was
 constructed in a
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)) from the media element:
 1. Let `HTMLMediaElement audioTracks list` equal the
 [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist) object returned by the
 [`audioTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-audiotracks)
 attribute on the HTMLMediaElement.
 2. Remove the
 [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack) object from the
 `HTMLMediaElement audioTracks list`.

 ::::
 :::
 Note
 :::

 This should trigger
 [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [removetrack](https://html.spec.whatwg.org/multipage/media.html#event-media-removetrack)
 using
 [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent) with the
 [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track)
 attribute initialized to the
 [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack) object, at the
 `HTMLMediaElement audioTracks list`. If the
 [`enabled`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-enabled)
 attribute on the
 [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack) object was true at the beginning of
 this removal step, then this should also trigger
 [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [change](https://html.spec.whatwg.org/multipage/media.html#event-media-change)
 at the `HTMLMediaElement audioTracks list`.
 ::::
5. Let `SourceBuffer videoTracks list` equal the
 [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist) object returned by `sourceBuffer`.[`videoTracks`](#dom-sourcebuffer-videotracks).
6. If the `SourceBuffer videoTracks list` is not empty, then run the following
 steps:
 1. For each
 [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack) object in the
 `SourceBuffer videoTracks list`, run the following steps:
 1. Set the
 [`sourceBuffer`](#dom-videotrack-sourcebuffer) attribute on the
 [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack) object to null.
 2. Remove the
 [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack) object from the
 `SourceBuffer videoTracks list`.

 ::::
 :::
 Note
 :::

 This should trigger
 [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [removetrack](https://html.spec.whatwg.org/multipage/media.html#event-media-removetrack)
 using
 [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent) with the
 [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track)
 attribute initialized to the
 [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack) object, at the
 `SourceBuffer videoTracks list`. If the
 [`selected`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-selected)
 attribute on the
 [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack) object was true at the beginning of this
 removal step, then this should also trigger
 [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [change](https://html.spec.whatwg.org/multipage/media.html#event-media-change)
 at the `SourceBuffer videoTracks list`.
 ::::
 3. Use the [mirror if
 necessary](#dfn-mirror-if-necessary) algorithm to run
 the following steps in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window), to remove the
 [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack) object (or instead, the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) mirror of it if the
 [`MediaSource`](#dom-mediasource) object was
 constructed in a
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)) from the media element:
 1. Let `HTMLMediaElement videoTracks list` equal the
 [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist) object returned by the
 [`videoTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-videotracks)
 attribute on the HTMLMediaElement.
 2. Remove the
 [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack) object from the
 `HTMLMediaElement videoTracks list`.

 ::::
 :::
 Note
 :::

 This should trigger
 [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [removetrack](https://html.spec.whatwg.org/multipage/media.html#event-media-removetrack)
 using
 [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent) with the
 [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track)
 attribute initialized to the
 [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack) object, at the
 `HTMLMediaElement videoTracks list`. If the
 [`selected`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-selected)
 attribute on the
 [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack) object was true at the beginning of
 this removal step, then this should also trigger
 [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [change](https://html.spec.whatwg.org/multipage/media.html#event-media-change)
 at the `HTMLMediaElement videoTracks list`.
 ::::
7. Let `SourceBuffer textTracks list` equal the
 [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist) object returned by `sourceBuffer`.[`textTracks`](#dom-sourcebuffer-texttracks).
8. If the `SourceBuffer textTracks list` is not empty, then run the following
 steps:
 1. For each
 [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) object in the
 `SourceBuffer textTracks list`, run the following steps:
 1. Set the
 [`sourceBuffer`](#dom-texttrack-sourcebuffer) attribute on the
 [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) object to null.
 2. Remove the
 [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) object from the
 `SourceBuffer textTracks list`.

 ::::
 :::
 Note
 :::

 This should trigger
 [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [removetrack](https://html.spec.whatwg.org/multipage/media.html#event-media-removetrack)
 using
 [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent) with the
 [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track)
 attribute initialized to the
 [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) object, at the
 `SourceBuffer textTracks list`. If the
 [`mode`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-mode)
 attribute on the
 [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) object was
 [`"showing"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-showing)
 or
 [`"hidden"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-hidden)
 at the beginning of this removal step, then this should also
 trigger
 [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [change](https://html.spec.whatwg.org/multipage/media.html#event-media-change)
 at the `SourceBuffer textTracks list`.
 ::::
 3. Use the [mirror if
 necessary](#dfn-mirror-if-necessary) algorithm to run
 the following steps in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window), to remove the
 [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) object (or instead, the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) mirror of it if the
 [`MediaSource`](#dom-mediasource) object was
 constructed in a
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)) from the media element:
 1. Let `HTMLMediaElement textTracks list` equal the
 [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist) object returned by the
 [`textTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-texttracks)
 attribute on the HTMLMediaElement.
 2. Remove the
 [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) object from the
 `HTMLMediaElement textTracks list`.

 ::::
 :::
 Note
 :::

 This should trigger
 [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [removetrack](https://html.spec.whatwg.org/multipage/media.html#event-media-removetrack)
 using
 [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent) with the
 [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track)
 attribute initialized to the
 [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) object, at the
 `HTMLMediaElement textTracks list`. If the
 [`mode`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-mode)
 attribute on the
 [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) object was
 [`"showing"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-showing)
 or
 [`"hidden"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-hidden)
 at the beginning of this removal step, then this should
 also trigger
 [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [change](https://html.spec.whatwg.org/multipage/media.html#event-media-change)
 at the `HTMLMediaElement textTracks list`.
 ::::
9. If `sourceBuffer` is in
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers), then remove `sourceBuffer` from
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers) and [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`removesourcebuffer`](#dfn-removesourcebuffer) at the
 [`SourceBufferList`](#dom-sourcebufferlist) returned by
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers).
10. Remove `sourceBuffer` from
 [`sourceBuffers`](#dom-mediasource-sourcebuffers) and [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`removesourcebuffer`](#dfn-removesourcebuffer) at the
 [`SourceBufferList`](#dom-sourcebufferlist) returned by
 [`sourceBuffers`](#dom-mediasource-sourcebuffers).
11. Destroy all resources for `sourceBuffer`.

::: header-wrapper
### 3.9 [`endOfStream()`] method

Signals the end of the stream.

1. If the
 [`readyState`](#dom-mediasource-readystate) attribute is not in the
 \"[`open`](#dom-readystate-open)\" state then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
2. If the
 [`updating`](#dom-sourcebuffer-updating) attribute equals true on any
 [`SourceBuffer`](#dom-sourcebuffer) in
 [`sourceBuffers`](#dom-mediasource-sourcebuffers), then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
3. Run the [end of
 stream](#dfn-end-of-stream) algorithm with the error
 parameter set to `error`.

::: header-wrapper
### 3.10 [`setLiveSeekableRange()`] method

[`[[live seekable range]]`](#dfn-live-seekable-range) that is
used in section [10. HTMLMediaElement
Extensions](#htmlmediaelement-extensions) to modify
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`seekable`](https://html.spec.whatwg.org/multipage/media.html#dom-media-seekable)
behavior.

When this method is invoked, the user agent must run the following
steps:

1. If the
 [`readyState`](#dom-mediasource-readystate) attribute is not
 \"[`open`](#dom-readystate-open)\" then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
2. If `start` is negative or greater than
 `end`, then throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) exception and abort these steps.
3. Set
 [`[[live seekable range]]`](#dfn-live-seekable-range) to
 be a new [normalized TimeRanges
 object](https://html.spec.whatwg.org/multipage/media.html#normalised-timeranges-object)
 containing a single range whose start position is `start` and end position is `end`.

::: header-wrapper
### 3.11 [`clearLiveSeekableRange()`] method

[`[[live seekable range]]`](#dfn-live-seekable-range) that is
used in section [10. HTMLMediaElement
Extensions](#htmlmediaelement-extensions) to modify
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`seekable`](https://html.spec.whatwg.org/multipage/media.html#dom-media-seekable)
behavior.

When this method is invoked, the user agent must run the following
steps:

1. If the
 [`readyState`](#dom-mediasource-readystate) attribute is not
 \"[`open`](#dom-readystate-open)\" then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
2. If
 [`[[live seekable range]]`](#dfn-live-seekable-range)
 contains a range, then set
 [`[[live seekable range]]`](#dfn-live-seekable-range) to
 be a new empty
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) object.

::: header-wrapper
### 3.12 [`isTypeSupported()`] method

Check to see whether the
[`MediaSource`](#dom-mediasource) is capable of creating
[`SourceBuffer`](#dom-sourcebuffer) objects for the specified MIME type.

If true is returned from this method, it only indicates that the
[`MediaSource`](#dom-mediasource) implementation is capable
of creating
[`SourceBuffer`](#dom-sourcebuffer) objects for the
specified MIME type. An
[`addSourceBuffer`](#dom-mediasource-addsourcebuffer)`()` call *SHOULD*
still fail if sufficient resources are not available to support the
addition of a new
[`SourceBuffer`](#dom-sourcebuffer).

This method returning true implies that
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`canPlayType`](https://html.spec.whatwg.org/multipage/media.html#dom-navigator-canplaytype)`()` will return \"maybe\" or \"probably\" since it
does not make sense for a
[`MediaSource`](#dom-mediasource) to support a type the
HTMLMediaElement knows it cannot play.

When this method is invoked, the user agent must run the following
steps:

1. If `type` is an empty string, then
 return false.
2. If `type` does not contain a valid
 MIME type string, then return false.
3. If `type` contains a media type or
 media subtype that the MediaSource does not support, then return
 false.
4. If `type` contains a codec that the
 MediaSource does not support, then return false.
5. If the MediaSource does not support the specified combination of
 media type, media subtype, and codecs then return false.
6. Return true.

::: header-wrapper
### 3.13 Event Summary

Event name Interface Dispatched when\...
 ------------------------------------------------------------------------------------------------------------ --------------------------------------------------------------------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 [sourceopen] [`Event`](https://dom.spec.whatwg.org/#event) [`MediaSource`](#dom-mediasource)\'s [`readyState`](#dom-mediasource-readystate) transitions from \"[`closed`](#dom-readystate-closed)\" to \"[`open`](#dom-readystate-open)\" or from \"[`ended`](#dom-readystate-ended)\" to \"[`open`](#dom-readystate-open)\".
 [sourceended] [`Event`](https://dom.spec.whatwg.org/#event) [`MediaSource`](#dom-mediasource)\'s [`readyState`](#dom-mediasource-readystate) transitions from \"[`open`](#dom-readystate-open)\" to \"[`ended`](#dom-readystate-ended)\".
 [sourceclose] [`Event`](https://dom.spec.whatwg.org/#event) [`MediaSource`](#dom-mediasource)\'s [`readyState`](#dom-mediasource-readystate) transitions from \"[`open`](#dom-readystate-open)\" to \"[`closed`](#dom-readystate-closed)\" or \"[`ended`](#dom-readystate-ended)\" to \"[`closed`](#dom-readystate-closed)\".

::: header-wrapper
### 3.14 [Cross-context communication model]

When a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) is attached to a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)
[`MediaSource`](#dom-mediasource), each context has
algorithms that depend on information from the other.

[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) is exposed only to
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) contexts, but
[`MediaSource`](#dom-mediasource) and related objects
defined in this specification are exposed in
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) and
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope) contexts. This lets applications
construct a
[`MediaSource`](#dom-mediasource) object in either of those
types of context and attach it to an
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) object in a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) context using a [MediaSource object
URL](#mediasource-object-url) or a
[`MediaSourceHandle`](#dom-mediasourcehandle) as described in the
[attaching to a media
element](#dfn-attaching-to-a-media-element) algorithm. A
[`MediaSource`](#dom-mediasource) object is not
[`Transferable`](https://html.spec.whatwg.org/multipage/structured-data.html#transferable); it is only visible in the context where it was
created.

The rest of this section describes a model for bounding information
latency for attachments of a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) media element to a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)
[`MediaSource`](#dom-mediasource). While the model
describes communication using message passing, implementations *MAY*
choose to communicate in potentially faster ways, such as using shared
memory and locks. Attachments to a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)
[`MediaSource`](#dom-mediasource) synchronously have the
information already without communicating it across contexts.

A [`MediaSource`](#dom-mediasource) that is constructed in a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope) has a [\[\[port to
main\]\]]
internal slot that stores a
[`MessagePort`](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport) setup during attachment and nulled during detachment.
A
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)
[`[[port to main]]`](#dfn-port-to-main) is always
null.

An
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) extended by this specification and attached to a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)
[`MediaSource`](#dom-mediasource) similarly has a [\[\[port
to worker\]\]] internal slot that stores a
[`MessagePort`](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport) and a [\[\[channel with
worker\]\]] internal slot that stores a
[`MessageChannel`](https://html.spec.whatwg.org/multipage/web-messaging.html#messagechannel), both setup during attachment and nulled during
detachment. Both
[`[[port to worker]]`](#dfn-port-to-worker) and
[`[[channel with worker]]`](#dfn-channel-with-worker) are
null unless attached to a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)
[`MediaSource`](#dom-mediasource).

Algorithms in this specification that need to communicate information
from a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) to an attached
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)
[`MediaSource`](#dom-mediasource), or vice versa, will use
these internal ports implicitly to post a message to their counterpart,
where the implicit handler of the message runs steps as described in the
algorithms.

::: header-wrapper
### 3.15 Algorithms

::: header-wrapper
#### 3.15.1 [Attaching to a media element]

There are distinct mechanisms for attaching a
[`MediaSource`](#dom-mediasource) to a media element
depending on where the
[`MediaSource`](#dom-mediasource) object was constructed,
in a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) versus in a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope):

- Attaching a
 [`MediaSource`](#dom-mediasource) that was constructed in
 a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) can be done by assigning a [MediaSource object
 URL](#mediasource-object-url) for that
 [`MediaSource`](#dom-mediasource) to the media element
 [`src`](https://html.spec.whatwg.org/multipage/media.html#dom-media-src)
 attribute or the src attribute of a \<source\> inside a media element.
 A [MediaSource object
 URL](#mediasource-object-url) is created by passing a
 MediaSource object to
 [`createObjectURL`](https://www.w3.org/TR/FileAPI/#dfn-createObjectURL)`()`.

 Though implementations *MAY* allow [MediaSource object
 URL](#mediasource-object-url) creation in a
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope) for a
 [`MediaSource`](#dom-mediasource) constructed in that
 worker, attempting to use that [MediaSource object
 URL](#mediasource-object-url) to attach to a media element
 using either the
 [`src`](https://html.spec.whatwg.org/multipage/media.html#dom-media-src)
 attribute or the src attribute of a \<source\> inside a media element
 *MUST* fail in the media element\'s [resource fetch
 algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource),
 as extended below.

 ::::
 :::
 Note
 :::

 Extending the object URL attachment mechanism to worker MediaSource
 object URLs would further propagate this idiom that is less preferred
 versus using srcObject, and would unnecessarily increase user agent
 interoperability risk and implementation complexity.
 ::::

- Attaching a
 [`MediaSource`](#dom-mediasource) that was constructed in
 a
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope) can only be done by obtaining a
 handle from it using
 [`handle`](#dom-mediasource-handle), transferring that
 [`MediaSourceHandle`](#dom-mediasourcehandle) to the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) context and assigning it to the media element
 [`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject)
 attribute. For the purposes of aligning this specification with
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) resource loading and fetching algorithms, the
 underlying
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)
 [`MediaSource`](#dom-mediasource) is the MediaSource
 object mentioned there, and the
 [`MediaSourceHandle`](#dom-mediasourcehandle) object is the
 media provider object.

If the [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)
was invoked with a media provider object that is a
[`MediaSource`](#dom-mediasource) object, a
[`MediaSourceHandle`](#dom-mediasourcehandle) object or a URL
record whose object is a
[`MediaSource`](#dom-mediasource) object, then let mode be
local, skip the first step in the [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)
(which may otherwise set mode to remote) and continue the execution of
the [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource).

The first step of the [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)
is expected to eventually align with selecting local mode for URL
records whose objects are media provider objects. The intent is that if
the
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`src`](https://html.spec.whatwg.org/multipage/media.html#dom-media-src)
attribute or selected child
[`source`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-source-element)\'s
[`src`](https://html.spec.whatwg.org/multipage/embedded-content.html#attr-source-src)
attribute is a `blob:` URL matching a [MediaSource object
URL](#mediasource-object-url) when the respective `src`
attribute was last changed, then that
[`MediaSource`](#dom-mediasource) object is used as the
media provider object and current media resource in the local mode logic
in the [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource).
This also means that the remote mode logic that includes observance of
any preload attribute is skipped when a MediaSource object is attached.
Even with that eventual change to
\[[HTML](#bib-html "HTML Standard")\], the
execution of the following steps at the beginning of the local mode
logic is still required when the current media resource is a
[`MediaSource`](#dom-mediasource) object.

At the beginning of the \"Otherwise (mode is local)\" section of the
[resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource),
execute the additional steps, below.

Relative to the action which triggered the media element\'s resource
selection algorithm, these steps are asynchronous. The [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)
is run after the task that invoked the resource selection algorithm is
allowed to continue and a stable state is reached. Implementations may
delay the steps in the \"*Otherwise*\" clause, below, until the
MediaSource object is ready for use.

1. If the [resource fetch
 algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)
 was invoked with a media provider object that is a
 [`MediaSource`](#dom-mediasource) object, a
 [`MediaSourceHandle`](#dom-mediasourcehandle) object or a URL
 record whose object is a
 [`MediaSource`](#dom-mediasource) object, then:

 If the media provider object is a URL record whose object is a [`MediaSource`](#dom-mediasource) that was constructed in a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope), such as would occur if attempting to use a [MediaSource object URL](#mediasource-object-url) from a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope) [`MediaSource`](#dom-mediasource)
 : Run the \"*If the media data cannot be fetched at all, due to
 network errors, causing the user agent to give up trying to
 fetch the resource*\" steps of the [resource fetch
 algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)\'s
 [media data processing steps
 list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).
 :::::
 :::
 Note
 :::

 :::
 This prevents using [MediaSource object
 URLs](#mediasource-object-url) for DedicatedWorker
 MediaSource attachments. Transferring
 [`MediaSource`](#dom-mediasource)\'s
 [`handle`](#dom-mediasource-handle) from the DedicatedWorker to the
 Window context and assigning it to the media element\'s
 [`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject)
 attribute is the only way to attach such a MediaSource.
 :::
 :::::

 If the media provider object is a [`MediaSourceHandle`](#dom-mediasourcehandle) whose [`[[Detached]]`](#dfn-detached) internal slot is true
 : Run the \"*If the media data cannot be fetched at all, due to
 network errors, causing the user agent to give up trying to
 fetch the resource*\" steps of the [resource fetch
 algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)\'s
 [media data processing steps
 list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).

 If the media provider object is a [`MediaSourceHandle`](#dom-mediasourcehandle) whose underlying [`MediaSource`](#dom-mediasource)\'s [`[[has ever been attached]]`](#dfn-has-ever-been-attached) internal slot is true
 : Run the \"*If the media data cannot be fetched at all, due to
 network errors, causing the user agent to give up trying to
 fetch the resource*\" steps of the [resource fetch
 algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)\'s
 [media data processing steps
 list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).
 :::::
 :::
 Note
 :::

 :::
 This prevents loading an underlying
 [`MediaSource`](#dom-mediasource) more than once
 using a
 [`MediaSourceHandle`](#dom-mediasourcehandle), even if
 the
 [`MediaSource`](#dom-mediasource) was constructed
 on
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) and had been loaded previously using a [MediaSource
 object
 URL](#mediasource-object-url). This doesn\'t
 preclude subsequent use of a [MediaSource object
 URL](#mediasource-object-url) for a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)
 [`MediaSource`](#dom-mediasource) from succeeding
 though.
 :::
 :::::

 If [`readyState`](#dom-mediasource-readystate) is NOT set to \"[`closed`](#dom-readystate-closed)\"
 : Run the \"*If the media data cannot be fetched at all, due to
 network errors, causing the user agent to give up trying to
 fetch the resource*\" steps of the [resource fetch
 algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)\'s
 [media data processing steps
 list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).

 Otherwise

 : 1. Set the
 [`MediaSource`](#dom-mediasource)\'s
 [`[[has ever been attached]]`](#dfn-has-ever-been-attached) internal slot to true.

 2. Set the media element\'s
 [delaying-the-load-event-flag](https://html.spec.whatwg.org/multipage/media.html#delaying-the-load-event-flag)
 to false.

 3.

 If the [`MediaSource`](#dom-mediasource) was constructed in a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope), then setup worker attachment communication and open the [`MediaSource`](#dom-mediasource):

 : 1. Set
 [`[[channel with worker]]`](#dfn-channel-with-worker) to be a new
 [`MessageChannel`](https://html.spec.whatwg.org/multipage/web-messaging.html#messagechannel).
 2. Set
 [`[[port to worker]]`](#dfn-port-to-worker) to the
 [`port1`](https://html.spec.whatwg.org/multipage/web-messaging.html#dom-messagechannel-port1)
 value of
 [`[[channel with worker]]`](#dfn-channel-with-worker).
 3. Execute
 [StructuredSerializeWithTransfer](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializewithtransfer)
 with the
 [`port2`](https://html.spec.whatwg.org/multipage/web-messaging.html#dom-messagechannel-port2)
 of
 [`[[channel with worker]]`](#dfn-channel-with-worker) as both the value and
 the sole member of the `transferList`,
 and let the result be `serialized port2`.
 4. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 on the
 [`MediaSource`](#dom-mediasource)\'s
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope) that will
 1. Execute
 [StructuredDeserializeWithTransfer](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserializewithtransfer)
 with `serialized port2` and
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)\'s
 [realm](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object's-realm),
 and set
 [`[[port to main]]`](#dfn-port-to-main) to be the resulting
 deserialized clone of the transferred
 [`port2`](https://html.spec.whatwg.org/multipage/web-messaging.html#dom-messagechannel-port2)
 value of
 [`[[channel with worker]]`](#dfn-channel-with-worker).
 2. Set the
 [`readyState`](#dom-mediasource-readystate) attribute to
 \"[`open`](#dom-readystate-open)\".
 3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`sourceopen`](#dfn-sourceopen) at
 the
 [`MediaSource`](#dom-mediasource).

 Otherwise, the [`MediaSource`](#dom-mediasource) was constructed in a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window):

 : 1. Set
 [`[[channel with worker]]`](#dfn-channel-with-worker) null.
 2. Set
 [`[[port to worker]]`](#dfn-port-to-worker) null.
 3. Set
 [`[[port to main]]`](#dfn-port-to-main) null.
 4. Set the
 [`readyState`](#dom-mediasource-readystate) attribute to
 \"[`open`](#dom-readystate-open)\".
 5. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`sourceopen`](#dfn-sourceopen) at the
 [`MediaSource`](#dom-mediasource).

 4. Continue the [resource fetch
 algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)
 by running the remaining \"*Otherwise (mode is local)*\"
 steps, with these requirements:
 1. Text in the [resource fetch
 algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)
 or the [media data processing steps
 list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list)
 that refers to \"the download\", \"bytes received\", or
 \"whenever new data for the current media resource
 becomes available\" refers to data passed in via
 [`appendBuffer`](#dom-sourcebuffer-appendbuffer)`()`.
 2. References to HTTP in the [resource fetch
 algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)
 and the [media data processing steps
 list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list)
 shall not apply because the HTMLMediaElement does not
 fetch media data via HTTP when a
 [`MediaSource`](#dom-mediasource) is
 attached.

An attached MediaSource does not use the remote mode steps in the
[resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource),
so the media element will not fire \"suspend\" events. Though future
versions of this specification will likely remove \"progress\" and
\"stalled\" events from a media element with an attached MediaSource,
user agents conforming to this version of the specification may still
fire these two events as these
\[[HTML](#bib-html "HTML Standard")\]
references changed after implementations of this specification
stabilized.

::: header-wrapper
#### 3.15.2 [Detaching from a media element]

The following steps are run in any case where the media element is going
to transition to
[`NETWORK_EMPTY`](https://html.spec.whatwg.org/multipage/media.html#dom-media-network_empty)
and [queue a
task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
to [fire an
event](https://dom.spec.whatwg.org/#concept-event-fire)
named
[emptied](https://html.spec.whatwg.org/multipage/media.html#event-media-emptied)
at the media element. These steps *SHOULD* be run right before the
transition.

1.

 If the [`MediaSource`](#dom-mediasource) was constructed in a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope):

 : 1. Notify the
 [`MediaSource`](#dom-mediasource) using an
 internal `detach` message posted to
 [`[[port to worker]]`](#dfn-port-to-worker).
 2. Set
 [`[[port to worker]]`](#dfn-port-to-worker)
 null.
 3. Set
 [`[[channel with worker]]`](#dfn-channel-with-worker) null.
 4. The implicit message handler for this `detach` notification
 runs the remainder of these steps in the
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)
 [`MediaSource`](#dom-mediasource).

 Otherwise, the [`MediaSource`](#dom-mediasource) was constructed in a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window):
 : Continue the remainder of these steps on the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)
 [`MediaSource`](#dom-mediasource).

2. Set
 [`[[port to main]]`](#dfn-port-to-main) null.

3. Set the
 [`readyState`](#dom-mediasource-readystate) attribute to
 \"[`closed`](#dom-readystate-closed)\".

4. If [this](https://webidl.spec.whatwg.org/#this) is
 a
 [`ManagedMediaSource`](#dom-managedmediasource), then set
 [`streaming`](#dom-managedmediasource-streaming) attribute to `false`.

5. Update
 [`duration`](#dom-mediasource-duration) to NaN.

6. Remove all the
 [`SourceBuffer`](#dom-sourcebuffer) objects from
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers).

7. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`removesourcebuffer`](#dfn-removesourcebuffer) at
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers).

8. Remove all the
 [`SourceBuffer`](#dom-sourcebuffer) objects from
 [`sourceBuffers`](#dom-mediasource-sourcebuffers).

9. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`removesourcebuffer`](#dfn-removesourcebuffer) at
 [`sourceBuffers`](#dom-mediasource-sourcebuffers).

10. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named [`sourceclose`](#dfn-sourceclose) at the
 [`MediaSource`](#dom-mediasource).

Going forward, this algorithm is intended to be externally called and
run in any case where the attached
[`MediaSource`](#dom-mediasource), if any, must be detached
from the media element. It *MAY* be called on HTMLMediaElement
\[[HTML](#bib-html "HTML Standard")\]
operations like load() and [resource fetch
algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)
failures in addition to, or in place of, when the media element
transitions to
[`NETWORK_EMPTY`](https://html.spec.whatwg.org/multipage/media.html#dom-media-network_empty).
Resource fetch algorithm failures are those which abort either the
resource fetch algorithm or the resource selection algorithm, with the
exception that the \"Final step\"
\[[HTML](#bib-html "HTML Standard")\] is not
considered a failure that triggers detachment.

::: header-wrapper
#### 3.15.3 [Seeking]

Run the following steps as part of the \"*Wait until the user agent has
established whether or not the media data for the new playback position
is available, and, if it is, until it has decoded enough data to play
back that position\"* step of the [seek
algorithm](https://html.spec.whatwg.org/multipage/media.html#dom-media-seek):

1. ::::
 :::
 Note
 :::

 The media element looks for [media
 segments](#dfn-media-segment) containing the
 `new playback position` in each
 [`SourceBuffer`](#dom-sourcebuffer) object in
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers). Any position within a
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) in the current value of the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered)
 attribute has all necessary media segments buffered for that
 position.
 ::::

 If `new playback position` is not in any [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) of [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered)

 : 1. If the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute is greater than
 [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata),
 then set the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute to
 [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata).

 ::::
 :::
 Note
 :::

 Per
 [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
 \[[HTML](#bib-html "HTML Standard")\] logic,
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) changes may trigger events on
 the HTMLMediaElement.
 ::::
 2. The media element waits until an
 [`appendBuffer`](#dom-sourcebuffer-appendbuffer)`()` call
 causes the [coded frame
 processing](#dfn-coded-frame-processing) algorithm to set
 the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute to a value greater
 than
 [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata).

 ::::
 :::
 Note
 :::

 The web application can use
 [`buffered`](#dom-sourcebuffer-buffered) and
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered)
 to determine what the media element needs to resume
 playback.
 ::::

 Otherwise
 : Continue
 ::::
 :::
 Note
 :::

 If the
 [`readyState`](#dom-mediasource-readystate) attribute is
 \"[`ended`](#dom-readystate-ended)\" and the
 `new playback position` is within a
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) currently in
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered),
 then the seek operation must continue to completion here even if
 one or more currently selected or enabled track buffers\'
 largest range end timestamp is less than
 `new playback position`. This condition should only
 occur due to logic in
 [`buffered`](#dom-sourcebuffer-buffered) when
 [`readyState`](#dom-mediasource-readystate) is
 \"[`ended`](#dom-readystate-ended)\".
 ::::

2. The media element resets all decoders and initializes each one with
 data from the appropriate [initialization
 segment](#dfn-initialization-segment).

3. The media element feeds [coded
 frames](#dfn-coded-frame) from the [active track
 buffers](#dfn-active-track-buffers) into the decoders starting
 with the closest [random access
 point](#random-access-point) before the
 `new playback position`.

4. Resume the [seek
 algorithm](https://html.spec.whatwg.org/multipage/media.html#dom-media-seek)
 at the \"*Await a stable state*\" step.

::: header-wrapper
#### 3.15.4 [SourceBuffer Monitoring]

The following steps are periodically run during playback to make sure
that all of the
[`SourceBuffer`](#dom-sourcebuffer) objects in
[`activeSourceBuffers`](#dom-mediasource-activesourcebuffers) have [enough data to ensure uninterrupted
playback](#enough-data). Changes to
[`activeSourceBuffers`](#dom-mediasource-activesourcebuffers) also cause these steps to run because they
affect the conditions that trigger state transitions.

Having [enough data to ensure uninterrupted playback] is an implementation
specific condition where the user agent determines that it currently has
enough data to play the presentation without stalling for a meaningful
period of time. This condition is constantly evaluated to determine when
to transition the media element into and out of the
[`HAVE_ENOUGH_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_enough_data)
ready state. These transitions indicate when the user agent believes it
has enough data buffered or it needs more data respectively.

An implementation *MAY* choose to use bytes buffered, time buffered, the
append rate, or any other metric it sees fit to determine when it has
enough data. The metrics used *MAY* change during playback so web
applications *SHOULD* only rely on the value of
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`readyState`](#dom-readystate) to determine whether more data is needed or not.

When the media element needs more data, the user agent *SHOULD*
transition it from
[`HAVE_ENOUGH_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_enough_data)
to
[`HAVE_FUTURE_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_future_data)
early enough for a web application to be able to respond without causing
an interruption in playback. For example, transitioning when the current
playback position is 500ms before the end of the buffered data gives the
application roughly 500ms to append more data before playback stalls.

If the [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s [`readyState`](#dom-readystate) attribute equals [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing):

: 1. Abort these steps.

If [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered) does not contain a [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) for the current playback position:

: 1. Set the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute to
 [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata).

 ::::
 :::
 Note
 :::

 Per
 [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
 \[[HTML](#bib-html "HTML Standard")\] logic,
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) changes may trigger events on the
 HTMLMediaElement.
 ::::
 2. Abort these steps.

If [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered) contains a [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) that includes the current playback position and [enough data to ensure uninterrupted playback](#enough-data):

: 1. Set the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute to
 [`HAVE_ENOUGH_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_enough_data).

 ::::
 :::
 Note
 :::

 Per
 [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
 \[[HTML](#bib-html "HTML Standard")\] logic,
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) changes may trigger events on the
 HTMLMediaElement.
 ::::
 2. Playback may resume at this point if it was previously suspended
 by a transition to
 [`HAVE_CURRENT_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_current_data).
 3. Abort these steps.

If [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered) contains a [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) that includes the current playback position and some time beyond the current playback position, then run the following steps:

: 1. Set the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute to
 [`HAVE_FUTURE_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_future_data).

 ::::
 :::
 Note
 :::

 Per
 [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
 \[[HTML](#bib-html "HTML Standard")\] logic,
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) changes may trigger events on the
 HTMLMediaElement.
 ::::
 2. Playback may resume at this point if it was previously suspended
 by a transition to
 [`HAVE_CURRENT_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_current_data).
 3. Abort these steps.

If [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered) contains a [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) that ends at the current playback position and does not have a range covering the time immediately after the current position:

: 1. Set the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute to
 [`HAVE_CURRENT_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_current_data).

 ::::
 :::
 Note
 :::

 Per
 [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
 \[[HTML](#bib-html "HTML Standard")\] logic,
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) changes may trigger events on the
 HTMLMediaElement.
 ::::
 2. Playback is suspended at this point since the media element
 doesn\'t have enough data to advance the [media
 timeline](https://html.spec.whatwg.org/multipage/media.html#media-timeline).
 3. Abort these steps.

::: header-wrapper
#### 3.15.5 [Changes to selected/enabled track state]

During playback
[`activeSourceBuffers`](#dom-mediasource-activesourcebuffers) needs to be updated if the
[`selected`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-selected)
video track, the
[`enabled`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-enabled)
audio track(s), or a text track
[`mode`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-mode)
changes. When one or more of these changes occur the following steps
need to be followed. Also, when
[`MediaSource`](#dom-mediasource) was constructed in a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope), then each change that occurs to a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) mirror of a track created previously by the implicit
handler for the internal `create track mirror` message *MUST* also be
made to the corresponding
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope) track using an internal
`update track state` message posted to
[`[[port to worker]]`](#dfn-port-to-worker) whose
implicit handler makes the change and runs the following steps.
Likewise, each change that occurs to a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope) track *MUST* also be made to the
corresponding
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) mirror of the track using an internal `update track state`
message posted to
[`[[port to main]]`](#dfn-port-to-main) whose implicit
handler makes the change to the mirror.

If the selected video track changes, then run the following steps:

: 1. If the
 [`SourceBuffer`](#dom-sourcebuffer) associated with
 the previously selected video track is not associated with any
 other enabled tracks, run the following steps:
 1. Remove the
 [`SourceBuffer`](#dom-sourcebuffer) from
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers).
 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`removesourcebuffer`](#dfn-removesourcebuffer) at
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers)
 2. If the
 [`SourceBuffer`](#dom-sourcebuffer) associated with
 the newly selected video track is not already in
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers), run the following steps:
 1. Add the
 [`SourceBuffer`](#dom-sourcebuffer) to
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers).
 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`addsourcebuffer`](#dfn-addsourcebuffer) at
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers)

If an audio track becomes disabled and the [`SourceBuffer`](#dom-sourcebuffer) associated with this track is not associated with any other enabled or selected track, then run the following steps:

: 1. Remove the
 [`SourceBuffer`](#dom-sourcebuffer) associated with
 the audio track from
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers)
 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`removesourcebuffer`](#dfn-removesourcebuffer) at
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers)

If an audio track becomes enabled and the [`SourceBuffer`](#dom-sourcebuffer) associated with this track is not already in [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers), then run the following steps:

: 1. Add the
 [`SourceBuffer`](#dom-sourcebuffer) associated with
 the audio track to
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers)
 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`addsourcebuffer`](#dfn-addsourcebuffer) at
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers)

If a text track [`mode`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-mode) becomes [`"disabled"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-disabled) and the [`SourceBuffer`](#dom-sourcebuffer) associated with this track is not associated with any other enabled or selected track, then run the following steps:

: 1. Remove the
 [`SourceBuffer`](#dom-sourcebuffer) associated with
 the text track from
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers)
 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`removesourcebuffer`](#dfn-removesourcebuffer) at
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers)

If a text track [`mode`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-mode) becomes [`"showing"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-showing) or [`"hidden"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-hidden) and the [`SourceBuffer`](#dom-sourcebuffer) associated with this track is not already in [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers), then run the following steps:

: 1. Add the
 [`SourceBuffer`](#dom-sourcebuffer) associated with
 the text track to
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers)
 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`addsourcebuffer`](#dfn-addsourcebuffer) at
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers)

::: header-wrapper
#### 3.15.6 [Duration change]

Follow these steps when
[`duration`](#dom-mediasource-duration) needs to change to a
`new duration`.

1. If the current value of
 [`duration`](#dom-mediasource-duration) is equal to `new duration`,
 then return.
2. If `new duration` is less than the highest [presentation
 timestamp](#presentation-timestamp) of any buffered [coded
 frames](#dfn-coded-frame) for all
 [`SourceBuffer`](#dom-sourcebuffer) objects in
 [`sourceBuffers`](#dom-mediasource-sourcebuffers), then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.

 ::::
 :::
 Note
 :::

 Duration reductions that would truncate currently buffered media are
 disallowed. When truncation is necessary, use
 [`remove`](#dom-sourcebuffer-remove)`()` to reduce the
 buffered range before updating
 [`duration`](#dom-mediasource-duration).
 ::::
3. Let `highest end time` be
 the largest [track buffer
 ranges](#track-buffer-ranges) end time across all the
 [track buffers](#track-buffer) across all
 [`SourceBuffer`](#dom-sourcebuffer) objects in
 [`sourceBuffers`](#dom-mediasource-sourcebuffers).
4. If `new duration` is less than
 `highest end time`, then

 ::::
 :::
 Note
 :::

 This condition can occur because the [coded frame
 removal](#dfn-coded-frame-removal) algorithm preserves coded
 frames that start before the start of the removal range.
 ::::

 1. Update `new duration` to equal
 `highest end time`.
5. Update
 [`duration`](#dom-mediasource-duration) to `new duration`.
6. Use the [mirror if
 necessary](#dfn-mirror-if-necessary) algorithm to run the
 following steps in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) to update the media element\'s duration:
 1. Update the media element\'s
 [`duration`](https://html.spec.whatwg.org/multipage/media.html#dom-media-duration)
 to `new duration`.
 2. Run the [HTMLMediaElement duration change
 algorithm](https://html.spec.whatwg.org/multipage/media.html#durationChange).

::: header-wrapper
#### 3.15.7 [End of stream]

This algorithm gets called when the application signals the end of
stream via an
[`endOfStream`](#dom-mediasource-endofstream)`()` call or an
algorithm needs to signal a decode error. This algorithm takes an
`error` parameter that indicates
whether an error will be signalled.

1. Change the
 [`readyState`](#dom-mediasource-readystate) attribute value to
 \"[`ended`](#dom-readystate-ended)\".

2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named [`sourceended`](#dfn-sourceended) at the
 [`MediaSource`](#dom-mediasource).

3.

 If `error` is not set

 : 1. Run the [duration
 change](#dfn-duration-change) algorithm with
 `new duration` set to the largest [track
 buffer
 ranges](#track-buffer-ranges) end time across
 all the [track
 buffers](#track-buffer) across all
 [`SourceBuffer`](#dom-sourcebuffer) objects in
 [`sourceBuffers`](#dom-mediasource-sourcebuffers).

 ::::
 :::
 Note
 :::

 This allows the duration to properly reflect the end of the
 appended media segments. For example, if the duration was
 explicitly set to 10 seconds and only media segments for 0
 to 5 seconds were appended before endOfStream() was called,
 then the duration will get updated to 5 seconds.
 ::::
 2. Notify the media element that it now has all of the media
 data.

 If `error` is set to \"[`network`](#dom-endofstreamerror-network)\"
 : Use the [mirror if
 necessary](#dfn-mirror-if-necessary) algorithm to run the
 following steps in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window):

 If the [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s [`readyState`](#dom-readystate) attribute equals [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing)
 : Run the \"*If the media data cannot be fetched at all, due
 to network errors, causing the user agent to give up trying
 to fetch the resource*\" steps of the [resource fetch
 algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)\'s
 [media data processing steps
 list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).

 If the [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s [`readyState`](#dom-readystate) attribute is greater than [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing)
 : Run the \"*If the connection is interrupted after some media
 data has been received, causing the user agent to give up
 trying to fetch the resource*\" steps of the [resource fetch
 algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)\'s
 [media data processing steps
 list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).

 If `error` is set to \"[`decode`](#dom-endofstreamerror-decode)\"
 : Use the [mirror if
 necessary](#dfn-mirror-if-necessary) algorithm to run the
 following steps in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window):

 If the [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s [`readyState`](#dom-readystate) attribute equals [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing)
 : Run the \"*If the media data can be fetched but is found by
 inspection to be in an unsupported format, or can otherwise
 not be rendered at all*\" steps of the [resource fetch
 algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)\'s
 [media data processing steps
 list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).

 If the [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s [`readyState`](#dom-readystate) attribute is greater than [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing)
 : Run the [media data is
 corrupted](https://html.spec.whatwg.org/multipage/media.html#fatal-decode-error)
 steps of the [resource fetch
 algorithm](https://html.spec.whatwg.org/multipage/media.html#concept-media-load-resource)\'s
 [media data processing steps
 list](https://html.spec.whatwg.org/multipage/media.html#media-data-processing-steps-list).

::: header-wrapper
#### 3.15.8 [Mirror if necessary]

This algorithm is used to run steps on
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) from a
[`MediaSource`](#dom-mediasource) attached from either the
same
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) or from a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope), usually to update the state of the
attached
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement). This algorithm takes a `steps`
parameter that lists the steps to run on
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window).

If the [`MediaSource`](#dom-mediasource) was constructed in a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope):
: Post an internal `mirror on window` message to
 [`[[port to main]]`](#dfn-port-to-main) whose
 implicit handler in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) will run `steps`. Return control to the
 caller without awaiting that handler\'s receipt of the message.
 :::::
 :::
 Note
 :::

 :::
 The purpose of the mirror message mechanism is to ensure that:
 1. `steps` run asynchronously as their own task on
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) rather than these `steps` somehow
 happening in the middle of some other
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) task\'s execution, and
 2. `steps` are run without blocking the synchronous
 execution and return of this algorithm on
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope).
 :::
 :::::

Otherwise:
: Run `steps`.

::: header-wrapper
## 4. [`MediaSourceHandle`] interface

[`MediaSourceHandle`](#dom-mediasourcehandle) interface
represents a proxy for a
[`MediaSource`](#dom-mediasource) object that is useful for
attaching a
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)
[`MediaSource`](#dom-mediasource) to a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) using
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject)
as described in the [attaching to a media
element](#dfn-attaching-to-a-media-element) algorithm.

This distinct object is necessary to attach a cross-context
[`MediaSource`](#dom-mediasource) to a media element
because [`MediaSource`](#dom-mediasource) objects themselves are
not transferable since they are event targets.

[`MediaSourceHandle`](#dom-mediasourcehandle) object has a
[\[\[has ever been assigned as
srcobject\]\]] internal slot that stores a
[`boolean`](https://webidl.spec.whatwg.org/#idl-boolean). It is initialized to false when the
[`MediaSourceHandle`](#dom-mediasourcehandle) object is created,
is set true in the extended
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject)
setter as described in section [10. HTMLMediaElement
Extensions](#htmlmediaelement-extensions), and if true,
prevents successful transfer of the
[`MediaSourceHandle`](#dom-mediasourcehandle) as described in
section [4.1 Transfer](#transfer).

[`MediaSourceHandle`](#dom-mediasourcehandle) objects are
[`Transferable`](https://html.spec.whatwg.org/multipage/structured-data.html#transferable), each having a [\[\[Detached\]\]] internal slot that is used to
ensure that once the handle object instance has been transferred, that
instance cannot be transferred again.

```
WebIDL[Transferable, Exposed=(Window,DedicatedWorker)]
interface MediaSourceHandle ;
```

::: header-wrapper
### 4.1 Transfer

[`MediaSourceHandle`](#dom-mediasourcehandle) [transfer
steps](https://html.spec.whatwg.org/multipage/structured-data.html#transfer-steps)
and [transfer-receiving
steps](https://html.spec.whatwg.org/multipage/structured-data.html#transfer-receiving-steps)
require the implementation to maintain an implicit internal slot
referencing the underlying
[`MediaSource`](#dom-mediasource) to enable [attaching to a
media
element](#dfn-attaching-to-a-media-element) using
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject)
and consequent setup of an attachment\'s [cross-context communication
model](#dfn-cross-context-communication-model).

Implementors should be aware that assumption of \"move\" semantics
implied by
[`Transferable`](https://html.spec.whatwg.org/multipage/structured-data.html#transferable) is not always reality. For example, extensions or
internal implementations of postMessage using broadcast may cause
unintended multiple recipients of a transferred
[`MediaSourceHandle`](#dom-mediasourcehandle). For this reason,
implementations are guided to not resolve which potential clone of a
transferred
[`MediaSourceHandle`](#dom-mediasourcehandle) is still valid for
attachment until and unless any handle for the underlying
[`MediaSource`](#dom-mediasource) object is used in the
asynchronous portion of the media element\'s resource selection
algorithm. This is similar to the existing behavior for attachment via
[MediaSource object
URLs](#mediasource-object-url), which can be cloned easily,
where such a URL is valid for at most one attachment start (across all
of its potentially many clones).

Implementations *MUST* support at most one attachment (load) via
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject)
ever for the
[`MediaSource`](#dom-mediasource) object underlying a
[`MediaSourceHandle`](#dom-mediasourcehandle), regardless of
potential cloning of the
[`MediaSourceHandle`](#dom-mediasourcehandle) due to varying
implementations of
[`Transferable`](https://html.spec.whatwg.org/multipage/structured-data.html#transferable).

See [attaching to a media
element](#dfn-attaching-to-a-media-element) for how this is enforced
during the asynchronous portion of the media element\'s resource
selection algorithm.

[`MediaSourceHandle`](#dom-mediasourcehandle) is only exposed on
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) and
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope) contexts, and cannot successfully
transfer between different [agent
clusters](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#sec-agent-clusters)
\[[ECMASCRIPT](#bib-ecmascript "ECMAScript Language Specification")\]. Transfer of a
[`MediaSourceHandle`](#dom-mediasourcehandle) object can only
succeed within the same [agent
cluster](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#sec-agent-clusters).

For example, transfer of a
[`MediaSourceHandle`](#dom-mediasourcehandle) object from either
a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) or
[`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope) to either a SharedWorker or a
ServiceWorker will not succeed. Developers should be aware of this
difference versus [MediaSource object
URLs](#mediasource-object-url) which are
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString)s that can be communicated many ways. Even so, [attaching
to a media
element](#dfn-attaching-to-a-media-element) using a [MediaSource object
URL](#mediasource-object-url) can only succeed for a
[`MediaSource`](#dom-mediasource) that was constructed in a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) context. See also the integration of the
[agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#agent)
and [agent
cluster](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#sec-agent-clusters)
formalisms for Web Application APIs
\[[HTML](#bib-html "HTML Standard")\] where
related concepts such as [dedicated worker
agents](https://html.spec.whatwg.org/multipage/webappapis.html#dedicated-worker-agent)
are defined.

[Transfer
steps](https://html.spec.whatwg.org/multipage/structured-data.html#transfer-steps)
for a
[`MediaSourceHandle`](#dom-mediasourcehandle) object *MUST*
include the following step:

1. If the
 [`MediaSourceHandle`](#dom-mediasourcehandle)\'s
 [`[[has ever been assigned as srcobject]]`](#dfn-has-ever-been-assigned-as-srcobject) internal slot is true,
 then the [transfer
 steps](https://html.spec.whatwg.org/multipage/structured-data.html#transfer-steps)
 must fail by throwing a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror) exception.

::: header-wrapper
## 5. [`SourceBuffer`] interface

```
WebIDLenum AppendMode {
 "segments",
 "sequence",
};
```

[`segments`]
: The timestamps in the media segment determine where the [coded
 frames](#dfn-coded-frame) are placed in the presentation. Media
 segments can be appended in any order.

[`sequence`]
: Media segments will be treated as adjacent in time independent of
 the timestamps in the media segment. Coded frames in a new media
 segment will be placed immediately after the coded frames in the
 previous media segment. The
 [`timestampOffset`](#dom-sourcebuffer-timestampoffset) attribute will be updated if a new
 offset is needed to make the new media segments adjacent to the
 previous media segment. Setting the
 [`timestampOffset`](#dom-sourcebuffer-timestampoffset) attribute in
 \"[`sequence`](#dom-appendmode-sequence)\" mode allows a media segment to be
 placed at a specific position in the timeline without any knowledge
 of the timestamps in the media segment.

```
WebIDL[Exposed=(Window,DedicatedWorker)]
interface SourceBuffer : EventTarget {
 attribute AppendMode mode;
 readonly attribute boolean updating;
 readonly attribute TimeRanges buffered;
 attribute double timestampOffset;
 readonly attribute AudioTrackList audioTracks;
 readonly attribute VideoTrackList videoTracks;
 readonly attribute TextTrackList textTracks;
 attribute double appendWindowStart;
 attribute unrestricted double appendWindowEnd;

 attribute EventHandler onupdatestart;
 attribute EventHandler onupdate;
 attribute EventHandler onupdateend;
 attribute EventHandler onerror;
 attribute EventHandler onabort;

 undefined appendBuffer(BufferSource data);
 undefined abort();
 undefined changeType(DOMString type);
 undefined remove(double start, unrestricted double end);
};
```

[[Issue
280]](https://github.com/w3c/media-source/issues/280)[:
MSE-in-Workers: {Audio,Video,Text}Track{,List} IDL in HTML need
additional DedicatedWorker in Exposed
[mse-in-workers](https://github.com/w3c/media-source/issues/?q=is%3Aissue+is%3Aopen+label%3A%22mse-in-workers%22)]

\[[HTML](#bib-html "HTML Standard")\]
[`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist),
[`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist) and
[`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist) need Window+DedicatedWorker exposure.

::: header-wrapper
### 5.1 Attributes

[`mode`] of type [`AppendMode`](#dom-appendmode)

: Controls how a sequence of [media
 segments](#dfn-media-segment) are handled. This
 attribute is initially set by
 [`addSourceBuffer`](#dom-mediasource-addsourcebuffer)`()` after the
 object is created, and can be updated by
 [`changeType`](#dom-sourcebuffer-changetype)`()` or setting this
 attribute.

 On getting, Return the initial value or the last value that was
 successfully set.

 On setting, run the following steps:

 1. If this object has been removed from the
 [`sourceBuffers`](#dom-mediasource-sourcebuffers) attribute of the [parent media
 source](#parent-media-source), then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.

 2. If the
 [`updating`](#dom-sourcebuffer-updating) attribute equals true, then throw
 an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.

 3. Let `new mode` equal the new
 value being assigned to this attribute.

 4. If
 [`[[generate timestamps flag]]`](#dfn-generate-timestamps-flag) equals true and
 `new mode` equals
 \"[`segments`](#dom-appendmode-segments)\", then throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) exception and abort these steps.

 5. If the
 [`readyState`](#dom-mediasource-readystate) attribute of the [parent media
 source](#parent-media-source) is in the
 \"[`ended`](#dom-readystate-ended)\" state then run the following
 steps:

 1. Set the
 [`readyState`](#dom-mediasource-readystate) attribute of the [parent media
 source](#parent-media-source) to
 \"[`open`](#dom-readystate-open)\"
 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`sourceopen`](#dfn-sourceopen) at the [parent
 media
 source](#parent-media-source).

 6. If the
 [`[[append state]]`](#dfn-append-state) equals
 [PARSING_MEDIA_SEGMENT](#sourcebuffer-parsing-media-segment), then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) and abort these steps.

 7. If the `new mode` equals
 \"[`sequence`](#dom-appendmode-sequence)\", then set the
 [`[[group start timestamp]]`](#dfn-group-start-timestamp) to the
 [`[[group end timestamp]]`](#dfn-group-end-timestamp).

 8. Update the attribute to `new mode`.

[`updating`] of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: Indicates whether the asynchronous continuation of an
 [`appendBuffer`](#dom-sourcebuffer-appendbuffer)`()` or
 [`remove`](#dom-sourcebuffer-remove)`()` operation is still
 being processed. This attribute is initially set to false when the
 object is created.

[`buffered`] of type [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges), readonly

: Indicates what
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) are buffered in the
 [`SourceBuffer`](#dom-sourcebuffer). This attribute is
 initially set to an empty
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) object when the object is created.

 When the attribute is read the following steps *MUST* occur:

 1. If this object has been removed from the
 [`sourceBuffers`](#dom-mediasource-sourcebuffers) attribute of the [parent media
 source](#parent-media-source) then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
 2. Let `highest end time` be the
 largest [track buffer
 ranges](#track-buffer-ranges) end time across all
 the [track buffers](#track-buffer) managed by this
 [`SourceBuffer`](#dom-sourcebuffer) object.
 3. Let `intersection ranges` equal a
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) object containing a single range from 0 to
 `highest end time`.
 4. For each audio and video [track
 buffer](#track-buffer) managed by this
 [`SourceBuffer`](#dom-sourcebuffer), run the
 following steps:

 ::::
 :::
 Note
 :::

 Text [track buffers](#track-buffer) are included in the
 calculation of `highest end time`,
 above, but excluded from the buffered range calculation here.
 They are not necessarily continuous, nor should any
 discontinuity within them trigger playback stall when the other
 media tracks are continuous over the same time range.
 ::::

 1. Let `track ranges` equal the [track buffer
 ranges](#track-buffer-ranges) for the current
 [track buffer](#track-buffer).
 2. If
 [`readyState`](#dom-mediasource-readystate) is
 \"[`ended`](#dom-readystate-ended)\", then set the end time on
 the last range in `track ranges` to
 `highest end time`.
 3. Let `new intersection ranges` equal the intersection
 between the `intersection ranges` and the
 `track ranges`.
 4. Replace the ranges in `intersection ranges` with the
 `new intersection ranges`.
 5. If `intersection ranges` does not contain the exact
 same range information as the current value of this attribute,
 then update the current value of this attribute to
 `intersection ranges`.
 6. Return the current value of this attribute.

[`timestampOffset`] of type [`double`](https://webidl.spec.whatwg.org/#idl-double)

: Controls the offset applied to timestamps inside subsequent [media
 segments](#dfn-media-segment) that are appended to this
 [`SourceBuffer`](#dom-sourcebuffer). The
 [`timestampOffset`](#dom-sourcebuffer-timestampoffset) is initially set to 0 which indicates
 that no offset is being applied.

 On getting, Return the initial value or the last value that was
 successfully set.

 On setting, run the following steps:

 1. Let `new timestamp offset` equal
 the new value being assigned to this attribute.

 2. If this object has been removed from the
 [`sourceBuffers`](#dom-mediasource-sourcebuffers) attribute of the [parent media
 source](#parent-media-source), then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.

 3. If the
 [`updating`](#dom-sourcebuffer-updating) attribute equals true, then throw
 an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.

 4. If the
 [`readyState`](#dom-mediasource-readystate) attribute of the [parent media
 source](#parent-media-source) is in the
 \"[`ended`](#dom-readystate-ended)\" state then run the following
 steps:

 1. Set the
 [`readyState`](#dom-mediasource-readystate) attribute of the [parent media
 source](#parent-media-source) to
 \"[`open`](#dom-readystate-open)\"
 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`sourceopen`](#dfn-sourceopen) at the [parent
 media
 source](#parent-media-source).

 5. If the
 [`[[append state]]`](#dfn-append-state) equals
 [PARSING_MEDIA_SEGMENT](#sourcebuffer-parsing-media-segment), then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) and abort these steps.

 6. If the
 [`mode`](#dom-sourcebuffer-mode) attribute equals
 \"[`sequence`](#dom-appendmode-sequence)\", then set the
 [`[[group start timestamp]]`](#dfn-group-start-timestamp) to
 `new timestamp offset`.

 7. Update the attribute to `new timestamp offset`.

[`audioTracks`] of type [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist), readonly
: The list of
 [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack) objects created by this object.

[`videoTracks`] of type [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist), readonly
: The list of
 [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack) objects created by this object.

[`textTracks`] of type [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist), readonly
: The list of
 [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) objects created by this object.

[`appendWindowStart`] of type [`double`](https://webidl.spec.whatwg.org/#idl-double)

: The [presentation
 timestamp](#presentation-timestamp) for the start of the
 [append window](#dfn-append-window). This attribute is
 initially set to the [presentation start
 time](#presentation-start-time).

 On getting, Return the initial value or the last value that was
 successfully set.

 On setting, run the following steps:

 1. If this object has been removed from the
 [`sourceBuffers`](#dom-mediasource-sourcebuffers) attribute of the [parent media
 source](#parent-media-source), then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
 2. If the
 [`updating`](#dom-sourcebuffer-updating) attribute equals true, then throw
 an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
 3. If the new value is less than 0 or greater than or equal to
 [`appendWindowEnd`](#dom-sourcebuffer-appendwindowend) then throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) exception and abort these steps.
 4. Update the attribute to the new value.

[`appendWindowEnd`] of type [`unrestricted double`](https://webidl.spec.whatwg.org/#idl-unrestricted-double)

: The [presentation
 timestamp](#presentation-timestamp) for the end of the [append
 window](#dfn-append-window). This attribute is
 initially set to positive Infinity.

 On getting, Return the initial value or the last value that was
 successfully set.

 On setting, run the following steps:

 1. If this object has been removed from the
 [`sourceBuffers`](#dom-mediasource-sourcebuffers) attribute of the [parent media
 source](#parent-media-source), then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
 2. If the
 [`updating`](#dom-sourcebuffer-updating) attribute equals true, then throw
 an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
 3. If the new value equals NaN, then throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) and abort these steps.
 4. If the new value is less than or equal to
 [`appendWindowStart`](#dom-sourcebuffer-appendwindowstart) then throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) exception and abort these steps.
 5. Update the attribute to the new value.

[`onupdatestart`] of type [`EventHandler`](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: The event handler for the
 [`updatestart`](#dfn-updatestart) event.

[`onupdate`] of type [`EventHandler`](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: The event handler for the
 [`update`](#dfn-update) event.

[`onupdateend`] of type [`EventHandler`](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: The event handler for the
 [`updateend`](#dfn-updateend) event.

[`onerror`] of type [`EventHandler`](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: The event handler for the [`error`](#dfn-error) event.

[`onabort`] of type [`EventHandler`](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: The event handler for the [`abort`](#dfn-abort) event.

::: header-wrapper
### 5.2 Methods

[`appendBuffer`]

: Appends the segment data in an
 [`BufferSource`](https://www.w3.org/TR/WebIDL-1/#common-BufferSource)\[[WEBIDL](#bib-webidl "Web IDL Standard")\] to the
 [`SourceBuffer`](#dom-sourcebuffer).

 When this method is invoked, the user agent must run the following
 steps:

 1. Run the [prepare
 append](#dfn-prepare-append) algorithm.
 2. Add `data` to the end of the
 [`[[input buffer]]`](#dfn-input-buffer).
 3. Set the
 [`updating`](#dom-sourcebuffer-updating) attribute to true.
 4. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`updatestart`](#dfn-updatestart) at this
 [`SourceBuffer`](#dom-sourcebuffer) object.
 5. Asynchronously run the [buffer
 append](#dfn-buffer-append) algorithm.

[`abort`]

: Aborts the current segment and resets the segment parser.

 When this method is invoked, the user agent must run the following
 steps:

 1. If this object has been removed from the
 [`sourceBuffers`](#dom-mediasource-sourcebuffers) attribute of the [parent media
 source](#parent-media-source) then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
 2. If the
 [`readyState`](#dom-mediasource-readystate) attribute of the [parent media
 source](#parent-media-source) is not in the
 \"[`open`](#dom-readystate-open)\" state then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
 3. If the [range
 removal](#dfn-range-removal) algorithm is running,
 then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
 4. If the
 [`updating`](#dom-sourcebuffer-updating) attribute equals true, then run
 the following steps:
 1. Abort the [buffer
 append](#dfn-buffer-append) algorithm if it is
 running.
 2. Set the
 [`updating`](#dom-sourcebuffer-updating) attribute to false.
 3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named [`abort`](#dfn-abort) at this
 [`SourceBuffer`](#dom-sourcebuffer) object.
 4. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named [`updateend`](#dfn-updateend) at this
 [`SourceBuffer`](#dom-sourcebuffer) object.
 5. Run the [reset parser
 state](#dfn-reset-parser-state) algorithm.
 6. Set
 [`appendWindowStart`](#dom-sourcebuffer-appendwindowstart) to the [presentation start
 time](#presentation-start-time).
 7. Set
 [`appendWindowEnd`](#dom-sourcebuffer-appendwindowend) to positive Infinity.

[`changeType`]

: Changes the MIME type associated with this object. Subsequent
 [`appendBuffer`](#dom-sourcebuffer-appendbuffer)`()` calls will
 expect the newly appended bytes to conform to the new type.

 When this method is invoked, the user agent must run the following
 steps:

 1. If `type` is an empty string
 then throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) exception and abort these steps.

 2. If this object has been removed from the
 [`sourceBuffers`](#dom-mediasource-sourcebuffers) attribute of the [parent media
 source](#parent-media-source), then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.

 3. If the
 [`updating`](#dom-sourcebuffer-updating) attribute equals true, then throw
 an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.

 4. If `type` contains a MIME type
 that is not supported or contains a MIME type that is not
 supported with the types specified (currently or previously) of
 [`SourceBuffer`](#dom-sourcebuffer) objects in the
 [`sourceBuffers`](#dom-mediasource-sourcebuffers) attribute of the [parent media
 source](#parent-media-source), then throw a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception and abort these steps.

 5. If the
 [`readyState`](#dom-mediasource-readystate) attribute of the [parent media
 source](#parent-media-source) is in the
 \"[`ended`](#dom-readystate-ended)\" state then run the following
 steps:

 1. Set the
 [`readyState`](#dom-mediasource-readystate) attribute of the [parent media
 source](#parent-media-source) to
 \"[`open`](#dom-readystate-open)\".
 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`sourceopen`](#dfn-sourceopen) at the [parent
 media
 source](#parent-media-source).

 6. Run the [reset parser
 state](#dfn-reset-parser-state) algorithm.

 7. Update the
 [`[[generate timestamps flag]]`](#dfn-generate-timestamps-flag) on this
 [`SourceBuffer`](#dom-sourcebuffer) object to the
 value in the \"Generate Timestamps Flag\" column of the byte
 stream format registry
 \[[MSE-REGISTRY](#bib-mse-registry "Media Source Extensions™ Byte Stream Format Registry")\] entry that is associated with
 `type`.

 8.

 If the [`[[generate timestamps flag]]`](#dfn-generate-timestamps-flag) equals true:
 : Set the
 [`mode`](#dom-sourcebuffer-mode) attribute on this
 [`SourceBuffer`](#dom-sourcebuffer) object to
 \"[`sequence`](#dom-appendmode-sequence)\", including running the
 associated steps for that attribute being set.

 Otherwise:
 : Keep the previous value of the
 [`mode`](#dom-sourcebuffer-mode) attribute on this
 [`SourceBuffer`](#dom-sourcebuffer) object,
 without running any associated steps for that attribute
 being set.

 9. Set the
 [`[[pending initialization segment for changeType flag]]`](#dfn-pending-initialization-segment-for-changetype-flag) on
 this
 [`SourceBuffer`](#dom-sourcebuffer) object to true.

[`remove`]

: Removes media for a specific time range. The `start` of
 the removal range, in seconds measured from [presentation start
 time](#presentation-start-time) The `end` of
 the removal range, in seconds measured from [presentation start
 time](#presentation-start-time).

 When this method is invoked, the user agent must run the following
 steps:

 1. If this object has been removed from the
 [`sourceBuffers`](#dom-mediasource-sourcebuffers) attribute of the [parent media
 source](#parent-media-source) then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.

 2. If the
 [`updating`](#dom-sourcebuffer-updating) attribute equals true, then throw
 an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.

 3. If
 [`duration`](#dom-mediasource-duration) equals NaN, then throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) exception and abort these steps.

 4. If `start` is negative or greater
 than
 [`duration`](#dom-mediasource-duration), then throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) exception and abort these steps.

 5. If `end` is less than
 or equal to `start` or
 `end` equals NaN,
 then throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) exception and abort these steps.

 6. If the
 [`readyState`](#dom-mediasource-readystate) attribute of the [parent media
 source](#parent-media-source) is in the
 \"[`ended`](#dom-readystate-ended)\" state then run the following
 steps:

 1. Set the
 [`readyState`](#dom-mediasource-readystate) attribute of the [parent media
 source](#parent-media-source) to
 \"[`open`](#dom-readystate-open)\"
 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`sourceopen`](#dfn-sourceopen) at the [parent
 media
 source](#parent-media-source).

 7. Run the [range
 removal](#dfn-range-removal) algorithm with
 `start` and `end` as the start and end of the
 removal range.

::: header-wrapper
### 5.3 Track Buffers

A [track buffer] stores the [track
descriptions](#dfn-track-description) and [coded
frames](#dfn-coded-frame) for an individual track. The track buffer
is updated as [initialization
segments](#dfn-initialization-segment) and [media
segments](#dfn-media-segment) are appended to the
[`SourceBuffer`](#dom-sourcebuffer).

Each [track buffer](#track-buffer) has a [last decode
timestamp] variable that stores the decode
timestamp of the last [coded
frame](#dfn-coded-frame) appended in the current [coded frame
group](#dfn-coded-frame-group). The variable is initially
unset to indicate that no [coded
frames](#dfn-coded-frame) have been appended yet.

Each [track buffer](#track-buffer) has a [last frame
duration] variable that stores the [coded frame
duration](#dfn-coded-frame-duration) of the last [coded
frame](#dfn-coded-frame) appended in the current [coded frame
group](#dfn-coded-frame-group). The variable is initially
unset to indicate that no [coded
frames](#dfn-coded-frame) have been appended yet.

Each [track buffer](#track-buffer) has a [highest end
timestamp] variable that stores the highest
[coded frame end
timestamp](#dfn-coded-frame-end-timestamp) across all [coded
frames](#dfn-coded-frame) in the current [coded frame
group](#dfn-coded-frame-group) that were appended to this
track buffer. The variable is initially unset to indicate that no [coded
frames](#dfn-coded-frame) have been appended yet.

Each [track buffer](#track-buffer) has a [need random access point
flag] variable that keeps track of whether the track buffer is
waiting for a [random access
point](#random-access-point) [coded
frame](#dfn-coded-frame). The variable is initially set to true to
indicate that [random access
point](#random-access-point) [coded
frame](#dfn-coded-frame) is needed before anything can be added to
the [track buffer](#track-buffer).

Each [track buffer](#track-buffer) has a [track buffer
ranges] variable that represents the presentation time ranges
occupied by the [coded
frames](#dfn-coded-frame) currently stored in the track buffer.

For track buffer ranges, these presentation time ranges are based on
[presentation
timestamps](#presentation-timestamp), frame durations, and
potentially coded frame group start times for coded frame groups across
track buffers in a muxed
[`SourceBuffer`](#dom-sourcebuffer).

For specification purposes, this information is treated as if it were
stored in a [normalized TimeRanges
object](https://html.spec.whatwg.org/multipage/media.html#normalised-timeranges-object).
Intersected [track buffer
ranges](#track-buffer-ranges) are used to report
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered),
and *MUST* therefore support uninterrupted playback within each range of
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered).

These coded frame group start times differ slightly from those mentioned
in the [coded frame
processing](#dfn-coded-frame-processing) algorithm in that they are the
earliest [presentation
timestamp](#presentation-timestamp) across all track buffers
following a discontinuity. Discontinuities can occur within the [coded
frame
processing](#dfn-coded-frame-processing) algorithm or result from the
[coded frame
removal](#dfn-coded-frame-removal) algorithm, regardless of
[`mode`](#dom-sourcebuffer-mode). The threshold for determining
disjointness of [track buffer
ranges](#track-buffer-ranges) is implementation-specific.
For example, to reduce unexpected playback stalls, implementations *MAY*
approximate the [coded frame
processing](#dfn-coded-frame-processing) algorithm\'s discontinuity
detection logic by coalescing adjacent ranges separated by a gap smaller
than 2 times the maximum frame duration buffered so far in this [track
buffer](#track-buffer). Implementations *MAY* also use coded frame
group start times as range start times across [track
buffers](#track-buffer) in a muxed
[`SourceBuffer`](#dom-sourcebuffer) to further reduce
unexpected playback stalls.

::: header-wrapper
### 5.4 Event Summary

Event name Interface Dispatched when\...
 ------------------------------------------------------------------------------------------------------------ --------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 [updatestart] [`Event`](https://dom.spec.whatwg.org/#event) [`SourceBuffer`](#dom-sourcebuffer)\'s [`updating`](#dom-sourcebuffer-updating) transitions from false to true.
 [update] [`Event`](https://dom.spec.whatwg.org/#event) A [`SourceBuffer`](#dom-sourcebuffer)\'s append or remove successfully completed. [`SourceBuffer`](#dom-sourcebuffer)\'s [`updating`](#dom-sourcebuffer-updating) transitions from true to false.
 [updateend] [`Event`](https://dom.spec.whatwg.org/#event) The append or remove of a [`SourceBuffer`](#dom-sourcebuffer) ended.
 [error] [`Event`](https://dom.spec.whatwg.org/#event) An error occurred during the append to a [`SourceBuffer`](#dom-sourcebuffer). [`updating`](#dom-sourcebuffer-updating) transitions from true to false.
 [abort] [`Event`](https://dom.spec.whatwg.org/#event) The [`SourceBuffer`](#dom-sourcebuffer)\'s append was aborted by an [`abort`](#dom-sourcebuffer-abort)`()` call. [`updating`](#dom-sourcebuffer-updating) transitions from true to false.

::: header-wrapper
### 5.5 Algorithms

::: header-wrapper
#### 5.5.1 [Segment Parser Loop]

Each [`SourceBuffer`](#dom-sourcebuffer) object has an
[\[\[append state\]\]] internal slot that keeps track of the high-level
segment parsing state. It is initially set to
[WAITING_FOR_SEGMENT](#sourcebuffer-waiting-for-segment) and can transition to the
following states as data is appended.

 Append state name Description
 ---------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 [WAITING_FOR_SEGMENT] Waiting for the start of an [initialization segment](#dfn-initialization-segment) or [media segment](#dfn-media-segment) to be appended.
 [PARSING_INIT_SEGMENT] Currently parsing an [initialization segment](#dfn-initialization-segment).
 [PARSING_MEDIA_SEGMENT] Currently parsing a [media segment](#dfn-media-segment).

Each [`SourceBuffer`](#dom-sourcebuffer) object has an [\[\[input
buffer\]\]]
internal slot that is a byte buffer that holds unparsed bytes across
[`appendBuffer`](#dom-sourcebuffer-appendbuffer)`()` calls. The buffer
is empty when the
[`SourceBuffer`](#dom-sourcebuffer) object is created.

Each [`SourceBuffer`](#dom-sourcebuffer) object has a [\[\[buffer
full flag\]\]]
internal slot that keeps track of whether
[`appendBuffer`](#dom-sourcebuffer-appendbuffer)`()` is allowed to
accept more bytes. It is set to false when the
[`SourceBuffer`](#dom-sourcebuffer) object is created and
gets updated as data is appended and removed.

Each [`SourceBuffer`](#dom-sourcebuffer) object has a [\[\[group
start timestamp\]\]] internal slot that keeps track of
the starting timestamp for a new [coded frame
group](#dfn-coded-frame-group) in the
\"[`sequence`](#dom-appendmode-sequence)\" mode. It is unset when the SourceBuffer
object is created and gets updated when the
[`mode`](#dom-sourcebuffer-mode) attribute equals
\"[`sequence`](#dom-appendmode-sequence)\" and the
[`timestampOffset`](#dom-sourcebuffer-timestampoffset) attribute is set, or the [coded frame
processing](#dfn-coded-frame-processing) algorithm runs.

Each [`SourceBuffer`](#dom-sourcebuffer) object has a [\[\[group
end timestamp\]\]] internal slot that stores the highest [coded
frame end
timestamp](#dfn-coded-frame-end-timestamp) across all [coded
frames](#dfn-coded-frame) in the current [coded frame
group](#dfn-coded-frame-group). It is set to 0 when the
SourceBuffer object is created and gets updated by the [coded frame
processing](#dfn-coded-frame-processing) algorithm.

[`[[group end timestamp]]`](#dfn-group-end-timestamp) stores
the highest [coded frame end
timestamp](#dfn-coded-frame-end-timestamp) across all [track
buffers](#track-buffer) in a
[`SourceBuffer`](#dom-sourcebuffer). Therefore, care should
be taken in setting the
[`mode`](#dom-sourcebuffer-mode) attribute when appending multiplexed
segments in which the timestamps are not aligned across tracks.

Each [`SourceBuffer`](#dom-sourcebuffer) object has a
[\[\[generate timestamps flag\]\]] internal slot that is a boolean
that keeps track of whether timestamps need to be generated for the
[coded frames](#dfn-coded-frame) passed to the [coded frame
processing](#dfn-coded-frame-processing) algorithm. This flag is set by
[`addSourceBuffer`](#dom-mediasource-addsourcebuffer)`()` when the
[`SourceBuffer`](#dom-sourcebuffer) object is created and is
updated by
[`changeType`](#dom-sourcebuffer-changetype)`()`.

When the segment parser loop algorithm is invoked, run the following
steps:

1. *Loop Top:* If the
 [`[[input buffer]]`](#dfn-input-buffer) is empty,
 then jump to the *need more data* step below.

2. If the
 [`[[input buffer]]`](#dfn-input-buffer) contains
 bytes that violate the [SourceBuffer byte stream format
 specification](#dfn-sourcebuffer-byte-stream-format-specification), then run the [append
 error](#dfn-append-error) algorithm and abort this algorithm.

3. Remove any bytes that the [byte stream format
 specifications](#byte-stream-format-specs) say *MUST* be ignored from
 the start of the
 [`[[input buffer]]`](#dfn-input-buffer).

4. If the
 [`[[append state]]`](#dfn-append-state) equals
 [WAITING_FOR_SEGMENT](#sourcebuffer-waiting-for-segment), then run the following
 steps:

 1. If the beginning of the
 [`[[input buffer]]`](#dfn-input-buffer)
 indicates the start of an [initialization
 segment](#dfn-initialization-segment), set the
 [`[[append state]]`](#dfn-append-state) to
 [PARSING_INIT_SEGMENT](#sourcebuffer-parsing-init-segment).
 2. If the beginning of the
 [`[[input buffer]]`](#dfn-input-buffer)
 indicates the start of a [media
 segment](#dfn-media-segment), set
 [`[[append state]]`](#dfn-append-state) to
 [PARSING_MEDIA_SEGMENT](#sourcebuffer-parsing-media-segment).
 3. Jump to the *loop top* step above.

5. If the
 [`[[append state]]`](#dfn-append-state) equals
 [PARSING_INIT_SEGMENT](#sourcebuffer-parsing-init-segment), then run the following
 steps:

 1. If the
 [`[[input buffer]]`](#dfn-input-buffer) does
 not contain a complete [initialization
 segment](#dfn-initialization-segment) yet, then jump to the
 *need more data* step below.
 2. Run the [initialization segment
 received](#dfn-initialization-segment-received) algorithm.
 3. Remove the [initialization
 segment](#dfn-initialization-segment) bytes from the
 beginning of the
 [`[[input buffer]]`](#dfn-input-buffer).
 4. Set
 [`[[append state]]`](#dfn-append-state) to
 [WAITING_FOR_SEGMENT](#sourcebuffer-waiting-for-segment).
 5. Jump to the *loop top* step above.

6. If the
 [`[[append state]]`](#dfn-append-state) equals
 [PARSING_MEDIA_SEGMENT](#sourcebuffer-parsing-media-segment), then run the following
 steps:

 1. If the
 [`[[first initialization segment received flag]]`](#dfn-first-initialization-segment-received-flag) is false or
 the
 [`[[pending initialization segment for changeType flag]]`](#dfn-pending-initialization-segment-for-changetype-flag) is
 true, then run the [append
 error](#dfn-append-error) algorithm and abort
 this algorithm.
 2. If the
 [`[[input buffer]]`](#dfn-input-buffer)
 contains one or more complete [coded
 frames](#dfn-coded-frame), then run the [coded
 frame
 processing](#dfn-coded-frame-processing) algorithm.

 ::::
 :::
 Note
 :::

 The frequency at which the coded frame processing algorithm is
 run is implementation-specific. The coded frame processing
 algorithm *MAY* be called when the input buffer contains the
 complete media segment or it *MAY* be called multiple times as
 complete coded frames are added to the input buffer.
 ::::
 3. If this
 [`SourceBuffer`](#dom-sourcebuffer) is full and
 cannot accept more media data, then set the
 [`[[buffer full flag]]`](#dfn-buffer-full-flag) to
 true.
 4. If the
 [`[[input buffer]]`](#dfn-input-buffer) does
 not contain a complete [media
 segment](#dfn-media-segment), then jump to the
 *need more data* step below.
 5. Remove the [media
 segment](#dfn-media-segment) bytes from the
 beginning of the
 [`[[input buffer]]`](#dfn-input-buffer).
 6. Set
 [`[[append state]]`](#dfn-append-state) to
 [WAITING_FOR_SEGMENT](#sourcebuffer-waiting-for-segment).
 7. Jump to the *loop top* step above.

7. *Need more data:* Return control to the calling algorithm.

::: header-wrapper
#### 5.5.2 [Reset Parser State]

When the parser state needs to be reset, run the following steps:

1. If the
 [`[[append state]]`](#dfn-append-state) equals
 [PARSING_MEDIA_SEGMENT](#sourcebuffer-parsing-media-segment) and the
 [`[[input buffer]]`](#dfn-input-buffer) contains
 some complete [coded
 frames](#dfn-coded-frame), then run the [coded frame
 processing](#dfn-coded-frame-processing) algorithm until all of
 these complete [coded
 frames](#dfn-coded-frame) have been processed.
2. Unset the [last decode
 timestamp](#last-decode-timestamp) on all [track
 buffers](#track-buffer).
3. Unset the [last frame
 duration](#last-frame-duration) on all [track
 buffers](#track-buffer).
4. Unset the [highest end
 timestamp](#highest-end-timestamp) on all [track
 buffers](#track-buffer).
5. Set the [need random access point
 flag](#need-RAP-flag) on all [track
 buffers](#track-buffer) to true.
6. If the
 [`mode`](#dom-sourcebuffer-mode) attribute equals
 \"[`sequence`](#dom-appendmode-sequence)\", then set the
 [`[[group start timestamp]]`](#dfn-group-start-timestamp)
 to the
 [`[[group end timestamp]]`](#dfn-group-end-timestamp)
7. Remove all bytes from the
 [`[[input buffer]]`](#dfn-input-buffer).
8. Set
 [`[[append state]]`](#dfn-append-state) to
 [WAITING_FOR_SEGMENT](#sourcebuffer-waiting-for-segment).

::: header-wrapper
#### 5.5.3 [Append Error]

This algorithm is called when an error occurs during an append.

1. Run the [reset parser
 state](#dfn-reset-parser-state) algorithm.
2. Set the
 [`updating`](#dom-sourcebuffer-updating) attribute to false.
3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named [`error`](#dfn-error) at this
 [`SourceBuffer`](#dom-sourcebuffer) object.
4. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named [`updateend`](#dfn-updateend) at this
 [`SourceBuffer`](#dom-sourcebuffer) object.
5. Run the [end of
 stream](#dfn-end-of-stream) algorithm with the
 `error` parameter set to
 \"[`decode`](#dom-endofstreamerror-decode)\".

::: header-wrapper
#### 5.5.4 [Prepare Append]

When an append operation begins, the following steps are run to validate
and prepare the
[`SourceBuffer`](#dom-sourcebuffer).

1. If the
 [`SourceBuffer`](#dom-sourcebuffer) has been removed
 from the
 [`sourceBuffers`](#dom-mediasource-sourcebuffers) attribute of the [parent media
 source](#parent-media-source) then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.

2. If the
 [`updating`](#dom-sourcebuffer-updating) attribute equals true, then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.

3. Let `recent element error` be
 determined as follows:

 If the [`MediaSource`](#dom-mediasource) was constructed in a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)
 : Let `recent element error` be
 true if the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`error`](#dfn-error) attribute is not null. If that attribute is
 null, then let `recent element error` be false.

 Otherwise
 : Let `recent element error` be the
 value resulting from the steps for the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) case, but run on the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) on any change to its
 [`error`](#dfn-error) attribute and communicated by using
 [`[[port to worker]]`](#dfn-port-to-worker)
 implicit messages. If such a message has not yet been received,
 then let `recent element error`
 be false.

4. If `recent element error` is true,
 then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.

5. If the
 [`readyState`](#dom-mediasource-readystate) attribute of the [parent media
 source](#parent-media-source) is in the
 \"[`ended`](#dom-readystate-ended)\" state then run the following steps:

 1. Set the
 [`readyState`](#dom-mediasource-readystate) attribute of the [parent media
 source](#parent-media-source) to
 \"[`open`](#dom-readystate-open)\"
 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named [`sourceopen`](#dfn-sourceopen) at the [parent
 media
 source](#parent-media-source).

6. Run the [coded frame
 eviction](#dfn-coded-frame-eviction) algorithm.

7. If the
 [`[[buffer full flag]]`](#dfn-buffer-full-flag) equals
 true, then throw a
 [`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror) exception and abort these steps.

 ::::
 :::
 Note
 :::

 This is the signal that the implementation was unable to evict
 enough data to accommodate the append or the append is too big. The
 web application *SHOULD* use
 [`remove`](#dom-sourcebuffer-remove)`()` to explicitly free
 up space and/or reduce the size of the append.
 ::::

::: header-wrapper
#### 5.5.5 [Buffer Append]

[`appendBuffer`](#dom-sourcebuffer-appendbuffer)`()` is called, the
following steps are run to process the appended data.

1. Run the [segment parser
 loop](#dfn-segment-parser-loop) algorithm.
2. If the [segment parser
 loop](#dfn-segment-parser-loop) algorithm in the previous
 step was aborted, then abort this algorithm.
3. Set the
 [`updating`](#dom-sourcebuffer-updating) attribute to false.
4. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named [`update`](#dfn-update) at this
 [`SourceBuffer`](#dom-sourcebuffer) object.
5. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named [`updateend`](#dfn-updateend) at this
 [`SourceBuffer`](#dom-sourcebuffer) object.

::: header-wrapper
#### 5.5.6 [Range Removal]

Follow these steps when a caller needs to initiate a JavaScript visible
range removal operation that blocks other SourceBuffer updates:

1. Let `start` equal the starting
 [presentation
 timestamp](#presentation-timestamp) for the removal range, in
 seconds measured from [presentation start
 time](#presentation-start-time).
2. Let `end` equal the end
 [presentation
 timestamp](#presentation-timestamp) for the removal range, in
 seconds measured from [presentation start
 time](#presentation-start-time).
3. Set the
 [`updating`](#dom-sourcebuffer-updating) attribute to true.
4. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named [`updatestart`](#dfn-updatestart) at this
 [`SourceBuffer`](#dom-sourcebuffer) object.
5. Return control to the caller and run the rest of the steps
 asynchronously.
6. Run the [coded frame
 removal](#dfn-coded-frame-removal) algorithm with
 `start` and `end` as the start and end of the removal
 range.
7. Set the
 [`updating`](#dom-sourcebuffer-updating) attribute to false.
8. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named [`update`](#dfn-update) at this
 [`SourceBuffer`](#dom-sourcebuffer) object.
9. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named [`updateend`](#dfn-updateend) at this
 [`SourceBuffer`](#dom-sourcebuffer) object.

::: header-wrapper
#### 5.5.7 [Initialization Segment Received]

The following steps are run when the [segment parser
loop](#dfn-segment-parser-loop) successfully parses a complete
[initialization
segment](#dfn-initialization-segment):

Each SourceBuffer object has a [\[\[first initialization segment
received flag\]\]] internal slot that tracks whether
the first [initialization
segment](#dfn-initialization-segment) has been appended and received
by this algorithm. This flag is set to false when the SourceBuffer is
created and updated by the algorithm below.

Each SourceBuffer object has a [\[\[pending initialization segment for
changeType
flag\]\]] internal slot that tracks whether
an [initialization
segment](#dfn-initialization-segment) is needed since the most
recent
[`changeType`](#dom-sourcebuffer-changetype)`()`. This flag is set to
false when the SourceBuffer is created, set to true by
[`changeType`](#dom-sourcebuffer-changetype)`()` and reset to false
by the algorithm below.

1. Update the
 [`duration`](#dom-mediasource-duration) attribute if it currently equals NaN:

 If the initialization segment contains a duration:
 : Run the [duration
 change](#dfn-duration-change) algorithm with
 `new duration` set to
 the duration in the initialization segment.

 Otherwise:
 : Run the [duration
 change](#dfn-duration-change) algorithm with
 `new duration` set to
 positive Infinity.

2. If the [initialization
 segment](#dfn-initialization-segment) has no audio, video, or
 text tracks, then run the [append
 error](#dfn-append-error) algorithm and abort these steps.

3. If the
 [`[[first initialization segment received flag]]`](#dfn-first-initialization-segment-received-flag) is true, then
 run the following steps:
 1. Verify the following properties. If any of the checks fail then
 run the [append
 error](#dfn-append-error) algorithm and abort
 these steps.
 - The number of audio, video, and text tracks match what was in
 the first [initialization
 segment](#dfn-initialization-segment).
 - If more than one track for a single type are present (e.g., 2
 audio tracks), then the [Track
 IDs](#dfn-track-id) match the ones in the first
 [initialization
 segment](#dfn-initialization-segment).
 - The codecs for each track are supported by the user agent.

 ::::
 :::
 Note
 :::

 User agents *MAY* consider codecs, that would otherwise be
 supported, as \"not supported\" here if the codecs were not
 specified in `type` parameter
 passed to (a) the most recently successful
 [`changeType`](#dom-sourcebuffer-changetype)`()` on this
 [`SourceBuffer`](#dom-sourcebuffer) object, or (b)
 if no successful
 [`changeType`](#dom-sourcebuffer-changetype)`()` has yet
 occurred on this object, the
 [`addSourceBuffer`](#dom-mediasource-addsourcebuffer)`()` that
 created this
 [`SourceBuffer`](#dom-sourcebuffer) object. For
 example, if the most recently successful
 [`changeType`](#dom-sourcebuffer-changetype)`()` was called
 with `'video/webm'` or `'video/webm; codecs="vp8"'`, and a
 video track containing vp9 appears in the initialization
 segment, then the user agent *MAY* use this step to trigger a
 decode error even if the other two properties\' checks, above,
 pass. Implementations are encouraged to trigger error in such
 cases only when the codec is indeed not supported or the other
 two properties\' checks fail. Web authors are encouraged to
 use
 [`changeType`](#dom-sourcebuffer-changetype)`()`,
 [`addSourceBuffer`](#dom-mediasource-addsourcebuffer)`()` and
 [`isTypeSupported`](#dom-mediasource-istypesupported)`()` with
 precise codec parameters to more proactively detect user agent
 support.
 [`changeType`](#dom-sourcebuffer-changetype)`()` is
 required if the
 [`SourceBuffer`](#dom-sourcebuffer) object\'s
 bytestream format is changing.
 ::::
 2. Add the appropriate [track
 descriptions](#dfn-track-description) from this
 [initialization
 segment](#dfn-initialization-segment) to each of the [track
 buffers](#track-buffer).
 3. Set the [need random access point
 flag](#need-RAP-flag) on all track buffers to true.

4. Let `active track flag` equal false.

5. If the
 [`[[first initialization segment received flag]]`](#dfn-first-initialization-segment-received-flag) is false, then
 run the following steps:

 1. If the [initialization
 segment](#dfn-initialization-segment) contains tracks with
 codecs the user agent does not support, then run the [append
 error](#dfn-append-error) algorithm and abort
 these steps.

 ::::
 :::
 Note
 :::

 User agents *MAY* consider codecs, that would otherwise be
 supported, as \"not supported\" here if the codecs were not
 specified in `type` parameter
 passed to (a) the most recently successful
 [`changeType`](#dom-sourcebuffer-changetype)`()` on this
 [`SourceBuffer`](#dom-sourcebuffer) object, or (b)
 if no successful
 [`changeType`](#dom-sourcebuffer-changetype)`()` has yet
 occurred on this object, the
 [`addSourceBuffer`](#dom-mediasource-addsourcebuffer)`()` that
 created this
 [`SourceBuffer`](#dom-sourcebuffer) object. For
 example,
 `MediaSource.isTypeSupported('video/webm;codecs="vp8,vorbis"')`
 may return true, but if
 [`addSourceBuffer`](#dom-mediasource-addsourcebuffer)`()` was
 called with `'video/webm;codecs="vp8"'` and a Vorbis track
 appears in the [initialization
 segment](#dfn-initialization-segment), then the user agent
 *MAY* use this step to trigger a decode error. Implementations
 are encouraged to trigger error in such cases only when the
 codec is indeed not supported. Web authors are encouraged to use
 [`changeType`](#dom-sourcebuffer-changetype)`()`,
 [`addSourceBuffer`](#dom-mediasource-addsourcebuffer)`()` and
 [`isTypeSupported`](#dom-mediasource-istypesupported)`()` with
 precise codec parameters to more proactively detect user agent
 support.
 [`changeType`](#dom-sourcebuffer-changetype)`()` is required
 if the
 [`SourceBuffer`](#dom-sourcebuffer) object\'s
 bytestream format is changing.
 ::::

 2. For each audio track in the [initialization
 segment](#dfn-initialization-segment), run following steps:

 1. Let `audio byte stream track ID` be the [Track
 ID](#dfn-track-id) for the current track being
 processed.
 2. Let `audio language` be a
 BCP 47 language tag for the language specified in the
 [initialization
 segment](#dfn-initialization-segment) for this track or
 an empty string if no language info is present.
 3. If `audio language` equals
 the \'und\' BCP 47 value, then assign an empty string to
 `audio language`.
 4. Let `audio label` be a
 label specified in the [initialization
 segment](#dfn-initialization-segment) for this track or
 an empty string if no label info is present.
 5. Let `audio kinds`
 be a sequence of kind strings specified in the
 [initialization
 segment](#dfn-initialization-segment) for this track or
 a sequence with a single empty string element in it if no
 kind information is provided.
 6. For each value in `audio kinds`, run the following steps:
 1. Let `current audio kind` equal the value from
 `audio kinds`
 for this iteration of the loop.

 2. Let `new audio track`
 be a new
 [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack) object.

 3. Generate a unique ID and assign it to the
 [`id`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-id)
 property on `new audio track`.

 4. Assign `audio language`
 to the
 [`language`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-language)
 property on `new audio track`.

 5. Assign `audio label` to
 the
 [`label`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-label)
 property on `new audio track`.

 6. Assign `current audio kind` to the
 [`kind`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-kind)
 property on `new audio track`.

 7. If this
 [`SourceBuffer`](#dom-sourcebuffer)
 object\'s
 [`audioTracks`](#dom-sourcebuffer-audiotracks)\'s
 [`length`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotracklist-length)
 equals 0, then run the following steps:

 1. Set the
 [`enabled`](https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-enabled)
 property on `new audio track` to true.
 2. Set `active track flag` to true.

 8. Add `new audio track`
 to the
 [`audioTracks`](#dom-sourcebuffer-audiotracks) attribute on this
 [`SourceBuffer`](#dom-sourcebuffer) object.

 ::::
 :::
 Note
 :::

 This should trigger
 [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [addtrack](https://html.spec.whatwg.org/multipage/media.html#event-media-addtrack)
 using
 [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent) with the
 [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track)
 attribute initialized to `new audio track`, at the
 [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist) object referenced by the
 [`audioTracks`](#dom-sourcebuffer-audiotracks) attribute on this
 [`SourceBuffer`](#dom-sourcebuffer) object.
 ::::

 9.

 If the [parent media source](#parent-media-source) was constructed in a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope):
 : Post an internal `create track mirror` message to
 [`[[port to main]]`](#dfn-port-to-main) whose implicit handler in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) runs the following steps:
 1. Let `mirrored audio track` be a new
 [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack) object.
 2. Assign the same property values to
 `mirrored audio track` as were determined for
 `new audio track`.
 3. Add `mirrored audio track` to the
 [`audioTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-audiotracks)
 attribute on the HTMLMediaElement.

 Otherwise:
 : Add `new audio track` to the
 [`audioTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-audiotracks)
 attribute on the HTMLMediaElement.

 ::::
 :::
 Note
 :::

 This should trigger
 [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [addtrack](https://html.spec.whatwg.org/multipage/media.html#event-media-addtrack)
 using
 [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent) with the
 [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track)
 attribute initialized to
 `mirrored audio track`
 or `new audio track`,
 at the
 [`AudioTrackList`](https://html.spec.whatwg.org/multipage/media.html#audiotracklist) object referenced by the
 [`audioTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-audiotracks)
 attribute on the HTMLMediaElement.
 ::::
 7. Create a new [track
 buffer](#track-buffer) to store [coded
 frames](#dfn-coded-frame) for this track.
 8. Add the [track
 description](#dfn-track-description) for this track to
 the [track buffer](#track-buffer).

 3. For each video track in the [initialization
 segment](#dfn-initialization-segment), run following steps:

 1. Let `video byte stream track ID` be the [Track
 ID](#dfn-track-id) for the current track being
 processed.
 2. Let `video language` be a
 BCP 47 language tag for the language specified in the
 [initialization
 segment](#dfn-initialization-segment) for this track or
 an empty string if no language info is present.
 3. If `video language` equals
 the \'und\' BCP 47 value, then assign an empty string to
 `video language`.
 4. Let `video label` be a
 label specified in the [initialization
 segment](#dfn-initialization-segment) for this track or
 an empty string if no label info is present.
 5. Let `video kinds`
 be a sequence of kind strings specified in the
 [initialization
 segment](#dfn-initialization-segment) for this track or
 a sequence with a single empty string element in it if no
 kind information is provided.
 6. For each value in `video kinds`, run the following steps:
 1. Let `current video kind` equal the value from
 `video kinds`
 for this iteration of the loop.

 2. Let `new video track`
 be a new
 [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack) object.

 3. Generate a unique ID and assign it to the
 [`id`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-id)
 property on `new video track`.

 4. Assign `video language`
 to the
 [`language`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-language)
 property on `new video track`.

 5. Assign `video label` to
 the
 [`label`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-label)
 property on `new video track`.

 6. Assign `current video kind` to the
 [`kind`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-kind)
 property on `new video track`.

 7. If this
 [`SourceBuffer`](#dom-sourcebuffer)
 object\'s
 [`videoTracks`](#dom-sourcebuffer-videotracks)\'s
 [`length`](https://html.spec.whatwg.org/multipage/media.html#dom-videotracklist-length)
 equals 0, then run the following steps:

 1. Set the
 [`selected`](https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-selected)
 property on `new video track` to true.
 2. Set `active track flag` to true.

 8. Add `new video track`
 to the
 [`videoTracks`](#dom-sourcebuffer-videotracks) attribute on this
 [`SourceBuffer`](#dom-sourcebuffer) object.

 ::::
 :::
 Note
 :::

 This should trigger
 [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [addtrack](https://html.spec.whatwg.org/multipage/media.html#event-media-addtrack)
 using
 [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent) with the
 [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track)
 attribute initialized to `new video track`, at the
 [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist) object referenced by the
 [`videoTracks`](#dom-sourcebuffer-videotracks) attribute on this
 [`SourceBuffer`](#dom-sourcebuffer) object.
 ::::

 9.

 If the [parent media source](#parent-media-source) was constructed in a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope):
 : Post an internal `create track mirror` message to
 [`[[port to main]]`](#dfn-port-to-main) whose implicit handler in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) runs the following steps:
 1. Let `mirrored video track` be a new
 [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack) object.
 2. Assign the same property values to
 `mirrored video track` as were determined for
 `new video track`.
 3. Add `mirrored video track` to the
 [`videoTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-videotracks)
 attribute on the HTMLMediaElement.

 Otherwise:
 : Add `new video track` to the
 [`videoTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-videotracks)
 attribute on the HTMLMediaElement.

 ::::
 :::
 Note
 :::

 This should trigger
 [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [addtrack](https://html.spec.whatwg.org/multipage/media.html#event-media-addtrack)
 using
 [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent) with the
 [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track)
 attribute initialized to
 `mirrored video track`
 or `new video track`,
 at the
 [`VideoTrackList`](https://html.spec.whatwg.org/multipage/media.html#videotracklist) object referenced by the
 [`videoTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-videotracks)
 attribute on the HTMLMediaElement.
 ::::
 7. Create a new [track
 buffer](#track-buffer) to store [coded
 frames](#dfn-coded-frame) for this track.
 8. Add the [track
 description](#dfn-track-description) for this track to
 the [track buffer](#track-buffer).

 4. For each text track in the [initialization
 segment](#dfn-initialization-segment), run following steps:

 1. Let `text byte stream track ID` be the [Track
 ID](#dfn-track-id) for the current track being
 processed.
 2. Let `text language` be a
 BCP 47 language tag for the language specified in the
 [initialization
 segment](#dfn-initialization-segment) for this track or
 an empty string if no language info is present.
 3. If `text language` equals
 the \'und\' BCP 47 value, then assign an empty string to
 `text language`.
 4. Let `text label` be a label
 specified in the [initialization
 segment](#dfn-initialization-segment) for this track or
 an empty string if no label info is present.
 5. Let `text kinds`
 be a sequence of kind strings specified in the
 [initialization
 segment](#dfn-initialization-segment) for this track or
 a sequence with a single empty string element in it if no
 kind information is provided.
 6. For each value in `text kinds`, run the following steps:
 1. Let `current text kind`
 equal the value from `text kinds` for this iteration of
 the loop.

 2. Let `new text track` be
 a new
 [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) object.

 3. Generate a unique ID and assign it to the
 [`id`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-id)
 property on `new text track`.

 4. Assign `text language`
 to the
 [`language`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-language)
 property on `new text track`.

 5. Assign `text label` to
 the
 [`label`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-label)
 property on `new text track`.

 6. Assign `current text kind` to the
 [`kind`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-kind)
 property on `new text track`.

 7. Populate the remaining properties on
 `new text track` with
 the appropriate information from the [initialization
 segment](#dfn-initialization-segment).

 8. If the
 [`mode`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-mode)
 property on `new text track` equals
 [`"showing"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-showing)
 or
 [`"hidden"`](https://html.spec.whatwg.org/multipage/media.html#dom-texttrack-hidden),
 then set `active track flag` to true.

 9. Add `new text track` to
 the
 [`textTracks`](#dom-sourcebuffer-texttracks) attribute on this
 [`SourceBuffer`](#dom-sourcebuffer) object.

 ::::
 :::
 Note
 :::

 This should trigger
 [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [addtrack](https://html.spec.whatwg.org/multipage/media.html#event-media-addtrack)
 using
 [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent) with the
 [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track)
 attribute initialized to `new text track`, at the
 [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist) object referenced by the
 [`textTracks`](#dom-sourcebuffer-texttracks) attribute on this
 [`SourceBuffer`](#dom-sourcebuffer) object.
 ::::

 10.

 If the [parent media source](#parent-media-source) was constructed in a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope):
 : Post an internal `create track mirror` message to
 [`[[port to main]]`](#dfn-port-to-main) whose implicit handler in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) runs the following steps:
 1. Let `mirrored text track` be a new
 [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) object.
 2. Assign the same property values to
 `mirrored text track` as were determined for
 `new text track`.
 3. Add `mirrored text track` to the
 [`textTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-texttracks)
 attribute on the HTMLMediaElement.

 Otherwise:
 : Add `new text track` to the
 [`textTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-texttracks)
 attribute on the HTMLMediaElement.

 ::::
 :::
 Note
 :::

 This should trigger
 [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist)
 \[[HTML](#bib-html "HTML Standard")\] logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [addtrack](https://html.spec.whatwg.org/multipage/media.html#event-media-addtrack)
 using
 [`TrackEvent`](https://html.spec.whatwg.org/multipage/media.html#trackevent) with the
 [`track`](https://html.spec.whatwg.org/multipage/media.html#dom-trackevent-track)
 attribute initialized to `mirrored text track` or `new text track`, at the
 [`TextTrackList`](https://html.spec.whatwg.org/multipage/media.html#texttracklist) object referenced by the
 [`textTracks`](https://html.spec.whatwg.org/multipage/media.html#dom-media-texttracks)
 attribute on the HTMLMediaElement.
 ::::
 7. Create a new [track
 buffer](#track-buffer) to store [coded
 frames](#dfn-coded-frame) for this track.
 8. Add the [track
 description](#dfn-track-description) for this track to
 the [track buffer](#track-buffer).

 5. If `active track flag` equals
 true, then run the following steps:
 1. Add this
 [`SourceBuffer`](#dom-sourcebuffer) to
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers).
 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`addsourcebuffer`](#dfn-addsourcebuffer) at
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers)

 6. Set
 [`[[first initialization segment received flag]]`](#dfn-first-initialization-segment-received-flag) to true.

6. Set
 [`[[pending initialization segment for changeType flag]]`](#dfn-pending-initialization-segment-for-changetype-flag) to
 false.

7. If the `active track flag` equals
 true, then run the following steps:

8. Use the [parent media
 source](#parent-media-source)\'s [mirror if
 necessary](#dfn-mirror-if-necessary) algorithm to run the
 following step in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window):
 1. If the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute is greater than
 [`HAVE_CURRENT_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_current_data),
 then set the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute to
 [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata).

 ::::
 :::
 Note
 :::

 Per
 [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
 \[[HTML](#bib-html "HTML Standard")\] logic,
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) changes may trigger events on the
 HTMLMediaElement.
 ::::

9. If each object in
 [`sourceBuffers`](#dom-mediasource-sourcebuffers) of the [parent media
 source](#parent-media-source) has
 [`[[first initialization segment received flag]]`](#dfn-first-initialization-segment-received-flag) equal to true,
 then use the [parent media
 source](#parent-media-source)\'s [mirror if
 necessary](#dfn-mirror-if-necessary) algorithm to run the
 following step in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window):
 1. If the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute is
 [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing),
 then set the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute to
 [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata).

 ::::
 :::
 Note
 :::

 Per
 [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
 \[[HTML](#bib-html "HTML Standard")\] logic,
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) changes may trigger events on the
 HTMLMediaElement. If transition from
 [`HAVE_NOTHING`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_nothing)
 to
 [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata)
 occurs, it should trigger HTMLMediaElement logic to [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [loadedmetadata](https://html.spec.whatwg.org/multipage/media.html#event-media-loadedmetadata)
 at the media element.
 ::::

::: header-wrapper
#### 5.5.8 [Coded Frame Processing]

When complete [coded
frames](#dfn-coded-frame) have been parsed by the [segment parser
loop](#dfn-segment-parser-loop) then the following steps are
run:

1. For each [coded frame](#dfn-coded-frame) in the [media
 segment](#dfn-media-segment) run the following steps:

 1. *Loop Top:*

 If [`[[generate timestamps flag]]`](#dfn-generate-timestamps-flag) equals true:

 : 1. Let `presentation timestamp` equal 0.
 2. Let `decode timestamp`
 equal 0.

 Otherwise:

 : 1. Let `presentation timestamp` be a double precision floating point
 representation of the coded frame\'s [presentation
 timestamp](#presentation-timestamp) in seconds.

 ::::
 :::
 Note
 :::

 Special processing may be needed to determine the
 presentation and decode timestamps for timed text frames
 since this information may not be explicitly present in
 the underlying format or may be dependent on the order
 of the frames. Some metadata text tracks, like MPEG2-TS
 PSI data, may only have implied timestamps. Format
 specific rules for these situations *SHOULD* be in the
 [byte stream format
 specifications](#byte-stream-format-specs) or in separate
 extension specifications.
 ::::
 2. Let `decode timestamp` be
 a double precision floating point representation of the
 coded frame\'s decode timestamp in seconds.

 ::::
 :::
 Note
 :::

 Implementations don\'t have to internally store
 timestamps in a double precision floating point
 representation. This representation is used here because
 it is the representation for timestamps in the HTML
 spec. The intention here is to make the behavior clear
 without adding unnecessary complexity to the algorithm
 to deal with the fact that adding a timestampOffset may
 cause a timestamp rollover in the underlying timestamp
 representation used by the byte stream format.
 Implementations can use any internal timestamp
 representation they wish, but the addition of
 timestampOffset *SHOULD* behave in a similar manner to
 what would happen if a double precision floating point
 representation was used.
 ::::

 2. Let `frame duration` be a double
 precision floating point representation of the [coded frame\'s
 duration](#dfn-coded-frame-duration) in seconds.

 3. If
 [`mode`](#dom-sourcebuffer-mode) equals
 \"[`sequence`](#dom-appendmode-sequence)\" and
 [`[[group start timestamp]]`](#dfn-group-start-timestamp) is set, then run the following
 steps:
 1. Set
 [`timestampOffset`](#dom-sourcebuffer-timestampoffset) equal to
 [`[[group start timestamp]]`](#dfn-group-start-timestamp) minus
 `presentation timestamp`.
 2. Set
 [`[[group end timestamp]]`](#dfn-group-end-timestamp) equal to
 [`[[group start timestamp]]`](#dfn-group-start-timestamp).
 3. Set the [need random access point
 flag](#need-RAP-flag) on all [track
 buffers](#track-buffer) to true.
 4. Unset
 [`[[group start timestamp]]`](#dfn-group-start-timestamp).

 4. If
 [`timestampOffset`](#dom-sourcebuffer-timestampoffset) is not 0, then run the following
 steps:

 1. Add
 [`timestampOffset`](#dom-sourcebuffer-timestampoffset) to the
 `presentation timestamp`.
 2. Add
 [`timestampOffset`](#dom-sourcebuffer-timestampoffset) to the
 `decode timestamp`.

 5. Let `track buffer` equal the [track
 buffer](#track-buffer) that the coded frame will be added
 to.

 6.

 If [last decode timestamp](#last-decode-timestamp) for `track buffer` is set and `decode timestamp` is less than [last decode timestamp](#last-decode-timestamp):
 : OR

 If [last decode timestamp](#last-decode-timestamp) for `track buffer` is set and the difference between `decode timestamp` and [last decode timestamp](#last-decode-timestamp) is greater than 2 times [last frame duration](#last-frame-duration):

 : 1.

 If [`mode`](#dom-sourcebuffer-mode) equals \"[`segments`](#dom-appendmode-segments)\":
 : Set
 [`[[group end timestamp]]`](#dfn-group-end-timestamp) to
 `presentation timestamp`.

 If [`mode`](#dom-sourcebuffer-mode) equals \"[`sequence`](#dom-appendmode-sequence)\":
 : Set
 [`[[group start timestamp]]`](#dfn-group-start-timestamp) equal to the
 [`[[group end timestamp]]`](#dfn-group-end-timestamp).

 2. Unset the [last decode
 timestamp](#last-decode-timestamp) on all [track
 buffers](#track-buffer).

 3. Unset the [last frame
 duration](#last-frame-duration) on all [track
 buffers](#track-buffer).

 4. Unset the [highest end
 timestamp](#highest-end-timestamp) on all [track
 buffers](#track-buffer).

 5. Set the [need random access point
 flag](#need-RAP-flag) on all [track
 buffers](#track-buffer) to true.

 6. Jump to the *Loop Top* step above to restart processing
 of the current [coded
 frame](#dfn-coded-frame).

 Otherwise:
 : Continue.

 7. Let `frame end timestamp` equal
 the sum of `presentation timestamp` and `frame duration`.

 8. If `presentation timestamp` is
 less than
 [`appendWindowStart`](#dom-sourcebuffer-appendwindowstart), then set the [need random access
 point flag](#need-RAP-flag) to true, drop the
 coded frame, and jump to the top of the loop to start processing
 the next coded frame.

 ::::
 :::
 Note
 :::

 Some implementations *MAY* choose to collect some of these coded
 frames with `presentation timestamp` less than
 [`appendWindowStart`](#dom-sourcebuffer-appendwindowstart) and use them to generate a splice
 at the first coded frame that has a [presentation
 timestamp](#presentation-timestamp) greater than or equal
 to
 [`appendWindowStart`](#dom-sourcebuffer-appendwindowstart) even if that frame is not a
 [random access
 point](#random-access-point). Supporting this
 requires multiple decoders or faster than real-time decoding so
 for now this behavior will not be a normative requirement.
 ::::

 9. If `frame end timestamp` is
 greater than
 [`appendWindowEnd`](#dom-sourcebuffer-appendwindowend), then set the [need random access
 point flag](#need-RAP-flag) to true, drop the
 coded frame, and jump to the top of the loop to start processing
 the next coded frame.

 ::::
 :::
 Note
 :::

 Some implementations *MAY* choose to collect coded frames with
 `presentation timestamp` less than
 [`appendWindowEnd`](#dom-sourcebuffer-appendwindowend) and
 `frame end timestamp` greater than
 [`appendWindowEnd`](#dom-sourcebuffer-appendwindowend) and use them to generate a splice
 across the portion of the collected coded frames within the
 append window at time of collection, and the beginning portion
 of later processed frames which only partially overlap the end
 of the collected coded frames. Supporting this requires multiple
 decoders or faster than real-time decoding so for now this
 behavior will not be a normative requirement. In conjunction
 with collecting coded frames that span
 [`appendWindowStart`](#dom-sourcebuffer-appendwindowstart), implementations *MAY* thus
 support gapless audio splicing.
 ::::

 10. If the [need random access point
 flag](#need-RAP-flag) on `track buffer` equals
 true, then run the following steps:
 1. If the coded frame is not a [random access
 point](#random-access-point), then drop the
 coded frame and jump to the top of the loop to start
 processing the next coded frame.
 2. Set the [need random access point
 flag](#need-RAP-flag) on `track buffer` to
 false.

 11. Let `spliced audio frame` be an unset variable for
 holding audio splice information

 12. Let `spliced timed text frame` be an unset variable
 for holding timed text splice information

 13. If [last decode
 timestamp](#last-decode-timestamp) for
 `track buffer` is unset and
 `presentation timestamp` falls within the
 [presentation
 interval](#presentation-interval) of a [coded
 frame](#dfn-coded-frame) in
 `track buffer`, then run the following steps:
 1. Let `overlapped frame` be the [coded
 frame](#dfn-coded-frame) in
 `track buffer` that matches the condition above.

 2.

 If `track buffer` contains audio [coded frames](#dfn-coded-frame):
 : Run the [audio splice
 frame](#dfn-audio-splice-frame) algorithm and
 if a splice frame is returned, assign it to
 `spliced audio frame`.

 If `track buffer` contains video [coded frames](#dfn-coded-frame):

 : 1. Let `remove window timestamp` equal the
 `overlapped frame` [presentation
 timestamp](#presentation-timestamp) plus 1
 microsecond.
 2. If the `presentation timestamp` is less than the
 `remove window timestamp`, then remove
 `overlapped frame` from
 `track buffer`.

 ::::
 :::
 Note
 :::

 This is to compensate for minor errors in frame
 timestamp computations that can appear when
 converting back and forth between double precision
 floating point numbers and rationals. This tolerance
 allows a frame to replace an existing one as long as
 it is within 1 microsecond of the existing frame\'s
 start time. Frames that come slightly before an
 existing frame are handled by the removal step
 below.
 ::::

 If `track buffer` contains timed text [coded frames](#dfn-coded-frame):
 : Run the [text splice
 frame](#dfn-text-splice-frame) algorithm and
 if a splice frame is returned, assign it to
 `spliced timed text frame`.

 14. Remove existing coded frames in `track buffer`:

 If [highest end timestamp](#highest-end-timestamp) for `track buffer` is not set:
 : Remove all [coded
 frames](#dfn-coded-frame) from
 `track buffer` that have a [presentation
 timestamp](#presentation-timestamp) greater than or
 equal to `presentation timestamp` and less than
 `frame end timestamp`.

 If [highest end timestamp](#highest-end-timestamp) for `track buffer` is set and less than or equal to `presentation timestamp`:
 : Remove all [coded
 frames](#dfn-coded-frame) from
 `track buffer` that have a [presentation
 timestamp](#presentation-timestamp) greater than or
 equal to [highest end
 timestamp](#highest-end-timestamp) and less than
 `frame end timestamp`.

 15. Remove all possible decoding dependencies on the [coded
 frames](#dfn-coded-frame) removed in the
 previous two steps by removing all [coded
 frames](#dfn-coded-frame) from
 `track buffer` between those frames removed in the
 previous two steps and the next [random access
 point](#random-access-point) after those removed
 frames.

 ::::
 :::
 Note
 :::

 Removing all [coded
 frames](#dfn-coded-frame) until the next [random
 access
 point](#random-access-point) is a conservative
 estimate of the decoding dependencies since it assumes all
 frames between the removed frames and the next random access
 point depended on the frames that were removed.
 ::::

 16.

 If `spliced audio frame` is set:
 : Add `spliced audio frame` to the
 `track buffer`.

 If `spliced timed text frame` is set:
 : Add `spliced timed text frame` to the
 `track buffer`.

 Otherwise:
 : Add the [coded
 frame](#dfn-coded-frame) with the
 `presentation timestamp`,
 `decode timestamp`, and
 `frame duration` to the
 `track buffer`.

 17. Set [last decode
 timestamp](#last-decode-timestamp) for
 `track buffer` to `decode timestamp`.

 18. Set [last frame
 duration](#last-frame-duration) for
 `track buffer` to `frame duration`.

 19. If [highest end
 timestamp](#highest-end-timestamp) for
 `track buffer` is unset or
 `frame end timestamp` is greater than [highest end
 timestamp](#highest-end-timestamp), then set [highest end
 timestamp](#highest-end-timestamp) for
 `track buffer` to `frame end timestamp`.

 ::::
 :::
 Note
 :::

 The greater than check is needed because bidirectional
 prediction between coded frames can cause
 `presentation timestamp` to not be
 monotonically increasing even though the decode timestamps are
 monotonically increasing.
 ::::

 20. If `frame end timestamp` is
 greater than
 [`[[group end timestamp]]`](#dfn-group-end-timestamp), then set
 [`[[group end timestamp]]`](#dfn-group-end-timestamp)
 equal to `frame end timestamp`.

 21. If
 [`[[generate timestamps flag]]`](#dfn-generate-timestamps-flag) equals true, then set
 [`timestampOffset`](#dom-sourcebuffer-timestampoffset) equal to
 `frame end timestamp`.

2. If the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute is
 [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata)
 and the new [coded
 frames](#dfn-coded-frame) cause
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered)
 to have a
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) for the current playback position, then set the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute to
 [`HAVE_CURRENT_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_current_data).

 ::::
 :::
 Note
 :::

 Per
 [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
 \[[HTML](#bib-html "HTML Standard")\]
 logic,
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) changes may trigger events on the
 HTMLMediaElement.
 ::::

3. If the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute is
 [`HAVE_CURRENT_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_current_data)
 and the new [coded
 frames](#dfn-coded-frame) cause
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered)
 to have a
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) that includes the current playback position and
 some time beyond the current playback position, then set the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute to
 [`HAVE_FUTURE_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_future_data).

 ::::
 :::
 Note
 :::

 Per
 [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
 \[[HTML](#bib-html "HTML Standard")\]
 logic,
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) changes may trigger events on the
 HTMLMediaElement.
 ::::

4. If the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute is
 [`HAVE_FUTURE_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_future_data)
 and the new [coded
 frames](#dfn-coded-frame) cause
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered)
 to have a
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) that includes the current playback position and
 [enough data to ensure uninterrupted
 playback](#enough-data), then set the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute to
 [`HAVE_ENOUGH_DATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_enough_data).

 ::::
 :::
 Note
 :::

 Per
 [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
 \[[HTML](#bib-html "HTML Standard")\]
 logic,
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) changes may trigger events on the
 HTMLMediaElement.
 ::::

5. If the [media
 segment](#dfn-media-segment) contains data beyond the
 current
 [`duration`](#dom-mediasource-duration), then run the [duration
 change](#dfn-duration-change) algorithm with
 `new duration` set to the
 maximum of the current duration and the
 [`[[group end timestamp]]`](#dfn-group-end-timestamp).

::: header-wrapper
#### 5.5.9 [Coded Frame Removal]

Follow these steps when [coded
frames](#dfn-coded-frame) for a specific time range need to be
removed from the SourceBuffer:

1. Let `start` be the starting
 [presentation
 timestamp](#presentation-timestamp) for the removal range.

2. Let `end` be the end
 [presentation
 timestamp](#presentation-timestamp) for the removal range.

3. For each [track buffer](#track-buffer) in this
 [`SourceBuffer`](#dom-sourcebuffer), run the following
 steps:

 1. Let `remove end timestamp` be the current value of
 [`duration`](#dom-mediasource-duration)

 2. If this [track buffer](#track-buffer) has a [random access
 point](#random-access-point) timestamp that is
 greater than or equal to `end`, then update
 `remove end timestamp` to that random access point
 timestamp.

 ::::
 :::
 Note
 :::

 Random access point timestamps can be different across tracks
 because the dependencies between [coded
 frames](#dfn-coded-frame) within a track are
 usually different than the dependencies in another track.
 ::::

 3. Remove all media data, from this [track
 buffer](#track-buffer), that contain starting timestamps
 greater than or equal to `start`
 and less than the `remove end timestamp`.
 1. For each removed frame, if the frame has a [decode
 timestamp](#dfn-decode-timestamp) equal to the [last
 decode
 timestamp](#last-decode-timestamp) for the frame\'s
 track, run the following steps:

 If [`mode`](#dom-sourcebuffer-mode) equals \"[`segments`](#dom-appendmode-segments)\":
 : Set
 [`[[group end timestamp]]`](#dfn-group-end-timestamp) to [presentation
 timestamp](#presentation-timestamp).

 If [`mode`](#dom-sourcebuffer-mode) equals \"[`sequence`](#dom-appendmode-sequence)\":
 : Set
 [`[[group start timestamp]]`](#dfn-group-start-timestamp) equal to the
 [`[[group end timestamp]]`](#dfn-group-end-timestamp).

 2. Unset the [last decode
 timestamp](#last-decode-timestamp) on all [track
 buffers](#track-buffer).

 3. Unset the [last frame
 duration](#last-frame-duration) on all [track
 buffers](#track-buffer).

 4. Unset the [highest end
 timestamp](#highest-end-timestamp) on all [track
 buffers](#track-buffer).

 5. Set the [need random access point
 flag](#need-RAP-flag) on all [track
 buffers](#track-buffer) to true.

 4. Remove all possible decoding dependencies on the [coded
 frames](#dfn-coded-frame) removed in the
 previous step by removing all [coded
 frames](#dfn-coded-frame) from this [track
 buffer](#track-buffer) between those frames removed in the
 previous step and the next [random access
 point](#random-access-point) after those removed
 frames.

 ::::
 :::
 Note
 :::

 Removing all [coded
 frames](#dfn-coded-frame) until the next [random
 access
 point](#random-access-point) is a conservative
 estimate of the decoding dependencies since it assumes all
 frames between the removed frames and the next random access
 point depended on the frames that were removed.
 ::::

 5. If this object is in
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers), the [current playback
 position](https://html.spec.whatwg.org/multipage/media.html#current-playback-position)
 is greater than or equal to `start` and less than the
 `remove end timestamp`, and
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) is greater than
 [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata),
 then set the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) attribute to
 [`HAVE_METADATA`](https://html.spec.whatwg.org/multipage/media.html#dom-media-have_metadata)
 and stall playback.

 ::::
 :::
 Note
 :::

 Per
 [`HTMLMediaElement ready states`](https://html.spec.whatwg.org/multipage/media.html#ready-states)
 \[[HTML](#bib-html "HTML Standard")\] logic,
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`readyState`](#dom-readystate) changes may trigger events on the
 HTMLMediaElement.
 ::::

 ::::
 :::
 Note
 :::

 This transition occurs because media data for the current
 position has been removed. Playback cannot progress until media
 for the [current playback
 position](https://html.spec.whatwg.org/multipage/media.html#current-playback-position)
 is appended or the [3.15.5 Changes to selected/enabled track
 state](#active-source-buffer-changes).
 ::::

4. If the
 [`[[buffer full flag]]`](#dfn-buffer-full-flag) equals
 true and this object is ready to accept more bytes, then set the
 [`[[buffer full flag]]`](#dfn-buffer-full-flag) to
 false.

::: header-wrapper
#### 5.5.10 [Coded Frame Eviction]

This algorithm is run to free up space in this
[`SourceBuffer`](#dom-sourcebuffer) when new data is
appended.

1. Let `new data` equal the data
 that is about to be appended to this SourceBuffer.

 :::::
 :::
 [[Issue
 289]](https://github.com/w3c/media-source/issues/289)[:
 Editorial? Coded Frame eviction algorithm needs to note that
 \"buffer full flag\" may be updated immediately based on \|new
 data\|]
 :::

 :::
 Need to recognize step here that implementations *MAY* decide to set
 [`[[buffer full flag]]`](#dfn-buffer-full-flag) true
 here if it predicts that processing `new data` in addition to any existing bytes in
 [`[[input buffer]]`](#dfn-input-buffer) would
 exceed the capacity of the
 [`SourceBuffer`](#dom-sourcebuffer). Such a step enables
 more proactive push-back from implementations before accepting
 `new data` which would overflow
 resources, for example. In practice, at least one implementation
 already does this.
 :::
 :::::
2. If the
 [`[[buffer full flag]]`](#dfn-buffer-full-flag) equals
 false, then abort these steps.
3. Let `removal ranges`
 equal a list of presentation time ranges that can be evicted from
 the presentation to make room for the `new data`.

 ::::
 :::
 Note
 :::

 Implementations *MAY* use different methods for selecting
 `removal ranges` so web
 applications *SHOULD NOT* depend on a specific behavior. The web
 application can use the
 [`buffered`](#dom-sourcebuffer-buffered) attribute to observe whether portions
 of the buffered data have been evicted.
 ::::
4. For each range in `removal ranges`, run the [coded frame
 removal](#dfn-coded-frame-removal) algorithm with
 `start` and `end` equal to the removal range start
 and end timestamp respectively.

::: header-wrapper
#### 5.5.11 [Audio Splice Frame]

Follow these steps when the [coded frame
processing](#dfn-coded-frame-processing) algorithm needs to generate a
splice frame for two overlapping audio [coded
frames](#dfn-coded-frame):

1. Let `track buffer` be the [track
 buffer](#track-buffer) that will contain the splice.
2. Let `new coded frame` be the new [coded
 frame](#dfn-coded-frame), that is being added to
 `track buffer`, which triggered the need for a splice.
3. Let `presentation timestamp` be the
 [presentation
 timestamp](#presentation-timestamp) for
 `new coded frame`.
4. Let `decode timestamp` be the decode
 timestamp for `new coded frame`.
5. Let `frame duration` be the [coded
 frame
 duration](#dfn-coded-frame-duration) of
 `new coded frame`.
6. Let `overlapped frame` be the [coded
 frame](#dfn-coded-frame) in `track buffer` with a
 [presentation
 interval](#presentation-interval) that contains
 `presentation timestamp`.
7. Update `presentation timestamp` and
 `decode timestamp` to the nearest
 audio sample timestamp based on sample rate of the audio in
 `overlapped frame`. If a timestamp is equidistant from
 both audio sample timestamps, then use the higher timestamp (e.g.,
 `floor(x * sample_rate + 0.5) / sample_rate`).

 :::::
 :::
 Note
 :::

 :::
 For example, given the following values:

 - The [presentation
 timestamp](#presentation-timestamp) of
 `overlapped frame` equals 10.
 - The sample rate of `overlapped frame` equals 8000 Hz
 - `presentation timestamp` equals
 10.01255
 - `decode timestamp` equals 10.01255

 `presentation timestamp` and
 `decode timestamp` are updated to
 10.0125 since 10.01255 is closer to 10 + 100/8000 (10.0125) than
 10 + 101/8000 (10.012625)
 :::
 :::::
8. If the user agent does not support crossfading then run the
 following steps:
 1. Remove `overlapped frame` from
 `track buffer`.
 2. Add a silence frame to `track buffer` with the
 following properties:
 - The [presentation
 timestamp](#presentation-timestamp) set to the
 `overlapped frame` [presentation
 timestamp](#presentation-timestamp).
 - The [decode
 timestamp](#dfn-decode-timestamp) set to the
 `overlapped frame` [decode
 timestamp](#dfn-decode-timestamp).
 - The [coded frame
 duration](#dfn-coded-frame-duration) set to difference
 between `presentation timestamp` and the
 `overlapped frame` [presentation
 timestamp](#presentation-timestamp).

 ::::
 :::
 Note
 :::

 Some implementations *MAY* apply fades to/from silence to coded
 frames on either side of the inserted silence to make the
 transition less jarring.
 ::::
 3. Return to caller without providing a splice frame.

 ::::
 :::
 Note
 :::

 This is intended to allow `new coded frame` to be
 added to the `track buffer` as if
 `overlapped frame` had not been in the
 `track buffer` to begin with.
 ::::
9. Let `frame end timestamp` equal the
 sum of `presentation timestamp` and
 `frame duration`.
10. Let `splice end timestamp` equal the
 sum of `presentation timestamp` and
 the splice duration of 5 milliseconds.
11. Let `fade out coded frames` equal
 `overlapped frame` as well as any additional frames in
 `track buffer` that have a [presentation
 timestamp](#presentation-timestamp) greater than
 `presentation timestamp` and less than
 `splice end timestamp`.
12. Remove all the frames included in `fade out coded frames`
 from `track buffer`.
13. Return a splice frame with the following properties:
 - The [presentation
 timestamp](#presentation-timestamp) set to the
 `overlapped frame` [presentation
 timestamp](#presentation-timestamp).
 - The [decode
 timestamp](#dfn-decode-timestamp) set to the
 `overlapped frame` [decode
 timestamp](#dfn-decode-timestamp).
 - The [coded frame
 duration](#dfn-coded-frame-duration) set to difference
 between `frame end timestamp` and
 the `overlapped frame` [presentation
 timestamp](#presentation-timestamp).
 - The fade out coded frames equals
 `fade out coded frames`.
 - The fade in coded frame equals `new coded frame`.

 ::::
 :::
 Note
 :::

 If the `new coded frame` is less than 5 milliseconds in
 duration, then coded frames that are appended after the
 `new coded frame` will be needed to properly render the
 splice.
 ::::
 - The splice timestamp equals `presentation timestamp`.

 ::::
 :::
 Note
 :::

 See the [audio splice
 rendering](#dfn-audio-splice-rendering) algorithm for details on
 how this splice frame is rendered.
 ::::

::: header-wrapper
#### 5.5.12 [Audio Splice Rendering]

The following steps are run when a spliced frame, generated by the
[audio splice
frame](#dfn-audio-splice-frame) algorithm, needs to be
rendered by the media element:

1. Let `fade out coded frames` be the [coded
 frames](#dfn-coded-frame) that are faded out during the splice.
2. Let `fade in coded frames` be the [coded
 frames](#dfn-coded-frame) that are faded in during the splice.
3. Let `presentation timestamp` be the
 [presentation
 timestamp](#presentation-timestamp) of the first coded frame
 in `fade out coded frames`.
4. Let `end timestamp` be the sum of the
 [presentation
 timestamp](#presentation-timestamp) and the [coded frame
 duration](#dfn-coded-frame-duration) of the last frame in
 `fade in coded frames`.
5. Let `splice timestamp` be the
 [presentation
 timestamp](#presentation-timestamp) where the splice starts.
 This corresponds with the [presentation
 timestamp](#presentation-timestamp) of the first frame in
 `fade in coded frames`.
6. Let `splice end timestamp` equal
 `splice timestamp` plus five
 milliseconds.
7. Let `fade out samples` be the samples generated by
 decoding `fade out coded frames`.
8. Trim `fade out samples` so that it only contains samples
 between `presentation timestamp` and
 `splice end timestamp`.
9. Let `fade in samples` be the samples generated by
 decoding `fade in coded frames`.
10. If `fade out samples` and `fade in samples` do
 not have a common sample rate and channel layout, then convert
 `fade out samples` and `fade in samples` to a
 common sample rate and channel layout.
11. Let `output samples` be a buffer to hold the output
 samples.
12. Apply a linear gain fade out with a starting gain of 1 and an ending
 gain of 0 to the samples between `splice timestamp` and `splice end timestamp` in `fade out samples`.
13. Apply a linear gain fade in with a starting gain of 0 and an ending
 gain of 1 to the samples between `splice timestamp` and `splice end timestamp` in `fade in samples`.
14. Copy samples between `presentation timestamp` to `splice timestamp` from `fade out samples` into
 `output samples`.
15. For each sample between `splice timestamp` and `splice end timestamp`, compute the sum of a sample from
 `fade out samples` and the corresponding sample in
 `fade in samples` and store the result in
 `output samples`.
16. Copy samples between `splice end timestamp` to `end timestamp`
 from `fade in samples` into `output samples`.
17. Render `output samples`.

Here is a graphical representation of this algorithm.

![Audio splice diagram](audio_splice.png)

::: header-wrapper
#### 5.5.13 [Text Splice Frame]

Follow these steps when the [coded frame
processing](#dfn-coded-frame-processing) algorithm needs to generate a
splice frame for two overlapping timed text [coded
frames](#dfn-coded-frame):

1. Let `track buffer` be the [track
 buffer](#track-buffer) that will contain the splice.
2. Let `new coded frame` be the new [coded
 frame](#dfn-coded-frame), that is being added to
 `track buffer`, which triggered the need for a splice.
3. Let `presentation timestamp` be the
 [presentation
 timestamp](#presentation-timestamp) for
 `new coded frame`
4. Let `decode timestamp` be the decode
 timestamp for `new coded frame`.
5. Let `frame duration` be the [coded
 frame
 duration](#dfn-coded-frame-duration) of
 `new coded frame`.
6. Let `frame end timestamp` equal the
 sum of `presentation timestamp` and
 `frame duration`.
7. Let `first overlapped frame` be the [coded
 frame](#dfn-coded-frame) in `track buffer` with a
 [presentation
 interval](#presentation-interval) that contains
 `presentation timestamp`.
8. Let `overlapped presentation timestamp` be the [presentation
 timestamp](#presentation-timestamp) of the
 `first overlapped frame`.
9. Let `overlapped frames` equal
 `first overlapped frame` as well as any additional frames
 in `track buffer` that have a [presentation
 timestamp](#presentation-timestamp) greater than
 `presentation timestamp` and less than
 `frame end timestamp`.
10. Remove all the frames included in `overlapped frames`
 from `track buffer`.
11. Update the [coded frame
 duration](#dfn-coded-frame-duration) of the
 `first overlapped frame` to
 `presentation timestamp` minus
 `overlapped presentation timestamp`.
12. Add `first overlapped frame` to the
 `track buffer`.
13. Return to caller without providing a splice frame.

 ::::
 :::
 Note
 :::

 This is intended to allow `new coded frame` to be added
 to the `track buffer` as if it hadn\'t overlapped any
 frames in `track buffer` to begin with.
 ::::

::: header-wrapper
## 6. [`SourceBufferList`] interface

[`SourceBufferList`](#dom-sourcebufferlist) is a simple
container object for
[`SourceBuffer`](#dom-sourcebuffer) objects. It provides read-only array
access and fires events when the list is modified.

```
WebIDL[Exposed=(Window,DedicatedWorker)]
interface SourceBufferList : EventTarget {
 readonly attribute unsigned long length;

 attribute EventHandler onaddsourcebuffer;
 attribute EventHandler onremovesourcebuffer;

 getter SourceBuffer (unsigned long index);
};
```

::: header-wrapper
### 6.1 Attributes

[`length`] of type [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Indicates the number of
 [`SourceBuffer`](#dom-sourcebuffer) objects in the list.

[`onaddsourcebuffer`] of type [`EventHandler`](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: The event handler for the
 [`addsourcebuffer`](#dfn-addsourcebuffer) event.

[`onremovesourcebuffer`] of type [`EventHandler`](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: The event handler for the
 [`removesourcebuffer`](#dfn-removesourcebuffer) event.

::: header-wrapper
### 6.2 Methods

[getter]

: Allows the SourceBuffer objects in the list to be accessed with an
 array operator (i.e., \[\]).

 When this method is invoked, the user agent must run the following
 steps:

 1. If `index` is greater than
 or equal to the
 [`length`](#dom-sourcebufferlist-length) attribute then return undefined
 and abort these steps.
 2. Return the `index`\'th
 [`SourceBuffer`](#dom-sourcebuffer) object in the
 list.

::: header-wrapper
### 6.3 Event Summary

Event name Interface Dispatched when\...
 -------------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------
 [addsourcebuffer] [`Event`](https://dom.spec.whatwg.org/#event) When a [`SourceBuffer`](#dom-sourcebuffer) is added to the list.
 [removesourcebuffer] [`Event`](https://dom.spec.whatwg.org/#event) When a [`SourceBuffer`](#dom-sourcebuffer) is removed from the list.

::: header-wrapper
## 7. [`ManagedMediaSource`] interface

[`ManagedMediaSource`](#dom-managedmediasource) is a
[`MediaSource`](#dom-mediasource) that actively manages its
memory content. Unlike a
[`MediaSource`](#dom-mediasource), the [user
agent](https://infra.spec.whatwg.org/#user-agent) can
evict content through the [memory
cleanup](#dfn-memory-cleanup) algorithm from its
[`sourceBuffers`](#dom-mediasource-sourcebuffers) (populated with
[`ManagedSourceBuffer`](#dom-managedsourcebuffer)) for any reason.

Note[: Eviction reasons]

Reasons that the user agent might evict content are implementation
specific and can include, but are not limited to, memory and/or hardware
limitations, change in environmental conditions, and so on. Developers
shouldn\'t make assumptions as to why, how, or when a user agent might
evict content. Instead, developers need to write scripts with the
assumption that content is constantly and randomly being evicted to
avoid stalled video playback (i.e., code defensibly and listen for the
[`bufferedchange`](#dfn-bufferedchange) event!).

```
WebIDL[Exposed=(Window,DedicatedWorker)]
interface ManagedMediaSource : MediaSource {
 constructor();
 readonly attribute boolean streaming;
 attribute EventHandler onstartstreaming;
 attribute EventHandler onendstreaming;
};
```

::: header-wrapper
### 7.1 Attributes

[`streaming`]

: On getting:

 1. Return the current value of the attribute.

::: header-wrapper
### 7.2 Event Summary

Event name Interface Dispatched when\...
 ------------------------------------------------------------------------------------------------------------------ --------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 [startstreaming] [`Event`](https://dom.spec.whatwg.org/#event) A [`ManagedMediaSource`](#dom-managedmediasource)\'s [`streaming`](#dom-managedmediasource-streaming) attribute changed from `false` to `true`.
 [endstreaming] [`Event`](https://dom.spec.whatwg.org/#event) A [`ManagedMediaSource`](#dom-managedmediasource)\'s [`streaming`](#dom-managedmediasource-streaming) attribute changed from `true` to `false`.

::: header-wrapper
### 7.3 Algorithms

::: header-wrapper
#### 7.3.1 `ManagedSourceBuffer` Monitoring

The following steps are run periodically, whenever the [SourceBuffer
Monitoring](#dfn-sourcebuffer-monitoring) algorithm is scheduled to run.

Having [enough managed data to ensure uninterrupted
playback] is an implementation
defined condition where the user agent determines that it currently has
enough data to play the presentation without stalling for a meaningful
period of time. This condition is constantly evaluated to determine when
to transition the value of
[`streaming`](#dom-managedmediasource-streaming). These transitions indicate when the user
agent believes it has enough data buffered or it needs more data
respectively.

Being [able to retrieve and buffer data in an efficient
way] is an implementation
defined condition where the user agent determines that it can fetch new
data in an energy efficient manner while able to achieve the desired
memory usage.

1. Run the
 [`MediaSource`](#dom-mediasource) [SourceBuffer
 Monitoring](#dfn-sourcebuffer-monitoring) algorithm.
2. Let `can play uninterrupted and efficiently` be a flag
 that is true if the
 [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered)
 attribute contains a
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) that includes the current playback position and
 [enough managed data to ensure uninterrupted
 playback](#dfn-enough-managed-data-to-ensure-uninterrupted-playback) and is [able to retrieve
 and buffer data in an efficient
 way](#dfn-able-to-retrieve-and-buffer-data-in-an-efficient-way)

 If `can play uninterrupted and efficiently` is not equal to [`streaming`](#dom-managedmediasource-streaming), [queue an element task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-an-element-task) on the [media element](https://html.spec.whatwg.org/multipage/media.html#media-element) that runs the following steps:

 : 1. Set
 [this](https://webidl.spec.whatwg.org/#this)
 [`streaming`](#dom-managedmediasource-streaming) attribute to
 `can play uninterrupted and efficiently`.
 2. If `can play uninterrupted and efficiently` is
 false [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 called
 [`startstreaming`](#dfn-startstreaming) at the
 [`ManagedMediaSource`](#dom-managedmediasource).
 3. Otherwise, [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 called
 [`endstreaming`](#dfn-endstreaming) at the
 [`ManagedMediaSource`](#dom-managedmediasource).

::: header-wrapper
#### 7.3.2 [Memory Cleanup]

1.

 For each `buffer` in [this](https://webidl.spec.whatwg.org/#this)\'s [`sourceBuffers`](#dom-mediasource-sourcebuffers):

 : 1. Run the `buffer`\'s [memory
 cleanup](#dfn-memory-cleanup-0) algorithm.

::: header-wrapper
## 8. [`BufferedChangeEvent`] interface

```
WebIDL[Exposed=(Window,DedicatedWorker)]
interface BufferedChangeEvent : Event {
 constructor(DOMString type, optional BufferedChangeEventInit eventInitDict = );

 [SameObject] readonly attribute TimeRanges addedRanges;
 [SameObject] readonly attribute TimeRanges removedRanges;
};

dictionary BufferedChangeEventInit : EventInit {
 TimeRanges addedRanges;
 TimeRanges removedRanges;
};
```

::: header-wrapper
### 8.1 Attributes

[`addedRanges`]
: The time ranges added between the last
 [`updatestart`](#dfn-updatestart) and
 [`updateend`](#dfn-updateend) events (which would have occurred
 during the last run of the [coded frame
 processing](#dfn-coded-frame-processing) algorithm).

[`removedRanges`]
: The time ranges removed between the last `updatestart` and
 `updateend` events (which would have occurred during the last run of
 the [coded frame
 removal](#dfn-coded-frame-removal) or [coded frame
 eviction](#dfn-coded-frame-eviction) algorithm or if the user
 agent evicted content in response to a [memory
 cleanup](#dfn-memory-cleanup-0)).

::: header-wrapper
## 9. [`ManagedSourceBuffer`] interface

```
WebIDL[Exposed=(Window,DedicatedWorker)]
interface ManagedSourceBuffer : SourceBuffer {
 attribute EventHandler onbufferedchange;
};
```

::: header-wrapper
### 9.1 Attributes

[`onbufferedchange`]

: An [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
 whose [event handler event
 type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type)
 is
 [`bufferedchange`](#dfn-bufferedchange).

::: header-wrapper
### 9.2 Event Summary

Event name Interface Dispatched when\...
 ------------------------------------------------------------------------------------------------------------------ --------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 [bufferedchange] [`BufferedChangeEvent`](#dom-bufferedchangeevent) The [`ManagedSourceBuffer`](#dom-managedsourcebuffer)\'s buffered range changed following a call to [`appendBuffer`](#dom-sourcebuffer-appendbuffer)`()`, [`remove`](#dom-sourcebuffer-remove)`()`, [`endOfStream`](#dom-mediasource-endofstream)`()`, or as a consequence of the user agent running the [memory cleanup](#dfn-memory-cleanup-0) algorithm.

::: header-wrapper
### 9.3 Algorithms

::: header-wrapper
#### 9.3.1 Buffered Change

The following steps are run at the completion of all operations to the
[`ManagedSourceBuffer`](#dom-managedsourcebuffer)
`buffer` that would cause a
`buffer`\'s
[`buffered`](#dom-sourcebuffer-buffered) to change. That is once
[`appendBuffer`](#dom-sourcebuffer-appendbuffer)`()`,
[`remove`](#dom-sourcebuffer-remove)`()` or [memory
cleanup](#dfn-memory-cleanup-0) algorithm have completed.

1. Let `previous buffered ranges` equal the
 [`buffered`](#dom-sourcebuffer-buffered) attribute before the changes occurred.
2. Let `new buffered ranges` equal the new
 [`buffered`](#dom-sourcebuffer-buffered)
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges).
3. Let `added` equal the
 `previous buffered ranges` subtracted from `new buffered ranges`.
4. Let `removed` equal the
 `new buffered ranges` subtracted from
 `previous buffered ranges`.
5. Let `eventInitDict` be a new
 [`BufferedChangeEventInit`](#dom-bufferedchangeeventinit)
 dictionary initialized with `added` as its
 [`addedRanges`](#dom-bufferedchangeeventinit-addedranges) and `removed` as its
 [`removedRanges`](#dom-bufferedchangeeventinit-removedranges)
6. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named
 [`bufferedchange`](#dfn-bufferedchange) at
 `buffer` using the
 [`BufferedChangeEvent`](#dom-bufferedchangeevent) interface,
 initialized with `eventInitDict`.

::: header-wrapper
#### 9.3.2 [Memory cleanup]

1.

 If [this](https://webidl.spec.whatwg.org/#this) is not in [this](https://webidl.spec.whatwg.org/#this)\'s [`ManagedMediaSource`](#dom-managedmediasource) parent [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers):

 : 1. Run the [coded frame
 removal](#dfn-coded-frame-removal) algorithm with
 start set to 0, end set to positive infinity, and abort
 these steps.

2. Let `removal ranges`
 equal a list of presentation time ranges that can be evicted from
 the presentation to ensure uninterrupted playback from
 [`currentTime`](https://html.spec.whatwg.org/multipage/media.html#dom-media-currenttime)
 until such presentation could be retrieved again.

 ::::
 :::
 Note
 :::

 Implementations can use different strategies for selecting
 `removal ranges` so web
 applications shouldn\'t depend on a specific behavior. The web
 application would listen to the
 [`bufferedchange`](#dfn-bufferedchange) event to observe
 whether portions of the buffered data have been evicted.
 ::::

3. For each range in `removal ranges`, run the [coded frame
 removal](#dfn-coded-frame-removal) algorithm with
 `start` and `end` equal to the removal range start
 and end timestamp respectively.

::: header-wrapper
## 10. HTMLMediaElement Extensions

This section specifies what existing
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`seekable`](https://html.spec.whatwg.org/multipage/media.html#dom-media-seekable)
and
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered)
attributes on the
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) *MUST* return when a
[`MediaSource`](#dom-mediasource) is attached to the
element, and what the existing
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject)
attribute *MUST* also do when it is set to be a
[`MediaSourceHandle`](#dom-mediasourcehandle) object.

::: header-wrapper
### 10.1 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s [`seekable`](https://html.spec.whatwg.org/multipage/media.html#dom-media-seekable)

[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`seekable`](https://html.spec.whatwg.org/multipage/media.html#dom-media-seekable)
attribute returns a new static [normalized TimeRanges
object](https://html.spec.whatwg.org/multipage/media.html#normalised-timeranges-object)
created based on the following steps:

1. If the
 [`MediaSource`](#dom-mediasource) was constructed in a
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope) that is terminated or is closing
 then return an empty
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) object and abort these steps.

 ::::
 :::
 Note
 :::

 This case is intended to handle implementations that may no longer
 maintain any previous information about buffered or seekable media
 in a MediaSource that was constructed in a
 DedicatedWorkerGlobalScope that has been terminated by
 [`terminate`](https://html.spec.whatwg.org/multipage/workers.html#dom-worker-terminate)`()` or user agent execution of [terminate a
 worker](https://html.spec.whatwg.org/multipage/workers.html#terminate-a-worker)
 for the MediaSource\'s DedicatedWorkerGlobalScope, for instance as
 the eventual result of
 [`close`](https://html.spec.whatwg.org/multipage/workers.html#dom-dedicatedworkerglobalscope-close)`()` execution.
 ::::

 :::::
 :::
 [[Issue
 277]](https://github.com/w3c/media-source/issues/277)[:
 MSE-in-Workers: Consider (eventually) transitioning attached element
 to error upon termination of MediaSource\'s worker/what should media
 element do?
 [mse-in-workers](https://github.com/w3c/media-source/issues/?q=is%3Aissue+is%3Aopen+label%3A%22mse-in-workers%22)]
 :::

 :::
 Should there be some (eventual) media element error transition in
 the case of an attached worker MediaSource having its context
 destroyed? The experimental Chromium implementation of worker MSE
 just keeps the element readyState, networkState and error the same
 as prior to that context destruction, though the seekable and
 buffered attributes each report an empty TimeRange.
 :::
 :::::

2. Let `recent duration` and
 `recent live seekable range` respectively be the recent values of
 [`duration`](#dom-mediasource-duration) and
 [`[[live seekable range]]`](#dfn-live-seekable-range),
 determined as follows:

 If the [`MediaSource`](#dom-mediasource) was constructed in a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)
 : Set `recent duration`
 to be
 [`duration`](#dom-mediasource-duration) and set
 `recent live seekable range` to be
 [`[[live seekable range]]`](#dfn-live-seekable-range).

 Otherwise:
 : Set `recent duration`
 and `recent live seekable range` respectively to be what the
 [`duration`](#dom-mediasource-duration) and
 [`[[live seekable range]]`](#dfn-live-seekable-range)
 were recently, updated by handling implicit messages posted by
 the
 [`MediaSource`](#dom-mediasource) to its
 [`[[port to main]]`](#dfn-port-to-main) on
 every change to
 [`duration`](#dom-mediasource-duration) or
 [`[[live seekable range]]`](#dfn-live-seekable-range).

3.

 If `recent duration` equals NaN:
 : Return an empty
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) object.

 If `recent duration` equals positive Infinity:

 : 1. If `recent live seekable range` is not empty:
 1. Let `union ranges` be the union of
 `recent live seekable range` and the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered)
 attribute.
 2. Return a single range with a start time equal to the
 earliest start time in `union ranges` and an end time equal
 to the highest end time in `union ranges` and
 abort these steps.
 2. If the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered)
 attribute returns an empty
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) object, then return an empty
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) object and abort these steps.
 3. Return a single range with a start time of 0 and an end time
 equal to the highest end time reported by the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
 [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered)
 attribute.

 Otherwise:
 : Return a single range with a start time of 0 and an end time
 equal to `recent duration`.

::: header-wrapper
### 10.2 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s [`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered)

[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`buffered`](https://html.spec.whatwg.org/multipage/media.html#dom-media-buffered)
attribute returns a static [normalized TimeRanges
object](https://html.spec.whatwg.org/multipage/media.html#normalised-timeranges-object)
based on the following steps.

1. If the
 [`MediaSource`](#dom-mediasource) was constructed in a
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope) that is terminated or is closing
 then return an empty
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) object and abort these steps.

 ::::
 :::
 Note
 :::

 This case is intended to handle implementations that may no longer
 maintain any previous information about buffered or seekable media
 in a MediaSource that was constructed in a
 DedicatedWorkerGlobalScope that has been terminated by
 [`terminate`](https://html.spec.whatwg.org/multipage/workers.html#dom-worker-terminate)`()` or user agent execution of [terminate a
 worker](https://html.spec.whatwg.org/multipage/workers.html#terminate-a-worker)
 for the MediaSource\'s DedicatedWorkerGlobalScope, for instance as
 the eventual result of
 [`close`](https://html.spec.whatwg.org/multipage/workers.html#dom-dedicatedworkerglobalscope-close)`()` execution.
 ::::

 :::::
 :::
 [[Issue
 277]](https://github.com/w3c/media-source/issues/277)[:
 MSE-in-Workers: Consider (eventually) transitioning attached element
 to error upon termination of MediaSource\'s worker/what should media
 element do?
 [mse-in-workers](https://github.com/w3c/media-source/issues/?q=is%3Aissue+is%3Aopen+label%3A%22mse-in-workers%22)]
 :::

 :::
 Should there be some (eventual) media element error transition in
 the case of an attached worker MediaSource having its context
 destroyed? The experimental Chromium implementation of worker MSE
 just keeps the element readyState, networkState and error the same
 as prior to that context destruction, though the seekable and
 buffered attributes each report an empty TimeRange.
 :::
 :::::
2. Let `recent intersection ranges` be determined as follows:

 If the [`MediaSource`](#dom-mediasource) was constructed in a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)

 : 1. Let `recent intersection ranges` equal an empty
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) object.
 2. If
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers).length does not equal 0 then
 run the following steps:
 1. Let `active ranges` be the
 ranges returned by
 [`buffered`](#dom-sourcebuffer-buffered) for each
 [`SourceBuffer`](#dom-sourcebuffer) object
 in
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers).
 2. Let `highest end time` be the largest range
 end time in the `active ranges`.
 3. Let `recent intersection ranges` equal a
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) object containing a single range from 0
 to `highest end time`.
 4. For each
 [`SourceBuffer`](#dom-sourcebuffer) object
 in
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers) run the following steps:
 1. Let `source ranges` equal the ranges
 returned by the
 [`buffered`](#dom-sourcebuffer-buffered) attribute on the
 current
 [`SourceBuffer`](#dom-sourcebuffer).
 2. If
 [`readyState`](#dom-mediasource-readystate) is
 \"[`ended`](#dom-readystate-ended)\", then set the end
 time on the last range in `source ranges` to
 `highest end time`.
 3. Let `new intersection ranges` equal the
 intersection between the
 `recent intersection ranges` and the
 `source ranges`.
 4. Replace the ranges in
 `recent intersection ranges` with the
 `new intersection ranges`.

 Otherwise:
 : Let `recent intersection ranges` be the
 [`TimeRanges`](https://html.spec.whatwg.org/multipage/media.html#timeranges) resulting from the steps for the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) case, but run with the
 [`MediaSource`](#dom-mediasource) and its
 [`SourceBuffer`](#dom-sourcebuffer) objects in their
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope) and communicated by using
 [`[[port to main]]`](#dfn-port-to-main)
 implicit messages on every update to the
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers),
 [`readyState`](#dom-mediasource-readystate), or any of the buffering state
 that would change any of the values of each of those
 [`buffered`](#dom-sourcebuffer-buffered) attributes of the
 [`activeSourceBuffers`](#dom-mediasource-activesourcebuffers).
 ::::
 :::
 Note
 :::

 The overhead of recalculating and communicating
 `recent intersection ranges` so frequently is one reason
 for allowing implementation flexibility to query this
 information on-demand using other mechanisms such as shared
 memory and locks as mentioned in [cross-context communication
 model](#dfn-cross-context-communication-model).
 ::::
3. If the current value of this attribute has not been set by this
 algorithm or `recent intersection ranges` does not
 contain the exact same range information as the current value of
 this attribute, then update the current value of this attribute to
 `recent intersection ranges`.
4. Return the current value of this attribute.

::: header-wrapper
### 10.3 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s [`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject)

If a
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject)
attribute is assigned a
[`MediaSourceHandle`](#dom-mediasourcehandle), then set
[`[[has ever been assigned as srcobject]]`](#dfn-has-ever-been-assigned-as-srcobject) for that
[`MediaSourceHandle`](#dom-mediasourcehandle) to true as part of
the synchronous steps of the extended
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s
[`srcObject`](https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject)
setter that occur before invoking the element\'s load algorithm.

This prevents transferring that
[`MediaSourceHandle`](#dom-mediasourcehandle) object ever again,
enabling clear synchronous exception if that is attempted.

[`MediaSourceHandle`](#dom-mediasourcehandle) needs to be added
to
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)\'s MediaProvider IDL typedef and related text
involving media provider objects.

::: header-wrapper
## 11. `AudioTrack` extensions

This section specifies extensions to the
\[[HTML](#bib-html "HTML Standard")\]
[`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack) definition.

```
WebIDL[Exposed=(Window,DedicatedWorker)]
partial interface AudioTrack {
 readonly attribute SourceBuffer? sourceBuffer;
};
```

[[Issue
280]](https://github.com/w3c/media-source/issues/280)[:
MSE-in-Workers: {Audio,Video,Text}Track{,List} IDL in HTML need
additional DedicatedWorker in Exposed
[mse-in-workers](https://github.com/w3c/media-source/issues/?q=is%3Aissue+is%3Aopen+label%3A%22mse-in-workers%22)]

\[[HTML](#bib-html "HTML Standard")\]
[`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack) needs Window+DedicatedWorker exposure.

::: header-wrapper
### Attributes

[`sourceBuffer`] of type [[`SourceBuffer`](#dom-sourcebuffer)], readonly , nullable

: On getting, run the following step:

 If this track was created by a [`SourceBuffer`](#dom-sourcebuffer) that was created on the same [realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-global-object-realm) as this track, and if that [`SourceBuffer`](#dom-sourcebuffer) has not been removed from the [`sourceBuffers`](#dom-mediasource-sourcebuffers) attribute of its [parent media source](#parent-media-source):
 : Return the
 [`SourceBuffer`](#dom-sourcebuffer) that created
 this track.

 Otherwise:
 : Return null.

 :::::
 :::
 Note
 :::

 :::
 For example, if a
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)
 [`SourceBuffer`](#dom-sourcebuffer) notified its
 internal `create track mirror` handler in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) to create this track, then the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) copy of the track would return null for this attribute.
 :::
 :::::

::: header-wrapper
## 12. `VideoTrack` extensions

This section specifies extensions to the
\[[HTML](#bib-html "HTML Standard")\]
[`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack) definition.

```
WebIDL[Exposed=(Window,DedicatedWorker)]
partial interface VideoTrack {
 readonly attribute SourceBuffer? sourceBuffer;
};
```

[[Issue
280]](https://github.com/w3c/media-source/issues/280)[:
MSE-in-Workers: {Audio,Video,Text}Track{,List} IDL in HTML need
additional DedicatedWorker in Exposed
[mse-in-workers](https://github.com/w3c/media-source/issues/?q=is%3Aissue+is%3Aopen+label%3A%22mse-in-workers%22)]

\[[HTML](#bib-html "HTML Standard")\]
[`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack) needs Window+DedicatedWorker exposure.

::: header-wrapper
### Attributes

[`sourceBuffer`] of type [[`SourceBuffer`](#dom-sourcebuffer)], readonly , nullable

: On getting, run the following step:

 If this track was created by a [`SourceBuffer`](#dom-sourcebuffer) that was created on the same [realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-global-object-realm) as this track, and if that [`SourceBuffer`](#dom-sourcebuffer) has not been removed from the [`sourceBuffers`](#dom-mediasource-sourcebuffers) attribute of its [parent media source](#parent-media-source):
 : Return the
 [`SourceBuffer`](#dom-sourcebuffer) that created
 this track.

 Otherwise:
 : Return null.

 :::::
 :::
 Note
 :::

 :::
 For example, if a
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)
 [`SourceBuffer`](#dom-sourcebuffer) notified its
 internal `create track mirror` handler in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) to create this track, then the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) copy of the track would return null for this attribute.
 :::
 :::::

::: header-wrapper
## 13. `TextTrack` extensions

This section specifies extensions to the
\[[HTML](#bib-html "HTML Standard")\]
[`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) definition.

```
WebIDL[Exposed=(Window,DedicatedWorker)]
partial interface TextTrack {
 readonly attribute SourceBuffer? sourceBuffer;
};
```

[[Issue
280]](https://github.com/w3c/media-source/issues/280)[:
MSE-in-Workers: {Audio,Video,Text}Track{,List} IDL in HTML need
additional DedicatedWorker in Exposed
[mse-in-workers](https://github.com/w3c/media-source/issues/?q=is%3Aissue+is%3Aopen+label%3A%22mse-in-workers%22)]

\[[HTML](#bib-html "HTML Standard")\]
[`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) needs Window+DedicatedWorker exposure.

::: header-wrapper
### Attributes

[`sourceBuffer`] of type [[`SourceBuffer`](#dom-sourcebuffer)], readonly , nullable

: On getting, run the following step:

 If this track was created by a [`SourceBuffer`](#dom-sourcebuffer) that was created on the same [realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-global-object-realm) as this track, and if that [`SourceBuffer`](#dom-sourcebuffer) has not been removed from the [`sourceBuffers`](#dom-mediasource-sourcebuffers) attribute of its [parent media source](#parent-media-source):
 : Return the
 [`SourceBuffer`](#dom-sourcebuffer) that created
 this track.

 Otherwise:
 : Return null.

 :::::
 :::
 Note
 :::

 :::
 For example, if a
 [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope)
 [`SourceBuffer`](#dom-sourcebuffer) notified its
 internal `create track mirror` handler in
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) to create this track, then the
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) copy of the track would return null for this attribute.
 :::
 :::::

::: header-wrapper
## 14. [Byte Stream Formats]

The bytes provided through
[`appendBuffer`](#dom-sourcebuffer-appendbuffer)`()` for a
[`SourceBuffer`](#dom-sourcebuffer) form a logical byte
stream. The format and semantics of these byte streams are defined in
[byte stream format specifications]. The byte stream format registry
\[[MSE-REGISTRY](#bib-mse-registry "Media Source Extensions™ Byte Stream Format Registry")\] provides mappings between a MIME type that may be
passed to
[`addSourceBuffer`](#dom-mediasource-addsourcebuffer)`()`,
[`isTypeSupported`](#dom-mediasource-istypesupported)`()` or
[`changeType`](#dom-sourcebuffer-changetype)`()` and the byte stream
format expected by a
[`SourceBuffer`](#dom-sourcebuffer) using that MIME type for
parsing newly appended data. Implementations are encouraged to register
mappings for byte stream formats they support to facilitate
interoperability. The byte stream format registry
\[[MSE-REGISTRY](#bib-mse-registry "Media Source Extensions™ Byte Stream Format Registry")\] is the authoritative source for these mappings. If
an implementation claims to support a MIME type listed in the registry,
its [`SourceBuffer`](#dom-sourcebuffer) implementation *MUST*
conform to the [byte stream format
specification](#byte-stream-format-specs) listed in the registry entry.

The byte stream format specifications in the registry are not intended
to define new storage formats. They simply outline the subset of
existing storage format structures that implementations of this
specification will accept.

Byte stream format parsing and validation is implemented in the [segment
parser
loop](#dfn-segment-parser-loop) algorithm.

This section provides general requirements for all byte stream format
specifications:

- A byte stream format specification *MUST* define [initialization
 segments](#dfn-initialization-segment) and [media
 segments](#dfn-media-segment).

- A byte stream format *SHOULD* provide references for sourcing
 [`AudioTrack`](https://html.spec.whatwg.org/multipage/media.html#audiotrack),
 [`VideoTrack`](https://html.spec.whatwg.org/multipage/media.html#videotrack), and
 [`TextTrack`](https://html.spec.whatwg.org/multipage/media.html#texttrack) attribute values from data in [initialization
 segments](#dfn-initialization-segment).

 ::::
 :::
 Note
 :::

 If the byte stream format covers a format similar to one covered in
 the in-band tracks spec
 \[[INBANDTRACKS](#bib-inbandtracks "Sourcing In-band Media Resource Tracks from Media Containers into HTML")\], then it *SHOULD* try to use the same attribute
 mappings so that Media Source Extensions playback and non-Media Source
 Extensions playback provide the same track information.
 ::::

- It *MUST* be possible to identify segment boundaries and segment type
 (initialization or media) by examining the byte stream alone.

- The user agent *MUST* run the [append
 error](#dfn-append-error) algorithm when any of the following
 conditions are met:
 1. The number and type of tracks are not consistent.

 ::::
 :::
 Note
 :::

 For example, if the first [initialization
 segment](#dfn-initialization-segment) has 2 audio tracks and 1
 video track, then all [initialization
 segments](#dfn-initialization-segment) that follow it in the
 byte stream *MUST* describe 2 audio tracks and 1 video track.
 ::::

 2. [Track IDs](#dfn-track-id) are not the same across
 [initialization
 segments](#dfn-initialization-segment), for segments describing
 multiple tracks of a single type (e.g., 2 audio tracks).

 3. Unsupported codec changes occur across [initialization
 segments](#dfn-initialization-segment).

 ::::
 :::
 Note
 :::

 See the [initialization segment
 received](#dfn-initialization-segment-received) algorithm,
 [`addSourceBuffer`](#dom-mediasource-addsourcebuffer)`()` and
 [`changeType`](#dom-sourcebuffer-changetype)`()` for details
 and examples of codec changes.
 ::::

- The user agent *MUST* support the following:
 1. [Track IDs](#dfn-track-id) changing across [initialization
 segments](#dfn-initialization-segment) if the segments describe
 only one track of each type.

 2. Video frame size changes. The user agent *MUST* support seamless
 playback.

 ::::
 :::
 Note
 :::

 This will cause the \<video\> display region to change size if the
 web application does not use CSS or HTML attributes (width/height)
 to constrain the element size.
 ::::

 3. Audio channel count changes. The user agent *MAY* support this
 seamlessly and could trigger downmixing.

 ::::
 :::
 Note
 :::

 This is a quality of implementation issue because changing the
 channel count may require reinitializing the audio device,
 resamplers, and channel mixers which tends to be audible.
 ::::

- The following rules apply to all [media
 segments](#dfn-media-segment) within a byte stream. A user
 agent *MUST*:
 1. Map all timestamps to the same [media
 timeline](https://html.spec.whatwg.org/multipage/media.html#media-timeline).
 2. Support seamless playback of [media
 segments](#dfn-media-segment) having a timestamp gap
 smaller than the audio frame size. User agents *MUST NOT* reflect
 these gaps in the
 [`buffered`](#dom-sourcebuffer-buffered) attribute.

 ::::
 :::
 Note
 :::

 This is intended to simplify switching between audio streams where
 the frame boundaries don\'t always line up across encodings (e.g.,
 Vorbis).
 ::::

- The user agent *MUST* run the [append
 error](#dfn-append-error) algorithm when any combination of an
 [initialization
 segment](#dfn-initialization-segment) and any contiguous sequence
 of [media segments](#dfn-media-segment) satisfies the following
 conditions:

 1. The number and type (audio, video, text, etc.) of all tracks in
 the [media
 segments](#dfn-media-segment) are not identified.
 2. The decoding capabilities needed to decode each track (i.e., codec
 and codec parameters) are not provided.
 3. Encryption parameters necessary to decrypt the content (except the
 encryption key itself) are not provided for all encrypted tracks.
 4. All information necessary to decode and render the earliest
 [random access
 point](#random-access-point) in the sequence of
 [media segments](#dfn-media-segment) and all subsequence
 samples in the sequence (in presentation time) are not provided.
 This includes in particular,
 - Information that determines the [intrinsic width and
 height](https://html.spec.whatwg.org/multipage/media.html#concept-video-intrinsic-width)
 of the video (specifically, this requires either the picture or
 pixel aspect ratio, together with the encoded resolution).
 - Information necessary to convert the video decoder output to a
 format suitable for display
 5. Information necessary to compute the global [presentation
 timestamp](#presentation-timestamp) of every sample in the
 sequence of [media
 segments](#dfn-media-segment) is not provided.

 For example, if I1 is associated with M1, M2, M3 then the above *MUST*
 hold for all the combinations I1+M1, I1+M2, I1+M1+M2, I1+M2+M3, etc.

Byte stream specifications *MUST* at a minimum define constraints which
ensure that the above requirements hold. Additional constraints *MAY* be
defined, for example to simplify implementation.

::: header-wrapper
## 15. Conformance

As well as sections marked as non-normative, all authoring guidelines,
diagrams, examples, and notes in this specification are non-normative.
Everything else in this specification is normative.

The key words *MAY*, *MUST*, *MUST NOT*, *SHOULD*, and *SHOULD NOT* in
this document are to be interpreted as described in [BCP
14](https://www.rfc-editor.org/info/bcp14)
\[[RFC2119](#bib-rfc2119 "Key words for use in RFCs to Indicate Requirement Levels")\]
\[[RFC8174](#bib-rfc8174 "Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words")\] when, and only when, they appear in all capitals,
as shown here.

::: header-wrapper
## 16. Examples

::: header-wrapper
### 16.1 Using Media Source Extensions

[Example 1](#example-1)

``` {aria-busy="false"}
<video id="v" autoplay></video>
<script>
const video = document.getElementById("v");
const mediaSource = new MediaSource();
mediaSource.addEventListener("sourceopen", onSourceOpen);
video.src = window.URL.createObjectURL(mediaSource);

async function onSourceOpen(e) {
 const mediaSource = e.target;

 if (mediaSource.sourceBuffers.length > 0) return;

 const sourceBuffer = mediaSource.addSourceBuffer(
 'video/webm; codecs="vorbis,vp8"',
 );

 video.addEventListener("seeking", (e) => onSeeking(mediaSource, e.target));
 video.addEventListener("progress", () =>
 appendNextMediaSegment(mediaSource),
 );

 try {
 const initSegment = await getInitializationSegment();

 if (initSegment == null) {
 // Error fetching the initialization segment. Signal end of stream with an error.
 mediaSource.endOfStream("network");
 return;
 }

 // Append the initialization segment.
 sourceBuffer.addEventListener("updateend", function firstAppendHandler() {
 sourceBuffer.removeEventListener("updateend", firstAppendHandler);

 // Append some initial media data.
 appendNextMediaSegment(mediaSource);
 });

 sourceBuffer.appendBuffer(initSegment);
 } catch (error) {
 // Handle errors that might occur during initialization segment fetching.
 console.error("Error fetching initialization segment:", error);
 mediaSource.endOfStream("network");
 }
}

async function appendNextMediaSegment(mediaSource) {
 if (
 mediaSource.readyState === "closed" ||
 mediaSource.sourceBuffers[0].updating
 )
 return;

 // If we have run out of stream data, then signal end of stream.
 if (!haveMoreMediaSegments()) {
 mediaSource.endOfStream();
 return;
 }

 try {
 const mediaSegment = await getNextMediaSegment();

 // NOTE: If mediaSource.readyState == "ended", this appendBuffer() call will
 // cause mediaSource.readyState to transition to "open". The web application
 // should be prepared to handle multiple "sourceopen" events.
 mediaSource.sourceBuffers[0].appendBuffer(mediaSegment);
 }
 catch (error) {
 // Handle errors that might occur during media segment fetching.
 console.error("Error fetching media segment:", error);
 mediaSource.endOfStream("network");
 }
}

function onSeeking(mediaSource, video) {
 if (mediaSource.readyState === "open") {
 // Abort current segment append.
 mediaSource.sourceBuffers[0].abort();
 }

 // Notify the media segment loading code to start fetching data at the
 // new playback position.
 seekToMediaSegmentAt(video.currentTime);

 // Append a media segment from the new playback position.
 appendNextMediaSegment(mediaSource);
}

function onProgress(mediaSource, e) {
 appendNextMediaSegment(mediaSource);
}

// Example of async function for getting initialization segment
async function getInitializationSegment() {
 // Implement fetching of the initialization segment
 // This is just a placeholder function
}

// Example function for checking if there are more media segments
function haveMoreMediaSegments() {
 // Implement logic to determine if there are more media segments
 // This is just a placeholder function
}

// Example function for getting the next media segment
async function getNextMediaSegment() {
 // Implement fetching of the next media segment
 // This is just a placeholder function
}

// Example function for seeking to a specific media segment
function seekToMediaSegmentAt(currentTime) {
 // Implement seeking logic
 // This is just a placeholder function
}
</script>
```

::: header-wrapper
### 16.2 Using a Managed Media Source

[Example 2](#example-2)

``` {aria-busy="false"}
<script>
async function setUpVideoStream() {
 // Specific video format and codec
 const mediaType = 'video/mp4; codecs="mp4a.40.2,avc1.4d4015"';

 // Check if the type of video format / codec is supported.
 if (!window.ManagedMediaSource?.isTypeSupported(mediaType)) {
 return; // Not supported, do something else.
 }

 // Set up video and its managed source.
 const video = document.createElement("video");
 const source = new ManagedMediaSource();

 video.controls = true;

 await new Promise((resolve) => {
 video.src = URL.createObjectURL(source);
 source.addEventListener("sourceopen", resolve, { once: true });
 document.body.appendChild(video);
 });

 const sourceBuffer = source.addSourceBuffer(mediaType);

 // Set up the event handlers
 sourceBuffer.onbufferedchange = (e) => {
 console.log("onbufferedchange event fired.");
 console.log(`Added Ranges: ${timeRangesToString(e.addedRanges)}`);
 console.log(`Removed Ranges: ${timeRangesToString(e.removedRanges)}`);
 };

 source.onstartstreaming = async () => {
 const response = await fetch("./videos/bipbop.mp4");
 const buffer = await response.arrayBuffer();
 await new Promise((resolve) => {
 sourceBuffer.addEventListener("updateend", resolve, { once: true });
 sourceBuffer.appendBuffer(buffer);
 });
 };

 source.onendstreaming = async () => {
 // Stop fetching new segments here
 };
}

// Helper function...
function timeRangesToString(timeRanges) {
 const ranges = ;
 for (let i = 0; i < timeRanges.length; i++) {
 ranges.push([timeRanges.start(i), timeRanges.end(i)]);
 }
 return "[" + ranges.map(([start, end]) => `[${start}, ${end})` ) + "]";
}
</script>
<body onload="setUpVideoStream()"></body>
```

::: header-wrapper
## 17. Acknowledgments

The editors would like to thank Alex Giladi, Bob Lund, Chris Needham,
Chris Poole, Chris Wilson, Cyril Concolato, Dale Curtis, David Dorwin,
David Singer, Duncan Rowden, François Daoust, Frank Galligan, Glenn
Adams, Jer Noble, Joe Steele, John Simmons, Kagami Sascha Rosylight,
Kevin Streeter, Marcos Cáceres, Mark Vickers, Matt Ward, Matthew Gregan,
Michael(tm) Smith, Michael Thornburgh, Mounir Lamouri, Paul Adenot,
Philip Jägenstedt, Philippe Le Hegaret, Pierre Lemieux, Ralph Giles,
Steven Robertson, and Tatsuya Igarashi for their contributions to this
specification.

::: header-wrapper
## A. VideoPlaybackQuality

*This section is non-normative.*

The video playback quality metrics described in previous revisions of
this specification (e.g., sections 5 and 10 of the [Candidate
Recommendation](https://www.w3.org/TR/2016/CR-media-source-20160705/))
are now being developed as part of
\[[MEDIA-PLAYBACK-QUALITY](#bib-media-playback-quality "Media Playback Quality")\]. Some implementations may have implemented the
earlier draft `VideoPlaybackQuality` object and the
[`HTMLVideoElement`](https://html.spec.whatwg.org/multipage/media.html#htmlvideoelement) extension method
[`getVideoPlaybackQuality`](https://w3c.github.io/media-playback-quality/#dom-htmlvideoelement-getvideoplaybackquality)`()` described in those previous
revisions.

::: header-wrapper
## B. Issue summary

- [Issue 276](#issue-container-number-276)[: MSE-in-Workers: Consider
 adding a \"closing\" readyState to explain new \`InvalidStateError\`
 exception when closing underway]{style="text-transform: none"}
- [Issue 280](#issue-container-number-280)[: MSE-in-Workers:
 {Audio,Video,Text}Track{,List} IDL in HTML need additional
 DedicatedWorker in Exposed]{style="text-transform: none"}
- [Issue 289](#issue-container-number-289)[: Editorial? Coded Frame
 eviction algorithm needs to note that \"buffer full flag\" may be
 updated immediately based on \|new
 data\|]{style="text-transform: none"}
- [Issue 277](#issue-container-number-277)[: MSE-in-Workers: Consider
 (eventually) transitioning attached element to error upon termination
 of MediaSource\'s worker/what should media element
 do?]{style="text-transform: none"}
- [Issue 277](#issue-container-number-277-0)[: MSE-in-Workers: Consider
 (eventually) transitioning attached element to error upon termination
 of MediaSource\'s worker/what should media element
 do?]{style="text-transform: none"}
- [Issue](#issue-container-generatedID-89)
- [Issue 280](#issue-container-number-280-0)[: MSE-in-Workers:
 {Audio,Video,Text}Track{,List} IDL in HTML need additional
 DedicatedWorker in Exposed]{style="text-transform: none"}
- [Issue 280](#issue-container-number-280-1)[: MSE-in-Workers:
 {Audio,Video,Text}Track{,List} IDL in HTML need additional
 DedicatedWorker in Exposed]{style="text-transform: none"}
- [Issue 280](#issue-container-number-280-2)[: MSE-in-Workers:
 {Audio,Video,Text}Track{,List} IDL in HTML need additional
 DedicatedWorker in Exposed]{style="text-transform: none"}

::: header-wrapper
## C. References

::: header-wrapper
### C.1 Normative references

\[dom\]
: [DOM Standard](https://dom.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://dom.spec.whatwg.org/>

\[ECMASCRIPT\]
: [ECMAScript Language
 Specification](https://tc39.es/ecma262/multipage/). Ecma
 International. URL: <https://tc39.es/ecma262/multipage/>

\[FILEAPI\]
: [File API](https://www.w3.org/TR/FileAPI/). Marijn Kruisselbrink.
 W3C. 4 December 2024. W3C Working Draft. URL:
 <https://www.w3.org/TR/FileAPI/>

\[HTML\]
: [HTML Standard](https://html.spec.whatwg.org/multipage/). Anne van
 Kesteren; Domenic Denicola; Dominic Farolino; Ian Hickson; Philip
 Jägenstedt; Simon Pieters. WHATWG. Living Standard. URL:
 <https://html.spec.whatwg.org/multipage/>

\[infra\]
: [Infra Standard](https://infra.spec.whatwg.org/). Anne van Kesteren;
 Domenic Denicola. WHATWG. Living Standard. URL:
 <https://infra.spec.whatwg.org/>

\[MSE-REGISTRY\]
: [Media Source Extensions™ Byte Stream Format
 Registry](https://w3c.github.io/mse-byte-stream-format-registry/).
 Matthew Wolenetz; Jerry Smith; Aaron Colwell. W3C. URL:
 <https://w3c.github.io/mse-byte-stream-format-registry/>

\[RFC2119\]
: [Key words for use in RFCs to Indicate Requirement
 Levels](https://www.rfc-editor.org/rfc/rfc2119). S. Bradner. IETF.
 March 1997. Best Current Practice. URL:
 <https://www.rfc-editor.org/rfc/rfc2119>

\[RFC8174\]
: [Ambiguity of Uppercase vs Lowercase in RFC 2119 Key
 Words](https://www.rfc-editor.org/rfc/rfc8174). B. Leiba. IETF.
 May 2017. Best Current Practice. URL:
 <https://www.rfc-editor.org/rfc/rfc8174>

\[WEBIDL\]
: [Web IDL Standard](https://webidl.spec.whatwg.org/). Edgar Chen;
 Timothy Gu. WHATWG. Living Standard. URL:
 <https://webidl.spec.whatwg.org/>

::: header-wrapper
### C.2 Informative references

\[INBANDTRACKS\]
: [Sourcing In-band Media Resource Tracks from Media Containers into
 HTML](https://dev.w3.org/html5/html-sourcing-inband-tracks/). Silvia
 Pfeiffer; Bob Lund. W3C. 26 April 2015. Unofficial Draft. URL:
 <https://dev.w3.org/html5/html-sourcing-inband-tracks/>

\[MEDIA-PLAYBACK-QUALITY\]
: [Media Playback
 Quality](https://w3c.github.io/media-playback-quality/). Mounir
 Lamouri; Chris Cunningham. W3C. W3C Editor\'s Draft. URL:
 <https://w3c.github.io/media-playback-quality/>

\[url\]
: [URL Standard](https://url.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://url.spec.whatwg.org/>

[[↑]](#title)

[Permalink](#dfn-active-track-buffers)

**Referenced in:**

- [§ 3.15.3
 Seeking](#ref-for-dfn-active-track-buffers-1 "§ 3.15.3 Seeking")

[Permalink](#dfn-append-window)

**Referenced in:**

- [§ 5.1 Attributes](#ref-for-dfn-append-window-1 "§ 5.1 Attributes")
 [(2)](#ref-for-dfn-append-window-2 "Reference 2")

[Permalink](#dfn-coded-frame)
[exported]

**Referenced in:**

- [§ 2. Definitions](#ref-for-dfn-coded-frame-1 "§ 2. Definitions")
 [(2)](#ref-for-dfn-coded-frame-2 "Reference 2")
 [(3)](#ref-for-dfn-coded-frame-3 "Reference 3")
 [(4)](#ref-for-dfn-coded-frame-4 "Reference 4")
 [(5)](#ref-for-dfn-coded-frame-5 "Reference 5")
 [(6)](#ref-for-dfn-coded-frame-6 "Reference 6")
 [(7)](#ref-for-dfn-coded-frame-7 "Reference 7")
 [(8)](#ref-for-dfn-coded-frame-8 "Reference 8")
 [(9)](#ref-for-dfn-coded-frame-9 "Reference 9")
- [§ 3.15.3 Seeking](#ref-for-dfn-coded-frame-10 "§ 3.15.3 Seeking")
- [§ 3.15.6 Duration
 change](#ref-for-dfn-coded-frame-11 "§ 3.15.6 Duration change")
- [§ 5. SourceBuffer
 interface](#ref-for-dfn-coded-frame-12 "§ 5. SourceBuffer interface")
- [§ 5.3 Track
 Buffers](#ref-for-dfn-coded-frame-13 "§ 5.3 Track Buffers")
 [(2)](#ref-for-dfn-coded-frame-14 "Reference 2")
 [(3)](#ref-for-dfn-coded-frame-15 "Reference 3")
 [(4)](#ref-for-dfn-coded-frame-16 "Reference 4")
 [(5)](#ref-for-dfn-coded-frame-17 "Reference 5")
 [(6)](#ref-for-dfn-coded-frame-18 "Reference 6")
 [(7)](#ref-for-dfn-coded-frame-19 "Reference 7")
 [(8)](#ref-for-dfn-coded-frame-20 "Reference 8")
 [(9)](#ref-for-dfn-coded-frame-21 "Reference 9")
 [(10)](#ref-for-dfn-coded-frame-22 "Reference 10")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-coded-frame-23 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-dfn-coded-frame-24 "Reference 2")
 [(3)](#ref-for-dfn-coded-frame-25 "Reference 3")
- [§ 5.5.2 Reset Parser
 State](#ref-for-dfn-coded-frame-26 "§ 5.5.2 Reset Parser State")
 [(2)](#ref-for-dfn-coded-frame-27 "Reference 2")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dfn-coded-frame-28 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dfn-coded-frame-29 "Reference 2")
 [(3)](#ref-for-dfn-coded-frame-30 "Reference 3")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dfn-coded-frame-31 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-dfn-coded-frame-32 "Reference 2")
 [(3)](#ref-for-dfn-coded-frame-33 "Reference 3")
 [(4)](#ref-for-dfn-coded-frame-34 "Reference 4")
 [(5)](#ref-for-dfn-coded-frame-35 "Reference 5")
 [(6)](#ref-for-dfn-coded-frame-36 "Reference 6")
 [(7)](#ref-for-dfn-coded-frame-37 "Reference 7")
 [(8)](#ref-for-dfn-coded-frame-38 "Reference 8")
 [(9)](#ref-for-dfn-coded-frame-39 "Reference 9")
 [(10)](#ref-for-dfn-coded-frame-40 "Reference 10")
 [(11)](#ref-for-dfn-coded-frame-41 "Reference 11")
 [(12)](#ref-for-dfn-coded-frame-42 "Reference 12")
 [(13)](#ref-for-dfn-coded-frame-43 "Reference 13")
 [(14)](#ref-for-dfn-coded-frame-44 "Reference 14")
 [(15)](#ref-for-dfn-coded-frame-45 "Reference 15")
 [(16)](#ref-for-dfn-coded-frame-46 "Reference 16")
 [(17)](#ref-for-dfn-coded-frame-47 "Reference 17")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-dfn-coded-frame-48 "§ 5.5.9 Coded Frame Removal")
 [(2)](#ref-for-dfn-coded-frame-49 "Reference 2")
 [(3)](#ref-for-dfn-coded-frame-50 "Reference 3")
 [(4)](#ref-for-dfn-coded-frame-51 "Reference 4")
 [(5)](#ref-for-dfn-coded-frame-52 "Reference 5")
- [§ 5.5.11 Audio Splice
 Frame](#ref-for-dfn-coded-frame-53 "§ 5.5.11 Audio Splice Frame")
 [(2)](#ref-for-dfn-coded-frame-54 "Reference 2")
 [(3)](#ref-for-dfn-coded-frame-55 "Reference 3")
- [§ 5.5.12 Audio Splice
 Rendering](#ref-for-dfn-coded-frame-56 "§ 5.5.12 Audio Splice Rendering")
 [(2)](#ref-for-dfn-coded-frame-57 "Reference 2")
- [§ 5.5.13 Text Splice
 Frame](#ref-for-dfn-coded-frame-58 "§ 5.5.13 Text Splice Frame")
 [(2)](#ref-for-dfn-coded-frame-59 "Reference 2")
 [(3)](#ref-for-dfn-coded-frame-60 "Reference 3")

[Permalink](#dfn-coded-frame-duration)

**Referenced in:**

- [§ 2.
 Definitions](#ref-for-dfn-coded-frame-duration-1 "§ 2. Definitions")
 [(2)](#ref-for-dfn-coded-frame-duration-2 "Reference 2")
 [(3)](#ref-for-dfn-coded-frame-duration-3 "Reference 3")
 [(4)](#ref-for-dfn-coded-frame-duration-4 "Reference 4")
- [§ 5.3 Track
 Buffers](#ref-for-dfn-coded-frame-duration-5 "§ 5.3 Track Buffers")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dfn-coded-frame-duration-6 "§ 5.5.8 Coded Frame Processing")
- [§ 5.5.11 Audio Splice
 Frame](#ref-for-dfn-coded-frame-duration-7 "§ 5.5.11 Audio Splice Frame")
 [(2)](#ref-for-dfn-coded-frame-duration-8 "Reference 2")
 [(3)](#ref-for-dfn-coded-frame-duration-9 "Reference 3")
- [§ 5.5.12 Audio Splice
 Rendering](#ref-for-dfn-coded-frame-duration-10 "§ 5.5.12 Audio Splice Rendering")
- [§ 5.5.13 Text Splice
 Frame](#ref-for-dfn-coded-frame-duration-11 "§ 5.5.13 Text Splice Frame")
 [(2)](#ref-for-dfn-coded-frame-duration-12 "Reference 2")

[Permalink](#dfn-coded-frame-end-timestamp)

**Referenced in:**

- [§ 5.3 Track
 Buffers](#ref-for-dfn-coded-frame-end-timestamp-1 "§ 5.3 Track Buffers")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-coded-frame-end-timestamp-2 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-dfn-coded-frame-end-timestamp-3 "Reference 2")

[Permalink](#dfn-coded-frame-group)

**Referenced in:**

- [§ 5.3 Track
 Buffers](#ref-for-dfn-coded-frame-group-1 "§ 5.3 Track Buffers")
 [(2)](#ref-for-dfn-coded-frame-group-2 "Reference 2")
 [(3)](#ref-for-dfn-coded-frame-group-3 "Reference 3")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-coded-frame-group-4 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-dfn-coded-frame-group-5 "Reference 2")

[Permalink](#dfn-decode-timestamp)

**Referenced in:**

- [§ 2. Definitions](#ref-for-dfn-decode-timestamp-1 "§ 2. Definitions")
 [(2)](#ref-for-dfn-decode-timestamp-2 "Reference 2")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-dfn-decode-timestamp-3 "§ 5.5.9 Coded Frame Removal")
- [§ 5.5.11 Audio Splice
 Frame](#ref-for-dfn-decode-timestamp-4 "§ 5.5.11 Audio Splice Frame")
 [(2)](#ref-for-dfn-decode-timestamp-5 "Reference 2")
 [(3)](#ref-for-dfn-decode-timestamp-6 "Reference 3")
 [(4)](#ref-for-dfn-decode-timestamp-7 "Reference 4")

[Permalink](#dfn-initialization-segment)
[exported]

**Referenced in:**

- [§ 2.
 Definitions](#ref-for-dfn-initialization-segment-1 "§ 2. Definitions")
 [(2)](#ref-for-dfn-initialization-segment-2 "Reference 2")
 [(3)](#ref-for-dfn-initialization-segment-3 "Reference 3")
- [§ 3.15.3
 Seeking](#ref-for-dfn-initialization-segment-4 "§ 3.15.3 Seeking")
- [§ 5.3 Track
 Buffers](#ref-for-dfn-initialization-segment-5 "§ 5.3 Track Buffers")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-initialization-segment-6 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-dfn-initialization-segment-7 "Reference 2")
 [(3)](#ref-for-dfn-initialization-segment-8 "Reference 3")
 [(4)](#ref-for-dfn-initialization-segment-9 "Reference 4")
 [(5)](#ref-for-dfn-initialization-segment-10 "Reference 5")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dfn-initialization-segment-11 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dfn-initialization-segment-12 "Reference 2")
 [(3)](#ref-for-dfn-initialization-segment-13 "Reference 3")
 [(4)](#ref-for-dfn-initialization-segment-14 "Reference 4")
 [(5)](#ref-for-dfn-initialization-segment-15 "Reference 5")
 [(6)](#ref-for-dfn-initialization-segment-16 "Reference 6")
 [(7)](#ref-for-dfn-initialization-segment-17 "Reference 7")
 [(8)](#ref-for-dfn-initialization-segment-18 "Reference 8")
 [(9)](#ref-for-dfn-initialization-segment-19 "Reference 9")
 [(10)](#ref-for-dfn-initialization-segment-20 "Reference 10")
 [(11)](#ref-for-dfn-initialization-segment-21 "Reference 11")
 [(12)](#ref-for-dfn-initialization-segment-22 "Reference 12")
 [(13)](#ref-for-dfn-initialization-segment-23 "Reference 13")
 [(14)](#ref-for-dfn-initialization-segment-24 "Reference 14")
 [(15)](#ref-for-dfn-initialization-segment-25 "Reference 15")
 [(16)](#ref-for-dfn-initialization-segment-26 "Reference 16")
 [(17)](#ref-for-dfn-initialization-segment-27 "Reference 17")
 [(18)](#ref-for-dfn-initialization-segment-28 "Reference 18")
 [(19)](#ref-for-dfn-initialization-segment-29 "Reference 19")
 [(20)](#ref-for-dfn-initialization-segment-30 "Reference 20")
 [(21)](#ref-for-dfn-initialization-segment-31 "Reference 21")
 [(22)](#ref-for-dfn-initialization-segment-32 "Reference 22")
- [§ 14. Byte Stream
 Formats](#ref-for-dfn-initialization-segment-33 "§ 14. Byte Stream Formats")
 [(2)](#ref-for-dfn-initialization-segment-34 "Reference 2")
 [(3)](#ref-for-dfn-initialization-segment-35 "Reference 3")
 [(4)](#ref-for-dfn-initialization-segment-36 "Reference 4")
 [(5)](#ref-for-dfn-initialization-segment-37 "Reference 5")
 [(6)](#ref-for-dfn-initialization-segment-38 "Reference 6")
 [(7)](#ref-for-dfn-initialization-segment-39 "Reference 7")
 [(8)](#ref-for-dfn-initialization-segment-40 "Reference 8")

[Permalink](#dfn-media-segment)
[exported]

**Referenced in:**

- [§ 2. Definitions](#ref-for-dfn-media-segment-1 "§ 2. Definitions")
 [(2)](#ref-for-dfn-media-segment-2 "Reference 2")
 [(3)](#ref-for-dfn-media-segment-3 "Reference 3")
- [§ 3.15.3 Seeking](#ref-for-dfn-media-segment-4 "§ 3.15.3 Seeking")
- [§ 5.1 Attributes](#ref-for-dfn-media-segment-5 "§ 5.1 Attributes")
 [(2)](#ref-for-dfn-media-segment-6 "Reference 2")
- [§ 5.3 Track
 Buffers](#ref-for-dfn-media-segment-7 "§ 5.3 Track Buffers")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-media-segment-8 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-dfn-media-segment-9 "Reference 2")
 [(3)](#ref-for-dfn-media-segment-10 "Reference 3")
 [(4)](#ref-for-dfn-media-segment-11 "Reference 4")
 [(5)](#ref-for-dfn-media-segment-12 "Reference 5")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dfn-media-segment-13 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-dfn-media-segment-14 "Reference 2")
- [§ 14. Byte Stream
 Formats](#ref-for-dfn-media-segment-15 "§ 14. Byte Stream Formats")
 [(2)](#ref-for-dfn-media-segment-16 "Reference 2")
 [(3)](#ref-for-dfn-media-segment-17 "Reference 3")
 [(4)](#ref-for-dfn-media-segment-18 "Reference 4")
 [(5)](#ref-for-dfn-media-segment-19 "Reference 5")
 [(6)](#ref-for-dfn-media-segment-20 "Reference 6")
 [(7)](#ref-for-dfn-media-segment-21 "Reference 7")

[Permalink](#mediasource-object-url)

**Referenced in:**

- [§ 3.14 Cross-context communication
 model](#ref-for-mediasource-object-url-1 "§ 3.14 Cross-context communication model")
- [§ 3.15.1 Attaching to a media
 element](#ref-for-mediasource-object-url-2 "§ 3.15.1 Attaching to a media element")
 [(2)](#ref-for-mediasource-object-url-3 "Reference 2")
 [(3)](#ref-for-mediasource-object-url-4 "Reference 3")
 [(4)](#ref-for-mediasource-object-url-5 "Reference 4")
 [(5)](#ref-for-mediasource-object-url-6 "Reference 5")
 [(6)](#ref-for-mediasource-object-url-7 "Reference 6")
 [(7)](#ref-for-mediasource-object-url-8 "Reference 7")
 [(8)](#ref-for-mediasource-object-url-9 "Reference 8")
 [(9)](#ref-for-mediasource-object-url-10 "Reference 9")
- [§ 4.1 Transfer](#ref-for-mediasource-object-url-11 "§ 4.1 Transfer")
 [(2)](#ref-for-mediasource-object-url-12 "Reference 2")
 [(3)](#ref-for-mediasource-object-url-13 "Reference 3")

[Permalink](#parent-media-source)

**Referenced in:**

- [§ 5.1 Attributes](#ref-for-parent-media-source-1 "§ 5.1 Attributes")
 [(2)](#ref-for-parent-media-source-2 "Reference 2")
 [(3)](#ref-for-parent-media-source-3 "Reference 3")
 [(4)](#ref-for-parent-media-source-4 "Reference 4")
 [(5)](#ref-for-parent-media-source-5 "Reference 5")
 [(6)](#ref-for-parent-media-source-6 "Reference 6")
 [(7)](#ref-for-parent-media-source-7 "Reference 7")
 [(8)](#ref-for-parent-media-source-8 "Reference 8")
 [(9)](#ref-for-parent-media-source-9 "Reference 9")
 [(10)](#ref-for-parent-media-source-10 "Reference 10")
 [(11)](#ref-for-parent-media-source-11 "Reference 11")
- [§ 5.2 Methods](#ref-for-parent-media-source-12 "§ 5.2 Methods")
 [(2)](#ref-for-parent-media-source-13 "Reference 2")
 [(3)](#ref-for-parent-media-source-14 "Reference 3")
 [(4)](#ref-for-parent-media-source-15 "Reference 4")
 [(5)](#ref-for-parent-media-source-16 "Reference 5")
 [(6)](#ref-for-parent-media-source-17 "Reference 6")
 [(7)](#ref-for-parent-media-source-18 "Reference 7")
 [(8)](#ref-for-parent-media-source-19 "Reference 8")
 [(9)](#ref-for-parent-media-source-20 "Reference 9")
 [(10)](#ref-for-parent-media-source-21 "Reference 10")
 [(11)](#ref-for-parent-media-source-22 "Reference 11")
- [§ 5.5.4 Prepare
 Append](#ref-for-parent-media-source-23 "§ 5.5.4 Prepare Append")
 [(2)](#ref-for-parent-media-source-24 "Reference 2")
 [(3)](#ref-for-parent-media-source-25 "Reference 3")
 [(4)](#ref-for-parent-media-source-26 "Reference 4")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-parent-media-source-27 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-parent-media-source-28 "Reference 2")
 [(3)](#ref-for-parent-media-source-29 "Reference 3")
 [(4)](#ref-for-parent-media-source-30 "Reference 4")
 [(5)](#ref-for-parent-media-source-31 "Reference 5")
 [(6)](#ref-for-parent-media-source-32 "Reference 6")
- [§ Attributes](#ref-for-parent-media-source-33 "§ Attributes")
 [(2)](#ref-for-parent-media-source-34 "Reference 2")
 [(3)](#ref-for-parent-media-source-35 "Reference 3")

[Permalink](#presentation-start-time)

**Referenced in:**

- [§ 2.
 Definitions](#ref-for-presentation-start-time-1 "§ 2. Definitions")
 [(2)](#ref-for-presentation-start-time-2 "Reference 2")
 [(3)](#ref-for-presentation-start-time-3 "Reference 3")
- [§ 5.1
 Attributes](#ref-for-presentation-start-time-4 "§ 5.1 Attributes")
- [§ 5.2 Methods](#ref-for-presentation-start-time-5 "§ 5.2 Methods")
 [(2)](#ref-for-presentation-start-time-6 "Reference 2")
 [(3)](#ref-for-presentation-start-time-7 "Reference 3")
- [§ 5.5.6 Range
 Removal](#ref-for-presentation-start-time-8 "§ 5.5.6 Range Removal")
 [(2)](#ref-for-presentation-start-time-9 "Reference 2")

[Permalink](#presentation-interval)

**Referenced in:**

- [§ 5.5.8 Coded Frame
 Processing](#ref-for-presentation-interval-1 "§ 5.5.8 Coded Frame Processing")
- [§ 5.5.11 Audio Splice
 Frame](#ref-for-presentation-interval-2 "§ 5.5.11 Audio Splice Frame")
- [§ 5.5.13 Text Splice
 Frame](#ref-for-presentation-interval-3 "§ 5.5.13 Text Splice Frame")

[Permalink](#presentation-order)

**Referenced in:**

- [§ 2. Definitions](#ref-for-presentation-order-1 "§ 2. Definitions")
 [(2)](#ref-for-presentation-order-2 "Reference 2")
 [(3)](#ref-for-presentation-order-3 "Reference 3")

[Permalink](#presentation-timestamp)
[exported]

**Referenced in:**

- [§ 2.
 Definitions](#ref-for-presentation-timestamp-1 "§ 2. Definitions")
 [(2)](#ref-for-presentation-timestamp-2 "Reference 2")
 [(3)](#ref-for-presentation-timestamp-3 "Reference 3")
 [(4)](#ref-for-presentation-timestamp-4 "Reference 4")
 [(5)](#ref-for-presentation-timestamp-5 "Reference 5")
 [(6)](#ref-for-presentation-timestamp-6 "Reference 6")
 [(7)](#ref-for-presentation-timestamp-7 "Reference 7")
 [(8)](#ref-for-presentation-timestamp-8 "Reference 8")
 [(9)](#ref-for-presentation-timestamp-9 "Reference 9")
 [(10)](#ref-for-presentation-timestamp-10 "Reference 10")
- [§ 3.15.6 Duration
 change](#ref-for-presentation-timestamp-11 "§ 3.15.6 Duration change")
- [§ 5.1
 Attributes](#ref-for-presentation-timestamp-12 "§ 5.1 Attributes")
 [(2)](#ref-for-presentation-timestamp-13 "Reference 2")
- [§ 5.3 Track
 Buffers](#ref-for-presentation-timestamp-14 "§ 5.3 Track Buffers")
 [(2)](#ref-for-presentation-timestamp-15 "Reference 2")
- [§ 5.5.6 Range
 Removal](#ref-for-presentation-timestamp-16 "§ 5.5.6 Range Removal")
 [(2)](#ref-for-presentation-timestamp-17 "Reference 2")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-presentation-timestamp-18 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-presentation-timestamp-19 "Reference 2")
 [(3)](#ref-for-presentation-timestamp-20 "Reference 3")
 [(4)](#ref-for-presentation-timestamp-21 "Reference 4")
 [(5)](#ref-for-presentation-timestamp-22 "Reference 5")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-presentation-timestamp-23 "§ 5.5.9 Coded Frame Removal")
 [(2)](#ref-for-presentation-timestamp-24 "Reference 2")
 [(3)](#ref-for-presentation-timestamp-25 "Reference 3")
- [§ 5.5.11 Audio Splice
 Frame](#ref-for-presentation-timestamp-26 "§ 5.5.11 Audio Splice Frame")
 [(2)](#ref-for-presentation-timestamp-27 "Reference 2")
 [(3)](#ref-for-presentation-timestamp-28 "Reference 3")
 [(4)](#ref-for-presentation-timestamp-29 "Reference 4")
 [(5)](#ref-for-presentation-timestamp-30 "Reference 5")
 [(6)](#ref-for-presentation-timestamp-31 "Reference 6")
 [(7)](#ref-for-presentation-timestamp-32 "Reference 7")
 [(8)](#ref-for-presentation-timestamp-33 "Reference 8")
 [(9)](#ref-for-presentation-timestamp-34 "Reference 9")
- [§ 5.5.12 Audio Splice
 Rendering](#ref-for-presentation-timestamp-35 "§ 5.5.12 Audio Splice Rendering")
 [(2)](#ref-for-presentation-timestamp-36 "Reference 2")
 [(3)](#ref-for-presentation-timestamp-37 "Reference 3")
 [(4)](#ref-for-presentation-timestamp-38 "Reference 4")
- [§ 5.5.13 Text Splice
 Frame](#ref-for-presentation-timestamp-39 "§ 5.5.13 Text Splice Frame")
 [(2)](#ref-for-presentation-timestamp-40 "Reference 2")
 [(3)](#ref-for-presentation-timestamp-41 "Reference 3")
- [§ 14. Byte Stream
 Formats](#ref-for-presentation-timestamp-42 "§ 14. Byte Stream Formats")

[Permalink](#random-access-point)
[exported]

**Referenced in:**

- [§ 3.15.3 Seeking](#ref-for-random-access-point-1 "§ 3.15.3 Seeking")
- [§ 5.3 Track
 Buffers](#ref-for-random-access-point-2 "§ 5.3 Track Buffers")
 [(2)](#ref-for-random-access-point-3 "Reference 2")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-random-access-point-4 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-random-access-point-5 "Reference 2")
 [(3)](#ref-for-random-access-point-6 "Reference 3")
 [(4)](#ref-for-random-access-point-7 "Reference 4")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-random-access-point-8 "§ 5.5.9 Coded Frame Removal")
 [(2)](#ref-for-random-access-point-9 "Reference 2")
 [(3)](#ref-for-random-access-point-10 "Reference 3")
- [§ 14. Byte Stream
 Formats](#ref-for-random-access-point-11 "§ 14. Byte Stream Formats")

[Permalink](#dfn-sourcebuffer-byte-stream-format-specification)

**Referenced in:**

- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-sourcebuffer-byte-stream-format-specification-1 "§ 5.5.1 Segment Parser Loop")

[Permalink](#dfn-sourcebuffer-configuration)

**Referenced in:**

- [§ 3.7 addSourceBuffer()
 method](#ref-for-dfn-sourcebuffer-configuration-1 "§ 3.7 addSourceBuffer() method")

[Permalink](#dfn-track-description)

**Referenced in:**

- [§ 2.
 Definitions](#ref-for-dfn-track-description-1 "§ 2. Definitions")
- [§ 5.3 Track
 Buffers](#ref-for-dfn-track-description-2 "§ 5.3 Track Buffers")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dfn-track-description-3 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dfn-track-description-4 "Reference 2")
 [(3)](#ref-for-dfn-track-description-5 "Reference 3")
 [(4)](#ref-for-dfn-track-description-6 "Reference 4")

[Permalink](#dfn-track-id)

**Referenced in:**

- [§ 2. Definitions](#ref-for-dfn-track-id-1 "§ 2. Definitions")
 [(2)](#ref-for-dfn-track-id-2 "Reference 2")
 [(3)](#ref-for-dfn-track-id-3 "Reference 3")
 [(4)](#ref-for-dfn-track-id-4 "Reference 4")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dfn-track-id-5 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dfn-track-id-6 "Reference 2")
 [(3)](#ref-for-dfn-track-id-7 "Reference 3")
 [(4)](#ref-for-dfn-track-id-8 "Reference 4")
- [§ 14. Byte Stream
 Formats](#ref-for-dfn-track-id-9 "§ 14. Byte Stream Formats")
 [(2)](#ref-for-dfn-track-id-10 "Reference 2")

[Permalink](#dom-mediasource)
[exported]
[IDL](#webidl-1502719514 "Jump to IDL declaration")

**Referenced in:**

- [§ Status of This
 Document](#ref-for-dom-mediasource-1 "§ Status of This Document")
- [§ 2. Definitions](#ref-for-dom-mediasource-2 "§ 2. Definitions")
 [(2)](#ref-for-dom-mediasource-3 "Reference 2")
 [(3)](#ref-for-dom-mediasource-4 "Reference 3")
 [(4)](#ref-for-dom-mediasource-5 "Reference 4")
 [(5)](#ref-for-dom-mediasource-6 "Reference 5")
 [(6)](#ref-for-dom-mediasource-7 "Reference 6")
- [§ 3. MediaSource
 interface](#ref-for-dom-mediasource-8 "§ 3. MediaSource interface")
 [(2)](#ref-for-dom-mediasource-9 "Reference 2")
 [(3)](#ref-for-dom-mediasource-10 "Reference 3")
 [(4)](#ref-for-dom-mediasource-11 "Reference 4")
 [(5)](#ref-for-dom-mediasource-12 "Reference 5")
 [(6)](#ref-for-dom-mediasource-13 "Reference 6")
 [(7)](#ref-for-dom-mediasource-14 "Reference 7")
 [(8)](#ref-for-dom-mediasource-15 "Reference 8")
 [(9)](#ref-for-dom-mediasource-16 "Reference 9")
 [(10)](#ref-for-dom-mediasource-17 "Reference 10")
 [(11)](#ref-for-dom-mediasource-18 "Reference 11")
- [§ 3.1 handle
 attribute](#ref-for-dom-mediasource-19 "§ 3.1 handle attribute")
 [(2)](#ref-for-dom-mediasource-20 "Reference 2")
 [(3)](#ref-for-dom-mediasource-21 "Reference 3")
 [(4)](#ref-for-dom-mediasource-22 "Reference 4")
 [(5)](#ref-for-dom-mediasource-23 "Reference 5")
 [(6)](#ref-for-dom-mediasource-24 "Reference 6")
- [§ 3.2 sourceBuffers
 attribute](#ref-for-dom-mediasource-25 "§ 3.2 sourceBuffers attribute")
 [(2)](#ref-for-dom-mediasource-26 "Reference 2")
- [§ 3.4 readyState
 attribute](#ref-for-dom-mediasource-27 "§ 3.4 readyState attribute")
 [(2)](#ref-for-dom-mediasource-28 "Reference 2")
- [§ 3.5 duration
 attribute](#ref-for-dom-mediasource-29 "§ 3.5 duration attribute")
- [§ 3.6 canConstructInDedicatedWorker
 attribute](#ref-for-dom-mediasource-30 "§ 3.6 canConstructInDedicatedWorker attribute")
 [(2)](#ref-for-dom-mediasource-31 "Reference 2")
- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dom-mediasource-32 "§ 3.8 removeSourceBuffer() method")
 [(2)](#ref-for-dom-mediasource-33 "Reference 2")
 [(3)](#ref-for-dom-mediasource-34 "Reference 3")
- [§ 3.12 isTypeSupported()
 method](#ref-for-dom-mediasource-35 "§ 3.12 isTypeSupported() method")
 [(2)](#ref-for-dom-mediasource-36 "Reference 2")
 [(3)](#ref-for-dom-mediasource-37 "Reference 3")
- [§ 3.13 Event
 Summary](#ref-for-dom-mediasource-38 "§ 3.13 Event Summary")
 [(2)](#ref-for-dom-mediasource-39 "Reference 2")
 [(3)](#ref-for-dom-mediasource-40 "Reference 3")
- [§ 3.14 Cross-context communication
 model](#ref-for-dom-mediasource-41 "§ 3.14 Cross-context communication model")
 [(2)](#ref-for-dom-mediasource-42 "Reference 2")
 [(3)](#ref-for-dom-mediasource-43 "Reference 3")
 [(4)](#ref-for-dom-mediasource-44 "Reference 4")
 [(5)](#ref-for-dom-mediasource-45 "Reference 5")
 [(6)](#ref-for-dom-mediasource-46 "Reference 6")
 [(7)](#ref-for-dom-mediasource-47 "Reference 7")
 [(8)](#ref-for-dom-mediasource-48 "Reference 8")
 [(9)](#ref-for-dom-mediasource-49 "Reference 9")
 [(10)](#ref-for-dom-mediasource-50 "Reference 10")
- [§ 3.15.1 Attaching to a media
 element](#ref-for-dom-mediasource-51 "§ 3.15.1 Attaching to a media element")
 [(2)](#ref-for-dom-mediasource-52 "Reference 2")
 [(3)](#ref-for-dom-mediasource-53 "Reference 3")
 [(4)](#ref-for-dom-mediasource-54 "Reference 4")
 [(5)](#ref-for-dom-mediasource-55 "Reference 5")
 [(6)](#ref-for-dom-mediasource-56 "Reference 6")
 [(7)](#ref-for-dom-mediasource-57 "Reference 7")
 [(8)](#ref-for-dom-mediasource-58 "Reference 8")
 [(9)](#ref-for-dom-mediasource-59 "Reference 9")
 [(10)](#ref-for-dom-mediasource-60 "Reference 10")
 [(11)](#ref-for-dom-mediasource-61 "Reference 11")
 [(12)](#ref-for-dom-mediasource-62 "Reference 12")
 [(13)](#ref-for-dom-mediasource-63 "Reference 13")
 [(14)](#ref-for-dom-mediasource-64 "Reference 14")
 [(15)](#ref-for-dom-mediasource-65 "Reference 15")
 [(16)](#ref-for-dom-mediasource-66 "Reference 16")
 [(17)](#ref-for-dom-mediasource-67 "Reference 17")
 [(18)](#ref-for-dom-mediasource-68 "Reference 18")
 [(19)](#ref-for-dom-mediasource-69 "Reference 19")
 [(20)](#ref-for-dom-mediasource-70 "Reference 20")
 [(21)](#ref-for-dom-mediasource-71 "Reference 21")
 [(22)](#ref-for-dom-mediasource-72 "Reference 22")
 [(23)](#ref-for-dom-mediasource-73 "Reference 23")
 [(24)](#ref-for-dom-mediasource-74 "Reference 24")
 [(25)](#ref-for-dom-mediasource-75 "Reference 25")
 [(26)](#ref-for-dom-mediasource-76 "Reference 26")
 [(27)](#ref-for-dom-mediasource-77 "Reference 27")
 [(28)](#ref-for-dom-mediasource-78 "Reference 28")
- [§ 3.15.2 Detaching from a media
 element](#ref-for-dom-mediasource-79 "§ 3.15.2 Detaching from a media element")
 [(2)](#ref-for-dom-mediasource-80 "Reference 2")
 [(3)](#ref-for-dom-mediasource-81 "Reference 3")
 [(4)](#ref-for-dom-mediasource-82 "Reference 4")
 [(5)](#ref-for-dom-mediasource-83 "Reference 5")
 [(6)](#ref-for-dom-mediasource-84 "Reference 6")
 [(7)](#ref-for-dom-mediasource-85 "Reference 7")
- [§ 3.15.5 Changes to selected/enabled track
 state](#ref-for-dom-mediasource-86 "§ 3.15.5 Changes to selected/enabled track state")
- [§ 3.15.7 End of
 stream](#ref-for-dom-mediasource-87 "§ 3.15.7 End of stream")
- [§ 3.15.8 Mirror if
 necessary](#ref-for-dom-mediasource-88 "§ 3.15.8 Mirror if necessary")
 [(2)](#ref-for-dom-mediasource-89 "Reference 2")
- [§ 4. MediaSourceHandle
 interface](#ref-for-dom-mediasource-90 "§ 4. MediaSourceHandle interface")
 [(2)](#ref-for-dom-mediasource-91 "Reference 2")
 [(3)](#ref-for-dom-mediasource-92 "Reference 3")
 [(4)](#ref-for-dom-mediasource-93 "Reference 4")
- [§ 4.1 Transfer](#ref-for-dom-mediasource-94 "§ 4.1 Transfer")
 [(2)](#ref-for-dom-mediasource-95 "Reference 2")
 [(3)](#ref-for-dom-mediasource-96 "Reference 3")
 [(4)](#ref-for-dom-mediasource-97 "Reference 4")
- [§ 5.5.4 Prepare
 Append](#ref-for-dom-mediasource-98 "§ 5.5.4 Prepare Append")
- [§ 7. ManagedMediaSource
 interface](#ref-for-dom-mediasource-99 "§ 7. ManagedMediaSource interface")
 [(2)](#ref-for-dom-mediasource-100 "Reference 2")
 [(3)](#ref-for-dom-mediasource-101 "Reference 3")
- [§ 7.3.1 ManagedSourceBuffer
 Monitoring](#ref-for-dom-mediasource-102 "§ 7.3.1 ManagedSourceBuffer Monitoring")
- [§ 10. HTMLMediaElement
 Extensions](#ref-for-dom-mediasource-103 "§ 10. HTMLMediaElement Extensions")
- [§ 10.1 HTMLMediaElement\'s
 seekable](#ref-for-dom-mediasource-104 "§ 10.1 HTMLMediaElement's seekable")
 [(2)](#ref-for-dom-mediasource-105 "Reference 2")
 [(3)](#ref-for-dom-mediasource-106 "Reference 3")
- [§ 10.2 HTMLMediaElement\'s
 buffered](#ref-for-dom-mediasource-107 "§ 10.2 HTMLMediaElement's buffered")
 [(2)](#ref-for-dom-mediasource-108 "Reference 2")
 [(3)](#ref-for-dom-mediasource-109 "Reference 3")

[Permalink](#dfn-live-seekable-range)

**Referenced in:**

- [§ 3.10 setLiveSeekableRange()
 method](#ref-for-dfn-live-seekable-range-1 "§ 3.10 setLiveSeekableRange() method")
 [(2)](#ref-for-dfn-live-seekable-range-2 "Reference 2")
- [§ 3.11 clearLiveSeekableRange()
 method](#ref-for-dfn-live-seekable-range-3 "§ 3.11 clearLiveSeekableRange() method")
 [(2)](#ref-for-dfn-live-seekable-range-4 "Reference 2")
 [(3)](#ref-for-dfn-live-seekable-range-5 "Reference 3")
- [§ 10.1 HTMLMediaElement\'s
 seekable](#ref-for-dfn-live-seekable-range-6 "§ 10.1 HTMLMediaElement's seekable")
 [(2)](#ref-for-dfn-live-seekable-range-7 "Reference 2")
 [(3)](#ref-for-dfn-live-seekable-range-8 "Reference 3")
 [(4)](#ref-for-dfn-live-seekable-range-9 "Reference 4")

[Permalink](#dfn-has-ever-been-attached)

**Referenced in:**

- [§ 3.15.1 Attaching to a media
 element](#ref-for-dfn-has-ever-been-attached-1 "§ 3.15.1 Attaching to a media element")
 [(2)](#ref-for-dfn-has-ever-been-attached-2 "Reference 2")

[Permalink](#dom-readystate)
[exported]

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-readystate-1 "§ 3. MediaSource interface")
- [§ 3.15.3 Seeking](#ref-for-dom-readystate-2 "§ 3.15.3 Seeking")
 [(2)](#ref-for-dom-readystate-3 "Reference 2")
 [(3)](#ref-for-dom-readystate-4 "Reference 3")
 [(4)](#ref-for-dom-readystate-5 "Reference 4")
- [§ 3.15.4 SourceBuffer
 Monitoring](#ref-for-dom-readystate-6 "§ 3.15.4 SourceBuffer Monitoring")
 [(2)](#ref-for-dom-readystate-7 "Reference 2")
 [(3)](#ref-for-dom-readystate-8 "Reference 3")
 [(4)](#ref-for-dom-readystate-9 "Reference 4")
 [(5)](#ref-for-dom-readystate-10 "Reference 5")
 [(6)](#ref-for-dom-readystate-11 "Reference 6")
 [(7)](#ref-for-dom-readystate-12 "Reference 7")
 [(8)](#ref-for-dom-readystate-13 "Reference 8")
 [(9)](#ref-for-dom-readystate-14 "Reference 9")
 [(10)](#ref-for-dom-readystate-15 "Reference 10")
- [§ 3.15.7 End of
 stream](#ref-for-dom-readystate-16 "§ 3.15.7 End of stream")
 [(2)](#ref-for-dom-readystate-17 "Reference 2")
 [(3)](#ref-for-dom-readystate-18 "Reference 3")
 [(4)](#ref-for-dom-readystate-19 "Reference 4")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dom-readystate-20 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dom-readystate-21 "Reference 2")
 [(3)](#ref-for-dom-readystate-22 "Reference 3")
 [(4)](#ref-for-dom-readystate-23 "Reference 4")
 [(5)](#ref-for-dom-readystate-24 "Reference 5")
 [(6)](#ref-for-dom-readystate-25 "Reference 6")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dom-readystate-26 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-dom-readystate-27 "Reference 2")
 [(3)](#ref-for-dom-readystate-28 "Reference 3")
 [(4)](#ref-for-dom-readystate-29 "Reference 4")
 [(5)](#ref-for-dom-readystate-30 "Reference 5")
 [(6)](#ref-for-dom-readystate-31 "Reference 6")
 [(7)](#ref-for-dom-readystate-32 "Reference 7")
 [(8)](#ref-for-dom-readystate-33 "Reference 8")
 [(9)](#ref-for-dom-readystate-34 "Reference 9")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-dom-readystate-35 "§ 5.5.9 Coded Frame Removal")
 [(2)](#ref-for-dom-readystate-36 "Reference 2")
 [(3)](#ref-for-dom-readystate-37 "Reference 3")

[Permalink](#dom-readystate-closed)
[exported]
[IDL](#webidl-26865842 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-readystate-closed-1 "§ 3. MediaSource interface")
- [§ 3.2 sourceBuffers
 attribute](#ref-for-dom-readystate-closed-2 "§ 3.2 sourceBuffers attribute")
- [§ 3.4 readyState
 attribute](#ref-for-dom-readystate-closed-3 "§ 3.4 readyState attribute")
- [§ 3.5 duration
 attribute](#ref-for-dom-readystate-closed-4 "§ 3.5 duration attribute")
- [§ 3.13 Event
 Summary](#ref-for-dom-readystate-closed-5 "§ 3.13 Event Summary")
 [(2)](#ref-for-dom-readystate-closed-6 "Reference 2")
 [(3)](#ref-for-dom-readystate-closed-7 "Reference 3")
- [§ 3.15.1 Attaching to a media
 element](#ref-for-dom-readystate-closed-8 "§ 3.15.1 Attaching to a media element")
- [§ 3.15.2 Detaching from a media
 element](#ref-for-dom-readystate-closed-9 "§ 3.15.2 Detaching from a media element")

[Permalink](#dom-readystate-open)
[exported]
[IDL](#webidl-26865842 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-readystate-open-1 "§ 3. MediaSource interface")
- [§ 3.2 sourceBuffers
 attribute](#ref-for-dom-readystate-open-2 "§ 3.2 sourceBuffers attribute")
- [§ 3.5 duration
 attribute](#ref-for-dom-readystate-open-3 "§ 3.5 duration attribute")
- [§ 3.7 addSourceBuffer()
 method](#ref-for-dom-readystate-open-4 "§ 3.7 addSourceBuffer() method")
- [§ 3.9 endOfStream()
 method](#ref-for-dom-readystate-open-5 "§ 3.9 endOfStream() method")
- [§ 3.10 setLiveSeekableRange()
 method](#ref-for-dom-readystate-open-6 "§ 3.10 setLiveSeekableRange() method")
- [§ 3.11 clearLiveSeekableRange()
 method](#ref-for-dom-readystate-open-7 "§ 3.11 clearLiveSeekableRange() method")
- [§ 3.13 Event
 Summary](#ref-for-dom-readystate-open-8 "§ 3.13 Event Summary")
 [(2)](#ref-for-dom-readystate-open-9 "Reference 2")
 [(3)](#ref-for-dom-readystate-open-10 "Reference 3")
 [(4)](#ref-for-dom-readystate-open-11 "Reference 4")
- [§ 3.15.1 Attaching to a media
 element](#ref-for-dom-readystate-open-12 "§ 3.15.1 Attaching to a media element")
 [(2)](#ref-for-dom-readystate-open-13 "Reference 2")
- [§ 5.1 Attributes](#ref-for-dom-readystate-open-14 "§ 5.1 Attributes")
 [(2)](#ref-for-dom-readystate-open-15 "Reference 2")
- [§ 5.2 Methods](#ref-for-dom-readystate-open-16 "§ 5.2 Methods")
 [(2)](#ref-for-dom-readystate-open-17 "Reference 2")
 [(3)](#ref-for-dom-readystate-open-18 "Reference 3")
- [§ 5.5.4 Prepare
 Append](#ref-for-dom-readystate-open-19 "§ 5.5.4 Prepare Append")

[Permalink](#dom-readystate-ended)
[exported]
[IDL](#webidl-26865842 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-readystate-ended-1 "§ 3. MediaSource interface")
- [§ 3.13 Event
 Summary](#ref-for-dom-readystate-ended-2 "§ 3.13 Event Summary")
 [(2)](#ref-for-dom-readystate-ended-3 "Reference 2")
 [(3)](#ref-for-dom-readystate-ended-4 "Reference 3")
- [§ 3.15.3 Seeking](#ref-for-dom-readystate-ended-5 "§ 3.15.3 Seeking")
 [(2)](#ref-for-dom-readystate-ended-6 "Reference 2")
- [§ 3.15.7 End of
 stream](#ref-for-dom-readystate-ended-7 "§ 3.15.7 End of stream")
- [§ 5.1 Attributes](#ref-for-dom-readystate-ended-8 "§ 5.1 Attributes")
 [(2)](#ref-for-dom-readystate-ended-9 "Reference 2")
 [(3)](#ref-for-dom-readystate-ended-10 "Reference 3")
- [§ 5.2 Methods](#ref-for-dom-readystate-ended-11 "§ 5.2 Methods")
 [(2)](#ref-for-dom-readystate-ended-12 "Reference 2")
- [§ 5.5.4 Prepare
 Append](#ref-for-dom-readystate-ended-13 "§ 5.5.4 Prepare Append")
- [§ 10.2 HTMLMediaElement\'s
 buffered](#ref-for-dom-readystate-ended-14 "§ 10.2 HTMLMediaElement's buffered")

[Permalink](#dom-endofstreamerror)
[exported]

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-endofstreamerror-1 "§ 3. MediaSource interface")

[Permalink](#dom-endofstreamerror-network)
[exported]
[IDL](#webidl-1031259774 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-endofstreamerror-network-1 "§ 3. MediaSource interface")
- [§ 3.15.7 End of
 stream](#ref-for-dom-endofstreamerror-network-2 "§ 3.15.7 End of stream")

[Permalink](#dom-endofstreamerror-decode)
[exported]
[IDL](#webidl-1031259774 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-endofstreamerror-decode-1 "§ 3. MediaSource interface")
- [§ 3.15.7 End of
 stream](#ref-for-dom-endofstreamerror-decode-2 "§ 3.15.7 End of stream")
- [§ 5.5.3 Append
 Error](#ref-for-dom-endofstreamerror-decode-3 "§ 5.5.3 Append Error")

[Permalink](#dom-mediasource-constructor)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-mediasource-onsourceopen)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-mediasource-onsourceended)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-mediasource-onsourceclose)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-mediasource-handle)
[exported]
[IDL](#webidl-1502719514 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-mediasource-handle-1 "§ 3. MediaSource interface")
- [§ 3.15.1 Attaching to a media
 element](#ref-for-dom-mediasource-handle-2 "§ 3.15.1 Attaching to a media element")
 [(2)](#ref-for-dom-mediasource-handle-3 "Reference 2")

[Permalink](#dom-mediasource-sourcebuffers)
[exported]
[IDL](#webidl-1502719514 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-mediasource-sourcebuffers-1 "§ 3. MediaSource interface")
 [(2)](#ref-for-dom-mediasource-sourcebuffers-2 "Reference 2")
 [(3)](#ref-for-dom-mediasource-sourcebuffers-3 "Reference 3")
- [§ 3.3 activeSourceBuffers
 attribute](#ref-for-dom-mediasource-sourcebuffers-4 "§ 3.3 activeSourceBuffers attribute")
 [(2)](#ref-for-dom-mediasource-sourcebuffers-5 "Reference 2")
- [§ 3.5 duration
 attribute](#ref-for-dom-mediasource-sourcebuffers-6 "§ 3.5 duration attribute")
- [§ 3.7 addSourceBuffer()
 method](#ref-for-dom-mediasource-sourcebuffers-7 "§ 3.7 addSourceBuffer() method")
 [(2)](#ref-for-dom-mediasource-sourcebuffers-8 "Reference 2")
 [(3)](#ref-for-dom-mediasource-sourcebuffers-9 "Reference 3")
 [(4)](#ref-for-dom-mediasource-sourcebuffers-10 "Reference 4")
- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dom-mediasource-sourcebuffers-11 "§ 3.8 removeSourceBuffer() method")
 [(2)](#ref-for-dom-mediasource-sourcebuffers-12 "Reference 2")
 [(3)](#ref-for-dom-mediasource-sourcebuffers-13 "Reference 3")
 [(4)](#ref-for-dom-mediasource-sourcebuffers-14 "Reference 4")
- [§ 3.9 endOfStream()
 method](#ref-for-dom-mediasource-sourcebuffers-15 "§ 3.9 endOfStream() method")
- [§ 3.15.2 Detaching from a media
 element](#ref-for-dom-mediasource-sourcebuffers-16 "§ 3.15.2 Detaching from a media element")
 [(2)](#ref-for-dom-mediasource-sourcebuffers-17 "Reference 2")
- [§ 3.15.6 Duration
 change](#ref-for-dom-mediasource-sourcebuffers-18 "§ 3.15.6 Duration change")
 [(2)](#ref-for-dom-mediasource-sourcebuffers-19 "Reference 2")
- [§ 3.15.7 End of
 stream](#ref-for-dom-mediasource-sourcebuffers-20 "§ 3.15.7 End of stream")
- [§ 5.1
 Attributes](#ref-for-dom-mediasource-sourcebuffers-21 "§ 5.1 Attributes")
 [(2)](#ref-for-dom-mediasource-sourcebuffers-22 "Reference 2")
 [(3)](#ref-for-dom-mediasource-sourcebuffers-23 "Reference 3")
 [(4)](#ref-for-dom-mediasource-sourcebuffers-24 "Reference 4")
 [(5)](#ref-for-dom-mediasource-sourcebuffers-25 "Reference 5")
- [§ 5.2
 Methods](#ref-for-dom-mediasource-sourcebuffers-26 "§ 5.2 Methods")
 [(2)](#ref-for-dom-mediasource-sourcebuffers-27 "Reference 2")
 [(3)](#ref-for-dom-mediasource-sourcebuffers-28 "Reference 3")
 [(4)](#ref-for-dom-mediasource-sourcebuffers-29 "Reference 4")
- [§ 5.5.4 Prepare
 Append](#ref-for-dom-mediasource-sourcebuffers-30 "§ 5.5.4 Prepare Append")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dom-mediasource-sourcebuffers-31 "§ 5.5.7 Initialization Segment Received")
- [§ 7. ManagedMediaSource
 interface](#ref-for-dom-mediasource-sourcebuffers-32 "§ 7. ManagedMediaSource interface")
- [§ 7.3.2 Memory
 Cleanup](#ref-for-dom-mediasource-sourcebuffers-33 "§ 7.3.2 Memory Cleanup")
- [§
 Attributes](#ref-for-dom-mediasource-sourcebuffers-34 "§ Attributes")
 [(2)](#ref-for-dom-mediasource-sourcebuffers-35 "Reference 2")
 [(3)](#ref-for-dom-mediasource-sourcebuffers-36 "Reference 3")

[Permalink](#dom-mediasource-activesourcebuffers)
[exported]
[IDL](#webidl-1502719514 "Jump to IDL declaration")

**Referenced in:**

- [§ 2.
 Definitions](#ref-for-dom-mediasource-activesourcebuffers-1 "§ 2. Definitions")
- [§ 3. MediaSource
 interface](#ref-for-dom-mediasource-activesourcebuffers-2 "§ 3. MediaSource interface")
- [§ 3.3 activeSourceBuffers
 attribute](#ref-for-dom-mediasource-activesourcebuffers-3 "§ 3.3 activeSourceBuffers attribute")
- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dom-mediasource-activesourcebuffers-4 "§ 3.8 removeSourceBuffer() method")
 [(2)](#ref-for-dom-mediasource-activesourcebuffers-5 "Reference 2")
 [(3)](#ref-for-dom-mediasource-activesourcebuffers-6 "Reference 3")
- [§ 3.15.2 Detaching from a media
 element](#ref-for-dom-mediasource-activesourcebuffers-7 "§ 3.15.2 Detaching from a media element")
 [(2)](#ref-for-dom-mediasource-activesourcebuffers-8 "Reference 2")
- [§ 3.15.3
 Seeking](#ref-for-dom-mediasource-activesourcebuffers-9 "§ 3.15.3 Seeking")
- [§ 3.15.4 SourceBuffer
 Monitoring](#ref-for-dom-mediasource-activesourcebuffers-10 "§ 3.15.4 SourceBuffer Monitoring")
 [(2)](#ref-for-dom-mediasource-activesourcebuffers-11 "Reference 2")
- [§ 3.15.5 Changes to selected/enabled track
 state](#ref-for-dom-mediasource-activesourcebuffers-12 "§ 3.15.5 Changes to selected/enabled track state")
 [(2)](#ref-for-dom-mediasource-activesourcebuffers-13 "Reference 2")
 [(3)](#ref-for-dom-mediasource-activesourcebuffers-14 "Reference 3")
 [(4)](#ref-for-dom-mediasource-activesourcebuffers-15 "Reference 4")
 [(5)](#ref-for-dom-mediasource-activesourcebuffers-16 "Reference 5")
 [(6)](#ref-for-dom-mediasource-activesourcebuffers-17 "Reference 6")
 [(7)](#ref-for-dom-mediasource-activesourcebuffers-18 "Reference 7")
 [(8)](#ref-for-dom-mediasource-activesourcebuffers-19 "Reference 8")
 [(9)](#ref-for-dom-mediasource-activesourcebuffers-20 "Reference 9")
 [(10)](#ref-for-dom-mediasource-activesourcebuffers-21 "Reference 10")
 [(11)](#ref-for-dom-mediasource-activesourcebuffers-22 "Reference 11")
 [(12)](#ref-for-dom-mediasource-activesourcebuffers-23 "Reference 12")
 [(13)](#ref-for-dom-mediasource-activesourcebuffers-24 "Reference 13")
 [(14)](#ref-for-dom-mediasource-activesourcebuffers-25 "Reference 14")
 [(15)](#ref-for-dom-mediasource-activesourcebuffers-26 "Reference 15")
 [(16)](#ref-for-dom-mediasource-activesourcebuffers-27 "Reference 16")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dom-mediasource-activesourcebuffers-28 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dom-mediasource-activesourcebuffers-29 "Reference 2")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-dom-mediasource-activesourcebuffers-30 "§ 5.5.9 Coded Frame Removal")
- [§ 9.3.2 Memory
 cleanup](#ref-for-dom-mediasource-activesourcebuffers-31 "§ 9.3.2 Memory cleanup")
- [§ 10.2 HTMLMediaElement\'s
 buffered](#ref-for-dom-mediasource-activesourcebuffers-32 "§ 10.2 HTMLMediaElement's buffered")
 [(2)](#ref-for-dom-mediasource-activesourcebuffers-33 "Reference 2")
 [(3)](#ref-for-dom-mediasource-activesourcebuffers-34 "Reference 3")
 [(4)](#ref-for-dom-mediasource-activesourcebuffers-35 "Reference 4")
 [(5)](#ref-for-dom-mediasource-activesourcebuffers-36 "Reference 5")

[Permalink](#dom-mediasource-readystate)
[exported]
[IDL](#webidl-1502719514 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-mediasource-readystate-1 "§ 3. MediaSource interface")
 [(2)](#ref-for-dom-mediasource-readystate-2 "Reference 2")
 [(3)](#ref-for-dom-mediasource-readystate-3 "Reference 3")
- [§ 3.2 sourceBuffers
 attribute](#ref-for-dom-mediasource-readystate-4 "§ 3.2 sourceBuffers attribute")
 [(2)](#ref-for-dom-mediasource-readystate-5 "Reference 2")
- [§ 3.4 readyState
 attribute](#ref-for-dom-mediasource-readystate-6 "§ 3.4 readyState attribute")
- [§ 3.5 duration
 attribute](#ref-for-dom-mediasource-readystate-7 "§ 3.5 duration attribute")
 [(2)](#ref-for-dom-mediasource-readystate-8 "Reference 2")
- [§ 3.7 addSourceBuffer()
 method](#ref-for-dom-mediasource-readystate-9 "§ 3.7 addSourceBuffer() method")
- [§ 3.9 endOfStream()
 method](#ref-for-dom-mediasource-readystate-10 "§ 3.9 endOfStream() method")
- [§ 3.10 setLiveSeekableRange()
 method](#ref-for-dom-mediasource-readystate-11 "§ 3.10 setLiveSeekableRange() method")
- [§ 3.11 clearLiveSeekableRange()
 method](#ref-for-dom-mediasource-readystate-12 "§ 3.11 clearLiveSeekableRange() method")
- [§ 3.13 Event
 Summary](#ref-for-dom-mediasource-readystate-13 "§ 3.13 Event Summary")
 [(2)](#ref-for-dom-mediasource-readystate-14 "Reference 2")
 [(3)](#ref-for-dom-mediasource-readystate-15 "Reference 3")
- [§ 3.15.1 Attaching to a media
 element](#ref-for-dom-mediasource-readystate-16 "§ 3.15.1 Attaching to a media element")
 [(2)](#ref-for-dom-mediasource-readystate-17 "Reference 2")
 [(3)](#ref-for-dom-mediasource-readystate-18 "Reference 3")
- [§ 3.15.2 Detaching from a media
 element](#ref-for-dom-mediasource-readystate-19 "§ 3.15.2 Detaching from a media element")
- [§ 3.15.3
 Seeking](#ref-for-dom-mediasource-readystate-20 "§ 3.15.3 Seeking")
 [(2)](#ref-for-dom-mediasource-readystate-21 "Reference 2")
- [§ 3.15.7 End of
 stream](#ref-for-dom-mediasource-readystate-22 "§ 3.15.7 End of stream")
- [§ 5.1
 Attributes](#ref-for-dom-mediasource-readystate-23 "§ 5.1 Attributes")
 [(2)](#ref-for-dom-mediasource-readystate-24 "Reference 2")
 [(3)](#ref-for-dom-mediasource-readystate-25 "Reference 3")
 [(4)](#ref-for-dom-mediasource-readystate-26 "Reference 4")
 [(5)](#ref-for-dom-mediasource-readystate-27 "Reference 5")
- [§ 5.2
 Methods](#ref-for-dom-mediasource-readystate-28 "§ 5.2 Methods")
 [(2)](#ref-for-dom-mediasource-readystate-29 "Reference 2")
 [(3)](#ref-for-dom-mediasource-readystate-30 "Reference 3")
 [(4)](#ref-for-dom-mediasource-readystate-31 "Reference 4")
 [(5)](#ref-for-dom-mediasource-readystate-32 "Reference 5")
- [§ 5.5.4 Prepare
 Append](#ref-for-dom-mediasource-readystate-33 "§ 5.5.4 Prepare Append")
 [(2)](#ref-for-dom-mediasource-readystate-34 "Reference 2")
- [§ 10.2 HTMLMediaElement\'s
 buffered](#ref-for-dom-mediasource-readystate-35 "§ 10.2 HTMLMediaElement's buffered")
 [(2)](#ref-for-dom-mediasource-readystate-36 "Reference 2")

[Permalink](#dom-mediasource-duration)
[exported]
[IDL](#webidl-1502719514 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-mediasource-duration-1 "§ 3. MediaSource interface")
- [§ 3.15.2 Detaching from a media
 element](#ref-for-dom-mediasource-duration-2 "§ 3.15.2 Detaching from a media element")
- [§ 3.15.6 Duration
 change](#ref-for-dom-mediasource-duration-3 "§ 3.15.6 Duration change")
 [(2)](#ref-for-dom-mediasource-duration-4 "Reference 2")
 [(3)](#ref-for-dom-mediasource-duration-5 "Reference 3")
 [(4)](#ref-for-dom-mediasource-duration-6 "Reference 4")
- [§ 5.2 Methods](#ref-for-dom-mediasource-duration-7 "§ 5.2 Methods")
 [(2)](#ref-for-dom-mediasource-duration-8 "Reference 2")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dom-mediasource-duration-9 "§ 5.5.7 Initialization Segment Received")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dom-mediasource-duration-10 "§ 5.5.8 Coded Frame Processing")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-dom-mediasource-duration-11 "§ 5.5.9 Coded Frame Removal")
- [§ 10.1 HTMLMediaElement\'s
 seekable](#ref-for-dom-mediasource-duration-12 "§ 10.1 HTMLMediaElement's seekable")
 [(2)](#ref-for-dom-mediasource-duration-13 "Reference 2")
 [(3)](#ref-for-dom-mediasource-duration-14 "Reference 3")
 [(4)](#ref-for-dom-mediasource-duration-15 "Reference 4")

[Permalink](#dom-mediasource-canconstructindedicatedworker)
[exported]
[IDL](#webidl-1502719514 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-mediasource-canconstructindedicatedworker-1 "§ 3. MediaSource interface")

[Permalink](#dom-mediasource-addsourcebuffer)
[exported]
[IDL](#webidl-1502719514 "Jump to IDL declaration")

**Referenced in:**

- [§ 2.
 Definitions](#ref-for-dom-mediasource-addsourcebuffer-1 "§ 2. Definitions")
- [§ 3. MediaSource
 interface](#ref-for-dom-mediasource-addsourcebuffer-2 "§ 3. MediaSource interface")
- [§ 3.2 sourceBuffers
 attribute](#ref-for-dom-mediasource-addsourcebuffer-3 "§ 3.2 sourceBuffers attribute")
- [§ 3.12 isTypeSupported()
 method](#ref-for-dom-mediasource-addsourcebuffer-4 "§ 3.12 isTypeSupported() method")
- [§ 5.1
 Attributes](#ref-for-dom-mediasource-addsourcebuffer-5 "§ 5.1 Attributes")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dom-mediasource-addsourcebuffer-6 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dom-mediasource-addsourcebuffer-7 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dom-mediasource-addsourcebuffer-8 "Reference 2")
 [(3)](#ref-for-dom-mediasource-addsourcebuffer-9 "Reference 3")
 [(4)](#ref-for-dom-mediasource-addsourcebuffer-10 "Reference 4")
 [(5)](#ref-for-dom-mediasource-addsourcebuffer-11 "Reference 5")
- [§ 14. Byte Stream
 Formats](#ref-for-dom-mediasource-addsourcebuffer-12 "§ 14. Byte Stream Formats")
 [(2)](#ref-for-dom-mediasource-addsourcebuffer-13 "Reference 2")

[Permalink](#dom-mediasource-removesourcebuffer)
[exported]
[IDL](#webidl-1502719514 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-mediasource-removesourcebuffer-1 "§ 3. MediaSource interface")

[Permalink](#dom-mediasource-endofstream)
[exported]
[IDL](#webidl-1502719514 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-mediasource-endofstream-1 "§ 3. MediaSource interface")
 [(2)](#ref-for-dom-mediasource-endofstream-2 "Reference 2")
- [§ 3.5 duration
 attribute](#ref-for-dom-mediasource-endofstream-3 "§ 3.5 duration attribute")
- [§ 3.15.7 End of
 stream](#ref-for-dom-mediasource-endofstream-4 "§ 3.15.7 End of stream")
- [§ 9.2 Event
 Summary](#ref-for-dom-mediasource-endofstream-5 "§ 9.2 Event Summary")

[Permalink](#dom-mediasource-setliveseekablerange)
[exported]
[IDL](#webidl-1502719514 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-mediasource-setliveseekablerange-1 "§ 3. MediaSource interface")
 [(2)](#ref-for-dom-mediasource-setliveseekablerange-2 "Reference 2")

[Permalink](#dom-mediasource-clearliveseekablerange)
[exported]
[IDL](#webidl-1502719514 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-mediasource-clearliveseekablerange-1 "§ 3. MediaSource interface")
 [(2)](#ref-for-dom-mediasource-clearliveseekablerange-2 "Reference 2")

[Permalink](#dom-mediasource-istypesupported)
[exported]
[IDL](#webidl-1502719514 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-mediasource-istypesupported-1 "§ 3. MediaSource interface")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dom-mediasource-istypesupported-2 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dom-mediasource-istypesupported-3 "Reference 2")
- [§ 14. Byte Stream
 Formats](#ref-for-dom-mediasource-istypesupported-4 "§ 14. Byte Stream Formats")

[Permalink](#dfn-sourceopen)

**Referenced in:**

- [§ 3.15.1 Attaching to a media
 element](#ref-for-dfn-sourceopen-1 "§ 3.15.1 Attaching to a media element")
 [(2)](#ref-for-dfn-sourceopen-2 "Reference 2")
- [§ 5.1 Attributes](#ref-for-dfn-sourceopen-3 "§ 5.1 Attributes")
 [(2)](#ref-for-dfn-sourceopen-4 "Reference 2")
- [§ 5.2 Methods](#ref-for-dfn-sourceopen-5 "§ 5.2 Methods")
 [(2)](#ref-for-dfn-sourceopen-6 "Reference 2")
- [§ 5.5.4 Prepare
 Append](#ref-for-dfn-sourceopen-7 "§ 5.5.4 Prepare Append")

[Permalink](#dfn-sourceended)

**Referenced in:**

- [§ 3.15.7 End of
 stream](#ref-for-dfn-sourceended-1 "§ 3.15.7 End of stream")

[Permalink](#dfn-sourceclose)

**Referenced in:**

- [§ 3.15.2 Detaching from a media
 element](#ref-for-dfn-sourceclose-1 "§ 3.15.2 Detaching from a media element")

[Permalink](#dfn-cross-context-communication-model)

**Referenced in:**

- [§ 4.1
 Transfer](#ref-for-dfn-cross-context-communication-model-1 "§ 4.1 Transfer")
- [§ 10.2 HTMLMediaElement\'s
 buffered](#ref-for-dfn-cross-context-communication-model-2 "§ 10.2 HTMLMediaElement's buffered")

[Permalink](#dfn-port-to-main)

**Referenced in:**

- [§ 3.14 Cross-context communication
 model](#ref-for-dfn-port-to-main-1 "§ 3.14 Cross-context communication model")
- [§ 3.15.1 Attaching to a media
 element](#ref-for-dfn-port-to-main-2 "§ 3.15.1 Attaching to a media element")
 [(2)](#ref-for-dfn-port-to-main-3 "Reference 2")
- [§ 3.15.2 Detaching from a media
 element](#ref-for-dfn-port-to-main-4 "§ 3.15.2 Detaching from a media element")
- [§ 3.15.5 Changes to selected/enabled track
 state](#ref-for-dfn-port-to-main-5 "§ 3.15.5 Changes to selected/enabled track state")
- [§ 3.15.8 Mirror if
 necessary](#ref-for-dfn-port-to-main-6 "§ 3.15.8 Mirror if necessary")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dfn-port-to-main-7 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dfn-port-to-main-8 "Reference 2")
 [(3)](#ref-for-dfn-port-to-main-9 "Reference 3")
- [§ 10.1 HTMLMediaElement\'s
 seekable](#ref-for-dfn-port-to-main-10 "§ 10.1 HTMLMediaElement's seekable")
- [§ 10.2 HTMLMediaElement\'s
 buffered](#ref-for-dfn-port-to-main-11 "§ 10.2 HTMLMediaElement's buffered")

[Permalink](#dfn-port-to-worker)

**Referenced in:**

- [§ 3.14 Cross-context communication
 model](#ref-for-dfn-port-to-worker-1 "§ 3.14 Cross-context communication model")
- [§ 3.15.1 Attaching to a media
 element](#ref-for-dfn-port-to-worker-2 "§ 3.15.1 Attaching to a media element")
 [(2)](#ref-for-dfn-port-to-worker-3 "Reference 2")
- [§ 3.15.2 Detaching from a media
 element](#ref-for-dfn-port-to-worker-4 "§ 3.15.2 Detaching from a media element")
 [(2)](#ref-for-dfn-port-to-worker-5 "Reference 2")
- [§ 3.15.5 Changes to selected/enabled track
 state](#ref-for-dfn-port-to-worker-6 "§ 3.15.5 Changes to selected/enabled track state")
- [§ 5.5.4 Prepare
 Append](#ref-for-dfn-port-to-worker-7 "§ 5.5.4 Prepare Append")

[Permalink](#dfn-channel-with-worker)

**Referenced in:**

- [§ 3.14 Cross-context communication
 model](#ref-for-dfn-channel-with-worker-1 "§ 3.14 Cross-context communication model")
- [§ 3.15.1 Attaching to a media
 element](#ref-for-dfn-channel-with-worker-2 "§ 3.15.1 Attaching to a media element")
 [(2)](#ref-for-dfn-channel-with-worker-3 "Reference 2")
 [(3)](#ref-for-dfn-channel-with-worker-4 "Reference 3")
 [(4)](#ref-for-dfn-channel-with-worker-5 "Reference 4")
 [(5)](#ref-for-dfn-channel-with-worker-6 "Reference 5")
- [§ 3.15.2 Detaching from a media
 element](#ref-for-dfn-channel-with-worker-7 "§ 3.15.2 Detaching from a media element")

[Permalink](#dfn-attaching-to-a-media-element)

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dfn-attaching-to-a-media-element-1 "§ 3. MediaSource interface")
- [§ 3.14 Cross-context communication
 model](#ref-for-dfn-attaching-to-a-media-element-2 "§ 3.14 Cross-context communication model")
- [§ 4. MediaSourceHandle
 interface](#ref-for-dfn-attaching-to-a-media-element-3 "§ 4. MediaSourceHandle interface")
- [§ 4.1
 Transfer](#ref-for-dfn-attaching-to-a-media-element-4 "§ 4.1 Transfer")
 [(2)](#ref-for-dfn-attaching-to-a-media-element-5 "Reference 2")
 [(3)](#ref-for-dfn-attaching-to-a-media-element-6 "Reference 3")

[Permalink](#dfn-detaching-from-a-media-element)

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-seeking)

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-sourcebuffer-monitoring)

**Referenced in:**

- [§ 7.3.1 ManagedSourceBuffer
 Monitoring](#ref-for-dfn-sourcebuffer-monitoring-1 "§ 7.3.1 ManagedSourceBuffer Monitoring")
 [(2)](#ref-for-dfn-sourcebuffer-monitoring-2 "Reference 2")

[Permalink](#enough-data)

**Referenced in:**

- [§ 3.15.4 SourceBuffer
 Monitoring](#ref-for-enough-data-1 "§ 3.15.4 SourceBuffer Monitoring")
 [(2)](#ref-for-enough-data-2 "Reference 2")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-enough-data-3 "§ 5.5.8 Coded Frame Processing")

[Permalink](#dfn-changes-to-selected-enabled-track-state)

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-duration-change)

**Referenced in:**

- [§ 3.5 duration
 attribute](#ref-for-dfn-duration-change-1 "§ 3.5 duration attribute")
 [(2)](#ref-for-dfn-duration-change-2 "Reference 2")
- [§ 3.15.7 End of
 stream](#ref-for-dfn-duration-change-3 "§ 3.15.7 End of stream")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dfn-duration-change-4 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dfn-duration-change-5 "Reference 2")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dfn-duration-change-6 "§ 5.5.8 Coded Frame Processing")

[Permalink](#dfn-end-of-stream)

**Referenced in:**

- [§ 3.9 endOfStream()
 method](#ref-for-dfn-end-of-stream-1 "§ 3.9 endOfStream() method")
- [§ 5.5.3 Append
 Error](#ref-for-dfn-end-of-stream-2 "§ 5.5.3 Append Error")

[Permalink](#dfn-mirror-if-necessary)

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dfn-mirror-if-necessary-1 "§ 3.8 removeSourceBuffer() method")
 [(2)](#ref-for-dfn-mirror-if-necessary-2 "Reference 2")
 [(3)](#ref-for-dfn-mirror-if-necessary-3 "Reference 3")
- [§ 3.15.6 Duration
 change](#ref-for-dfn-mirror-if-necessary-4 "§ 3.15.6 Duration change")
- [§ 3.15.7 End of
 stream](#ref-for-dfn-mirror-if-necessary-5 "§ 3.15.7 End of stream")
 [(2)](#ref-for-dfn-mirror-if-necessary-6 "Reference 2")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dfn-mirror-if-necessary-7 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dfn-mirror-if-necessary-8 "Reference 2")

[Permalink](#dom-mediasourcehandle)
[exported]
[IDL](#webidl-1737388085 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-mediasourcehandle-1 "§ 3. MediaSource interface")
 [(2)](#ref-for-dom-mediasourcehandle-2 "Reference 2")
- [§ 3.1 handle
 attribute](#ref-for-dom-mediasourcehandle-3 "§ 3.1 handle attribute")
 [(2)](#ref-for-dom-mediasourcehandle-4 "Reference 2")
- [§ 3.14 Cross-context communication
 model](#ref-for-dom-mediasourcehandle-5 "§ 3.14 Cross-context communication model")
- [§ 3.15.1 Attaching to a media
 element](#ref-for-dom-mediasourcehandle-6 "§ 3.15.1 Attaching to a media element")
 [(2)](#ref-for-dom-mediasourcehandle-7 "Reference 2")
 [(3)](#ref-for-dom-mediasourcehandle-8 "Reference 3")
 [(4)](#ref-for-dom-mediasourcehandle-9 "Reference 4")
 [(5)](#ref-for-dom-mediasourcehandle-10 "Reference 5")
 [(6)](#ref-for-dom-mediasourcehandle-11 "Reference 6")
 [(7)](#ref-for-dom-mediasourcehandle-12 "Reference 7")
- [§ 4. MediaSourceHandle
 interface](#ref-for-dom-mediasourcehandle-13 "§ 4. MediaSourceHandle interface")
 [(2)](#ref-for-dom-mediasourcehandle-14 "Reference 2")
 [(3)](#ref-for-dom-mediasourcehandle-15 "Reference 3")
 [(4)](#ref-for-dom-mediasourcehandle-16 "Reference 4")
 [(5)](#ref-for-dom-mediasourcehandle-17 "Reference 5")
 [(6)](#ref-for-dom-mediasourcehandle-18 "Reference 6")
- [§ 4.1 Transfer](#ref-for-dom-mediasourcehandle-19 "§ 4.1 Transfer")
 [(2)](#ref-for-dom-mediasourcehandle-20 "Reference 2")
 [(3)](#ref-for-dom-mediasourcehandle-21 "Reference 3")
 [(4)](#ref-for-dom-mediasourcehandle-22 "Reference 4")
 [(5)](#ref-for-dom-mediasourcehandle-23 "Reference 5")
 [(6)](#ref-for-dom-mediasourcehandle-24 "Reference 6")
 [(7)](#ref-for-dom-mediasourcehandle-25 "Reference 7")
 [(8)](#ref-for-dom-mediasourcehandle-26 "Reference 8")
 [(9)](#ref-for-dom-mediasourcehandle-27 "Reference 9")
 [(10)](#ref-for-dom-mediasourcehandle-28 "Reference 10")
- [§ 10. HTMLMediaElement
 Extensions](#ref-for-dom-mediasourcehandle-29 "§ 10. HTMLMediaElement Extensions")
- [§ 10.3 HTMLMediaElement\'s
 srcObject](#ref-for-dom-mediasourcehandle-30 "§ 10.3 HTMLMediaElement's srcObject")
 [(2)](#ref-for-dom-mediasourcehandle-31 "Reference 2")
 [(3)](#ref-for-dom-mediasourcehandle-32 "Reference 3")
 [(4)](#ref-for-dom-mediasourcehandle-33 "Reference 4")

[Permalink](#dfn-has-ever-been-assigned-as-srcobject)

**Referenced in:**

- [§ 4.1
 Transfer](#ref-for-dfn-has-ever-been-assigned-as-srcobject-1 "§ 4.1 Transfer")
- [§ 10.3 HTMLMediaElement\'s
 srcObject](#ref-for-dfn-has-ever-been-assigned-as-srcobject-2 "§ 10.3 HTMLMediaElement's srcObject")

[Permalink](#dfn-detached)

**Referenced in:**

- [§ 3.15.1 Attaching to a media
 element](#ref-for-dfn-detached-1 "§ 3.15.1 Attaching to a media element")

[Permalink](#dom-sourcebuffer)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 1. Introduction](#ref-for-dom-sourcebuffer-1 "§ 1. Introduction")
 [(2)](#ref-for-dom-sourcebuffer-2 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-3 "Reference 3")
- [§ 2. Definitions](#ref-for-dom-sourcebuffer-4 "§ 2. Definitions")
 [(2)](#ref-for-dom-sourcebuffer-5 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-6 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-7 "Reference 4")
 [(5)](#ref-for-dom-sourcebuffer-8 "Reference 5")
 [(6)](#ref-for-dom-sourcebuffer-9 "Reference 6")
- [§ 3. MediaSource
 interface](#ref-for-dom-sourcebuffer-10 "§ 3. MediaSource interface")
 [(2)](#ref-for-dom-sourcebuffer-11 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-12 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-13 "Reference 4")
 [(5)](#ref-for-dom-sourcebuffer-14 "Reference 5")
 [(6)](#ref-for-dom-sourcebuffer-15 "Reference 6")
- [§ 3.2 sourceBuffers
 attribute](#ref-for-dom-sourcebuffer-16 "§ 3.2 sourceBuffers attribute")
- [§ 3.3 activeSourceBuffers
 attribute](#ref-for-dom-sourcebuffer-17 "§ 3.3 activeSourceBuffers attribute")
- [§ 3.5 duration
 attribute](#ref-for-dom-sourcebuffer-18 "§ 3.5 duration attribute")
- [§ 3.7 addSourceBuffer()
 method](#ref-for-dom-sourcebuffer-19 "§ 3.7 addSourceBuffer() method")
 [(2)](#ref-for-dom-sourcebuffer-20 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-21 "Reference 3")
- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dom-sourcebuffer-22 "§ 3.8 removeSourceBuffer() method")
- [§ 3.9 endOfStream()
 method](#ref-for-dom-sourcebuffer-23 "§ 3.9 endOfStream() method")
- [§ 3.12 isTypeSupported()
 method](#ref-for-dom-sourcebuffer-24 "§ 3.12 isTypeSupported() method")
 [(2)](#ref-for-dom-sourcebuffer-25 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-26 "Reference 3")
- [§ 3.15.2 Detaching from a media
 element](#ref-for-dom-sourcebuffer-27 "§ 3.15.2 Detaching from a media element")
 [(2)](#ref-for-dom-sourcebuffer-28 "Reference 2")
- [§ 3.15.3 Seeking](#ref-for-dom-sourcebuffer-29 "§ 3.15.3 Seeking")
- [§ 3.15.4 SourceBuffer
 Monitoring](#ref-for-dom-sourcebuffer-30 "§ 3.15.4 SourceBuffer Monitoring")
- [§ 3.15.5 Changes to selected/enabled track
 state](#ref-for-dom-sourcebuffer-31 "§ 3.15.5 Changes to selected/enabled track state")
 [(2)](#ref-for-dom-sourcebuffer-32 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-33 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-34 "Reference 4")
 [(5)](#ref-for-dom-sourcebuffer-35 "Reference 5")
 [(6)](#ref-for-dom-sourcebuffer-36 "Reference 6")
 [(7)](#ref-for-dom-sourcebuffer-37 "Reference 7")
 [(8)](#ref-for-dom-sourcebuffer-38 "Reference 8")
 [(9)](#ref-for-dom-sourcebuffer-39 "Reference 9")
 [(10)](#ref-for-dom-sourcebuffer-40 "Reference 10")
 [(11)](#ref-for-dom-sourcebuffer-41 "Reference 11")
 [(12)](#ref-for-dom-sourcebuffer-42 "Reference 12")
- [§ 3.15.6 Duration
 change](#ref-for-dom-sourcebuffer-43 "§ 3.15.6 Duration change")
 [(2)](#ref-for-dom-sourcebuffer-44 "Reference 2")
- [§ 3.15.7 End of
 stream](#ref-for-dom-sourcebuffer-45 "§ 3.15.7 End of stream")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-46 "§ 5. SourceBuffer interface")
- [§ 5.1 Attributes](#ref-for-dom-sourcebuffer-47 "§ 5.1 Attributes")
 [(2)](#ref-for-dom-sourcebuffer-48 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-49 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-50 "Reference 4")
- [§ 5.2 Methods](#ref-for-dom-sourcebuffer-51 "§ 5.2 Methods")
 [(2)](#ref-for-dom-sourcebuffer-52 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-53 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-54 "Reference 4")
 [(5)](#ref-for-dom-sourcebuffer-55 "Reference 5")
 [(6)](#ref-for-dom-sourcebuffer-56 "Reference 6")
 [(7)](#ref-for-dom-sourcebuffer-57 "Reference 7")
 [(8)](#ref-for-dom-sourcebuffer-58 "Reference 8")
 [(9)](#ref-for-dom-sourcebuffer-59 "Reference 9")
- [§ 5.3 Track
 Buffers](#ref-for-dom-sourcebuffer-60 "§ 5.3 Track Buffers")
 [(2)](#ref-for-dom-sourcebuffer-61 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-62 "Reference 3")
- [§ 5.4 Event
 Summary](#ref-for-dom-sourcebuffer-63 "§ 5.4 Event Summary")
 [(2)](#ref-for-dom-sourcebuffer-64 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-65 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-66 "Reference 4")
 [(5)](#ref-for-dom-sourcebuffer-67 "Reference 5")
 [(6)](#ref-for-dom-sourcebuffer-68 "Reference 6")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dom-sourcebuffer-69 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-dom-sourcebuffer-70 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-71 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-72 "Reference 4")
 [(5)](#ref-for-dom-sourcebuffer-73 "Reference 5")
 [(6)](#ref-for-dom-sourcebuffer-74 "Reference 6")
 [(7)](#ref-for-dom-sourcebuffer-75 "Reference 7")
 [(8)](#ref-for-dom-sourcebuffer-76 "Reference 8")
 [(9)](#ref-for-dom-sourcebuffer-77 "Reference 9")
 [(10)](#ref-for-dom-sourcebuffer-78 "Reference 10")
 [(11)](#ref-for-dom-sourcebuffer-79 "Reference 11")
- [§ 5.5.3 Append
 Error](#ref-for-dom-sourcebuffer-80 "§ 5.5.3 Append Error")
 [(2)](#ref-for-dom-sourcebuffer-81 "Reference 2")
- [§ 5.5.4 Prepare
 Append](#ref-for-dom-sourcebuffer-82 "§ 5.5.4 Prepare Append")
 [(2)](#ref-for-dom-sourcebuffer-83 "Reference 2")
- [§ 5.5.5 Buffer
 Append](#ref-for-dom-sourcebuffer-84 "§ 5.5.5 Buffer Append")
 [(2)](#ref-for-dom-sourcebuffer-85 "Reference 2")
- [§ 5.5.6 Range
 Removal](#ref-for-dom-sourcebuffer-86 "§ 5.5.6 Range Removal")
 [(2)](#ref-for-dom-sourcebuffer-87 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-88 "Reference 3")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dom-sourcebuffer-89 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dom-sourcebuffer-90 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-91 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-92 "Reference 4")
 [(5)](#ref-for-dom-sourcebuffer-93 "Reference 5")
 [(6)](#ref-for-dom-sourcebuffer-94 "Reference 6")
 [(7)](#ref-for-dom-sourcebuffer-95 "Reference 7")
 [(8)](#ref-for-dom-sourcebuffer-96 "Reference 8")
 [(9)](#ref-for-dom-sourcebuffer-97 "Reference 9")
 [(10)](#ref-for-dom-sourcebuffer-98 "Reference 10")
 [(11)](#ref-for-dom-sourcebuffer-99 "Reference 11")
 [(12)](#ref-for-dom-sourcebuffer-100 "Reference 12")
 [(13)](#ref-for-dom-sourcebuffer-101 "Reference 13")
 [(14)](#ref-for-dom-sourcebuffer-102 "Reference 14")
 [(15)](#ref-for-dom-sourcebuffer-103 "Reference 15")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-dom-sourcebuffer-104 "§ 5.5.9 Coded Frame Removal")
- [§ 5.5.10 Coded Frame
 Eviction](#ref-for-dom-sourcebuffer-105 "§ 5.5.10 Coded Frame Eviction")
 [(2)](#ref-for-dom-sourcebuffer-106 "Reference 2")
- [§ 6. SourceBufferList
 interface](#ref-for-dom-sourcebuffer-107 "§ 6. SourceBufferList interface")
 [(2)](#ref-for-dom-sourcebuffer-108 "Reference 2")
- [§ 6.1 Attributes](#ref-for-dom-sourcebuffer-109 "§ 6.1 Attributes")
- [§ 6.2 Methods](#ref-for-dom-sourcebuffer-110 "§ 6.2 Methods")
- [§ 6.3 Event
 Summary](#ref-for-dom-sourcebuffer-111 "§ 6.3 Event Summary")
 [(2)](#ref-for-dom-sourcebuffer-112 "Reference 2")
- [§ 9. ManagedSourceBuffer
 interface](#ref-for-dom-sourcebuffer-113 "§ 9. ManagedSourceBuffer interface")
- [§ 10.2 HTMLMediaElement\'s
 buffered](#ref-for-dom-sourcebuffer-114 "§ 10.2 HTMLMediaElement's buffered")
 [(2)](#ref-for-dom-sourcebuffer-115 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-116 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-117 "Reference 4")
- [§ 11. AudioTrack
 extensions](#ref-for-dom-sourcebuffer-118 "§ 11. AudioTrack extensions")
- [§ Attributes](#ref-for-dom-sourcebuffer-119 "§ Attributes")
 [(2)](#ref-for-dom-sourcebuffer-120 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-121 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-122 "Reference 4")
 [(5)](#ref-for-dom-sourcebuffer-123 "Reference 5")
 [(6)](#ref-for-dom-sourcebuffer-125 "Reference 6")
 [(7)](#ref-for-dom-sourcebuffer-126 "Reference 7")
 [(8)](#ref-for-dom-sourcebuffer-127 "Reference 8")
 [(9)](#ref-for-dom-sourcebuffer-128 "Reference 9")
 [(10)](#ref-for-dom-sourcebuffer-129 "Reference 10")
 [(11)](#ref-for-dom-sourcebuffer-131 "Reference 11")
 [(12)](#ref-for-dom-sourcebuffer-132 "Reference 12")
 [(13)](#ref-for-dom-sourcebuffer-133 "Reference 13")
 [(14)](#ref-for-dom-sourcebuffer-134 "Reference 14")
 [(15)](#ref-for-dom-sourcebuffer-135 "Reference 15")
- [§ 12. VideoTrack
 extensions](#ref-for-dom-sourcebuffer-124 "§ 12. VideoTrack extensions")
- [§ 13. TextTrack
 extensions](#ref-for-dom-sourcebuffer-130 "§ 13. TextTrack extensions")
- [§ 14. Byte Stream
 Formats](#ref-for-dom-sourcebuffer-136 "§ 14. Byte Stream Formats")
 [(2)](#ref-for-dom-sourcebuffer-137 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-138 "Reference 3")

[Permalink](#dom-appendmode)
[exported]

**Referenced in:**

- [§ 5. SourceBuffer
 interface](#ref-for-dom-appendmode-1 "§ 5. SourceBuffer interface")
- [§ 5.1 Attributes](#ref-for-dom-appendmode-2 "§ 5.1 Attributes")

[Permalink](#dom-appendmode-segments)
[exported]
[IDL](#webidl-955395090 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.7 addSourceBuffer()
 method](#ref-for-dom-appendmode-segments-1 "§ 3.7 addSourceBuffer() method")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-appendmode-segments-2 "§ 5. SourceBuffer interface")
- [§ 5.1
 Attributes](#ref-for-dom-appendmode-segments-3 "§ 5.1 Attributes")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dom-appendmode-segments-4 "§ 5.5.8 Coded Frame Processing")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-dom-appendmode-segments-5 "§ 5.5.9 Coded Frame Removal")

[Permalink](#dom-appendmode-sequence)
[exported]
[IDL](#webidl-955395090 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.7 addSourceBuffer()
 method](#ref-for-dom-appendmode-sequence-1 "§ 3.7 addSourceBuffer() method")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-appendmode-sequence-2 "§ 5. SourceBuffer interface")
 [(2)](#ref-for-dom-appendmode-sequence-3 "Reference 2")
- [§ 5.1
 Attributes](#ref-for-dom-appendmode-sequence-4 "§ 5.1 Attributes")
 [(2)](#ref-for-dom-appendmode-sequence-5 "Reference 2")
- [§ 5.2 Methods](#ref-for-dom-appendmode-sequence-6 "§ 5.2 Methods")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dom-appendmode-sequence-7 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-dom-appendmode-sequence-8 "Reference 2")
- [§ 5.5.2 Reset Parser
 State](#ref-for-dom-appendmode-sequence-9 "§ 5.5.2 Reset Parser State")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dom-appendmode-sequence-10 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-dom-appendmode-sequence-11 "Reference 2")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-dom-appendmode-sequence-12 "§ 5.5.9 Coded Frame Removal")

[Permalink](#dom-sourcebuffer-mode)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.7 addSourceBuffer()
 method](#ref-for-dom-sourcebuffer-mode-1 "§ 3.7 addSourceBuffer() method")
 [(2)](#ref-for-dom-sourcebuffer-mode-2 "Reference 2")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-mode-3 "§ 5. SourceBuffer interface")
- [§ 5.1
 Attributes](#ref-for-dom-sourcebuffer-mode-4 "§ 5.1 Attributes")
- [§ 5.2 Methods](#ref-for-dom-sourcebuffer-mode-5 "§ 5.2 Methods")
 [(2)](#ref-for-dom-sourcebuffer-mode-6 "Reference 2")
- [§ 5.3 Track
 Buffers](#ref-for-dom-sourcebuffer-mode-7 "§ 5.3 Track Buffers")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dom-sourcebuffer-mode-8 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-dom-sourcebuffer-mode-9 "Reference 2")
- [§ 5.5.2 Reset Parser
 State](#ref-for-dom-sourcebuffer-mode-10 "§ 5.5.2 Reset Parser State")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dom-sourcebuffer-mode-11 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-dom-sourcebuffer-mode-12 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-mode-13 "Reference 3")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-dom-sourcebuffer-mode-14 "§ 5.5.9 Coded Frame Removal")
 [(2)](#ref-for-dom-sourcebuffer-mode-15 "Reference 2")

[Permalink](#dom-sourcebuffer-updating)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.5 duration
 attribute](#ref-for-dom-sourcebuffer-updating-1 "§ 3.5 duration attribute")
- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dom-sourcebuffer-updating-2 "§ 3.8 removeSourceBuffer() method")
 [(2)](#ref-for-dom-sourcebuffer-updating-3 "Reference 2")
- [§ 3.9 endOfStream()
 method](#ref-for-dom-sourcebuffer-updating-4 "§ 3.9 endOfStream() method")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-updating-5 "§ 5. SourceBuffer interface")
- [§ 5.1
 Attributes](#ref-for-dom-sourcebuffer-updating-6 "§ 5.1 Attributes")
 [(2)](#ref-for-dom-sourcebuffer-updating-7 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-updating-8 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-updating-9 "Reference 4")
- [§ 5.2 Methods](#ref-for-dom-sourcebuffer-updating-10 "§ 5.2 Methods")
 [(2)](#ref-for-dom-sourcebuffer-updating-11 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-updating-12 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-updating-13 "Reference 4")
 [(5)](#ref-for-dom-sourcebuffer-updating-14 "Reference 5")
- [§ 5.4 Event
 Summary](#ref-for-dom-sourcebuffer-updating-15 "§ 5.4 Event Summary")
 [(2)](#ref-for-dom-sourcebuffer-updating-16 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-updating-17 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-updating-18 "Reference 4")
- [§ 5.5.3 Append
 Error](#ref-for-dom-sourcebuffer-updating-19 "§ 5.5.3 Append Error")
- [§ 5.5.4 Prepare
 Append](#ref-for-dom-sourcebuffer-updating-20 "§ 5.5.4 Prepare Append")
- [§ 5.5.5 Buffer
 Append](#ref-for-dom-sourcebuffer-updating-21 "§ 5.5.5 Buffer Append")
- [§ 5.5.6 Range
 Removal](#ref-for-dom-sourcebuffer-updating-22 "§ 5.5.6 Range Removal")
 [(2)](#ref-for-dom-sourcebuffer-updating-23 "Reference 2")

[Permalink](#dom-sourcebuffer-buffered)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.15.3
 Seeking](#ref-for-dom-sourcebuffer-buffered-1 "§ 3.15.3 Seeking")
 [(2)](#ref-for-dom-sourcebuffer-buffered-2 "Reference 2")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-buffered-3 "§ 5. SourceBuffer interface")
- [§ 5.5.10 Coded Frame
 Eviction](#ref-for-dom-sourcebuffer-buffered-4 "§ 5.5.10 Coded Frame Eviction")
- [§ 9.3.1 Buffered
 Change](#ref-for-dom-sourcebuffer-buffered-5 "§ 9.3.1 Buffered Change")
 [(2)](#ref-for-dom-sourcebuffer-buffered-6 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-buffered-7 "Reference 3")
- [§ 10.2 HTMLMediaElement\'s
 buffered](#ref-for-dom-sourcebuffer-buffered-8 "§ 10.2 HTMLMediaElement's buffered")
 [(2)](#ref-for-dom-sourcebuffer-buffered-9 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-buffered-10 "Reference 3")
- [§ 14. Byte Stream
 Formats](#ref-for-dom-sourcebuffer-buffered-11 "§ 14. Byte Stream Formats")

[Permalink](#dom-sourcebuffer-timestampoffset)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-timestampoffset-1 "§ 5. SourceBuffer interface")
 [(2)](#ref-for-dom-sourcebuffer-timestampoffset-2 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-timestampoffset-3 "Reference 3")
- [§ 5.1
 Attributes](#ref-for-dom-sourcebuffer-timestampoffset-4 "§ 5.1 Attributes")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dom-sourcebuffer-timestampoffset-5 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dom-sourcebuffer-timestampoffset-6 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-dom-sourcebuffer-timestampoffset-7 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-timestampoffset-8 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-timestampoffset-9 "Reference 4")
 [(5)](#ref-for-dom-sourcebuffer-timestampoffset-10 "Reference 5")

[Permalink](#dom-sourcebuffer-audiotracks)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dom-sourcebuffer-audiotracks-1 "§ 3.8 removeSourceBuffer() method")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-audiotracks-2 "§ 5. SourceBuffer interface")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dom-sourcebuffer-audiotracks-3 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dom-sourcebuffer-audiotracks-4 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-audiotracks-5 "Reference 3")

[Permalink](#dom-sourcebuffer-videotracks)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dom-sourcebuffer-videotracks-1 "§ 3.8 removeSourceBuffer() method")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-videotracks-2 "§ 5. SourceBuffer interface")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dom-sourcebuffer-videotracks-3 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dom-sourcebuffer-videotracks-4 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-videotracks-5 "Reference 3")

[Permalink](#dom-sourcebuffer-texttracks)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dom-sourcebuffer-texttracks-1 "§ 3.8 removeSourceBuffer() method")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-texttracks-2 "§ 5. SourceBuffer interface")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dom-sourcebuffer-texttracks-3 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dom-sourcebuffer-texttracks-4 "Reference 2")

[Permalink](#dom-sourcebuffer-appendwindowstart)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 2.
 Definitions](#ref-for-dom-sourcebuffer-appendwindowstart-1 "§ 2. Definitions")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-appendwindowstart-2 "§ 5. SourceBuffer interface")
- [§ 5.1
 Attributes](#ref-for-dom-sourcebuffer-appendwindowstart-3 "§ 5.1 Attributes")
- [§ 5.2
 Methods](#ref-for-dom-sourcebuffer-appendwindowstart-4 "§ 5.2 Methods")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dom-sourcebuffer-appendwindowstart-5 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-dom-sourcebuffer-appendwindowstart-6 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-appendwindowstart-7 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-appendwindowstart-8 "Reference 4")

[Permalink](#dom-sourcebuffer-appendwindowend)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 2.
 Definitions](#ref-for-dom-sourcebuffer-appendwindowend-1 "§ 2. Definitions")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-appendwindowend-2 "§ 5. SourceBuffer interface")
- [§ 5.1
 Attributes](#ref-for-dom-sourcebuffer-appendwindowend-3 "§ 5.1 Attributes")
- [§ 5.2
 Methods](#ref-for-dom-sourcebuffer-appendwindowend-4 "§ 5.2 Methods")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dom-sourcebuffer-appendwindowend-5 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-dom-sourcebuffer-appendwindowend-6 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-appendwindowend-7 "Reference 3")

[Permalink](#dom-sourcebuffer-onupdatestart)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-onupdatestart-1 "§ 5. SourceBuffer interface")

[Permalink](#dom-sourcebuffer-onupdate)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-onupdate-1 "§ 5. SourceBuffer interface")

[Permalink](#dom-sourcebuffer-onupdateend)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-onupdateend-1 "§ 5. SourceBuffer interface")

[Permalink](#dom-sourcebuffer-onerror)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-onerror-1 "§ 5. SourceBuffer interface")

[Permalink](#dom-sourcebuffer-onabort)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-onabort-1 "§ 5. SourceBuffer interface")

[Permalink](#dom-sourcebuffer-appendbuffer)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.5 duration
 attribute](#ref-for-dom-sourcebuffer-appendbuffer-1 "§ 3.5 duration attribute")
- [§ 3.15.1 Attaching to a media
 element](#ref-for-dom-sourcebuffer-appendbuffer-2 "§ 3.15.1 Attaching to a media element")
- [§ 3.15.3
 Seeking](#ref-for-dom-sourcebuffer-appendbuffer-3 "§ 3.15.3 Seeking")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-appendbuffer-4 "§ 5. SourceBuffer interface")
- [§ 5.1
 Attributes](#ref-for-dom-sourcebuffer-appendbuffer-5 "§ 5.1 Attributes")
- [§ 5.2
 Methods](#ref-for-dom-sourcebuffer-appendbuffer-6 "§ 5.2 Methods")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dom-sourcebuffer-appendbuffer-7 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-dom-sourcebuffer-appendbuffer-8 "Reference 2")
- [§ 5.5.5 Buffer
 Append](#ref-for-dom-sourcebuffer-appendbuffer-9 "§ 5.5.5 Buffer Append")
- [§ 9.2 Event
 Summary](#ref-for-dom-sourcebuffer-appendbuffer-10 "§ 9.2 Event Summary")
- [§ 9.3.1 Buffered
 Change](#ref-for-dom-sourcebuffer-appendbuffer-11 "§ 9.3.1 Buffered Change")
- [§ 14. Byte Stream
 Formats](#ref-for-dom-sourcebuffer-appendbuffer-12 "§ 14. Byte Stream Formats")

[Permalink](#dom-sourcebuffer-abort)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 2.
 Definitions](#ref-for-dom-sourcebuffer-abort-1 "§ 2. Definitions")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-abort-2 "§ 5. SourceBuffer interface")
- [§ 5.4 Event
 Summary](#ref-for-dom-sourcebuffer-abort-3 "§ 5.4 Event Summary")

[Permalink](#dom-sourcebuffer-changetype)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ Status of This
 Document](#ref-for-dom-sourcebuffer-changetype-1 "§ Status of This Document")
- [§ 2.
 Definitions](#ref-for-dom-sourcebuffer-changetype-2 "§ 2. Definitions")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-changetype-3 "§ 5. SourceBuffer interface")
- [§ 5.1
 Attributes](#ref-for-dom-sourcebuffer-changetype-4 "§ 5.1 Attributes")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dom-sourcebuffer-changetype-5 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dom-sourcebuffer-changetype-6 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dom-sourcebuffer-changetype-7 "Reference 2")
 [(3)](#ref-for-dom-sourcebuffer-changetype-8 "Reference 3")
 [(4)](#ref-for-dom-sourcebuffer-changetype-9 "Reference 4")
 [(5)](#ref-for-dom-sourcebuffer-changetype-10 "Reference 5")
 [(6)](#ref-for-dom-sourcebuffer-changetype-11 "Reference 6")
 [(7)](#ref-for-dom-sourcebuffer-changetype-12 "Reference 7")
 [(8)](#ref-for-dom-sourcebuffer-changetype-13 "Reference 8")
 [(9)](#ref-for-dom-sourcebuffer-changetype-14 "Reference 9")
 [(10)](#ref-for-dom-sourcebuffer-changetype-15 "Reference 10")
 [(11)](#ref-for-dom-sourcebuffer-changetype-16 "Reference 11")
- [§ 14. Byte Stream
 Formats](#ref-for-dom-sourcebuffer-changetype-17 "§ 14. Byte Stream Formats")
 [(2)](#ref-for-dom-sourcebuffer-changetype-18 "Reference 2")

[Permalink](#dom-sourcebuffer-remove)
[exported]
[IDL](#webidl-544711679 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.15.6 Duration
 change](#ref-for-dom-sourcebuffer-remove-1 "§ 3.15.6 Duration change")
- [§ 5. SourceBuffer
 interface](#ref-for-dom-sourcebuffer-remove-2 "§ 5. SourceBuffer interface")
- [§ 5.1
 Attributes](#ref-for-dom-sourcebuffer-remove-3 "§ 5.1 Attributes")
- [§ 5.5.4 Prepare
 Append](#ref-for-dom-sourcebuffer-remove-4 "§ 5.5.4 Prepare Append")
- [§ 9.2 Event
 Summary](#ref-for-dom-sourcebuffer-remove-5 "§ 9.2 Event Summary")
- [§ 9.3.1 Buffered
 Change](#ref-for-dom-sourcebuffer-remove-6 "§ 9.3.1 Buffered Change")

[Permalink](#track-buffer)

**Referenced in:**

- [§ 2. Definitions](#ref-for-track-buffer-1 "§ 2. Definitions")
- [§ 3.15.6 Duration
 change](#ref-for-track-buffer-2 "§ 3.15.6 Duration change")
- [§ 3.15.7 End of
 stream](#ref-for-track-buffer-3 "§ 3.15.7 End of stream")
- [§ 5.1 Attributes](#ref-for-track-buffer-4 "§ 5.1 Attributes")
 [(2)](#ref-for-track-buffer-5 "Reference 2")
 [(3)](#ref-for-track-buffer-6 "Reference 3")
 [(4)](#ref-for-track-buffer-7 "Reference 4")
- [§ 5.3 Track Buffers](#ref-for-track-buffer-8 "§ 5.3 Track Buffers")
 [(2)](#ref-for-track-buffer-9 "Reference 2")
 [(3)](#ref-for-track-buffer-10 "Reference 3")
 [(4)](#ref-for-track-buffer-11 "Reference 4")
 [(5)](#ref-for-track-buffer-12 "Reference 5")
 [(6)](#ref-for-track-buffer-13 "Reference 6")
 [(7)](#ref-for-track-buffer-14 "Reference 7")
 [(8)](#ref-for-track-buffer-15 "Reference 8")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-track-buffer-16 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.2 Reset Parser
 State](#ref-for-track-buffer-17 "§ 5.5.2 Reset Parser State")
 [(2)](#ref-for-track-buffer-18 "Reference 2")
 [(3)](#ref-for-track-buffer-19 "Reference 3")
 [(4)](#ref-for-track-buffer-20 "Reference 4")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-track-buffer-21 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-track-buffer-22 "Reference 2")
 [(3)](#ref-for-track-buffer-23 "Reference 3")
 [(4)](#ref-for-track-buffer-24 "Reference 4")
 [(5)](#ref-for-track-buffer-25 "Reference 5")
 [(6)](#ref-for-track-buffer-26 "Reference 6")
 [(7)](#ref-for-track-buffer-27 "Reference 7")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-track-buffer-28 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-track-buffer-29 "Reference 2")
 [(3)](#ref-for-track-buffer-30 "Reference 3")
 [(4)](#ref-for-track-buffer-31 "Reference 4")
 [(5)](#ref-for-track-buffer-32 "Reference 5")
 [(6)](#ref-for-track-buffer-33 "Reference 6")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-track-buffer-34 "§ 5.5.9 Coded Frame Removal")
 [(2)](#ref-for-track-buffer-35 "Reference 2")
 [(3)](#ref-for-track-buffer-36 "Reference 3")
 [(4)](#ref-for-track-buffer-37 "Reference 4")
 [(5)](#ref-for-track-buffer-38 "Reference 5")
 [(6)](#ref-for-track-buffer-39 "Reference 6")
 [(7)](#ref-for-track-buffer-40 "Reference 7")
 [(8)](#ref-for-track-buffer-41 "Reference 8")
- [§ 5.5.11 Audio Splice
 Frame](#ref-for-track-buffer-42 "§ 5.5.11 Audio Splice Frame")
- [§ 5.5.13 Text Splice
 Frame](#ref-for-track-buffer-43 "§ 5.5.13 Text Splice Frame")

[Permalink](#last-decode-timestamp)

**Referenced in:**

- [§ 5.5.2 Reset Parser
 State](#ref-for-last-decode-timestamp-1 "§ 5.5.2 Reset Parser State")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-last-decode-timestamp-2 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-last-decode-timestamp-3 "Reference 2")
 [(3)](#ref-for-last-decode-timestamp-4 "Reference 3")
 [(4)](#ref-for-last-decode-timestamp-5 "Reference 4")
 [(5)](#ref-for-last-decode-timestamp-6 "Reference 5")
 [(6)](#ref-for-last-decode-timestamp-7 "Reference 6")
 [(7)](#ref-for-last-decode-timestamp-8 "Reference 7")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-last-decode-timestamp-9 "§ 5.5.9 Coded Frame Removal")
 [(2)](#ref-for-last-decode-timestamp-10 "Reference 2")

[Permalink](#last-frame-duration)

**Referenced in:**

- [§ 5.5.2 Reset Parser
 State](#ref-for-last-frame-duration-1 "§ 5.5.2 Reset Parser State")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-last-frame-duration-2 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-last-frame-duration-3 "Reference 2")
 [(3)](#ref-for-last-frame-duration-4 "Reference 3")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-last-frame-duration-5 "§ 5.5.9 Coded Frame Removal")

[Permalink](#highest-end-timestamp)

**Referenced in:**

- [§ 5.5.2 Reset Parser
 State](#ref-for-highest-end-timestamp-1 "§ 5.5.2 Reset Parser State")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-highest-end-timestamp-2 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-highest-end-timestamp-3 "Reference 2")
 [(3)](#ref-for-highest-end-timestamp-4 "Reference 3")
 [(4)](#ref-for-highest-end-timestamp-5 "Reference 4")
 [(5)](#ref-for-highest-end-timestamp-6 "Reference 5")
 [(6)](#ref-for-highest-end-timestamp-7 "Reference 6")
 [(7)](#ref-for-highest-end-timestamp-8 "Reference 7")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-highest-end-timestamp-9 "§ 5.5.9 Coded Frame Removal")

[Permalink](#need-RAP-flag)

**Referenced in:**

- [§ 5.5.2 Reset Parser
 State](#ref-for-need-RAP-flag-1 "§ 5.5.2 Reset Parser State")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-need-RAP-flag-2 "§ 5.5.7 Initialization Segment Received")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-need-RAP-flag-3 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-need-RAP-flag-4 "Reference 2")
 [(3)](#ref-for-need-RAP-flag-5 "Reference 3")
 [(4)](#ref-for-need-RAP-flag-6 "Reference 4")
 [(5)](#ref-for-need-RAP-flag-7 "Reference 5")
 [(6)](#ref-for-need-RAP-flag-8 "Reference 6")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-need-RAP-flag-9 "§ 5.5.9 Coded Frame Removal")

[Permalink](#track-buffer-ranges)

**Referenced in:**

- [§ 3.15.6 Duration
 change](#ref-for-track-buffer-ranges-1 "§ 3.15.6 Duration change")
- [§ 3.15.7 End of
 stream](#ref-for-track-buffer-ranges-2 "§ 3.15.7 End of stream")
- [§ 5.1 Attributes](#ref-for-track-buffer-ranges-3 "§ 5.1 Attributes")
 [(2)](#ref-for-track-buffer-ranges-4 "Reference 2")
- [§ 5.3 Track
 Buffers](#ref-for-track-buffer-ranges-5 "§ 5.3 Track Buffers")
 [(2)](#ref-for-track-buffer-ranges-6 "Reference 2")

[Permalink](#dfn-updatestart)

**Referenced in:**

- [§ 5.1 Attributes](#ref-for-dfn-updatestart-1 "§ 5.1 Attributes")
- [§ 5.2 Methods](#ref-for-dfn-updatestart-2 "§ 5.2 Methods")
- [§ 5.5.6 Range
 Removal](#ref-for-dfn-updatestart-3 "§ 5.5.6 Range Removal")
- [§ 8.1 Attributes](#ref-for-dfn-updatestart-4 "§ 8.1 Attributes")

[Permalink](#dfn-update)

**Referenced in:**

- [§ 5.1 Attributes](#ref-for-dfn-update-1 "§ 5.1 Attributes")
- [§ 5.5.5 Buffer Append](#ref-for-dfn-update-2 "§ 5.5.5 Buffer Append")
- [§ 5.5.6 Range Removal](#ref-for-dfn-update-3 "§ 5.5.6 Range Removal")

[Permalink](#dfn-updateend)

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dfn-updateend-1 "§ 3.8 removeSourceBuffer() method")
- [§ 5.1 Attributes](#ref-for-dfn-updateend-2 "§ 5.1 Attributes")
- [§ 5.2 Methods](#ref-for-dfn-updateend-3 "§ 5.2 Methods")
- [§ 5.5.3 Append
 Error](#ref-for-dfn-updateend-4 "§ 5.5.3 Append Error")
- [§ 5.5.5 Buffer
 Append](#ref-for-dfn-updateend-5 "§ 5.5.5 Buffer Append")
- [§ 5.5.6 Range
 Removal](#ref-for-dfn-updateend-6 "§ 5.5.6 Range Removal")
- [§ 8.1 Attributes](#ref-for-dfn-updateend-7 "§ 8.1 Attributes")

[Permalink](#dfn-error)

**Referenced in:**

- [§ 5.1 Attributes](#ref-for-dfn-error-1 "§ 5.1 Attributes")
- [§ 5.5.3 Append Error](#ref-for-dfn-error-2 "§ 5.5.3 Append Error")
- [§ 5.5.4 Prepare
 Append](#ref-for-dfn-error-3 "§ 5.5.4 Prepare Append")
 [(2)](#ref-for-dfn-error-4 "Reference 2")

[Permalink](#dfn-abort)

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dfn-abort-1 "§ 3.8 removeSourceBuffer() method")
- [§ 5.1 Attributes](#ref-for-dfn-abort-2 "§ 5.1 Attributes")
- [§ 5.2 Methods](#ref-for-dfn-abort-3 "§ 5.2 Methods")

[Permalink](#dfn-segment-parser-loop)

**Referenced in:**

- [§ 5.5.5 Buffer
 Append](#ref-for-dfn-segment-parser-loop-1 "§ 5.5.5 Buffer Append")
 [(2)](#ref-for-dfn-segment-parser-loop-2 "Reference 2")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dfn-segment-parser-loop-3 "§ 5.5.7 Initialization Segment Received")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dfn-segment-parser-loop-4 "§ 5.5.8 Coded Frame Processing")
- [§ 14. Byte Stream
 Formats](#ref-for-dfn-segment-parser-loop-5 "§ 14. Byte Stream Formats")

[Permalink](#dfn-append-state)

**Referenced in:**

- [§ 5.1 Attributes](#ref-for-dfn-append-state-1 "§ 5.1 Attributes")
 [(2)](#ref-for-dfn-append-state-2 "Reference 2")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-append-state-3 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-dfn-append-state-4 "Reference 2")
 [(3)](#ref-for-dfn-append-state-5 "Reference 3")
 [(4)](#ref-for-dfn-append-state-6 "Reference 4")
 [(5)](#ref-for-dfn-append-state-7 "Reference 5")
 [(6)](#ref-for-dfn-append-state-8 "Reference 6")
 [(7)](#ref-for-dfn-append-state-9 "Reference 7")
- [§ 5.5.2 Reset Parser
 State](#ref-for-dfn-append-state-10 "§ 5.5.2 Reset Parser State")
 [(2)](#ref-for-dfn-append-state-11 "Reference 2")

[Permalink](#sourcebuffer-waiting-for-segment)

**Referenced in:**

- [§ 5.5.1 Segment Parser
 Loop](#ref-for-sourcebuffer-waiting-for-segment-1 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-sourcebuffer-waiting-for-segment-2 "Reference 2")
 [(3)](#ref-for-sourcebuffer-waiting-for-segment-3 "Reference 3")
 [(4)](#ref-for-sourcebuffer-waiting-for-segment-4 "Reference 4")
- [§ 5.5.2 Reset Parser
 State](#ref-for-sourcebuffer-waiting-for-segment-5 "§ 5.5.2 Reset Parser State")

[Permalink](#sourcebuffer-parsing-init-segment)

**Referenced in:**

- [§ 5.5.1 Segment Parser
 Loop](#ref-for-sourcebuffer-parsing-init-segment-1 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-sourcebuffer-parsing-init-segment-2 "Reference 2")

[Permalink](#sourcebuffer-parsing-media-segment)

**Referenced in:**

- [§ 5.1
 Attributes](#ref-for-sourcebuffer-parsing-media-segment-1 "§ 5.1 Attributes")
 [(2)](#ref-for-sourcebuffer-parsing-media-segment-2 "Reference 2")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-sourcebuffer-parsing-media-segment-3 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-sourcebuffer-parsing-media-segment-4 "Reference 2")
- [§ 5.5.2 Reset Parser
 State](#ref-for-sourcebuffer-parsing-media-segment-5 "§ 5.5.2 Reset Parser State")

[Permalink](#dfn-input-buffer)

**Referenced in:**

- [§ 5.2 Methods](#ref-for-dfn-input-buffer-1 "§ 5.2 Methods")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-input-buffer-2 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-dfn-input-buffer-3 "Reference 2")
 [(3)](#ref-for-dfn-input-buffer-4 "Reference 3")
 [(4)](#ref-for-dfn-input-buffer-5 "Reference 4")
 [(5)](#ref-for-dfn-input-buffer-6 "Reference 5")
 [(6)](#ref-for-dfn-input-buffer-7 "Reference 6")
 [(7)](#ref-for-dfn-input-buffer-8 "Reference 7")
 [(8)](#ref-for-dfn-input-buffer-9 "Reference 8")
 [(9)](#ref-for-dfn-input-buffer-10 "Reference 9")
 [(10)](#ref-for-dfn-input-buffer-11 "Reference 10")
- [§ 5.5.2 Reset Parser
 State](#ref-for-dfn-input-buffer-12 "§ 5.5.2 Reset Parser State")
 [(2)](#ref-for-dfn-input-buffer-13 "Reference 2")
- [§ 5.5.10 Coded Frame
 Eviction](#ref-for-dfn-input-buffer-14 "§ 5.5.10 Coded Frame Eviction")

[Permalink](#dfn-buffer-full-flag)

**Referenced in:**

- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-buffer-full-flag-1 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.4 Prepare
 Append](#ref-for-dfn-buffer-full-flag-2 "§ 5.5.4 Prepare Append")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-dfn-buffer-full-flag-3 "§ 5.5.9 Coded Frame Removal")
 [(2)](#ref-for-dfn-buffer-full-flag-4 "Reference 2")
- [§ 5.5.10 Coded Frame
 Eviction](#ref-for-dfn-buffer-full-flag-5 "§ 5.5.10 Coded Frame Eviction")
 [(2)](#ref-for-dfn-buffer-full-flag-6 "Reference 2")

[Permalink](#dfn-group-start-timestamp)

**Referenced in:**

- [§ 5.1
 Attributes](#ref-for-dfn-group-start-timestamp-1 "§ 5.1 Attributes")
 [(2)](#ref-for-dfn-group-start-timestamp-2 "Reference 2")
- [§ 5.5.2 Reset Parser
 State](#ref-for-dfn-group-start-timestamp-3 "§ 5.5.2 Reset Parser State")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dfn-group-start-timestamp-4 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-dfn-group-start-timestamp-5 "Reference 2")
 [(3)](#ref-for-dfn-group-start-timestamp-6 "Reference 3")
 [(4)](#ref-for-dfn-group-start-timestamp-7 "Reference 4")
 [(5)](#ref-for-dfn-group-start-timestamp-8 "Reference 5")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-dfn-group-start-timestamp-9 "§ 5.5.9 Coded Frame Removal")

[Permalink](#dfn-group-end-timestamp)

**Referenced in:**

- [§ 5.1
 Attributes](#ref-for-dfn-group-end-timestamp-1 "§ 5.1 Attributes")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-group-end-timestamp-2 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.2 Reset Parser
 State](#ref-for-dfn-group-end-timestamp-3 "§ 5.5.2 Reset Parser State")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dfn-group-end-timestamp-4 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-dfn-group-end-timestamp-5 "Reference 2")
 [(3)](#ref-for-dfn-group-end-timestamp-6 "Reference 3")
 [(4)](#ref-for-dfn-group-end-timestamp-7 "Reference 4")
 [(5)](#ref-for-dfn-group-end-timestamp-8 "Reference 5")
 [(6)](#ref-for-dfn-group-end-timestamp-9 "Reference 6")
- [§ 5.5.9 Coded Frame
 Removal](#ref-for-dfn-group-end-timestamp-10 "§ 5.5.9 Coded Frame Removal")
 [(2)](#ref-for-dfn-group-end-timestamp-11 "Reference 2")

[Permalink](#dfn-generate-timestamps-flag)
[exported]

**Referenced in:**

- [§ 3.7 addSourceBuffer()
 method](#ref-for-dfn-generate-timestamps-flag-1 "§ 3.7 addSourceBuffer() method")
 [(2)](#ref-for-dfn-generate-timestamps-flag-2 "Reference 2")
- [§ 5.1
 Attributes](#ref-for-dfn-generate-timestamps-flag-3 "§ 5.1 Attributes")
- [§ 5.2
 Methods](#ref-for-dfn-generate-timestamps-flag-4 "§ 5.2 Methods")
 [(2)](#ref-for-dfn-generate-timestamps-flag-5 "Reference 2")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dfn-generate-timestamps-flag-6 "§ 5.5.8 Coded Frame Processing")
 [(2)](#ref-for-dfn-generate-timestamps-flag-7 "Reference 2")

[Permalink](#dfn-reset-parser-state)

**Referenced in:**

- [§ 5.2 Methods](#ref-for-dfn-reset-parser-state-1 "§ 5.2 Methods")
 [(2)](#ref-for-dfn-reset-parser-state-2 "Reference 2")
- [§ 5.5.3 Append
 Error](#ref-for-dfn-reset-parser-state-3 "§ 5.5.3 Append Error")

[Permalink](#dfn-append-error)
[exported]

**Referenced in:**

- [§ 2. Definitions](#ref-for-dfn-append-error-1 "§ 2. Definitions")
 [(2)](#ref-for-dfn-append-error-2 "Reference 2")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-append-error-3 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-dfn-append-error-4 "Reference 2")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dfn-append-error-5 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dfn-append-error-6 "Reference 2")
 [(3)](#ref-for-dfn-append-error-7 "Reference 3")
- [§ 14. Byte Stream
 Formats](#ref-for-dfn-append-error-8 "§ 14. Byte Stream Formats")
 [(2)](#ref-for-dfn-append-error-9 "Reference 2")

[Permalink](#dfn-prepare-append)

**Referenced in:**

- [§ 5.2 Methods](#ref-for-dfn-prepare-append-1 "§ 5.2 Methods")

[Permalink](#dfn-buffer-append)

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dfn-buffer-append-1 "§ 3.8 removeSourceBuffer() method")
- [§ 5.2 Methods](#ref-for-dfn-buffer-append-2 "§ 5.2 Methods")
 [(2)](#ref-for-dfn-buffer-append-3 "Reference 2")

[Permalink](#dfn-range-removal)

**Referenced in:**

- [§ 5.2 Methods](#ref-for-dfn-range-removal-1 "§ 5.2 Methods")
 [(2)](#ref-for-dfn-range-removal-2 "Reference 2")

[Permalink](#dfn-initialization-segment-received)

**Referenced in:**

- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-initialization-segment-received-1 "§ 5.5.1 Segment Parser Loop")
- [§ 14. Byte Stream
 Formats](#ref-for-dfn-initialization-segment-received-2 "§ 14. Byte Stream Formats")

[Permalink](#dfn-first-initialization-segment-received-flag)

**Referenced in:**

- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-first-initialization-segment-received-flag-1 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dfn-first-initialization-segment-received-flag-2 "§ 5.5.7 Initialization Segment Received")
 [(2)](#ref-for-dfn-first-initialization-segment-received-flag-3 "Reference 2")
 [(3)](#ref-for-dfn-first-initialization-segment-received-flag-4 "Reference 3")
 [(4)](#ref-for-dfn-first-initialization-segment-received-flag-5 "Reference 4")

[Permalink](#dfn-pending-initialization-segment-for-changetype-flag)

**Referenced in:**

- [§ 5.2
 Methods](#ref-for-dfn-pending-initialization-segment-for-changetype-flag-1 "§ 5.2 Methods")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-pending-initialization-segment-for-changetype-flag-2 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dfn-pending-initialization-segment-for-changetype-flag-3 "§ 5.5.7 Initialization Segment Received")

[Permalink](#dfn-coded-frame-processing)
[exported]

**Referenced in:**

- [§ 2.
 Definitions](#ref-for-dfn-coded-frame-processing-1 "§ 2. Definitions")
- [§ 3.15.3
 Seeking](#ref-for-dfn-coded-frame-processing-2 "§ 3.15.3 Seeking")
- [§ 5.3 Track
 Buffers](#ref-for-dfn-coded-frame-processing-3 "§ 5.3 Track Buffers")
 [(2)](#ref-for-dfn-coded-frame-processing-4 "Reference 2")
 [(3)](#ref-for-dfn-coded-frame-processing-5 "Reference 3")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-dfn-coded-frame-processing-6 "§ 5.5.1 Segment Parser Loop")
 [(2)](#ref-for-dfn-coded-frame-processing-7 "Reference 2")
 [(3)](#ref-for-dfn-coded-frame-processing-8 "Reference 3")
 [(4)](#ref-for-dfn-coded-frame-processing-9 "Reference 4")
- [§ 5.5.2 Reset Parser
 State](#ref-for-dfn-coded-frame-processing-10 "§ 5.5.2 Reset Parser State")
- [§ 5.5.11 Audio Splice
 Frame](#ref-for-dfn-coded-frame-processing-11 "§ 5.5.11 Audio Splice Frame")
- [§ 5.5.13 Text Splice
 Frame](#ref-for-dfn-coded-frame-processing-12 "§ 5.5.13 Text Splice Frame")
- [§ 8.1
 Attributes](#ref-for-dfn-coded-frame-processing-13 "§ 8.1 Attributes")

[Permalink](#dfn-coded-frame-removal)

**Referenced in:**

- [§ 3.15.6 Duration
 change](#ref-for-dfn-coded-frame-removal-1 "§ 3.15.6 Duration change")
- [§ 5.3 Track
 Buffers](#ref-for-dfn-coded-frame-removal-2 "§ 5.3 Track Buffers")
- [§ 5.5.6 Range
 Removal](#ref-for-dfn-coded-frame-removal-3 "§ 5.5.6 Range Removal")
- [§ 5.5.10 Coded Frame
 Eviction](#ref-for-dfn-coded-frame-removal-4 "§ 5.5.10 Coded Frame Eviction")
- [§ 8.1
 Attributes](#ref-for-dfn-coded-frame-removal-5 "§ 8.1 Attributes")
- [§ 9.3.2 Memory
 cleanup](#ref-for-dfn-coded-frame-removal-6 "§ 9.3.2 Memory cleanup")
 [(2)](#ref-for-dfn-coded-frame-removal-7 "Reference 2")

[Permalink](#dfn-coded-frame-eviction)

**Referenced in:**

- [§ 5.5.4 Prepare
 Append](#ref-for-dfn-coded-frame-eviction-1 "§ 5.5.4 Prepare Append")
- [§ 8.1
 Attributes](#ref-for-dfn-coded-frame-eviction-2 "§ 8.1 Attributes")

[Permalink](#dfn-audio-splice-frame)

**Referenced in:**

- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dfn-audio-splice-frame-1 "§ 5.5.8 Coded Frame Processing")
- [§ 5.5.12 Audio Splice
 Rendering](#ref-for-dfn-audio-splice-frame-2 "§ 5.5.12 Audio Splice Rendering")

[Permalink](#dfn-audio-splice-rendering)

**Referenced in:**

- [§ 5.5.11 Audio Splice
 Frame](#ref-for-dfn-audio-splice-rendering-1 "§ 5.5.11 Audio Splice Frame")

[Permalink](#dfn-text-splice-frame)

**Referenced in:**

- [§ 5.5.8 Coded Frame
 Processing](#ref-for-dfn-text-splice-frame-1 "§ 5.5.8 Coded Frame Processing")

[Permalink](#dom-sourcebufferlist)
[exported]
[IDL](#webidl-2108728413 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. MediaSource
 interface](#ref-for-dom-sourcebufferlist-1 "§ 3. MediaSource interface")
 [(2)](#ref-for-dom-sourcebufferlist-2 "Reference 2")
- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dom-sourcebufferlist-3 "§ 3.8 removeSourceBuffer() method")
 [(2)](#ref-for-dom-sourcebufferlist-4 "Reference 2")
- [§ 6. SourceBufferList
 interface](#ref-for-dom-sourcebufferlist-5 "§ 6. SourceBufferList interface")
 [(2)](#ref-for-dom-sourcebufferlist-6 "Reference 2")

[Permalink](#dom-sourcebufferlist-getter)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-sourcebufferlist-length)
[exported]
[IDL](#webidl-2108728413 "Jump to IDL declaration")

**Referenced in:**

- [§ 6. SourceBufferList
 interface](#ref-for-dom-sourcebufferlist-length-1 "§ 6. SourceBufferList interface")
- [§ 6.2
 Methods](#ref-for-dom-sourcebufferlist-length-2 "§ 6.2 Methods")

[Permalink](#dom-sourcebufferlist-onaddsourcebuffer)
[exported]
[IDL](#webidl-2108728413 "Jump to IDL declaration")

**Referenced in:**

- [§ 6. SourceBufferList
 interface](#ref-for-dom-sourcebufferlist-onaddsourcebuffer-1 "§ 6. SourceBufferList interface")

[Permalink](#dom-sourcebufferlist-onremovesourcebuffer)
[exported]
[IDL](#webidl-2108728413 "Jump to IDL declaration")

**Referenced in:**

- [§ 6. SourceBufferList
 interface](#ref-for-dom-sourcebufferlist-onremovesourcebuffer-1 "§ 6. SourceBufferList interface")

[Permalink](#dfn-sourcebufferlist-getter)

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-addsourcebuffer)

**Referenced in:**

- [§ 3.7 addSourceBuffer()
 method](#ref-for-dfn-addsourcebuffer-1 "§ 3.7 addSourceBuffer() method")
- [§ 3.15.5 Changes to selected/enabled track
 state](#ref-for-dfn-addsourcebuffer-2 "§ 3.15.5 Changes to selected/enabled track state")
 [(2)](#ref-for-dfn-addsourcebuffer-3 "Reference 2")
 [(3)](#ref-for-dfn-addsourcebuffer-4 "Reference 3")
- [§ 5.5.7 Initialization Segment
 Received](#ref-for-dfn-addsourcebuffer-5 "§ 5.5.7 Initialization Segment Received")
- [§ 6.1 Attributes](#ref-for-dfn-addsourcebuffer-6 "§ 6.1 Attributes")

[Permalink](#dfn-removesourcebuffer)

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dfn-removesourcebuffer-1 "§ 3.8 removeSourceBuffer() method")
 [(2)](#ref-for-dfn-removesourcebuffer-2 "Reference 2")
- [§ 3.15.2 Detaching from a media
 element](#ref-for-dfn-removesourcebuffer-3 "§ 3.15.2 Detaching from a media element")
 [(2)](#ref-for-dfn-removesourcebuffer-4 "Reference 2")
- [§ 3.15.5 Changes to selected/enabled track
 state](#ref-for-dfn-removesourcebuffer-5 "§ 3.15.5 Changes to selected/enabled track state")
 [(2)](#ref-for-dfn-removesourcebuffer-6 "Reference 2")
 [(3)](#ref-for-dfn-removesourcebuffer-7 "Reference 3")
- [§ 6.1
 Attributes](#ref-for-dfn-removesourcebuffer-8 "§ 6.1 Attributes")

[Permalink](#dom-managedmediasource)
[exported]
[IDL](#webidl-1619111096 "Jump to IDL declaration")

**Referenced in:**

- [§ Status of This
 Document](#ref-for-dom-managedmediasource-1 "§ Status of This Document")
- [§ 3.7 addSourceBuffer()
 method](#ref-for-dom-managedmediasource-2 "§ 3.7 addSourceBuffer() method")
- [§ 3.15.2 Detaching from a media
 element](#ref-for-dom-managedmediasource-3 "§ 3.15.2 Detaching from a media element")
- [§ 7. ManagedMediaSource
 interface](#ref-for-dom-managedmediasource-4 "§ 7. ManagedMediaSource interface")
 [(2)](#ref-for-dom-managedmediasource-5 "Reference 2")
- [§ 7.2 Event
 Summary](#ref-for-dom-managedmediasource-6 "§ 7.2 Event Summary")
 [(2)](#ref-for-dom-managedmediasource-7 "Reference 2")
- [§ 7.3.1 ManagedSourceBuffer
 Monitoring](#ref-for-dom-managedmediasource-8 "§ 7.3.1 ManagedSourceBuffer Monitoring")
 [(2)](#ref-for-dom-managedmediasource-9 "Reference 2")
- [§ 9.3.2 Memory
 cleanup](#ref-for-dom-managedmediasource-10 "§ 9.3.2 Memory cleanup")

[Permalink](#dom-managedmediasource-constructor)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-managedmediasource-onstartstreaming)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-managedmediasource-onendstreaming)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-managedmediasource-streaming)
[exported]
[IDL](#webidl-1619111096 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.15.2 Detaching from a media
 element](#ref-for-dom-managedmediasource-streaming-1 "§ 3.15.2 Detaching from a media element")
- [§ 7. ManagedMediaSource
 interface](#ref-for-dom-managedmediasource-streaming-2 "§ 7. ManagedMediaSource interface")
- [§ 7.2 Event
 Summary](#ref-for-dom-managedmediasource-streaming-3 "§ 7.2 Event Summary")
 [(2)](#ref-for-dom-managedmediasource-streaming-4 "Reference 2")
- [§ 7.3.1 ManagedSourceBuffer
 Monitoring](#ref-for-dom-managedmediasource-streaming-5 "§ 7.3.1 ManagedSourceBuffer Monitoring")
 [(2)](#ref-for-dom-managedmediasource-streaming-6 "Reference 2")
 [(3)](#ref-for-dom-managedmediasource-streaming-7 "Reference 3")

[Permalink](#dfn-startstreaming)

**Referenced in:**

- [§ 7.3.1 ManagedSourceBuffer
 Monitoring](#ref-for-dfn-startstreaming-1 "§ 7.3.1 ManagedSourceBuffer Monitoring")

[Permalink](#dfn-endstreaming)

**Referenced in:**

- [§ 7.3.1 ManagedSourceBuffer
 Monitoring](#ref-for-dfn-endstreaming-1 "§ 7.3.1 ManagedSourceBuffer Monitoring")

[Permalink](#dfn-enough-managed-data-to-ensure-uninterrupted-playback)

**Referenced in:**

- [§ 7.3.1 ManagedSourceBuffer
 Monitoring](#ref-for-dfn-enough-managed-data-to-ensure-uninterrupted-playback-1 "§ 7.3.1 ManagedSourceBuffer Monitoring")

[Permalink](#dfn-able-to-retrieve-and-buffer-data-in-an-efficient-way)

**Referenced in:**

- [§ 7.3.1 ManagedSourceBuffer
 Monitoring](#ref-for-dfn-able-to-retrieve-and-buffer-data-in-an-efficient-way-1 "§ 7.3.1 ManagedSourceBuffer Monitoring")

[Permalink](#dfn-memory-cleanup)

**Referenced in:**

- [§ 7. ManagedMediaSource
 interface](#ref-for-dfn-memory-cleanup-1 "§ 7. ManagedMediaSource interface")

[Permalink](#dom-bufferedchangeevent)
[exported]
[IDL](#webidl-2057880103 "Jump to IDL declaration")

**Referenced in:**

- [§ Status of This
 Document](#ref-for-dom-bufferedchangeevent-1 "§ Status of This Document")
- [§ 8. BufferedChangeEvent
 interface](#ref-for-dom-bufferedchangeevent-2 "§ 8. BufferedChangeEvent interface")
- [§ 9.2 Event
 Summary](#ref-for-dom-bufferedchangeevent-3 "§ 9.2 Event Summary")
- [§ 9.3.1 Buffered
 Change](#ref-for-dom-bufferedchangeevent-4 "§ 9.3.1 Buffered Change")

[Permalink](#dom-bufferedchangeevent-constructor)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#dom-bufferedchangeeventinit)
[exported]

**Referenced in:**

- [§ 8. BufferedChangeEvent
 interface](#ref-for-dom-bufferedchangeeventinit-1 "§ 8. BufferedChangeEvent interface")
- [§ 9.3.1 Buffered
 Change](#ref-for-dom-bufferedchangeeventinit-2 "§ 9.3.1 Buffered Change")

[Permalink](#dom-bufferedchangeeventinit-addedranges)
[exported]

**Referenced in:**

- [§ 9.3.1 Buffered
 Change](#ref-for-dom-bufferedchangeeventinit-addedranges-1 "§ 9.3.1 Buffered Change")

[Permalink](#dom-bufferedchangeeventinit-removedranges)
[exported]

**Referenced in:**

- [§ 9.3.1 Buffered
 Change](#ref-for-dom-bufferedchangeeventinit-removedranges-1 "§ 9.3.1 Buffered Change")

[Permalink](#dom-bufferedchangeevent-addedranges)
[exported]
[IDL](#webidl-2057880103 "Jump to IDL declaration")

**Referenced in:**

- [§ 8. BufferedChangeEvent
 interface](#ref-for-dom-bufferedchangeevent-addedranges-1 "§ 8. BufferedChangeEvent interface")

[Permalink](#dom-bufferedchangeevent-removedranges)
[exported]
[IDL](#webidl-2057880103 "Jump to IDL declaration")

**Referenced in:**

- [§ 8. BufferedChangeEvent
 interface](#ref-for-dom-bufferedchangeevent-removedranges-1 "§ 8. BufferedChangeEvent interface")

[Permalink](#dom-managedsourcebuffer)
[exported]
[IDL](#webidl-1682162223 "Jump to IDL declaration")

**Referenced in:**

- [§ Status of This
 Document](#ref-for-dom-managedsourcebuffer-1 "§ Status of This Document")
- [§ 3.7 addSourceBuffer()
 method](#ref-for-dom-managedsourcebuffer-2 "§ 3.7 addSourceBuffer() method")
- [§ 7. ManagedMediaSource
 interface](#ref-for-dom-managedsourcebuffer-3 "§ 7. ManagedMediaSource interface")
- [§ 9. ManagedSourceBuffer
 interface](#ref-for-dom-managedsourcebuffer-4 "§ 9. ManagedSourceBuffer interface")
- [§ 9.2 Event
 Summary](#ref-for-dom-managedsourcebuffer-5 "§ 9.2 Event Summary")
- [§ 9.3.1 Buffered
 Change](#ref-for-dom-managedsourcebuffer-6 "§ 9.3.1 Buffered Change")

[Permalink](#dom-managedsourcebuffer-onbufferedchange)
[exported]
[IDL](#webidl-1682162223 "Jump to IDL declaration")

**Referenced in:**

- [§ 9. ManagedSourceBuffer
 interface](#ref-for-dom-managedsourcebuffer-onbufferedchange-1 "§ 9. ManagedSourceBuffer interface")

[Permalink](#dfn-bufferedchange)

**Referenced in:**

- [§ 7. ManagedMediaSource
 interface](#ref-for-dfn-bufferedchange-1 "§ 7. ManagedMediaSource interface")
- [§ 9.1 Attributes](#ref-for-dfn-bufferedchange-2 "§ 9.1 Attributes")
- [§ 9.3.1 Buffered
 Change](#ref-for-dfn-bufferedchange-3 "§ 9.3.1 Buffered Change")
- [§ 9.3.2 Memory
 cleanup](#ref-for-dfn-bufferedchange-4 "§ 9.3.2 Memory cleanup")

[Permalink](#dfn-memory-cleanup-0)

**Referenced in:**

- [§ 7.3.2 Memory
 Cleanup](#ref-for-dfn-memory-cleanup-0-1 "§ 7.3.2 Memory Cleanup")
- [§ 8.1 Attributes](#ref-for-dfn-memory-cleanup-0-2 "§ 8.1 Attributes")
- [§ 9.2 Event
 Summary](#ref-for-dfn-memory-cleanup-0-3 "§ 9.2 Event Summary")
- [§ 9.3.1 Buffered
 Change](#ref-for-dfn-memory-cleanup-0-4 "§ 9.3.1 Buffered Change")

[Permalink](#dom-audiotrack-sourcebuffer)
[exported]
[IDL](#webidl-935490083 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dom-audiotrack-sourcebuffer-1 "§ 3.8 removeSourceBuffer() method")
- [§ 11. AudioTrack
 extensions](#ref-for-dom-audiotrack-sourcebuffer-2 "§ 11. AudioTrack extensions")

[Permalink](#dom-videotrack-sourcebuffer)
[exported]
[IDL](#webidl-251527976 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dom-videotrack-sourcebuffer-1 "§ 3.8 removeSourceBuffer() method")
- [§ 12. VideoTrack
 extensions](#ref-for-dom-videotrack-sourcebuffer-2 "§ 12. VideoTrack extensions")

[Permalink](#dom-texttrack-sourcebuffer)
[exported]
[IDL](#webidl-959897060 "Jump to IDL declaration")

**Referenced in:**

- [§ 3.8 removeSourceBuffer()
 method](#ref-for-dom-texttrack-sourcebuffer-1 "§ 3.8 removeSourceBuffer() method")
- [§ 13. TextTrack
 extensions](#ref-for-dom-texttrack-sourcebuffer-2 "§ 13. TextTrack extensions")

[Permalink](#dfn-byte-stream-formats)
[exported]

**Referenced in:**

- Not referenced in this document.

[Permalink](#byte-stream-format-specs)

**Referenced in:**

- [§ 2.
 Definitions](#ref-for-byte-stream-format-specs-1 "§ 2. Definitions")
 [(2)](#ref-for-byte-stream-format-specs-2 "Reference 2")
 [(3)](#ref-for-byte-stream-format-specs-3 "Reference 3")
 [(4)](#ref-for-byte-stream-format-specs-4 "Reference 4")
- [§ 5.5.1 Segment Parser
 Loop](#ref-for-byte-stream-format-specs-5 "§ 5.5.1 Segment Parser Loop")
- [§ 5.5.8 Coded Frame
 Processing](#ref-for-byte-stream-format-specs-6 "§ 5.5.8 Coded Frame Processing")
- [§ 14. Byte Stream
 Formats](#ref-for-byte-stream-format-specs-7 "§ 14. Byte Stream Formats")
