## [ Introduction]

Audio on the web has been fairly primitive up to this point and until
very recently has had to be delivered through plugins such as Flash and
QuickTime. The introduction of the
[`audio`](https://html.spec.whatwg.org/multipage/media.html#audio) element in HTML5 is very important, allowing for
basic streaming audio playback. But, it is not powerful enough to handle
more complex audio applications. For sophisticated web-based games or
interactive applications, another solution is required. It is a goal of
this specification to include the capabilities found in modern game
audio engines as well as some of the mixing, processing, and filtering
tasks that are found in modern desktop audio production applications.

The APIs have been designed with a wide variety of use cases
[\[webaudio-usecases\]](#biblio-webaudio-usecases "Web Audio Processing: Use Cases and Requirements")
in mind. Ideally, it should be able to support *any* use case which
could reasonably be implemented with an optimized C++ engine controlled
via script and run in a browser. That said, modern desktop audio
software can have very advanced capabilities, some of which would be
difficult or impossible to build with this system. Apple's Logic Audio
is one such application which has support for external MIDI controllers,
arbitrary plugin audio effects and synthesizers, highly optimized
direct-to-disk audio file reading/writing, tightly integrated
time-stretching, and so on. Nevertheless, the proposed system will be
quite capable of supporting a large range of reasonably complex games
and interactive applications, including musical ones. And it can be a
very good complement to the more advanced graphics features offered by
WebGL. The API has been designed so that more advanced capabilities can
be added at a later time.

### [ Features]

The API supports these primary features:

- [Modular routing](#ModularRouting) for simple or complex mixing/effect
 architectures.

- High dynamic range, using 32-bit floats for internal processing.

- [Sample-accurate scheduled sound
 playback](#AudioParam) with low
 [latency](#latency) for musical applications requiring a very high
 degree of rhythmic precision such as drum machines and sequencers.
 This also includes the possibility of [dynamic
 creation](#DynamicLifetime) of effects.

- Automation of audio parameters for envelopes, fade-ins / fade-outs,
 granular effects, filter sweeps, LFOs etc.

- Flexible handling of channels in an audio stream, allowing them to be
 split and merged.

- Processing of audio sources from an
 [`audio`](https://html.spec.whatwg.org/multipage/media.html#audio) or
 [`video`](https://html.spec.whatwg.org/multipage/media.html#video)
 [`media element`](#MediaElementAudioSourceNode).

- Processing live audio input using a
 [`MediaStream`](#MediaStreamTrackAudioSourceNode) from
 [`getUserMedia()`](https://www.w3.org/TR/mediacapture-streams/#dom-mediadevices-getusermedia).

- Integration with WebRTC

 - Processing audio received from a remote peer using a
 [`MediaStreamTrackAudioSourceNode`](#MediaStreamTrackAudioSourceNode) and
 [\[webrtc\]](#biblio-webrtc "WebRTC: Real-Time Communication in Browsers").

 - Sending a generated or processed audio stream to a remote peer using
 a
 [`MediaStreamAudioDestinationNode`](#MediaStreamAudioDestinationNode) and
 [\[webrtc\]](#biblio-webrtc "WebRTC: Real-Time Communication in Browsers").

- Audio stream synthesis and processing [directly using
 scripts](#AudioWorklet).

- [Spatialized audio](#Spatialization) supporting a wide range of 3D
 games and immersive environments:

 - Panning models: equalpower, HRTF, pass-through

 - Distance Attenuation

 - Sound Cones

 - Obstruction / Occlusion

 - Source / Listener based

- A convolution engine for a wide range of linear effects, especially
 very high-quality room effects. Here are some examples of possible
 effects:

 - Small / large room

 - Cathedral

 - Concert hall

 - Cave

 - Tunnel

 - Hallway

 - Forest

 - Amphitheater

 - Sound of a distant room through a doorway

 - Extreme filters

 - Strange backwards effects

 - Extreme comb filter effects

- Dynamics compression for overall control and sweetening of the mix

- Efficient [real-time time-domain and frequency-domain analysis / music
 visualizer support](#AnalyserNode).

- Efficient biquad filters for lowpass, highpass, and other common
 filters.

- A Waveshaping effect for distortion and other non-linear effects

- Oscillators

#### [ Modular Routing]

Modular routing allows arbitrary connections between different
[`AudioNode`](#AudioNode)
objects. Each node can have [inputs] and/or [outputs]. A [source node] has no inputs and a single
output. A [destination node] has one input and no outputs. Other nodes
such as filters can be placed between the source and destination nodes.
The developer doesn't have to worry about low-level stream format
details when two objects are connected together; [the right thing just
happens](#channel-up-mixing-and-down-mixing). For example, if a mono
audio stream is connected to a stereo input it should just mix to left
and right channels [appropriately](#channel-up-mixing-and-down-mixing).

In the simplest case, a single source can be routed directly to the
output. All routing occurs within an
[`AudioContext`](#AudioContext) containing a single
[`AudioDestinationNode`](#AudioDestinationNode):

![A simple example of modular
routing.](images/modular-routing1.png){a
height="128" width="305"}

Illustrating this simple routing, here's a simple example playing a
single sound:

```
const context = new AudioContext();

function playSound() {
 const source = context.createBufferSource();
 source.buffer = dogBarkingBuffer;
 source.connect(context.destination);
 source.start(0);
}
```

Here's a more complex example with three sources and a convolution
reverb send with a dynamics compressor at the final output stage:

![A more complex example of modular
routing.](images/modular-routing2.png){a
height="411" width="561"}

```
let context;let compressor;let reverb;let source1, source2, source3;let lowpassFilter;let waveShaper;let panner;let dry1, dry2, dry3;let wet1, wet2, wet3;let mainDry;let mainWet;function setupRoutingGraph () { context = new AudioContext(); // Create the effects nodes. lowpassFilter = context.createBiquadFilter(); waveShaper = context.createWaveShaper(); panner = context.createPanner(); compressor = context.createDynamicsCompressor(); reverb = context.createConvolver(); // Create main wet and dry. mainDry = context.createGain(); mainWet = context.createGain(); // Connect final compressor to final destination. compressor.connect(context.destination); // Connect main dry and wet to compressor. mainDry.connect(compressor); mainWet.connect(compressor); // Connect reverb to main wet. reverb.connect(mainWet); // Create a few sources. source1 = context.createBufferSource(); source2 = context.createBufferSource(); source3 = context.createOscillator(); source1.buffer = manTalkingBuffer; source2.buffer = footstepsBuffer; source3.frequency.value = 440; // Connect source1 dry1 = context.createGain(); wet1 = context.createGain(); source1.connect(lowpassFilter); lowpassFilter.connect(dry1); lowpassFilter.connect(wet1); dry1.connect(mainDry); wet1.connect(reverb); // Connect source2 dry2 = context.createGain(); wet2 = context.createGain(); source2.connect(waveShaper); waveShaper.connect(dry2); waveShaper.connect(wet2); dry2.connect(mainDry); wet2.connect(reverb); // Connect source3 dry3 = context.createGain(); wet3 = context.createGain(); source3.connect(panner); panner.connect(dry3); panner.connect(wet3); dry3.connect(mainDry); wet3.connect(reverb); // Start the sources now. source1.start(0); source2.start(0); source3.start(0);}
```

Modular routing also permits the output of
[`AudioNode`](#AudioNode)s to
be routed to an [`AudioParam`](#AudioParam) parameter that controls the behavior of a different
[`AudioNode`](#AudioNode). In
this scenario, the output of a node can act as a modulation signal
rather than an input signal.

![Modular routing illustrating one Oscillator modulating the frequency
of another.](images/modular-routing3.png){a
height="337" width="346"}

```
function setupRoutingGraph() { const context = new AudioContext(); // Create the low frequency oscillator that supplies the modulation signal const lfo = context.createOscillator(); lfo.frequency.value = 1.0; // Create the high frequency oscillator to be modulated const hfo = context.createOscillator(); hfo.frequency.value = 440.0; // Create a gain node whose gain determines the amplitude of the modulation signal const modulationGain = context.createGain(); modulationGain.gain.value = 50; // Configure the graph and start the oscillators lfo.connect(modulationGain); modulationGain.connect(hfo.detune); hfo.connect(context.destination); hfo.start(0); lfo.start(0);}
```

### [ API Overview]

The interfaces defined are:

- An [AudioContext](#AudioContext)
 interface, which contains an audio signal graph representing
 connections between
 [`AudioNode`](#AudioNode)s.

- An [`AudioNode`](#AudioNode) interface, which represents audio sources, audio
 outputs, and intermediate processing modules.
 [`AudioNode`](#AudioNode)s
 can be dynamically connected together in a [modular
 fashion](#ModularRouting).
 [`AudioNode`](#AudioNode)s
 exist in the context of an
 [`AudioContext`](#AudioContext).

- An [`AnalyserNode`](#AnalyserNode) interface, an
 [`AudioNode`](#AudioNode)
 for use with music visualizers, or other visualization applications.

- An [`AudioBuffer`](#AudioBuffer) interface, for working with memory-resident audio
 assets. These can represent one-shot sounds, or longer audio clips.

- An
 [`AudioBufferSourceNode`](#AudioBufferSourceNode) interface, an
 [`AudioNode`](#AudioNode)
 which generates audio from an AudioBuffer.

- An
 [`AudioDestinationNode`](#AudioDestinationNode) interface, an
 [`AudioNode`](#AudioNode)
 subclass representing the final destination for all rendered audio.

- An [`AudioParam`](#AudioParam) interface, for controlling an individual aspect of an
 [`AudioNode`](#AudioNode)'s functioning, such as volume.

- An [`AudioListener`](#AudioListener) interface, which works with a
 [`PannerNode`](#PannerNode)
 for spatialization.

- An [`AudioWorklet`](#AudioWorklet) interface representing a factory for creating custom
 nodes that can process audio directly using scripts.

- An
 [`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope) interface, the context in which AudioWorkletProcessor
 processing scripts run.

- An
 [`AudioWorkletNode`](#AudioWorkletNode) interface, an
 [`AudioNode`](#AudioNode)
 representing a node processed in an AudioWorkletProcessor.

- An
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) interface, representing a single node instance inside
 an audio worker.

- A
 [`BiquadFilterNode`](#BiquadFilterNode) interface, an
 [`AudioNode`](#AudioNode)
 for common low-order filters such as:

 - Low Pass

 - High Pass

 - Band Pass

 - Low Shelf

 - High Shelf

 - Peaking

 - Notch

 - Allpass

- A
 [`ChannelMergerNode`](#ChannelMergerNode) interface, an
 [`AudioNode`](#AudioNode)
 for combining channels from multiple audio streams into a single audio
 stream.

- A
 [`ChannelSplitterNode`](#ChannelSplitterNode) interface, an
 [`AudioNode`](#AudioNode)
 for accessing the individual channels of an audio stream in the
 routing graph.

- A
 [`ConstantSourceNode`](#ConstantSourceNode) interface, an
 [`AudioNode`](#AudioNode)
 for generating a nominally constant output value with an
 [`AudioParam`](#AudioParam) to allow automation of the value.

- A [`ConvolverNode`](#ConvolverNode) interface, an
 [`AudioNode`](#AudioNode)
 for applying a real-time linear effect (such as the sound of a concert
 hall).

- A [`DelayNode`](#DelayNode)
 interface, an [`AudioNode`](#AudioNode) which applies a dynamically adjustable variable
 delay.

- A
 [`DynamicsCompressorNode`](#DynamicsCompressorNode) interface, an
 [`AudioNode`](#AudioNode)
 for dynamics compression.

- A [`GainNode`](#GainNode)
 interface, an [`AudioNode`](#AudioNode) for explicit gain control.

- An [`IIRFilterNode`](#IIRFilterNode) interface, an
 [`AudioNode`](#AudioNode)
 for a general IIR filter.

- A
 [`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode) interface, an
 [`AudioNode`](#AudioNode)
 which is the audio source from an
 [`audio`](https://html.spec.whatwg.org/multipage/media.html#audio),
 [`video`](https://html.spec.whatwg.org/multipage/media.html#video), or other media element.

- A
 [`MediaStreamAudioSourceNode`](#MediaStreamAudioSourceNode) interface, an
 [`AudioNode`](#AudioNode)
 which is the audio source from a
 [`MediaStream`](https://w3c.github.io/mediacapture-main/#dom-mediastream) such as live audio input, or from a remote peer.

- A
 [`MediaStreamTrackAudioSourceNode`](#MediaStreamTrackAudioSourceNode) interface, an
 [`AudioNode`](#AudioNode)
 which is the audio source from a
 [`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack).

- A
 [`MediaStreamAudioDestinationNode`](#MediaStreamAudioDestinationNode) interface, an
 [`AudioNode`](#AudioNode)
 which is the audio destination to a
 [`MediaStream`](https://w3c.github.io/mediacapture-main/#dom-mediastream) sent to a remote peer.

- A [`PannerNode`](#PannerNode) interface, an
 [`AudioNode`](#AudioNode)
 for spatializing / positioning audio in 3D space.

- A [`PeriodicWave`](#PeriodicWave) interface for specifying custom periodic waveforms
 for use by the
 [`OscillatorNode`](#OscillatorNode).

- An [`OscillatorNode`](#OscillatorNode) interface, an
 [`AudioNode`](#AudioNode)
 for generating a periodic waveform.

- A
 [`StereoPannerNode`](#stereopannernode) interface, an
 [`AudioNode`](#AudioNode)
 for equal-power positioning of audio input in a stereo stream.

- A [`WaveShaperNode`](#WaveShaperNode) interface, an
 [`AudioNode`](#AudioNode)
 which applies a non-linear waveshaping effect for distortion and other
 more subtle warming effects.

- An
 [`AudioPlaybackStats`](#AudioPlaybackStats) interface, which provides statistics about the audio
 played from the
 [`AudioContext`](#AudioContext).

There are also several features that have been deprecated from the Web
Audio API but not yet removed, pending implementation experience of
their replacements:

- A
 [`ScriptProcessorNode`](#ScriptProcessorNode) interface, an
 [`AudioNode`](#AudioNode)
 for generating or processing audio directly using scripts.

- An
 [`AudioProcessingEvent`](#AudioProcessingEvent) interface, which is an event type used with
 [`ScriptProcessorNode`](#ScriptProcessorNode) objects.

## 1. The Audio API

### 1.1. The [`BaseAudioContext` Interface]
This interface represents a set of
[`AudioNode`](#AudioNode)
objects and their connections. It allows for arbitrary routing of
signals to an
[`AudioDestinationNode`](#AudioDestinationNode). Nodes are created from the context and are then
[connected](#ModularRouting) together.

[`BaseAudioContext`](#BaseAudioContext) is not instantiated directly, but is instead extended
by the concrete interfaces
[`AudioContext`](#AudioContext) (for real-time rendering) and
[`OfflineAudioContext`](#OfflineAudioContext) (for offline rendering).

[`BaseAudioContext`](#BaseAudioContext) are created with an internal slot
[`[[pending promises]]`] that is an initially empty ordered list
of promises.

Each
[`BaseAudioContext`](#BaseAudioContext) has a unique [media element event task
source](https://html.spec.whatwg.org/multipage/media.html#media-element-event-task-source).
Additionally, a
[`BaseAudioContext`](#BaseAudioContext) has several private slots
[`[[rendering thread state]]`] and
[`[[control thread state]]`] that take values from
[`AudioContextState`](#enumdef-audiocontextstate), and that are both initially set to `"suspended" `,
[`[[state before interruption]] `] that
also take values from
[`AudioContextState`](#enumdef-audiocontextstate) and is initially set to `null` and a private slot
[`[[render quantum size]]`] that is an
unsigned integer.

```
enum AudioContextState {
 "suspended",
 "running",
 "closed",
 "interrupted"
};
```

::: enum-description
[`AudioContextState`](#enumdef-audiocontextstate) enumeration description

Enum value

Description

\"[`suspended`]\"

This context is currently suspended (context time is not proceeding,
audio hardware may be powered down/released).

\"[`running`]\"

Audio is being processed.

\"[`closed`]\"

This context has been released, and can no longer be used to process
audio. All system audio resources have been released.

\"[`interrupted`]\"

This context is currently interrupted and cannot process audio until the
[interruption](#interruption)
ends.

```
enum AudioContextRenderSizeCategory {
 "default",
 "hardware"
};
```

::: enum-description
Enumeration description

\"[`default`]\"

The AudioContext's [render quantum
size](#render-quantum-size) is the default value of 128 frames.

\"[`hardware`]\"

The User-Agent picks a [render quantum
size](#render-quantum-size) that is best for the current configuration.

 This exposes information about the host and can be used
for fingerprinting.

```
callback DecodeErrorCallback = undefined (DOMException error);

callback DecodeSuccessCallback = undefined (AudioBuffer decodedData);

[Exposed=Window]
interface BaseAudioContext : EventTarget {
 readonly attribute AudioDestinationNode destination;
 readonly attribute float sampleRate;
 readonly attribute double currentTime;
 readonly attribute AudioListener listener;
 readonly attribute AudioContextState state;
 readonly attribute unsigned long renderQuantumSize;
 [SameObject, SecureContext]
 readonly attribute AudioWorklet audioWorklet;
 attribute EventHandler onstatechange;

 AnalyserNode createAnalyser ();
 BiquadFilterNode createBiquadFilter ();
 AudioBuffer createBuffer (unsigned long numberOfChannels,
 unsigned long length,
 float sampleRate);
 AudioBufferSourceNode createBufferSource ();
 ChannelMergerNode createChannelMerger (optional unsigned long numberOfInputs = 6);
 ChannelSplitterNode createChannelSplitter (
 optional unsigned long numberOfOutputs = 6);
 ConstantSourceNode createConstantSource ();
 ConvolverNode createConvolver ();
 DelayNode createDelay (optional double maxDelayTime = 1.0);
 DynamicsCompressorNode createDynamicsCompressor ();
 GainNode createGain ();
 IIRFilterNode createIIRFilter (sequence<double> feedforward,
 sequence<double> feedback);
 OscillatorNode createOscillator ();
 PannerNode createPanner ();
 PeriodicWave createPeriodicWave (sequence<float> real,
 sequence<float> imag,
 optional PeriodicWaveConstraints constraints = );
 ScriptProcessorNode createScriptProcessor(
 optional unsigned long bufferSize = 0,
 optional unsigned long numberOfInputChannels = 2,
 optional unsigned long numberOfOutputChannels = 2);
 StereoPannerNode createStereoPanner ();
 WaveShaperNode createWaveShaper ();

 Promise<AudioBuffer> decodeAudioData (
 ArrayBuffer audioData,
 optional DecodeSuccessCallback? successCallback,
 optional DecodeErrorCallback? errorCallback);
};
```

#### 1.1.1. Attributes

[`audioWorklet`], of type [AudioWorklet](#AudioWorklet), readonly

: Allows access to the `Worklet` object that can import a script
 containing
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) class definitions via the algorithms defined by
 [\[HTML\]](#biblio-html "HTML Standard") and
 [`AudioWorklet`](#AudioWorklet).

[`currentTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly

: This is the time in seconds of the sample frame immediately
 following the last sample-frame in the block of audio most recently
 processed by the context's rendering graph. If the context's
 rendering graph has not yet processed a block of audio, then
 [`currentTime`](#dom-baseaudiocontext-currenttime) has a value of zero.

 In the time coordinate system of
 [`currentTime`](#dom-baseaudiocontext-currenttime), the value of zero corresponds to the first
 sample-frame in the first block processed by the graph. Elapsed time
 in this system corresponds to elapsed time in the audio stream
 generated by the
 [`BaseAudioContext`](#BaseAudioContext), which may not be synchronized with other clocks in
 the system. (For an
 [`OfflineAudioContext`](#OfflineAudioContext), since the stream is not being actively played by
 any device, there is not even an approximation to real time.)

 All scheduled times in the Web Audio API are relative to the value
 of
 [`currentTime`](#dom-baseaudiocontext-currenttime).

 When the
 [`BaseAudioContext`](#BaseAudioContext) is in the
 \"[`running`](#dom-audiocontextstate-running)\" state, the value of this attribute is
 monotonically increasing and is updated by the rendering thread in
 uniform increments, corresponding to one [render
 quantum](#render-quantum).
 Thus, for a running context, `currentTime` increases steadily as the
 system processes audio blocks, and always represents the time of the
 start of the next audio block to be processed. It is also the
 earliest possible time when any change scheduled in the current
 state might take effect.

 `currentTime` MUST be read
 [atomically](#atomically) on
 the control thread before being returned.

[`destination`], of type [AudioDestinationNode](#AudioDestinationNode), readonly

: An
 [`AudioDestinationNode`](#AudioDestinationNode) with a single input representing the final
 destination for all audio. Usually this will represent the actual
 audio hardware. All
 [`AudioNode`](#AudioNode)s actively rendering audio will directly or
 indirectly connect to
 [`destination`](#dom-baseaudiocontext-destination).

[`listener`], of type [AudioListener](#AudioListener), readonly

: An [`AudioListener`](#AudioListener) which is used for 3D
 [spatialization](#Spatialization).

[`onstatechange`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: A property used to set an [event
 handler](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers) for an event that is dispatched to
 [`BaseAudioContext`](#BaseAudioContext) when the state of the AudioContext has changed
 (i.e. when the corresponding promise would have resolved). The event
 type of this event handler is
 [`statechange`]. An event that uses the
 [`Event`](https://dom.spec.whatwg.org/#event) interface will be dispatched to the event handler,
 which can query the AudioContext's state directly. A newly-created
 AudioContext will always begin in the `suspended` state, and a state
 change event will be fired whenever the state changes to a different
 state. This event is fired before the
 [`complete`](#eventdef-offlineaudiocontext-complete) event is fired.

[`sampleRate`], of type [float](https://webidl.spec.whatwg.org/#idl-float), readonly

: The sample rate (in sample-frames per second) at which the
 [`BaseAudioContext`](#BaseAudioContext) handles audio. It is assumed that all
 [`AudioNode`](#AudioNode)s in the context run at this rate. In making this
 assumption, sample-rate converters or \"varispeed\" processors are
 not supported in real-time processing. The [Nyquist
 frequency] is half this sample-rate value.

[`state`], of type [AudioContextState](#enumdef-audiocontextstate), readonly

: Describes the current state of the
 [`BaseAudioContext`](#BaseAudioContext). Getting this attribute returns the contents of the
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) slot.

[`renderQuantumSize`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Getting this attribute returns the value of
 [`[[render quantum size]]`](#dom-baseaudiocontext-render-quantum-size-slot) slot.

#### 1.1.2. Methods

[`createAnalyser()`]

: [Factory method](#factory-method) for an
 [`AnalyserNode`](#AnalyserNode).

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`AnalyserNode`](#AnalyserNode)
 :::

[`createBiquadFilter()`]

: [Factory method](#factory-method) for a
 [`BiquadFilterNode`](#BiquadFilterNode) representing a second order filter which can be
 configured as one of several common filter types.

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`BiquadFilterNode`](#BiquadFilterNode)
 :::

[`createBuffer(numberOfChannels, length, sampleRate)`]

: Creates an AudioBuffer of the given size. The audio data in the
 buffer will be zero-initialized (silent). [A
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown if any of the arguments is
 negative, zero, or outside its nominal range.]

 Arguments for the
 [BaseAudioContext.createBuffer()](#dom-baseaudiocontext-createbuffer) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`numberOfChannels`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✘]

 Determines how many channels the buffer will have. An implementation
 MUST support at least 32 channels.

 [`length`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✘]

 Determines the size of the buffer in sample-frames. This MUST be at
 least 1.

 [`sampleRate`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 Describes the sample-rate of the [linear
 PCM](#linear-pcm) audio data in
 the buffer in sample-frames per second. See [§ 2.4 Supported Sample
 Rates](#sample-rates) for the required supported range.

 :::
 *Return type:*
 [`AudioBuffer`](#AudioBuffer)
 :::

[`createBufferSource()`]

: [Factory method](#factory-method) for a
 [`AudioBufferSourceNode`](#AudioBufferSourceNode).

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`AudioBufferSourceNode`](#AudioBufferSourceNode)
 :::

[`createChannelMerger(numberOfInputs)`]

: [Factory method](#factory-method) for a
 [`ChannelMergerNode`](#ChannelMergerNode) representing a channel merger. [An
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown if
 [`numberOfInputs`](#dom-baseaudiocontext-createchannelmerger-numberofinputs-numberofinputs) is less than 1 or is greater than the number of
 supported channels.]

 Arguments for the
 [BaseAudioContext.createChannelMerger(numberOfInputs)](#dom-baseaudiocontext-createchannelmerger) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`numberOfInputs`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✔]

 Determines the number of inputs. Values of up to 32 MUST be
 supported. If not specified, then `6` will be used.

 :::
 *Return type:*
 [`ChannelMergerNode`](#ChannelMergerNode)
 :::

[`createChannelSplitter(numberOfOutputs)`]

: [Factory method](#factory-method) for a
 [`ChannelSplitterNode`](#ChannelSplitterNode) representing a channel splitter. [An
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown if
 [`numberOfOutputs`](#dom-baseaudiocontext-createchannelsplitter-numberofoutputs-numberofoutputs) is less than 1 or is greater than the number of
 supported channels.]

 Arguments for the
 [BaseAudioContext.createChannelSplitter(numberOfOutputs)](#dom-baseaudiocontext-createchannelsplitter) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`numberOfOutputs`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✔]

 The number of outputs. Values of up to 32 MUST be supported. If not
 specified, then `6` will be used.

 :::
 *Return type:*
 [`ChannelSplitterNode`](#ChannelSplitterNode)
 :::

[`createConstantSource()`]

: [Factory method](#factory-method) for a
 [`ConstantSourceNode`](#ConstantSourceNode).

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`ConstantSourceNode`](#ConstantSourceNode)
 :::

[`createConvolver()`]

: [Factory method](#factory-method) for a
 [`ConvolverNode`](#ConvolverNode).

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`ConvolverNode`](#ConvolverNode)
 :::

[`createDelay(maxDelayTime)`]

: [Factory method](#factory-method) for a
 [`DelayNode`](#DelayNode). The initial default delay time will be 0 seconds.

 Arguments for the
 [BaseAudioContext.createDelay(maxDelayTime)](#dom-baseaudiocontext-createdelay) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`maxDelayTime`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✔]

 Specifies the maximum delay time in seconds allowed for the delay
 line. [If specified, this value MUST be greater than zero and less
 than three minutes or a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown.] If not
 specified, then `1` will be used.

 :::
 *Return type:* [`DelayNode`](#DelayNode)
 :::

[`createDynamicsCompressor()`]

: [Factory method](#factory-method) for a
 [`DynamicsCompressorNode`](#DynamicsCompressorNode).

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`DynamicsCompressorNode`](#DynamicsCompressorNode)
 :::

[`createGain()`]

: [Factory method](#factory-method) for
 [`GainNode`](#GainNode).

 :::
 *No parameters.*
 :::

 :::
 *Return type:* [`GainNode`](#GainNode)
 :::

[`createIIRFilter(feedforward, feedback)`]
: Arguments for the
 [BaseAudioContext.createIIRFilter()](#dom-baseaudiocontext-createiirfilter) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`feedforward`]
 [`sequence`](https://webidl.spec.whatwg.org/#idl-sequence)`<`[`double`](https://webidl.spec.whatwg.org/#idl-double)`>`
 [✘]
 [✘]
 An array of the feedforward (numerator) coefficients for the
 transfer function of the IIR filter. The maximum length of this
 array is 20. If all of the values are zero, [an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) *MUST* be thrown]. [A
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) *MUST* be thrown if the array length is 0 or
 greater than 20].
 [`feedback`]
 [`sequence`](https://webidl.spec.whatwg.org/#idl-sequence)`<`[`double`](https://webidl.spec.whatwg.org/#idl-double)`>`
 [✘]
 [✘]
 An array of the feedback (denominator) coefficients for the transfer
 function of the IIR filter. The maximum length of this array is 20.
 If the first element of the array is 0, [an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) *MUST* be thrown]. [A
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) *MUST* be thrown if the array length is 0 or
 greater than 20].
 :::
 *Return type:*
 [`IIRFilterNode`](#IIRFilterNode)
 :::

[`createOscillator()`]

: [Factory method](#factory-method) for an
 [`OscillatorNode`](#OscillatorNode).

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`OscillatorNode`](#OscillatorNode)
 :::

[`createPanner()`]

: [Factory method](#factory-method) for a
 [`PannerNode`](#PannerNode).

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`PannerNode`](#PannerNode)
 :::

[`createPeriodicWave(real, imag, constraints)`]

: [Factory method](#factory-method) to create a
 [`PeriodicWave`](#PeriodicWave).

 :::
 When calling this method, execute these steps:
 1. [If
 [`real`](#dom-baseaudiocontext-createperiodicwave-real) and
 [`imag`](#dom-baseaudiocontext-createperiodicwave-imag) are not of the same length, an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) MUST be thrown.]

 2. Let `o` be a new object of type
 [`PeriodicWaveOptions`](#PeriodicWaveOptions).

 3. Respectively set the
 [`real`](#dom-baseaudiocontext-createperiodicwave-real) and
 [`imag`](#dom-baseaudiocontext-createperiodicwave-imag) parameters passed to this factory method to the
 attributes of the same name on `o`.

 4. Set the
 [`disableNormalization`](#dom-periodicwaveconstraints-disablenormalization) attribute on `o` to the value of the
 [`disableNormalization`](#dom-periodicwaveconstraints-disablenormalization) attribute of the `constraints` attribute passed
 to the factory method.

 5. Construct a new
 [`PeriodicWave`](#PeriodicWave) `p`, passing the
 [`BaseAudioContext`](#BaseAudioContext) this factory method has been called on as a
 first argument, and `o`.

 6. Return `p`.
 :::

 Arguments for the
 [BaseAudioContext.createPeriodicWave()](#dom-baseaudiocontext-createperiodicwave) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`real`]

 [`sequence`](https://webidl.spec.whatwg.org/#idl-sequence)`<`[`float`](https://webidl.spec.whatwg.org/#idl-float)`>`

 [✘]

 [✘]

 A sequence of cosine parameters. See its
 [`real`](#dom-periodicwaveoptions-real) constructor argument for a more detailed
 description.

 [`imag`]

 [`sequence`](https://webidl.spec.whatwg.org/#idl-sequence)`<`[`float`](https://webidl.spec.whatwg.org/#idl-float)`>`

 [✘]

 [✘]

 A sequence of sine parameters. See its
 [`imag`](#dom-periodicwaveoptions-imag) constructor argument for a more detailed
 description.

 [`constraints`]

 [`PeriodicWaveConstraints`](#PeriodicWaveConstraints)

 [✘]

 [✔]

 If not given, the waveform is normalized. Otherwise, the waveform is
 normalized according the value given by `constraints`.

 :::
 *Return type:*
 [`PeriodicWave`](#PeriodicWave)
 :::

[`createScriptProcessor(bufferSize, numberOfInputChannels, numberOfOutputChannels)`]

: [Factory method](#factory-method) for a
 [`ScriptProcessorNode`](#ScriptProcessorNode). This method is DEPRECATED, as it is intended to be
 replaced by
 [`AudioWorkletNode`](#AudioWorkletNode). Creates a
 [`ScriptProcessorNode`](#ScriptProcessorNode) for direct audio processing using scripts. [An
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown if
 [`bufferSize`](#dom-baseaudiocontext-createscriptprocessor-buffersize-numberofinputchannels-numberofoutputchannels-buffersize) or
 [`numberOfInputChannels`](#dom-baseaudiocontext-createscriptprocessor-buffersize-numberofinputchannels-numberofoutputchannels-numberofinputchannels) or
 [`numberOfOutputChannels`](#dom-baseaudiocontext-createscriptprocessor-buffersize-numberofinputchannels-numberofoutputchannels-numberofoutputchannels) are outside the valid range.]

 It is invalid for both
 [`numberOfInputChannels`](#dom-baseaudiocontext-createscriptprocessor-buffersize-numberofinputchannels-numberofoutputchannels-numberofinputchannels) and
 [`numberOfOutputChannels`](#dom-baseaudiocontext-createscriptprocessor-buffersize-numberofinputchannels-numberofoutputchannels-numberofoutputchannels) to be zero. [In this case an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) MUST be thrown.]

 Arguments for the
 [BaseAudioContext.createScriptProcessor(bufferSize,
 numberOfInputChannels,
 numberOfOutputChannels)](#dom-baseaudiocontext-createscriptprocessor) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`bufferSize`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✔]

 The
 [`bufferSize`](#dom-scriptprocessornode-buffersize) parameter determines the buffer size in units of
 sample-frames. If it's not passed in, or if the value is 0, then the
 implementation will choose the best buffer size for the given
 environment, which will be constant power of 2 throughout the
 lifetime of the node. Otherwise if the author explicitly specifies
 the bufferSize, it *MUST* be one of the following values: 256, 512,
 1024, 2048, 4096, 8192, 16384. This value controls how frequently
 the
 [`audioprocess`](#eventdef-scriptprocessornode-audioprocess) event is dispatched and how many sample-frames need
 to be processed each call. Lower values for
 [`bufferSize`](#dom-scriptprocessornode-buffersize) will result in a lower (better)
 [latency](#latency). Higher values will be necessary to avoid audio
 breakup and [glitches](#audio-glitching). It is recommended for
 authors to not specify this buffer size and allow the implementation
 to pick a good buffer size to balance between [latency](#latency)
 and audio quality. If the value of this parameter is not one of the
 allowed power-of-2 values listed above, [an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) *MUST* be thrown].

 [`numberOfInputChannels`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✔]

 This parameter determines the number of channels for this node's
 input. The default value is 2. Values of up to 32 must be supported.
 [A
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) must be thrown if the number of channels is not
 supported.]

 [`numberOfOutputChannels`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✔]

 This parameter determines the number of channels for this node's
 output. The default value is 2. Values of up to 32 must be
 supported. [A
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) must be thrown if the number of channels is not
 supported.]

 :::
 *Return type:*
 [`ScriptProcessorNode`](#ScriptProcessorNode)
 :::

[`createStereoPanner()`]

: [Factory method](#factory-method) for a
 [`StereoPannerNode`](#stereopannernode).

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`StereoPannerNode`](#stereopannernode)
 :::

[`createWaveShaper()`]

: [Factory method](#factory-method) for a
 [`WaveShaperNode`](#WaveShaperNode) representing a non-linear distortion.

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`WaveShaperNode`](#WaveShaperNode)
 :::

[`decodeAudioData(audioData, successCallback, errorCallback)`]

: Asynchronously decodes the audio file data contained in the
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer). The
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) can, for example, be loaded from an
 `XMLHttpRequest`'s `response` attribute after setting the
 `responseType` to `"arraybuffer"`. Audio file data can be in any of
 the formats supported by the
 [`audio`](https://html.spec.whatwg.org/multipage/media.html#audio) element. The buffer passed to
 [`decodeAudioData()`](#dom-baseaudiocontext-decodeaudiodata) has its content-type determined by sniffing, as
 described in
 [\[mimesniff\]](#biblio-mimesniff "MIME Sniffing Standard").

 Although the primary method of interfacing with this function is via
 its promise return value, the callback parameters are provided for
 legacy reasons.

 Encourage implementation to warn authors in case of a corrupted
 file. It isn't possible to throw because this would be a breaking
 change.

 :::
 Note: If the compressed audio data byte-stream is corrupted but the
 decoding can otherwise proceed, implementations are encouraged to
 warn authors for example via the developer tools.
 :::

 :::
 [When `decodeAudioData` is called, the following steps MUST be
 performed on the control thread:]
 1. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active) then return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Let `promise` be a new Promise.

 3. If
 [`audioData`](#dom-baseaudiocontext-decodeaudiodata-audiodata-successcallback-errorcallback-audiodata) is not
 [detached](https://webidl.spec.whatwg.org/#buffersource-detached), execute the following steps:

 1. Append `promise` to
 [`[[pending promises]]`](#dom-baseaudiocontext-pending-promises-slot).

 2. [Detach](https://webidl.spec.whatwg.org/#dfn-detach) the
 [`audioData`](#dom-baseaudiocontext-decodeaudiodata-audiodata-successcallback-errorcallback-audiodata)
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer). If this operation throws, jump to step
 4.1.

 3. Queue a decoding operation to be performed on another
 thread.

 4. Else, execute the following error steps:

 1. Let `error` be a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror).

 2. Reject `promise` with `error`, and
 remove it from
 [`[[pending promises]]`](#dom-baseaudiocontext-pending-promises-slot).

 3. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to invoke
 [`errorCallback`](#dom-baseaudiocontext-decodeaudiodata-errorcallback) with `error`.

 5. Return `promise`.
 :::

 :::
 When queuing a decoding operation to be performed on another thread,
 the following steps MUST happen on a thread that is not the [control
 thread](#control-thread)
 nor the [rendering
 thread](#rendering-thread), called the
 [`decoding thread`].
 Multiple
 [`decoding thread`](#dom-baseaudiocontext-decoding-thread)s can run in parallel to service multiple calls to
 `decodeAudioData`.

 1. Let `can decode` be a boolean flag, initially set to
 true.

 2. Attempt to determine the MIME type of
 [`audioData`](#dom-baseaudiocontext-decodeaudiodata-audiodata-successcallback-errorcallback-audiodata), using [MIME Sniffing § 6.2
 Matching an audio or video type
 pattern](https://mimesniff.spec.whatwg.org/#matching-an-audio-or-video-type-pattern).
 If the audio or video type pattern matching algorithm returns
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined), set `can decode` to *false*.

 3. If `can decode` is *true*, attempt to decode the
 encoded
 [`audioData`](#dom-baseaudiocontext-decodeaudiodata-audiodata-successcallback-errorcallback-audiodata) into [linear
 PCM](#linear-pcm). In case
 of failure, set `can decode` to *false*.

 If the media byte-stream contains multiple audio tracks, only
 decode the first track to [linear
 pcm](#linear-pcm).

 Authors who need more control over the decoding
 process can use
 [\[WEBCODECS\]](#biblio-webcodecs "WebCodecs").

 4. If `can decode` is `false`, [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to execute the following steps:

 1. Let `error` be a `DOMException` whose name is
 [`EncodingError`](https://webidl.spec.whatwg.org/#encodingerror).

 2. Reject `promise` with `error`, and
 remove it from
 [`[[pending promises]]`](#dom-baseaudiocontext-pending-promises-slot).

 2. If
 [`errorCallback`](#dom-baseaudiocontext-decodeaudiodata-errorcallback) is not missing, invoke
 [`errorCallback`](#dom-baseaudiocontext-decodeaudiodata-errorcallback) with `error`.

 5. Otherwise:

 1. Take the result, representing the decoded [linear
 PCM](#linear-pcm)
 audio data, and resample it to the sample-rate of the
 [`BaseAudioContext`](#BaseAudioContext) if it is different from the sample-rate of
 [`audioData`](#dom-baseaudiocontext-decodeaudiodata-audiodata-successcallback-errorcallback-audiodata).

 2. [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to execute the following steps:

 1. Let `buffer` be an
 [`AudioBuffer`](#AudioBuffer) containing the final result (after
 possibly performing sample-rate conversion).

 2. Resolve `promise` with `buffer`.

 3. If
 [`successCallback`](#dom-baseaudiocontext-decodeaudiodata-successcallback) is not missing, invoke
 [`successCallback`](#dom-baseaudiocontext-decodeaudiodata-successcallback) with
 `buffer`.
 :::

 Arguments for the
 [BaseAudioContext.decodeAudioData()](#dom-baseaudiocontext-decodeaudiodata) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`audioData`]

 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer)

 [✘]

 [✘]

 An ArrayBuffer containing compressed audio data.

 [`successCallback`]

 [`DecodeSuccessCallback`](#callback-decodesuccesscallback-parameters)`?`

 [✔]

 [✔]

 A callback function which will be invoked when the decoding is
 finished. The single argument to this callback is an AudioBuffer
 representing the decoded PCM audio data.

 [`errorCallback`]

 [`DecodeErrorCallback`](#callback-decodeerrorcallback-parameters)`?`

 [✔]

 [✔]

 A callback function which will be invoked if there is an error
 decoding the audio file.

 :::
 *Return type:*
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`AudioBuffer`](#AudioBuffer)\>
 :::

#### 1.1.3. Callback [`DecodeSuccessCallback()` Parameters]
[`decodedData`](#dom-decodesuccesscallback-decodeddata), of type [`AudioBuffer`](#AudioBuffer)

: The AudioBuffer containing the decoded audio data.

#### 1.1.4. Callback [`DecodeErrorCallback()` Parameters]
[`error`](#dom-decodeerrorcallback-error), of type [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException)

: The error that occurred while decoding.

#### 1.1.5. Lifetime

Once created, an
[`AudioContext`](#AudioContext) will continue to play sound until it has no more sound
to play, or the page goes away.

#### 1.1.6. Lack of Introspection or Serialization Primitives

The Web Audio API takes a *fire-and-forget* approach to audio source
scheduling. That is, [source
nodes](#audionode-source-nodes) are created for each note during the lifetime of the
[`AudioContext`](#AudioContext), and never explicitly removed from the graph. This is
incompatible with a serialization API, since there is no stable set of
nodes that could be serialized.

Moreover, having an introspection API would allow content script to be
able to observe garbage collections.

#### 1.1.7. System Resources Associated with [`BaseAudioContext` Subclasses]
The subclasses
[`AudioContext`](#AudioContext) and
[`OfflineAudioContext`](#OfflineAudioContext) should be considered expensive objects. Creating these
objects may involve creating a high-priority thread, or using a
low-latency system audio stream, both having an impact on energy
consumption. It is usually not necessary to create more than one
[`AudioContext`](#AudioContext) in a document.

Constructing or resuming a
[`BaseAudioContext`](#BaseAudioContext) subclass involves [acquiring system
resources] for
that context. For
[`AudioContext`](#AudioContext), this also requires creation of a system audio stream.
These operations return when the context begins generating output from
its associated audio graph.

Additionally, a user-agent can have an implementation-defined maximum
number of [`AudioContext`](#AudioContext)s, after which any attempt to create a new
[`AudioContext`](#AudioContext) will fail, [throwing
[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror)].

[`suspend`](#dom-audiocontext-suspend) and
[`close`](#dom-audiocontext-close) allow authors to [release system resources], including threads,
processes and audio streams. Suspending a
[`BaseAudioContext`](#BaseAudioContext) permits implementations to release some of its
resources, and allows it to continue to operate later by invoking
[`resume`](#dom-audiocontext-resume). Closing an
[`AudioContext`](#AudioContext) permits implementations to release all of its
resources, after which it cannot be used or resumed again.

 For example, this can involve waiting for the audio
callbacks to fire regularly, or to wait for the hardware to be ready for
processing.

### 1.2. The [`AudioContext` Interface]
This interface represents an audio graph whose
[`AudioDestinationNode`](#AudioDestinationNode) is routed to a real-time output device that produces a
signal directed at the user. In most use cases, only a single
[`AudioContext`](#AudioContext) is used per document.

```
enum AudioContextLatencyCategory {
 "balanced",
 "interactive",
 "playback"
};
```

::: enum-description
[`AudioContextLatencyCategory`](#enumdef-audiocontextlatencycategory) enumeration description

Enum value

Description

\"[`balanced`]\"

Balance audio output latency and power consumption.

\"[`interactive`]\"

Provide the lowest audio output latency possible without glitching. This
is the default.

\"[`playback`]\"

Prioritize sustained playback without interruption over audio output
latency. Lowest power consumption.

```
enum AudioSinkType {
 "none"
};
```

::: enum-description
[`AudioSinkType`](#enumdef-audiosinktype) Enumeration description

Enum Value

Description

\"[`none`]\"

The audio graph will be processed without being played through an audio
output device.

```
[Exposed=Window]
interface AudioContext : BaseAudioContext {
 constructor (optional AudioContextOptions contextOptions = );
 readonly attribute double baseLatency;
 readonly attribute double outputLatency;
 [SecureContext] readonly attribute (DOMString or AudioSinkInfo) sinkId;
 attribute EventHandler onsinkchange;
 attribute EventHandler onerror;
 [SameObject] readonly attribute AudioPlaybackStats playbackStats;
 AudioTimestamp getOutputTimestamp ();
 Promise<undefined> resume ();
 Promise<undefined> suspend ();
 Promise<undefined> close ();
 [SecureContext] Promise<undefined> setSinkId ((DOMString or AudioSinkOptions) sinkId);
 MediaElementAudioSourceNode createMediaElementSource (HTMLMediaElement mediaElement);
 MediaStreamAudioSourceNode createMediaStreamSource (MediaStream mediaStream);
 MediaStreamTrackAudioSourceNode createMediaStreamTrackSource (
 MediaStreamTrack mediaStreamTrack);
 MediaStreamAudioDestinationNode createMediaStreamDestination ();
};
```

An [`AudioContext`](#AudioContext) is said to be [allowed to start] if the user agent allows the
context state to transition from
\"[`suspended`](#dom-audiocontextstate-suspended)\" to
\"[`running`](#dom-audiocontextstate-running)\". A user agent may disallow this initial transition,
and to allow it only when the
[`AudioContext`](#AudioContext)'s [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) has [sticky
activation](https://html.spec.whatwg.org/multipage/interaction.html#sticky-activation).

[`AudioContext`](#AudioContext) has following internal slots:

[`[[suspended by user]]`]

: A boolean flag representing whether the context is suspended by user
 code. The initial value is `false`.

[`[[sink ID]]`]

: A
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) or an
 [`AudioSinkInfo`](#AudioSinkInfo) representing the identifier or the information of
 the current audio output device respectively. The initial value is
 `""`, which means the default audio output device.

[`[[sink ID at construction]]`]

: A
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) or an
 [`AudioSinkInfo`](#AudioSinkInfo) representing the identifier or the information of
 the audio output device requested at construction, respectively. The
 initial value is `""`, which means the default audio output device.

[`[[pending resume promises]]`]

: An ordered list to store pending
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)s created by
 [`resume()`](#dom-audiocontext-resume). It is initially empty.

[`[[playback stats]]`]

: A slot where the instance of
 [`AudioPlaybackStats`](#AudioPlaybackStats) is stored.

#### 1.2.1. Constructors

[`AudioContext(contextOptions)`]

: :::
 If the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is NOT [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), throw an
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\" and abort these steps.

 [When creating an
 [`AudioContext`](#AudioContext), execute these steps:]
 1. Let `context` be a new
 [`AudioContext`](#AudioContext) object.

 2. Set a
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) to `suspended` on `context`.

 3. Set a
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) to `suspended` on `context`.

 4. Set
 [`[[state before interruption]]`](#dom-baseaudiocontext-state-before-interruption-slot) to `null` on `context`.

 5. Let `messageChannel` be a new
 [`MessageChannel`](https://html.spec.whatwg.org/multipage/web-messaging.html#messagechannel).

 6. Let `controlSidePort` be the value of
 `messageChannel`'s
 [`port1`](https://html.spec.whatwg.org/multipage/web-messaging.html#dom-messagechannel-port1) attribute.

 7. Let `renderingSidePort` be the value of
 `messageChannel`'s
 [`port2`](https://html.spec.whatwg.org/multipage/web-messaging.html#dom-messagechannel-port2) attribute.

 8. Let `serializedRenderingSidePort` be the result of
 [StructuredSerializeWithTransfer](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializewithtransfer)(`renderingSidePort`, «
 `renderingSidePort` »).

 9. Set this
 [`audioWorklet`](#dom-baseaudiocontext-audioworklet)'s
 [`port`](#dom-audioworklet-port) to `controlSidePort`.

 10. [Queue a control message](#queuing) to [set the MessagePort on the
 AudioContextGlobalScope](#setting-the-messageport-on-the-scope),
 with `serializedRenderingSidePort`.

 11. If `contextOptions` is given, perform the following substeps:

 1. If
 [`sinkId`](#dom-audiocontextoptions-sinkid) is specified, let `sinkId` be
 the value of
 `contextOptions.`[`sinkId`](#dom-audiocontextoptions-sinkid) and run the following substeps:

 1. If both `sinkId` and
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) are a type of
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString), and they are equal to each other,
 abort these substeps.

 2. If `sinkId` is a type of
 [`AudioSinkOptions`](#AudioSinkOptions) and
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) is a type of
 [`AudioSinkInfo`](#AudioSinkInfo), and
 [`type`](#dom-audiosinkoptions-type) in `sinkId` and
 [`type`](#dom-audiosinkinfo-type) in
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) are equal, abort these substeps.

 3. If `sinkId` is a type of
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString), set
 [`[[sink ID at construction]]`](#dom-audiocontext-sink-id-at-construction-slot) to `sinkId` and abort these
 substeps.

 4. If `sinkId` is a type of
 [`AudioSinkOptions`](#AudioSinkOptions), set
 [`[[sink ID at construction]]`](#dom-audiocontext-sink-id-at-construction-slot) to a new instance of
 [`AudioSinkInfo`](#AudioSinkInfo) created with the value of
 [`type`](#dom-audiosinkoptions-type) of `sinkId`.

 2. Set the internal latency of `context` according
 to
 `contextOptions.`[`latencyHint`](#dom-audiocontextoptions-latencyhint), as described in
 [`latencyHint`](#dom-audiocontextoptions-latencyhint).

 3. If
 `contextOptions.`[`sampleRate`](#dom-audiocontextoptions-samplerate)` ` is specified, set the
 [`sampleRate`](#dom-baseaudiocontext-samplerate) of `context` to this value.
 Otherwise, follow these substeps:

 1. If `sinkId` is the empty string or a type of
 [`AudioSinkOptions`](#AudioSinkOptions), use the sample rate of the default
 output device. Abort these substeps.

 2. If `sinkId` is a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString), use the sample rate of the output
 device identified by `sinkId`. Abort these
 substeps.

 If
 `contextOptions.`[`sampleRate`](#dom-audiocontextoptions-samplerate) differs from the sample rate of the output
 device, the user agent MUST resample the audio output to
 match the sample rate of the output device.

 If resampling is required, the latency of
 `context` may be affected, possibly by a large
 amount.

 4. Set the
 [`[[render quantum size]]`](#dom-baseaudiocontext-render-quantum-size-slot) of `context` based on the value
 of the
 `contextOptions.`[`renderSizeHint`](#dom-audiocontextoptions-rendersizehint):

 1. If it has the default value of `"default"`, set the
 [`[[render quantum size]]`](#dom-baseaudiocontext-render-quantum-size-slot) private slot to 128.

 2. Else, if it has the value of `"hardware"`, set the
 [`[[render quantum size]]`](#dom-baseaudiocontext-render-quantum-size-slot) private slot to 0.

 3. Else, if an integer has been passed, a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) MUST be thrown if the value is outside
 the range specified in [§ 2.5 Supported Render Quantum
 Sizes](#render-quantum-sizes), otherwise set the
 [`[[render quantum size]]`](#dom-baseaudiocontext-render-quantum-size-slot) private slot to the passed value.

 12. If `context` is [allowed to
 start](#allowed-to-start), send a [control
 message](#control-message) to start processing.

 13. Set
 [`[[playback stats]]`](#dom-audiocontext-playback-stats-slot) to a new instance of
 [`AudioPlaybackStats`](#AudioPlaybackStats).

 14. Return `context`.
 :::

 :::
 Sending a [control
 message](#control-message) to start processing means executing the following
 steps:
 1. Let `validationResult` be the return value of [sink
 identifier validation](#validating-sink-identifier) of
 [`[[sink ID at construction]]`](#dom-audiocontext-sink-id-at-construction-slot).

 2. If `validationResult` is `false`, execute the
 following steps:

 1. Set
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) to the empty string.

 2. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`error`](#eventdef-audiocontext-error) at the
 [`AudioContext`](#AudioContext), and abort the following steps.

 3. Attempt to [acquire system
 resources](#acquiring) to
 use a following audio output device based on
 [`[[sink ID at construction]]`](#dom-audiocontext-sink-id-at-construction-slot) for rendering:

 - The default audio output device for the empty string.

 - An audio output device identified by
 [`[[sink ID at construction]]`](#dom-audiocontext-sink-id-at-construction-slot).

 1. If resource acquisition fails, [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`error`](#eventdef-audiocontext-error) at the
 [`AudioContext`](#AudioContext), and abort the following steps.

 4. Set
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) to the value of
 [`[[sink ID at construction]]`](#dom-audiocontext-sink-id-at-construction-slot).

 5. Set [this](https://webidl.spec.whatwg.org/#this)
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) to `running` on the
 [`AudioContext`](#AudioContext).

 6. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to execute the following steps:

 1. If the
 [`[[render quantum size]]`](#dom-baseaudiocontext-render-quantum-size-slot) of the
 [`AudioContext`](#AudioContext) is 0, set it to the actual hardware render
 quantum size chosen during resource acquisition.

 2. Set the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`AudioContext`](#AudioContext) to
 \"[`running`](#dom-audiocontextstate-running)\".

 3. [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`statechange`](#eventdef-baseaudiocontext-statechange) at the
 [`AudioContext`](#AudioContext).
 :::

 [NOTE:] In cases where an
 [`AudioContext`](#AudioContext) is constructed with no arguments and resource
 acquisition fails, the User-Agent will attempt to silently render
 the audio graph using a mechanism that emulates an audio output
 device.

 :::
 Sending a [control
 message](#control-message) to set the
 [`MessagePort`](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport) on the
 [`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope) means executing the following steps, on the
 [rendering thread](#rendering-thread), with `serializedRenderingSidePort`,
 that has been transfered to the
 [`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope):
 1. Let `deserializedPort` be the result of
 [StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize)(`serializedRenderingSidePort`,
 the current Realm).

 2. Set
 [`port`](#dom-audioworkletglobalscope-port) to `deserializedPort`.
 :::

#### 1.2.2. Attributes

[`baseLatency`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly

: This represents the number of seconds of processing latency incurred
 by the [`AudioContext`](#AudioContext) passing the audio from the
 [`AudioDestinationNode`](#AudioDestinationNode) to the audio subsystem. It does not include any
 additional latency that might be caused by any other processing
 between the output of the
 [`AudioDestinationNode`](#AudioDestinationNode) and the audio hardware and specifically does not
 include any latency incurred the audio graph itself.

 For example, if the audio context is running at 44.1 kHz with
 default render quantum size, and the
 [`AudioDestinationNode`](#AudioDestinationNode) implements double buffering internally and can
 process and output audio each [render
 quantum](#render-quantum),
 then the processing latency is \\((2\\cdot128)/44100 = 5.805
 \\mathrm{ ms}\\), approximately.

[`outputLatency`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly

: The estimation in seconds of audio output latency, i.e., the
 interval between the time the UA requests the host system to play a
 buffer and the time at which the first sample in the buffer is
 actually processed by the audio output device. For devices such as
 speakers or headphones that produce an acoustic signal, this latter
 time refers to the time when a sample's sound is produced.

 An
 [`outputLatency`](#dom-audiocontext-outputlatency) attribute value depends on the platform and the
 connected audio output device hardware. The
 [`outputLatency`](#dom-audiocontext-outputlatency) attribute value may change while the context is
 running or the associated audio output device changes. It is useful
 to query this value frequently when accurate synchronization is
 required.

[`sinkId`], of type `(DOMString or AudioSinkInfo)`, readonly

: Returns the value of
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) internal slot. This attribute is cached upon
 update, and it returns the same object after caching.

[`onsinkchange`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: An [event
 handler](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers) for
 [`setSinkId()`](#dom-audiocontext-setsinkid). The event type of this event handler is
 [`sinkchange`]. This
 event will be dispatched when changing the output device is
 completed.

 [NOTE:] This is not dispatched for the initial device
 selection in the construction of
 [`AudioContext`](#AudioContext). The
 [`statechange`](#eventdef-baseaudiocontext-statechange) event is available to check the readiness of the
 initial output device.

[`onerror`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: An [event
 handler](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers) for the
 [`Event`](https://dom.spec.whatwg.org/#event) dispatched from an
 [`AudioContext`](#AudioContext). The event type of this handler is
 [`error`] and the user
 agent can dispatch this event in the following cases:

 - When initializing and activating a selected audio device
 encounters failures.

 - When the audio output device associated with an
 [`AudioContext`](#AudioContext) is disconnected while the context is
 [`running`](#dom-audiocontextstate-running).

 - When the operating system reports an audio device malfunction.

[`playbackStats`], of type [AudioPlaybackStats](#AudioPlaybackStats), readonly

: An instance of
 [`AudioPlaybackStats`](#AudioPlaybackStats) for this
 [`AudioContext`](#AudioContext). Returns the value of the
 [`[[playback stats]]`](#dom-audiocontext-playback-stats-slot) internal slot.

#### 1.2.3. Methods

[`close()`]

: Closes the
 [`AudioContext`](#AudioContext), [releasing the system
 resources](#releasing) being
 used. This will not automatically release all
 [`AudioContext`](#AudioContext)-created objects, but will suspend the progression
 of the [`AudioContext`](#AudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime), and stop processing audio data.

 :::
 [When close is called, execute these steps:]
 1. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active) then return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Let `promise` be a new Promise.

 3. If the
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) flag on the
 [`AudioContext`](#AudioContext) is `closed` reject the promise with
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror), abort these steps, returning
 `promise`.

 4. Set the
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) flag on the
 [`AudioContext`](#AudioContext) to `closed`.

 5. [Queue a control message](#queuing) to close the
 [`AudioContext`](#AudioContext).

 6. Return *promise*.
 :::

 :::
 Running a [control
 message](#control-message) to close an
 [`AudioContext`](#AudioContext) means running these steps on the [rendering
 thread](#rendering-thread):
 1. Attempt to [release system
 resources](#releasing).

 2. Set the
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) to `suspended`.

 :::
 This will stop rendering.
 :::

 3. If this [control
 message](#control-message) is being run in a reaction to the document
 being unloaded, abort this algorithm.

 :::
 There is no need to notify the control thread in this case.
 :::

 4. [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to execute the following steps:

 1. Resolve *promise*.

 2. If the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`AudioContext`](#AudioContext) is not already
 \"[`closed`](#dom-audiocontextstate-closed)\":

 1. Set the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`AudioContext`](#AudioContext) to
 \"[`closed`](#dom-audiocontextstate-closed)\".

 2. [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`statechange`](#eventdef-baseaudiocontext-statechange) at the
 [`AudioContext`](#AudioContext).
 :::

 When an
 [`AudioContext`](#AudioContext) is closed, any
 [`MediaStream`](https://w3c.github.io/mediacapture-main/#dom-mediastream)s and
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)s that were connected to an
 [`AudioContext`](#AudioContext) will have their output ignored. That is, these will
 no longer cause any output to speakers or other output devices. For
 more flexibility in behavior, consider using
 [`HTMLMediaElement.captureStream()`](https://www.w3.org/TR/mediacapture-fromelement/#dom-htmlmediaelement-capturestream).

 When an
 [`AudioContext`](#AudioContext) has been closed, implementation can choose to
 aggressively release more resources than when suspending.

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)\>
 :::

[`createMediaElementSource(mediaElement)`]

: Creates a
 [`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode) given an
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement). As a consequence of calling this method, audio
 playback from the
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) will be re-routed into the processing graph of the
 [`AudioContext`](#AudioContext).

 Arguments for the
 [AudioContext.createMediaElementSource()](#dom-audiocontext-createmediaelementsource) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`mediaElement`]

 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)

 [✘]

 [✘]

 The media element that will be re-routed.

 :::
 *Return type:*
 [`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode)
 :::

[`createMediaStreamDestination()`]

: Creates a
 [`MediaStreamAudioDestinationNode`](#MediaStreamAudioDestinationNode)

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`MediaStreamAudioDestinationNode`](#MediaStreamAudioDestinationNode)
 :::

[`createMediaStreamSource(mediaStream)`]

: Creates a
 [`MediaStreamAudioSourceNode`](#MediaStreamAudioSourceNode).

 Arguments for the
 [AudioContext.createMediaStreamSource()](#dom-audiocontext-createmediastreamsource) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`mediaStream`]

 [`MediaStream`](https://w3c.github.io/mediacapture-main/#dom-mediastream)

 [✘]

 [✘]

 The media stream that will act as source.

 :::
 *Return type:*
 [`MediaStreamAudioSourceNode`](#MediaStreamAudioSourceNode)
 :::

[`createMediaStreamTrackSource(mediaStreamTrack)`]

: Creates a
 [`MediaStreamTrackAudioSourceNode`](#MediaStreamTrackAudioSourceNode).

 Arguments for the
 [AudioContext.createMediaStreamTrackSource()](#dom-audiocontext-createmediastreamtracksource) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`mediaStreamTrack`]

 [`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack)

 [✘]

 [✘]

 The
 [`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack) that will act as source. [The value of its `kind`
 attribute must be equal to `"audio"`, or an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception MUST be thrown.]

 :::
 *Return type:*
 [`MediaStreamTrackAudioSourceNode`](#MediaStreamTrackAudioSourceNode)
 :::

[`getOutputTimestamp()`]

: Returns a new
 [`AudioTimestamp`](#AudioTimestamp) instance containing two related audio stream
 position values for the context: the
 [`contextTime`](#dom-audiotimestamp-contexttime) member contains the time of the sample frame which
 is currently being rendered by the audio output device (i.e., output
 audio stream position), in the same units and origin as context's
 [`currentTime`](#dom-baseaudiocontext-currenttime); the
 [`performanceTime`](#dom-audiotimestamp-performancetime) member contains the time estimating the moment when
 the sample frame corresponding to the stored `contextTime` value was
 rendered by the audio output device, in the same units and origin as
 `performance.now()` (described in
 [\[hr-time-3\]](#biblio-hr-time-3 "High Resolution Time")).

 If the context's rendering graph has not yet processed a block of
 audio, then
 [`getOutputTimestamp`](#dom-audiocontext-getoutputtimestamp) call returns an
 [`AudioTimestamp`](#AudioTimestamp) instance with both members containing zero.

 After the context's rendering graph has started processing of blocks
 of audio, its
 [`currentTime`](#dom-baseaudiocontext-currenttime) attribute value always exceeds the
 [`contextTime`](#dom-audiotimestamp-contexttime) value obtained from
 [`getOutputTimestamp`](#dom-audiocontext-getoutputtimestamp) method call.

 :::
 (#example-a967f6fb) The value returned from
 [`getOutputTimestamp`](#dom-audiocontext-getoutputtimestamp) method can be used to get performance time
 estimation for the slightly later context's time value:
 ``` highlight
 function outputPerformanceTime(contextTime) {
 const timestamp = context.getOutputTimestamp();
 const elapsedTime = contextTime - timestamp.contextTime;
 return timestamp.performanceTime + elapsedTime * 1000;
 }
 ```

 In the above example the accuracy of the estimation depends on how
 close the argument value is to the current output audio stream
 position: the closer the given `contextTime` is to
 `timestamp.contextTime`, the better the accuracy of the obtained
 estimation.
 :::

 The difference between the values of the context's
 [`currentTime`](#dom-baseaudiocontext-currenttime) and the
 [`contextTime`](#dom-audiotimestamp-contexttime) obtained from
 [`getOutputTimestamp`](#dom-audiocontext-getoutputtimestamp) method call cannot be considered as a reliable
 output latency estimation because
 [`currentTime`](#dom-baseaudiocontext-currenttime) may be incremented at non-uniform time intervals,
 so
 [`outputLatency`](#dom-audiocontext-outputlatency) attribute should be used instead.

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`AudioTimestamp`](#AudioTimestamp)
 :::

[`resume()`]

: Resumes the progression of the
 [`AudioContext`](#AudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime) when it has been suspended.

 :::
 [When resume is called, execute these steps:]
 1. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active) then return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Let `promise` be a new Promise.

 3. If the
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) on the
 [`AudioContext`](#AudioContext) is `closed` reject the promise with
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror), abort these steps, returning
 `promise`.

 4. Set
 [`[[suspended by user]]`](#dom-audiocontext-suspended-by-user-slot) to `false`.

 5. If the context's
 [`state`](#dom-baseaudiocontext-state) attribute is
 \"[`suspended`](#dom-audiocontextstate-suspended)\" and the context's
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) is
 \"[`interrupted`](#dom-audiocontextstate-interrupted)\", then:

 1. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to execute the following steps:

 1. Set the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`AudioContext`](#AudioContext) to
 \"[`interrupted`](#dom-audiocontextstate-interrupted)\".

 2. Set the
 [`[[state before interruption]]`](#dom-baseaudiocontext-state-before-interruption-slot) slot to
 \"[`running`](#dom-audiocontextstate-running)\".

 3. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`statechange`](#eventdef-baseaudiocontext-statechange) at the
 [`AudioContext`](#AudioContext).

 2. Reject the promise with
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror), abort these steps, returning
 `promise`.

 6. If the context is not [allowed to
 start](#allowed-to-start), append `promise` to
 [`[[pending promises]]`](#dom-baseaudiocontext-pending-promises-slot) and
 [`[[pending resume promises]]`](#dom-audiocontext-pending-resume-promises-slot) and abort these steps, returning
 `promise`.

 7. Set the
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) on the
 [`AudioContext`](#AudioContext) to `running`.

 8. [Queue a control message](#queuing) to resume the
 [`AudioContext`](#AudioContext) with `promise`.

 9. Return `promise`.
 :::

 :::
 Running a [control
 message](#control-message) to resume an
 [`AudioContext`](#AudioContext) means running these steps on the [rendering
 thread](#rendering-thread):
 1. Let `promise` be the promise passed into this
 algorithm.

 2. Attempt to [acquire system
 resources](#acquiring).

 3. Set the
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) on the
 [`AudioContext`](#AudioContext) to `running`.

 4. Start [rendering the audio graph](#rendering-loop).

 5. In case of failure, [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to execute the following steps:

 1. Reject all promises from
 [`[[pending resume promises]]`](#dom-audiocontext-pending-resume-promises-slot) in order, then clear
 [`[[pending resume promises]]`](#dom-audiocontext-pending-resume-promises-slot).

 2. Additionally, remove those promises from
 [`[[pending promises]]`](#dom-baseaudiocontext-pending-promises-slot).

 6. [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to execute the following steps:

 1. If the
 [`[[render quantum size]]`](#dom-baseaudiocontext-render-quantum-size-slot) of the
 [`AudioContext`](#AudioContext) is 0, set it to the actual hardware render
 quantum size chosen during resource acquisition.

 2. Resolve all promises from
 [`[[pending resume promises]]`](#dom-audiocontext-pending-resume-promises-slot) in order.

 3. Clear
 [`[[pending resume promises]]`](#dom-audiocontext-pending-resume-promises-slot). Additionally, remove those promises from
 [`[[pending promises]]`](#dom-baseaudiocontext-pending-promises-slot).

 4. Resolve `promise`.

 5. If the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`AudioContext`](#AudioContext) is not already
 \"[`running`](#dom-audiocontextstate-running)\":

 1. Set the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`AudioContext`](#AudioContext) to
 \"[`running`](#dom-audiocontextstate-running)\".

 2. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`statechange`](#eventdef-baseaudiocontext-statechange) at the
 [`AudioContext`](#AudioContext).
 :::

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)\>
 :::

[`suspend()`]

: Suspends the progression of
 [`AudioContext`](#AudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime), allows any current context processing blocks that
 are already processed to be played to the destination, and then
 allows the system to release its claim on audio hardware. This is
 generally useful when the application knows it will not need the
 [`AudioContext`](#AudioContext) for some time, and wishes to temporarily [release
 system resource](#releasing)
 associated with the
 [`AudioContext`](#AudioContext). The promise resolves when the frame buffer is
 empty (has been handed off to the hardware), or immediately (with no
 other effect) if the context is already `suspended`. The promise is
 rejected if the context has been closed.

 :::
 [When suspend is called, execute these steps:]
 1. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active) then return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Let `promise` be a new Promise.

 3. If the
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) on the
 [`AudioContext`](#AudioContext) is `closed` reject the promise with
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror), abort these steps, returning
 `promise`.

 4. Append `promise` to
 [`[[pending promises]]`](#dom-baseaudiocontext-pending-promises-slot).

 5. Set
 [`[[suspended by user]]`](#dom-audiocontext-suspended-by-user-slot) to `true`.

 6. Set the
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) on the
 [`AudioContext`](#AudioContext) to `suspended`.

 7. [Queue a control message](#queuing) to suspend the
 [`AudioContext`](#AudioContext) with `promise`.

 8. Return `promise`.
 :::

 :::
 Running a [control
 message](#control-message) to suspend an
 [`AudioContext`](#AudioContext) means running these steps on the [rendering
 thread](#rendering-thread):
 1. Let `promise` be the promise passed into this
 algorithm.

 2. Attempt to [release system
 resources](#releasing).

 3. If the
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) on the
 [`AudioContext`](#AudioContext) is
 \"[`interrupted`](#dom-audiocontextstate-interrupted)\", [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to set the
 [`[[state before interruption]]`](#dom-baseaudiocontext-state-before-interruption-slot) slot to
 \"[`suspended`](#dom-audiocontextstate-suspended)\".

 4. Set the
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) on the
 [`AudioContext`](#AudioContext) to
 \"[`suspended`](#dom-audiocontextstate-suspended)\".

 5. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to execute the following steps:

 1. Resolve `promise`.

 2. If the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`AudioContext`](#AudioContext) is not already
 \"[`suspended`](#dom-audiocontextstate-suspended)\":

 1. Set the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`AudioContext`](#AudioContext) to
 \"[`suspended`](#dom-audiocontextstate-suspended)\".

 2. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`statechange`](#eventdef-baseaudiocontext-statechange) at the
 [`AudioContext`](#AudioContext).
 :::

 While an
 [`AudioContext`](#AudioContext) is suspended,
 [`MediaStream`](https://w3c.github.io/mediacapture-main/#dom-mediastream)s will have their output ignored; that is, data will
 be lost by the real time nature of media streams.
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)s will similarly have their output ignored until the
 system is resumed.
 [`AudioWorkletNode`](#AudioWorkletNode)s and
 [`ScriptProcessorNode`](#ScriptProcessorNode)s will cease to have their processing handlers
 invoked while suspended, but will resume when the context is
 resumed. For the purpose of
 [`AnalyserNode`](#AnalyserNode) window functions, the data is considered as a
 continuous stream - i.e. the `resume()`/`suspend()` does not cause
 silence to appear in the
 [`AnalyserNode`](#AnalyserNode)'s stream of data. In particular, calling
 [`AnalyserNode`](#AnalyserNode) functions repeatedly when a
 [`AudioContext`](#AudioContext) is suspended MUST return the same data.

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)\>
 :::

[`setSinkId((DOMString or AudioSinkOptions) sinkId)`]

: Sets the identifier of an output device. When this method is
 invoked, the user agent MUST run the following steps:

 :::
 1. Let `sinkId` be the method's first argument.

 2. If `sinkId` is equal to
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot), return a promise, resolve it immediately and
 abort these steps.

 3. Let `validationResult` be the return value of [sink
 identifier validation](#validating-sink-identifier) of
 `sinkId`.

 4. If `validationResult` is `false`, return a promise
 rejected with a new
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) whose name is
 \"[`NotAllowedError`](https://webidl.spec.whatwg.org/#notallowederror)\". Abort these steps.

 5. Let `p` be a new promise.

 6. Send a [control
 message](#control-message) with `p` and `sinkId` to
 start processing.

 7. Return `p`.
 :::

 :::
 Sending a [control
 message](#control-message) to start processing during
 [`setSinkId()`](#dom-audiocontext-setsinkid) means executing the following steps:
 1. Let `p` be the promise passed into this algorithm.

 2. Let `sinkId` be the sink identifier passed into this
 algorithm.

 3. If both `sinkId` and
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) are a type of
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString), and they are equal to each other, [queue a
 media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to resolve `p` and abort these steps.

 4. If `sinkId` is a type of
 [`AudioSinkOptions`](#AudioSinkOptions) and
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) is a type of
 [`AudioSinkInfo`](#AudioSinkInfo), and
 [`type`](#dom-audiosinkoptions-type) in `sinkId` and
 [`type`](#dom-audiosinkinfo-type) in
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) are equal, [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to resolve `p` and abort these steps.

 5. Let `wasRunning` be true.

 6. Set `wasRunning` to false if the
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) on the
 [`AudioContext`](#AudioContext) is `"suspended"`.

 7. Pause the renderer after processing the current render quantum.

 8. Attempt to [release system
 resources](#releasing).

 9. If `wasRunning` is true:

 1. Set the
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) on the
 [`AudioContext`](#AudioContext) to `"suspended"`.

 2. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to execute the following steps:

 1. If the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`AudioContext`](#AudioContext) is not already
 \"[`suspended`](#dom-audiocontextstate-suspended)\":

 1. Set the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`AudioContext`](#AudioContext) to
 \"[`suspended`](#dom-audiocontextstate-suspended)\".

 2. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`statechange`](#eventdef-baseaudiocontext-statechange) at the associated
 [`AudioContext`](#AudioContext).

 10. Attempt to [acquire system
 resources](#acquiring) to use a following
 audio output device based on
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) for rendering:

 - The default audio output device for the empty string.

 - A audio output device identified by
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot).

 In case of failure, reject `p` with
 \"[`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror)\" abort the following steps.

 11. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to execute the following steps:

 1. If `sinkId` is a type of
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString), set
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) to `sinkId`. Abort these steps.

 2. If `sinkId` is a type of
 [`AudioSinkOptions`](#AudioSinkOptions) and
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) is a type of
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString), set
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) to a new instance of
 [`AudioSinkInfo`](#AudioSinkInfo) created with the value of
 [`type`](#dom-audiosinkoptions-type) of `sinkId`.

 3. If `sinkId` is a type of
 [`AudioSinkOptions`](#AudioSinkOptions) and
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) is a type of
 [`AudioSinkInfo`](#AudioSinkInfo), set
 [`type`](#dom-audiosinkinfo-type) of
 [`[[sink ID]]`](#dom-audiocontext-sink-id-slot) to the
 [`type`](#dom-audiosinkoptions-type) value of `sinkId`.

 4. Resolve `p`.

 5. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`sinkchange`](#eventdef-audiocontext-sinkchange) at the associated
 [`AudioContext`](#AudioContext).

 12. If `wasRunning` is true:

 1. Set the
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) on the
 [`AudioContext`](#AudioContext) to `"running"`.

 2. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to execute the following steps:

 1. If the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`AudioContext`](#AudioContext) is not already
 \"[`running`](#dom-audiocontextstate-running)\":

 1. Set the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`AudioContext`](#AudioContext) to
 \"[`running`](#dom-audiocontextstate-running)\".

 2. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`statechange`](#eventdef-baseaudiocontext-statechange) at the associated
 [`AudioContext`](#AudioContext).
 :::

#### 1.2.4. Validating [`sinkId`]
This algorithm is used to validate the information provided to modify
[`sinkId`](#dom-audiocontext-sinkid):

1. Let `document` be the current settings object's
 [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

2. Let `sinkIdArg` be the value passed in to this algorithm.

3. If `document` is not allowed to use the feature
 identified by `"speaker-selection"`, return `false`.

4. If `sinkIdArg` is a type of
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) but it is not equal to the empty string or it does
 not match any audio output device identified by the result that
 would be provided by
 [`enumerateDevices()`](https://w3c.github.io/mediacapture-main/#dom-mediadevices-enumeratedevices), return `false`.

5. Return `true`.

#### 1.2.5. [`AudioContextOptions`]
The
[`AudioContextOptions`](#AudioContextOptions) dictionary is used to specify user-specified options
for an [`AudioContext`](#AudioContext).

```
dictionary AudioContextOptions {
 (AudioContextLatencyCategory or double) latencyHint = "interactive";
 float sampleRate;
 (DOMString or AudioSinkOptions) sinkId;
 (AudioContextRenderSizeCategory or unsigned long) renderSizeHint = "default";
};
```

##### 1.2.5.1. Dictionary [`AudioContextOptions` Members]
[`latencyHint`], of type `(AudioContextLatencyCategory or double)`, defaulting to `"interactive"`

: Identify the type of playback, which affects tradeoffs between audio
 output latency and power consumption.

 The preferred value of the `latencyHint` is a value from
 [`AudioContextLatencyCategory`](#enumdef-audiocontextlatencycategory). However, a double can also be specified for the
 number of seconds of latency for finer control to balance latency
 and power consumption. It is at the browser's discretion to
 interpret the number appropriately. The actual latency used is given
 by AudioContext's
 [`baseLatency`](#dom-audiocontext-baselatency) attribute.

[`sampleRate`], of type [float](https://webidl.spec.whatwg.org/#idl-float)

: Set the
 [`sampleRate`](#dom-baseaudiocontext-samplerate) to this value for the
 [`AudioContext`](#AudioContext) that will be created. See [§ 2.4 Supported Sample
 Rates](#sample-rates) for the required supported range.

 If
 [`sampleRate`](#dom-audiocontextoptions-samplerate) is not specified, the preferred sample rate of the
 output device for this
 [`AudioContext`](#AudioContext) is used.

[`sinkId`], of type `(DOMString or AudioSinkOptions)`

: The identifier or associated information of the audio output device.
 See
 [`sinkId`](#dom-audiocontext-sinkid) for more details.

[`renderSizeHint`], of type `(AudioContextRenderSizeCategory or unsigned long)`, defaulting to `"default"`

: This allows users to ask for a particular [render quantum
 size](#render-quantum-size) when an integer is passed, to use the default of
 128 frames if nothing or `"default"` is passed, or to ask the
 User-Agent to pick a good [render quantum
 size](#render-quantum-size) if `"hardware"` is specified.

 See [§ 2.5 Supported Render Quantum Sizes](#render-quantum-sizes)
 for the required supported range.

 It is a hint that might not be honored.

#### 1.2.6. [`AudioSinkOptions`]
The
[`AudioSinkOptions`](#AudioSinkOptions) dictionary is used to specify options for
[`sinkId`](#dom-audiocontext-sinkid).

```
dictionary AudioSinkOptions {
 required AudioSinkType type;
};
```

##### 1.2.6.1. Dictionary [`AudioSinkOptions` Members]
[`type`], of type [AudioSinkType](#enumdef-audiosinktype)

: A value of
 [`AudioSinkType`](#enumdef-audiosinktype) to specify the type of the device.

#### 1.2.7. [`AudioSinkInfo`]
The [`AudioSinkInfo`](#AudioSinkInfo) interface is used to get information on the current
audio output device via
[`sinkId`](#dom-audiocontext-sinkid).

```
[Exposed=Window]
interface AudioSinkInfo {
 readonly attribute AudioSinkType type;
};
```

##### 1.2.7.1. Attributes

[`type`], of type [AudioSinkType](#enumdef-audiosinktype), readonly

: A value of
 [`AudioSinkType`](#enumdef-audiosinktype) that represents the type of the device.

#### 1.2.8. [`AudioTimestamp`]
```
dictionary AudioTimestamp {
 double contextTime;
 DOMHighResTimeStamp performanceTime;
};
```

##### 1.2.8.1. Dictionary [`AudioTimestamp` Members]
[`contextTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: Represents a point in the time coordinate system of
 BaseAudioContext's
 [`currentTime`](#dom-baseaudiocontext-currenttime).

[`performanceTime`], of type [DOMHighResTimeStamp](https://w3c.github.io/hr-time/#typedefdef-domhighrestimestamp)

: Represents a point in the time coordinate system of a `Performance`
 interface implementation (described in
 [\[hr-time-3\]](#biblio-hr-time-3 "High Resolution Time")).

### 1.3. The [`OfflineAudioContext` Interface]
[`OfflineAudioContext`](#OfflineAudioContext) is a particular type of
[`BaseAudioContext`](#BaseAudioContext) for rendering/mixing-down (potentially) faster than
real-time. It does not render to the audio hardware, but instead renders
as quickly as possible, fulfilling the returned promise with the
rendered result as an
[`AudioBuffer`](#AudioBuffer).

```
[Exposed=Window]
interface OfflineAudioContext : BaseAudioContext {
 constructor(OfflineAudioContextOptions contextOptions);
 constructor(unsigned long numberOfChannels, unsigned long length, float sampleRate);
 Promise<AudioBuffer> startRendering(optional unsigned long? chunkSize = null);
 Promise<undefined> resume();
 Promise<undefined> suspend(double suspendTime);
 Promise<undefined> close();
 readonly attribute unsigned long? length;
 attribute EventHandler oncomplete;
};
```

[`OfflineAudioContext`](#OfflineAudioContext) has the following internal slots:

[`[[rendering started]]`]

: A boolean flag representing whether the rendering has started. The
 initial value is `false`.

[`[[rendered buffers]]`]

: An ordered list of
 [`AudioBuffer`](#AudioBuffer)s that are being rendered. The initial value is an
 empty list.

[`[[committed frames]]`]

: Tracks the number of frames that the
 [`OfflineAudioContext`](#OfflineAudioContext) has committed to render. The initial value is `0`.

[`[[rendered frames]]`]

: Tracks the number of frames that have been rendered. The initial
 value is `0`.

#### 1.3.1. Constructors

[`OfflineAudioContext(contextOptions)`]

: :::
 If the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is NOT [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) and abort these steps.

 Let `c` be a new
 [`OfflineAudioContext`](#OfflineAudioContext) object. Initialize `c` as follows:
 1. Set the
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) for `c` to `"suspended"`.

 2. Set the
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) for `c` to `"suspended"`.

 3. Set the
 [`sampleRate`](#dom-baseaudiocontext-samplerate) for `c`, based on the value of
 `contextOptions.`[`sampleRate`](#dom-offlineaudiocontextoptions-samplerate).

 4. Determine the
 [`[[render quantum size]]`](#dom-baseaudiocontext-render-quantum-size-slot) for `c`, based on the value of the
 `contextOptions.`[`renderSizeHint`](#dom-offlineaudiocontextoptions-rendersizehint):

 1. If it has the default value of `"default"` or `"hardware`\",
 set the
 [`[[render quantum size]]`](#dom-baseaudiocontext-render-quantum-size-slot) private slot to 128.

 2. Else, if an integer has been passed, a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) MUST be thrown if the value is outside the
 range specified in [§ 2.5 Supported Render Quantum
 Sizes](#render-quantum-sizes), otherwise set the
 [`[[render quantum size]]`](#dom-baseaudiocontext-render-quantum-size-slot) private slot to the passed value.

 5. Construct an
 [`AudioDestinationNode`](#AudioDestinationNode) with its
 [`channelCount`](#dom-audionode-channelcount) set to `contextOptions.numberOfChannels`.

 6. Let `messageChannel` be a new
 [`MessageChannel`](https://html.spec.whatwg.org/multipage/web-messaging.html#messagechannel).

 7. Let `controlSidePort` be the value of
 `messageChannel`'s
 [`port1`](https://html.spec.whatwg.org/multipage/web-messaging.html#dom-messagechannel-port1) attribute.

 8. Let `renderingSidePort` be the value of
 `messageChannel`'s
 [`port2`](https://html.spec.whatwg.org/multipage/web-messaging.html#dom-messagechannel-port2) attribute.

 9. Let `serializedRenderingSidePort` be the result of
 [StructuredSerializeWithTransfer](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializewithtransfer)(`renderingSidePort`, «
 `renderingSidePort` »).

 10. Set this
 [`audioWorklet`](#dom-baseaudiocontext-audioworklet)'s
 [`port`](#dom-audioworklet-port) to `controlSidePort`.

 11. [Queue a control message](#queuing) to [set the MessagePort on the
 AudioContextGlobalScope](#setting-the-messageport-on-the-scope),
 with `serializedRenderingSidePort`.
 :::

 Arguments for the
 [OfflineAudioContext.constructor(contextOptions)](#dom-offlineaudiocontext-offlineaudiocontext) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`contextOptions`]
 The initial parameters needed to construct this context.

[`OfflineAudioContext(numberOfChannels, length, sampleRate)`]

: The
 [`OfflineAudioContext`](#OfflineAudioContext) can be constructed with the same arguments as
 AudioContext.createBuffer. [A
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown if any of the arguments is
 negative, zero, or outside its nominal range.]

 The OfflineAudioContext is constructed as if

 ``` highlight
 new OfflineAudioContext({
 numberOfChannels: numberOfChannels,
 length: length,
 sampleRate: sampleRate
 })
 ```

 were called instead.

 Arguments for the [OfflineAudioContext.constructor(numberOfChannels,
 length,
 sampleRate)](#dom-offlineaudiocontext-offlineaudiocontext-numberofchannels-length-samplerate) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`numberOfChannels`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✘]

 Determines how many channels the buffer will have. See
 [`createBuffer()`](#dom-baseaudiocontext-createbuffer) for the supported number of channels.

 [`length`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✘]

 Determines the total size of the audio render in sample-frames.

 [`sampleRate`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 Describes the sample-rate of the [linear
 PCM](#linear-pcm) audio data
 in the buffer in sample-frames per second. See [§ 2.4 Supported
 Sample Rates](#sample-rates) for the required supported range.

#### 1.3.2. Attributes

[`length`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly, nullable

: The total size of the audio render in sample-frames. This is the
 same as the value of the `length` parameter for the constructor.

 For undefined-length rendering, this attribute SHOULD be set to
 `null`.

[`oncomplete`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: The event type of this event handler is
 [`complete`]. The event dispatched to the event
 handler will use the
 [`OfflineAudioCompletionEvent`](#OfflineAudioCompletionEvent) interface. It is the last event fired on an
 [`OfflineAudioContext`](#OfflineAudioContext).

#### 1.3.3. Methods

[`startRendering(chunkSize)`]

: Given the current connections and scheduled changes, starts
 rendering audio.

 Although the primary method of getting the rendered audio data is
 via its promise return value, the instance will also fire an event
 named `complete` for legacy reasons.

 :::
 [When `startRendering` is called, the following steps MUST be
 performed on the [control
 thread](#control-thread):]
 1. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active) then return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).
 2. Let `promise` be a new promise.
 3. If the
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) on the
 [`OfflineAudioContext`](#OfflineAudioContext) is
 [`closed`](#dom-audiocontextstate-closed), reject `promise` with
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) and abort these steps.
 4. If the
 [`OfflineAudioContext`](#OfflineAudioContext)'s
 [`length`](#dom-offlineaudiocontext-length) is not `null` and
 [`[[committed frames]]`](#dom-offlineaudiocontext-committed-frames-slot) is greater than or equal to
 [`OfflineAudioContext`](#OfflineAudioContext)'s
 [`length`](#dom-offlineaudiocontext-length), reject `promise` with
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) and abort these steps.
 5. Let `bufferLength` be a number initialized to the
 value of the
 [`chunkSize`](#dom-offlineaudiocontext-startrendering-chunksize-chunksize).
 1. If the
 [`OfflineAudioContext`](#OfflineAudioContext)'s
 [`length`](#dom-offlineaudiocontext-length) is `null`:
 1. If
 [`chunkSize`](#dom-offlineaudiocontext-startrendering-chunksize-chunksize) is `null`, set
 `bufferLength` to [render quantum
 size](#render-quantum-size).
 2. Otherwise, if the
 [`OfflineAudioContext`](#OfflineAudioContext)'s
 [`length`](#dom-offlineaudiocontext-length) is not `null`:
 1. If
 [`chunkSize`](#dom-offlineaudiocontext-startrendering-chunksize-chunksize) is not `null` and
 [`[[committed frames]]`](#dom-offlineaudiocontext-committed-frames-slot) +
 [`chunkSize`](#dom-offlineaudiocontext-startrendering-chunksize-chunksize) is less than the
 [`OfflineAudioContext`](#OfflineAudioContext)'s
 [`length`](#dom-offlineaudiocontext-length), set `bufferLength` to
 [`chunkSize`](#dom-offlineaudiocontext-startrendering-chunksize-chunksize).
 2. Otherwise, set `bufferLength` to
 [`length`](#dom-offlineaudiocontext-length) -
 [`[[committed frames]]`](#dom-offlineaudiocontext-committed-frames-slot).
 6. If `bufferLength` is not a multiple of [render
 quantum
 size](#render-quantum-size), round it up to the next multiple of the
 [render quantum
 size](#render-quantum-size).
 7. Create a new
 [`AudioBuffer`](#AudioBuffer) `buffer`, with a number of channels
 and sample rate equal respectively to the `numberOfChannels` and
 `sampleRate` values passed to this instance's constructor in the
 `contextOptions` parameter; and length equal to
 `bufferLength`.
 8. If an exception was thrown during the preceding
 [`AudioBuffer`](#AudioBuffer) constructor call, reject `promise`
 with this exception and return `promise`.
 9. Set
 [`[[rendering started]]`](#dom-offlineaudiocontext-rendering-started-slot) to *true*.
 10. Set
 [`[[committed frames]]`](#dom-offlineaudiocontext-committed-frames-slot) to the sum of
 [`[[committed frames]]`](#dom-offlineaudiocontext-committed-frames-slot) and the `buffer`'s
 [`length`](#dom-audiobuffer-length).
 11. Append `buffer` to
 [`[[rendered buffers]]`](#dom-offlineaudiocontext-rendered-buffers-slot) and [begin offline
 rendering](#begin-offline-rendering) for `buffer`.
 12. Append `promise` to
 [`[[pending promises]]`](#dom-baseaudiocontext-pending-promises-slot).
 13. Return `promise`.
 :::

 :::
 To [begin offline rendering] for an
 [`AudioBuffer`](#AudioBuffer) `buffer`, the following steps MUST
 happen on a [rendering
 thread](#rendering-thread) that is created for the occasion.
 1. Given the current connections and scheduled changes, start
 rendering `buffer`'s
 [`length`](#dom-audiobuffer-length) sample-frames of audio into
 `buffer`.
 2. For every [render
 quantum](#render-quantum), check and
 [`suspend`](#dom-offlineaudiocontext-suspend) rendering if necessary.
 3. If a suspended context is resumed, continue to render the
 buffer.
 4. Once the rendering is complete, [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to execute the following steps:
 1. Resolve the `promise` created by
 [`startRendering()`](#dom-offlineaudiocontext-startrendering) with `buffer`.
 2. Remove the `promise` from
 [`[[pending promises]]`](#dom-baseaudiocontext-pending-promises-slot).
 3. Remove `buffer` from
 [`[[rendered buffers]]`](#dom-offlineaudiocontext-rendered-buffers-slot).
 4. Set
 [`[[rendered frames]]`](#dom-offlineaudiocontext-rendered-frames-slot) to the sum of
 [`[[rendered frames]]`](#dom-offlineaudiocontext-rendered-frames-slot) and the
 [`length`](#dom-audiobuffer-length) of `buffer`.
 5. If
 [`length`](#dom-offlineaudiocontext-length) is not `null`:
 1. If
 [`[[rendered frames]]`](#dom-offlineaudiocontext-rendered-frames-slot) is greater than or equal to
 [`length`](#dom-offlineaudiocontext-length), [Queue a control
 message](#queuing) to
 close the
 [`OfflineAudioContext`](#OfflineAudioContext).
 2. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`complete`](#eventdef-offlineaudiocontext-complete) at the
 [`OfflineAudioContext`](#OfflineAudioContext) using
 [`OfflineAudioCompletionEvent`](#OfflineAudioCompletionEvent) whose `renderedBuffer` property is set
 to `buffer`.
 :::

 Arguments for the
 [OfflineAudioContext.startRendering(chunkSize)](#dom-offlineaudiocontext-startrendering) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`chunkSize`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)`?`

 [✔]

 [✔]

 The number of sample-frames to render during this call.

 :::
 *Return type:*
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`AudioBuffer`](#AudioBuffer)\>
 :::

[`resume()`]

: Resumes the progression of the
 [`OfflineAudioContext`](#OfflineAudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime) when it has been suspended.

 :::
 [When resume is called, execute these steps:]
 1. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active) then return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Let `promise` be a new Promise.

 3. Abort these steps and reject `promise` with
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) when any of following conditions is true:

 - The
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) on the
 [`OfflineAudioContext`](#OfflineAudioContext) is `closed`.

 - The
 [`[[rendering started]]`](#dom-offlineaudiocontext-rendering-started-slot) slot on the
 [`OfflineAudioContext`](#OfflineAudioContext) is *false*.

 4. Set the
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) flag on the
 [`OfflineAudioContext`](#OfflineAudioContext) to `running`.

 5. [Queue a control message](#queuing) to resume the
 [`OfflineAudioContext`](#OfflineAudioContext).

 6. Return `promise`.
 :::

 :::
 Running a [control
 message](#control-message) to resume an
 [`OfflineAudioContext`](#OfflineAudioContext) means running these steps on the [rendering
 thread](#rendering-thread):
 1. Set the
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) on the
 [`OfflineAudioContext`](#OfflineAudioContext) to `running`.

 2. Start [rendering the audio graph](#rendering-loop).

 3. In case of failure, [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to reject `promise` and abort the remaining steps.

 4. [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to execute the following steps:

 1. Resolve `promise`.

 2. If the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`OfflineAudioContext`](#OfflineAudioContext) is not already
 \"[`running`](#dom-audiocontextstate-running)\":

 1. Set the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`OfflineAudioContext`](#OfflineAudioContext) to
 \"[`running`](#dom-audiocontextstate-running)\".

 2. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`statechange`](#eventdef-baseaudiocontext-statechange) at the
 [`OfflineAudioContext`](#OfflineAudioContext).
 :::

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)\>
 :::

[`suspend(suspendTime)`]

: Schedules a suspension of the time progression in the audio context
 at the specified time and returns a promise. This is generally
 useful when manipulating the audio graph synchronously on
 [`OfflineAudioContext`](#OfflineAudioContext).

 Note that the maximum precision of suspension is the size of the
 [render quantum](#render-quantum) and the specified suspension time will be rounded
 up to the nearest [render
 quantum](#render-quantum)
 boundary. For this reason, it is not allowed to schedule multiple
 suspends at the same quantized frame. Also, scheduling should be
 done while the context is not running to ensure precise suspension.

 Arguments for the
 [OfflineAudioContext.suspend()](#dom-offlineaudiocontext-suspend) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`suspendTime`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✘]

 Schedules a suspension of the rendering at the specified time, which
 is quantized and rounded up to the [render
 quantum](#render-quantum)
 size. If the quantized frame number

 1. is negative or
 2. is less than or equal to the current time or
 3. is greater than or equal to the total render duration or
 4. is scheduled by another suspend for the same time,

 then the promise is rejected with
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror).

 :::
 *Return type:*
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)\<[`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)\>
 :::

[`close()`]

: Closes the
 [`OfflineAudioContext`](#OfflineAudioContext). This will not automatically release all
 [`AudioContext`](#AudioContext)-created objects, but will suspend the progression
 of the [`AudioContext`](#AudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime), and stop processing audio data.

 :::
 [When close is called, execute these steps:]
 1. If [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active) then return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 \"[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)\"
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Let `promise` be a new Promise.

 3. If the
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) flag on the
 [`OfflineAudioContext`](#OfflineAudioContext) is `closed` reject the promise with
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror), abort these steps, returning
 `promise`.

 4. Set the
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) flag on the
 [`OfflineAudioContext`](#OfflineAudioContext) to `closed`.

 5. [Queue a control message](#queuing) to close the
 [`OfflineAudioContext`](#OfflineAudioContext).

 6. Return *promise*.
 :::

 :::
 Running a [control
 message](#control-message) to close an
 [`OfflineAudioContext`](#OfflineAudioContext) means running these steps on the [rendering
 thread](#rendering-thread):
 1. Set the
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) to `suspended`.

 :::
 This will stop rendering.
 :::

 2. If this [control
 message](#control-message) is being run in a reaction to the document
 being unloaded, abort this algorithm.

 :::
 There is no need to notify the control thread in this case.
 :::

 3. [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to execute the following steps:

 1. Resolve *promise*.

 2. If the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`OfflineAudioContext`](#OfflineAudioContext) is not already
 \"[`closed`](#dom-audiocontextstate-closed)\":

 1. Set the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`OfflineAudioContext`](#OfflineAudioContext) to
 \"[`closed`](#dom-audiocontextstate-closed)\".

 <!-- -->

 1. [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`statechange`](#eventdef-baseaudiocontext-statechange) at the
 [`OfflineAudioContext`](#OfflineAudioContext).
 :::

#### 1.3.4. [`OfflineAudioContextOptions`]
This specifies the options to use in constructing an
[`OfflineAudioContext`](#OfflineAudioContext).

```
dictionary OfflineAudioContextOptions {
 unsigned long numberOfChannels = 1;
 unsigned long? length = null;
 required float sampleRate;
 (AudioContextRenderSizeCategory or unsigned long) renderSizeHint = "default";
};
```

##### 1.3.4.1. Dictionary [`OfflineAudioContextOptions` Members]
[`length`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), nullable, defaulting to `null`

: The length of the rendered
 [`AudioBuffer`](#AudioBuffer) in sample-frames.

[`numberOfChannels`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), defaulting to `1`

: The number of channels for this
 [`OfflineAudioContext`](#OfflineAudioContext).

[`sampleRate`], of type [float](https://webidl.spec.whatwg.org/#idl-float)

: The sample rate for this
 [`OfflineAudioContext`](#OfflineAudioContext). See [§ 2.4 Supported Sample Rates](#sample-rates)
 for the required supported range.

[`renderSizeHint`], of type `(AudioContextRenderSizeCategory or unsigned long)`, defaulting to `"default"`

: A hint for the [render quantum
 size](#render-quantum-size) of this
 [`OfflineAudioContext`](#OfflineAudioContext). See [§ 2.5 Supported Render Quantum
 Sizes](#render-quantum-sizes) for the required supported range.

#### 1.3.5. The [`OfflineAudioCompletionEvent` Interface]
This is an
[`Event`](https://dom.spec.whatwg.org/#event) object which is dispatched to
[`OfflineAudioContext`](#OfflineAudioContext) for legacy reasons.

```
[Exposed=Window]
interface OfflineAudioCompletionEvent : Event {
 constructor (DOMString type, OfflineAudioCompletionEventInit eventInitDict);
 readonly attribute AudioBuffer renderedBuffer;
};
```

##### 1.3.5.1. Attributes

[`renderedBuffer`], of type [AudioBuffer](#AudioBuffer), readonly

: An [`AudioBuffer`](#AudioBuffer) containing the rendered audio data.

##### 1.3.5.2. [`OfflineAudioCompletionEventInit`]
```
dictionary OfflineAudioCompletionEventInit : EventInit {
 required AudioBuffer renderedBuffer;
};
```

###### 1.3.5.2.1. Dictionary [`OfflineAudioCompletionEventInit` Members]
[`renderedBuffer`], of type [AudioBuffer](#AudioBuffer)

: Value to be assigned to the
 [`renderedBuffer`](#dom-offlineaudiocompletionevent-renderedbuffer) attribute of the event.

### 1.4. The [`AudioBuffer` Interface]
This interface represents a memory-resident audio asset. It can contain
one or more channels with each channel appearing to be 32-bit
floating-point [linear PCM](#linear-pcm) values with a nominal range of \\(\[-1,1\]\\) but the
values are not limited to this range. Typically, it would be expected
that the length of the PCM data would be fairly short (usually somewhat
less than a minute). For longer sounds, such as music soundtracks,
streaming should be used with the
[`audio`](https://html.spec.whatwg.org/multipage/media.html#audio) element and
[`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode).

An [`AudioBuffer`](#AudioBuffer) may be used by one or more
[`AudioContext`](#AudioContext)s, and can be shared between an
[`OfflineAudioContext`](#OfflineAudioContext) and an
[`AudioContext`](#AudioContext).

[`AudioBuffer`](#AudioBuffer) has four internal slots:

[`[[number of channels]]`]

: The number of audio channels for this
 [`AudioBuffer`](#AudioBuffer), which is an unsigned long.

[`[[length]]`]

: The length of each channel of this
 [`AudioBuffer`](#AudioBuffer), which is an unsigned long.

[`[[sample rate]]`]

: The sample-rate, in Hz, of this
 [`AudioBuffer`](#AudioBuffer), a float.

[`[[internal data]]`]

: A [data
 block](https://tc39.github.io/ecma262/#sec-data-blocks) holding the audio sample data.

```
[Exposed=Window]
interface AudioBuffer {
 constructor (AudioBufferOptions options);
 readonly attribute float sampleRate;
 readonly attribute unsigned long length;
 readonly attribute double duration;
 readonly attribute unsigned long numberOfChannels;
 Float32Array getChannelData (unsigned long channel);
 undefined copyFromChannel (Float32Array destination,
 unsigned long channelNumber,
 optional unsigned long bufferOffset = 0);
 undefined copyToChannel (Float32Array source,
 unsigned long channelNumber,
 optional unsigned long bufferOffset = 0);
};
```

#### 1.4.1. Constructors

[`AudioBuffer(options)`]

: :::
 1. [If any of the values in
 [`options`](#dom-audiobuffer-constructor-options) lie outside its nominal range,
 throw a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception and abort the following
 steps.]

 2. Let `b` be a new
 [`AudioBuffer`](#AudioBuffer) object.

 3. Respectively assign the values of the attributes
 [`numberOfChannels`](#dom-audiobufferoptions-numberofchannels),
 [`length`](#dom-audiobufferoptions-length),
 [`sampleRate`](#dom-audiobufferoptions-samplerate) of the
 [`AudioBufferOptions`](#AudioBufferOptions) passed in the constructor to the internal slots
 [`[[number of channels]]`](#dom-audiobuffer-number-of-channels-slot),
 [`[[length]]`](#dom-audiobuffer-length-slot),
 [`[[sample rate]]`](#dom-audiobuffer-sample-rate-slot).

 4. Set the internal slot
 [`[[internal data]]`](#dom-audiobuffer-internal-data-slot) of this
 [`AudioBuffer`](#AudioBuffer) to the result of calling
 ` `[`CreateByteDataBlock`](https://tc39.github.io/ecma262/#sec-createbytedatablock)`(`[`[[length]]`](#dom-audiobuffer-length-slot)` * `[`[[number of channels]]`](#dom-audiobuffer-number-of-channels-slot)`)`.

 This initializes the underlying storage to
 zero.

 5. Return `b`.
 :::

 Arguments for the
 [AudioBuffer.constructor()](#dom-audiobuffer-audiobuffer) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`options`]
 [`AudioBufferOptions`](#AudioBufferOptions)
 [✘]
 [✘]
 An
 [`AudioBufferOptions`](#AudioBufferOptions) that determine the properties for this
 [`AudioBuffer`](#AudioBuffer).

#### 1.4.2. Attributes

[`duration`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly

: Duration of the PCM audio data in seconds.

 This is computed from the
 [`[[sample rate]]`](#dom-audiobuffer-sample-rate-slot) and the
 [`[[length]]`](#dom-audiobuffer-length-slot) of the
 [`AudioBuffer`](#AudioBuffer) by performing a division between the
 [`[[length]]`](#dom-audiobuffer-length-slot) and the
 [`[[sample rate]]`](#dom-audiobuffer-sample-rate-slot).

[`length`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Length of the PCM audio data in sample-frames. This MUST return the
 value of
 [`[[length]]`](#dom-audiobuffer-length-slot).

[`numberOfChannels`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: The number of discrete audio channels. This MUST return the value of
 [`[[number of channels]]`](#dom-audiobuffer-number-of-channels-slot).

[`sampleRate`], of type [float](https://webidl.spec.whatwg.org/#idl-float), readonly

: The sample-rate for the PCM audio data in samples per second. This
 MUST return the value of
 [`[[sample rate]]`](#dom-audiobuffer-sample-rate-slot).

#### 1.4.3. Methods

[`copyFromChannel(destination, channelNumber, bufferOffset)`]

: The
 [`copyFromChannel()`](#dom-audiobuffer-copyfromchannel) method copies the samples from the specified
 channel of the
 [`AudioBuffer`](#AudioBuffer) to the `destination` array.

 Let `buffer` be the
 [`AudioBuffer`](#AudioBuffer) with \\(N_b\\) frames, let \\(N_f\\) be the number
 of elements in the
 [`destination`](#dom-audiobuffer-copyfromchannel-destination) array, and \\(k\\) be the value of
 [`bufferOffset`](#dom-audiobuffer-copyfromchannel-bufferoffset). Then the number of frames copied from `buffer` to
 [`destination`](#dom-audiobuffer-copyfromchannel-destination) is \\(\\max(0, \\min(N_b - k, N_f))\\). If this is
 less than \\(N_f\\), then the remaining elements of
 [`destination`](#dom-audiobuffer-copyfromchannel-destination) are not modified.

 Arguments for the
 [AudioBuffer.copyFromChannel()](#dom-audiobuffer-copyfromchannel) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`destination`]

 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)

 [✘]

 [✘]

 The array the channel data will be copied to.

 [`channelNumber`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✘]

 The index of the channel to copy the data from. If `channelNumber`
 is greater or equal than the number of channels of the
 [`AudioBuffer`](#AudioBuffer), [an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) MUST be thrown].

 [`bufferOffset`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✔]

 An optional offset, defaulting to 0. Data from the
 [`AudioBuffer`](#AudioBuffer) starting at this offset is copied to the
 [`destination`](#dom-audiobuffer-copyfromchannel-destination).

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`copyToChannel(source, channelNumber, bufferOffset)`]

: The
 [`copyToChannel()`](#dom-audiobuffer-copytochannel) method copies the samples to the specified channel
 of the [`AudioBuffer`](#AudioBuffer) from the `source` array.

 A
 [`UnknownError`](https://webidl.spec.whatwg.org/#unknownerror) may be thrown if
 [`source`](#dom-audiobuffer-copytochannel-source) cannot be copied to the buffer.

 Let `buffer` be the
 [`AudioBuffer`](#AudioBuffer) with \\(N_b\\) frames, let \\(N_f\\) be the number
 of elements in the
 [`source`](#dom-audiobuffer-copytochannel-source) array, and \\(k\\) be the value of
 [`bufferOffset`](#dom-audiobuffer-copytochannel-bufferoffset). Then the number of frames copied from
 [`source`](#dom-audiobuffer-copytochannel-source) to the `buffer` is \\(\\max(0, \\min(N_b - k,
 N_f))\\). If this is less than \\(N_f\\), then the remaining
 elements of `buffer` are not modified.

 Arguments for the
 [AudioBuffer.copyToChannel()](#dom-audiobuffer-copytochannel) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`source`]

 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)

 [✘]

 [✘]

 The array the channel data will be copied from.

 [`channelNumber`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✘]

 The index of the channel to copy the data to. If `channelNumber` is
 greater or equal than the number of channels of the
 [`AudioBuffer`](#AudioBuffer), [an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) MUST be thrown].

 [`bufferOffset`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✔]

 An optional offset, defaulting to 0. Data from the
 [`source`](#dom-audiobuffer-copytochannel-source) is copied to the
 [`AudioBuffer`](#AudioBuffer) starting at this offset.

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`getChannelData(channel)`]

: According to the rules described in [acquire the
 content](#acquire-the-content) either
 allow
 [writing](https://webidl.spec.whatwg.org/#arraybufferview-write) into or [getting a copy
 of](https://webidl.spec.whatwg.org/#dfn-get-buffer-source-copy) the bytes stored in
 [`[[internal data]]`](#dom-audiobuffer-internal-data-slot) in a new
 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)

 A
 [`UnknownError`](https://webidl.spec.whatwg.org/#unknownerror) may be thrown if the
 [`[[internal data]]`](#dom-audiobuffer-internal-data-slot) or the new
 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array) cannot be created.

 Arguments for the
 [AudioBuffer.getChannelData()](#dom-audiobuffer-getchanneldata) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`channel`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✘]

 This parameter is an index representing the particular channel to
 get data for. An index value of 0 represents the first channel.
 [This index value MUST be less than
 [`[[number of channels]]`](#dom-audiobuffer-number-of-channels-slot) or an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown.]

 :::
 *Return type:*
 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)
 :::

 The methods
[`copyToChannel()`](#dom-audiobuffer-copytochannel) and
[`copyFromChannel()`](#dom-audiobuffer-copyfromchannel) can be used to fill part of an array by passing in a
[`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array) that's a view onto the larger array. When reading data
from an [`AudioBuffer`](#AudioBuffer)'s channels, and the data can be processed in chunks,
[`copyFromChannel()`](#dom-audiobuffer-copyfromchannel) should be preferred to calling
[`getChannelData()`](#dom-audiobuffer-getchanneldata) and accessing the resulting array, because it may avoid
unnecessary memory allocation and copying.

An internal operation [acquire the contents of an
AudioBuffer](#acquire-the-content) is
invoked when the contents of an
[`AudioBuffer`](#AudioBuffer) are needed by some API implementation. This operation
returns immutable channel data to the invoker.

When an [acquire the content] operation occurs on an
[`AudioBuffer`](#AudioBuffer), run the following steps:

1. If any of the
 [`AudioBuffer`](#AudioBuffer)'s
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer)s are
 [detached](https://webidl.spec.whatwg.org/#buffersource-detached), return `true`, abort these steps, and return a
 zero-length channel data buffer to the invoker.

2. [Detach](https://webidl.spec.whatwg.org/#dfn-detach) all
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer)s for arrays previously returned by
 [`getChannelData()`](#dom-audiobuffer-getchanneldata) on this
 [`AudioBuffer`](#AudioBuffer).

 Because
 [`AudioBuffer`](#AudioBuffer) can only be created via
 [`createBuffer()`](#dom-baseaudiocontext-createbuffer) or via the
 [`AudioBuffer`](#AudioBuffer) constructor, this cannot throw.

3. Retain the underlying
 [`[[internal data]]`](#dom-audiobuffer-internal-data-slot) from those
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer)s and return references to them to the invoker.

4. Attach
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer)s containing copies of the data to the
 [`AudioBuffer`](#AudioBuffer), to be returned by the next call to
 [`getChannelData()`](#dom-audiobuffer-getchanneldata).

The [acquire the contents of an
AudioBuffer](#acquire-the-content) operation is invoked in the following cases:

- When
 [`AudioBufferSourceNode.start`](#dom-audiobuffersourcenode-start) is called, it [acquires the
 contents](#acquire-the-content) of the
 node's
 [`buffer`](#dom-audiobuffersourcenode-buffer). If the operation fails, nothing is played.

- When the
 [`buffer`](#dom-audiobuffersourcenode-buffer) of an
 [`AudioBufferSourceNode`](#AudioBufferSourceNode) is set and
 [`AudioBufferSourceNode.start`](#dom-audiobuffersourcenode-start) has been previously called, the setter [acquires the
 content](#acquire-the-content) of the
 [`AudioBuffer`](#AudioBuffer). If the operation fails, nothing is played.

- When a [`ConvolverNode`](#ConvolverNode)'s
 [`buffer`](#dom-convolvernode-buffer) is set to an
 [`AudioBuffer`](#AudioBuffer) it [acquires the
 content](#acquire-the-content) of the
 [`AudioBuffer`](#AudioBuffer).

- When the dispatch of an
 [`AudioProcessingEvent`](#AudioProcessingEvent) completes, it [acquires the
 contents](#acquire-the-content) of its
 [`outputBuffer`](#dom-audioprocessingevent-outputbuffer).

 This means that
[`copyToChannel()`](#dom-audiobuffer-copytochannel) cannot be used to change the content of an
[`AudioBuffer`](#AudioBuffer) currently in use by an
[`AudioNode`](#AudioNode)
that has [acquired the content of an
AudioBuffer](#acquire-the-content) since the
[`AudioNode`](#AudioNode)
will continue to use the data previously acquired.

#### 1.4.4. [`AudioBufferOptions`]
This specifies the options to use in constructing an
[`AudioBuffer`](#AudioBuffer). The
[`length`](#dom-audiobufferoptions-length) and
[`sampleRate`](#dom-audiobufferoptions-samplerate) members are required.

```
dictionary AudioBufferOptions {
 unsigned long numberOfChannels = 1;
 required unsigned long length;
 required float sampleRate;
};
```

##### 1.4.4.1. Dictionary [`AudioBufferOptions` Members]
The allowed values for the members of this dictionary are constrained.
See
[`createBuffer()`](#dom-baseaudiocontext-createbuffer).

[`length`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: The length in sample frames of the buffer. See
 [`length`](#dom-baseaudiocontext-createbuffer-length) for constraints.

[`numberOfChannels`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), defaulting to `1`

: The number of channels for the buffer. See
 [`numberOfChannels`](#dom-baseaudiocontext-createbuffer-numberofchannels) for constraints.

[`sampleRate`], of type [float](https://webidl.spec.whatwg.org/#idl-float)

: The sample rate in Hz for the buffer. See [§ 2.4 Supported Sample
 Rates](#sample-rates) for the required supported range.

### 1.5. The [`AudioNode` Interface]
[`AudioNode`](#AudioNode)s
are the building blocks of an
[`AudioContext`](#AudioContext). This interface represents audio sources, the audio
destination, and intermediate processing modules. These modules can be
connected together to form [processing graphs](#ModularRouting) for
rendering audio to the audio hardware. Each node can have
[inputs](#inputs) and/or
[outputs](#outputs). A [source
node](#source-node) has no inputs
and a single output. Most processing nodes such as filters will have one
input and one output. Each type of
[`AudioNode`](#AudioNode)
differs in the details of how it processes or synthesizes audio. But, in
general, an [`AudioNode`](#AudioNode) will process its inputs (if it has any), and generate
audio for its outputs (if it has any).

Each output has one or more channels. The exact number of channels
depends on the details of the specific
[`AudioNode`](#AudioNode).

An output may connect to one or more
[`AudioNode`](#AudioNode)
inputs, thus *fan-out* is supported. An input initially has no
connections, but may be connected from one or more
[`AudioNode`](#AudioNode)
outputs, thus *fan-in* is supported. When the `connect()` method is
called to connect an output of an
[`AudioNode`](#AudioNode) to
an input of an [`AudioNode`](#AudioNode), we call that a [connection] to the input.

Each [`AudioNode`](#AudioNode) [input] has a specific number of channels at any given time. This
number can change depending on the
[connection](#connection)(s) made
to the input. If the input has no connections then it has one channel
which is silent.

For each [input](#input), an
[`AudioNode`](#AudioNode)
performs a mixing of all connections to that input. Please see [§ 4
Channel Up-Mixing and Down-Mixing](#channel-up-mixing-and-down-mixing)
for normative requirements and details.

The processing of inputs and the internal operations of an
[`AudioNode`](#AudioNode)
take place continuously with respect to
[`AudioContext`](#AudioContext) time, regardless of whether the node has connected
outputs, and regardless of whether these outputs ultimately reach an
[`AudioContext`](#AudioContext)'s
[`AudioDestinationNode`](#AudioDestinationNode).

```
[Exposed=Window]
interface AudioNode : EventTarget {
 AudioNode connect (AudioNode destinationNode,
 optional unsigned long output = 0,
 optional unsigned long input = 0);
 undefined connect (AudioParam destinationParam, optional unsigned long output = 0);
 undefined disconnect ();
 undefined disconnect (unsigned long output);
 undefined disconnect (AudioNode destinationNode);
 undefined disconnect (AudioNode destinationNode, unsigned long output);
 undefined disconnect (AudioNode destinationNode,
 unsigned long output,
 unsigned long input);
 undefined disconnect (AudioParam destinationParam);
 undefined disconnect (AudioParam destinationParam, unsigned long output);
 readonly attribute BaseAudioContext context;
 readonly attribute unsigned long numberOfInputs;
 readonly attribute unsigned long numberOfOutputs;
 attribute unsigned long channelCount;
 attribute ChannelCountMode channelCountMode;
 attribute ChannelInterpretation channelInterpretation;
};
```

#### 1.5.1. AudioNode Creation

[`AudioNode`](#AudioNode)s
can be created in two ways: by using the constructor for this particular
interface, or by using the [factory method] on the
[`BaseAudioContext`](#BaseAudioContext) or
[`AudioContext`](#AudioContext).

The
[`BaseAudioContext`](#BaseAudioContext) passed as first argument of the constructor of an
[`AudioNode`](#AudioNode)s
is called the [associated
[`BaseAudioContext`](#BaseAudioContext)] of the [`AudioNode`](#AudioNode) to be created. Similarly, when using the factory
method, the [associated
`BaseAudioContext`](#associated) of
the [`AudioNode`](#AudioNode) is the
[`BaseAudioContext`](#BaseAudioContext) this factory method is called on.

To create a new [`AudioNode`](#AudioNode) of a particular type `n` using its [factory
method](#factory-method),
called on a
[`BaseAudioContext`](#BaseAudioContext) `c`, execute these steps:

1. Let `node` be a new object of type `n`.

2. Let `option` be a dictionary of the type
 [associated](#associated-option-object) to the interface
 [associated](#associated-interface) to this factory method.

3. For each parameter passed to the factory method, set the dictionary
 member of the same name on `option` to the value of this
 parameter.

4. Call the constructor for `n` on `node` with
 `c` and `option` as arguments.

5. Return `node`

[Initializing] an object `o` that inherits from
[`AudioNode`](#AudioNode)
means executing the following steps, given the arguments
`context` and `dict` passed to the constructor of
this interface.

1. Set `o`'s associated
 [`BaseAudioContext`](#BaseAudioContext) to `context`.

2. Set its value for
 [`numberOfInputs`](#dom-audionode-numberofinputs),
 [`numberOfOutputs`](#dom-audionode-numberofoutputs),
 [`channelCount`](#dom-audionode-channelcount),
 [`channelCountMode`](#dom-audionode-channelcountmode),
 [`channelInterpretation`](#dom-audionode-channelinterpretation) to the default value for this specific interface
 outlined in the section for each
 [`AudioNode`](#AudioNode).

3. For each member of `dict` passed in, execute these steps,
 with `k` the key of the member, and `v` its
 value. If any exceptions is thrown when executing these steps, abort
 the iteration and propagate the exception to the caller of the
 algorithm (constructor or factory method).

 1. If `k` is the name of an
 [`AudioParam`](#AudioParam) on this interface, set the
 [`value`](#dom-audioparam-value) attribute of this
 [`AudioParam`](#AudioParam) to `v`.

 2. Else if `k` is the name of an attribute on this
 interface, set the object associated with this attribute to
 `v`.

The [associated interface] for a factory method is the interface of the
objects that are returned from this method. The [associated option
object] for an interface is the option object that can be passed to
the constructor for this interface.

[`AudioNode`](#AudioNode)s
are
[`EventTarget`](https://dom.spec.whatwg.org/#eventtarget)s, as described in
[\[DOM\]](#biblio-dom "DOM Standard"). This means
that it is possible to dispatch events to
[`AudioNode`](#AudioNode)s
the same way that other
[`EventTarget`](https://dom.spec.whatwg.org/#eventtarget)s accept events.

```
enum ChannelCountMode {
 "max",
 "clamped-max",
 "explicit"
};
```

The
[`ChannelCountMode`](#enumdef-channelcountmode), in conjuction with the node's
[`channelCount`](#dom-audionode-channelcount) and
[`channelInterpretation`](#dom-audionode-channelinterpretation) values, is used to determine the
[computedNumberOfChannels] that controls how inputs to a node are to be
mixed. The
[computedNumberOfChannels](#computednumberofchannels) is determined as shown below. See [§ 4 Channel
Up-Mixing and Down-Mixing](#channel-up-mixing-and-down-mixing) for more
information on how mixing is to be done.

::: enum-description
[`ChannelCountMode`](#enumdef-channelcountmode) enumeration description

Enum value

Description

\"[`max`]\"

[computedNumberOfChannels](#computednumberofchannels) is the maximum of the number of channels of all
connections to an input. In this mode
[`channelCount`](#dom-audionode-channelcount) is ignored.

\"[`clamped-max`]\"

[computedNumberOfChannels](#computednumberofchannels) is determined as for
\"[`max`](#dom-channelcountmode-max)\" and then clamped to a maximum value of the given
[`channelCount`](#dom-audionode-channelcount).

\"[`explicit`]\"

[computedNumberOfChannels](#computednumberofchannels) is the exact value as specified by the
[`channelCount`](#dom-audionode-channelcount).

```
enum ChannelInterpretation {
 "speakers",
 "discrete"
};
```

::: enum-description
[`ChannelInterpretation`](#enumdef-channelinterpretation) enumeration description

Enum value

Description

\"[`speakers`]\"

use [up-mix equations](#UpMix-sub) or [down-mix equations](#down-mix).
In cases where the number of channels do not match any of these basic
speaker layouts, revert to
\"[`discrete`](#dom-channelinterpretation-discrete)\".

\"[`discrete`]\"

Up-mix by filling channels until they run out then zero out remaining
channels. Down-mix by filling as many channels as possible, then
dropping remaining channels.

#### 1.5.2. AudioNode Tail-Time

An [`AudioNode`](#AudioNode)
can have a [tail-time]. This means that even when the
[`AudioNode`](#AudioNode) is
fed silence, the output can be non-silent.

[`AudioNode`](#AudioNode)s
have a non-zero tail-time if they have internal processing state such
that input in the past affects the future output.
[`AudioNode`](#AudioNode)s
may continue to produce non-silent output for the calculated tail-time
even after the input transitions from non-silent to silent.

#### 1.5.3. AudioNode Lifetime

[`AudioNode`](#AudioNode)
can be [actively processing] during a [render
quantum](#render-quantum), if
any of the following conditions hold.

- An
 [`AudioScheduledSourceNode`](#AudioScheduledSourceNode) is [actively
 processing](#actively-processing) if and only if it is
 [playing](#playing) for at least
 part of the current rendering quantum.

- A
 [`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode) is [actively
 processing](#actively-processing) if and only if its
 [`mediaElement`](#dom-mediaelementaudiosourcenode-mediaelement) is playing for at least part of the current rendering
 quantum.

- A
 [`MediaStreamAudioSourceNode`](#MediaStreamAudioSourceNode) or a
 [`MediaStreamTrackAudioSourceNode`](#MediaStreamTrackAudioSourceNode) are [actively
 processing](#actively-processing) when the associated
 [`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack) object has a `readyState` attribute equal to
 `"live"`, a `muted` attribute equal to `false` and an `enabled`
 attribute equal to `true`.

- A [`DelayNode`](#DelayNode)
 in a cycle is [actively
 processing](#actively-processing) only when the absolute value of any output sample for
 the current [render quantum](#render-quantum) is greater than or equal to \\( 2\^{-126} \\).

- A
 [`ScriptProcessorNode`](#ScriptProcessorNode) is [actively
 processing](#actively-processing) when its input or output is connected.

- An
 [`AudioWorkletNode`](#AudioWorkletNode) is [actively
 processing](#actively-processing) when its
 [`AudioWorkletProcessor`](#AudioWorkletProcessor)'s
 [`[[callable process]]`](#dom-audioworkletprocessor-callable-process-slot) returns `true` and either its [active
 source](#active-source) flag
 is `true` or any [`AudioNode`](#AudioNode) connected to one of its inputs is [actively
 processing](#actively-processing).

- All other [`AudioNode`](#AudioNode)s start [actively
 processing](#actively-processing) when any
 [`AudioNode`](#AudioNode)
 connected to one of its inputs is [actively
 processing](#actively-processing), and stops [actively
 processing](#actively-processing) when the input that was received from other [actively
 processing](#actively-processing) [`AudioNode`](#AudioNode) no longer affects the output.

 This takes into account
[`AudioNode`](#AudioNode)s
that have a [tail-time](#tail-time).

[`AudioNode`](#AudioNode)s
that are not [actively
processing](#actively-processing) output a single channel of silence.

#### 1.5.4. Attributes

[`channelCount`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: [`channelCount`](#dom-audionode-channelcount) is the number of channels used when up-mixing and
 down-mixing connections to any inputs to the node. The default value
 is 2 except for specific nodes where its value is specially
 determined. This attribute has no effect for nodes with no inputs.
 [If this value is set to zero or to a value greater than the
 implementation's maximum number of channels the implementation MUST
 throw a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception.]

 In addition, some nodes have additional [channelCount
 constraints] on the possible values for the channel count:

 [`AudioDestinationNode`](#AudioDestinationNode)

 : The behavior depends on whether the destination node is the
 destination of an
 [`AudioContext`](#AudioContext) or
 [`OfflineAudioContext`](#OfflineAudioContext):

 [`AudioContext`](#AudioContext)

 : The channel count MUST be between 1 and
 [`maxChannelCount`](#dom-audiodestinationnode-maxchannelcount). An
 [[`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown for any attempt to
 set the count outside this range].

 [`OfflineAudioContext`](#OfflineAudioContext)

 : The channel count cannot be changed. An
 [[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception MUST be thrown for any attempt to
 change the value.]

 [`AudioWorkletNode`](#AudioWorkletNode)

 : See [§ 1.32.4.3.2 Configuring Channels with
 AudioWorkletNodeOptions](#configuring-channels-with-audioworkletnodeoptions)
 Configuring Channels with
 [`AudioWorkletNodeOptions`](#AudioWorkletNodeOptions).

 [`ChannelMergerNode`](#ChannelMergerNode)

 : The channel count cannot be changed, and an
 [[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception MUST be thrown for any attempt to
 change the value.]

 [`ChannelSplitterNode`](#ChannelSplitterNode)

 : The channel count cannot be changed, and an
 [[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception MUST be thrown for any attempt to
 change the value.]

 [`ConvolverNode`](#ConvolverNode)

 : The channel count cannot be greater than two, and a
 [[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown for any attempt to
 change it to a value greater than two.]

 [`DynamicsCompressorNode`](#DynamicsCompressorNode)

 : The channel count cannot be greater than two, and a
 [[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown for any attempt to
 change it to a value greater than two.]

 [`PannerNode`](#PannerNode)

 : The channel count cannot be greater than two, and a
 [[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown for any attempt to
 change it to a value greater than two.]

 [`ScriptProcessorNode`](#ScriptProcessorNode)

 : The channel count cannot be changed, and an
 [[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown for any attempt to
 change the value.]

 [`StereoPannerNode`](#stereopannernode)

 : The channel count cannot be greater than two, and a
 [[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown for any attempt to
 change it to a value greater than two.]

 See [§ 4 Channel Up-Mixing and
 Down-Mixing](#channel-up-mixing-and-down-mixing) for more
 information on this attribute.

[`channelCountMode`], of type [ChannelCountMode](#enumdef-channelcountmode)

: [`channelCountMode`](#dom-audionode-channelcountmode) determines how channels will be counted when
 up-mixing and down-mixing connections to any inputs to the node. The
 default value is
 \"[`max`](#dom-channelcountmode-max)\". This attribute has no effect for nodes with no
 inputs.

 In addition, some nodes have additional [channelCountMode
 constraints] on the possible
 values for the channel count mode:

 [`AudioDestinationNode`](#AudioDestinationNode)

 : If the
 [`AudioDestinationNode`](#AudioDestinationNode) is the
 [`destination`](#dom-baseaudiocontext-destination) node of an
 [`OfflineAudioContext`](#OfflineAudioContext), then the channel count mode cannot be changed.
 An
 [[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception MUST be thrown for any attempt to
 change the value.]

 [`ChannelMergerNode`](#ChannelMergerNode)

 : The channel count mode cannot be changed from
 \"[`explicit`](#dom-channelcountmode-explicit)\" and an
 [[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception MUST be thrown for any attempt to
 change the value.]

 [`ChannelSplitterNode`](#ChannelSplitterNode)

 : The channel count mode cannot be changed from
 \"[`explicit`](#dom-channelcountmode-explicit)\" and an
 [[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception MUST be thrown for any attempt to
 change the value.]

 [`ConvolverNode`](#ConvolverNode)

 : The channel count mode cannot be set to
 \"[`max`](#dom-channelcountmode-max)\", and a
 [[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown for any attempt to set
 it to
 \"[`max`](#dom-channelcountmode-max)\".]

 [`DynamicsCompressorNode`](#DynamicsCompressorNode)

 : The channel count mode cannot be set to
 \"[`max`](#dom-channelcountmode-max)\", and a
 [[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown for any attempt to set
 it to
 \"[`max`](#dom-channelcountmode-max)\".]

 [`PannerNode`](#PannerNode)

 : The channel count mode cannot be set to
 \"[`max`](#dom-channelcountmode-max)\", and a
 [[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown for any attempt to set
 it to
 \"[`max`](#dom-channelcountmode-max)\".]

 [`ScriptProcessorNode`](#ScriptProcessorNode)

 : The channel count mode cannot be changed from
 \"[`explicit`](#dom-channelcountmode-explicit)\" and an
 [[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown for any attempt to
 change the value.]

 [`StereoPannerNode`](#stereopannernode)

 : The channel count mode cannot be set to
 \"[`max`](#dom-channelcountmode-max)\", and a
 [[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown for any attempt to set
 it to
 \"[`max`](#dom-channelcountmode-max)\".]

 See the [§ 4 Channel Up-Mixing and
 Down-Mixing](#channel-up-mixing-and-down-mixing) section for more
 information on this attribute.

[`channelInterpretation`], of type [ChannelInterpretation](#enumdef-channelinterpretation)

: [`channelInterpretation`](#dom-audionode-channelinterpretation) determines how individual channels will be treated
 when up-mixing and down-mixing connections to any inputs to the
 node. The default value is
 \"[`speakers`](#dom-channelinterpretation-speakers)\". This attribute has no effect for nodes with no
 inputs.

 In addition, some nodes have additional [channelInterpretation
 constraints] on the
 possible values for the channel interpretation:

 [`ChannelSplitterNode`](#ChannelSplitterNode)

 : The channel intepretation can not be changed from
 \"[`discrete`](#dom-channelinterpretation-discrete)\" and a
 [[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception MUST be thrown for any attempt to
 change the value.]

 See [§ 4 Channel Up-Mixing and
 Down-Mixing](#channel-up-mixing-and-down-mixing) for more
 information on this attribute.

[`context`], of type [BaseAudioContext](#BaseAudioContext), readonly

: The
 [`BaseAudioContext`](#BaseAudioContext) which owns this
 [`AudioNode`](#AudioNode).

[`numberOfInputs`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: The number of inputs feeding into the
 [`AudioNode`](#AudioNode). For [source nodes], this
 will be 0. This attribute is predetermined for many
 [`AudioNode`](#AudioNode) types, but some
 [`AudioNode`](#AudioNode)s, like the
 [`ChannelMergerNode`](#ChannelMergerNode) and the
 [`AudioWorkletNode`](#AudioWorkletNode), have variable number of inputs.

[`numberOfOutputs`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: The number of outputs coming out of the
 [`AudioNode`](#AudioNode). This attribute is predetermined for some
 [`AudioNode`](#AudioNode) types, but can be variable, like for the
 [`ChannelSplitterNode`](#ChannelSplitterNode) and the
 [`AudioWorkletNode`](#AudioWorkletNode).

#### 1.5.5. Methods

[`connect(destinationNode, output, input)`]

: There can only be one connection between a given output of one
 specific node and a given input of another specific node. Multiple
 connections with the same termini are ignored.

 :::
 (#example-bbcc3e9e) For example:
 ``` highlight
 nodeA.connect(nodeB);
 nodeA.connect(nodeB);
 ```

 will have the same effect as

 ``` highlight
 nodeA.connect(nodeB);
 ```
 :::

 This method returns `destination`
 [`AudioNode`](#AudioNode) object.

 Arguments for the [AudioNode.connect(destinationNode, output,
 input)](#dom-audionode-connect) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`destinationNode`]

 The `destination` parameter is the
 [`AudioNode`](#AudioNode) to connect to. [If the `destination` parameter is
 an [`AudioNode`](#AudioNode) that has been created using another
 [`AudioContext`](#AudioContext), an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror) MUST be thrown]. That is,
 [`AudioNode`](#AudioNode)s cannot be shared between
 [`AudioContext`](#AudioContext)s. Multiple
 [`AudioNode`](#AudioNode)s can be connected to the same
 [`AudioNode`](#AudioNode), this is described in [Channel Upmixing and down
 mixing](#channel-up-mixing-and-down-mixing) section.

 [`output`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✔]

 The `output` parameter is an index describing which output of the
 [`AudioNode`](#AudioNode) from which to connect. [If this parameter is
 out-of-bounds, an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown.] It is
 possible to connect an
 [`AudioNode`](#AudioNode) output to more than one input with multiple calls
 to connect(). Thus, \"fan-out\" is supported.

 [`input`]

 The `input` parameter is an index describing which input of the
 destination [`AudioNode`](#AudioNode) to connect to. [If this parameter is out-of-bounds,
 an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown.] It is
 possible to connect an
 [`AudioNode`](#AudioNode) to another
 [`AudioNode`](#AudioNode) which creates a [cycle]: an
 [`AudioNode`](#AudioNode) may connect to another
 [`AudioNode`](#AudioNode), which in turn connects back to the input or
 [`AudioParam`](#AudioParam) of the first
 [`AudioNode`](#AudioNode).

 :::
 *Return type:* [`AudioNode`](#AudioNode)
 :::

[`connect(destinationParam, output)`]

: Connects the [`AudioNode`](#AudioNode) to an
 [`AudioParam`](#AudioParam), controlling the parameter value with an
 [a-rate](#a-rate) signal.

 It is possible to connect an
 [`AudioNode`](#AudioNode) output to more than one
 [`AudioParam`](#AudioParam) with multiple calls to connect(). Thus, \"fan-out\"
 is supported.

 It is possible to connect more than one
 [`AudioNode`](#AudioNode) output to a single
 [`AudioParam`](#AudioParam) with multiple calls to connect(). Thus, \"fan-in\"
 is supported.

 An [`AudioParam`](#AudioParam) will take the rendered audio data from any
 [`AudioNode`](#AudioNode) output connected to it and [convert it to
 mono](#down-mix) by down-mixing if it is not already mono, then mix
 it together with other such outputs and finally will mix with the
 *intrinsic* parameter value (the `value` the
 [`AudioParam`](#AudioParam) would normally have without any audio connections),
 including any timeline changes scheduled for the parameter.

 The down-mixing to mono is equivalent to the down-mixing for an
 [`AudioNode`](#AudioNode) with
 [`channelCount`](#dom-audionode-channelcount) = 1,
 [`channelCountMode`](#dom-audionode-channelcountmode) =
 \"[`explicit`](#dom-channelcountmode-explicit)\", and
 [`channelInterpretation`](#dom-audionode-channelinterpretation) =
 \"[`speakers`](#dom-channelinterpretation-speakers)\".

 There can only be one connection between a given output of one
 specific node and a specific
 [`AudioParam`](#AudioParam). Multiple connections with the same termini are
 ignored.

 :::
 (#example-8779522d) For example:
 ``` highlight
 nodeA.connect(param);
 nodeA.connect(param);
 ```

 will have the same effect as

 ``` highlight
 nodeA.connect(param);
 ```
 :::

 Arguments for the [AudioNode.connect(destinationParam,
 output)](#dom-audionode-connect-destinationparam-output) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`destinationParam`]

 [`AudioParam`](#AudioParam)

 [✘]

 [✘]

 The `destination` parameter is the
 [`AudioParam`](#AudioParam) to connect to. This method does not return the
 `destination`
 [`AudioParam`](#AudioParam) object. [If
 [`destinationParam`](#dom-audionode-connect-destinationparam-output-destinationparam) belongs to an
 [`AudioNode`](#AudioNode) that belongs to a
 [`BaseAudioContext`](#BaseAudioContext) that is different from the
 [`BaseAudioContext`](#BaseAudioContext) that has created the
 [`AudioNode`](#AudioNode) on which this method was called, an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror) MUST be thrown.]

 [`output`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✔]

 The `output` parameter is an index describing which output of the
 [`AudioNode`](#AudioNode) from which to connect. [If the `parameter` is
 out-of-bounds, an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown.]

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`disconnect()`]

: Disconnects all outgoing connections from the
 [`AudioNode`](#AudioNode).

 :::
 *No parameters.*
 :::

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`disconnect(output)`]

: Disconnects a single output of the
 [`AudioNode`](#AudioNode) from any other
 [`AudioNode`](#AudioNode) or
 [`AudioParam`](#AudioParam) objects to which it is connected.

 Arguments for the
 [AudioNode.disconnect(output)](#dom-audionode-disconnect-output) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`output`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✘]

 This parameter is an index describing which output of the
 [`AudioNode`](#AudioNode) to disconnect. It disconnects all outgoing
 connections from the given output. [If this parameter is
 out-of-bounds, an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown.]

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`disconnect(destinationNode)`]

: Disconnects all outputs of the
 [`AudioNode`](#AudioNode) that go to a specific destination
 [`AudioNode`](#AudioNode).

 Arguments for the
 [AudioNode.disconnect(destinationNode)](#dom-audionode-disconnect-destinationnode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`destinationNode`]

 The `destinationNode` parameter is the
 [`AudioNode`](#AudioNode) to disconnect. It disconnects all outgoing
 connections to the given `destinationNode`. [If there is no
 connection to the `destinationNode`, an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror) exception MUST be thrown.]

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`disconnect(destinationNode, output)`]

: Disconnects a specific output of the
 [`AudioNode`](#AudioNode) from any and all inputs of some destination
 [`AudioNode`](#AudioNode).

 Arguments for the [AudioNode.disconnect(destinationNode,
 output)](#dom-audionode-disconnect-destinationnode-output) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`destinationNode`]

 The `destinationNode` parameter is the
 [`AudioNode`](#AudioNode) to disconnect. [If there is no connection to the
 `destinationNode` from the given output, an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror) exception MUST be thrown.]

 [`output`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✘]

 The `output` parameter is an index describing which output of the
 [`AudioNode`](#AudioNode) from which to disconnect. [If this parameter is
 out-of-bounds, an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown.]

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`disconnect(destinationNode, output, input)`]

: Disconnects a specific output of the
 [`AudioNode`](#AudioNode) from a specific input of some destination
 [`AudioNode`](#AudioNode).

 Arguments for the [AudioNode.disconnect(destinationNode, output,
 input)](#dom-audionode-disconnect-destinationnode-output-input) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`destinationNode`]

 The `destinationNode` parameter is the
 [`AudioNode`](#AudioNode) to disconnect. [If there is no connection to the
 `destinationNode` from the given output to the given input, an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror) exception MUST be thrown.]

 [`output`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✘]

 The `output` parameter is an index describing which output of the
 [`AudioNode`](#AudioNode) from which to disconnect. [If this parameter is
 out-of-bounds, an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown.]

 [`input`]

 The `input` parameter is an index describing which input of the
 destination [`AudioNode`](#AudioNode) to disconnect. [If this parameter is out-of-bounds,
 an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown.]

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`disconnect(destinationParam)`]

: Disconnects all outputs of the
 [`AudioNode`](#AudioNode) that go to a specific destination
 [`AudioParam`](#AudioParam). The contribution of this
 [`AudioNode`](#AudioNode) to the computed parameter value goes to 0 when this
 operation takes effect. The intrinsic parameter value is not
 affected by this operation.

 Arguments for the
 [AudioNode.disconnect(destinationParam)](#dom-audionode-disconnect-destinationparam) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`destinationParam`]

 [`AudioParam`](#AudioParam)

 [✘]

 [✘]

 The `destinationParam` parameter is the
 [`AudioParam`](#AudioParam) to disconnect. [If there is no connection to the
 `destinationParam`, an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror) exception MUST be thrown.]

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`disconnect(destinationParam, output)`]

: Disconnects a specific output of the
 [`AudioNode`](#AudioNode) from a specific destination
 [`AudioParam`](#AudioParam). The contribution of this
 [`AudioNode`](#AudioNode) to the computed parameter value goes to 0 when this
 operation takes effect. The intrinsic parameter value is not
 affected by this operation.

 Arguments for the [AudioNode.disconnect(destinationParam,
 output)](#dom-audionode-disconnect-destinationparam-output) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`destinationParam`]

 [`AudioParam`](#AudioParam)

 [✘]

 [✘]

 The `destinationParam` parameter is the
 [`AudioParam`](#AudioParam) to disconnect. [If there is no connection to the
 `destinationParam`, an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror) exception MUST be thrown.]

 [`output`]

 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)

 [✘]

 [✘]

 The `output` parameter is an index describing which output of the
 [`AudioNode`](#AudioNode) from which to disconnect. [If the `parameter` is
 out-of-bounds, an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown.]

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

#### 1.5.6. [`AudioNodeOptions`]
This specifies the options that can be used in constructing all
[`AudioNode`](#AudioNode)s.
All members are optional. However, the specific values used for each
node depends on the actual node.

```
dictionary AudioNodeOptions {
 unsigned long channelCount;
 ChannelCountMode channelCountMode;
 ChannelInterpretation channelInterpretation;
};
```

##### 1.5.6.1. Dictionary [`AudioNodeOptions` Members]
[`channelCount`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: Desired number of channels for the
 [`channelCount`](#dom-audionode-channelcount) attribute.

[`channelCountMode`], of type [ChannelCountMode](#enumdef-channelcountmode)

: Desired mode for the
 [`channelCountMode`](#dom-audionode-channelcountmode) attribute.

[`channelInterpretation`], of type [ChannelInterpretation](#enumdef-channelinterpretation)

: Desired mode for the
 [`channelInterpretation`](#dom-audionode-channelinterpretation) attribute.

### 1.6. The [`AudioParam` Interface]
[`AudioParam`](#AudioParam)
controls an individual aspect of an
[`AudioNode`](#AudioNode)'s
functionality, such as volume. The parameter can be set immediately to a
particular value using the `value` attribute. Or, value changes can be
scheduled to happen at very precise times (in the coordinate system of
[`AudioContext`](#AudioContext)'s
[`currentTime`](#dom-baseaudiocontext-currenttime) attribute), for envelopes, volume fades, LFOs, filter
sweeps, grain windows, etc. In this way, arbitrary timeline-based
automation curves can be set on any
[`AudioParam`](#AudioParam). Additionally, audio signals from the outputs of
[`AudioNode`](#AudioNode)s
can be connected to an
[`AudioParam`](#AudioParam), summing with the *intrinsic* parameter value.

Some synthesis and processing
[`AudioNode`](#AudioNode)s
have [`AudioParam`](#AudioParam)s as attributes whose values MUST be taken into account
on a per-audio-sample basis. For other
[`AudioParam`](#AudioParam)s, sample-accuracy is not important and the value
changes can be sampled more coarsely. Each individual
[`AudioParam`](#AudioParam)
will specify that it is either an [a-rate](#a-rate) parameter which means that its values MUST be taken
into account on a per-audio-sample basis, or it is a
[k-rate](#k-rate) parameter.

Implementations MUST use block processing, with each
[`AudioNode`](#AudioNode)
processing one [render
quantum](#render-quantum).

For each [render quantum](#render-quantum), the value of a [k-rate] parameter MUST be sampled at the time of the
very first sample-frame, and that value MUST be used for the entire
block. [a-rate]
parameters MUST be sampled for each sample-frame of the block. Depending
on the [`AudioParam`](#AudioParam), its rate can be controlled by setting the
[`automationRate`](#dom-audioparam-automationrate) attribute to either
\"[`a-rate`](#dom-automationrate-a-rate)\" or
\"[`k-rate`](#dom-automationrate-k-rate)\". See the description of the individual
[`AudioParam`](#AudioParam)s for further details.

Each [`AudioParam`](#AudioParam) includes
[`minValue`](#dom-audioparam-minvalue) and
[`maxValue`](#dom-audioparam-maxvalue) attributes that together form the [simple nominal
range] for the parameter. In effect, value of the parameter is
clamped to the range \\(\[\\mathrm{minValue}, \\mathrm{maxValue}\]\\).
See [§ 1.6.3 Computation of Value](#computation-of-value) for full
details.

For many [`AudioParam`](#AudioParam)s the
[`minValue`](#dom-audioparam-minvalue) and
[`maxValue`](#dom-audioparam-maxvalue) is intended to be set to the maximum possible range. In
this case,
[`maxValue`](#dom-audioparam-maxvalue) should be set to the
[most-positive-single-float] value, which is 3.4028235e38.
(However, in JavaScript which only supports IEEE-754 double precision
float values, this must be written as 3.4028234663852886e38.) Similarly,
[`minValue`](#dom-audioparam-minvalue) should be set to the
[most-negative-single-float] value, which is the negative of
the
[most-positive-single-float](#most-positive-single-float): -3.4028235e38. (Similarly, this must be written in
JavaScript as -3.4028234663852886e38.)

An [`AudioParam`](#AudioParam) maintains a list of zero or more [automation
events]. Each automation event specifies changes to the parameter's
value over a specific time range, in relation to its [automation event
time] in the time coordinate system of the
[`AudioContext`](#AudioContext)'s
[`currentTime`](#dom-baseaudiocontext-currenttime) attribute. The list of automation events is maintained
in ascending order of automation event time.

The behavior of a given automation event is a function of the
[`AudioContext`](#AudioContext)'s current time, as well as the automation event times
of this event and of adjacent events in the list. The following
[automation methods] change the event list
by adding a new event to the event list, of a type specific to the
method:

- [`setValueAtTime()`](#dom-audioparam-setvalueattime) - `SetValue`

- [`linearRampToValueAtTime()`](#dom-audioparam-linearramptovalueattime) - `LinearRampToValue`

- [`exponentialRampToValueAtTime()`](#dom-audioparam-exponentialramptovalueattime) - `ExponentialRampToValue`

- [`setTargetAtTime()`](#dom-audioparam-settargetattime) - `SetTarget`

- [`setValueCurveAtTime()`](#dom-audioparam-setvaluecurveattime) - `SetValueCurve`

The following rules will apply when calling these methods:

- [Automation event
 times](#automation-event-time) are not quantized with respect to the prevailing
 sample rate. Formulas for determining curves and ramps are applied to
 the exact numerical times given when scheduling events.

- If one of these events is added at a time where there is already one
 or more events, then it will be placed in the list after them, but
 before events whose times are after the event.

- [If
 [setValueCurveAtTime()](#dom-audioparam-setvaluecurveattime) is called for time \\(T\\) and duration
 \\(D\\) and there are any events having a time strictly greater than
 \\(T\\), but strictly less than \\(T + D\\), then a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown.] In other
 words, it's not ok to schedule a value curve during a time period
 containing other events, but it's ok to schedule a value curve exactly
 at the time of another event.

- [Similarly a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown if any [automation
 method](#dfn-automation-method) is
 called at a time which is contained in \\(\[T, T+D)\\), \\(T\\) being
 the time of the curve and \\(D\\) its duration. ]

 [`AudioParam`](#AudioParam) attributes are read only, with the exception of the
[`value`](#dom-audioparam-value) attribute.

The automation rate of an
[`AudioParam`](#AudioParam)
can be selected setting the
[`automationRate`](#dom-audioparam-automationrate) attribute with one of the following values. However,
some [`AudioParam`](#AudioParam)s have constraints on whether the automation rate can be
changed.

```
enum AutomationRate {
 "a-rate",
 "k-rate"
};
```

::: enum-description
[`AutomationRate`](#enumdef-automationrate) enumeration description

Enum value

Description

\"[`a-rate`]\"

This [`AudioParam`](#AudioParam) is set for [a-rate](#a-rate) processing.

\"[`k-rate`]\"

This [`AudioParam`](#AudioParam) is set for [k-rate](#k-rate) processing.

Each [`AudioParam`](#AudioParam) has an internal slot
[`[[current value]]`], initially set to the
[`AudioParam`](#AudioParam)'s
[`defaultValue`](#dom-audioparam-defaultvalue).

```
[Exposed=Window]
interface AudioParam {
 attribute float value;
 attribute AutomationRate automationRate;
 readonly attribute float defaultValue;
 readonly attribute float minValue;
 readonly attribute float maxValue;
 AudioParam setValueAtTime (float value, double startTime);
 AudioParam linearRampToValueAtTime (float value, double endTime);
 AudioParam exponentialRampToValueAtTime (float value, double endTime);
 AudioParam setTargetAtTime (float target, double startTime, float timeConstant);
 AudioParam setValueCurveAtTime (sequence<float> values,
 double startTime,
 double duration);
 AudioParam cancelScheduledValues (double cancelTime);
 AudioParam cancelAndHoldAtTime (double cancelTime);
};
```

#### 1.6.1. Attributes

[`automationRate`], of type [AutomationRate](#enumdef-automationrate)

: The automation rate for the
 [`AudioParam`](#AudioParam). The default value depends on the actual
 [`AudioParam`](#AudioParam); see the description of each individual
 [`AudioParam`](#AudioParam) for the default value.

 Some nodes have additional [automation rate
 constraints] as
 follows:

 [`AudioBufferSourceNode`](#AudioBufferSourceNode)

 : The [`AudioParam`](#AudioParam)s
 [`playbackRate`](#dom-audiobuffersourcenode-playbackrate) and
 [`detune`](#dom-audiobuffersourcenode-detune) MUST be
 \"[`k-rate`](#dom-automationrate-k-rate)\". [An
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) must be thrown if the rate is changed to
 \"[`a-rate`](#dom-automationrate-a-rate)\"].

 [`DynamicsCompressorNode`](#DynamicsCompressorNode)

 : The [`AudioParam`](#AudioParam)s
 [`threshold`](#dom-dynamicscompressornode-threshold),
 [`knee`](#dom-dynamicscompressornode-knee),
 [`ratio`](#dom-dynamicscompressornode-ratio),
 [`attack`](#dom-dynamicscompressornode-attack), and
 [`release`](#dom-dynamicscompressornode-release) MUST be
 \"[`k-rate`](#dom-automationrate-k-rate)\". [An
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) must be thrown if the rate is changed to
 \"[`a-rate`](#dom-automationrate-a-rate)\"].

 [`PannerNode`](#PannerNode)

 : If the
 [`panningModel`](#dom-pannernode-panningmodel) is
 \"[`HRTF`](#dom-panningmodeltype-hrtf)\", the setting of the
 [`automationRate`](#dom-audioparam-automationrate) for any
 [`AudioParam`](#AudioParam) of the
 [`PannerNode`](#PannerNode) is ignored. Likewise, the setting of the
 [`automationRate`](#dom-audioparam-automationrate) for any
 [`AudioParam`](#AudioParam) of the
 [`AudioListener`](#AudioListener) is ignored. In this case, the
 [`AudioParam`](#AudioParam) behaves as if the
 [`automationRate`](#dom-audioparam-automationrate) were set to
 \"[`k-rate`](#dom-automationrate-k-rate)\".

[`defaultValue`], of type [float](https://webidl.spec.whatwg.org/#idl-float), readonly

: Initial value for the `value` attribute.

[`maxValue`], of type [float](https://webidl.spec.whatwg.org/#idl-float), readonly

: The nominal maximum value that the parameter can take. Together with
 `minValue`, this forms the [nominal
 range](#nominal-range) for
 this parameter.

[`minValue`], of type [float](https://webidl.spec.whatwg.org/#idl-float), readonly

: The nominal minimum value that the parameter can take. Together with
 `maxValue`, this forms the [nominal
 range](#nominal-range) for
 this parameter.

[`value`], of type [float](https://webidl.spec.whatwg.org/#idl-float)

: The parameter's floating-point value. This attribute is initialized
 to the `defaultValue`.

 Getting this attribute returns the contents of the
 [`[[current value]]`](#dom-audioparam-current-value-slot) slot. See [§ 1.6.3 Computation of
 Value](#computation-of-value) for the algorithm for the value that
 is returned.

 Setting this attribute has the effect of assigning the requested
 value to the
 [`[[current value]]`](#dom-audioparam-current-value-slot) slot, and calling the
 [setValueAtTime()](#dom-audioparam-setvalueattime) method with the current
 [`AudioContext`](#AudioContext)'s `currentTime` and
 [`[[current value]]`](#dom-audioparam-current-value-slot). Any exceptions that would be thrown by
 `setValueAtTime()` will also be thrown by setting this attribute.

#### 1.6.2. Methods

[`cancelAndHoldAtTime(cancelTime)`]

: This is similar to
 [`cancelScheduledValues()`](#dom-audioparam-cancelscheduledvalues) in that it cancels all scheduled parameter changes
 with times greater than or equal to
 [`cancelTime`](#dom-audioparam-cancelandholdattime-canceltime). However, in addition, the
 automation value that would have happened at
 [`cancelTime`](#dom-audioparam-cancelandholdattime-canceltime) is then propagated for all future
 time until other automation events are introduced.

 The behavior of the timeline in the face of
 [`cancelAndHoldAtTime()`](#dom-audioparam-cancelandholdattime) when automations are running and can be introduced
 at any time after calling
 [`cancelAndHoldAtTime()`](#dom-audioparam-cancelandholdattime) and before
 [`cancelTime`](#dom-audioparam-cancelandholdattime-canceltime) is reached is quite complicated. The
 behavior of
 [`cancelAndHoldAtTime()`](#dom-audioparam-cancelandholdattime) is therefore specified in the following algorithm.

 :::
 Let \\(t_c\\) be the value of
 [`cancelTime`](#dom-audioparam-cancelandholdattime-canceltime). Then
 1. Let \\(E_1\\) be the event (if any) at time \\(t_1\\) where
 \\(t_1\\) is the largest number satisfying \\(t_1 \\le t_c\\).

 2. Let \\(E_2\\) be the event (if any) at time \\(t_2\\) where
 \\(t_2\\) is the smallest number satisfying \\(t_c \\lt t_2\\).

 3. If \\(E_2\\) exists:

 1. If \\(E_2\\) is a linear or exponential ramp,

 1. Effectively rewrite \\(E_2\\) to be the same kind of
 ramp ending at time \\(t_c\\) with an end value that
 would be the value of the original ramp at time
 \\(t_c\\). ![Graphical representation of calling
 cancelAndHoldAtTime when linearRampToValueAtTime has
 been called at this
 time.](images/cancel-linear.svg){style="height:75%;width:75%"}

 2. Go to step 5.

 2. Otherwise, go to step 4.

 4. If \\(E_1\\) exists:

 1. If \\(E_1\\) is a `setTarget` event,

 1. Implicitly insert a `setValueAtTime` event at time
 \\(t_c\\) with the value that the `setTarget` would have
 at time \\(t_c\\). ![Graphical representation of calling
 cancelAndHoldAtTime when setTargetAtTime has been called
 at this
 time](images/cancel-setTarget.svg){style="height:75%;width:75%"}

 2. Go to step 5.

 2. If \\(E_1\\) is a `setValueCurve` with a start time of
 \\(t_3\\) and a duration of \\(d\\)

 1. If \\(t_c \\gt t_3 + d\\), go to step 5.

 2. Otherwise,

 1. Effectively replace this event with a
 `setValueCurve` event with a start time of \\(t_3\\)
 and a new duration of \\(t_c-t_3\\). However, this
 is not a true replacement; this automation MUST take
 care to produce the same output as the original, and
 not one computed using a different duration. (That
 would cause sampling of the value curve in a
 slightly different way, producing different
 results.) ![Graphical representation of calling
 cancelAndHoldAtTime when setValueCurve has been
 called at this
 time](images/cancel-setValueCurve.svg){style="height:75%;width:75%"}

 2. Go to step 5.

 5. Remove all events with time greater than \\(t_c\\).

 If no events are added, then the automation value after
 [`cancelAndHoldAtTime()`](#dom-audioparam-cancelandholdattime) is the constant value that the original timeline
 would have had at time \\(t_c\\).
 :::

 Arguments for the
 [AudioParam.cancelAndHoldAtTime()](#dom-audioparam-cancelandholdattime) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`cancelTime`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✘]

 The time after which any previously scheduled parameter changes will
 be cancelled. It is a time in the same time coordinate system as the
 [`AudioContext`](#AudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime) attribute. [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if `cancelTime` is
 negative.] If
 [`cancelTime`](#dom-audioparam-cancelandholdattime-canceltime) is less than
 [`currentTime`](#dom-baseaudiocontext-currenttime), it is clamped to
 [`currentTime`](#dom-baseaudiocontext-currenttime).

 :::
 *Return type:*
 [`AudioParam`](#AudioParam)
 :::

[`cancelScheduledValues(cancelTime)`]

: Cancels all scheduled parameter changes with times greater than or
 equal to
 [`cancelTime`](#dom-audioparam-cancelscheduledvalues-canceltime). Cancelling a scheduled parameter
 change means removing the scheduled event from the event list. Any
 active automations whose [automation event
 time](#automation-event-time) is less than
 [`cancelTime`](#dom-audioparam-cancelscheduledvalues-canceltime) are also cancelled, and such
 cancellations may cause discontinuities because the original value
 (from before such automation) is restored immediately. Any hold
 values scheduled by
 [`cancelAndHoldAtTime()`](#dom-audioparam-cancelandholdattime) are also removed if the hold time occurs after
 [`cancelTime`](#dom-audioparam-cancelscheduledvalues-canceltime).

 For a
 [`setValueCurveAtTime()`](#dom-audioparam-setvaluecurveattime), let \\(T_0\\) and \\(T_D\\) be the corresponding
 [`startTime`](#dom-audioparam-setvaluecurveattime-starttime) and
 [`duration`](#dom-audioparam-setvaluecurveattime-duration), respectively of this event. Then if
 [`cancelTime`](#dom-audioparam-cancelscheduledvalues-canceltime) is in the range \\(\[T_0, T_0 +
 T_D\]\\), the event is removed from the timeline.

 Arguments for the
 [AudioParam.cancelScheduledValues()](#dom-audioparam-cancelscheduledvalues) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`cancelTime`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✘]

 The time after which any previously scheduled parameter changes will
 be cancelled. It is a time in the same time coordinate system as the
 [`AudioContext`](#AudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime) attribute. [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if `cancelTime` is
 negative.] If `cancelTime` is less than
 [`currentTime`](#dom-baseaudiocontext-currenttime), it is clamped to
 [`currentTime`](#dom-baseaudiocontext-currenttime).

 :::
 *Return type:*
 [`AudioParam`](#AudioParam)
 :::

[`exponentialRampToValueAtTime(value, endTime)`]

: Schedules an exponential continuous change in parameter value from
 the previous scheduled parameter value to the given value.
 Parameters representing filter frequencies and playback rate are
 best changed exponentially because of the way humans perceive sound.

 The value during the time interval \\(T_0 \\leq t \< T_1\\) (where
 \\(T_0\\) is the time of the previous event and \\(T_1\\) is the
 [`endTime`](#dom-audioparam-exponentialramptovalueattime-endtime) parameter passed into this method)
 will be calculated as:

 $$
 v(t) = V_0 \left(\frac{V_1}{V_0}\right)^\frac{t - T_0}{T_1 - T_0}
 $$

 where \\(V_0\\) is the value at the time \\(T_0\\) and \\(V_1\\) is
 the
 [`value`](#dom-audioparam-exponentialramptovalueattime-value) parameter passed into this method.
 If \\(V_0\\) and \\(V_1\\) have opposite signs or if \\(V_0\\) is
 zero, then \\(v(t) = V_0\\) for \\(T_0 \\le t \\lt T_1\\).

 This also implies an exponential ramp to 0 is not possible. A good
 approximation can be achieved using
 [`setTargetAtTime()`](#dom-audioparam-settargetattime) with an appropriately chosen time constant.

 If there are no more events after this *ExponentialRampToValue*
 event then for \\(t \\geq T_1\\), \\(v(t) = V_1\\).

 If there is no event preceding this event, the exponential ramp
 behaves as if
 [`setValueAtTime(value, currentTime)`](#dom-audioparam-setvalueattime) were called where `value` is the current value of
 the attribute and `currentTime` is the context
 [`currentTime`](#dom-baseaudiocontext-currenttime) at the time
 [`exponentialRampToValueAtTime()`](#dom-audioparam-exponentialramptovalueattime) is called.

 If the preceding event is a `SetTarget` event, \\(T_0\\) and
 \\(V_0\\) are chosen from the current time and value of `SetTarget`
 automation. That is, if the `SetTarget` event has not started,
 \\(T_0\\) is the start time of the event, and \\(V_0\\) is the value
 just before the `SetTarget` event starts. In this case, the
 `ExponentialRampToValue` event effectively replaces the `SetTarget`
 event. If the `SetTarget` event has already started, \\(T_0\\) is
 the current context time, and \\(V_0\\) is the current `SetTarget`
 automation value at time \\(T_0\\). In both cases, the automation
 curve is continuous.

 Arguments for the
 [AudioParam.exponentialRampToValueAtTime()](#dom-audioparam-exponentialramptovalueattime) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`value`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 The value the parameter will exponentially ramp to at the given
 time. [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if this value is equal to
 0.]

 [`endTime`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✘]

 The time in the same time coordinate system as the
 [`AudioContext`](#AudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime) attribute where the exponential ramp ends. [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if `endTime` is negative
 or is not a finite number.] If `endTime` is
 less than
 [`currentTime`](#dom-baseaudiocontext-currenttime), it is clamped to
 [`currentTime`](#dom-baseaudiocontext-currenttime).

 :::
 *Return type:*
 [`AudioParam`](#AudioParam)
 :::

[`linearRampToValueAtTime(value, endTime)`]

: Schedules a linear continuous change in parameter value from the
 previous scheduled parameter value to the given value.

 The value during the time interval \\(T_0 \\leq t \< T_1\\) (where
 \\(T_0\\) is the time of the previous event and \\(T_1\\) is the
 [`endTime`](#dom-audioparam-linearramptovalueattime-endtime) parameter passed into this method)
 will be calculated as:

 $$
 v(t) = V_0 + (V_1 - V_0) \frac{t - T_0}{T_1 - T_0}
 $$

 where \\(V_0\\) is the value at the time \\(T_0\\) and \\(V_1\\) is
 the
 [`value`](#dom-audioparam-linearramptovalueattime-value) parameter passed into this method.

 If there are no more events after this *LinearRampToValue* event
 then for \\(t \\geq T_1\\), \\(v(t) = V_1\\).

 If there is no event preceding this event, the linear ramp behaves
 as if
 [`setValueAtTime(value, currentTime)`](#dom-audioparam-setvalueattime) were called where `value` is the current value of
 the attribute and `currentTime` is the context
 [`currentTime`](#dom-baseaudiocontext-currenttime) at the time
 [`linearRampToValueAtTime()`](#dom-audioparam-linearramptovalueattime) is called.

 If the preceding event is a `SetTarget` event, \\(T_0\\) and
 \\(V_0\\) are chosen from the current time and value of `SetTarget`
 automation. That is, if the `SetTarget` event has not started,
 \\(T_0\\) is the start time of the event, and \\(V_0\\) is the value
 just before the `SetTarget` event starts. In this case, the
 `LinearRampToValue` event effectively replaces the `SetTarget`
 event. If the `SetTarget` event has already started, \\(T_0\\) is
 the current context time, and \\(V_0\\) is the current `SetTarget`
 automation value at time \\(T_0\\). In both cases, the automation
 curve is continuous.

 Arguments for the
 [AudioParam.linearRampToValueAtTime()](#dom-audioparam-linearramptovalueattime) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`value`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 The value the parameter will linearly ramp to at the given time.

 [`endTime`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✘]

 The time in the same time coordinate system as the
 [`AudioContext`](#AudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime) attribute at which the automation ends. [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if `endTime` is negative
 or is not a finite number.] If `endTime` is
 less than
 [`currentTime`](#dom-baseaudiocontext-currenttime), it is clamped to
 [`currentTime`](#dom-baseaudiocontext-currenttime).

 :::
 *Return type:*
 [`AudioParam`](#AudioParam)
 :::

[`setTargetAtTime(target, startTime, timeConstant)`]

: Start exponentially approaching the target value at the given time
 with a rate having the given time constant. Among other uses, this
 is useful for implementing the \"decay\" and \"release\" portions of
 an ADSR envelope. Please note that the parameter value does not
 immediately change to the target value at the given time, but
 instead gradually changes to the target value.

 During the time interval: \\(T_0 \\leq t\\), where \\(T_0\\) is the
 [`startTime`](#dom-audioparam-settargetattime-starttime) parameter:

 $$
 v(t) = V_1 + (V_0 - V_1)\, e^{-\left(\frac{t - T_0}{\tau}\right)}
 $$

 where \\(V_0\\) is the initial value (the
 [`[[current value]]`](#dom-audioparam-current-value-slot) attribute) at \\(T_0\\) (the
 [`startTime`](#dom-audioparam-settargetattime-starttime) parameter), \\(V_1\\) is equal to
 the
 [`target`](#dom-audioparam-settargetattime-target) parameter, and \\(\\tau\\) is the
 [`timeConstant`](#dom-audioparam-settargetattime-timeconstant) parameter.

 If a `LinearRampToValue` or `ExponentialRampToValue` event follows
 this event, the behavior is described in
 [`linearRampToValueAtTime()`](#dom-audioparam-linearramptovalueattime) or
 [`exponentialRampToValueAtTime()`](#dom-audioparam-exponentialramptovalueattime), respectively. For all other events, the
 `SetTarget` event ends at the time of the next event.

 Arguments for the
 [AudioParam.setTargetAtTime()](#dom-audioparam-settargetattime) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`target`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 The value the parameter will *start* changing to at the given time.

 [`startTime`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✘]

 The time at which the exponential approach will begin, in the same
 time coordinate system as the
 [`AudioContext`](#AudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime) attribute. [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if `start` is negative or
 is not a finite number.] If `startTime` is
 less than
 [`currentTime`](#dom-baseaudiocontext-currenttime), it is clamped to
 [`currentTime`](#dom-baseaudiocontext-currenttime).

 [`timeConstant`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 The time-constant value of first-order filter (exponential) approach
 to the target value. The larger this value is, the slower the
 transition will be. [The value MUST be non-negative or a
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown.] If
 `timeConstant` is zero, the output value jumps immediately to the
 final value. More precisely, *timeConstant* is the time it takes a
 first-order linear continuous time-invariant system to reach the
 value \\(1 - 1/e\\) (around 63.2%) given a step input response
 (transition from 0 to 1 value).

 :::
 *Return type:*
 [`AudioParam`](#AudioParam)
 :::

[`setValueAtTime(value, startTime)`]

: Schedules a parameter value change at the given time.

 If there are no more events after this `SetValue` event, then for
 \\(t \\geq T_0\\), \\(v(t) = V\\), where \\(T_0\\) is the
 [`startTime`](#dom-audioparam-setvalueattime-starttime) parameter and \\(V\\) is the
 [`value`](#dom-audioparam-setvalueattime-value) parameter. In other words, the value
 will remain constant.

 If the next event (having time \\(T_1\\)) after this `SetValue`
 event is not of type `LinearRampToValue` or
 `ExponentialRampToValue`, then, for \\(T_0 \\leq t \< T_1\\):

 $$
 v(t) = V
 $$

 In other words, the value will remain constant during this time
 interval, allowing the creation of \"step\" functions.

 If the next event after this `SetValue` event is of type
 `LinearRampToValue` or `ExponentialRampToValue` then please see
 [`linearRampToValueAtTime()`](#dom-audioparam-linearramptovalueattime) or
 [`exponentialRampToValueAtTime()`](#dom-audioparam-exponentialramptovalueattime), respectively.

 Arguments for the
 [AudioParam.setValueAtTime()](#dom-audioparam-setvalueattime) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`value`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 The value the parameter will change to at the given time.

 [`startTime`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✘]

 The time in the same time coordinate system as the
 [`BaseAudioContext`](#BaseAudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime) attribute at which the parameter changes to the
 given value. [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if `startTime` is negative
 or is not a finite number.] If `startTime`
 is less than
 [`currentTime`](#dom-baseaudiocontext-currenttime), it is clamped to
 [`currentTime`](#dom-baseaudiocontext-currenttime).

 :::
 *Return type:*
 [`AudioParam`](#AudioParam)
 :::

[`setValueCurveAtTime(values, startTime, duration)`]

: Sets an array of arbitrary parameter values starting at the given
 time for the given duration. The number of values will be scaled to
 fit into the desired duration.

 Let \\(T_0\\) be
 [`startTime`](#dom-audioparam-setvaluecurveattime-starttime), \\(T_D\\) be
 [`duration`](#dom-audioparam-setvaluecurveattime-duration), \\(V\\) be the
 [`values`](#dom-audioparam-setvaluecurveattime-values) array, and \\(N\\) be the length of
 the
 [`values`](#dom-audioparam-setvaluecurveattime-values) array. Then, during the time
 interval: \\(T_0 \\le t \< T_0 + T_D\\), let

 $$
 \begin{align*} k &amp;= \left\lfloor \frac{N - 1}{T_D}(t-T_0) \right\rfloor \\
 \end{align*}
 $$

 Then \\(v(t)\\) is computed by linearly interpolating between
 \\(V\[k\]\\) and \\(V\[k+1\]\\),

 After the end of the curve time interval (\\(t \\ge T_0 + T_D\\)),
 the value will remain constant at the final curve value, until there
 is another automation event (if any).

 An implicit call to
 [`setValueAtTime()`](#dom-audioparam-setvalueattime) is made at time \\(T_0 + T_D\\) with value
 \\(V\[N-1\]\\) so that following automations will start from the end
 of the
 [`setValueCurveAtTime()`](#dom-audioparam-setvaluecurveattime) event.

 Arguments for the
 [AudioParam.setValueCurveAtTime()](#dom-audioparam-setvaluecurveattime) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`values`]

 [`sequence`](https://webidl.spec.whatwg.org/#idl-sequence)`<`[`float`](https://webidl.spec.whatwg.org/#idl-float)`>`

 [✘]

 [✘]

 A sequence of float values representing a parameter value curve.
 These values will apply starting at the given time and lasting for
 the given duration. When this method is called, an internal copy of
 the curve is created for automation purposes. Subsequent
 modifications of the contents of the passed-in array therefore have
 no effect on the
 [`AudioParam`](#AudioParam). [An
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) MUST be thrown if this attribute is a
 `sequence<float>` object that has a length less than
 2.]

 [`startTime`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✘]

 The start time in the same time coordinate system as the
 [`AudioContext`](#AudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime) attribute at which the value curve will be applied.
 [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if `startTime` is negative
 or is not a finite number]. If `startTime`
 is less than
 [`currentTime`](#dom-baseaudiocontext-currenttime), it is clamped to
 [`currentTime`](#dom-baseaudiocontext-currenttime).

 [`duration`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✘]

 The amount of time in seconds (after the `startTime` parameter)
 where values will be calculated according to the `values` parameter.
 [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if `duration` is not
 strictly positive or is not a finite number].

 :::
 *Return type:*
 [`AudioParam`](#AudioParam)
 :::

#### 1.6.3. Computation of Value

There are two different kind of
[`AudioParam`](#AudioParam)s, [simple
parameters](#simple-parameter) and [compound
parameters](#compound-parameter). [Simple parameters] (the
default) are used on their own to compute the final audio output of an
[`AudioNode`](#AudioNode).
[Compound parameters] are
[`AudioParam`](#AudioParam)s that are used with other
[`AudioParam`](#AudioParam)s to compute a value that is then used as an input to
compute the output of an
[`AudioNode`](#AudioNode).

The [computedValue] is the final value controlling the audio DSP and is
computed by the audio rendering thread during each rendering time
quantum.

The computation of the value of an
[`AudioParam`](#AudioParam)
consists of two parts:

- the `paramIntrinsicValue` value that is computed from the
 [`value`](#dom-audioparam-value) attribute and any [automation
 events](#dfn-automation-event).

- the `paramComputedValue` that is the final value
 controlling the audio DSP and is computed by the audio rendering
 thread during each [render
 quantum](#render-quantum).

These values MUST be computed as follows:

1. `paramIntrinsicValue` will be calculated at each time,
 which is either the value set directly to the
 [`value`](#dom-audioparam-value) attribute, or, if there are any [automation
 events](#dfn-automation-event) with
 times before or at this time, the value as calculated from these
 events. If automation events are removed from a given time range,
 then the `paramIntrinsicValue` value will remain
 unchanged and stay at its previous value until either the
 [`value`](#dom-audioparam-value) attribute is directly set, or automation events are
 added for the time range.

2. Set
 [`[[current value]]`](#dom-audioparam-current-value-slot) to the value of `paramIntrinsicValue` at
 the beginning of this [render
 quantum](#render-quantum).

3. `paramComputedValue` is the sum of the
 `paramIntrinsicValue` value and the value of the [input
 AudioParam
 buffer](#input-audioparam-buffer).
 If the sum is `NaN`, replace the sum with the
 [`defaultValue`](#dom-audioparam-defaultvalue).

4. If this [`AudioParam`](#AudioParam) is a [compound
 parameter](#compound-parameter), compute its final value with other
 [`AudioParam`](#AudioParam)s.

5. Set [computedValue](#computedvalue) to `paramComputedValue`.

The [nominal range] for a
[computedValue](#computedvalue)
are the lower and higher values this parameter can effectively have. For
[simple parameters](#simple-parameter), the
[computedValue](#computedvalue)
is clamped to the [simple nominal
range](#simple-nominal-range) for this parameter. [Compound
parameters](#compound-parameter) have their final value clamped to their [nominal
range](#nominal-range) after
having been computed from the different
[`AudioParam`](#AudioParam)
values they are composed of.

When automation methods are used, clamping is still applied. However,
the automation is run as if there were no clamping at all. Only when the
automation values are to be applied to the output is the clamping done
as specified above.

For example, consider a node \\(N\\)
has an AudioParam \\(p\\) with a nominal range of \\(\[0, 1\]\\), and
following automation sequence

``` highlight
N.p.setValueAtTime(0, 0);
N.p.linearRampToValueAtTime(4, 1);
N.p.linearRampToValueAtTime(0, 2);
```

The initial slope of the curve is 4, until it reaches the maximum value
of 1, at which time, the output is held constant. Finally, near time 2,
the slope of the curve is -4. This is illustrated in the graph below
where the dashed line indicates what would have happened without
clipping, and the solid line indicates the actual expected behavior of
the audioparam due to clipping to the nominal range.

![An example of clipping of an AudioParam automation from the nominal
range.](images/audioparam-automation-clipping.png){a
height="546" width="915"}

#### 1.6.4. [`AudioParam` Automation Example]
![An example of parameter
automation.](images/audioparam-automation1.png){a
height="541" width="917"}

```
const curveLength = 44100;const curve = new Float32Array(curveLength);for (const i = 0; i < curveLength; ++i) curve[i] = Math.sin(Math.PI * i / curveLength);const t0 = 0;const t1 = 0.1;const t2 = 0.2;const t3 = 0.3;const t4 = 0.325;const t5 = 0.5;const t6 = 0.6;const t7 = 0.7;const t8 = 1.0;const timeConstant = 0.1;param.setValueAtTime(0.2, t0);param.setValueAtTime(0.3, t1);param.setValueAtTime(0.4, t2);param.linearRampToValueAtTime(1, t3);param.linearRampToValueAtTime(0.8, t4);param.setTargetAtTime(.5, t4, timeConstant);// Compute where the setTargetAtTime will be at time t5 so we can make// the following exponential start at the right point so there's no// jump discontinuity. From the spec, we have// v(t) = 0.5 + (0.8 - 0.5)*exp(-(t-t4)/timeConstant)// Thus v(t5) = 0.5 + (0.8 - 0.5)*exp(-(t5-t4)/timeConstant)param.setValueAtTime(0.5 + (0.8 - 0.5)*Math.exp(-(t5 - t4)/timeConstant), t5);param.exponentialRampToValueAtTime(0.75, t6);param.exponentialRampToValueAtTime(0.05, t7);param.setValueCurveAtTime(curve, t7, t8 - t7);
```

### 1.7. The [`AudioScheduledSourceNode` Interface]
The interface represents the common features of source nodes such as
[`AudioBufferSourceNode`](#AudioBufferSourceNode),
[`ConstantSourceNode`](#ConstantSourceNode), and
[`OscillatorNode`](#OscillatorNode).

Before a source is started (by calling
[`start()`](#dom-audioscheduledsourcenode-start), the source node MUST output silence (0). After a
source has been stopped (by calling
[`stop()`](#dom-audioscheduledsourcenode-stop)), the source MUST then output silence (0).

[`AudioScheduledSourceNode`](#AudioScheduledSourceNode) cannot be instantiated directly, but is instead
extended by the concrete interfaces for the source nodes.

An
[`AudioScheduledSourceNode`](#AudioScheduledSourceNode) is said to be [playing] when its associated
[`BaseAudioContext`](#BaseAudioContext)'s
[`currentTime`](#BaseAudioContext) is greater or equal to the time the
[`AudioScheduledSourceNode`](#AudioScheduledSourceNode) is set to start, and less than the time it's set to
stop.

[`AudioScheduledSourceNode`](#AudioScheduledSourceNode)s are created with an internal boolean slot
[`[[source started]]`], initially set to false.

```
[Exposed=Window]
interface AudioScheduledSourceNode : AudioNode {
 attribute EventHandler onended;
 undefined start(optional double when = 0);
 undefined stop(optional double when = 0);
};
```

#### 1.7.1. Attributes

[`onended`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: A property used to set an [event
 handler](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers) for the
 [`ended`] event type that is dispatched to
 [`AudioScheduledSourceNode`](#AudioScheduledSourceNode) node types. When the source node has stopped
 playing (as determined by the concrete node), an event that uses the
 [`Event`](https://dom.spec.whatwg.org/#event) interface will be dispatched to the event handler.

 For all
 [`AudioScheduledSourceNode`](#AudioScheduledSourceNode)s, the
 [`ended`](#eventdef-audioscheduledsourcenode-ended) event is dispatched when the stop time determined
 by
 [`stop()`](#dom-audioscheduledsourcenode-stop) is reached. For an
 [`AudioBufferSourceNode`](#AudioBufferSourceNode), the event is also dispatched because the
 [`duration`](#dom-audiobuffersourcenode-start-when-offset-duration-duration) has been reached or if the entire
 [`buffer`](#dom-audiobuffersourcenode-buffer) has been played.

#### 1.7.2. Methods

[`start(when)`]

: Schedules a sound to playback at an exact time.

 :::
 [When this method is called, execute these steps:]
 1. [If this
 [`AudioScheduledSourceNode`](#AudioScheduledSourceNode) internal slot
 [`[[source started]]`](#dom-audioscheduledsourcenode-source-started-slot) is true, an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception MUST be thrown.]

 2. Check for any errors that must be thrown due to parameter
 constraints described below. If any exception is thrown during
 this step, abort those steps.

 3. Set the internal slot
 [`[[source started]]`](#dom-audioscheduledsourcenode-source-started-slot) on this
 [`AudioScheduledSourceNode`](#AudioScheduledSourceNode) to `true`.

 4. [Queue a control message](#queuing) to start the
 [`AudioScheduledSourceNode`](#AudioScheduledSourceNode), including the parameter values in the message.

 5. Send a [control
 message](#control-message) to the associated
 [`AudioContext`](#AudioContext) to [start running its rendering
 thread](#context-resume) only when all the following conditions
 are met:

 1. The context's
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) is
 \"[`suspended`](#dom-audiocontextstate-suspended)\".

 2. The context is [allowed to
 start](#allowed-to-start).

 3. [`[[suspended by user]]`](#dom-audiocontext-suspended-by-user-slot) flag is `false`.

 [NOTE:] This can allow
 [`start()`](#dom-audioscheduledsourcenode-start) to start an
 [`AudioContext`](#AudioContext) that is currently [allowed to
 start](#allowed-to-start), but has previously been prevented from
 starting.
 :::

 Arguments for the
 [AudioScheduledSourceNode.start(when)](#dom-audioscheduledsourcenode-start) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`when`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✔]

 The
 [`when`](#dom-audioscheduledsourcenode-start-when-when) parameter describes at what time (in seconds) the
 sound should start playing. It is in the same time coordinate system
 as the
 [`AudioContext`](#AudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime) attribute. When the signal emitted by the
 [`AudioScheduledSourceNode`](#AudioScheduledSourceNode) depends on the sound's start time, the exact value
 of `when` is always used without rounding to the nearest sample
 frame. If 0 is passed in for this value or if the value is less than
 [`currentTime`](#dom-baseaudiocontext-currenttime), then the sound will start playing immediately. [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if `when` is
 negative.]

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`stop(when)`]

: Schedules a sound to stop playback at an exact time. If `stop` is
 called again after already having been called, the last invocation
 will be the only one applied; stop times set by previous calls will
 not be applied, unless the buffer has already stopped prior to any
 subsequent calls. If the buffer has already stopped, further calls
 to `stop` will have no effect. If a stop time is reached prior to
 the scheduled start time, the sound will not play.

 :::
 [When this method is called, execute these steps:]
 1. [If this
 [`AudioScheduledSourceNode`](#AudioScheduledSourceNode) internal slot
 [`[[source started]]`](#dom-audioscheduledsourcenode-source-started-slot) is not `true`, an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception MUST be thrown.]

 2. Check for any errors that must be thrown due to parameter
 constraints described below.

 3. [Queue a control message](#queuing) to stop the
 [`AudioScheduledSourceNode`](#AudioScheduledSourceNode), including the parameter values in the message.
 :::

 :::
 If the node is an
 [`AudioBufferSourceNode`](#AudioBufferSourceNode), running a [control
 message](#control-message) to stop the
 [`AudioBufferSourceNode`](#AudioBufferSourceNode) means invoking the `handleStop()` function in the
 [playback algorithm](#playback-AudioBufferSourceNode).
 :::

 Arguments for the
 [AudioScheduledSourceNode.stop(when)](#dom-audioscheduledsourcenode-stop) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`when`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✔]

 The
 [`when`](#dom-audioscheduledsourcenode-stop-when-when) parameter describes at what time (in seconds) the
 source should stop playing. It is in the same time coordinate system
 as the
 [`AudioContext`](#AudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime) attribute. If 0 is passed in for this value or if
 the value is less than
 [`currentTime`](#dom-baseaudiocontext-currenttime), then the sound will stop playing immediately. [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if `when` is
 negative].

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

### 1.8. The [`AnalyserNode` Interface]
This interface represents a node which is able to provide real-time
frequency and time-domain analysis information. The audio stream will be
passed un-processed from input to output.

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

This output may be left unconnected.

[`channelCount`](#dom-audionode-channelcount)

2

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`max`\"

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

No

```
[Exposed=Window]
interface AnalyserNode : AudioNode {
 constructor (BaseAudioContext context, optional AnalyserOptions options = );
 undefined getFloatFrequencyData (Float32Array array);
 undefined getByteFrequencyData (Uint8Array array);
 undefined getFloatTimeDomainData (Float32Array array);
 undefined getByteTimeDomainData (Uint8Array array);
 attribute unsigned long fftSize;
 readonly attribute unsigned long frequencyBinCount;
 attribute double minDecibels;
 attribute double maxDecibels;
 attribute double smoothingTimeConstant;
};
```

#### 1.8.1. Constructors

[`AnalyserNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `c` and an option object
 `option`, the user agent MUST [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [AnalyserNode.constructor()](#dom-analysernode-analysernode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`AnalyserNode`](#AnalyserNode) will be
 [associated](#associated) with.

 [`options`]

 [`AnalyserOptions`](#AnalyserOptions)

 [✘]

 [✔]

 Optional initial parameter value for this
 [`AnalyserNode`](#AnalyserNode).

#### 1.8.2. Attributes

[`fftSize`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: The size of the FFT used for frequency-domain analysis (in
 sample-frames). [This MUST be a power of two in the range 32 to
 32768, otherwise an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown]. The
 default value is 2048. Note that large FFT sizes can be costly to
 compute.

 If the
 [`fftSize`](#dom-analysernode-fftsize) is changed to a different value, then all state
 associated with smoothing of the frequency data (for
 [`getByteFrequencyData()`](#dom-analysernode-getbytefrequencydata) and
 [`getFloatFrequencyData()`](#dom-analysernode-getfloatfrequencydata)) is reset. That is the [previous
 block](#previous-block),
 \\(\\hat{X}\_{-1}\[k\]\\), used for [smoothing over
 time](#smoothing-over-time) is set to
 0 for all \\(k\\).

 Note that increasing
 [`fftSize`](#dom-analysernode-fftsize) does mean that the [current time-domain
 data](#current-time-domain-data) must be expanded to include past frames that it
 previously did not. This means that the
 [`AnalyserNode`](#AnalyserNode) effectively MUST keep around the last 32768
 sample-frames and the [current time-domain
 data](#current-time-domain-data) is the most recent
 [`fftSize`](#dom-analysernode-fftsize) sample-frames out of that.

[`frequencyBinCount`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Half the FFT size.

[`maxDecibels`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: [`maxDecibels`](#dom-analysernode-maxdecibels) is the maximum power value in the scaling range for
 the FFT analysis data for conversion to unsigned byte values. The
 default value is -30. [If the value of this attribute is set to a
 value less than or equal to
 [`minDecibels`](#dom-analysernode-mindecibels), an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown.]

[`minDecibels`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: [`minDecibels`](#dom-analysernode-mindecibels) is the minimum power value in the scaling range for
 the FFT analysis data for conversion to unsigned byte values. The
 default value is -100. [If the value of this attribute is set to a
 value more than or equal to
 [`maxDecibels`](#dom-analysernode-maxdecibels), an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown.]

[`smoothingTimeConstant`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: A value from 0 -\> 1 where 0 represents no time averaging with the
 last analysis frame. The default value is 0.8. [If the value of this
 attribute is set to a value less than 0 or more than 1, an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown.]

#### 1.8.3. Methods

[`getByteFrequencyData(array)`]

: [Write](https://webidl.spec.whatwg.org/#arraybufferview-write) the [current frequency
 data](#current-frequency-data) into `array`. If `array`'s
 [byte
 length](https://webidl.spec.whatwg.org/#buffersource-byte-length) is less than
 [`frequencyBinCount`](#dom-analysernode-frequencybincount), the excess elements will be dropped. If
 `array`'s [byte
 length](https://webidl.spec.whatwg.org/#buffersource-byte-length) is greater than the
 [`frequencyBinCount`](#dom-analysernode-frequencybincount), the excess elements will be ignored. The most
 recent
 [`fftSize`](#dom-analysernode-fftsize) frames are used in computing the frequency data.

 If another call to
 [`getByteFrequencyData()`](#dom-analysernode-getbytefrequencydata) or
 [`getFloatFrequencyData()`](#dom-analysernode-getfloatfrequencydata) occurs within the same [render
 quantum](#render-quantum)
 as a previous call, the [current frequency
 data](#current-frequency-data) is not updated with the same data. Instead, the
 previously computed data is returned.

 The values stored in the unsigned byte array are computed in the
 following way. Let \\(Y\[k\]\\) be the [current frequency
 data](#current-frequency-data) as described in [FFT windowing and
 smoothing](#fft-windowing-and-smoothing-over-time). Then the byte
 value, \\(b\[k\]\\), is

 $$
 b[k] = \left\lfloor
 \frac{255}{\mbox{dB}_{max} - \mbox{dB}_{min}}
 \left(Y[k] - \mbox{dB}_{min}\right)
 \right\rfloor
 $$

 where \\(\\mbox{dB}\_{min}\\) is
 [`minDecibels`](#dom-analysernode-mindecibels) and \\(\\mbox{dB}\_{max}\\) is
 [`maxDecibels`](#dom-analysernode-maxdecibels). If \\(b\[k\]\\) lies outside the range of 0 to
 255, \\(b\[k\]\\) is clipped to lie in that range.

 Arguments for the
 [AnalyserNode.getByteFrequencyData()](#dom-analysernode-getbytefrequencydata) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`array`]

 [`Uint8Array`](https://webidl.spec.whatwg.org/#idl-Uint8Array)

 [✘]

 [✘]

 This parameter is where the frequency-domain analysis data will be
 copied.

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`getByteTimeDomainData(array)`]

: [Write](https://webidl.spec.whatwg.org/#arraybufferview-write) the [current time-domain
 data](#current-time-domain-data) (waveform data) into `array`. If
 `array`'s [byte
 length](https://webidl.spec.whatwg.org/#buffersource-byte-length) is less than
 [`fftSize`](#dom-analysernode-fftsize), the excess elements will be dropped. If
 `array`'s [byte
 length](https://webidl.spec.whatwg.org/#buffersource-byte-length) is greater than the
 [`fftSize`](#dom-analysernode-fftsize), the excess elements will be ignored. The most
 recent
 [`fftSize`](#dom-analysernode-fftsize) frames are used in computing the byte data.

 The values stored in the unsigned byte array are computed in the
 following way. Let \\(x\[k\]\\) be the time-domain data. Then the
 byte value, \\(b\[k\]\\), is

 $$
 b[k] = \left\lfloor 128(1 + x[k]) \right\rfloor.
 $$

 If \\(b\[k\]\\) lies outside the range 0 to 255, \\(b\[k\]\\) is
 clipped to lie in that range.

 Arguments for the
 [AnalyserNode.getByteTimeDomainData()](#dom-analysernode-getbytetimedomaindata) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`array`]

 [`Uint8Array`](https://webidl.spec.whatwg.org/#idl-Uint8Array)

 [✘]

 [✘]

 This parameter is where the time-domain sample data will be copied.

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`getFloatFrequencyData(array)`]

: [Write](https://webidl.spec.whatwg.org/#arraybufferview-write) the [current frequency
 data](#current-frequency-data) into `array`. If `array` has
 fewer elements than the
 [`frequencyBinCount`](#dom-analysernode-frequencybincount), the excess elements will be dropped. If
 `array` has more elements than the
 [`frequencyBinCount`](#dom-analysernode-frequencybincount), the excess elements will be ignored. The most
 recent
 [`fftSize`](#dom-analysernode-fftsize) frames are used in computing the frequency data.

 If another call to
 [`getFloatFrequencyData()`](#dom-analysernode-getfloatfrequencydata) or
 [`getByteFrequencyData()`](#dom-analysernode-getbytefrequencydata) occurs within the same [render
 quantum](#render-quantum)
 as a previous call, the [current frequency
 data](#current-frequency-data) is not updated with the same data. Instead, the
 previously computed data is returned.

 The frequency data are in dB units.

 Arguments for the
 [AnalyserNode.getFloatFrequencyData()](#dom-analysernode-getfloatfrequencydata) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`array`]

 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)

 [✘]

 [✘]

 This parameter is where the frequency-domain analysis data will be
 copied.

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`getFloatTimeDomainData(array)`]

: [Write](https://webidl.spec.whatwg.org/#arraybufferview-write) the [current time-domain
 data](#current-time-domain-data) (waveform data) into `array`. If
 `array` has fewer elements than the value of
 [`fftSize`](#dom-analysernode-fftsize), the excess elements will be dropped. If
 `array` has more elements than the value of
 [`fftSize`](#dom-analysernode-fftsize), the excess elements will be ignored. The most
 recent
 [`fftSize`](#dom-analysernode-fftsize) frames are written (after downmixing).

 Arguments for the
 [AnalyserNode.getFloatTimeDomainData()](#dom-analysernode-getfloattimedomaindata) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`array`]

 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)

 [✘]

 [✘]

 This parameter is where the time-domain sample data will be copied.

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

#### 1.8.4. [`AnalyserOptions`]
This specifies the options to be used when constructing an
[`AnalyserNode`](#AnalyserNode). All members are optional; if not specified, the normal
default values are used to construct the node.

```
dictionary AnalyserOptions : AudioNodeOptions {
 unsigned long fftSize = 2048;
 double maxDecibels = -30;
 double minDecibels = -100;
 double smoothingTimeConstant = 0.8;
};
```

##### 1.8.4.1. Dictionary [`AnalyserOptions` Members]
[`fftSize`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), defaulting to `2048`

: The desired initial size of the FFT for frequency-domain analysis.

[`maxDecibels`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `-30`

: The desired initial maximum power in dB for FFT analysis.

[`minDecibels`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `-100`

: The desired initial minimum power in dB for FFT analysis.

[`smoothingTimeConstant`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `0.8`

: The desired initial smoothing constant for the FFT analysis.

#### 1.8.5. Time-Domain Down-Mixing

When the [current time-domain data] are computed, the input signal
must be [down-mixed](#channel-up-mixing-and-down-mixing) to mono as if
[`channelCount`](#dom-audionode-channelcount) is 1,
[`channelCountMode`](#dom-audionode-channelcountmode) is
\"[`max`](#dom-channelcountmode-max)\" and
[`channelInterpretation`](#dom-audionode-channelinterpretation) is
\"[`speakers`](#dom-channelinterpretation-speakers)\". This is independent of the settings for the
[`AnalyserNode`](#AnalyserNode) itself. The most recent
[`fftSize`](#dom-analysernode-fftsize) frames are used for the down-mixing operation.

#### 1.8.6. FFT Windowing and Smoothing over Time

When the [current frequency data] are
computed, the following operations are to be performed:

1. Compute the [current time-domain
 data](#current-time-domain-data).

2. [Apply a Blackman
 window](#blackman-window) to the time
 domain input data.

3. [Apply a Fourier
 transform](#fourier-transform) to the
 windowed time domain input data to get real and imaginary frequency
 data.

4. [Smooth over
 time](#smoothing-over-time) the
 frequency domain data.

5. [Convert to dB](#conversion-to-db).

In the following, let \\(N\\) be the value of the
[`fftSize`](#dom-analysernode-fftsize) attribute of this
[`AnalyserNode`](#AnalyserNode).

[Applying a Blackman window] consists in the following operation on the
input time domain data. Let \\(x\[n\]\\) for \\(n = 0, \\ldots, N - 1\\)
be the time domain data. The Blackman window is defined by

 $$
 \begin{align*}
 \alpha &amp;= \mbox{0.16} \\ a_0 &amp;= \frac{1-\alpha}{2} \\
 a_1 &amp;= \frac{1}{2} \\
 a_2 &amp;= \frac{\alpha}{2} \\
 w[n] &amp;= a_0 - a_1 \cos\frac{2\pi n}{N} + a_2 \cos\frac{4\pi n}{N}, \mbox{ for } n = 0, \ldots, N - 1
 \end{align*}
 $$

The windowed signal \\(\\hat{x}\[n\]\\) is

 $$
 \hat{x}[n] = x[n] w[n], \mbox{ for } n = 0, \ldots, N - 1
 $$

[Applying a Fourier transform] consists of computing the Fourier transform
in the following way. Let \\(X\[k\]\\) be the complex frequency domain
data and \\(\\hat{x}\[n\]\\) be the windowed time domain data computed
above. Then

 $$
 X[k] = \frac{1}{N} \sum_{n = 0}^{N - 1} \hat{x}[n]\, W^{-kn}_{N}
 $$

for \\(k = 0, \\dots, N/2-1\\) where \\(W_N = e\^{2\\pi i/N}\\).

[Smoothing over time] frequency data consists in the following
operation:

- Let \\(\\hat{X}\_{-1}\[k\]\\) be the result of this operation on the
 [previous block](#previous-block). The [previous block] is defined as being the
 buffer computed by the previous [smoothing over
 time](#smoothing-over-time) operation,
 or an array of \\(N\\) zeros if this is the first time we are
 [smoothing over
 time](#smoothing-over-time).

- Let \\(\\tau\\) be the value of the
 [`smoothingTimeConstant`](#dom-analysernode-smoothingtimeconstant) attribute for this
 [`AnalyserNode`](#AnalyserNode).

- Let \\(X\[k\]\\) be the result of [applying a Fourier
 transform](#fourier-transform) of the
 current block.

Then the smoothed value, \\(\\hat{X}\[k\]\\), is computed by

 $$
 \hat{X}[k] = \tau\, \hat{X}_{-1}[k] + (1 - \tau)\, \left|X[k]\right|
 $$

- If \\(\\hat{X}\[k\]\\) is `NaN`, positive infinity or negative
 infinity, set \\(\\hat{X}\[k\]\\) = 0.

for \\(k = 0, \\ldots, N - 1\\).

[Conversion to dB] consists of the following operation, where
\\(\\hat{X}\[k\]\\) is computed in [smoothing over
time](#smoothing-over-time):

 $$
 Y[k] = 20\log_{10}\hat{X}[k]
 $$

for \\(k = 0, \\ldots, N-1\\).

This array, \\(Y\[k\]\\), is copied to the output array for
[`getFloatFrequencyData()`](#dom-analysernode-getfloatfrequencydata). For
[`getByteFrequencyData()`](#dom-analysernode-getbytefrequencydata), the \\(Y\[k\]\\) is clipped to lie between
[`minDecibels`](#dom-analysernode-mindecibels) and
[`maxDecibels`](#dom-analysernode-maxdecibels) and then scaled to fit in an unsigned byte such that
[`minDecibels`](#dom-analysernode-mindecibels) is represented by the value 0 and
[`maxDecibels`](#dom-analysernode-maxdecibels) is represented by the value 255.

### 1.9. The [`AudioBufferSourceNode` Interface]
This interface represents an audio source from an in-memory audio asset
in an [`AudioBuffer`](#AudioBuffer). It is useful for playing audio assets which require a
high degree of scheduling flexibility and accuracy. If sample-accurate
playback of network- or disk-backed assets is required, an implementer
should use
[`AudioWorkletNode`](#AudioWorkletNode) to implement playback.

The
[`start()`](#dom-audioscheduledsourcenode-start) method is used to schedule when sound playback will
happen. The
[`start()`](#dom-audioscheduledsourcenode-start) method may not be issued multiple times. The playback
will stop automatically when the buffer's audio data has been completely
played (if the
[`loop`](#dom-audiobuffersourcenode-loop) attribute is `false`), or when the
[`stop()`](#dom-audioscheduledsourcenode-stop) method has been called and the specified time has been
reached. Please see more details in the
[`start()`](#dom-audioscheduledsourcenode-start) and
[`stop()`](#dom-audioscheduledsourcenode-stop) descriptions.

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

0

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

2

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`max`\"

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

No

The number of channels of the output equals the number of channels of
the AudioBuffer assigned to the
[`buffer`](#dom-audiobuffersourcenode-buffer) attribute, or is one channel of silence if
[`buffer`](#dom-audiobuffersourcenode-buffer) is `null`.

In addition, if the buffer has more than one channel, then the
[`AudioBufferSourceNode`](#AudioBufferSourceNode) output must change to a single channel of silence at
the beginning of a render quantum after the time at which any one of the
following conditions holds:

- the end of the
 [`buffer`](#dom-audiobuffersourcenode-buffer) has been reached;

- the
 [`duration`](#dom-audiobuffersourcenode-start-when-offset-duration-duration) has been reached;

- the
 [`stop`](#dom-audioscheduledsourcenode-stop-when-when) time has been reached.

A [playhead position] for an
[`AudioBufferSourceNode`](#AudioBufferSourceNode) is defined as any quantity representing a time offset
in seconds, relative to the time coordinate of the first sample frame in
the buffer. Such values are to be considered independently from the
node's `playbackRate` and
[`detune`](#dom-audiobuffersourcenode-detune) parameters. In general, playhead positions may be
subsample-accurate and need not refer to exact sample frame positions.
They may assume valid values between 0 and the duration of the buffer.

The
[`playbackRate`](#dom-audiobuffersourcenode-playbackrate) and
[`detune`](#dom-audiobuffersourcenode-detune) attributes form a [compound
parameter](#compound-parameter). They are used together to determine a
[computedPlaybackRate] value:

 computedPlaybackRate(t) = playbackRate(t) * pow(2, detune(t) / 1200)

The [nominal range](#nominal-range) for this [compound
parameter](#compound-parameter) is \\((-\\infty, \\infty)\\).

[`AudioBufferSourceNode`](#AudioBufferSourceNode)s are created with an internal boolean slot
[`[[buffer set]]`], initially set to false.

```
[Exposed=Window]
interface AudioBufferSourceNode : AudioScheduledSourceNode {
 constructor (BaseAudioContext context,
 optional AudioBufferSourceOptions options = );
 attribute AudioBuffer? buffer;
 readonly attribute AudioParam playbackRate;
 readonly attribute AudioParam detune;
 attribute boolean loop;
 attribute double loopStart;
 attribute double loopEnd;
 undefined start (optional double when = 0,
 optional double offset,
 optional double duration);
};
```

#### 1.9.1. Constructors

[`AudioBufferSourceNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `c` and an option object
 `option`, the user agent MUST [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [AudioBufferSourceNode.constructor()](#dom-audiobuffersourcenode-audiobuffersourcenode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`AudioBufferSourceNode`](#AudioBufferSourceNode) will be
 [associated](#associated) with.

 [`options`]

 [`AudioBufferSourceOptions`](#AudioBufferSourceOptions)

 [✘]

 [✔]

 Optional initial parameter value for this
 [`AudioBufferSourceNode`](#AudioBufferSourceNode).

#### 1.9.2. Attributes

[`buffer`], of type [AudioBuffer](#AudioBuffer), nullable

: Represents the audio asset to be played.

 :::
 To set the
 [`buffer`](#dom-audiobuffersourcenode-buffer) attribute, execute these steps:
 1. Let `new buffer` be the
 [`AudioBuffer`](#AudioBuffer) or `null` value to be assigned to
 [`buffer`](#dom-audiobuffersourcenode-buffer).

 2. If `new buffer` is not `null` and
 [`[[buffer set]]`](#dom-audiobuffersourcenode-buffer-set-slot) is true, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) and abort these steps.

 3. If `new buffer` is not `null`, set
 [`[[buffer set]]`](#dom-audiobuffersourcenode-buffer-set-slot) to true.

 4. Assign `new buffer` to the
 [`buffer`](#dom-audiobuffersourcenode-buffer) attribute.

 5. If `start()` has previously been called on this node, perform
 the operation [acquire the
 content](#acquire-the-content) on
 [`buffer`](#dom-audiobuffersourcenode-buffer).
 :::

[`detune`], of type [AudioParam](#AudioParam), readonly

: An additional parameter, in cents, to modulate the speed at which is
 rendered the audio stream. This parameter is a [compound
 parameter](#compound-parameter) with
 [`playbackRate`](#dom-audiobuffersourcenode-playbackrate) to form a
 [computedPlaybackRate](#computedplaybackrate).

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`k-rate`](#dom-automationrate-k-rate)\"
 Has [automation rate
 constraints](#audioparam-automation-rate-constraints)
 :::

[`loop`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean)

: Indicates if the region of audio data designated by
 [`loopStart`](#dom-audiobuffersourcenode-loopstart) and
 [`loopEnd`](#dom-audiobuffersourcenode-loopend) should be played continuously in a loop. The
 default value is `false`.

[`loopEnd`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: An optional [playhead
 position](#playhead-position) where looping should end if the
 [`loop`](#dom-audiobuffersourcenode-loop) attribute is true. Its value is exclusive of the
 content of the loop. Its default `value` is 0, and it may usefully
 be set to any value between 0 and the duration of the buffer. If
 [`loopEnd`](#dom-audiobuffersourcenode-loopend) is less than or equal to 0, or if
 [`loopEnd`](#dom-audiobuffersourcenode-loopend) is greater than the duration of the buffer, looping
 will end at the end of the buffer.

[`loopStart`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: An optional [playhead
 position](#playhead-position) where looping should begin if the
 [`loop`](#dom-audiobuffersourcenode-loop) attribute is true. Its default `value` is 0, and it
 may usefully be set to any value between 0 and the duration of the
 buffer. If
 [`loopStart`](#dom-audiobuffersourcenode-loopstart) is less than 0, looping will begin at 0. If
 [`loopStart`](#dom-audiobuffersourcenode-loopstart) is greater than the duration of the buffer, looping
 will begin at the end of the buffer.

[`playbackRate`], of type [AudioParam](#AudioParam), readonly

: The speed at which to render the audio stream. This is a [compound
 parameter](#compound-parameter) with
 [`detune`](#dom-audiobuffersourcenode-detune) to form a
 [computedPlaybackRate](#computedplaybackrate).

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 1
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`k-rate`](#dom-automationrate-k-rate)\"
 Has [automation rate
 constraints](#audioparam-automation-rate-constraints)
 :::

#### 1.9.3. Methods

[`start(when, offset, duration)`]

: Schedules a sound to playback at an exact time.

 :::
 [When this method is called, execute these steps:]
 1. [If this
 [`AudioBufferSourceNode`](#AudioBufferSourceNode) internal slot
 [`[[source started]]`](#dom-audioscheduledsourcenode-source-started-slot) is `true`, an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception MUST be thrown.]

 2. Check for any errors that must be thrown due to parameter
 constraints described below. If any exception is thrown during
 this step, abort those steps.

 3. Set the internal slot
 [`[[source started]]`](#dom-audioscheduledsourcenode-source-started-slot) on this
 [`AudioBufferSourceNode`](#AudioBufferSourceNode) to `true`.

 4. [Queue a control message](#queuing) to start the
 [`AudioBufferSourceNode`](#AudioBufferSourceNode), including the parameter values in the message.

 5. [Acquire the
 contents](#acquire-the-content) of the
 [`buffer`](#dom-audiobuffersourcenode-buffer) if the
 [`buffer`](#dom-audiobuffersourcenode-buffer) has been set.

 6. Send a [control
 message](#control-message) to the associated
 [`AudioContext`](#AudioContext) to [start running its rendering
 thread](#context-resume) only when all the following conditions
 are met:

 1. The context's
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) is
 [`suspended`](#dom-audiocontextstate-suspended).

 2. The context is [allowed to
 start](#allowed-to-start).

 3. [`[[suspended by user]]`](#dom-audiocontext-suspended-by-user-slot) flag is `false`.

 [NOTE:] This can allow
 [`start()`](#dom-audiobuffersourcenode-start) to start an
 [`AudioContext`](#AudioContext) that is currently [allowed to
 start](#allowed-to-start), but has previously been prevented from
 starting.
 :::

 :::
 Running a [control
 message](#control-message) to start the
 [`AudioBufferSourceNode`](#AudioBufferSourceNode) means invoking the `handleStart()` function in the
 [playback algorithm](#playback-AudioBufferSourceNode) which follows.
 :::

 Arguments for the [AudioBufferSourceNode.start(when, offset,
 duration)](#dom-audiobuffersourcenode-start) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`when`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✔]

 The `when` parameter describes at what time (in seconds) the sound
 should start playing. It is in the same time coordinate system as
 the [`AudioContext`](#AudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime) attribute. If 0 is passed in for this value or if
 the value is less than **currentTime**, then the sound will start
 playing immediately. [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if `when` is
 negative.]

 [`offset`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✔]

 The `offset` parameter supplies a [playhead
 position](#playhead-position) where playback will begin. If 0 is passed in for
 this value, then playback will start from the beginning of the
 buffer. [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if `offset` is
 negative.] If `offset` is greater than
 [`loopEnd`](#dom-audiobuffersourcenode-loopend),
 [`playbackRate`](#dom-audiobuffersourcenode-playbackrate) is positive or zero, and
 [`loop`](#dom-audiobuffersourcenode-loop) is `true`, playback will begin at
 [`loopEnd`](#dom-audiobuffersourcenode-loopend). If `offset` is greater than
 [`loopStart`](#dom-audiobuffersourcenode-loopstart),
 [`playbackRate`](#dom-audiobuffersourcenode-playbackrate) is negative, and
 [`loop`](#dom-audiobuffersourcenode-loop) is `true`, playback will begin at
 [`loopStart`](#dom-audiobuffersourcenode-loopstart). `offset` is silently clamped to \[0, `duration`\],
 when `startTime` is reached, where `duration` is the value of the
 `duration` attribute of the
 [`AudioBuffer`](#AudioBuffer) set to the
 [`buffer`](#dom-audiobuffersourcenode-buffer) attribute of this `AudioBufferSourceNode`.

 [`duration`]

 [`double`](https://webidl.spec.whatwg.org/#idl-double)

 [✘]

 [✔]

 The
 [`duration`](#dom-audiobuffersourcenode-start-when-offset-duration-duration) parameter describes the duration of sound to be
 played, expressed as seconds of total buffer content to be output,
 including any whole or partial loop iterations. The units of
 [`duration`](#dom-audiobuffersourcenode-start-when-offset-duration-duration) are independent of the effects of
 [`playbackRate`](#dom-audiobuffersourcenode-playbackrate). For example, a
 [`duration`](#dom-audiobuffersourcenode-start-when-offset-duration-duration) of 5 seconds with a playback rate of 0.5 will
 output 5 seconds of buffer content at half speed, producing 10
 seconds of audible output. [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if `duration` is
 negative.]

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

#### 1.9.4. [`AudioBufferSourceOptions`]
This specifies options for constructing a
[`AudioBufferSourceNode`](#AudioBufferSourceNode). All members are optional; if not specified, the normal
default is used in constructing the node.

```
dictionary AudioBufferSourceOptions {
 AudioBuffer? buffer;
 float detune = 0;
 boolean loop = false;
 double loopEnd = 0;
 double loopStart = 0;
 float playbackRate = 1;
};
```

##### 1.9.4.1. Dictionary [`AudioBufferSourceOptions` Members]
[`buffer`], of type [AudioBuffer](#AudioBuffer), nullable

: The audio asset to be played. This is equivalent to assigning
 [`buffer`](#dom-audiobuffersourceoptions-buffer) to the
 [`buffer`](#dom-audiobuffersourcenode-buffer) attribute of the
 [`AudioBufferSourceNode`](#AudioBufferSourceNode).

[`detune`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0`

: The initial value for the
 [`detune`](#dom-audiobuffersourcenode-detune) AudioParam.

[`loop`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: The initial value for the
 [`loop`](#dom-audiobuffersourcenode-loop) attribute.

[`loopEnd`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `0`

: The initial value for the
 [`loopEnd`](#dom-audiobuffersourcenode-loopend) attribute.

[`loopStart`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `0`

: The initial value for the
 [`loopStart`](#dom-audiobuffersourcenode-loopstart) attribute.

[`playbackRate`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `1`

: The initial value for the
 [`playbackRate`](#dom-audiobuffersourcenode-playbackrate) AudioParam.

#### 1.9.5. Looping

*This section is non-normative. Please see [the playback
algorithm](#playback-AudioBufferSourceNode) for normative requirements.*

Setting the
[`loop`](#dom-audiobuffersourcenode-loop) attribute to true causes playback of the region of the
buffer defined by the endpoints
[`loopStart`](#dom-audiobuffersourcenode-loopstart) and
[`loopEnd`](#dom-audiobuffersourcenode-loopend) to continue indefinitely, once any part of the looped
region has been played. While
[`loop`](#dom-audiobuffersourcenode-loop) remains true, looped playback will continue until one
of the following occurs:

- [`stop()`](#dom-audioscheduledsourcenode-stop) is called,

- the scheduled stop time has been reached,

- the `duration` has been exceeded, if
 [`start()`](#dom-audiobuffersourcenode-start) was called with a `duration` value.

The body of the loop is considered to occupy a region from
[`loopStart`](#dom-audiobuffersourcenode-loopstart) up to, but not including,
[`loopEnd`](#dom-audiobuffersourcenode-loopend). The direction of playback of the looped region
respects the sign of the node's playback rate. For positive playback
rates, looping occurs from
[`loopStart`](#dom-audiobuffersourcenode-loopstart) to
[`loopEnd`](#dom-audiobuffersourcenode-loopend); for negative rates, looping occurs from
[`loopEnd`](#dom-audiobuffersourcenode-loopend) to
[`loopStart`](#dom-audiobuffersourcenode-loopstart).

Looping does not affect the interpretation of the `offset` argument of
[`start()`](#dom-audiobuffersourcenode-start). Playback always starts at the requested offset, and
looping only begins once the body of the loop is encountered during
playback.

The effective loop start and end points are required to lie within the
range of zero and the buffer duration, as specified in the algorithm
below.
[`loopEnd`](#dom-audiobuffersourcenode-loopend) is further constrained to be at or after
[`loopStart`](#dom-audiobuffersourcenode-loopstart). If any of these constraints are violated, the loop is
considered to include the entire buffer contents.

Loop endpoints have subsample accuracy. When endpoints do not fall on
exact sample frame offsets, or when the playback rate is not equal to 1,
playback of the loop is interpolated to splice the beginning and end of
the loop together just as if the looped audio occurred in sequential,
non-looped regions of the buffer.

Loop-related properties may be varied during playback of the buffer, and
in general take effect on the next rendering quantum. The exact results
are defined by the normative playback algorithm which follows.

The default values of the
[`loopStart`](#dom-audiobuffersourcenode-loopstart) and
[`loopEnd`](#dom-audiobuffersourcenode-loopend) attributes are both 0. Since a
[`loopEnd`](#dom-audiobuffersourcenode-loopend) value of zero is equivalent to the length of the
buffer, the default endpoints cause the entire buffer to be included in
the loop.

Note that the values of the loop endpoints are expressed as time offsets
in terms of the sample rate of the buffer, meaning that these values are
independent of the node's
[`playbackRate`](#dom-audiobuffersourcenode-playbackrate) parameter which can vary dynamically during the course
of playback.

#### 1.9.6. Playback of AudioBuffer Contents

This normative section specifies the playback of the contents of the
buffer, accounting for the fact that playback is influenced by the
following factors working in combination:

- A starting offset, which can be expressed with sub-sample precision.

- Loop points, which can be expressed with sub-sample precision and can
 vary dynamically during playback.

- Playback rate and detuning parameters, which combine to yield a single
 [computedPlaybackRate](#computedplaybackrate) that can assume finite values which may be positive
 or negative.

The algorithm to be followed internally to generate output from an
[`AudioBufferSourceNode`](#AudioBufferSourceNode) conforms to the following principles:

- Resampling of the buffer may be performed arbitrarily by the UA at any
 desired point to increase the efficiency or quality of the output.

- Sub-sample start offsets or loop points may require additional
 interpolation between sample frames.

- The playback of a looped buffer should behave identically to an
 unlooped buffer containing consecutive occurrences of the looped audio
 content, excluding any effects from interpolation.

The description of the algorithm is as follows:

```
let buffer; // AudioBuffer employed by this nodelet context; // AudioContext employed by this node// The following variables capture attribute and AudioParam values for the node.// They are updated on a k-rate basis, prior to each invocation of process().let loop;let detune;let loopStart;let loopEnd;let playbackRate;// Variables for the node's playback parameterslet start = 0, offset = 0, duration = Infinity; // Set by start()let stop = Infinity; // Set by stop()// Variables for tracking node's playback statelet bufferTime = 0, started = false, enteredLoop = false;let bufferTimeElapsed = 0;let dt = 1 / context.sampleRate;// Handle invocation of start method callfunction handleStart(when, pos, dur) { if (arguments.length >= 1) { start = when; } offset = pos; if (arguments.length >= 3) { duration = dur; }}// Handle invocation of stop method callfunction handleStop(when) { if (arguments.length >= 1) { stop = when; } else { stop = context.currentTime; }}// Interpolate a multi-channel signal value for some sample frame.// Returns an array of signal values.function playbackSignal(position) { /* This function provides the playback signal function for buffer, which is a function that maps from a playhead position to a set of output signal values, one for each output channel. If |position| corresponds to the location of an exact sample frame in the buffer, this function returns that frame. Otherwise, its return value is determined by a UA-supplied algorithm that interpolates sample frames in the neighborhood of |position|. If |position| is greater than or equal to |loopEnd| and there is no subsequent sample frame in buffer, then interpolation should be based on the sequence of subsequent frames beginning at |loopStart|. */ ...}// Generate a single render quantum of audio to be placed// in the channel arrays defined by output. Returns an array// of |numberOfFrames| sample frames to be output.function process(numberOfFrames) { let currentTime = context.currentTime; // context time of next rendered frame const output = ; // accumulates rendered sample frames // Combine the two k-rate parameters affecting playback rate const computedPlaybackRate = playbackRate * Math.pow(2, detune / 1200); // Determine loop endpoints as applicable let actualLoopStart, actualLoopEnd; if (loop && buffer != null) { if (loopStart >= 0 && loopEnd > 0 && loopStart < loopEnd) { actualLoopStart = loopStart; actualLoopEnd = Math.min(loopEnd, buffer.duration); } else { actualLoopStart = 0; actualLoopEnd = buffer.duration; } } else { // If the loop flag is false, remove any record of the loop having been entered enteredLoop = false; } // Handle null buffer case if (buffer == null) { stop = currentTime; // force zero output for all time } // Render each sample frame in the quantum for (let index = 0; index < numberOfFrames; index++) { // Check that currentTime and bufferTimeElapsed are // within allowable range for playback if (currentTime < start || currentTime >= stop || bufferTimeElapsed >= duration) { output.push(0); // this sample frame is silent currentTime += dt; continue; } if (!started) { // Take note that buffer has started playing and get initial // playhead position. if (loop && computedPlaybackRate >= 0 && offset >= actualLoopEnd) { offset = actualLoopEnd; } if (computedPlaybackRate < 0 && loop && offset < actualLoopStart) { offset = actualLoopStart; } bufferTime = offset; started = true; } // Handle loop-related calculations if (loop) { // Determine if looped portion has been entered for the first time if (!enteredLoop) { if (offset < actualLoopEnd && bufferTime >= actualLoopStart) { // playback began before or within loop, and playhead is // now past loop start enteredLoop = true; } if (offset >= actualLoopEnd && bufferTime < actualLoopEnd) { // playback began after loop, and playhead is now prior // to the loop end enteredLoop = true; } } // Wrap loop iterations as needed. Note that enteredLoop // may become true inside the preceding conditional. if (enteredLoop) { while (bufferTime >= actualLoopEnd) { bufferTime -= actualLoopEnd - actualLoopStart; } while (bufferTime < actualLoopStart) { bufferTime += actualLoopEnd - actualLoopStart; } } } if (bufferTime >= 0 && bufferTime < buffer.duration) { output.push(playbackSignal(bufferTime)); } else { output.push(0); // past end of buffer, so output silent frame } bufferTime += dt * computedPlaybackRate; bufferTimeElapsed += dt * computedPlaybackRate; currentTime += dt; } // End of render quantum loop if (currentTime >= stop) { // End playback state of this node. No further invocations of process() // will occur. Schedule a change to set the number of output channels to 1. } return output;}
```

The following non-normative figures illustrate the behavior of the
algorithm in assorted key scenarios. Dynamic resampling of the buffer is
not considered, but as long as the times of loop positions are not
changed this does not materially affect the resulting playback. In all
figures, the following conventions apply:

- context sample rate is 1000 Hz

- [`AudioBuffer`](#AudioBuffer) content is shown with the first sample frame at the
 *x* origin.

- output signals are shown with the sample frame located at time `start`
 at the *x* origin.

- linear interpolation is depicted throughout, although a UA could
 employ other interpolation techniques.

- the `duration` values noted in the figures refer to the `buffer`, not
 arguments to
 [`start()`](#dom-audiobuffersourcenode-start)

This figure illustrates basic playback of a buffer, with a simple loop
that ends after the last sample frame in the buffer:

![[`AudioBufferSourceNode`](#AudioBufferSourceNode) basic playback](images/absn-basic.png){height="485"
width="556"}

This figure illustrates `playbackRate` interpolation, showing half-speed
playback of buffer contents in which every other output sample frame is
interpolated. Of particular note is the last sample frame in the looped
output, which is interpolated using the loop start point:

![[`AudioBufferSourceNode`](#AudioBufferSourceNode) playbackRate
interpolation](images/absn-slow-loop.png){height="472" width="543"}

This figure illustrates sample rate interpolation, showing playback of a
buffer whose sample rate is 50% of the context sample rate, resulting in
a computed playback rate of 0.5 that corrects for the difference in
sample rate between the buffer and the context. The resulting output is
the same as the preceding example, but for different reasons.

![[`AudioBufferSourceNode`](#AudioBufferSourceNode) sample rate
interpolation.](images/absn-half-sample-rate.png){a
height="459" width="543"}

This figure illustrates subsample offset playback, in which the offset
within the buffer begins at exactly half a sample frame. Consequently,
every output frame is interpolated:

![[`AudioBufferSourceNode`](#AudioBufferSourceNode) subsample offset
playback](images/absn-offset.png){height="448" width="543"}

This figure illustrates subsample loop playback, showing how fractional
frame offsets in the loop endpoints map to interpolated data points in
the buffer that respect these offsets as if they were references to
exact sample frames:

![[`AudioBufferSourceNode`](#AudioBufferSourceNode) subsample loop
playback](images/absn-subsample-loop.png){height="480" width="543"}

### 1.10. The [`AudioDestinationNode` Interface]
This is an [`AudioNode`](#AudioNode) representing the final audio destination and is what
the user will ultimately hear. It can often be considered as an audio
output device which is connected to speakers. All rendered audio to be
heard will be routed to this node, a \"terminal\" node in the
[`AudioContext`](#AudioContext)'s routing graph. There is only a single
AudioDestinationNode per
[`AudioContext`](#AudioContext), provided through the `destination` attribute of
[`AudioContext`](#AudioContext).

The output of a
[`AudioDestinationNode`](#AudioDestinationNode) is produced by [summing its
input](#channel-up-mixing-and-down-mixing), allowing to capture the
output of an
[`AudioContext`](#AudioContext) into, for example, a
[`MediaStreamAudioDestinationNode`](#MediaStreamAudioDestinationNode), or a `MediaRecorder` (described in
[\[mediastream-recording\]](#biblio-mediastream-recording "MediaStream Recording")).

The
[`AudioDestinationNode`](#AudioDestinationNode) can be either the destination of an
[`AudioContext`](#AudioContext) or
[`OfflineAudioContext`](#OfflineAudioContext), and the channel properties depend on what the context
is.

For an [`AudioContext`](#AudioContext), the defaults are

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

2

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`explicit`\"

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

No

[`channelCount`](#dom-audionode-channelcount) can be set to any value less than or equal to
[`maxChannelCount`](#dom-audiodestinationnode-maxchannelcount). [An
[`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception MUST be thrown if this value is not within
the valid range.] Giving a concrete example, if the audio
hardware supports 8-channel output, then we may set
[`channelCount`](#dom-audionode-channelcount) to 8, and render 8 channels of output.

For an
[`OfflineAudioContext`](#OfflineAudioContext), the defaults are

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

numberOfChannels

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`explicit`\"

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

No

where `numberOfChannels` is the number of channels specified when
constructing the
[`OfflineAudioContext`](#OfflineAudioContext). This value may not be changed; [a
[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) exception MUST be thrown if
[`channelCount`](#dom-audionode-channelcount) is changed to a different value].

```
[Exposed=Window]
interface AudioDestinationNode : AudioNode {
 readonly attribute unsigned long maxChannelCount;
};
```

#### 1.10.1. Attributes

[`maxChannelCount`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: The maximum number of channels that the
 [`channelCount`](#dom-audionode-channelcount) attribute can be set to. An
 [`AudioDestinationNode`](#AudioDestinationNode) representing the audio hardware end-point (the
 normal case) can potentially output more than 2 channels of audio if
 the audio hardware is multi-channel.
 [`maxChannelCount`](#dom-audiodestinationnode-maxchannelcount) is the maximum number of channels that this
 hardware is capable of supporting.

### 1.11. The [`AudioListener` Interface]
This interface represents the position and orientation of the person
listening to the audio scene. All
[`PannerNode`](#PannerNode)
objects spatialize in relation to the
[`BaseAudioContext`](#BaseAudioContext)'s
[`listener`](#dom-baseaudiocontext-listener). See [§ 6 Spatialization/Panning](#Spatialization) for
more details about spatialization.

The
[`positionX`](#dom-audiolistener-positionx),
[`positionY`](#dom-audiolistener-positiony), and
[`positionZ`](#dom-audiolistener-positionz) parameters represent the location of the listener in 3D
Cartesian coordinate space.
[`PannerNode`](#PannerNode)
objects use this position relative to individual audio sources for
spatialization.

The
[`forwardX`](#dom-audiolistener-forwardx),
[`forwardY`](#dom-audiolistener-forwardy), and
[`forwardZ`](#dom-audiolistener-forwardz) parameters represent a direction vector in 3D space.
Both a `forward` vector and an `up` vector are used to determine the
orientation of the listener. In simple human terms, the `forward` vector
represents which direction the person's nose is pointing. The `up`
vector represents the direction the top of a person's head is pointing.
These two vectors are expected to be linearly independent. For normative
requirements of how these values are to be interpreted, see the [§ 6
Spatialization/Panning](#Spatialization) section.

```
[Exposed=Window]
interface AudioListener {
 readonly attribute AudioParam positionX;
 readonly attribute AudioParam positionY;
 readonly attribute AudioParam positionZ;
 readonly attribute AudioParam forwardX;
 readonly attribute AudioParam forwardY;
 readonly attribute AudioParam forwardZ;
 readonly attribute AudioParam upX;
 readonly attribute AudioParam upY;
 readonly attribute AudioParam upZ;
 undefined setPosition (float x, float y, float z);
 undefined setOrientation (float x, float y, float z, float xUp, float yUp, float zUp);
};
```

#### 1.11.1. Attributes

[`forwardX`], of type [AudioParam](#AudioParam), readonly

: Sets the x coordinate component of the forward direction the
 listener is pointing in 3D Cartesian coordinate space.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

[`forwardY`], of type [AudioParam](#AudioParam), readonly

: Sets the y coordinate component of the forward direction the
 listener is pointing in 3D Cartesian coordinate space.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

[`forwardZ`], of type [AudioParam](#AudioParam), readonly

: Sets the z coordinate component of the forward direction the
 listener is pointing in 3D Cartesian coordinate space.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 -1
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

[`positionX`], of type [AudioParam](#AudioParam), readonly

: Sets the x coordinate position of the audio listener in a 3D
 Cartesian coordinate space.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

[`positionY`], of type [AudioParam](#AudioParam), readonly

: Sets the y coordinate position of the audio listener in a 3D
 Cartesian coordinate space.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

[`positionZ`], of type [AudioParam](#AudioParam), readonly

: Sets the z coordinate position of the audio listener in a 3D
 Cartesian coordinate space.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

[`upX`], of type [AudioParam](#AudioParam), readonly

: Sets the x coordinate component of the up direction the listener is
 pointing in 3D Cartesian coordinate space.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

[`upY`], of type [AudioParam](#AudioParam), readonly

: Sets the y coordinate component of the up direction the listener is
 pointing in 3D Cartesian coordinate space.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 1
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

[`upZ`], of type [AudioParam](#AudioParam), readonly

: Sets the z coordinate component of the up direction the listener is
 pointing in 3D Cartesian coordinate space.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

#### 1.11.2. Methods

[`setOrientation(x, y, z, xUp, yUp, zUp)`]

: This method is DEPRECATED. It is equivalent to setting
 [`forwardX`](#dom-audiolistener-forwardx).[`value`](#dom-audioparam-value),
 [`forwardY`](#dom-audiolistener-forwardy).[`value`](#dom-audioparam-value),
 [`forwardZ`](#dom-audiolistener-forwardz).[`value`](#dom-audioparam-value),
 [`upX`](#dom-audiolistener-upx).[`value`](#dom-audioparam-value),
 [`upY`](#dom-audiolistener-upy).[`value`](#dom-audioparam-value), and
 [`upZ`](#dom-audiolistener-upz).[`value`](#dom-audioparam-value) directly with the given `x`, `y`, `z`, `xUp`,
 `yUp`, and `zUp` values, respectively.

 [Consequently, if any of the
 [`forwardX`](#dom-audiolistener-forwardx),
 [`forwardY`](#dom-audiolistener-forwardy),
 [`forwardZ`](#dom-audiolistener-forwardz),
 [`upX`](#dom-audiolistener-upx),
 [`upY`](#dom-audiolistener-upy) and
 [`upZ`](#dom-audiolistener-upz)
 [`AudioParam`](#AudioParam)s have an automation curve set using
 [`setValueCurveAtTime()`](#dom-audioparam-setvaluecurveattime) at the time this method is called, a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) MUST be thrown.]

 [`setOrientation()`](#dom-audiolistener-setorientation) describes which direction the listener is pointing
 in the 3D cartesian coordinate space. Both a
 [forward](#audiolistener-forward) vector and an
 [up](#audiolistener-up)
 vector are provided. In simple human terms, the
 [forward] vector
 represents which direction the person's nose is pointing. The
 [up] vector represents the direction the top
 of a person's head is pointing. These two vectors are expected to be
 linearly independent. For normative requirements of how these values
 are to be interpreted, see the [§ 6
 Spatialization/Panning](#Spatialization).

 The
 [`x`](#dom-audiolistener-setorientation-x),
 [`y`](#dom-audiolistener-setorientation-y), and
 [`z`](#dom-audiolistener-setorientation-z) parameters represent a
 [forward](#audiolistener-forward) direction vector in 3D space, with the default
 value being (0,0,-1).

 The
 [`xUp`](#dom-audiolistener-setorientation-xup),
 [`yUp`](#dom-audiolistener-setorientation-yup), and
 [`zUp`](#dom-audiolistener-setorientation-zup) parameters represent an
 [up](#audiolistener-up)
 direction vector in 3D space, with the default value being (0,1,0).

 Arguments for the
 [AudioListener.setOrientation()](#dom-audiolistener-setorientation) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`x`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 forward *x* direction fo the
 [`AudioListener`](#AudioListener)

 [`y`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 forward *y* direction fo the
 [`AudioListener`](#AudioListener)

 [`z`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 forward *z* direction fo the
 [`AudioListener`](#AudioListener)

 [`xUp`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 up *x* direction fo the
 [`AudioListener`](#AudioListener)

 [`yUp`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 up *y* direction fo the
 [`AudioListener`](#AudioListener)

 [`zUp`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 up *z* direction fo the
 [`AudioListener`](#AudioListener)

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`setPosition(x, y, z)`]

: This method is DEPRECATED. It is equivalent to setting
 [`positionX`](#dom-audiolistener-positionx).[`value`](#dom-audioparam-value),
 [`positionY`](#dom-audiolistener-positiony).[`value`](#dom-audioparam-value), and
 [`positionZ`](#dom-audiolistener-positionz).[`value`](#dom-audioparam-value) directly with the given `x`, `y`, and `z` values,
 respectively.

 [Consequently, any of the
 [`positionX`](#dom-audiolistener-positionx),
 [`positionY`](#dom-audiolistener-positiony), and
 [`positionZ`](#dom-audiolistener-positionz)
 [`AudioParam`](#AudioParam)s for this
 [`AudioListener`](#AudioListener) have an automation curve set using
 [`setValueCurveAtTime()`](#dom-audioparam-setvaluecurveattime) at the time this method is called, a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) MUST be thrown.]

 [`setPosition()`](#dom-audiolistener-setposition) sets the position of the listener in a 3D cartesian
 coordinate space.
 [`PannerNode`](#PannerNode) objects use this position relative to individual
 audio sources for spatialization.

 The
 [`x`](#dom-audiolistener-setposition-x),
 [`y`](#dom-audiolistener-setposition-y), and
 [`z`](#dom-audiolistener-setposition-z) parameters represent the coordinates
 in 3D space.

 The default value is (0,0,0).

 Arguments for the
 [AudioListener.setPosition()](#dom-audiolistener-setposition) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`x`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 *x*-coordinate of the position of the
 [`AudioListener`](#AudioListener)

 [`y`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 *y*-coordinate of the position of the
 [`AudioListener`](#AudioListener)

 [`z`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 *z*-coordinate of the position of the
 [`AudioListener`](#AudioListener)

#### 1.11.3. Processing

Because [`AudioListener`](#AudioListener)'s parameters can be connected with
[`AudioNode`](#AudioNode)s
and they can also affect the output of
[`PannerNode`](#PannerNode)s in the same graph, the node ordering algorithm should
take the
[`AudioListener`](#AudioListener) into consideration when computing the order of
processing. For this reason, all the
[`PannerNode`](#PannerNode)s in the graph have the
[`AudioListener`](#AudioListener) as input.

### 1.12. The [`AudioProcessingEvent` Interface - DEPRECATED]
This is an
[`Event`](https://dom.spec.whatwg.org/#event) object which is dispatched to
[`ScriptProcessorNode`](#ScriptProcessorNode) nodes. It will be removed when the ScriptProcessorNode
is removed, as the replacement
[`AudioWorkletNode`](#AudioWorkletNode) uses a different approach.

The event handler processes audio from the input (if any) by accessing
the audio data from the `inputBuffer` attribute. The audio data which is
the result of the processing (or the synthesized data if there are no
inputs) is then placed into the
[`outputBuffer`](#dom-audioprocessingevent-outputbuffer).

```
[Exposed=Window]
interface AudioProcessingEvent : Event {
 constructor (DOMString type, AudioProcessingEventInit eventInitDict);
 readonly attribute double playbackTime;
 readonly attribute AudioBuffer inputBuffer;
 readonly attribute AudioBuffer outputBuffer;
};
```

#### 1.12.1. Attributes

[`inputBuffer`], of type [AudioBuffer](#AudioBuffer), readonly

: An AudioBuffer containing the input audio data. It will have a
 number of channels equal to the `numberOfInputChannels` parameter of
 the createScriptProcessor() method. This AudioBuffer is only valid
 while in the scope of the
 [`audioprocess`](#eventdef-scriptprocessornode-audioprocess) event handler functions. Its values will be
 meaningless outside of this scope.

[`outputBuffer`], of type [AudioBuffer](#AudioBuffer), readonly

: An AudioBuffer where the output audio data MUST be written. It will
 have a number of channels equal to the `numberOfOutputChannels`
 parameter of the createScriptProcessor() method. Script code within
 the scope of the
 [`audioprocess`](#eventdef-scriptprocessornode-audioprocess) event handler functions are expected to modify the
 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array) arrays representing channel data in this
 AudioBuffer. Any script modifications to this AudioBuffer outside of
 this scope will not produce any audible effects.

[`playbackTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly

: The time when the audio will be played in the same time coordinate
 system as the
 [`AudioContext`](#AudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime).

#### 1.12.2. [`AudioProcessingEventInit`]
```
dictionary AudioProcessingEventInit : EventInit {
 required double playbackTime;
 required AudioBuffer inputBuffer;
 required AudioBuffer outputBuffer;
};
```

##### 1.12.2.1. Dictionary [`AudioProcessingEventInit` Members]
[`inputBuffer`], of type [AudioBuffer](#AudioBuffer)

: Value to be assigned to the
 [`inputBuffer`](#dom-audioprocessingevent-inputbuffer) attribute of the event.

[`outputBuffer`], of type [AudioBuffer](#AudioBuffer)

: Value to be assigned to the
 [`outputBuffer`](#dom-audioprocessingevent-outputbuffer) attribute of the event.

[`playbackTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: Value to be assigned to the
 [`playbackTime`](#dom-audioprocessingevent-playbacktime) attribute of the event.

### 1.13. The [`BiquadFilterNode` Interface]
[`BiquadFilterNode`](#BiquadFilterNode) is an
[`AudioNode`](#AudioNode)
processor implementing very common low-order filters.

Low-order filters are the building blocks of basic tone controls (bass,
mid, treble), graphic equalizers, and more advanced filters. Multiple
[`BiquadFilterNode`](#BiquadFilterNode) filters can be combined to form more complex filters.
The filter parameters such as
[`frequency`](#dom-biquadfilternode-frequency) can be changed over time for filter sweeps, etc. Each
[`BiquadFilterNode`](#BiquadFilterNode) can be configured as one of a number of common filter
types as shown in the IDL below. The default filter type is `"lowpass"`.

Both
[`frequency`](#dom-biquadfilternode-frequency) and
[`detune`](#dom-biquadfilternode-detune) form a [compound
parameter](#compound-parameter) and are both [a-rate](#a-rate). They are used together to determine a
[computedFrequency] value:

 computedFrequency(t) = frequency(t) * pow(2, detune(t) / 1200)

The [nominal range](#nominal-range) for this [compound
parameter](#compound-parameter) is \[0, [Nyquist
frequency](#--nyquist-frequency)\].

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

2

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`max`\"

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

Yes

Continues to output non-silent audio with zero input. Since this is an
IIR filter, the filter produces non-zero input forever, but in practice,
this can be limited after some finite time where the output is
sufficiently close to zero. The actual time depends on the filter
coefficients.

The number of channels of the output always equals the number of
channels of the input.

```
enum BiquadFilterType {
 "lowpass",
 "highpass",
 "bandpass",
 "lowshelf",
 "highshelf",
 "peaking",
 "notch",
 "allpass"
};
```

::: enum-description
[`BiquadFilterType`](#enumdef-biquadfiltertype) enumeration description

Enum value

Description

\"[`lowpass`]\"

A [lowpass filter](https://en.wikipedia.org/wiki/Low-pass_filter) allows
frequencies below the cutoff frequency to pass through and attenuates
frequencies above the cutoff. It implements a standard second-order
resonant lowpass filter with 12dB/octave rolloff.

frequency

: The cutoff frequency

[Q](https://en.wikipedia.org/wiki/Q_factor)

: Controls how peaked the response will be at the cutoff frequency. A
 large value makes the response more peaked.

gain

: Not used in this filter type

\"[`highpass`]\"

A [highpass filter](https://en.wikipedia.org/wiki/High-pass_filter) is
the opposite of a lowpass filter. Frequencies above the cutoff frequency
are passed through, but frequencies below the cutoff are attenuated. It
implements a standard second-order resonant highpass filter with
12dB/octave rolloff.

frequency

: The cutoff frequency below which the frequencies are attenuated

[Q](https://en.wikipedia.org/wiki/Q_factor)

: Controls how peaked the response will be at the cutoff frequency. A
 large value makes the response more peaked.

gain

: Not used in this filter type

\"[`bandpass`]\"

A [bandpass filter](https://en.wikipedia.org/wiki/Band-pass_filter)
allows a range of frequencies to pass through and attenuates the
frequencies below and above this frequency range. It implements a
second-order bandpass filter.

frequency

: The center of the frequency band

[Q](https://en.wikipedia.org/wiki/Q_factor)

: Controls the width of the band. The width becomes narrower as the Q
 value increases.

gain

: Not used in this filter type

\"[`lowshelf`]\"

The lowshelf filter allows all frequencies through, but adds a boost (or
attenuation) to the lower frequencies. It implements a second-order
lowshelf filter.

frequency

: The upper limit of the frequences where the boost (or attenuation)
 is applied.

[Q](https://en.wikipedia.org/wiki/Q_factor)

: Not used in this filter type.

gain

: The boost, in dB, to be applied. If the value is negative, the
 frequencies are attenuated.

\"[`highshelf`]\"

The highshelf filter is the opposite of the lowshelf filter and allows
all frequencies through, but adds a boost to the higher frequencies. It
implements a second-order highshelf filter

frequency

: The lower limit of the frequences where the boost (or attenuation)
 is applied.

[Q](https://en.wikipedia.org/wiki/Q_factor)

: Not used in this filter type.

gain

: The boost, in dB, to be applied. If the value is negative, the
 frequencies are attenuated.

\"[`peaking`]\"

The peaking filter allows all frequencies through, but adds a boost (or
attenuation) to a range of frequencies.

frequency

: The center frequency of where the boost is applied.

[Q](https://en.wikipedia.org/wiki/Q_factor)

: Controls the width of the band of frequencies that are boosted. A
 large value implies a narrow width.

gain

: The boost, in dB, to be applied. If the value is negative, the
 frequencies are attenuated.

\"[`notch`]\"

The notch filter (also known as a [band-stop or band-rejection
filter](https://en.wikipedia.org/wiki/Band-stop_filter)) is the opposite
of a bandpass filter. It allows all frequencies through, except for a
set of frequencies.

frequency

: The center frequency of where the notch is applied.

[Q](https://en.wikipedia.org/wiki/Q_factor)

: Controls the width of the band of frequencies that are attenuated. A
 large value implies a narrow width.

gain

: Not used in this filter type.

\"[`allpass`]\"

An [allpass
filter](https://en.wikipedia.org/wiki/All-pass_filter#Digital_implementation)
allows all frequencies through, but changes the phase relationship
between the various frequencies. It implements a second-order allpass
filter

frequency

: The frequency where the center of the phase transition occurs.
 Viewed another way, this is the frequency with maximal [group
 delay](https://en.wikipedia.org/wiki/Group_delay).

[Q](https://en.wikipedia.org/wiki/Q_factor)

: Controls how sharp the phase transition is at the center frequency.
 A larger value implies a sharper transition and a larger group
 delay.

gain

: Not used in this filter type.

All attributes of the
[`BiquadFilterNode`](#BiquadFilterNode) are [a-rate](#a-rate)
[`AudioParam`](#AudioParam)s.

```
[Exposed=Window]
interface BiquadFilterNode : AudioNode {
 constructor (BaseAudioContext context, optional BiquadFilterOptions options = );
 attribute BiquadFilterType type;
 readonly attribute AudioParam frequency;
 readonly attribute AudioParam detune;
 readonly attribute AudioParam Q;
 readonly attribute AudioParam gain;
 undefined getFrequencyResponse (Float32Array frequencyHz,
 Float32Array magResponse,
 Float32Array phaseResponse);
};
```

#### 1.13.1. Constructors

[`BiquadFilterNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `c` and an option object
 `option`, the user agent MUST [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [BiquadFilterNode.constructor()](#dom-biquadfilternode-biquadfilternode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`BiquadFilterNode`](#BiquadFilterNode) will be
 [associated](#associated) with.

 [`options`]

 [`BiquadFilterOptions`](#BiquadFilterOptions)

 [✘]

 [✔]

 Optional initial parameter value for this
 [`BiquadFilterNode`](#BiquadFilterNode).

#### 1.13.2. Attributes

[`Q`], of type [AudioParam](#AudioParam), readonly

: The [Q](https://en.wikipedia.org/wiki/Q_factor) factor of the
 filter.

 For
 [`lowpass`](#dom-biquadfiltertype-lowpass) and
 [`highpass`](#dom-biquadfiltertype-highpass) filters the
 [`Q`](#dom-biquadfilternode-q) value is interpreted to be in dB. For these filters
 the nominal range is \\(\[-Q\_{lim}, Q\_{lim}\]\\) where
 \\(Q\_{lim}\\) is the largest value for which \\(10\^{Q/20}\\) does
 not overflow. This is approximately \\(770.63678\\).

 For the
 [`bandpass`](#dom-biquadfiltertype-bandpass),
 [`notch`](#dom-biquadfiltertype-notch),
 [`allpass`](#dom-biquadfiltertype-allpass), and
 [`peaking`](#dom-biquadfiltertype-peaking) filters, this value is a linear value. The value is
 related to the bandwidth of the filter and hence should be a
 positive value. The nominal range is \\(\[0, 3.4028235e38\]\\), the
 upper limit being the
 [most-positive-single-float](#most-positive-single-float).

 This is not used for the
 [`lowshelf`](#dom-biquadfiltertype-lowshelf) and
 [`highshelf`](#dom-biquadfiltertype-highshelf) filters.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 1
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38, but see above for the actual limits for
 different filters
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38, but see above for the actual limits for
 different filters
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

[`detune`], of type [AudioParam](#AudioParam), readonly

: A detune value, in cents, for the frequency. It forms a [compound
 parameter](#compound-parameter) with
 [`frequency`](#dom-biquadfilternode-frequency) to form the
 [computedFrequency](#computedfrequency).

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 \\(\\approx -153600\\)
 [`maxValue`](#dom-audioparam-maxvalue)
 \\(\\approx 153600\\)
 This value is approximately \\(1200\\ \\log_2
 \\mathrm{FLT\\\_MAX}\\) where FLT_MAX is the largest
 [`float`](https://webidl.spec.whatwg.org/#idl-float) value.
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

[`frequency`], of type [AudioParam](#AudioParam), readonly

: The frequency at which the
 [`BiquadFilterNode`](#BiquadFilterNode) will operate, in Hz. It forms a [compound
 parameter](#compound-parameter) with
 [`detune`](#dom-biquadfilternode-detune) to form the
 [computedFrequency](#computedfrequency).

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 350
 [`minValue`](#dom-audioparam-minvalue)
 0
 [`maxValue`](#dom-audioparam-maxvalue)
 [Nyquist
 frequency](#--nyquist-frequency)
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

[`gain`], of type [AudioParam](#AudioParam), readonly

: The gain of the filter. Its value is in dB units. The gain is only
 used for
 [`lowshelf`](#dom-biquadfiltertype-lowshelf),
 [`highshelf`](#dom-biquadfiltertype-highshelf), and
 [`peaking`](#dom-biquadfiltertype-peaking) filters.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 \\(\\approx 1541\\)
 This value is approximately \\(40\\ \\log\_{10}
 \\mathrm{FLT\\\_MAX}\\) where FLT_MAX is the largest
 [`float`](https://webidl.spec.whatwg.org/#idl-float) value.
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

[`type`], of type [BiquadFilterType](#enumdef-biquadfiltertype)

: The type of this
 [`BiquadFilterNode`](#BiquadFilterNode). Its default value is
 \"[`lowpass`](#dom-biquadfiltertype-lowpass)\". The exact meaning of the other parameters depend
 on the value of the
 [`type`](#dom-biquadfilternode-type) attribute.

#### 1.13.3. Methods

[`getFrequencyResponse(frequencyHz, magResponse, phaseResponse)`]

: [Given the
 [`[[current value]]`](#dom-audioparam-current-value-slot) from each of the filter parameters, synchronously
 calculates the frequency response for the specified frequencies. The
 three parameters MUST be
 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)s of the same length, or an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror) MUST be thrown.]

 The frequency response returned MUST be computed with the
 [`AudioParam`](#AudioParam) sampled for the current processing block.

 Arguments for the
 [BiquadFilterNode.getFrequencyResponse()](#dom-biquadfilternode-getfrequencyresponse) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`frequencyHz`]

 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)

 [✘]

 [✘]

 This parameter specifies an array of frequencies, in Hz, at which
 the response values will be calculated.

 [`magResponse`]

 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)

 [✘]

 [✘]

 This parameter specifies an output array receiving the linear
 magnitude response values. If a value in the `frequencyHz` parameter
 is not within \[0, sampleRate/2\], where `sampleRate` is the value
 of the
 [`sampleRate`](#dom-baseaudiocontext-samplerate) property of the
 [`AudioContext`](#AudioContext), the corresponding value at the same index of the
 `magResponse` array MUST be `NaN`.

 [`phaseResponse`]

 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)

 [✘]

 [✘]

 This parameter specifies an output array receiving the phase
 response values in radians. If a value in the `frequencyHz`
 parameter is not within \[0; sampleRate/2\], where `sampleRate` is
 the value of the
 [`sampleRate`](#dom-baseaudiocontext-samplerate) property of the
 [`AudioContext`](#AudioContext), the corresponding value at the same index of the
 `phaseResponse` array MUST be `NaN`.

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

#### 1.13.4. [`BiquadFilterOptions`]
This specifies the options to be used when constructing a
[`BiquadFilterNode`](#BiquadFilterNode). All members are optional; if not specified, the normal
default values are used to construct the node.

```
dictionary BiquadFilterOptions : AudioNodeOptions {
 BiquadFilterType type = "lowpass";
 float Q = 1;
 float detune = 0;
 float frequency = 350;
 float gain = 0;
};
```

##### 1.13.4.1. Dictionary [`BiquadFilterOptions` Members]
[`Q`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `1`

: The desired initial value for
 [`Q`](#dom-biquadfilternode-q).

[`detune`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0`

: The desired initial value for
 [`detune`](#dom-biquadfilternode-detune).

[`frequency`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `350`

: The desired initial value for
 [`frequency`](#dom-biquadfilternode-frequency).

[`gain`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0`

: The desired initial value for
 [`gain`](#dom-biquadfilternode-gain).

[`type`], of type [BiquadFilterType](#enumdef-biquadfiltertype), defaulting to `"lowpass"`

: The desired initial type of the filter.

#### 1.13.5. Filters Characteristics

There are multiple ways of implementing the type of filters available
through the
[`BiquadFilterNode`](#BiquadFilterNode) each having very different characteristics. The
formulas in this section describe the filters that a [conforming
implementation](https://webidl.spec.whatwg.org/#dfn-conforming-implementation) MUST implement, as they determine the characteristics
of the different filter types. They are inspired by formulas found in
the [Audio EQ
Cookbook](https://webaudio.github.io/Audio-EQ-Cookbook/audio-eq-cookbook.html).

The
[`BiquadFilterNode`](#BiquadFilterNode) processes audio with a transfer function of

 $$
 H(z) = \frac{\frac{b_0}{a_0} + \frac{b_1}{a_0}z^{-1} + \frac{b_2}{a_0}z^{-2}}
 {1+\frac{a_1}{a_0}z^{-1}+\frac{a_2}{a_0}z^{-2}}
 $$

which is equivalent to a time-domain equation of:

 $$
 a_0 y(n) + a_1 y(n-1) + a_2 y(n-2) =
 b_0 x(n) + b_1 x(n-1) + b_2 x(n-2)
 $$

The initial filter state is 0.

 While fixed filters are stable, it is possible to
create unstable biquad filters using automations of
[`AudioParam`](#AudioParam)s. It is the developers responsibility to manage this.

 The UA may produce a warning to notify the user that
NaN values have occurred in the filter state. This is usually indicative
of an unstable filter.

The coefficients in the transfer function above are different for each
node type. The following intermediate variables are necessary for their
computation, based on the
[computedValue](#computedvalue)
of the [`AudioParam`](#AudioParam)s of the
[`BiquadFilterNode`](#BiquadFilterNode).

- Let \\(F_s\\) be the value of the
 [`sampleRate`](#dom-baseaudiocontext-samplerate) attribute for this
 [`AudioContext`](#AudioContext).

- Let \\(f_0\\) be the value of the
 [computedFrequency](#computedfrequency).

- Let \\(G\\) be the value of the
 [`gain`](#dom-biquadfilternode-gain)
 [`AudioParam`](#AudioParam).

- Let \\(Q\\) be the value of the
 [`Q`](#dom-biquadfilternode-q)
 [`AudioParam`](#AudioParam).

- Finally let

 $$
 \begin{align*}
 A &amp;= 10^{\frac{G}{40}} \\
 \omega_0 &amp;= 2\pi\frac{f_0}{F_s} \\
 \alpha_Q &amp;= \frac{\sin\omega_0}{2Q} \\
 \alpha_{Q_{dB}} &amp;= \frac{\sin\omega_0}{2 \cdot 10^{Q/20}} \\
 S &amp;= 1 \\
 \alpha_S &amp;= \frac{\sin\omega_0}{2}\sqrt{\left(A+\frac{1}{A}\right)\left(\frac{1}{S}-1\right)+2}
 \end{align*}
 $$

The six coefficients (\\(b_0, b_1, b_2, a_0, a_1, a_2\\)) for each
filter type, are:

\"[`lowpass`](#dom-biquadfiltertype-lowpass)\"

: $$
 \begin{align*}
 b_0 &amp;= \frac{1 - \cos\omega_0}{2} \\
 b_1 &amp;= 1 - \cos\omega_0 \\
 b_2 &amp;= \frac{1 - \cos\omega_0}{2} \\
 a_0 &amp;= 1 + \alpha_{Q_{dB}} \\
 a_1 &amp;= -2 \cos\omega_0 \\
 a_2 &amp;= 1 - \alpha_{Q_{dB}}
 \end{align*}
 $$

\"[`highpass`](#dom-biquadfiltertype-highpass)\"

: $$
 \begin{align*}
 b_0 &amp;= \frac{1 + \cos\omega_0}{2} \\
 b_1 &amp;= -(1 + \cos\omega_0) \\
 b_2 &amp;= \frac{1 + \cos\omega_0}{2} \\
 a_0 &amp;= 1 + \alpha_{Q_{dB}} \\
 a_1 &amp;= -2 \cos\omega_0 \\
 a_2 &amp;= 1 - \alpha_{Q_{dB}}
 \end{align*}
 $$

\"[`bandpass`](#dom-biquadfiltertype-bandpass)\"

: $$
 \begin{align*}
 b_0 &amp;= \alpha_Q \\
 b_1 &amp;= 0 \\
 b_2 &amp;= -\alpha_Q \\
 a_0 &amp;= 1 + \alpha_Q \\
 a_1 &amp;= -2 \cos\omega_0 \\
 a_2 &amp;= 1 - \alpha_Q
 \end{align*}
 $$

\"[`notch`](#dom-biquadfiltertype-notch)\"

: $$
 \begin{align*}
 b_0 &amp;= 1 \\
 b_1 &amp;= -2\cos\omega_0 \\
 b_2 &amp;= 1 \\
 a_0 &amp;= 1 + \alpha_Q \\
 a_1 &amp;= -2 \cos\omega_0 \\
 a_2 &amp;= 1 - \alpha_Q
 \end{align*}
 $$

\"[`allpass`](#dom-biquadfiltertype-allpass)\"

: $$
 \begin{align*}
 b_0 &amp;= 1 - \alpha_Q \\
 b_1 &amp;= -2\cos\omega_0 \\
 b_2 &amp;= 1 + \alpha_Q \\
 a_0 &amp;= 1 + \alpha_Q \\
 a_1 &amp;= -2 \cos\omega_0 \\
 a_2 &amp;= 1 - \alpha_Q
 \end{align*}
 $$

\"[`peaking`](#dom-biquadfiltertype-peaking)\"

: $$
 \begin{align*}
 b_0 &amp;= 1 + \alpha_Q\, A \\
 b_1 &amp;= -2\cos\omega_0 \\
 b_2 &amp;= 1 - \alpha_Q\,A \\
 a_0 &amp;= 1 + \frac{\alpha_Q}{A} \\
 a_1 &amp;= -2 \cos\omega_0 \\
 a_2 &amp;= 1 - \frac{\alpha_Q}{A}
 \end{align*}
 $$

\"[`lowshelf`](#dom-biquadfiltertype-lowshelf)\"

: $$
 \begin{align*}
 b_0 &amp;= A \left[ (A+1) - (A-1) \cos\omega_0 + 2 \alpha_S \sqrt{A})\right] \\
 b_1 &amp;= 2 A \left[ (A-1) - (A+1) \cos\omega_0 )\right] \\
 b_2 &amp;= A \left[ (A+1) - (A-1) \cos\omega_0 - 2 \alpha_S \sqrt{A}) \right] \\
 a_0 &amp;= (A+1) + (A-1) \cos\omega_0 + 2 \alpha_S \sqrt{A} \\
 a_1 &amp;= -2 \left[ (A-1) + (A+1) \cos\omega_0\right] \\
 a_2 &amp;= (A+1) + (A-1) \cos\omega_0 - 2 \alpha_S \sqrt{A})
 \end{align*}
 $$

\"[`highshelf`](#dom-biquadfiltertype-highshelf)\"

: $$
 \begin{align*}
 b_0 &amp;= A\left[ (A+1) + (A-1)\cos\omega_0 + 2\alpha_S\sqrt{A} )\right] \\
 b_1 &amp;= -2A\left[ (A-1) + (A+1)\cos\omega_0 )\right] \\
 b_2 &amp;= A\left[ (A+1) + (A-1)\cos\omega_0 - 2\alpha_S\sqrt{A} )\right] \\
 a_0 &amp;= (A+1) - (A-1)\cos\omega_0 + 2\alpha_S\sqrt{A} \\
 a_1 &amp;= 2\left[ (A-1) - (A+1)\cos\omega_0\right] \\
 a_2 &amp;= (A+1) - (A-1)\cos\omega_0 - 2\alpha_S\sqrt{A}
 \end{align*}
 $$

### 1.14. The [`ChannelMergerNode` Interface]
The
[`ChannelMergerNode`](#ChannelMergerNode) is for use in more advanced applications and would
often be used in conjunction with
[`ChannelSplitterNode`](#ChannelSplitterNode).

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

see notes

Defaults to 6, but is determined by
[`ChannelMergerOptions`](#ChannelMergerOptions),[`numberOfInputs`](#dom-channelmergeroptions-numberofinputs) or the value specified by
[`createChannelMerger`](#dom-baseaudiocontext-createchannelmerger).

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

1

Has [channelCount
constraints](#audionode-channelcount-constraints)

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`explicit`\"

Has [channelCountMode
constraints](#audionode-channelcountmode-constraints)

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

No

This interface represents an
[`AudioNode`](#AudioNode)
for combining channels from multiple audio streams into a single audio
stream. It has a variable number of inputs (defaulting to 6), but not
all of them need be connected. There is a single output whose audio
stream has a number of channels equal to the number of inputs when any
of the inputs is [actively
processing](#actively-processing). If none of the inputs are [actively
processing](#actively-processing), then output is a single channel of silence.

To merge multiple inputs into one stream, each input gets downmixed into
one channel (mono) based on the specified mixing rule. An unconnected
input still counts as **one silent channel** in the output. Changing
input streams does **not** affect the order of output channels.

For example, if a default
[`ChannelMergerNode`](#ChannelMergerNode) has two connected stereo inputs, the first and second
input will be downmixed to mono respectively before merging. The output
will be a 6-channel stream whose first two channels are be filled with
the first two (downmixed) inputs and the rest of channels will be
silent.

Also the
[`ChannelMergerNode`](#ChannelMergerNode) can be used to arrange multiple audio streams in a
certain order for the multi-channel speaker array such as 5.1 surround
set up. The merger does not interpret the channel identities (such as
left, right, etc.), but simply combines channels in the order that they
are input.

![A diagram of
ChannelMerger](images/channel-merger.svg){a}

```
[Exposed=Window]
interface ChannelMergerNode : AudioNode {
 constructor (BaseAudioContext context, optional ChannelMergerOptions options = );
};
```

#### 1.14.1. Constructors

[`ChannelMergerNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `c` and an option object
 `option`, the user agent MUST [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [ChannelMergerNode.constructor()](#dom-channelmergernode-channelmergernode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`ChannelMergerNode`](#ChannelMergerNode) will be
 [associated](#associated) with.

 [`options`]

 [`ChannelMergerOptions`](#ChannelMergerOptions)

 [✘]

 [✔]

 Optional initial parameter value for this
 [`ChannelMergerNode`](#ChannelMergerNode).

#### 1.14.2. [`ChannelMergerOptions`]
```
dictionary ChannelMergerOptions : AudioNodeOptions {
 unsigned long numberOfInputs = 6;
};
```

##### 1.14.2.1. Dictionary [`ChannelMergerOptions` Members]
[`numberOfInputs`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), defaulting to `6`

: The number inputs for the
 [`ChannelMergerNode`](#ChannelMergerNode). See
 [`createChannelMerger()`](#dom-baseaudiocontext-createchannelmerger) for constraints on this value.

### 1.15. The [`ChannelSplitterNode` Interface]
The
[`ChannelSplitterNode`](#ChannelSplitterNode) is for use in more advanced applications and would
often be used in conjunction with
[`ChannelMergerNode`](#ChannelMergerNode).

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

see notes

This defaults to 6, but is otherwise determined from
[`ChannelSplitterOptions.numberOfOutputs`](#dom-channelsplitteroptions-numberofoutputs) or the value specified by
[`createChannelSplitter`](#dom-baseaudiocontext-createchannelsplitter) or the
[`numberOfOutputs`](#dom-channelsplitteroptions-numberofoutputs) member of the
[`ChannelSplitterOptions`](#ChannelSplitterOptions) dictionary for the
[`constructor`](#dom-channelsplitternode-channelsplitternode).

[`channelCount`](#dom-audionode-channelcount)

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

Has [channelCount
constraints](#audionode-channelcount-constraints)

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`explicit`\"

Has [channelCountMode
constraints](#audionode-channelcountmode-constraints)

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`discrete`\"

Has [channelInterpretation
constraints](#audionode-channelinterpretation-constraints)

[tail-time](#tail-time)

No

This interface represents an
[`AudioNode`](#AudioNode)
for accessing the individual channels of an audio stream in the routing
graph. It has a single input, and a number of \"active\" outputs which
equals the number of channels in the input audio stream. For example, if
a stereo input is connected to an
[`ChannelSplitterNode`](#ChannelSplitterNode) then the number of active outputs will be two (one from
the left channel and one from the right). There are always a total
number of N outputs (determined by the `numberOfOutputs` parameter to
the [`AudioContext`](#AudioContext) method
[`createChannelSplitter()`](#dom-baseaudiocontext-createchannelsplitter)), The default number is 6 if this value is not
provided. Any outputs which are not \"active\" will output silence and
would typically not be connected to anything.

![A diagram of a
ChannelSplitter](images/channel-splitter.png){a
height="398" width="601"}

Please note that in this example, the splitter does **not** interpret
the channel identities (such as left, right, etc.), but simply splits
out channels in the order that they are input.

One application for
[`ChannelSplitterNode`](#ChannelSplitterNode) is for doing \"matrix mixing\" where individual gain
control of each channel is desired.

```
[Exposed=Window]
interface ChannelSplitterNode : AudioNode {
 constructor (BaseAudioContext context, optional ChannelSplitterOptions options = );
};
```

#### 1.15.1. Constructors

[`ChannelSplitterNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `c` and an option object
 `option`, the user agent MUST [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [ChannelSplitterNode.constructor()](#dom-channelsplitternode-channelsplitternode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`ChannelSplitterNode`](#ChannelSplitterNode) will be
 [associated](#associated) with.

 [`options`]

 [`ChannelSplitterOptions`](#ChannelSplitterOptions)

 [✘]

 [✔]

 Optional initial parameter value for this
 [`ChannelSplitterNode`](#ChannelSplitterNode).

#### 1.15.2. [`ChannelSplitterOptions`]
```
dictionary ChannelSplitterOptions : AudioNodeOptions {
 unsigned long numberOfOutputs = 6;
};
```

##### 1.15.2.1. Dictionary [`ChannelSplitterOptions` Members]
[`numberOfOutputs`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), defaulting to `6`

: The number outputs for the
 [`ChannelSplitterNode`](#ChannelSplitterNode). See
 [`createChannelSplitter()`](#dom-baseaudiocontext-createchannelsplitter) for constraints on this value.

### 1.16. The [`ConstantSourceNode` Interface]
This interface represents a constant audio source whose output is
nominally a constant value. It is useful as a constant source node in
general and can be used as if it were a constructible
[`AudioParam`](#AudioParam) by automating its
[`offset`](#dom-constantsourcenode-offset) or connecting another node to it.

The single output of this node consists of one channel (mono).

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

0

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

2

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`max`\"

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

No

```
[Exposed=Window]
interface ConstantSourceNode : AudioScheduledSourceNode {
 constructor (BaseAudioContext context, optional ConstantSourceOptions options = );
 readonly attribute AudioParam offset;
};
```

#### 1.16.1. Constructors

[`ConstantSourceNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `c` and an option object
 `option`, the user agent MUST [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [ConstantSourceNode.constructor()](#dom-constantsourcenode-constantsourcenode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`ConstantSourceNode`](#ConstantSourceNode) will be
 [associated](#associated) with.

 [`options`]

 [`ConstantSourceOptions`](#ConstantSourceOptions)

 [✘]

 [✔]

 Optional initial parameter value for this
 [`ConstantSourceNode`](#ConstantSourceNode).

#### 1.16.2. Attributes

[`offset`], of type [AudioParam](#AudioParam), readonly

: The constant value of the source.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 1
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

#### 1.16.3. [`ConstantSourceOptions`]
This specifies options for constructing a
[`ConstantSourceNode`](#ConstantSourceNode). All members are optional; if not specified, the normal
defaults are used for constructing the node.

```
dictionary ConstantSourceOptions {
 float offset = 1;
};
```

##### 1.16.3.1. Dictionary [`ConstantSourceOptions` Members]
[`offset`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `1`

: The initial value for the
 [`offset`](#dom-constantsourcenode-offset) AudioParam of this node.

### 1.17. The [`ConvolverNode` Interface]
This interface represents a processing node which applies a linear
convolution effect given an impulse response.

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

2

Has [channelCount
constraints](#audionode-channelcount-constraints)

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`clamped-max`\"

Has [channelCountMode
constraints](#audionode-channelcountmode-constraints)

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

Yes

Continues to output non-silent audio with zero input for the length of
the
[`buffer`](#dom-convolvernode-buffer).

The input of this node is either mono (1 channel) or stereo (2 channels)
and cannot be increased. Connections from nodes with more channels will
be [down-mixed appropriately](#channel-up-mixing-and-down-mixing).

There are [channelCount
constraints](#audionode-channelcount-constraints) and [channelCountMode
constraints](#audionode-channelcountmode-constraints) for this node. These constraints ensure that the input
to the node is either mono or stereo.

```
[Exposed=Window]
interface ConvolverNode : AudioNode {
 constructor (BaseAudioContext context, optional ConvolverOptions options = );
 attribute AudioBuffer? buffer;
 attribute boolean normalize;
};
```

#### 1.17.1. Constructors

[`ConvolverNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `context` and an option object
 `options`, execute these steps:

 1. Set the attributes
 [`normalize`](#dom-convolvernode-normalize) to the inverse of the value of
 [`disableNormalization`](#dom-convolveroptions-disablenormalization).

 2. If
 [`buffer`](#dom-convolvernode-buffer)
 [exists](https://infra.spec.whatwg.org/#map-exists), set the
 [`buffer`](#dom-convolvernode-buffer) attribute to its value.

 This means that the buffer will be normalized
 according to the value of the
 [`normalize`](#dom-convolvernode-normalize) attribute.

 3. Let `o` be new
 [`AudioNodeOptions`](#AudioNodeOptions) dictionary.

 4. If
 [`channelCount`](#dom-audionodeoptions-channelcount)
 [exists](https://infra.spec.whatwg.org/#map-exists) in `options`, set
 [`channelCount`](#dom-audionodeoptions-channelcount) on `o` with the same value.

 5. If
 [`channelCountMode`](#dom-audionodeoptions-channelcountmode)
 [exists](https://infra.spec.whatwg.org/#map-exists) in `options`, set
 [`channelCountMode`](#dom-audionodeoptions-channelcountmode) on `o` with the same value.

 6. If
 [`channelInterpretation`](#dom-audionodeoptions-channelinterpretation)
 [exists](https://infra.spec.whatwg.org/#map-exists) in `options`, set
 [`channelInterpretation`](#dom-audionodeoptions-channelinterpretation) on `o` with the same value.

 7. [Initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `c` and `o` as
 argument.

 Arguments for the
 [ConvolverNode.constructor()](#dom-convolvernode-convolvernode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`ConvolverNode`](#ConvolverNode) will be
 [associated](#associated) with.

 [`options`]

 [`ConvolverOptions`](#ConvolverOptions)

 [✘]

 [✔]

 Optional initial parameter value for this
 [`ConvolverNode`](#ConvolverNode).

#### 1.17.2. Attributes

[`buffer`], of type [AudioBuffer](#AudioBuffer), nullable

: At the time when this attribute is set, the
 [`buffer`](#dom-convolvernode-buffer) and the state of the
 [`normalize`](#dom-convolvernode-normalize) attribute will be used to configure the
 [`ConvolverNode`](#ConvolverNode) with this impulse response having the given
 normalization. The initial value of this attribute is null.

 :::
 When setting the
 [`buffer attribute`], execute the following [steps
 synchronously]:
 1. If the buffer
 [`number of channels`](#dom-audiobuffer-numberofchannels) is not 1, 2, 4, or if the
 [`sample-rate`](#dom-audiobuffer-samplerate) of the buffer is not the same as the
 [`sample-rate`](#dom-baseaudiocontext-samplerate) of its
 [associated](#associated)
 [`BaseAudioContext`](#BaseAudioContext), a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) MUST be thrown.

 2. [Acquire the
 content](#acquire-the-content)
 of the
 [`AudioBuffer`](#AudioBuffer).
 :::

 If the
 [`buffer`](#dom-convolvernode-buffer) is set to an new buffer, audio may glitch. If this
 is undesirable, it is recommended to create a new
 [`ConvolverNode`](#ConvolverNode) to replace the old, possibly cross-fading between
 the two.

 The
 [`ConvolverNode`](#ConvolverNode) produces a mono output only in the single case
 where there is a single input channel and a single-channel
 [`buffer`](#dom-convolvernode-buffer). In all other cases, the output is stereo. In
 particular, when the
 [`buffer`](#dom-convolvernode-buffer) has four channels and there are two input channels,
 the [`ConvolverNode`](#ConvolverNode) performs matrix \"true\" stereo convolution. For
 normative information please see the [channel configuration
 diagrams](#Convolution-channel-configurations)

[`normalize`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean)

: Controls whether the impulse response from the buffer will be scaled
 by an equal-power normalization when the
 [`buffer`](#dom-convolvernode-buffer) attribute is set. Its default value is `true` in
 order to achieve a more uniform output level from the convolver when
 loaded with diverse impulse responses. If
 [`normalize`](#dom-convolvernode-normalize) is set to `false`, then the convolution will be
 rendered with no pre-processing/scaling of the impulse response.
 Changes to this value do not take effect until the next time the
 [`buffer`](#dom-convolvernode-buffer) attribute is set.

 If the
 [`normalize`](#dom-convolvernode-normalize) attribute is false when the
 [`buffer`](#dom-convolvernode-buffer) attribute is set then the
 [`ConvolverNode`](#ConvolverNode) will perform a linear convolution given the exact
 impulse response contained within the
 [`buffer`](#dom-convolvernode-buffer).

 Otherwise, if the
 [`normalize`](#dom-convolvernode-normalize) attribute is true when the
 [`buffer`](#dom-convolvernode-buffer) attribute is set then the
 [`ConvolverNode`](#ConvolverNode) will first perform a scaled RMS-power analysis of
 the audio data contained within
 [`buffer`](#dom-convolvernode-buffer) to calculate a `normalizationScale`
 given this algorithm:

 ```
 function calculateNormalizationScale(buffer) { const GainCalibration = 0.00125; const GainCalibrationSampleRate = 44100; const MinPower = 0.000125; // Normalize by RMS power. const numberOfChannels = buffer.numberOfChannels; const length = buffer.length; let power = 0; for (let i = 0; i < numberOfChannels; i++) { let channelPower = 0; const channelData = buffer.getChannelData(i); for (let j = 0; j < length; j++) { const sample = channelData[j]; channelPower += sample * sample; } power += channelPower; } power = Math.sqrt(power / (numberOfChannels * length)); // Protect against accidental overload. if (!isFinite(power) || isNaN(power) || power < MinPower) power = MinPower; let scale = 1 / power; // Calibrate to make perceived volume same as unprocessed. scale *= GainCalibration; // Scale depends on sample-rate. if (buffer.sampleRate) scale *= GainCalibrationSampleRate / buffer.sampleRate; // True-stereo compensation. if (numberOfChannels == 4) scale *= 0.5; return scale;}
 ```

 During processing, the ConvolverNode will then take this calculated
 `normalizationScale` value and multiply it by the result
 of the linear convolution resulting from processing the input with
 the impulse response (represented by the
 [`buffer`](#dom-convolvernode-buffer)) to produce the final output. Or any mathematically
 equivalent operation may be used, such as pre-multiplying the input
 by `normalizationScale`, or pre-multiplying a version of
 the impulse-response by `normalizationScale`.

#### 1.17.3. [`ConvolverOptions`]
The specifies options for constructing a
[`ConvolverNode`](#ConvolverNode). All members are optional; if not specified, the node
is contructing using the normal defaults.

```
dictionary ConvolverOptions : AudioNodeOptions {
 AudioBuffer? buffer;
 boolean disableNormalization = false;
};
```

##### 1.17.3.1. Dictionary [`ConvolverOptions` Members]
[`buffer`], of type [AudioBuffer](#AudioBuffer), nullable

: The desired buffer for the
 [`ConvolverNode`](#ConvolverNode). This buffer will be normalized according to the
 value of
 [`disableNormalization`](#dom-convolveroptions-disablenormalization).

[`disableNormalization`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: The opposite of the desired initial value for the
 [`normalize`](#dom-convolvernode-normalize) attribute of the
 [`ConvolverNode`](#ConvolverNode).

#### 1.17.4. Channel Configurations for Input, Impulse Response and Output

Implementations MUST support the following allowable configurations of
impulse response channels in a
[`ConvolverNode`](#ConvolverNode) to achieve various reverb effects with 1 or 2 channels
of input.

As shown in the diagram below, single channel convolution operates on a
mono audio input, using a mono impulse response, and generating a mono
output. The remaining images in the diagram illustrate the supported
cases for mono and stereo playback where the number of channels of the
input is 1 or 2, and the number of channels in the
[`buffer`](#dom-convolvernode-buffer) is 1, 2, or 4. Developers desiring more complex and
arbitrary matrixing can use a
[`ChannelSplitterNode`](#ChannelSplitterNode), multiple single-channel
[`ConvolverNode`](#ConvolverNode)s and a
[`ChannelMergerNode`](#ChannelMergerNode).

If this node is not [actively
processing](#actively-processing), the output is a single channel of silence.

 The diagrams below show the outputs when [actively
processing](#actively-processing).

![A graphical representation of supported input and output channel count
possibilities when using a
[`ConvolverNode`](#ConvolverNode).](images/convolver-diagram.png)

### 1.18. The [`DelayNode` Interface]
A delay-line is a fundamental building block in audio applications. This
interface is an [`AudioNode`](#AudioNode) with a single input and single output.

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

2

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`max`\"

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

Yes

Continues to output non-silent audio with zero input up to the
[`maxDelayTime`](#dom-delayoptions-maxdelaytime) of the node.

The number of channels of the output always equals the number of
channels of the input.

It delays the incoming audio signal by a certain amount. Specifically,
at each time *t*, input signal *input(t)*, delay time *delayTime(t)* and
output signal *output(t)*, the output will be *output(t) = input(t -
delayTime(t))*. The default `delayTime` is 0 seconds (no delay).

When the number of channels in a
[`DelayNode`](#DelayNode)'s
input changes (thus changing the output channel count also), there may
be delayed audio samples which have not yet been output by the node and
are part of its internal state. If these samples were received earlier
with a different channel count, they MUST be upmixed or downmixed before
being combined with newly received input so that all internal delay-line
mixing takes place using the single prevailing channel layout.

 By definition, a
[`DelayNode`](#DelayNode)
introduces an audio processing latency equal to the amount of the delay.

```
[Exposed=Window]
interface DelayNode : AudioNode {
 constructor (BaseAudioContext context, optional DelayOptions options = );
 readonly attribute AudioParam delayTime;
};
```

#### 1.18.1. Constructors

[`DelayNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `c` and an option object
 `option`, the user agent MUST [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [DelayNode.constructor()](#dom-delaynode-delaynode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`DelayNode`](#DelayNode)
 will be [associated](#associated) with.

 [`options`]

 [`DelayOptions`](#DelayOptions)

 [✘]

 [✔]

 Optional initial parameter value for this
 [`DelayNode`](#DelayNode).

#### 1.18.2. Attributes

[`delayTime`], of type [AudioParam](#AudioParam), readonly

: An [`AudioParam`](#AudioParam) object representing the amount of delay (in
 seconds) to apply. Its default `value` is 0 (no delay). The minimum
 value is 0 and the maximum value is determined by the
 [`maxDelayTime`](#dom-baseaudiocontext-createdelay-maxdelaytime-maxdelaytime) argument to the
 [`AudioContext`](#AudioContext) method
 [`createDelay()`](#dom-baseaudiocontext-createdelay) or the
 [`maxDelayTime`](#dom-delayoptions-maxdelaytime) member of the
 [`DelayOptions`](#DelayOptions) dictionary for the
 [`constructor`](#dom-delaynode-delaynode).

 If [`DelayNode`](#DelayNode) is part of a [cycle](#cycle), then the value of the
 [`delayTime`](#dom-delaynode-delaytime) attribute is clamped to a minimum of one [render
 quantum](#render-quantum).

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 0
 [`maxValue`](#dom-audioparam-maxvalue)
 [`maxDelayTime`](#dom-delayoptions-maxdelaytime)
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

#### 1.18.3. [`DelayOptions`]
This specifies options for constructing a
[`DelayNode`](#DelayNode).
All members are optional; if not given, the node is constructed using
the normal defaults.

```
dictionary DelayOptions : AudioNodeOptions {
 double maxDelayTime = 1;
 double delayTime = 0;
};
```

##### 1.18.3.1. Dictionary [`DelayOptions` Members]
[`delayTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `0`

: The initial delay time for the node.

[`maxDelayTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `1`

: The maximum delay time for the node. See
 [`createDelay(maxDelayTime)`](#dom-baseaudiocontext-createdelay-maxdelaytime-maxdelaytime) for constraints.

#### 1.18.4. Processing

A [`DelayNode`](#DelayNode)
has an internal buffer that holds
[`delayTime`](#DelayNode)
seconds of audio.

The processing of a [`DelayNode`](#DelayNode) is broken down in two parts: writing to the delay line,
and reading from the delay line. This is done via two internal
[`AudioNode`](#AudioNode)s
(that are not available to authors and exist only to ease the
description of the inner workings of the node). Both are created from a
[`DelayNode`](#DelayNode).

Creating a [DelayWriter] for a [`DelayNode`](#DelayNode) means creating an object that has the same interface as
an [`AudioNode`](#AudioNode), and that writes the input audio into the internal
buffer of the [`DelayNode`](#DelayNode). It has the same input connections as the
[`DelayNode`](#DelayNode) it
was created from.

Creating a [DelayReader] for a [`DelayNode`](#DelayNode) means creating an object that has the same interface as
an [`AudioNode`](#AudioNode), and that can read the audio data from the internal
buffer of the [`DelayNode`](#DelayNode). It is connected to the same
[`AudioNode`](#AudioNode)s
as the [`DelayNode`](#DelayNode) it was created from. A
[DelayReader](#delayreader) is a
[source node](#source-node).

When processing an input buffer, a
[DelayWriter](#delaywriter) MUST
write the audio to the internal buffer of the
[`DelayNode`](#DelayNode).

When producing an output buffer, a
[DelayReader](#delayreader) MUST
yield exactly the audio that was written to the corresponding
[DelayWriter](#delaywriter)
[`delayTime`](#DelayNode)
seconds ago.

 This means that channel count changes are reflected
after the delay time has passed.

### 1.19. The [`DynamicsCompressorNode` Interface]
[`DynamicsCompressorNode`](#DynamicsCompressorNode) is an
[`AudioNode`](#AudioNode)
processor implementing a dynamics compression effect.

Dynamics compression is very commonly used in musical production and
game audio. It lowers the volume of the loudest parts of the signal and
raises the volume of the softest parts. Overall, a louder, richer, and
fuller sound can be achieved. It is especially important in games and
musical applications where large numbers of individual sounds are played
simultaneous to control the overall signal level and help avoid clipping
(distorting) the audio output to the speakers.

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

2

Has [channelCount
constraints](#audionode-channelcount-constraints)

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`clamped-max`\"

Has [channelCountMode
constraints](#audionode-channelcountmode-constraints)

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

Yes

This node has a [tail-time](#tail-time) such that this node continues to output non-silent
audio with zero input due to the look-ahead delay.

```
[Exposed=Window]
interface DynamicsCompressorNode : AudioNode {
 constructor (BaseAudioContext context,
 optional DynamicsCompressorOptions options = );
 readonly attribute AudioParam threshold;
 readonly attribute AudioParam knee;
 readonly attribute AudioParam ratio;
 readonly attribute float reduction;
 readonly attribute AudioParam attack;
 readonly attribute AudioParam release;
};
```

#### 1.19.1. Constructors

[`DynamicsCompressorNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `c` and an option object
 `option`, the user agent MUST [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Let
 [`[[internal reduction]]`] be a private slot on
 `this`, that holds a floating point number, in decibels.
 Set
 [`[[internal reduction]]`](#dom-dynamicscompressornode-internal-reduction-slot) to 0.0.

 Arguments for the
 [DynamicsCompressorNode.constructor()](#dom-dynamicscompressornode-dynamicscompressornode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`DynamicsCompressorNode`](#DynamicsCompressorNode) will be
 [associated](#associated) with.

 [`options`]

 [`DynamicsCompressorOptions`](#DynamicsCompressorOptions)

 [✘]

 [✔]

 Optional initial parameter value for this
 [`DynamicsCompressorNode`](#DynamicsCompressorNode).

#### 1.19.2. Attributes

[`attack`], of type [AudioParam](#AudioParam), readonly

: The amount of time (in seconds) to reduce the gain by 10dB.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 .003
 [`minValue`](#dom-audioparam-minvalue)
 0
 [`maxValue`](#dom-audioparam-maxvalue)
 1
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`k-rate`](#dom-automationrate-k-rate)\"
 Has [automation rate
 constraints](#audioparam-automation-rate-constraints)
 :::

[`knee`], of type [AudioParam](#AudioParam), readonly

: A decibel value representing the range above the threshold where the
 curve smoothly transitions to the \"ratio\" portion.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 30
 [`minValue`](#dom-audioparam-minvalue)
 0
 [`maxValue`](#dom-audioparam-maxvalue)
 40
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`k-rate`](#dom-automationrate-k-rate)\"
 Has [automation rate
 constraints](#audioparam-automation-rate-constraints)
 :::

[`ratio`], of type [AudioParam](#AudioParam), readonly

: The amount of dB change in input for a 1 dB change in output.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 12
 [`minValue`](#dom-audioparam-minvalue)
 1
 [`maxValue`](#dom-audioparam-maxvalue)
 20
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`k-rate`](#dom-automationrate-k-rate)\"
 Has [automation rate
 constraints](#audioparam-automation-rate-constraints)
 :::

[`reduction`], of type [float](https://webidl.spec.whatwg.org/#idl-float), readonly

: A read-only decibel value for metering purposes, representing the
 current amount of gain reduction that the compressor is applying to
 the signal. If fed no signal the value will be 0 (no gain
 reduction). When this attribute is read, return the value of the
 private slot
 [`[[internal reduction]]`](#dom-dynamicscompressornode-internal-reduction-slot).

[`release`], of type [AudioParam](#AudioParam), readonly

: The amount of time (in seconds) to increase the gain by 10dB.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 .25
 [`minValue`](#dom-audioparam-minvalue)
 0
 [`maxValue`](#dom-audioparam-maxvalue)
 1
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`k-rate`](#dom-automationrate-k-rate)\"
 Has [automation rate
 constraints](#audioparam-automation-rate-constraints)
 :::

[`threshold`], of type [AudioParam](#AudioParam), readonly

: The decibel value above which the compression will start taking
 effect.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 -24
 [`minValue`](#dom-audioparam-minvalue)
 -100
 [`maxValue`](#dom-audioparam-maxvalue)
 0
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`k-rate`](#dom-automationrate-k-rate)\"
 Has [automation rate
 constraints](#audioparam-automation-rate-constraints)
 :::

#### 1.19.3. [`DynamicsCompressorOptions`]
This specifies the options to use in constructing a
[`DynamicsCompressorNode`](#DynamicsCompressorNode). All members are optional; if not specified the normal
defaults are used in constructing the node.

```
dictionary DynamicsCompressorOptions : AudioNodeOptions {
 float attack = 0.003;
 float knee = 30;
 float ratio = 12;
 float release = 0.25;
 float threshold = -24;
};
```

##### 1.19.3.1. Dictionary [`DynamicsCompressorOptions` Members]
[`attack`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0.003`

: The initial value for the
 [`attack`](#dom-dynamicscompressornode-attack) AudioParam.

[`knee`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `30`

: The initial value for the
 [`knee`](#dom-dynamicscompressornode-knee) AudioParam.

[`ratio`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `12`

: The initial value for the
 [`ratio`](#dom-dynamicscompressornode-ratio) AudioParam.

[`release`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0.25`

: The initial value for the
 [`release`](#dom-dynamicscompressornode-release) AudioParam.

[`threshold`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `-24`

: The initial value for the
 [`threshold`](#dom-dynamicscompressornode-threshold) AudioParam.

#### 1.19.4. Processing

Dynamics compression can be implemented in a variety of ways. The
[`DynamicsCompressorNode`](#DynamicsCompressorNode) implements a dynamics processor that has the following
characteristics:

- Fixed look-ahead (this means that an
 [`DynamicsCompressorNode`](#DynamicsCompressorNode) adds a fixed latency to the signal chain).

- Configurable attack speed, release speed, threshold, knee hardness and
 ratio.

- Side-chaining is not supported.

- The gain reduction is reported *via* the `reduction` property on the
 [`DynamicsCompressorNode`](#DynamicsCompressorNode).

- The compression curve has three parts:

 - The first part is the identity: \\(f(x) = x\\).

 - The second part is the soft-knee portion, which MUST be a
 monotonically increasing function.

 - The third part is a linear function: \\(f(x) = \\frac{1}{ratio}
 \\cdot x \\).

 This curve MUST be continuous and piece-wise differentiable, and
 corresponds to a target output level, based on the input level.

Graphically, such a curve would look something like this:

![A typical compression curve, showing the knee portion (soft or hard)
as well as the
threshold.](images/compression-curve.svg){a
style="width: 50%"}

Internally, the
[`DynamicsCompressorNode`](#DynamicsCompressorNode) is described with a combination of other
[`AudioNode`](#AudioNode)s,
as well as a special algorithm, to compute the gain reduction value.

The following [`AudioNode`](#AudioNode) graph is used internally, `input` and `output`
respectively being the input and output
[`AudioNode`](#AudioNode),
`context` the
[`BaseAudioContext`](#BaseAudioContext) for this
[`DynamicsCompressorNode`](#DynamicsCompressorNode), and a new class, [EnvelopeFollower], that instantiates a
special object that behaves like an
[`AudioNode`](#AudioNode),
described below:

 const delay = new DelayNode(context, {delayTime: 0.006});
 const gain = new GainNode(context);
 const compression = new EnvelopeFollower();

 input.connect(delay).connect(gain).connect(output);
 input.connect(compression).connect(gain.gain);

![The graph of internal
[`AudioNode`](#AudioNode)s
used as part of the
[`DynamicsCompressorNode`](#DynamicsCompressorNode) processing
algorithm.](images/dynamicscompressor-internal-graph.svg){a}

 This implements the pre-delay and the application of
the reduction gain.

The following algorithm describes the processing performed by an
[EnvelopeFollower](#envelopefollower) object, to be applied to the input signal to produce
the gain reduction value. An
[EnvelopeFollower](#envelopefollower) has two slots holding floating point values. Those
values persist accros invocation of this algorithm.

- Let
 [`[[detector average]]`] be a floating point number,
 initialized to 0.0.

- Let
 [`[[compressor gain]]`] be a floating point number,
 initialized to 1.0.

The following algorithm allow determining a value for
`reduction gain`, for each sample of input, for a render
quantum of audio.

1. Let `attack` and `release` have the values of
 [`attack`](#dom-dynamicscompressornode-attack) and
 [`release`](#dom-dynamicscompressornode-release), respectively, sampled at the time of processing
 (those are [k-rate](#k-rate)
 parameters), mutiplied by the sample-rate of the
 [`BaseAudioContext`](#BaseAudioContext) this
 [`DynamicsCompressorNode`](#DynamicsCompressorNode) is [associated](#associated)
 with.

2. Let `detector average` be the value of the slot
 [`[[detector average]]`](#dom-dynamicscompressornode-detector-average-slot).

3. Let `compressor gain` be the value of the slot
 [`[[compressor gain]]`](#dom-dynamicscompressornode-compressor-gain-slot).

4. For each sample `input` of the render quantum to be
 processed, execute the following steps:

 1. If the absolute value of `input` is less than 0.0001,
 let `attenuation` be 1.0. Else, let
 `shaped input` be the value of applying the
 [compression
 curve](#compression-curve) to the
 absolute value of `input`. Let
 `attenuation` be `shaped input` divided by
 the absolute value of `input`.

 2. Let `releasing` be `true` if `attenuation`
 is greater than `compressor gain`, `false` otherwise.

 3. Let `detector rate` be the result of applying the
 [detector curve](#detector-curve) to
 `attenuation`.

 4. Subtract `detector average` from
 `attenuation`, and multiply the result by
 `detector rate`. Add this new result to
 `detector average`.

 5. Clamp `detector average` to a maximum of 1.0.

 6. Let `envelope rate` be the result of [computing the
 envelope
 rate](#computing-the-envelope-rate) based on values of `attack` and
 `release`.

 7. If `releasing` is `true`, set
 `compressor gain` to be the product of
 `compressor gain` and `envelope rate`,
 clamped to a maximum of 1.0.

 8. Else, if `releasing` is `false`, let
 `gain increment` to be `detector average`
 minus `compressor gain`. Multiply
 `gain increment` by `envelope rate`, and
 add the result to `compressor gain`.

 9. Compute `reduction gain` to be
 `compressor gain` multiplied by the return value of
 [computing the makeup
 gain](#computing-the-makeup-gain).

 10. Compute `metering gain` to be
 `reduction gain`, [converted to
 decibel](#linear-to-decibel).

5. Set
 [`[[compressor gain]]`](#dom-dynamicscompressornode-compressor-gain-slot) to `compressor gain`.

6. Set
 [`[[detector average]]`](#dom-dynamicscompressornode-detector-average-slot) to `detector average`.

7. [Atomically](#atomically) set
 the internal slot
 [`[[internal reduction]]`](#dom-dynamicscompressornode-internal-reduction-slot) to the value of `metering gain`.

 This step makes the metering gain update once per
 block, at the end of the block processing.

The makeup gain is a fixed gain stage that only depends on ratio, knee
and threshold parameter of the compressor, and not on the input signal.
The intent here is to increase the output level of the compressor so it
is comparable to the input level.

[Computing the makeup gain] means executing the following steps:

1. Let `full range gain` be the value returned by applying
 the [compression
 curve](#compression-curve) to the value 1.0.

2. Let `full range makeup gain` be the inverse of
 `full range gain`.

3. Return the result of taking the 0.6 power of
 `full range makeup gain`.

[Computing the envelope rate] is done by applying a function
to the ratio of the `compressor gain` and the
`detector average`. User-agents are allowed to choose the
shape of the envelope function. However, this function MUST respect the
following constraints:

- The envelope rate MUST be the calculated from the ratio of the
 `compressor gain` and the `detector average`.

 When attacking, this number less than or equal to 1,
 when releasing, this number is strictly greater than 1.

- The attack curve MUST be a continuous, monotonically increasing
 function in the range \\(\[0, 1\]\\). The shape of this curve MAY be
 controlled by
 [`attack`](#dom-dynamicscompressornode-attack).

- The release curve MUST be a continuous, monotonically decreasing
 function that is always greater than 1. The shape of this curve MAY be
 controlled by
 [`release`](#dom-dynamicscompressornode-release).

This operation returns the value computed by applying this function to
the ratio of `compressor gain` and
`detector average`.

Applying the [detector curve] to the change rate when attacking or
releasing allow implementing *adaptive release*. It is a function that
MUST respect the following constraints:

- The output of the function MUST be in \\(\[0,1\]\\).

- The function MUST be monotonically increasing, continuous.

 It is allowed, for example, to have a compressor that
performs an *adaptive release*, that is, releasing faster the harder the
compression, or to have curves for attack and release that are not of
the same shape.

Applying a [compression curve] to a value means computing the value of this
sample when passed to a function, and returning the computed value. This
function MUST respect the following characteristics:

1. Let `threshold` and `knee` have the values of
 [`threshold`](#dom-dynamicscompressornode-threshold) and
 [`knee`](#dom-dynamicscompressornode-knee), respectively, [converted to linear
 units](#decibels-to-linear-gain-unit) and sampled at the time of processing of this block
 (as [k-rate](#k-rate) parameters).

2. Calculate the sum of
 [`threshold`](#dom-dynamicscompressornode-threshold) plus
 [`knee`](#dom-dynamicscompressornode-knee) also sampled at the time of processing of this
 block (as [k-rate](#k-rate)
 parameters).

3. Let `knee end threshold` have the value of this sum
 [converted to linear
 units](#decibels-to-linear-gain-unit).

4. Let `ratio` have the value of the
 [`ratio`](#dom-dynamicscompressornode-ratio), sampled at the time of processing of this block
 (as a [k-rate](#k-rate)
 parameter).

5. This function is the identity up to the value of the linear
 `threshold` (i.e., \\(f(x) = x\\)).

6. From the `threshold` up to the
 `knee end threshold`, User-Agents can choose the curve
 shape. The whole function MUST be monotonically increasing and
 continuous.

 If the `knee` is 0, the
 [`DynamicsCompressorNode`](#DynamicsCompressorNode) is called a hard-knee compressor.

7. This function is linear, based on the `ratio`, after the
 `threshold` and the soft knee (i.e., \\(f(x) =
 \\frac{1}{ratio} \\cdot x \\)).

Converting a value \\(v\\) in [linear gain unit to
decibel] means executing the
following steps:

1. If \\(v\\) is equal to zero, return -1000.

2. Else, return \\( 20 \\, \\log\_{10}{v} \\).

Converting a value \\(v\\) in [decibels to linear gain
unit] means returning
\\(10\^{v/20}\\).

### 1.20. The [`GainNode` Interface]
Changing the gain of an audio signal is a fundamental operation in audio
applications. This interface is an
[`AudioNode`](#AudioNode)
with a single input and single output:

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

2

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`max`\"

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

No

Each sample of each channel of the input data of the
[`GainNode`](#GainNode) MUST
be multiplied by the
[computedValue](#computedvalue)
of the [`gain`](#dom-gainnode-gain)
[`AudioParam`](#AudioParam).

```
[Exposed=Window]
interface GainNode : AudioNode {
 constructor (BaseAudioContext context, optional GainOptions options = );
 readonly attribute AudioParam gain;
};
```

#### 1.20.1. Constructors

[`GainNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `c` and an option object
 `option`, the user agent MUST [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [GainNode.constructor()](#dom-gainnode-gainnode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`GainNode`](#GainNode)
 will be [associated](#associated) with.

 [`options`]

 [`GainOptions`](#GainOptions)

 [✘]

 [✔]

 Optional initial parameter values for this
 [`GainNode`](#GainNode).

#### 1.20.2. Attributes

[`gain`], of type [AudioParam](#AudioParam), readonly

: Represents the amount of gain to apply.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 1
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

#### 1.20.3. [`GainOptions`]
This specifies options to use in constructing a
[`GainNode`](#GainNode). All
members are optional; if not specified, the normal defaults are used in
constructing the node.

```
dictionary GainOptions : AudioNodeOptions {
 float gain = 1.0;
};
```

##### 1.20.3.1. Dictionary [`GainOptions` Members]
[`gain`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `1.0`

: The initial gain value for the
 [`gain`](#dom-gainnode-gain) AudioParam.

### 1.21. The [`IIRFilterNode` Interface]
[`IIRFilterNode`](#IIRFilterNode) is an
[`AudioNode`](#AudioNode)
processor implementing a general [IIR
Filter](https://en.wikipedia.org/wiki/Infinite_impulse_response). In
general, it is best to use
[`BiquadFilterNode`](#BiquadFilterNode)'s to implement higher-order filters for the following
reasons:

- Generally less sensitive to numeric issues

- Filter parameters can be automated

- Can be used to create all even-ordered IIR filters

However, odd-ordered filters cannot be created, so if such filters are
needed or automation is not needed, then IIR filters may be appropriate.

Once created, the coefficients of the IIR filter cannot be changed.

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

2

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`max`\"

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

Yes

Continues to output non-silent audio with zero input. Since this is an
IIR filter, the filter produces non-zero input forever, but in practice,
this can be limited after some finite time where the output is
sufficiently close to zero. The actual time depends on the filter
coefficients.

The number of channels of the output always equals the number of
channels of the input.

```
[Exposed=Window]
interface IIRFilterNode : AudioNode {
 constructor (BaseAudioContext context, IIRFilterOptions options);
 undefined getFrequencyResponse (Float32Array frequencyHz,
 Float32Array magResponse,
 Float32Array phaseResponse);
};
```

#### 1.21.1. Constructors

[`IIRFilterNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `c` and an option object
 `option`, the user agent MUST [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [IIRFilterNode.constructor()](#dom-iirfilternode-iirfilternode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`IIRFilterNode`](#IIRFilterNode) will be
 [associated](#associated) with.

 [`options`]

 [`IIRFilterOptions`](#IIRFilterOptions)

 [✘]

 [✘]

 Initial parameter value for this
 [`IIRFilterNode`](#IIRFilterNode).

#### 1.21.2. Methods

[`getFrequencyResponse(frequencyHz, magResponse, phaseResponse)`]

: [Given the current filter parameter settings, synchronously
 calculates the frequency response for the specified frequencies. The
 three parameters MUST be
 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)s of the same length, or an
 [`InvalidAccessError`](https://webidl.spec.whatwg.org/#invalidaccesserror) MUST be thrown.]

 Arguments for the
 [IIRFilterNode.getFrequencyResponse()](#dom-iirfilternode-getfrequencyresponse) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`frequencyHz`]

 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)

 [✘]

 [✘]

 This parameter specifies an array of frequencies, in Hz, at which
 the response values will be calculated.

 [`magResponse`]

 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)

 [✘]

 [✘]

 This parameter specifies an output array receiving the linear
 magnitude response values. If a value in the `frequencyHz` parameter
 is not within \[0, sampleRate/2\], where `sampleRate` is the value
 of the
 [`sampleRate`](#dom-baseaudiocontext-samplerate) property of the
 [`AudioContext`](#AudioContext), the corresponding value at the same index of the
 `magResponse` array MUST be `NaN`.

 [`phaseResponse`]

 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)

 [✘]

 [✘]

 This parameter specifies an output array receiving the phase
 response values in radians. If a value in the `frequencyHz`
 parameter is not within \[0; sampleRate/2\], where `sampleRate` is
 the value of the
 [`sampleRate`](#dom-baseaudiocontext-samplerate) property of the
 [`AudioContext`](#AudioContext), the corresponding value at the same index of the
 `phaseResponse` array MUST be `NaN`.

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

#### 1.21.3. [`IIRFilterOptions`]
The `IIRFilterOptions` dictionary is used to specify the filter
coefficients of the
[`IIRFilterNode`](#IIRFilterNode).

```
dictionary IIRFilterOptions : AudioNodeOptions {
 required sequence<double> feedforward;
 required sequence<double> feedback;
};
```

##### 1.21.3.1. Dictionary [`IIRFilterOptions` Members]
[`feedforward`], of type sequence\<[double](https://webidl.spec.whatwg.org/#idl-double)\>

: The feedforward coefficients for the
 [`IIRFilterNode`](#IIRFilterNode). This member is required. See
 [`feedforward`](#dom-baseaudiocontext-createiirfilter-feedforward) argument of
 [`createIIRFilter()`](#dom-baseaudiocontext-createiirfilter) for other constraints.

[`feedback`], of type sequence\<[double](https://webidl.spec.whatwg.org/#idl-double)\>

: The feedback coefficients for the
 [`IIRFilterNode`](#IIRFilterNode). This member is required. See
 [`feedback`](#dom-baseaudiocontext-createiirfilter-feedback) argument of
 [`createIIRFilter()`](#dom-baseaudiocontext-createiirfilter) for other constraints.

#### 1.21.4. Filter Definition

Let \\(b_m\\) be the `feedforward` coefficients and \\(a_n\\) be the
`feedback` coefficients specified by
[`createIIRFilter()`](#dom-baseaudiocontext-createiirfilter) or the
[`IIRFilterOptions`](#IIRFilterOptions) dictionary for the
[`constructor`](#dom-iirfilternode-iirfilternode). Then the transfer function of the general IIR filter
is given by

 $$
 H(z) = \frac{\sum_{m=0}^{M} b_m z^{-m}}{\sum_{n=0}^{N} a_n z^{-n}}
 $$

where \\(M + 1\\) is the length of the \\(b\\) array and \\(N + 1\\) is
the length of the \\(a\\) array. The coefficient \\(a_0\\) MUST not be 0
(see
[`feedback parameter`](#dom-baseaudiocontext-createiirfilter-feedback) for
[`createIIRFilter()`](#dom-baseaudiocontext-createiirfilter)). At least one of \\(b_m\\) MUST be non-zero (see
[`feedforward parameter`](#dom-baseaudiocontext-createiirfilter-feedforward) for
[`createIIRFilter()`](#dom-baseaudiocontext-createiirfilter)).

Equivalently, the time-domain equation is:

 $$
 \sum_{k=0}^{N} a_k y(n-k) = \sum_{k=0}^{M} b_k x(n-k)
 $$

The initial filter state is the all-zeroes state.

 The UA may produce a warning to notify the user that
NaN values have occurred in the filter state. This is usually indicative
of an unstable filter.

### 1.22. The [`MediaElementAudioSourceNode` Interface]
This interface represents an audio source from an
[`audio`](https://html.spec.whatwg.org/multipage/media.html#audio) or
[`video`](https://html.spec.whatwg.org/multipage/media.html#video) element.

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

0

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[tail-time](#tail-time) reference

No

The number of channels of the output corresponds to the number of
channels of the media referenced by the
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement). Thus, changes to the media element's `src` attribute
can change the number of channels output by this node.

If the sample rate of the
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) differs from the sample rate of the associated
[`AudioContext`](#AudioContext), then the output from the
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) must be resampled to match the context's
[`sample rate`](#dom-baseaudiocontext-samplerate).

A
[`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode) is created given an
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) using the
[`AudioContext`](#AudioContext)
[`createMediaElementSource()`](#dom-audiocontext-createmediaelementsource) method or the
[`mediaElement`](#dom-mediaelementaudiosourceoptions-mediaelement) member of the
[`MediaElementAudioSourceOptions`](#MediaElementAudioSourceOptions) dictionary for the
[`constructor`](#dom-mediaelementaudiosourcenode-mediaelementaudiosourcenode).

The number of channels of the single output equals the number of
channels of the audio referenced by the
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) passed in as the argument to
[`createMediaElementSource()`](#dom-audiocontext-createmediaelementsource), or is 1 if the
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) has no audio.

The
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) MUST behave in an identical fashion after the
[`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode) has been created, *except* that the rendered audio will
no longer be heard directly, but instead will be heard as a consequence
of the
[`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode) being connected through the routing graph. Thus
pausing, seeking, volume, `src` attribute changes, and other aspects of
the
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) MUST behave as they normally would if *not* used with a
[`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode).

```
const mediaElement = document.getElementById('mediaElementID');
const sourceNode = context.createMediaElementSource(mediaElement);
sourceNode.connect(filterNode);
```

```
[Exposed=Window]
interface MediaElementAudioSourceNode : AudioNode {
 constructor (AudioContext context, MediaElementAudioSourceOptions options);
 [SameObject] readonly attribute HTMLMediaElement mediaElement;
};
```

#### 1.22.1. Constructors

[`MediaElementAudioSourceNode(context, options)`]

: 1. [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [MediaElementAudioSourceNode.constructor()](#dom-mediaelementaudiosourcenode-mediaelementaudiosourcenode) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`context`]
 [`AudioContext`](#AudioContext)
 [✘]
 [✘]
 The [`AudioContext`](#AudioContext) this new
 [`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode) will be
 [associated](#associated) with.
 [`options`]
 [`MediaElementAudioSourceOptions`](#MediaElementAudioSourceOptions)
 [✘]
 [✘]
 Initial parameter value for this
 [`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode).

#### 1.22.2. Attributes

[`mediaElement`], of type [HTMLMediaElement](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement), readonly

: The
 [`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) used when constructing this
 [`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode).

#### 1.22.3. [`MediaElementAudioSourceOptions`]
This specifies the options to use in constructing a
[`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode).

```
dictionary MediaElementAudioSourceOptions {
 required HTMLMediaElement mediaElement;
};
```

##### 1.22.3.1. Dictionary [`MediaElementAudioSourceOptions` Members]
[`mediaElement`], of type [HTMLMediaElement](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement)

: The media element that will be re-routed. This MUST be specified.

#### 1.22.4. Security with MediaElementAudioSourceNode and Cross-Origin Resources

[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) allows the playback of cross-origin resources. Because
Web Audio allows inspection of the content of the resource (e.g. using a
[`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode), and an
[`AudioWorkletNode`](#AudioWorkletNode) or
[`ScriptProcessorNode`](#ScriptProcessorNode) to read the samples), information leakage can occur if
scripts from one
[origin](https://html.spec.whatwg.org/multipage/browsers.html#origin)
inspect the content of a resource from another
[origin](https://html.spec.whatwg.org/multipage/browsers.html#origin).

To prevent this, a
[`MediaElementAudioSourceNode`](#MediaElementAudioSourceNode) MUST output *silence* instead of the normal output of
the
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) if it has been created using an
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement) for which the execution of the [fetch
algorithm](https://fetch.spec.whatwg.org/#fetching)
[\[FETCH\]](#biblio-fetch "Fetch Standard") labeled
the resource as
[CORS-cross-origin](https://html.spec.whatwg.org/#cors-cross-origin).

### 1.23. The [`MediaStreamAudioDestinationNode` Interface]
This interface is an audio destination representing a
[`MediaStream`](https://w3c.github.io/mediacapture-main/#dom-mediastream) with a single
[`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack) whose `kind` is `"audio"`. This
[`MediaStream`](https://w3c.github.io/mediacapture-main/#dom-mediastream) is created when the node is created and is accessible
via the
[`stream`](#dom-mediastreamaudiodestinationnode-stream) attribute. This stream can be used in a similar way as
a
[`MediaStream`](https://w3c.github.io/mediacapture-main/#dom-mediastream) obtained via
[`getUserMedia()`](https://www.w3.org/TR/mediacapture-streams/#dom-mediadevices-getusermedia), and can, for example, be sent to a remote peer using
the `RTCPeerConnection` (described in
[\[webrtc\]](#biblio-webrtc "WebRTC: Real-Time Communication in Browsers"))
`addStream()` method.

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

0

[`channelCount`](#dom-audionode-channelcount)

2

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`explicit`\"

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

No

The number of channels of the input is by default 2 (stereo).

```
[Exposed=Window]
interface MediaStreamAudioDestinationNode : AudioNode {
 constructor (AudioContext context, optional AudioNodeOptions options = );
 readonly attribute MediaStream stream;
};
```

#### 1.23.1. Constructors

[`MediaStreamAudioDestinationNode(context, options)`]

: 1. [Initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [MediaStreamAudioDestinationNode.constructor()](#dom-mediastreamaudiodestinationnode-mediastreamaudiodestinationnode) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`context`]
 [`AudioContext`](#AudioContext)
 [✘]
 [✘]
 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`MediaStreamAudioDestinationNode`](#MediaStreamAudioDestinationNode) will be
 [associated](#associated) with.
 [`options`]
 [`AudioNodeOptions`](#AudioNodeOptions)
 [✘]
 [✔]
 Optional initial parameter value for this
 [`MediaStreamAudioDestinationNode`](#MediaStreamAudioDestinationNode).

#### 1.23.2. Attributes

[`stream`], of type [MediaStream](https://w3c.github.io/mediacapture-main/#dom-mediastream), readonly

: A
 [`MediaStream`](https://w3c.github.io/mediacapture-main/#dom-mediastream) containing a single
 [`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack) with the same number of channels as the node
 itself, and whose `kind` attribute has the value `"audio"`.

### 1.24. The [`MediaStreamAudioSourceNode` Interface]
This interface represents an audio source from a
[`MediaStream`](https://w3c.github.io/mediacapture-main/#dom-mediastream).

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

0

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[tail-time](#tail-time) reference

No

The number of channels of the output corresponds to the number of
channels of the
[`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack). When the
[`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack) ends, this
[`AudioNode`](#AudioNode)
outputs one channel of silence.

If the sample rate of the
[`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack) differs from the sample rate of the associated
[`AudioContext`](#AudioContext), then the output of the
[`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack) is resampled to match the context's
[`sample rate`](#dom-baseaudiocontext-samplerate).

```
[Exposed=Window]
interface MediaStreamAudioSourceNode : AudioNode {
 constructor (AudioContext context, MediaStreamAudioSourceOptions options);
 [SameObject] readonly attribute MediaStream mediaStream;
};
```

#### 1.24.1. Constructors

[`MediaStreamAudioSourceNode(context, options)`]

: 1. If the
 [`mediaStream`](#dom-mediastreamaudiosourceoptions-mediastream) member of
 [`options`](#dom-mediastreamaudiosourcenode-mediastreamaudiosourcenode-context-options-options) does not reference a
 [`MediaStream`](https://w3c.github.io/mediacapture-main/#dom-mediastream) that has at least one
 [`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack) whose `kind` attribute has the value `"audio"`,
 throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) and abort these steps. Else, let this stream be
 `inputStream`.

 2. Let `tracks` be the list of all
 [`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack)s of `inputStream` that have a `kind`
 of `"audio"`.

 3. Sort the elements in `tracks` based on their `id`
 attribute using an ordering on sequences of [code
 unit](https://infra.spec.whatwg.org/#code-unit) values.

 4. [Initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 5. Set an internal slot
 [`[[input track]]`] on this
 [`MediaStreamAudioSourceNode`](#MediaStreamAudioSourceNode) to be the first element of `tracks`.
 This is the track used as the input audio for this
 [`MediaStreamAudioSourceNode`](#MediaStreamAudioSourceNode).

 After construction, any change to the
 [`MediaStream`](https://w3c.github.io/mediacapture-main/#dom-mediastream) that was passed to the constructor do not affect
 the underlying output of this
 [`AudioNode`](#AudioNode).

 The slot
 [`[[input track]]`](#dom-mediastreamaudiosourcenode-input-track-slot) is only used to keep a reference to the
 [`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack).

 This means that when removing the track chosen by
 the constructor of the
 [`MediaStreamAudioSourceNode`](#MediaStreamAudioSourceNode) from the
 [`MediaStream`](https://w3c.github.io/mediacapture-main/#dom-mediastream) passed into this constructor, the
 [`MediaStreamAudioSourceNode`](#MediaStreamAudioSourceNode) will still take its input from the same track.

 The behaviour for picking the track to output is
 arbitrary for legacy reasons.
 [`MediaStreamTrackAudioSourceNode`](#MediaStreamTrackAudioSourceNode) can be used instead to be explicit about which
 track to use as input.

 Arguments for the
 [MediaStreamAudioSourceNode.constructor()](#dom-mediastreamaudiosourcenode-mediastreamaudiosourcenode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`AudioContext`](#AudioContext)

 [✘]

 [✘]

 The [`AudioContext`](#AudioContext) this new
 [`MediaStreamAudioSourceNode`](#MediaStreamAudioSourceNode) will be
 [associated](#associated) with.

 [`options`]

 [`MediaStreamAudioSourceOptions`](#MediaStreamAudioSourceOptions)

 [✘]

 [✘]

 Initial parameter value for this
 [`MediaStreamAudioSourceNode`](#MediaStreamAudioSourceNode).

#### 1.24.2. Attributes

[`mediaStream`], of type [MediaStream](https://w3c.github.io/mediacapture-main/#dom-mediastream), readonly

: The
 [`MediaStream`](https://w3c.github.io/mediacapture-main/#dom-mediastream) used when constructing this
 [`MediaStreamAudioSourceNode`](#MediaStreamAudioSourceNode).

#### 1.24.3. [`MediaStreamAudioSourceOptions`]
This specifies the options for constructing a
[`MediaStreamAudioSourceNode`](#MediaStreamAudioSourceNode).

```
dictionary MediaStreamAudioSourceOptions {
 required MediaStream mediaStream;
};
```

##### 1.24.3.1. Dictionary [`MediaStreamAudioSourceOptions` Members]
[`mediaStream`], of type [MediaStream](https://w3c.github.io/mediacapture-main/#dom-mediastream)

: The media stream that will act as a source. This MUST be specified.

### 1.25. The [`MediaStreamTrackAudioSourceNode` Interface]
This interface represents an audio source from a
[`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack).

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

0

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[tail-time](#tail-time) reference

No

The number of channels of the output corresponds to the number of
channels of the
[`mediaStreamTrack`](#dom-mediastreamtrackaudiosourceoptions-mediastreamtrack).

If the sample rate of the
[`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack) differs from the sample rate of the associated
[`AudioContext`](#AudioContext), then the output of the
[`mediaStreamTrack`](#dom-mediastreamtrackaudiosourceoptions-mediastreamtrack) is resampled to match the context's
[`sample rate`](#dom-baseaudiocontext-samplerate).

```
[Exposed=Window]
interface MediaStreamTrackAudioSourceNode : AudioNode {
 constructor (AudioContext context, MediaStreamTrackAudioSourceOptions options);
};
```

#### 1.25.1. Constructors

[`MediaStreamTrackAudioSourceNode(context, options)`]

: 1. If the
 [`mediaStreamTrack`](#dom-mediastreamtrackaudiosourceoptions-mediastreamtrack)'s `kind` attribute is not `"audio"`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) and abort these steps.

 2. [Initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [MediaStreamTrackAudioSourceNode.constructor()](#dom-mediastreamtrackaudiosourcenode-mediastreamtrackaudiosourcenode) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`context`]
 [`AudioContext`](#AudioContext)
 [✘]
 [✘]
 The [`AudioContext`](#AudioContext) this new
 [`MediaStreamTrackAudioSourceNode`](#MediaStreamTrackAudioSourceNode) will be
 [associated](#associated) with.
 [`options`]
 [`MediaStreamTrackAudioSourceOptions`](#MediaStreamTrackAudioSourceOptions)
 [✘]
 [✘]
 Initial parameter value for this
 [`MediaStreamTrackAudioSourceNode`](#MediaStreamTrackAudioSourceNode).

#### 1.25.2. [`MediaStreamTrackAudioSourceOptions`]
This specifies the options for constructing a
[`MediaStreamTrackAudioSourceNode`](#MediaStreamTrackAudioSourceNode). This is required.

```
dictionary MediaStreamTrackAudioSourceOptions {
 required MediaStreamTrack mediaStreamTrack;
};
```

##### 1.25.2.1. Dictionary [`MediaStreamTrackAudioSourceOptions` Members]
[`mediaStreamTrack`], of type [MediaStreamTrack](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack)

: The media stream track that will act as a source. [If this
 [`MediaStreamTrack`](https://w3c.github.io/mediacapture-main/#dom-mediastreamtrack) `kind` attribute is not `"audio"`, an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) MUST be thrown.]

### 1.26. The [`OscillatorNode` Interface]
[`OscillatorNode`](#OscillatorNode) represents an audio source generating a periodic
waveform. It can be set to a few commonly used waveforms. Additionally,
it can be set to an arbitrary periodic waveform through the use of a
[`PeriodicWave`](#PeriodicWave) object.

Oscillators are common foundational building blocks in audio synthesis.
An OscillatorNode will start emitting sound at the time specified by the
[`start()`](#dom-audioscheduledsourcenode-start) method.

Mathematically speaking, a *continuous-time* periodic waveform can have
very high (or infinitely high) frequency information when considered in
the frequency domain. When this waveform is sampled as a discrete-time
digital audio signal at a particular sample-rate, then care MUST be
taken to discard (filter out) the high-frequency information higher than
the [Nyquist
frequency](#--nyquist-frequency) before converting the waveform to a digital form. If
this is not done, then
[*aliasing*](https://en.wikipedia.org/wiki/Aliasing) of higher
frequencies (than the [Nyquist
frequency](#--nyquist-frequency)) will fold back as mirror images into frequencies lower
than the [Nyquist
frequency](#--nyquist-frequency). In many cases this will cause audibly objectionable
artifacts. This is a basic and well-understood principle of audio DSP.

There are several practical approaches that an implementation may take
to avoid this aliasing. Regardless of approach, the *idealized*
discrete-time digital audio signal is well defined mathematically. The
trade-off for the implementation is a matter of implementation cost (in
terms of CPU usage) versus fidelity to achieving this ideal.

It is expected that an implementation will take some care in achieving
this ideal, but it is reasonable to consider lower-quality, less-costly
approaches on lower-end hardware.

Both
[`frequency`](#dom-oscillatornode-frequency) and
[`detune`](#dom-oscillatornode-detune) are [a-rate](#a-rate)
parameters, and form a [compound
parameter](#compound-parameter). They are used together to determine a
[computedOscFrequency] value:

 computedOscFrequency(t) = frequency(t) * pow(2, detune(t) / 1200)

The OscillatorNode's instantaneous phase at each time is the definite
time integral of
[computedOscFrequency](#computedoscfrequency), assuming a phase angle of zero at the node's exact
start time. Its [nominal range](#nominal-range) is \[-[Nyquist
frequency](#--nyquist-frequency), [Nyquist
frequency](#--nyquist-frequency)\].

The single output of this node consists of one channel (mono).

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

0

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

2

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`max`\"

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

No

```
enum OscillatorType {
 "sine",
 "square",
 "sawtooth",
 "triangle",
 "custom"
};
```

::: enum-description
[`OscillatorType`](#enumdef-oscillatortype) enumeration description

Enum value

Description

\"[`sine`]\"

A sine wave

\"[`square`]\"

A square wave of duty period 0.5

\"[`sawtooth`]\"

A sawtooth wave

\"[`triangle`]\"

A triangle wave

\"[`custom`]\"

A custom periodic wave

```
[Exposed=Window]
interface OscillatorNode : AudioScheduledSourceNode {
 constructor (BaseAudioContext context, optional OscillatorOptions options = );
 attribute OscillatorType type;
 readonly attribute AudioParam frequency;
 readonly attribute AudioParam detune;
 undefined setPeriodicWave (PeriodicWave periodicWave);
};
```

#### 1.26.1. Constructors

[`OscillatorNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `c` and an option object
 `option`, the user agent MUST [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [OscillatorNode.constructor()](#dom-oscillatornode-oscillatornode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`OscillatorNode`](#OscillatorNode) will be
 [associated](#associated) with.

 [`options`]

 [`OscillatorOptions`](#OscillatorOptions)

 [✘]

 [✔]

 Optional initial parameter value for this
 [`OscillatorNode`](#OscillatorNode).

#### 1.26.2. Attributes

[`detune`], of type [AudioParam](#AudioParam), readonly

: A detuning value (in
 [cents](https://en.wikipedia.org/wiki/Cent_(music))) which will
 offset the
 [`frequency`](#dom-oscillatornode-frequency) by the given amount. Its default `value` is 0. This
 parameter is [a-rate](#a-rate). It
 forms a [compound
 parameter](#compound-parameter) with
 [`frequency`](#dom-oscillatornode-frequency) to form the
 [computedOscFrequency](#computedoscfrequency). The nominal range listed below allows this
 parameter to detune the
 [`frequency`](#dom-oscillatornode-frequency) over the entire possible range of frequencies.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 \\(\\approx -153600\\)
 [`maxValue`](#dom-audioparam-maxvalue)
 \\(\\approx 153600\\)
 This value is approximately \\(1200\\ \\log_2
 \\mathrm{FLT\\\_MAX}\\) where FLT_MAX is the largest
 [`float`](https://webidl.spec.whatwg.org/#idl-float) value.
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

[`frequency`], of type [AudioParam](#AudioParam), readonly

: The frequency (in Hertz) of the periodic waveform. Its default
 `value` is 440. This parameter is [a-rate](#a-rate). It forms a [compound
 parameter](#compound-parameter) with
 [`detune`](#dom-oscillatornode-detune) to form the
 [computedOscFrequency](#computedoscfrequency). Its [nominal
 range](#nominal-range) is
 \[-[Nyquist
 frequency](#--nyquist-frequency), [Nyquist
 frequency](#--nyquist-frequency)\].

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 440
 [`minValue`](#dom-audioparam-minvalue)
 \-[Nyquist
 frequency](#--nyquist-frequency)
 [`maxValue`](#dom-audioparam-maxvalue)
 [Nyquist
 frequency](#--nyquist-frequency)
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

[`type`], of type [OscillatorType](#enumdef-oscillatortype)

: The shape of the periodic waveform. It may directly be set to any of
 the type constant values except for
 \"[`custom`](#dom-oscillatortype-custom)\". [Doing so MUST throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception.] The
 [`setPeriodicWave()`](#dom-oscillatornode-setperiodicwave) method can be used to set a custom waveform, which
 results in this attribute being set to
 \"[`custom`](#dom-oscillatortype-custom)\". The default value is
 \"[`sine`](#dom-oscillatortype-sine)\". When this attribute is set, the phase of the
 oscillator MUST be conserved.

#### 1.26.3. Methods

[`setPeriodicWave(periodicWave)`]

: Sets an arbitrary custom periodic waveform given a
 [`PeriodicWave`](#PeriodicWave).

 Arguments for the
 [OscillatorNode.setPeriodicWave()](#dom-oscillatornode-setperiodicwave) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`periodicWave`]

 [`PeriodicWave`](#PeriodicWave)

 [✘]

 [✘]

 custom waveform to be used by the oscillator

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

#### 1.26.4. [`OscillatorOptions`]
This specifies the options to be used when constructing an
[`OscillatorNode`](#OscillatorNode). All of the members are optional; if not specified, the
normal default values are used for constructing the oscillator.

```
dictionary OscillatorOptions : AudioNodeOptions {
 OscillatorType type = "sine";
 float frequency = 440;
 float detune = 0;
 PeriodicWave periodicWave;
};
```

##### 1.26.4.1. Dictionary [`OscillatorOptions` Members]
[`detune`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0`

: The initial detune value for the
 [`OscillatorNode`](#OscillatorNode).

[`frequency`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `440`

: The initial frequency for the
 [`OscillatorNode`](#OscillatorNode).

[`periodicWave`], of type [PeriodicWave](#PeriodicWave)

: The [`PeriodicWave`](#PeriodicWave) for the
 [`OscillatorNode`](#OscillatorNode). If this is specified, then any valid value for
 [`type`](#dom-oscillatoroptions-type) is ignored; it is treated as if
 \"[`custom`](#dom-oscillatortype-custom)\" were specified.

[`type`], of type [OscillatorType](#enumdef-oscillatortype), defaulting to `"sine"`

: The type of oscillator to be constructed. If this is set to
 \"custom\" without also specifying a
 [`periodicWave`](#dom-oscillatoroptions-periodicwave), then an
 [[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception MUST be thrown]. If
 [`periodicWave`](#dom-oscillatoroptions-periodicwave) is specified, then any valid value for
 [`type`](#dom-oscillatoroptions-type) is ignored; it is treated as if it were set to
 \"custom\".

#### 1.26.5. Basic Waveform Phase

The idealized mathematical waveforms for the various oscillator types
are defined below. In summary, all waveforms are defined mathematically
to be an odd function with a positive slope at time 0. The actual
waveforms produced by the oscillator may differ to prevent aliasing
affects.

The oscillator MUST produce the same result as if a
[`PeriodicWave`](#PeriodicWave), with the appropriate [Fourier
series](#oscillator-coefficients) and with
[`disableNormalization`](#dom-periodicwaveconstraints-disablenormalization) set to false, were used to create these basic
waveforms.

\"[`sine`](#dom-oscillatortype-sine)\"

: The waveform for sine oscillator is:

 $$
 x(t) = \sin t
 $$

\"[`square`](#dom-oscillatortype-square)\"

: The waveform for the square wave oscillator is:

 $$
 x(t) = \begin{cases}
 1 & \mbox{for } 0≤ t < \pi \\
 -1 & \mbox{for } -\pi < t < 0.
 \end{cases}
 $$

 This is extended to all \\(t\\) by using the fact that the waveform
 is an odd function with period \\(2\\pi\\).

\"[`sawtooth`](#dom-oscillatortype-sawtooth)\"

: The waveform for the sawtooth oscillator is the ramp:

 $$
 x(t) = \frac{t}{\pi} \mbox{ for } -\pi < t ≤ \pi;
 $$

 This is extended to all \\(t\\) by using the fact that the waveform
 is an odd function with period \\(2\\pi\\).

\"[`triangle`](#dom-oscillatortype-triangle)\"

: The waveform for the triangle oscillator is:

 $$
 x(t) = \begin{cases}
 \frac{2}{\pi} t & \mbox{for } 0 ≤ t ≤ \frac{\pi}{2} \\
 1-\frac{2}{\pi} \left(t-\frac{\pi}{2}\right) & \mbox{for }
 \frac{\pi}{2} < t ≤ \pi.
 \end{cases}
 $$

 This is extended to all \\(t\\) by using the fact that the waveform
 is an odd function with period \\(2\\pi\\).

### 1.27. The [`PannerNode` Interface]
This interface represents a processing node which [positions /
spatializes](#Spatialization) an incoming audio stream in
three-dimensional space. The spatialization is in relation to the
[`BaseAudioContext`](#BaseAudioContext)'s
[`AudioListener`](#AudioListener)
([`listener`](#dom-baseaudiocontext-listener) attribute).

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

2

Has [channelCount
constraints](#audionode-channelcount-constraints)

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`clamped-max`\"

Has [channelCountMode
constraints](#audionode-channelcountmode-constraints)

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

Maybe

If the
[`panningModel`](#dom-pannernode-panningmodel) is set to
\"[`HRTF`](#dom-panningmodeltype-hrtf)\", the node will produce non-silent output for silent
input due to the inherent processing for head responses. Otherwise the
tail-time is zero.

The input of this node is either mono (1 channel) or stereo (2 channels)
and cannot be increased. Connections from nodes with fewer or more
channels will be [up-mixed or down-mixed
appropriately](#channel-up-mixing-and-down-mixing).

If the node is [actively
processing](#actively-processing), the output of this node is hard-coded to stereo (2
channels) and cannot be configured. If the node is not [actively
processing](#actively-processing), then the output is a single channel of silence.

The
[`PanningModelType`](#enumdef-panningmodeltype) enum determines which spatialization algorithm will be
used to position the audio in 3D space. The default is
\"[`equalpower`](#dom-panningmodeltype-equalpower)\".

```
enum PanningModelType {
 "equalpower",
 "HRTF"
};
```

::: enum-description
[`PanningModelType`](#enumdef-panningmodeltype) enumeration description

Enum value

Description

\"[`equalpower`]\"

A simple and efficient spatialization algorithm using equal-power
panning.

 When this panning model is used, all the
[`AudioParam`](#AudioParam)s used to compute the output of this node are
[a-rate](#a-rate).

\"[`HRTF`]\"

A higher quality spatialization algorithm using a convolution with
measured impulse responses from human subjects. This panning method
renders stereo output.

When this panning model is used, all the
[`AudioParam`](#AudioParam)s used to compute the output of this node are
[k-rate](#k-rate).

The [effective automation rate] for an
[`AudioParam`](#AudioParam) of a
[`PannerNode`](#PannerNode)
is determined by the
[`panningModel`](#dom-pannernode-panningmodel) and
[`automationRate`](#dom-audioparam-automationrate) of the
[`AudioParam`](#AudioParam). If the
[`panningModel`](#dom-pannernode-panningmodel) is
\"[`HRTF`](#dom-panningmodeltype-hrtf)\", the [effective automation
rate](#effective-automation-rate) is
\"[`k-rate`](#dom-automationrate-k-rate)\", independent of the setting of the
[`automationRate`](#dom-audioparam-automationrate). Otherwise the [effective automation
rate](#effective-automation-rate) is the value of
[`automationRate`](#dom-audioparam-automationrate).

The
[`DistanceModelType`](#enumdef-distancemodeltype) enum determines which algorithm will be used to reduce
the volume of an audio source as it moves away from the listener. The
default is
\"[`inverse`](#dom-distancemodeltype-inverse)\".

In the description of each distance model below, let \\(d\\) be the
distance between the listener and the panner; \\(d\_{ref}\\) be the
value of the
[`refDistance`](#dom-pannernode-refdistance) attribute; \\(d\_{max}\\) be the value of the
[`maxDistance`](#dom-pannernode-maxdistance) attribute; and \\(f\\) be the value of the
[`rolloffFactor`](#dom-pannernode-rollofffactor) attribute.

```
enum DistanceModelType {
 "linear",
 "inverse",
 "exponential"
};
```

::: enum-description
[`DistanceModelType`](#enumdef-distancemodeltype) enumeration description

Enum value

Description

\"[`linear`]\"

A linear distance model which calculates *distanceGain* according to:

 $$
 1 - f\ \frac{\max\left[\min\left(d, d'_{max}\right), d'_{ref}\right] - d'_{ref}}{d'_{max} - d'_{ref}}
 $$

where \\(d'\_{ref} = \\min\\left(d\_{ref}, d\_{max}\\right)\\) and
\\(d'\_{max} = \\max\\left(d\_{ref}, d\_{max}\\right)\\). In the case
where \\(d'\_{ref} = d'\_{max}\\), the value of the linear model is
taken to be \\(1-f\\).

Note that \\(d\\) is clamped to the interval \\(\\left\[d'\_{ref},\\,
d'\_{max}\\right\]\\).

\"[`inverse`]\"

An inverse distance model which calculates *distanceGain* according to:

 $$
 \frac{d_{ref}}{d_{ref} + f\ \left[\max\left(d, d_{ref}\right) - d_{ref}\right]}
 $$

That is, \\(d\\) is clamped to the interval \\(\\left\[d\_{ref},\\,
\\infty\\right)\\). If \\(d\_{ref} = 0\\), the value of the inverse
model is taken to be 0, independent of the value of \\(d\\) and \\(f\\).

\"[`exponential`]\"

An exponential distance model which calculates *distanceGain* according
to:

 $$
 \left[\frac{\max\left(d, d_{ref}\right)}{d_{ref}}\right]^{-f}
 $$

That is, \\(d\\) is clamped to the interval \\(\\left\[d\_{ref},\\,
\\infty\\right)\\). If \\(d\_{ref} = 0\\), the value of the exponential
model is taken to be 0, independent of \\(d\\) and \\(f\\).

```
[Exposed=Window]
interface PannerNode : AudioNode {
 constructor (BaseAudioContext context, optional PannerOptions options = );
 attribute PanningModelType panningModel;
 readonly attribute AudioParam positionX;
 readonly attribute AudioParam positionY;
 readonly attribute AudioParam positionZ;
 readonly attribute AudioParam orientationX;
 readonly attribute AudioParam orientationY;
 readonly attribute AudioParam orientationZ;
 attribute DistanceModelType distanceModel;
 attribute double refDistance;
 attribute double maxDistance;
 attribute double rolloffFactor;
 attribute double coneInnerAngle;
 attribute double coneOuterAngle;
 attribute double coneOuterGain;
 undefined setPosition (float x, float y, float z);
 undefined setOrientation (float x, float y, float z);
};
```

#### 1.27.1. Constructors

[`PannerNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `c` and an option object
 `option`, the user agent MUST [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [PannerNode.constructor()](#dom-pannernode-pannernode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`PannerNode`](#PannerNode) will be
 [associated](#associated) with.

 [`options`]

 [`PannerOptions`](#PannerOptions)

 [✘]

 [✔]

 Optional initial parameter value for this
 [`PannerNode`](#PannerNode).

#### 1.27.2. Attributes

[`coneInnerAngle`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: A parameter for directional audio sources that is an angle, in
 degrees, inside of which there will be no volume reduction. The
 default value is 360. The behavior is undefined if the angle is
 outside the interval \[0, 360\].

[`coneOuterAngle`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: A parameter for directional audio sources that is an angle, in
 degrees, outside of which the volume will be reduced to a constant
 value of
 [`coneOuterGain`](#dom-pannernode-coneoutergain). The default value is 360. The behavior is
 undefined if the angle is outside the interval \[0, 360\].

[`coneOuterGain`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: A parameter for directional audio sources that is the gain outside
 of the
 [`coneOuterAngle`](#dom-pannernode-coneouterangle). The default value is 0. It is a linear value (not
 dB) in the range \[0, 1\]. [An
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) MUST be thrown if the parameter is outside this
 range.]

[`distanceModel`], of type [DistanceModelType](#enumdef-distancemodeltype)

: Specifies the distance model used by this
 [`PannerNode`](#PannerNode). Defaults to
 \"[`inverse`](#dom-distancemodeltype-inverse)\".

[`maxDistance`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: The maximum distance between source and listener, after which the
 volume will not be reduced any further. The default value is 10000.
 [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if this is set to a
 non-positive value.]

[`orientationX`], of type [AudioParam](#AudioParam), readonly

: Describes the \\(x\\)-component of the vector of the direction the
 audio source is pointing in 3D Cartesian coordinate space.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 1
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 Has [automation rate
 constraints](#audioparam-automation-rate-constraints)
 :::

[`orientationY`], of type [AudioParam](#AudioParam), readonly

: Describes the \\(y\\)-component of the vector of the direction the
 audio source is pointing in 3D cartesian coordinate space.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 Has [automation rate
 constraints](#audioparam-automation-rate-constraints)
 :::

[`orientationZ`], of type [AudioParam](#AudioParam), readonly

: Describes the \\(z\\)-component of the vector of the direction the
 audio source is pointing in 3D cartesian coordinate space.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 Has [automation rate
 constraints](#audioparam-automation-rate-constraints)
 :::

[`panningModel`], of type [PanningModelType](#enumdef-panningmodeltype)

: Specifies the panning model used by this
 [`PannerNode`](#PannerNode). Defaults to
 \"[`equalpower`](#dom-panningmodeltype-equalpower)\".

[`positionX`], of type [AudioParam](#AudioParam), readonly

: Sets the \\(x\\)-coordinate position of the audio source in a 3D
 Cartesian system.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 Has [automation rate
 constraints](#audioparam-automation-rate-constraints)
 :::

[`positionY`], of type [AudioParam](#AudioParam), readonly

: Sets the \\(y\\)-coordinate position of the audio source in a 3D
 Cartesian system.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 Has [automation rate
 constraints](#audioparam-automation-rate-constraints)
 :::

[`positionZ`], of type [AudioParam](#AudioParam), readonly

: Sets the \\(z\\)-coordinate position of the audio source in a 3D
 Cartesian system.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 [most-negative-single-float](#most-negative-single-float)
 Approximately -3.4028235e38
 [`maxValue`](#dom-audioparam-maxvalue)
 [most-positive-single-float](#most-positive-single-float)
 Approximately 3.4028235e38
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 Has [automation rate
 constraints](#audioparam-automation-rate-constraints)
 :::

[`refDistance`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: A reference distance for reducing volume as source moves further
 from the listener. For distances less than this, the volume is not
 reduced. The default value is 1. [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if this is set to a
 negative value.]

[`rolloffFactor`], of type [double](https://webidl.spec.whatwg.org/#idl-double)

: Describes how quickly the volume is reduced as source moves away
 from listener. The default value is 1. [A
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror) exception MUST be thrown if this is set to a
 negative value.]

 The nominal range for the
 [`rolloffFactor`](#dom-pannernode-rollofffactor) specifies the minimum and maximum values the
 `rolloffFactor` can have. Values outside the range are clamped to
 lie within this range. The nominal range depends on the
 [`distanceModel`](#dom-pannernode-distancemodel) as follows:

 \"[`linear`](#dom-distancemodeltype-linear)\"

 : The nominal range is \\(\[0, 1\]\\).

 \"[`inverse`](#dom-distancemodeltype-inverse)\"

 : The nominal range is \\(\[0, \\infty)\\).

 \"[`exponential`](#dom-distancemodeltype-exponential)\"

 : The nominal range is \\(\[0, \\infty)\\).

 Note that the clamping happens as part of the processing of the
 distance computation. The attribute reflects the value that was set
 and is not modified.

#### 1.27.3. Methods

[`setOrientation(x, y, z)`]

: This method is DEPRECATED. It is equivalent to setting
 [`orientationX`](#dom-pannernode-orientationx).[`value`](#dom-audioparam-value),
 [`orientationY`](#dom-pannernode-orientationy).[`value`](#dom-audioparam-value), and
 [`orientationZ`](#dom-pannernode-orientationz).[`value`](#dom-audioparam-value) attribute directly, with the `x`, `y` and `z`
 parameters, respectively.

 [Consequently, if any of the
 [`orientationX`](#dom-pannernode-orientationx),
 [`orientationY`](#dom-pannernode-orientationy), and
 [`orientationZ`](#dom-pannernode-orientationz)
 [`AudioParam`](#AudioParam)s have an automation curve set using
 [`setValueCurveAtTime()`](#dom-audioparam-setvaluecurveattime) at the time this method is called, a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) MUST be thrown.]

 Describes which direction the audio source is pointing in the 3D
 cartesian coordinate space. Depending on how directional the sound
 is (controlled by the **cone** attributes), a sound pointing away
 from the listener can be very quiet or completely silent.

 The `x, y, z` parameters represent a direction vector in 3D space.

 The default value is (1,0,0).

 Arguments for the
 [PannerNode.setOrientation()](#dom-pannernode-setorientation) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`x`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 [`y`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 [`z`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

[`setPosition(x, y, z)`]

: This method is DEPRECATED. It is equivalent to setting
 [`positionX`](#dom-pannernode-positionx).[`value`](#dom-audioparam-value),
 [`positionY`](#dom-pannernode-positiony).[`value`](#dom-audioparam-value), and
 [`positionZ`](#dom-pannernode-positionz).[`value`](#dom-audioparam-value) attribute directly with the `x`, `y` and `z`
 parameters, respectively.

 [Consequently, if any of the
 [`positionX`](#dom-pannernode-positionx),
 [`positionY`](#dom-pannernode-positiony), and
 [`positionZ`](#dom-pannernode-positionz)
 [`AudioParam`](#AudioParam)s have an automation curve set using
 [`setValueCurveAtTime()`](#dom-audioparam-setvaluecurveattime) at the time this method is called, a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) MUST be thrown.]

 Sets the position of the audio source relative to the
 [`listener`](#dom-baseaudiocontext-listener) attribute. A 3D cartesian coordinate system is
 used.

 The `x, y, z` parameters represent the coordinates in 3D space.

 The default value is (0,0,0).

 Arguments for the
 [PannerNode.setPosition()](#dom-pannernode-setposition) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`x`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 [`y`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 [`z`]

 [`float`](https://webidl.spec.whatwg.org/#idl-float)

 [✘]

 [✘]

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

#### 1.27.4. [`PannerOptions`]
This specifies options for constructing a
[`PannerNode`](#PannerNode). All members are optional; if not specified, the normal
default is used in constructing the node.

```
dictionary PannerOptions : AudioNodeOptions {
 PanningModelType panningModel = "equalpower";
 DistanceModelType distanceModel = "inverse";
 float positionX = 0;
 float positionY = 0;
 float positionZ = 0;
 float orientationX = 1;
 float orientationY = 0;
 float orientationZ = 0;
 double refDistance = 1;
 double maxDistance = 10000;
 double rolloffFactor = 1;
 double coneInnerAngle = 360;
 double coneOuterAngle = 360;
 double coneOuterGain = 0;
};
```

##### 1.27.4.1. Dictionary [`PannerOptions` Members]
[`coneInnerAngle`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `360`

: The initial value for the
 [`coneInnerAngle`](#dom-pannernode-coneinnerangle) attribute of the node.

[`coneOuterAngle`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `360`

: The initial value for the
 [`coneOuterAngle`](#dom-pannernode-coneouterangle) attribute of the node.

[`coneOuterGain`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `0`

: The initial value for the
 [`coneOuterGain`](#dom-pannernode-coneoutergain) attribute of the node.

[`distanceModel`], of type [DistanceModelType](#enumdef-distancemodeltype), defaulting to `"inverse"`

: The distance model to use for the node.

[`maxDistance`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `10000`

: The initial value for the
 [`maxDistance`](#dom-pannernode-maxdistance) attribute of the node.

[`orientationX`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `1`

: The initial \\(x\\)-component value for the
 [`orientationX`](#dom-pannernode-orientationx) AudioParam.

[`orientationY`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0`

: The initial \\(y\\)-component value for the
 [`orientationY`](#dom-pannernode-orientationy) AudioParam.

[`orientationZ`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0`

: The initial \\(z\\)-component value for the
 [`orientationZ`](#dom-pannernode-orientationz) AudioParam.

[`panningModel`], of type [PanningModelType](#enumdef-panningmodeltype), defaulting to `"equalpower"`

: The panning model to use for the node.

[`positionX`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0`

: The initial \\(x\\)-coordinate value for the
 [`positionX`](#dom-pannernode-positionx) AudioParam.

[`positionY`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0`

: The initial \\(y\\)-coordinate value for the
 [`positionY`](#dom-pannernode-positiony) AudioParam.

[`positionZ`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0`

: The initial \\(z\\)-coordinate value for the
 [`positionZ`](#dom-pannernode-positionz) AudioParam.

[`refDistance`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `1`

: The initial value for the
 [`refDistance`](#dom-pannernode-refdistance) attribute of the node.

[`rolloffFactor`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `1`

: The initial value for the
 [`rolloffFactor`](#dom-pannernode-rollofffactor) attribute of the node.

#### 1.27.5. Channel Limitations

The set of [channel limitations](#panner-channel-limitations) for
[`StereoPannerNode`](#stereopannernode) also apply to
[`PannerNode`](#PannerNode).

### 1.28. The [`PeriodicWave` Interface]
[`PeriodicWave`](#PeriodicWave) represents an arbitrary periodic waveform to be used
with an
[`OscillatorNode`](#OscillatorNode).

A [conforming
implementation](https://webidl.spec.whatwg.org/#dfn-conforming-implementation) MUST support
[`PeriodicWave`](#PeriodicWave) up to at least 8192 elements.

```
[Exposed=Window]
interface PeriodicWave {
 constructor (BaseAudioContext context, optional PeriodicWaveOptions options = );
};
```

#### 1.28.1. Constructors

[`PeriodicWave(context, options)`]

: :::
 1. Let `p` be a new
 [`PeriodicWave`](#PeriodicWave) object. Let
 [`[[real]]`]
 and [`[[imag]]`]
 be two internal slots of type
 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array), and let
 [`[[normalize]]`] be an internal slot.

 2. Process
 [`options`](#dom-periodicwave-periodicwave-context-options-options) according to one of the
 following cases:

 1. If both
 [`options.real`](#dom-periodicwaveoptions-real) and
 [`options.imag`](#dom-periodicwaveoptions-imag) are present

 1. [If the lengths of
 [`options.real`](#dom-periodicwaveoptions-real) and
 [`options.imag`](#dom-periodicwaveoptions-imag) are different or if either length is
 less than 2, throw an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) and abort this
 algorithm.]

 2. Set
 [`[[real]]`](#dom-periodicwave-real-slot) and
 [`[[imag]]`](#dom-periodicwave-imag-slot) to new arrays with the same length as
 [`options.real`](#dom-periodicwaveoptions-real).

 3. Copy all elements from
 [`options.real`](#dom-periodicwaveoptions-real) to
 [`[[real]]`](#dom-periodicwave-real-slot) and
 [`options.imag`](#dom-periodicwaveoptions-imag) to
 [`[[imag]]`](#dom-periodicwave-imag-slot).

 2. If only
 [`options.real`](#dom-periodicwaveoptions-real) is present

 1. [If length of
 [`options.real`](#dom-periodicwaveoptions-real) is less than 2, throw an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) and abort this
 algorithm.]

 2. Set
 [`[[real]]`](#dom-periodicwave-real-slot) and
 [`[[imag]]`](#dom-periodicwave-imag-slot) to arrays with the same length as
 [`options.real`](#dom-periodicwaveoptions-real).

 3. Copy
 [`options.real`](#dom-periodicwaveoptions-real) to
 [`[[real]]`](#dom-periodicwave-real-slot) and set
 [`[[imag]]`](#dom-periodicwave-imag-slot) to all zeros.

 3. If only
 [`options.imag`](#dom-periodicwaveoptions-imag) is present

 1. [If length of
 [`options.imag`](#dom-periodicwaveoptions-imag) is less than 2, throw an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) and abort this
 algorithm.]

 2. Set
 [`[[real]]`](#dom-periodicwave-real-slot) and
 [`[[imag]]`](#dom-periodicwave-imag-slot) to arrays with the same length as
 [`options.imag`](#dom-periodicwaveoptions-real).

 3. Copy
 [`options.imag`](#dom-periodicwaveoptions-imag) to
 [`[[imag]]`](#dom-periodicwave-imag-slot) and set
 [`[[real]]`](#dom-periodicwave-real-slot) to all zeros.

 4. Otherwise

 1. Set
 [`[[real]]`](#dom-periodicwave-real-slot) and
 [`[[imag]]`](#dom-periodicwave-imag-slot) to zero-filled arrays of length 2.

 2. Set element at index 1 of
 [`[[imag]]`](#dom-periodicwave-imag-slot) to 1.

 When setting this
 [`PeriodicWave`](#PeriodicWave) on an
 [`OscillatorNode`](#OscillatorNode), this is equivalent to using the built-in
 type
 \"[`sine`](#dom-oscillatortype-sine)\".

 3. Set element at index 0 of both
 [`[[real]]`](#dom-periodicwave-real-slot) and
 [`[[imag]]`](#dom-periodicwave-imag-slot) to 0. (This sets the DC component to 0.)

 4. Initialize
 [`[[normalize]]`](#dom-periodicwave-normalize-slot) to the inverse of the
 [`disableNormalization`](#dom-periodicwaveconstraints-disablenormalization) attribute of the
 [`PeriodicWaveConstraints`](#PeriodicWaveConstraints) on the
 [`PeriodicWaveOptions`](#PeriodicWaveOptions).

 5. Return `p`.
 :::

 Arguments for the
 [PeriodicWave.constructor()](#dom-periodicwave-periodicwave) method.
 Parameter
 Type
 Nullable
 Optional
 Description
 [`context`]
 [`BaseAudioContext`](#BaseAudioContext)
 [✘]
 [✘]
 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`PeriodicWave`](#PeriodicWave) will be
 [associated](#associated) with. Unlike
 [`AudioBuffer`](#AudioBuffer),
 [`PeriodicWave`](#PeriodicWave)s can't be shared accross
 [`AudioContext`](#AudioContext)s or
 [`OfflineAudioContext`](#OfflineAudioContext)s. It is associated with a particular
 [`BaseAudioContext`](#BaseAudioContext).
 [`options`]
 [`PeriodicWaveOptions`](#PeriodicWaveOptions)
 [✘]
 [✔]
 Optional initial parameter value for this
 [`PeriodicWave`](#PeriodicWave).

#### 1.28.2. [`PeriodicWaveConstraints`]
The
[`PeriodicWaveConstraints`](#PeriodicWaveConstraints) dictionary is used to specify how the waveform is
[normalized](#waveform-normalization).

```
dictionary PeriodicWaveConstraints {
 boolean disableNormalization = false;
};
```

##### 1.28.2.1. Dictionary [`PeriodicWaveConstraints` Members]
[`disableNormalization`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`

: Controls whether the periodic wave is normalized or not. If `true`,
 the waveform is not normalized; otherwise, the waveform is
 normalized.

#### 1.28.3. [`PeriodicWaveOptions`]
The
[`PeriodicWaveOptions`](#PeriodicWaveOptions) dictionary is used to specify how the waveform is
constructed. If only one of
[`real`](#dom-periodicwaveoptions-real) or
[`imag`](#dom-periodicwaveoptions-imag) is specified. The other is treated as if it were an
array of all zeroes of the same length, as specified below in
[description of the dictionary
members](#dictionary-periodicwaveoptions-members). If neither is given,
a [`PeriodicWave`](#PeriodicWave) is created that MUST be equivalent to an
[`OscillatorNode`](#OscillatorNode) with
[`type`](#dom-oscillatornode-type)
\"[`sine`](#dom-oscillatortype-sine)\". If both are given, the sequences must have the same
length; otherwise an [error of type
[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) MUST be thrown].

```
dictionary PeriodicWaveOptions : PeriodicWaveConstraints {
 sequence<float> real;
 sequence<float> imag;
};
```

##### 1.28.3.1. Dictionary [`PeriodicWaveOptions` Members]
[`imag`], of type sequence\<[float](https://webidl.spec.whatwg.org/#idl-float)\>

: The
 [`imag`](#dom-periodicwaveoptions-imag) parameter represents an array of `sine` terms. The
 first element (index 0) does not exist in the Fourier series. The
 second element (index 1) represents the fundamental frequency. The
 third represents the first overtone and so on.

[`real`], of type sequence\<[float](https://webidl.spec.whatwg.org/#idl-float)\>

: The
 [`real`](#dom-periodicwaveoptions-real) parameter represents an array of `cosine` terms.
 The first element (index 0) is the DC-offset of the periodic
 waveform. The second element (index 1) represents the fundamental
 frequency. The third represents the first overtone and so on.

#### 1.28.4. Waveform Generation

The
[`createPeriodicWave()`](#dom-baseaudiocontext-createperiodicwave) method takes two arrays to specify the Fourier
coefficients of the
[`PeriodicWave`](#PeriodicWave). Let \\(a\\) and \\(b\\) represent the
[`[[real]]`](#dom-periodicwave-real-slot) and
[`[[imag]]`](#dom-periodicwave-imag-slot) arrays of length \\(L\\), respectively. Then the basic
time-domain waveform, \\(x(t)\\), can be computed using:

 $$
 x(t) = \sum_{k=1}^{L-1} \left[a[k]\cos2\pi k t + b[k]\sin2\pi k t\right]
 $$

This is the basic (unnormalized) waveform.

#### 1.28.5. Waveform Normalization

If the internal slot
[`[[normalize]]`](#dom-periodicwave-normalize-slot) of this
[`PeriodicWave`](#PeriodicWave) is `true` (the default), the waveform defined in the
previous section is normalized so that the maximum value is 1. The
normalization is done as follows.

Let

 $$
 \tilde{x}(n) = \sum_{k=1}^{L-1} \left(a[k]\cos\frac{2\pi k n}{N} + b[k]\sin\frac{2\pi k n}{N}\right)
 $$

where \\(N\\) is a power of two. (Note: \\(\\tilde{x}(n)\\) can
conveniently be computed using an inverse FFT.) The fixed normalization
factor \\(f\\) is computed as follows.

 $$
 f = \max_{n = 0, \ldots, N - 1} |\tilde{x}(n)|
 $$

Thus, the actual normalized waveform \\(\\hat{x}(n)\\) is:

 $$
 \hat{x}(n) = \frac{\tilde{x}(n)}{f}
 $$

This fixed normalization factor MUST be applied to all generated
waveforms.

#### 1.28.6. Oscillator Coefficients

The builtin oscillator types are created using
[`PeriodicWave`](#PeriodicWave) objects. For completeness the coefficients for the
[`PeriodicWave`](#PeriodicWave) for each of the builtin oscillator types is given here.
This is useful if a builtin type is desired but without the default
normalization.

In the following descriptions, let \\(a\\) be the array of real
coefficients and \\(b\\) be the array of imaginary coefficients for
[`createPeriodicWave()`](#dom-baseaudiocontext-createperiodicwave). In all cases \\(a\[n\] = 0\\) for all \\(n\\) because
the waveforms are odd functions. Also, \\(b\[0\] = 0\\) in all cases.
Hence, only \\(b\[n\]\\) for \\(n \\ge 1\\) is specified below.

\"[`sine`](#dom-oscillatortype-sine)\"

: $$
 b[n] = \begin{cases}
 1 &amp; \mbox{for } n = 1 \\
 0 &amp; \mbox{otherwise}
 \end{cases}
 $$

\"[`square`](#dom-oscillatortype-square)\"

: $$
 b[n] = \frac{2}{n\pi}\left[1 - (-1)^n\right]
 $$

\"[`sawtooth`](#dom-oscillatortype-sawtooth)\"

: $$
 b[n] = (-1)^{n+1} \dfrac{2}{n\pi}
 $$

\"[`triangle`](#dom-oscillatortype-triangle)\"

: $$
 b[n] = \frac{8\sin\dfrac{n\pi}{2}}{(\pi n)^2}
 $$

### 1.29. The [`ScriptProcessorNode` Interface - DEPRECATED]
This interface is an
[`AudioNode`](#AudioNode)
which can generate, process, or analyse audio directly using a script.
This node type is deprecated, to be replaced by the
[`AudioWorkletNode`](#AudioWorkletNode); this text is only here for informative purposes until
implementations remove this node type.

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

[`numberOfInputChannels`](#dom-baseaudiocontext-createscriptprocessor-buffersize-numberofinputchannels-numberofoutputchannels-numberofinputchannels)

This is the number of channels specified when constructing this node.
There are [channelCount
constraints](#audionode-channelcount-constraints).

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`explicit`\"

Has [channelCountMode
constraints](#audionode-channelcountmode-constraints)

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

No

[`ScriptProcessorNode`](#ScriptProcessorNode) is constructed with a
[`bufferSize`](#dom-baseaudiocontext-createscriptprocessor-buffersize-numberofinputchannels-numberofoutputchannels-buffersize) which MUST be one of the following values: 256, 512,
1024, 2048, 4096, 8192, 16384. This value controls how frequently the
[`audioprocess`](#eventdef-scriptprocessornode-audioprocess) event is dispatched and how many sample-frames need to
be processed each call.
[`audioprocess`](#eventdef-scriptprocessornode-audioprocess) events are only dispatched if the
[`ScriptProcessorNode`](#ScriptProcessorNode) has at least one input or one output connected. Lower
numbers for
[`bufferSize`](#dom-scriptprocessornode-buffersize) will result in a lower (better) [latency](#latency).
Higher numbers will be necessary to avoid audio breakup and
[glitches](#audio-glitching). This value will be picked by the
implementation if the bufferSize argument to
[`createScriptProcessor()`](#dom-baseaudiocontext-createscriptprocessor) is not passed in, or is set to 0.

[`numberOfInputChannels`](#dom-baseaudiocontext-createscriptprocessor-buffersize-numberofinputchannels-numberofoutputchannels-numberofinputchannels) and
[`numberOfOutputChannels`](#dom-baseaudiocontext-createscriptprocessor-buffersize-numberofinputchannels-numberofoutputchannels-numberofoutputchannels) determine the number of input and output channels. It
is invalid for both
[`numberOfInputChannels`](#dom-baseaudiocontext-createscriptprocessor-buffersize-numberofinputchannels-numberofoutputchannels-numberofinputchannels) and
[`numberOfOutputChannels`](#dom-baseaudiocontext-createscriptprocessor-buffersize-numberofinputchannels-numberofoutputchannels-numberofoutputchannels) to be zero.

```
[Exposed=Window]
interface ScriptProcessorNode : AudioNode {
 attribute EventHandler onaudioprocess;
 readonly attribute long bufferSize;
};
```

#### 1.29.1. Attributes

[`bufferSize`], of type [long](https://webidl.spec.whatwg.org/#idl-long), readonly

: The size of the buffer (in sample-frames) which needs to be
 processed each time
 [`audioprocess`](#eventdef-scriptprocessornode-audioprocess) is fired. Legal values are (256, 512, 1024, 2048,
 4096, 8192, 16384).

[`onaudioprocess`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: A property used to set an [event
 handler](https://html.spec.whatwg.org/multipage/webappapis.html#event-handlers) for the
 [`audioprocess`] event type that is dispatched to
 [`ScriptProcessorNode`](#ScriptProcessorNode) node types. The event dispatched to the event
 handler uses the
 [`AudioProcessingEvent`](#AudioProcessingEvent) interface.

### 1.30. The [`StereoPannerNode` Interface]
This interface represents a processing node which positions an incoming
audio stream in a stereo image using [a low-cost panning
algorithm](#stereopanner-algorithm). This panning effect is common in
positioning audio components in a stereo stream.

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

2

Has [channelCount
constraints](#audionode-channelcount-constraints)

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`clamped-max`\"

Has [channelCountMode
constraints](#audionode-channelcountmode-constraints)

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

No

The input of this node is stereo (2 channels) and cannot be increased.
Connections from nodes with fewer or more channels will be [up-mixed or
down-mixed appropriately](#channel-up-mixing-and-down-mixing).

The output of this node is hard-coded to stereo (2 channels) and cannot
be configured.

```
[Exposed=Window]
interface StereoPannerNode : AudioNode {
 constructor (BaseAudioContext context, optional StereoPannerOptions options = );
 readonly attribute AudioParam pan;
};
```

#### 1.30.1. Constructors

[`StereoPannerNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `c` and an option object
 `option`, the user agent MUST [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Arguments for the
 [StereoPannerNode.constructor()](#dom-stereopannernode-stereopannernode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`StereoPannerNode`](#stereopannernode) will be
 [associated](#associated) with.

 [`options`]

 [`StereoPannerOptions`](#StereoPannerOptions)

 [✘]

 [✔]

 Optional initial parameter value for this
 [`StereoPannerNode`](#stereopannernode).

#### 1.30.2. Attributes

[`pan`], of type [AudioParam](#AudioParam), readonly

: The position of the input in the output's stereo image. -1
 represents full left, +1 represents full right.

 ::: audioparam-info
 Parameter
 Value
 Notes
 [`defaultValue`](#dom-audioparam-defaultvalue)
 0
 [`minValue`](#dom-audioparam-minvalue)
 -1
 [`maxValue`](#dom-audioparam-maxvalue)
 1
 [`automationRate`](#dom-audioparam-automationrate)
 \"[`a-rate`](#dom-automationrate-a-rate)\"
 :::

#### 1.30.3. [`StereoPannerOptions`]
This specifies the options to use in constructing a
[`StereoPannerNode`](#stereopannernode). All members are optional; if not specified, the normal
default is used in constructing the node.

```
dictionary StereoPannerOptions : AudioNodeOptions {
 float pan = 0;
};
```

##### 1.30.3.1. Dictionary [`StereoPannerOptions` Members]
[`pan`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0`

: The initial value for the
 [`pan`](#dom-stereopannernode-pan) AudioParam.

#### 1.30.4. Channel Limitations

Because its processing is constrained by the above definitions,
[`StereoPannerNode`](#stereopannernode) is limited to mixing no more than 2 channels of audio,
and producing exactly 2 channels. It is possible to use a
[`ChannelSplitterNode`](#ChannelSplitterNode), intermediate processing by a subgraph of
[`GainNode`](#GainNode)s
and/or other nodes, and recombination via a
[`ChannelMergerNode`](#ChannelMergerNode) to realize arbitrary approaches to panning and mixing.

### 1.31. The [`WaveShaperNode` Interface]
[`WaveShaperNode`](#WaveShaperNode) is an
[`AudioNode`](#AudioNode)
processor implementing non-linear distortion effects.

Non-linear waveshaping distortion is commonly used for both subtle
non-linear warming, or more obvious distortion effects. Arbitrary
non-linear shaping curves may be specified.

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

2

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`max`\"

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

Maybe

There is a [tail-time](#tail-time)
only if the
[`oversample`](#dom-waveshapernode-oversample) attribute is set to
\"[`2x`](#dom-oversampletype-2x)\" or
\"[`4x`](#dom-oversampletype-4x)\". The actual duration of this
[tail-time](#tail-time) depends on
the implementation.

The number of channels of the output always equals the number of
channels of the input.

```
enum OverSampleType {
 "none",
 "2x",
 "4x"
};
```

::: enum-description
[`OverSampleType`](#enumdef-oversampletype) enumeration description

Enum value

Description

\"[`none`]\"

Don't oversample

\"[`2x`]\"

Oversample two times

\"[`4x`]\"

Oversample four times

```
[Exposed=Window]
interface WaveShaperNode : AudioNode {
 constructor (BaseAudioContext context, optional WaveShaperOptions options = );
 attribute Float32Array? curve;
 attribute OverSampleType oversample;
};
```

#### 1.31.1. Constructors

[`WaveShaperNode(context, options)`]

: When the constructor is called with a
 [`BaseAudioContext`](#BaseAudioContext) `c` and an option object
 `option`, the user agent MUST [initialize the
 AudioNode](#audionode-constructor-init)
 `this`, with `context` and
 `options` as arguments.

 Also, let [`[[curve set]]`] be an internal slot of this
 [`WaveShaperNode`](#WaveShaperNode). Initialize this slot to `false`. If
 [`options`](#dom-waveshapernode-waveshapernode-context-options-options) is given and specifies a
 [`curve`](#dom-waveshaperoptions-curve), set
 [`[[curve set]]`](#dom-waveshapernode-curve-set-slot) to `true`.

 Arguments for the
 [WaveShaperNode.constructor()](#dom-waveshapernode-waveshapernode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`WaveShaperNode`](#WaveShaperNode) will be
 [associated](#associated) with.

 [`options`]

 [`WaveShaperOptions`](#WaveShaperOptions)

 [✘]

 [✔]

 Optional initial parameter value for this
 [`WaveShaperNode`](#WaveShaperNode).

#### 1.31.2. Attributes

[`curve`], of type [Float32Array](https://webidl.spec.whatwg.org/#idl-Float32Array), nullable

: The shaping curve used for the waveshaping effect. The input signal
 is nominally within the range \[-1, 1\]. Each input sample within
 this range will index into the shaping curve, with a signal level of
 zero corresponding to the center value of the curve array if there
 are an odd number of entries, or interpolated between the two
 centermost values if there are an even number of entries in the
 array. Any sample value less than -1 will correspond to the first
 value in the curve array. Any sample value greater than +1 will
 correspond to the last value in the curve array.

 The implementation MUST perform linear interpolation between
 adjacent points in the curve. Initially the curve attribute is null,
 which means that the WaveShaperNode will pass its input to its
 output without modification.

 Values of the curve are spread with equal spacing in the \[-1; 1\]
 range. This means that a
 [`curve`](#dom-waveshapernode-curve) with a even number of value will not have a value
 for a signal at zero, and a
 [`curve`](#dom-waveshapernode-curve) with an odd number of value will have a value for a
 signal at zero. The output is determined by the following algorithm.

 :::
 1. Let \\(x\\) be the input sample, \\(y\\) be the corresponding
 output of the node, \\(c_k\\) be the \\(k\\)\'th element of the
 [`curve`](#dom-waveshapernode-curve), and \\(N\\) be the length of the
 [`curve`](#dom-waveshapernode-curve).

 2. Let

 $$
 \begin{align*}
 v &= \frac{N-1}{2}(x + 1) \\
 k &= \lfloor v \rfloor \\
 f &= v - k
 \end{align*}
 $$

 3. Then

 $$
 \begin{align*}
 y &=
 \begin{cases}
 c_0 & v \lt 0 \\
 c_{N-1} & v \ge N - 1 \\
 (1-f)\,c_k + fc_{k+1} & \mathrm{otherwise}
 \end{cases}
 \end{align*}
 $$
 :::

 [A
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) MUST be thrown if this attribute is set with a
 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array) that has a `length` less than 2.]

 When this attribute is set, an internal copy of the curve is created
 by the
 [`WaveShaperNode`](#WaveShaperNode). Subsequent modifications of the contents of the
 array used to set the attribute therefore have no effect.

 :::
 To set the
 [`curve`](#dom-waveshapernode-curve) attribute, execute these steps:
 1. Let `new curve` be a
 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array) to be assigned to
 [`curve`](#dom-waveshapernode-curve) or `null`. .

 2. If `new curve` is not `null` and
 [`[[curve set]]`](#dom-waveshapernode-curve-set-slot) is true, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) and abort these steps.

 3. If `new curve` is not `null`, set
 [`[[curve set]]`](#dom-waveshapernode-curve-set-slot) to true.

 4. Assign `new curve` to the
 [`curve`](#dom-waveshapernode-curve) attribute.
 :::

 The use of a curve that produces a non-zero output
 value for zero input value will cause this node to produce a DC
 signal even if there are no inputs connected to this node. This will
 persist until the node is disconnected from downstream nodes.

[`oversample`], of type [OverSampleType](#enumdef-oversampletype)

: Specifies what type of oversampling (if any) should be used when
 applying the shaping curve. The default value is
 \"[`none`](#dom-oversampletype-none)\", meaning the curve will be applied directly to
 the input samples. A value of
 \"[`2x`](#dom-oversampletype-2x)\" or
 \"[`4x`](#dom-oversampletype-4x)\" can improve the quality of the processing by
 avoiding some aliasing, with the
 \"[`4x`](#dom-oversampletype-4x)\" value yielding the highest quality. For some
 applications, it's better to use no oversampling in order to get a
 very precise shaping curve.

 :::
 A value of
 \"[`2x`](#dom-oversampletype-2x)\" or
 \"[`4x`](#dom-oversampletype-4x)\" means that the following steps MUST be performed:
 1. Up-sample the input samples to 2x or 4x the sample-rate of the
 [`AudioContext`](#AudioContext). Thus for each [render
 quantum](#render-quantum), generate twice (for 2x) or four times (for 4x)
 samples.

 2. Apply the shaping curve.

 3. Down-sample the result back to the sample-rate of the
 [`AudioContext`](#AudioContext). Thus taking the previously processed samples
 processed samples, generating a single render quantum worth of
 samples as the final result.
 :::

 The exact up-sampling and down-sampling filters are not specified,
 and can be tuned for sound quality (low aliasing, etc.), low
 latency, or performance.

 Use of oversampling introduces some degree of audio
 processing latency due to the up-sampling and down-sampling filters.
 The amount of this latency can vary from one implementation to
 another.

#### 1.31.3. [`WaveShaperOptions`]
This specifies the options for constructing a
[`WaveShaperNode`](#WaveShaperNode). All members are optional; if not specified, the normal
default is used in constructing the node.

```
dictionary WaveShaperOptions : AudioNodeOptions {
 sequence<float> curve;
 OverSampleType oversample = "none";
};
```

##### 1.31.3.1. Dictionary [`WaveShaperOptions` Members]
[`curve`], of type sequence\<[float](https://webidl.spec.whatwg.org/#idl-float)\>

: The shaping curve for the waveshaping effect.

[`oversample`], of type [OverSampleType](#enumdef-oversampletype), defaulting to `"none"`

: The type of oversampling to use for the shaping curve.

### 1.32. The [`AudioWorklet` Interface]
```
[Exposed=Window, SecureContext]
interface AudioWorklet : Worklet {
 readonly attribute MessagePort port;
};
```

#### 1.32.1. Attributes

[`port`], of type [MessagePort](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport), readonly

: A
 [`MessagePort`](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport) connected to the port on the
 [`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope).

 Authors that register an event listener on the
 `"message"` event of this
 [`port`](#dom-audioworklet-port) should call
 [`close`](https://html.spec.whatwg.org/multipage/indices.html#event-close) on either end of the
 [`MessageChannel`](https://html.spec.whatwg.org/multipage/web-messaging.html#messagechannel) (either in the
 [`AudioWorklet`](#AudioWorklet) or the
 [`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope) side) to allow for resources to be
 [collected](https://html.spec.whatwg.org/multipage/web-messaging.html#ports-and-garbage-collection).

#### 1.32.2. Concepts

The [`AudioWorklet`](#AudioWorklet) object allows developers to supply scripts (such as
JavaScript or WebAssembly code) to process audio on the [rendering
thread](#rendering-thread),
supporting custom [`AudioNode`](#AudioNode)s. This processing mechanism ensures synchronous
execution of the script code with other built-in
[`AudioNode`](#AudioNode)s
in the audio graph.

An associated pair of objects MUST be defined in order to realize this
mechanism:
[`AudioWorkletNode`](#AudioWorkletNode) and
[`AudioWorkletProcessor`](#AudioWorkletProcessor). The former represents the interface for the main
global scope similar to other
[`AudioNode`](#AudioNode)
objects, and the latter implements the internal audio processing within
a special scope named
[`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope).

![[`AudioWorkletNode`](#AudioWorkletNode) and
[`AudioWorkletProcessor`](#AudioWorkletProcessor)](images/audioworklet-concept.png){a
height="144" width="756"}

Each
[`BaseAudioContext`](#BaseAudioContext) possesses exactly one
[`AudioWorklet`](#AudioWorklet).

The [`AudioWorklet`](#AudioWorklet)'s [worklet global scope
type](https://html.spec.whatwg.org/multipage/worklets.html#worklet-global-scope-type) is
[`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope).

The [`AudioWorklet`](#AudioWorklet)'s [worklet destination
type](https://html.spec.whatwg.org/multipage/worklets.html#worklet-destination-type) is `"audioworklet"`.

Importing a script via the
[`addModule(moduleUrl)`](https://html.spec.whatwg.org/multipage/worklets.html#dom-worklet-addmodule) method registers class definitions of
[`AudioWorkletProcessor`](#AudioWorkletProcessor) under the
[`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope). There are two internal storage areas for the imported
class constructor and the active instances created from the constructor.

[`AudioWorklet`](#AudioWorklet) has one internal slot:

- [node name to parameter descriptor
 map] which is a map containing an identical set
 of string keys from [node name to processor constructor
 map](#node-name-to-processor-constructor-map) that are associated with the matching
 [parameterDescriptors](#parameterdescriptors) values. This internal storage is populated as a
 consequence of calling the
 [`registerProcessor()`](#dom-audioworkletglobalscope-registerprocessor) method in the [rendering
 thread](#rendering-thread). The population is guaranteed to complete prior to
 the resolution of the promise returned by
 [`addModule()`](https://html.spec.whatwg.org/multipage/worklets.html#dom-worklet-addmodule) on a context's
 [`audioWorklet`](#dom-baseaudiocontext-audioworklet).

```
// bypass-processor.js script file, runs on AudioWorkletGlobalScope
class BypassProcessor extends AudioWorkletProcessor {
 process (inputs, outputs) {
 // Single input, single channel.
 const input = inputs[0];
 const output = outputs[0];
 output[0].set(input[0]);

 // Process only while there are active inputs.
 return false;
 }
};

registerProcessor('bypass-processor', BypassProcessor);
```

```
// The main global scope
const context = new AudioContext();
context.audioWorklet.addModule('bypass-processor.js').then(() => {
 const bypassNode = new AudioWorkletNode(context, 'bypass-processor');
});
```

At the instantiation of
[`AudioWorkletNode`](#AudioWorkletNode) in the main global scope, the counterpart
[`AudioWorkletProcessor`](#AudioWorkletProcessor) will also be created in
[`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope). These two objects communicate via the asynchronous
message passing described in [§ 2 Processing model](#processing-model).

#### 1.32.3. The [`AudioWorkletGlobalScope` Interface]
This special execution context is designed to enable the generation,
processing, and analysis of audio data directly using a script in the
audio [rendering thread](#rendering-thread). The user-supplied script code is evaluated in this
scope to define one or more
[`AudioWorkletProcessor`](#AudioWorkletProcessor) subclasses, which in turn are used to instantiate
[`AudioWorkletProcessor`](#AudioWorkletProcessor)s, in a 1:1 association with
[`AudioWorkletNode`](#AudioWorkletNode)s in the main scope.

Exactly one
[`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope) exists for each
[`AudioContext`](#AudioContext) that contains one or more
[`AudioWorkletNode`](#AudioWorkletNode)s. The running of imported scripts is performed by the
UA as defined in
[\[HTML\]](#biblio-html "HTML Standard"). Overriding
the default specified in
[\[HTML\]](#biblio-html "HTML Standard"),
[`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope)s must not be
[terminated](https://html.spec.whatwg.org/multipage/worklets.html#terminate-a-worklet-global-scope) arbitrarily by the user agent.

An
[`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope) has the following internal slots:

- [node name to processor constructor
 map] which is a map that stores key-value pairs
 of *processor name* →
 *[`AudioWorkletProcessorConstructor`](#callbackdef-audioworkletprocessorconstructor)* instance. Initially this map is empty and populated
 when the
 [`registerProcessor()`](#dom-audioworkletglobalscope-registerprocessor) method is called.

- [pending processor construction
 data] stores temporary data generated by the
 [`AudioWorkletNode`](#AudioWorkletNode) constructor for the instantiation of the
 corresponding
 [`AudioWorkletProcessor`](#AudioWorkletProcessor). The [pending processor construction
 data](#pending-processor-construction-data) contains the following items:

 - [node reference] which is initially empty. This storage
 is for an
 [`AudioWorkletNode`](#AudioWorkletNode) reference that is transferred from the
 [`AudioWorkletNode`](#AudioWorkletNode) constructor.

 - [transferred
 port] which is initially empty. This storage
 is for a deserialized
 [`MessagePort`](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport) that is transferred from the
 [`AudioWorkletNode`](#AudioWorkletNode) constructor.

 The
[`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope) may also contain any other data and code to be shared
by these instances. As an example, multiple processors might share an
ArrayBuffer defining a wavetable or an impulse response.

 An
[`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope) is associated with a single
[`BaseAudioContext`](#BaseAudioContext), and with a single audio rendering thread for that
context. This prevents data races from occurring in global scope code
running within concurrent threads.

```
callback AudioWorkletProcessorConstructor = AudioWorkletProcessor (object options);

[Global=(Worklet, AudioWorklet), Exposed=AudioWorklet]
interface AudioWorkletGlobalScope : WorkletGlobalScope {
 undefined registerProcessor (DOMString name,
 AudioWorkletProcessorConstructor processorCtor);
 readonly attribute unsigned long long currentFrame;
 readonly attribute double currentTime;
 readonly attribute float sampleRate;
 readonly attribute unsigned long renderQuantumSize;
 readonly attribute MessagePort port;
};
```

##### 1.32.3.1. Attributes

[`currentFrame`], of type [unsigned long long](https://webidl.spec.whatwg.org/#idl-unsigned-long-long), readonly

: The current frame of the block of audio being processed. This must
 be equal to the value of the
 [`[[current frame]]`](#dom-baseaudiocontext-current-frame-slot) internal slot of the
 [`BaseAudioContext`](#BaseAudioContext).

[`currentTime`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly

: The context time of the block of audio being processed. This must be
 equal to the value of
 [`BaseAudioContext`](#BaseAudioContext)'s
 [`currentTime`](#dom-baseaudiocontext-currenttime) attribute.

[`sampleRate`], of type [float](https://webidl.spec.whatwg.org/#idl-float), readonly

: The sample rate of the associated
 [`BaseAudioContext`](#BaseAudioContext).

[`renderQuantumSize`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: The value of the private slot [render quantum
 size](#render-quantum-size) of the associated
 [`BaseAudioContext`](#BaseAudioContext).

[`port`], of type [MessagePort](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport), readonly

: A
 [`MessagePort`](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport) connected to the port on the
 [`AudioWorklet`](#AudioWorklet).

 Authors that register an event listener on the
 `"message"` event of this
 [`port`](#dom-audioworkletglobalscope-port) should call
 [`close`](https://html.spec.whatwg.org/multipage/indices.html#event-close) on either end of the
 [`MessageChannel`](https://html.spec.whatwg.org/multipage/web-messaging.html#messagechannel) (either in the
 [`AudioWorklet`](#AudioWorklet) or the
 [`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope) side) to allow for resources to be
 [collected](https://html.spec.whatwg.org/multipage/web-messaging.html#ports-and-garbage-collection).

##### 1.32.3.2. Methods

[`registerProcessor(name, processorCtor)`]

: Registers a class constructor derived from
 [`AudioWorkletProcessor`](#AudioWorkletProcessor).

 :::
 When the
 [`registerProcessor(name, processorCtor)`](#dom-audioworkletglobalscope-registerprocessor) method is called, perform the following steps. If
 an exception is thrown in any step, abort the remaining steps.
 1. If `name` is an empty string, [throw a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror)].

 2. If `name` already exists as a key in the [node name
 to processor constructor
 map](#node-name-to-processor-constructor-map), [throw a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror)].

 3. If the result of
 [`IsConstructor`](https://tc39.es/ecma262#sec-isconstructor)`(argument=``processorCtor``)`
 is `false`, [throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) ].

 4. Let *`prototype`* be the result of
 ` `[`Get`](https://tc39.es/ecma262#sec-get-o-p)`(O=`*`processorCtor`*`, P="prototype")`.

 5. If the result of
 [`Type`](https://tc39.es/ecma262#sec-ecmascript-data-types-and-values)`(argument=`*`prototype`*`)`
 is not `Object`, [throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) ].

 6. Let `parameterDescriptorsValue` be the result of
 [`Get`](https://tc39.es/ecma262#sec-get-o-p)`(O=`*`processorCtor`*`, P="parameterDescriptors")`.

 7. If `parameterDescriptorsValue` is not
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined), execute the following steps:

 1. Let `parameterDescriptorSequence` be the result
 of [the
 conversion](https://webidl.spec.whatwg.org/#es-to-sequence)
 from `parameterDescriptorsValue` to an IDL value
 of type `sequence<AudioParamDescriptor>`.

 2. Let `paramNames` be an empty Array.

 3. :::
 :::

 For each `descriptor` of
 `parameterDescriptorSequence`:
 1. Let `paramName` be the value of the member
 [`name`](#dom-audioparamdescriptor-name) in `descriptor`. [Throw a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror)] if
 `paramNames` already contains
 `paramName` value.

 2. Append `paramName` to the
 `paramNames` array.

 3. Let `defaultValue` be the value of the member
 [`defaultValue`](#dom-audioparamdescriptor-defaultvalue) in `descriptor`.

 4. Let `minValue` be the value of the member
 [`minValue`](#dom-audioparamdescriptor-minvalue) in `descriptor`.

 5. Let `maxValue` be the value of the member
 [`maxValue`](#dom-audioparamdescriptor-maxvalue) in `descriptor`.

 6. If the expresstion `minValue` \<=
 `defaultValue` \<= `maxValue` is
 false, [throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)].

 8. Append the key-value pair `name` →
 `processorCtor` to [node name to processor
 constructor
 map](#node-name-to-processor-constructor-map) of the associated
 [`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope).

 9. [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)
 to append the key-value pair `name` →
 `parameterDescriptorSequence` to the [node name to
 parameter descriptor
 map](#node-name-to-parameter-descriptor-map) of the associated
 [`BaseAudioContext`](#BaseAudioContext).
 :::

 The class constructor should only be looked up
 once, thus it does not have the opportunity to dynamically change
 after registration.

 Arguments for the [AudioWorkletGlobalScope.registerProcessor(name,
 processorCtor)](#dom-audioworkletglobalscope-registerprocessor) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`name`]

 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString)

 [✘]

 [✘]

 A string key that represents a class constructor to be registered.
 This key is used to look up the constructor of
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) during construction of an
 [`AudioWorkletNode`](#AudioWorkletNode).

 [`processorCtor`]

 [`AudioWorkletProcessorConstructor`](#callbackdef-audioworkletprocessorconstructor)

 [✘]

 [✘]

 A class constructor extended from
 [`AudioWorkletProcessor`](#AudioWorkletProcessor).

 :::
 *Return type:*
 [`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)
 :::

##### 1.32.3.3. The instantiation of [`AudioWorkletProcessor`]
At the end of the
[`AudioWorkletNode`](#AudioWorkletNode) construction, A
[struct](https://infra.spec.whatwg.org/#struct) named [processor construction
data] will be prepared for cross-thread transfer. This
[struct](https://infra.spec.whatwg.org/#struct) contains the following
[items](https://infra.spec.whatwg.org/#struct-item):

- [name]
 which is a
 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) that is to be looked up in the [node name to
 processor constructor
 map](#node-name-to-processor-constructor-map).

- [node]
 which is a reference to the
 [`AudioWorkletNode`](#AudioWorkletNode) created.

- [options]
 which is a serialized
 [`AudioWorkletNodeOptions`](#AudioWorkletNodeOptions) given to the
 [`AudioWorkletNode`](#AudioWorkletNode)'s
 [`constructor`](#dom-audioworkletnode-audioworkletnode).

- [port]
 which is a serialized
 [`MessagePort`](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport) paired with the
 [`AudioWorkletNode`](#AudioWorkletNode)'s
 [`port`](#dom-audioworkletnode-port).

Upon the arrival of the transferred data on the
[`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope), the [rendering
thread](#rendering-thread)
will invoke the algorithm below:

1. Let `constructionData` be the [processor construction
 data](#processor-construction-data) transferred from the [control
 thread](#control-thread).

2. Let `processorName`, `nodeReference` and
 `serializedPort` be `constructionData`'s
 [name](#processor-construction-data-name),
 [node](#processor-construction-data-node), and
 [port](#processor-construction-data-port) respectively.

3. Let `serializedOptions` be
 `constructionData`'s
 [options](#processor-construction-data-options).

4. Let `deserializedPort` be the result of
 [StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize)(`serializedPort`, the current
 Realm).

5. Let `deserializedOptions` be the result of
 [StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize)(`serializedOptions`, the current
 Realm).

6. Let `processorCtor` be the result of looking up
 `processorName` on the
 [`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope)'s [node name to processor constructor
 map](#node-name-to-processor-constructor-map).

7. Store `nodeReference` and `deserializedPort`
 to [node
 reference](#pending-processor-construction-data-node-reference) and [transferred
 port](#pending-processor-construction-data-transferred-port) of this
 [`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope)'s [pending processor construction
 data](#pending-processor-construction-data) respectively.

8. [Construct a callback
 function](https://webidl.spec.whatwg.org/#construct-a-callback-function) from `processorCtor` with the argument
 of `deserializedOptions`. If any exceptions are thrown in
 the callback, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to the [control
 thread](#control-thread)
 to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`processorerror`](#eventdef-audioworkletnode-processorerror) at `nodeReference` using
 [`ErrorEvent`](https://html.spec.whatwg.org/multipage/webappapis.html#errorevent).

9. Empty the [pending processor construction
 data](#pending-processor-construction-data) slot.

#### 1.32.4. The [`AudioWorkletNode` Interface]
This interface represents a user-defined
[`AudioNode`](#AudioNode)
which lives on the [control
thread](#control-thread). The
user can create an
[`AudioWorkletNode`](#AudioWorkletNode) from a
[`BaseAudioContext`](#BaseAudioContext), and such a node can be connected with other built-in
[`AudioNode`](#AudioNode)s
to form an audio graph.

::: node-info
Property

Value

Notes

[`numberOfInputs`](#dom-audionode-numberofinputs)

1

[`numberOfOutputs`](#dom-audionode-numberofoutputs)

1

[`channelCount`](#dom-audionode-channelcount)

2

[`channelCountMode`](#dom-audionode-channelcountmode)

\"`max`\"

[`channelInterpretation`](#dom-audionode-channelinterpretation)

\"`speakers`\"

[tail-time](#tail-time)

See notes

Any [tail-time](#tail-time) is
handled by the node itself

[`AudioWorkletProcessor`](#AudioWorkletProcessor) has an associated [active source] flag, initially `true`. This
flag causes the node to be retained in memory and perform audio
processing in the absence of any connected inputs.

All tasks posted from an
[`AudioWorkletNode`](#AudioWorkletNode) are posted to the task queue of its associated
[`BaseAudioContext`](#BaseAudioContext).

```
[Exposed=Window]
interface AudioParamMap {
 readonly maplike<DOMString, AudioParam>;
};
```

This interface has \"entries\", \"forEach\", \"get\", \"has\", \"keys\",
\"values\", @@iterator methods and a \"size\" getter brought by
`readonly maplike`.

```
[Exposed=Window, SecureContext]
interface AudioWorkletNode : AudioNode {
 constructor (BaseAudioContext context, DOMString name,
 optional AudioWorkletNodeOptions options = );
 readonly attribute AudioParamMap parameters;
 readonly attribute MessagePort port;
 attribute EventHandler onprocessorerror;
};
```

##### 1.32.4.1. Constructors

[`AudioWorkletNode(context, name, options)`]

: Arguments for the
 [AudioWorkletNode.constructor()](#dom-audioworkletnode-audioworkletnode) method.

 Parameter

 Type

 Nullable

 Optional

 Description

 [`context`]

 [`BaseAudioContext`](#BaseAudioContext)

 [✘]

 [✘]

 The
 [`BaseAudioContext`](#BaseAudioContext) this new
 [`AudioWorkletNode`](#AudioWorkletNode) will be
 [associated](#associated) with.

 [`name`]

 [`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString)

 [✘]

 [✘]

 A string that is a key for the
 [`BaseAudioContext`](#BaseAudioContext)'s [node name to parameter descriptor
 map](#node-name-to-parameter-descriptor-map).

 [`options`]

 [`AudioWorkletNodeOptions`](#AudioWorkletNodeOptions)

 [✘]

 [✔]

 Optional initial parameters value for this
 [`AudioWorkletNode`](#AudioWorkletNode).

 When the constructor is called, the user agent MUST perform the
 following steps on the control thread:

 :::
 When the
 [`AudioWorkletNode`](#dom-audioworkletnode-audioworkletnode) constructor is invoked with `context`,
 `nodeName`, `options`:
 1. If `nodeName` does not exist as a key in the
 [`BaseAudioContext`](#BaseAudioContext)'s [node name to parameter descriptor
 map](#node-name-to-parameter-descriptor-map), throw a
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.

 2. Let `node` be
 [this](https://webidl.spec.whatwg.org/#this) value.

 3. [Initialize the
 AudioNode](#audionode-constructor-init)
 `node` with `context` and
 `options` as arguments.

 4. [Configure input, output and output
 channels](#configure-with-audioworkletnodeoptions) of
 `node` with `options`. Abort the remaining
 steps if any exception is thrown.

 5. Let `messageChannel` be a new
 [`MessageChannel`](https://html.spec.whatwg.org/multipage/web-messaging.html#messagechannel).

 6. Let `nodePort` be the value of
 `messageChannel`'s
 [`port1`](https://html.spec.whatwg.org/multipage/web-messaging.html#dom-messagechannel-port1) attribute.

 7. Let `processorPortOnThisSide` be the value of
 `messageChannel`'s
 [`port2`](https://html.spec.whatwg.org/multipage/web-messaging.html#dom-messagechannel-port2) attribute.

 8. Let `serializedProcessorPort` be the result of
 [StructuredSerializeWithTransfer](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserializewithtransfer)(`processorPortOnThisSide`, «
 `processorPortOnThisSide` »).

 9. [Convert](https://webidl.spec.whatwg.org/#dictionary-to-es)
 `options` dictionary to `optionsObject`.

 10. Let `serializedOptions` be the result of
 [StructuredSerialize](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserialize)(`optionsObject`).

 11. Set `node`'s
 [`port`](#dom-audioworkletnode-port) to `nodePort`.

 12. Let `parameterDescriptors` be the result of retrieval
 of `nodeName` from [node name to parameter descriptor
 map](#node-name-to-parameter-descriptor-map):

 1. Let `audioParamMap` be a new
 [`AudioParamMap`](#audioparammap) object.

 2. For each `descriptor` of
 `parameterDescriptors`:

 1. Let `paramName` be the value of
 [`name`](#dom-audioparamdescriptor-name) member in `descriptor`.

 2. Let `audioParam` be a new
 [`AudioParam`](#AudioParam) instance with
 [`automationRate`](#dom-audioparamdescriptor-automationrate),
 [`defaultValue`](#dom-audioparamdescriptor-defaultvalue),
 [`minValue`](#dom-audioparamdescriptor-minvalue), and
 [`maxValue`](#dom-audioparamdescriptor-maxvalue) having values equal to the values of
 corresponding members on `descriptor`.

 3. Append a key-value pair `paramName` →
 `audioParam` to `audioParamMap`'s
 entries.

 3. If
 [`parameterData`](#dom-audioworkletnodeoptions-parameterdata) is present on `options`, perform
 the following steps:

 1. Let `parameterData` be the value of
 [`parameterData`](#dom-audioworkletnodeoptions-parameterdata).

 2. For each `paramName` →
 `paramValue` of `parameterData`:

 1. If there exists a map entry on
 `audioParamMap` with key
 `paramName`, let
 `audioParamInMap` be such entry.

 2. Set
 [`value`](#dom-audioparam-value) property of
 `audioParamInMap` to
 `paramValue`.

 4. Set `node`'s
 [`parameters`](#dom-audioworkletnode-parameters) to `audioParamMap`.

 13. [Queue a control message](#queuing) to [invoke](#invoking-processor-constructor)
 the
 [`constructor`](#dom-audioworkletprocessor-audioworkletprocessor) of the corresponding
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) with the [processor construction
 data](#processor-construction-data) that consists of: `nodeName`,
 `node`, `serializedOptions`, and
 `serializedProcessorPort`.
 :::

##### 1.32.4.2. Attributes

[`onprocessorerror`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: When an unhandled exception is thrown from the processor's
 `constructor`, `process` method, or any user-defined class method,
 the processor will [queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`processorerror`] at the associated
 [`AudioWorkletNode`](#AudioWorkletNode) using
 [`ErrorEvent`](https://html.spec.whatwg.org/multipage/webappapis.html#errorevent).

 The `ErrorEvent` is created and initialized appropriately with its
 `message`, `filename`, `lineno`, `colno` attributes on the control
 thread.

 Note that once a unhandled exception is thrown, the processor will
 output silence throughout its lifetime.

[`parameters`], of type [AudioParamMap](#audioparammap), readonly

: The `parameters` attribute is a collection of
 [`AudioParam`](#AudioParam) objects with associated names. This maplike object
 is populated from a list of
 [`AudioParamDescriptor`](#AudioParamDescriptor)s in the
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) class constructor at the instantiation.

[`port`], of type [MessagePort](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport), readonly

: Every
 [`AudioWorkletNode`](#AudioWorkletNode) has an associated `port` which is the
 [`MessagePort`](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport). It is connected to the port on the corresponding
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) object allowing bidirectional communication between
 the
 [`AudioWorkletNode`](#AudioWorkletNode) and its
 [`AudioWorkletProcessor`](#AudioWorkletProcessor).

 Authors that register an event listener on the
 `"message"` event of this
 [`port`](#dom-audioworkletnode-port) should call
 [`close`](https://html.spec.whatwg.org/multipage/indices.html#event-close) on either end of the
 [`MessageChannel`](https://html.spec.whatwg.org/multipage/web-messaging.html#messagechannel) (either in the
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) or the
 [`AudioWorkletNode`](#AudioWorkletNode) side) to allow for resources to be
 [collected](https://html.spec.whatwg.org/multipage/web-messaging.html#ports-and-garbage-collection).

##### 1.32.4.3. [`AudioWorkletNodeOptions`]
The
[`AudioWorkletNodeOptions`](#AudioWorkletNodeOptions) dictionary can be used to initialize attibutes in the
instance of an
[`AudioWorkletNode`](#AudioWorkletNode).

```
dictionary AudioWorkletNodeOptions : AudioNodeOptions {
 unsigned long numberOfInputs = 1;
 unsigned long numberOfOutputs = 1;
 sequence<unsigned long> outputChannelCount;
 record<DOMString, double> parameterData;
 object processorOptions;
};
```

###### 1.32.4.3.1. Dictionary [`AudioWorkletNodeOptions` Members]
[`numberOfInputs`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), defaulting to `1`

: This is used to initialize the value of the
 [`AudioNode`](#AudioNode)
 [`numberOfInputs`](#dom-audionode-numberofinputs) attribute.

[`numberOfOutputs`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), defaulting to `1`

: This is used to initialize the value of the
 [`AudioNode`](#AudioNode)
 [`numberOfOutputs`](#dom-audionode-numberofoutputs) attribute.

[`outputChannelCount`], of type `sequence<unsigned long>`

: This array is used to configure the number of channels in each
 output.

[`parameterData`], of type record\<[DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), [double](https://webidl.spec.whatwg.org/#idl-double)\>

: This is a list of user-defined key-value pairs that are used to set
 the initial
 [`value`](#dom-audioparam-value) of an
 [`AudioParam`](#AudioParam) with the matched name in the
 [`AudioWorkletNode`](#AudioWorkletNode).

[`processorOptions`], of type [object](https://webidl.spec.whatwg.org/#idl-object)

: This holds any user-defined data that may be used to initialize
 custom properties in an
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) instance that is associated with the
 [`AudioWorkletNode`](#AudioWorkletNode).

###### 1.32.4.3.2. Configuring Channels with [`AudioWorkletNodeOptions`]
The following algorithm describes how an
[`AudioWorkletNodeOptions`](#AudioWorkletNodeOptions) can be used to configure various channel
configurations.

1. Let `node` be an
 [`AudioWorkletNode`](#AudioWorkletNode) instance that is given to this algorithm.

2. If both
 [`numberOfInputs`](#dom-audioworkletnodeoptions-numberofinputs) and
 [`numberOfOutputs`](#dom-audioworkletnodeoptions-numberofoutputs) are zero, throw a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) and abort the remaining steps.

3. If
 [`outputChannelCount`](#dom-audioworkletnodeoptions-outputchannelcount)
 [exists](https://infra.spec.whatwg.org/#map-exists),

 1. If any value in
 [`outputChannelCount`](#dom-audioworkletnodeoptions-outputchannelcount) is zero or greater than the implementation's
 maximum number of channels, throw a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) and abort the remaining steps.

 2. If the length of
 [`outputChannelCount`](#dom-audioworkletnodeoptions-outputchannelcount) does not equal
 [`numberOfOutputs`](#dom-audioworkletnodeoptions-numberofoutputs), throw an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) and abort the remaining steps.

 3. If both
 [`numberOfInputs`](#dom-audioworkletnodeoptions-numberofinputs) and
 [`numberOfOutputs`](#dom-audioworkletnodeoptions-numberofoutputs) are 1, set the channel count of the
 `node` output to the one value in
 [`outputChannelCount`](#dom-audioworkletnodeoptions-outputchannelcount).

 4. Otherwise set the channel count of the *k*th output of the
 `node` to the *k*th element of
 [`outputChannelCount`](#dom-audioworkletnodeoptions-outputchannelcount) sequence and return.

4. If
 [`outputChannelCount`](#dom-audioworkletnodeoptions-outputchannelcount) does not
 [exists](https://infra.spec.whatwg.org/#map-exists),

 1. If both
 [`numberOfInputs`](#dom-audioworkletnodeoptions-numberofinputs) and
 [`numberOfOutputs`](#dom-audioworkletnodeoptions-numberofoutputs) are 1, set the initial channel count of the
 `node` output to 1 and return.

 [NOTE:] For this case, the output chanel count will
 change to
 [computedNumberOfChannels](#computednumberofchannels) dynamically based on the input and the
 [`channelCountMode`](#dom-audionode-channelcountmode) at runtime.

 2. Otherwise set the channel count of each output of the
 `node` to 1 and return.

#### 1.32.5. The [`AudioWorkletProcessor` Interface]
This interface represents an audio processing code that runs on the
audio [rendering thread](#rendering-thread). It lives in the
[`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope), and the definition of the class manifests the actual
audio processing. Note that the an
[`AudioWorkletProcessor`](#AudioWorkletProcessor) construction can only happen as a result of an
[`AudioWorkletNode`](#AudioWorkletNode) contruction.

```
[Exposed=AudioWorklet]
interface AudioWorkletProcessor {
 constructor ();
 readonly attribute MessagePort port;
};

callback AudioWorkletProcessCallback =
 boolean (FrozenArray<FrozenArray<Float32Array>> inputs,
 FrozenArray<FrozenArray<Float32Array>> outputs,
 object parameters);
```

[`AudioWorkletProcessor`](#AudioWorkletProcessor) has two internal slots:

[`[[node reference]]`]

: A reference to the associated
 [`AudioWorkletNode`](#AudioWorkletNode).

[`[[callable process]]`]

: A boolean flag representing whether
 [process()](#process) is a valid
 function that can be invoked.

##### 1.32.5.1. Constructors

[`AudioWorkletProcessor()`]

: When the constructor for
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) is invoked, the following steps are performed on
 the [rendering
 thread](#rendering-thread).

 :::
 1. Let `nodeReference` be the result of looking up [node
 reference](#pending-processor-construction-data-node-reference) on the [pending processor construction
 data](#pending-processor-construction-data) of the current
 [`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope). Throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) exception if the slot is empty.

 2. Let `processor` be the
 [this](https://webidl.spec.whatwg.org/#this) value.

 3. Set `processor`'s
 [`[[node reference]]`](#dom-audioworkletprocessor-node-reference-slot) to `nodeReference`.

 4. Set `processor`'s
 [`[[callable process]]`](#dom-audioworkletprocessor-callable-process-slot) to `true`.

 5. Let `deserializedPort` be the result of looking up
 [transferred
 port](#pending-processor-construction-data-transferred-port) from the [pending processor construction
 data](#pending-processor-construction-data).

 6. Set `processor`'s
 [`port`](#dom-audioworkletprocessor-port) to `deserializedPort`.

 7. Empty the [pending processor construction
 data](#pending-processor-construction-data) slot.
 :::

##### 1.32.5.2. Attributes

[`port`], of type [MessagePort](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport), readonly

: Every
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) has an associated `port` which is a
 [`MessagePort`](https://html.spec.whatwg.org/multipage/web-messaging.html#messageport). It is connected to the port on the corresponding
 [`AudioWorkletNode`](#AudioWorkletNode) object allowing bidirectional communication between
 an
 [`AudioWorkletNode`](#AudioWorkletNode) and its
 [`AudioWorkletProcessor`](#AudioWorkletProcessor).

 Authors that register an event listener on the
 `"message"` event of this
 [`port`](#dom-audioworkletprocessor-port) should call
 [`close`](https://html.spec.whatwg.org/multipage/indices.html#event-close) on either end of the
 [`MessageChannel`](https://html.spec.whatwg.org/multipage/web-messaging.html#messagechannel) (either in the
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) or the
 [`AudioWorkletNode`](#AudioWorkletNode) side) to allow for resources to be
 [collected](https://html.spec.whatwg.org/multipage/web-messaging.html#ports-and-garbage-collection).

##### 1.32.5.3. Callback [`AudioWorkletProcessCallback`]
Users can define a custom audio processor by extending
[`AudioWorkletProcessor`](#AudioWorkletProcessor). The subclass MUST define an
[`AudioWorkletProcessCallback`](#audioworkletprocess-callback-parameters) named [`process()`] that implements the audio processing
algorithm and may have a static property named
[`parameterDescriptors`] which is an iterable of
[`AudioParamDescriptor`](#AudioParamDescriptor)s.

The [process()](#process) callback
function is handled as specified when [rendering a
graph](#rendering-a-graph).

The return value of this callback controls the lifetime of the
[`AudioWorkletProcessor`](#AudioWorkletProcessor)'s associated
[`AudioWorkletNode`](#AudioWorkletNode).

This lifetime policy can support a variety of approaches found in
built-in nodes, including the following:

- Nodes that transform their inputs, and are active only while connected
 inputs and/or script references exist. Such nodes SHOULD return
 `false` from [process()](#process)
 which allows the presence or absence of connected inputs to determine
 whether the
 [`AudioWorkletNode`](#AudioWorkletNode) is [actively
 processing](#actively-processing).

- Nodes that transform their inputs, but which remain active for a
 [tail-time](#tail-time) after
 their inputs are disconnected. In this case,
 [process()](#process) SHOULD return
 `true` for some period of time after `inputs` is found to contain zero
 channels. The current time may be obtained from the global scope's
 [`currentTime`](#dom-audioworkletglobalscope-currenttime) to measure the start and end of this tail-time
 interval, or the interval could be calculated dynamically depending on
 the processor's internal state.

- Nodes that act as sources of output, typically with a lifetime. Such
 nodes SHOULD return `true` from
 [process()](#process) until the
 point at which they are no longer producing an output.

Note that the preceding definition implies that when no return value is
provided from an implementation of
[process()](#process), the effect is
identical to returning `false` (since the effective return value is the
falsy value
[`undefined`](https://webidl.spec.whatwg.org/#idl-undefined)). This is a reasonable behavior for any
[`AudioWorkletProcessor`](#AudioWorkletProcessor) that is active only when it has active inputs.

The example below shows how
[`AudioParam`](#AudioParam) can be defined and used in an
[`AudioWorkletProcessor`](#AudioWorkletProcessor).

```
class MyProcessor extends AudioWorkletProcessor {
 static get parameterDescriptors() {
 return [{
 name: 'myParam',
 defaultValue: 0.5,
 minValue: 0,
 maxValue: 1,
 automationRate: "k-rate"
 }];
 }

 process(inputs, outputs, parameters) {
 // Get the first input and output.
 const input = inputs[0];
 const output = outputs[0];
 const myParam = parameters.myParam;

 // A simple amplifier for single input and output. Note that the
 // automationRate is "k-rate", so it will have a single value at index [0]
 // for each render quantum.
 for (let channel = 0; channel < output.length; ++channel) {
 for (let i = 0; i < output[channel].length; ++i) {
 output[channel][i] = input[channel][i] * myParam[0];
 }
 }
 }
}
```

###### 1.32.5.3.1. Callback [`AudioWorkletProcessCallback` Parameters ]
The following describes the parameters to the
[`AudioWorkletProcessCallback`](#audioworkletprocess-callback-parameters) function.

In general, the
[`inputs`](#dom-audioworkletprocesscallback-inputs) and
[`outputs`](#dom-audioworkletprocesscallback-outputs) arrays will be reused between calls so
that no memory allocation is done. However, if the topology changes,
because, say, the number of channels in the input or the output changes,
new arrays are reallocated. New arrays are also reallocated if any part
of the
[`inputs`](#dom-audioworkletprocesscallback-inputs) or
[`outputs`](#dom-audioworkletprocesscallback-outputs) arrays are transferred.

[`inputs`](#dom-audioworkletprocesscallback-inputs), of type [`FrozenArray`](https://webidl.spec.whatwg.org/#idl-frozen-array)`<`[`FrozenArray`](https://webidl.spec.whatwg.org/#idl-frozen-array)`<`[`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)`>>`

: The input audio buffer from the incoming connections provided by the
 user agent. `inputs[n][m]` is a
 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array) of audio samples for the \\(m\\)th channel of the
 \\(n\\)th input. While the number of inputs is fixed at
 construction, the number of channels can be changed dynamically
 based on
 [computedNumberOfChannels](#computednumberofchannels).

 If there are no [actively
 processing](#actively-processing)
 [`AudioNode`](#AudioNode)s connected to the \\(n\\)th input of the
 [`AudioWorkletNode`](#AudioWorkletNode) for the current render quantum, then the content of
 `inputs[n]` is an empty array, indicating that zero channels of
 input are available. This is the only circumstance under which the
 number of elements of `inputs[n]` can be zero.

[`outputs`](#dom-audioworkletprocesscallback-outputs), of type [`FrozenArray`](https://webidl.spec.whatwg.org/#idl-frozen-array)`<`[`FrozenArray`](https://webidl.spec.whatwg.org/#idl-frozen-array)`<`[`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)`>>`

: The output audio buffer that is to be consumed by the user agent.
 `outputs[n][m]` is a
 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array) object containing the audio samples for \\(m\\)th
 channel of \\(n\\)th output. Each of the
 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)s are zero-filled. The number of channels in the
 output will match
 [computedNumberOfChannels](#computednumberofchannels) only when the node has a single output.

[`parameters`](#dom-audioworkletprocesscallback-parameters), of type [`object`](https://webidl.spec.whatwg.org/#idl-object)

: An [ordered
 map](https://infra.spec.whatwg.org/#ordered-map) of `name` →
 `parameterValues`. `parameters["``name``"]`
 returns `parameterValues`, which is a
 [`FrozenArray`](https://webidl.spec.whatwg.org/#idl-frozen-array)\<[`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)\> with the automation values of the
 `name`
 [`AudioParam`](#AudioParam).

 For each array, the array contains the
 [computedValue](#computedvalue) of the parameter for all frames in the [render
 quantum](#render-quantum). However, if no automation is scheduled during this
 render quantum, the array MAY have length 1 with the array element
 being the constant value of the
 [`AudioParam`](#AudioParam) for the [render
 quantum](#render-quantum).

 This object is frozen according the the following steps

 :::
 1. Let `parameter` be the [ordered
 map](https://infra.spec.whatwg.org/#ordered-map) of the name and parameter values.

 2. [SetIntegrityLevel](https://tc39.es/ecma262/#sec-setintegritylevel)(`parameter`,
 frozen)
 :::

 This frozen [ordered
 map](https://infra.spec.whatwg.org/#ordered-map) computed in the algorithm is passed to the
 [`parameters`](#dom-audioworkletprocesscallback-parameters) argument.

 This means the object cannot be modified and hence
 the same object can be used for successive calls unless length of an
 array changes.

##### 1.32.5.4. [`AudioParamDescriptor`]
The
[`AudioParamDescriptor`](#AudioParamDescriptor) dictionary is used to specify properties for an
[`AudioParam`](#AudioParam) object that is used in an
[`AudioWorkletNode`](#AudioWorkletNode).

```
dictionary AudioParamDescriptor {
 required DOMString name;
 float defaultValue = 0;
 float minValue = -3.4028235e38;
 float maxValue = 3.4028235e38;
 AutomationRate automationRate = "a-rate";
};
```

###### 1.32.5.4.1. Dictionary [`AudioParamDescriptor` Members]
There are constraints on the values for these members. See the
[algorithm for handling an
AudioParamDescriptor](#steps-parameterDescriptorSequence) for the
constraints.

[`automationRate`], of type [AutomationRate](#enumdef-automationrate), defaulting to `"a-rate"`

: Represents the default automation rate.

[`defaultValue`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `0`

: Represents the default value of the parameter.

[`maxValue`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `3.4028235e38`

: Represents the maximum value.

[`minValue`], of type [float](https://webidl.spec.whatwg.org/#idl-float), defaulting to `-3.4028235e38`

: Represents the minimum value.

[`name`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString)

: Represents the name of the parameter.

#### 1.32.6. AudioWorklet Sequence of Events

The following figure illustrates an idealized sequence of events
occurring relative to an
[`AudioWorklet`](#AudioWorklet):

![[`AudioWorklet`](#AudioWorklet)
sequence](images/audioworklet-instantiation-sequence.png){height="427"
width="784"}

The steps depicted in the diagram are one possible sequence of events
involving the creation of an
[`AudioContext`](#AudioContext) and an associated
[`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope), followed by the creation of an
[`AudioWorkletNode`](#AudioWorkletNode) and its associated
[`AudioWorkletProcessor`](#AudioWorkletProcessor).

1. An [`AudioContext`](#AudioContext) is created.

2. In the main scope, `context.audioWorklet` is requested to add a
 script module.

3. Since none exists yet, a new
 [`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope) is created in association with the context. This is
 the global scope in which
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) class definitions will be evaluated. (On subsequent
 calls, this previously created scope will be used.)

4. The imported script is run in the newly created global scope.

5. As part of running the imported script, an
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) is registered under a key (`"custom"` in the above
 diagram) within the
 [`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope). This populates maps both in the global scope and
 in the
 [`AudioContext`](#AudioContext).

6. The promise for the
 [`addModule()`](https://html.spec.whatwg.org/multipage/worklets.html#dom-worklet-addmodule) call is resolved.

7. In the main scope, an
 [`AudioWorkletNode`](#AudioWorkletNode) is created using the user-specified key along with
 a dictionary of options.

8. As part of the node's creation, this key is used to look up the
 correct
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) subclass for instantiation.

9. An instance of the
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) subclass is instantiated with a structured clone of
 the same options dictionary. This instance is paired with the
 previously created
 [`AudioWorkletNode`](#AudioWorkletNode).

#### 1.32.7. AudioWorklet Examples

##### 1.32.7.1. The BitCrusher Node

Bitcrushing is a mechanism by which the quality of an audio stream is
reduced both by quantizing the sample value (simulating a lower
bit-depth), and by quantizing in time resolution (simulating a lower
sample rate). This example shows how to use
[`AudioParam`](#AudioParam)s (in this case, treated as
[a-rate](#a-rate)) inside an
[`AudioWorkletProcessor`](#AudioWorkletProcessor).

```
const context = new AudioContext();context.audioWorklet.addModule('bitcrusher.js').then(() => { const osc = new OscillatorNode(context); const amp = new GainNode(context); // Create a worklet node. 'BitCrusher' identifies the // AudioWorkletProcessor previously registered when // bitcrusher.js was imported. The options automatically // initialize the correspondingly named AudioParams. const bitcrusher = new AudioWorkletNode(context, 'bitcrusher', { parameterData: {bitDepth: 8} }); osc.connect(bitcrusher).connect(amp).connect(context.destination); osc.start();});
```

```
class Bitcrusher extends AudioWorkletProcessor { static get parameterDescriptors () { return [{ name: 'bitDepth', defaultValue: 12, minValue: 1, maxValue: 16 }, { name: 'frequencyReduction', defaultValue: 0.5, minValue: 0, maxValue: 1 }]; } constructor () { super(); this._phase = 0; this._lastSampleValue = 0; } process (inputs, outputs, parameters) { const input = inputs[0]; const output = outputs[0]; const bitDepth = parameters.bitDepth; const frequencyReduction = parameters.frequencyReduction; if (bitDepth.length > 1) { for (let channel = 0; channel < output.length; ++channel) { for (let i = 0; i < output[channel].length; ++i) { let step = Math.pow(0.5, bitDepth[i]); // Use modulo for indexing to handle the case where // the length of the frequencyReduction array is 1. this._phase += frequencyReduction[i % frequencyReduction.length]; if (this._phase >= 1.0) { this._phase -= 1.0; this._lastSampleValue = step * Math.floor(input[channel][i] / step + 0.5); } output[channel][i] = this._lastSampleValue; } } } else { // Because we know bitDepth is constant for this call, // we can lift the computation of step outside the loop, // saving many operations. const step = Math.pow(0.5, bitDepth[0]); for (let channel = 0; channel < output.length; ++channel) { for (let i = 0; i < output[channel].length; ++i) { this._phase += frequencyReduction[i % frequencyReduction.length]; if (this._phase >= 1.0) { this._phase -= 1.0; this._lastSampleValue = step * Math.floor(input[channel][i] / step + 0.5); } output[channel][i] = this._lastSampleValue; } } } // No need to return a value; this node's lifetime is dependent only on its // input connections. }};registerProcessor('bitcrusher', Bitcrusher);
```

 In the definition of
[`AudioWorkletProcessor`](#AudioWorkletProcessor) class, an
[`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) will be thrown if the author-supplied constructor has
an explicit return value that is not `this` or does not properly call
`super()`.

##### 1.32.7.2. VU Meter Node

This example of a simple sound level meter further illustrates how to
create an
[`AudioWorkletNode`](#AudioWorkletNode) subclass that acts like a native
[`AudioNode`](#AudioNode),
accepting constructor options and encapsulating the inter-thread
communication (asynchronous) between
[`AudioWorkletNode`](#AudioWorkletNode) and
[`AudioWorkletProcessor`](#AudioWorkletProcessor). This node does not use any output.

```
/* vumeter-node.js: Main global scope */export default class VUMeterNode extends AudioWorkletNode { constructor (context, updateIntervalInMS) { super(context, 'vumeter', { numberOfInputs: 1, numberOfOutputs: 0, channelCount: 1, processorOptions: { updateIntervalInMS: updateIntervalInMS || 16.67 } }); // States in AudioWorkletNode this._updateIntervalInMS = updateIntervalInMS; this._volume = 0; // Handles updated values from AudioWorkletProcessor this.port.onmessage = event => { if (event.data.volume) this._volume = event.data.volume; } this.port.start(); } get updateInterval() { return this._updateIntervalInMS; } set updateInterval(updateIntervalInMS) { this._updateIntervalInMS = updateIntervalInMS; this.port.postMessage({updateIntervalInMS: updateIntervalInMS}); } draw () { // Draws the VU meter based on the volume value // every |this._updateIntervalInMS| milliseconds. }};
```

```
/* vumeter-processor.js: AudioWorkletGlobalScope */const SMOOTHING_FACTOR = 0.9;const MINIMUM_VALUE = 0.00001;registerProcessor('vumeter', class extends AudioWorkletProcessor { constructor (options) { super(); this._volume = 0; this._updateIntervalInMS = options.processorOptions.updateIntervalInMS; this._nextUpdateFrame = this._updateIntervalInMS; this.port.onmessage = event => { if (event.data.updateIntervalInMS) this._updateIntervalInMS = event.data.updateIntervalInMS; } } get intervalInFrames () { return this._updateIntervalInMS / 1000 * sampleRate; } process (inputs, outputs, parameters) { const input = inputs[0]; // Note that the input will be down-mixed to mono; however, if no inputs are // connected then zero channels will be passed in. if (input.length > 0) { const samples = input[0]; let sum = 0; let rms = 0; // Calculated the squared-sum. for (let i = 0; i < samples.length; ++i) sum += samples[i] * samples[i]; // Calculate the RMS level and update the volume. rms = Math.sqrt(sum / samples.length); this._volume = Math.max(rms, this._volume * SMOOTHING_FACTOR); // Update and sync the volume property with the main thread. this._nextUpdateFrame -= samples.length; if (this._nextUpdateFrame < 0) { this._nextUpdateFrame += this.intervalInFrames; this.port.postMessage({volume: this._volume}); } } // Keep on processing if the volume is above a threshold, so that // disconnecting inputs does not immediately cause the meter to stop // computing its smoothed value. return this._volume >= MINIMUM_VALUE; }});
```

```
/* index.js: Main global scope, entry point */import VUMeterNode from './vumeter-node.js';const context = new AudioContext();context.audioWorklet.addModule('vumeter-processor.js').then(() => { const oscillator = new OscillatorNode(context); const vuMeterNode = new VUMeterNode(context, 25); oscillator.connect(vuMeterNode); oscillator.start(); function drawMeter () { vuMeterNode.draw(); requestAnimationFrame(drawMeter); } drawMeter();});
```

### 1.33. The [`AudioPlaybackStats` Interface]
Provides audio underrun and latency statistics for audio played through
the [`AudioContext`](#AudioContext).

When audio is not delivered to the playback device on time, this causes
an audio underrun. This causes a discontinuity in the played signal,
which produces an audible \"click\", commonly called a \"glitch\". These
glitches are bad for the user experience, so if any of these occur it
can be useful for the application to be able to detect them and possibly
take some action to improve the playback.

[`AudioPlaybackStats`](#AudioPlaybackStats) is a dedicated object for audio statistics reporting;
it reports audio underrun and playback latency statistics for the
[`AudioContext`](#AudioContext)'s playback path via the
[`AudioDestinationNode`](#AudioDestinationNode) and its associated audio output device. This allows
applications to measure underruns, which can occur due to the following
reasons:

- The audio graph is too complex for the system to generate audio on
 time, causing underruns.

- There is some external problem causing underruns. Examples of such
 problems are:

 - Another program playing audio to the same playback device is
 malfunctioning.

 - There is a global system CPU overload.

 - The system is overloaded due to thermal throttling.

Underruns are defined in terms of [underrun
frames](#underrun-frame) and
[underrun events](#underrun-event):

- An [underrun frame] is an audio frame played by the output device that was
 not provided by the
 [`AudioContext`](#AudioContext). This happens when the playback path fails to provide
 audio frames to the output device on time, in which case it will still
 have to play something.

 [NOTE:] Underrun frames are typically silence.

- An [underrun event] is the playback of a continuous sequence of [underrun
 frames](#underrun-frame).
 The duration of the [underrun
 event](#underrun-event) is
 the total duration of the sequence of [underrun
 frames](#underrun-frame)s.

```
[Exposed=Window, SecureContext]
interface AudioPlaybackStats {
 readonly attribute double underrunDuration;
 readonly attribute unsigned long underrunEvents;
 readonly attribute double totalDuration;
 readonly attribute double averageLatency;
 readonly attribute double minimumLatency;
 readonly attribute double maximumLatency;
 undefined resetLatency();
 [Default] object toJSON();
};
```

Each [`AudioContext`](#AudioContext) possesses exactly one
[`AudioPlaybackStats`](#AudioPlaybackStats).

[`AudioPlaybackStats`](#AudioPlaybackStats) has the following internal slots:

[`[[audio context]]`]

: The [`AudioContext`](#AudioContext) that this instance of
 [`AudioPlaybackStats`](#AudioPlaybackStats) is associated with. Initialized to the owning
 [`AudioContext`](#AudioContext) upon creation.

[`[[underrun duration]]`]

: The total duration of all [underrun
 events](#underrun-event)
 that have occurred in
 [`[[audio context]]`](#dom-audioplaybackstats-audio-context-slot) playback as of the last stat update, a double.
 Initialized to 0.

[`[[underrun events]]`]

: The total number of [underrun
 events](#underrun-event)
 that have occurred in
 [`[[audio context]]`](#dom-audioplaybackstats-audio-context-slot) playback as of the last stat update, an int.
 Initialized to 0.

[`[[total duration]]`]

: The total duration in seconds of all frames in
 [`[[audio context]]`](#dom-audioplaybackstats-audio-context-slot) playback as of the last stat update, a double,
 defined as
 [`[[underrun duration]]`](#dom-audioplaybackstats-underrun-duration-slot)` + `[`currentTime`](#dom-baseaudiocontext-currenttime). Initialized to 0.

[`[[average latency]]`]

: The average audio output latency of
 [`[[audio context]]`](#dom-audioplaybackstats-audio-context-slot) over the
 [`currently tracked interval`](#dom-audioplaybackstats-currently-tracked-interval), a double.

[`[[minimum latency]]`]

: The minimum audio output latency of
 [`[[audio context]]`](#dom-audioplaybackstats-audio-context-slot) over the
 [`currently tracked interval`](#dom-audioplaybackstats-currently-tracked-interval), a double. Initialized to 0.

[`[[maximum latency]]`]

: The maximum audio output latency of
 [`[[audio context]]`](#dom-audioplaybackstats-audio-context-slot) over the
 [`currently tracked interval`](#dom-audioplaybackstats-currently-tracked-interval), a double. Initialized to 0.

[`[[latency reset time]]`]

: The time when the latency statistics were last reset, a double. This
 is in the clock domain of
 [`currentTime`](#dom-baseaudiocontext-currenttime). Initialized to 0.

 The
 [`currently tracked interval`] is the interval from
 [`[[latency reset time]]`](#dom-audioplaybackstats-latency-reset-time-slot) to the current
 [`currentTime`](#dom-baseaudiocontext-currenttime).

#### 1.33.1. Attributes

 These attributes update only once per second and under
specific conditions. See [§ 1.33.3 Updating the
stats](#update-audio-stats) and [§ 1.33.4.2
Mitigations](#AudioPlaybackStats-privacy-mitigations) for details.

[`underrunDuration`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly

: Returns the value of the
 [`[[underrun duration]]`](#dom-audioplaybackstats-underrun-duration-slot) internal slot.

 [NOTE:] This metric can be used together with
 [`totalDuration`](#dom-audioplaybackstats-totalduration) to calculate the percentage of played out media
 that was not provided by the
 [`AudioContext`](#AudioContext).

<!-- -->

[`underrunEvents`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Returns the value of the
 [`[[underrun events]]`](#dom-audioplaybackstats-underrun-events-slot) internal slot.

<!-- -->

[`totalDuration`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly

: Returns the value of the
 [`[[total duration]]`](#dom-audioplaybackstats-total-duration-slot) internal slot.

<!-- -->

[`averageLatency`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly

: Returns the value of the
 [`[[average latency]]`](#dom-audioplaybackstats-average-latency-slot) internal slot.

<!-- -->

[`minimumLatency`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly

: Returns the value of the
 [`[[minimum latency]]`](#dom-audioplaybackstats-minimum-latency-slot) internal slot.

<!-- -->

[`maximumLatency`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly

: Returns the value of the
 [`[[maximum latency]]`](#dom-audioplaybackstats-maximum-latency-slot) internal slot.

#### 1.33.2. Methods

[`resetLatency()`]

: Sets the start of the interval that latency stats are tracked over
 to the current time. When
 [`resetLatency`](#dom-audioplaybackstats-resetlatency) is called, run the following steps:

 1. Set
 [`[[latency reset time]]`](#dom-audioplaybackstats-latency-reset-time-slot) to
 [`currentTime`](#dom-baseaudiocontext-currenttime).

 2. Let `currentLatency` be the playback latency of the
 last frame played by
 [`[[audio context]]`](#dom-audioplaybackstats-audio-context-slot), or 0 if no frames have been played out yet.

 3. Set
 [`[[average latency]]`](#dom-audioplaybackstats-average-latency-slot) to `currentLatency`.

 4. Set
 [`[[minimum latency]]`](#dom-audioplaybackstats-minimum-latency-slot) to `currentLatency`.

 5. Set
 [`[[maximum latency]]`](#dom-audioplaybackstats-maximum-latency-slot) to `currentLatency`.

#### 1.33.3. Updating the stats

Once per second, execute the update audio stats algorithm:

1. If
 [`[[audio context]]`](#dom-audioplaybackstats-audio-context-slot) is not running, abort these steps.

2. Let `canUpdate` be false.

3. Let `document` be the current
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window). If `document` is [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active) and `document`'s [visibility
 state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) is `"visible"`, set `canUpdate` to true.

4. Let `permission` be the [permission
 state](https://w3c.github.io/permissions/#dfn-permission-state) for the permission associated with \"microphone\"
 access. If `permission` is \"granted\", set
 `canUpdate` to true.

5. If `canUpdate` is false, abort these steps.

6. Set
 [`[[underrun duration]]`](#dom-audioplaybackstats-underrun-duration-slot) to the total duration of all [underrun
 events](#underrun-event)
 (in seconds) that have occurred in
 [`[[audio context]]`](#dom-audioplaybackstats-audio-context-slot) playback since its construction.

7. Set
 [`[[underrun events]]`](#dom-audioplaybackstats-underrun-events-slot) to the total number of [underrun
 events](#underrun-event)
 that have occurred in
 [`[[audio context]]`](#dom-audioplaybackstats-audio-context-slot) playback since its construction.

8. Set
 [`[[total duration]]`](#dom-audioplaybackstats-total-duration-slot) to
 [`[[underrun duration]]`](#dom-audioplaybackstats-underrun-duration-slot) +
 [`[[audio context]]`](#dom-audioplaybackstats-audio-context-slot).[`currentTime`](#dom-baseaudiocontext-currenttime).

9. Set
 [`[[average latency]]`](#dom-audioplaybackstats-average-latency-slot) to the average playback latency (in seconds) of
 [`[[audio context]]`](#dom-audioplaybackstats-audio-context-slot) playback over the
 [`currently tracked interval`](#dom-audioplaybackstats-currently-tracked-interval).

10. Set
 [`[[minimum latency]]`](#dom-audioplaybackstats-minimum-latency-slot) to the minimum playback latency (in seconds) of
 [`[[audio context]]`](#dom-audioplaybackstats-audio-context-slot) playback over the
 [`currently tracked interval`](#dom-audioplaybackstats-currently-tracked-interval).

11. Set
 [`[[maximum latency]]`](#dom-audioplaybackstats-maximum-latency-slot) to the maximum playback latency (in seconds) of
 [`[[audio context]]`](#dom-audioplaybackstats-audio-context-slot) playback over the
 [`currently tracked interval`](#dom-audioplaybackstats-currently-tracked-interval).

#### 1.33.4. Privacy considerations for [`AudioPlaybackStats`]
##### 1.33.4.1. Risk

Audio underrun information could be used to form a cross-site covert
channel between two cooperating sites. One site could transmit
information by intentionally causing audio glitches (by causing very
high CPU usage, for example) while the other site could detect these
glitches.

 This covert channel depends on specific system
characteristics. It typically requires a shared linearization point
(such as an OS or browser audio mixer) and callbacks that are
effectively synchronous from that point, without intermediate buffering
that would flatten load spikes.

##### 1.33.4.2. Mitigations

To inhibit the usage of such a covert channel, the API implements these
mitigations.

- The values returned by the API MUST not be updated more than once per
 second.

- The API MUST be restricted to sites that fulfill at least one of the
 following criteria:

 1. The site has obtained
 [getUserMedia](https://w3c.github.io/mediacapture-main/#dom-mediadevices-getusermedia)
 permission.

 The reasoning is that if a site has obtained
 [getUserMedia](https://w3c.github.io/mediacapture-main/#dom-mediadevices-getusermedia)
 permission, it can receive glitch information or communicate
 efficiently through use of the microphone, making access to the
 information provided by
 [`AudioPlaybackStats`](#AudioPlaybackStats) redundant. These options include detecting
 glitches through gaps in the microphone signal, or communicating
 using human-inaudible sine waves. If microphone access is ever
 made safer in this regard, this condition should be reconsidered.

 2. The document is [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active) and its [visibility
 state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) is `"visible"`.

 Assuming that neither cooperating site has
 microphone permission, this criterion ensures that the site that
 receives the covert signal must be visible, restricting the
 conditions under which the covert channel can be used. It makes it
 impossible for sites to communicate with each other using the
 covert channel while not visible.

## 2. Processing model

### 2.1. Background

*This section is non-normative.*

Real-time audio systems that require low latency are often implemented
using *callback functions*, where the operating system calls the program
back when more audio has to be computed in order for the playback to
stay uninterrupted. Such a callback is ideally called on a high priority
thread (often the highest priority on the system). This means that a
program that deals with audio only executes code from this callback.
Crossing thread boundaries or adding some buffering between a rendering
thread and the callback would naturally add latency or make the system
less resilient to glitches.

For this reason, the traditional way of executing asynchronous
operations on the Web Platform, the event loop, does not work here, as
the thread is not *continuously executing*. Additionally, a lot of
unnecessary and potentially blocking operations are available from
traditional execution contexts (Windows and Workers), which is not
something that is desirable to reach an acceptable level of performance.

Additionally, the Worker model makes creating a dedicated thread
necessary for a script execution context, while all
[`AudioNode`](#AudioNode)s
usually share the same execution context.

 This section specifies how the end result should look
like, not how it should be implemented. In particular, instead of using
message queue, implementors can use memory that is shared between
threads, as long as the memory operations are not reordered.

### 2.2. Control Thread and Rendering Thread

The Web Audio API MUST be implemented using a [control
thread](#control-thread), and
a [rendering thread](#rendering-thread).

The [control thread] is the thread from which the
[`AudioContext`](#AudioContext) is instantiated, and from which authors manipulate the
audio graph, that is, from where the operations on a
[`BaseAudioContext`](#BaseAudioContext) are invoked. The [rendering thread] is the thread on which the
actual audio output is computed, in reaction to the calls from the
[control thread](#control-thread). It can be a real-time, callback-based audio thread, if
computing audio for an
[`AudioContext`](#AudioContext), or a normal thread if computing audio for an
[`OfflineAudioContext`](#OfflineAudioContext).

The [control thread](#control-thread) uses a traditional event loop, as described in
[\[HTML\]](#biblio-html "HTML Standard").

The [rendering thread](#rendering-thread) uses a specialized rendering loop, described in the
section [Rendering an audio graph](#rendering-loop)

Communication from the [control
thread](#control-thread) to
the [rendering thread](#rendering-thread) is done using [control
message](#control-message)
passing. Communication in the other direction is done using regular
event loop tasks.

Each [`AudioContext`](#AudioContext) has a single [control message
queue] that is a list of [control messages] that are
operations running on the [rendering
thread](#rendering-thread).

[Queuing a control message] means adding the message to
the end of the [control message
queue](#control-message-queue) of an
[`BaseAudioContext`](#BaseAudioContext).

 For example, successfuly calling `start()` on an
[`AudioBufferSourceNode`](#AudioBufferSourceNode) `source` adds a [control
message](#control-message)
to the [control message
queue](#control-message-queue) of the
associated
[`BaseAudioContext`](#BaseAudioContext).

[Control messages](#control-message) in a [control message
queue](#control-message-queue) are ordered by time of insertion. The [oldest
message]
is therefore the one at the front of the [control message
queue](#control-message-queue).

[Swapping]
a [control message
queue](#control-message-queue) `Q`~`A`~ with another [control
message queue](#control-message-queue) `Q`~`B`~ means executing the
following steps:

1. Let `Q`~`C`~ be a new, empty [control message
 queue](#control-message-queue).

2. Move all the [control
 messages](#control-message) `Q`~`A`~ to
 `Q`~`C`~.

3. Move all the [control
 messages](#control-message) `Q`~`B`~ to
 `Q`~`A`~.

4. Move all the [control
 messages](#control-message) `Q`~`C`~ to
 `Q`~`B`~.

### 2.3. Asynchronous Operations

Calling methods on [`AudioNode`](#AudioNode)s is effectively asynchronous, and MUST to be done in
two phases: a synchronous part and an asynchronous part. For each
method, some part of the execution happens on the [control
thread](#control-thread) (for
example, throwing an exception in case of invalid parameters), and some
part happens on the [rendering
thread](#rendering-thread)
(for example, changing the value of an
[`AudioParam`](#AudioParam)).

In the description of each operation on
[`AudioNode`](#AudioNode)s
and
[`BaseAudioContext`](#BaseAudioContext)s, the synchronous section is marked with a ⌛. All the
other operations are executed [in
parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel),
as described in
[\[HTML\]](#biblio-html "HTML Standard").

The synchronous section is executed on the [control
thread](#control-thread), and
happens immediately. If it fails, the method execution is aborted,
possibly throwing an exception. If it succeeds, a [control
message](#control-message),
encoding the operation to be executed on the [rendering
thread](#rendering-thread)
is enqueued on the [control message
queue](#control-message-queue) of this [rendering
thread](#rendering-thread).

The synchronous and asynchronous sections order with respect to other
events MUST be the same: given two operation `A` and
`B` with respective synchronous and asynchronous section
`A`~`Sync`~ and
`A`~`Async`~, and
`B`~`Sync`~ and
`B`~`Async`~, if `A` happens before
`B`, then `A`~`Sync`~ happens before
`B`~`Sync`~, and
`A`~`Async`~ happens before
`B`~`Async`~. In other words, synchronous and
asynchronous sections can't be reordered.

### 2.4. Supported Sample Rates

Implementations MUST support sample rates between 3000 Hz and 768000 Hz,
inclusive. A
[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) MUST be thrown if a sample rate outside this range is
specified.

### 2.5. Supported Render Quantum Sizes

Implementations MUST support
[`[[render quantum size]]`](#dom-baseaudiocontext-render-quantum-size-slot) between 1 sample frame and 6 times the context sample
rate, inclusive, rounding down to the nearest integer if 6 times the
context sample rate is not an integer. A
[`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) MUST be thrown if a
[`[[render quantum size]]`](#dom-baseaudiocontext-render-quantum-size-slot) outside this range is specified.

Note: the upper limit of 6 seconds was chosen to support applications
using the deprecated
[`ScriptProcessorNode`](#ScriptProcessorNode) interface at its highest buffer size of 16384 and the
lowest supported sample rate of 3000 Hz. For a context sample rate of
3000 Hz the supported range is \[1, 18000\]. Higher sample rates will
have a higher upper bound.

### 2.6. Rendering an Audio Graph

Audio graph rendering is done in blocks of sample-frames, with the size
of each block remaining constant for the lifetime of a
[`BaseAudioContext`](#BaseAudioContext). The number of sample-frames in a block is called
[render quantum size], and the block itself is called a [render
quantum].
Its default value is 128, and it can be configured by setting
[`renderSizeHint`](#dom-audiocontextoptions-rendersizehint).

Operations that happen [atomically] on a given thread can only be executed when
no other [atomic](#atomically)
operation is running on another thread.

The algorithm for rendering a block of audio from a
[`BaseAudioContext`](#BaseAudioContext) *G* with a [control message
queue](#control-message-queue) *Q* is
comprised of multiple steps and explained in further detail in the
algorithm of [rendering a graph](#rendering-a-graph).

The [`AudioContext`](#AudioContext) [rendering
thread](#rendering-thread)
is driven by a [system-level audio
callback], that is periodically called at regular intevals. Each call
has a [system-level audio callback buffer
size], which is a varying number of sample-frames that needs to
be computed on time before the next [system-level audio
callback](#system-level-audio-callback) arrives.

A [load value]
is computed for each [system-level audio
callback](#system-level-audio-callback), by dividing its execution duration by the
[system-level audio callback buffer
size](#system-level-audio-callback-buffer-size) divided by
[`sampleRate`](#dom-baseaudiocontext-samplerate).

Ideally the [load value](#load-value) is below 1.0, meaning that it took less time to render
the audio that it took to play it out. An [audio buffer
underrun] happens when this [load
value](#load-value) is greater
than 1.0: the system could not render audio fast enough for real-time.

The [render quantum
size](#render-quantum-size) for an audio graph is not necessarily a divisor of the
[system-level audio callback buffer
size](#system-level-audio-callback-buffer-size). This causes increased audio latencies and reduced
possible maximum load without [audio buffer
underrun](#audio-buffer-underrun).

Note that the concepts of [system-level audio
callback](#system-level-audio-callback) and [load value](#load-value) do not apply to
[`OfflineAudioContext`](#OfflineAudioContext)s.

The audio callback is also queued as a task in the [control message
queue](#control-message-queue). The UA
MUST perform the following algorithms to process render quanta to
fulfill such task by filling up the requested buffer size. Along with
the [control message
queue](#control-message-queue), each
[`AudioContext`](#AudioContext) has a regular [task
queue](https://html.spec.whatwg.org/multipage/webappapis.html#task-queue),
called its [associated task
queue] for tasks that
are posted to the rendering thread from the control thread. An
additional microtask checkpoint is performed after processing a render
quantum to run any microtasks that might have been queued during the
execution of the `process` methods of
[`AudioWorkletProcessor`](#AudioWorkletProcessor).

All tasks posted from an
[`AudioWorkletNode`](#AudioWorkletNode) are posted to the [associated task
queue](#baseaudiocontext-associated-task-queue) of its associated
[`BaseAudioContext`](#BaseAudioContext).

The following step MUST be performed once before the rendering loop
starts.

1. Set the internal slot
 [`[[current frame]]`] of the
 [`BaseAudioContext`](#BaseAudioContext) to 0. Also set
 [`currentTime`](#dom-baseaudiocontext-currenttime) to 0.

The following steps MUST be performed when rendering a render quantum.

1. Let `render result` be `false`.

2. Process the [control message
 queue](#control-message-queue).

 1. Let `Q`~`rendering`~ be an empty [control
 message
 queue](#control-message-queue). [Atomically](#atomically) [swap](#swap)
 `Q`~`rendering`~ with the current [control
 message
 queue](#control-message-queue).

 2. While there are messages in
 `Q`~`rendering`~, execute the following
 steps:

 1. Execute the asynchronous section of the [oldest
 message](#oldest-message) of `Q`~`rendering`~.

 2. Remove the [oldest
 message](#oldest-message) of `Q`~`rendering`~.

3. Process the
 [`BaseAudioContext`](#BaseAudioContext)'s [associated task
 queue](#baseaudiocontext-associated-task-queue).

 1. Let `task queue` be the
 [`BaseAudioContext`](#BaseAudioContext)'s [associated task
 queue](#baseaudiocontext-associated-task-queue).

 2. Let `task count` be the number of tasks in the in
 `task queue`

 3. While `task count` is not equal to 0, execute the
 following steps:

 1. Let `oldest task` be the first runnable task in
 `task queue`, and remove it from
 `task queue`.

 2. Set the rendering loop's currently running task to
 `oldest task`.

 3. Perform `oldest task`'s steps.

 4. Set the rendering loop currently running task back to
 `null`.

 5. Decrement `task count`

 6. Perform a microtask checkpoint.

4. Process a render quantum.

 1. If the
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) of the
 [`BaseAudioContext`](#BaseAudioContext) is not `running`, return false.

 2. Order the [`AudioNode`](#AudioNode)s of the
 [`BaseAudioContext`](#BaseAudioContext) to be processed.

 1. Let `ordered node list` be an empty list of
 [`AudioNode`](#AudioNode)s and
 [`AudioListener`](#AudioListener). It will contain an ordered list of
 [`AudioNode`](#AudioNode)s and the
 [`AudioListener`](#AudioListener) when this ordering algorithm terminates.

 2. Let `nodes` be the set of all nodes created by
 this
 [`BaseAudioContext`](#BaseAudioContext), and still alive.

 3. Add the
 [`AudioListener`](#AudioListener) to `nodes`.

 4. Let `cycle breakers` be an empty set of
 [`DelayNode`](#DelayNode)s. It will contain all the
 [`DelayNode`](#DelayNode)s that are part of a cycle.

 5. For each
 [`AudioNode`](#AudioNode) `node` in `nodes`:

 1. If `node` is a
 [`DelayNode`](#DelayNode) that is part of a cycle, add it to
 `cycle breakers` and remove it from
 `nodes`.

 6. For each
 [`DelayNode`](#DelayNode) `delay` in
 `cycle breakers`:

 1. Let `delayWriter` and
 `delayReader` respectively be a
 [DelayWriter](#delaywriter) and a
 [DelayReader](#delayreader), for `delay`. Add
 `delayWriter` and `delayReader` to
 `nodes`. Disconnect `delay` from
 all its input and outputs.

 This breaks the cycle: if a `DelayNode`
 is in a cycle, its two ends can be considered
 separately, because delay lines cannot be smaller than
 one render quantum when in a cycle.

 7. If `nodes` contains cycles,
 [mute](#mute) all the
 [`AudioNode`](#AudioNode)s that are part of this cycle, and remove
 them from `nodes`.

 8. Consider all elements in `nodes` to be unmarked.
 While there are unmarked elements in `nodes`:

 1. Choose an element `node` in
 `nodes`.

 2. [Visit](#visit)
 `node`.

 :::
 [Visiting a node] means performing the following
 steps:
 1. If `node` is marked, abort these steps.

 2. Mark `node`.

 3. If `node` is an
 [`AudioNode`](#AudioNode), [Visit](#visit) each
 [`AudioNode`](#AudioNode) connected to the input of
 `node`.

 4. For each
 [`AudioParam`](#AudioParam) `param` of
 `node`:

 1. For each
 [`AudioNode`](#AudioNode) `param input node`
 connected to `param`:

 1. [Visit](#visit)
 `param input node`

 5. Add `node` to the beginning of
 `ordered node list`.
 :::

 9. Reverse the order of `ordered node list`.

 3. [Compute the value(s)](#computation-of-value) of the
 [`AudioListener`](#AudioListener)'s
 [`AudioParam`](#AudioParam)s for this block.

 4. For each [`AudioNode`](#AudioNode), in `ordered node list`:

 1. For each
 [`AudioParam`](#AudioParam) of this
 [`AudioNode`](#AudioNode), execute these steps:

 1. If this
 [`AudioParam`](#AudioParam) has any
 [`AudioNode`](#AudioNode) connected to it,
 [sum](#channel-up-mixing-and-down-mixing) the buffers
 [made available for
 reading](#available-for-reading) by all
 [`AudioNode`](#AudioNode) connected to this
 [`AudioParam`](#AudioParam), [down mix](#down-mix) the resulting
 buffer down to a mono channel, and call this buffer the
 [ input AudioParam buffer].

 2. [Compute the value(s)](#computation-of-value) of this
 [`AudioParam`](#AudioParam) for this block.

 3. [Queue a control message](#queuing) to set the
 [`[[current value]]`](#dom-audioparam-current-value-slot) slot of this
 [`AudioParam`](#AudioParam) according to [§ 1.6.3 Computation of
 Value](#computation-of-value).

 2. If this
 [`AudioNode`](#AudioNode) has any
 [`AudioNode`](#AudioNode)s connected to its input,
 [sum](#channel-up-mixing-and-down-mixing) the buffers [made
 available for
 reading](#available-for-reading) by all
 [`AudioNode`](#AudioNode)s connected to this
 [`AudioNode`](#AudioNode). The resulting buffer is called the [input
 buffer]. [Up or
 down-mix](#channel-up-mixing-and-down-mixing) it to match if
 number of input channels of this
 [`AudioNode`](#AudioNode).

 3. If this
 [`AudioNode`](#AudioNode) is a [source
 node](#source-node),
 [compute a block of
 audio](#computing-a-block-of-audio), and [make it available for
 reading](#available-for-reading).

 4. If this
 [`AudioNode`](#AudioNode) is an
 [`AudioWorkletNode`](#AudioWorkletNode), execute these substeps:

 1. Let `processor` be the associated
 [`AudioWorkletProcessor`](#AudioWorkletProcessor) instance of
 [`AudioWorkletNode`](#AudioWorkletNode).

 2. Let `O` be the ECMAScript object
 corresponding to `processor`.

 3. Let `processCallback` be an uninitialized
 variable.

 4. Let `completion` be an uninitialized
 variable.

 5. [Prepare to run
 script](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-script) with the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object).

 6. [Prepare to run a
 callback](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-a-callback) with the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object).

 7. Let `getResult` be
 [Get](https://tc39.github.io/ecma262/#sec-get-o-p)(`O`,
 \"process\").

 8. If `getResult` is an [abrupt
 completion](https://tc39.github.io/ecma262/#sec-completion-record-specification-type),
 set `completion` to `getResult`
 and jump to the step labeled
 [return](#audio-worklet-render-return).

 9. Set `processCallback` to
 `getResult`.\[\[Value\]\].

 10. If
 [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands)
 [IsCallable](https://tc39.es/ecma262/#sec-iscallable)(`processCallback`)
 is `false`, then:

 1. Set `completion` to new
 [Completion](https://tc39.es/ecma262/#sec-throwcompletion)
 {\[\[Type\]\]: throw, \[\[Value\]\]: a newly created
 [TypeError](https://tc39.es/ecma262/#sec-native-error-types-used-in-this-standard-typeerror)
 object, \[\[Target\]\]: empty}.

 2. Jump to the step labeled
 [return](#audio-worklet-render-return).

 11. Set
 [`[[callable process]]`](#dom-audioworkletprocessor-callable-process-slot) to `true`.

 12. Perform the following substeps:

 1. Let `args` be a [Web IDL arguments
 list](https://webidl.spec.whatwg.org/#web-idl-arguments-list)
 consisting of
 [`inputs`](#dom-audioworkletprocesscallback-inputs),
 [`outputs`](#dom-audioworkletprocesscallback-outputs), and
 [`parameters`](#dom-audioworkletprocesscallback-parameters).

 2. Let `esArgs` be the result of
 [converting](https://webidl.spec.whatwg.org/#web-idl-arguments-list-converting)
 `args` to an ECMAScript arguments list.

 3. Let `callResult` be the
 [Call](https://tc39.github.io/ecma262/#sec-call)(`processCallback`,
 `O`, `esArgs`). This operation
 [computes a block of
 audio](#computing-a-block-of-audio) with `esArgs`. Upon a
 successful function call, a buffer containing copies
 of the elements of the
 [`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array)s passed via the
 [`outputs`](#dom-audioworkletprocesscallback-outputs) is [made available for
 reading](#available-for-reading). Any
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) resolved within this call will be
 queued into the microtask queue in the
 [`AudioWorkletGlobalScope`](#AudioWorkletGlobalScope).

 4. If `callResult` is an [abrupt
 completion](https://tc39.github.io/ecma262/#sec-completion-record-specification-type),
 set `completion` to
 `callResult` and jump to the step labeled
 [return](#audio-worklet-render-return).

 5. Set `processor`'s [active
 source](#active-source) flag to
 [ToBoolean](https://tc39.github.io/ecma262/#sec-toboolean)(`callResult`.\[\[Value\]\]).

 13. **Return:** at this point `completion` will
 be set to an ECMAScript
 [completion](https://tc39.es/ecma262/#sec-completion-record-specification-type)
 value.

 1. [Clean up after running a
 callback](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-a-callback) with the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object).

 2. [Clean up after running
 script](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-script) with the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object).

 3. If `completion` is an [abrupt
 completion](https://tc39.github.io/ecma262/#sec-completion-record-specification-type):

 1. Set
 [`[[callable process]]`](#dom-audioworkletprocessor-callable-process-slot) to `false`.

 2. Set `processor`'s [active
 source](#active-source) flag to `false`.

 3. [Make a silent output buffer available for
 reading](#available-for-reading).

 4. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to the [control
 thread](#control-thread) to [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`processorerror`](#eventdef-audioworkletnode-processorerror) at the associated
 [`AudioWorkletNode`](#AudioWorkletNode) using
 [`ErrorEvent`](https://html.spec.whatwg.org/multipage/webappapis.html#errorevent).

 5. If this
 [`AudioNode`](#AudioNode) is a [destination
 node](#destination-node), [record the
 input](#recording-the-input) of this
 [`AudioNode`](#AudioNode).

 6. Else,
 [process](#processing-an-input-buffer) the [input
 buffer](#input-buffer), and [make available for
 reading](#available-for-reading) the resulting buffer.

 5. [Atomically](#atomically)
 perform the following steps:

 1. Increment
 [`[[current frame]]`](#dom-baseaudiocontext-current-frame-slot) by the [render quantum
 size](#render-quantum-size).

 2. Set
 [`currentTime`](#dom-baseaudiocontext-currenttime) to
 [`[[current frame]]`](#dom-baseaudiocontext-current-frame-slot) divided by
 [`sampleRate`](#dom-baseaudiocontext-samplerate).

 6. Set `render result` to `true`.

5. [Perform a microtask
 checkpoint](https://html.spec.whatwg.org/multipage/webappapis.html#perform-a-microtask-checkpoint).

6. Return `render result`.

[Muting] an
[`AudioNode`](#AudioNode)
means that its output MUST be silence for the rendering of this audio
block.

[Making a buffer available for reading] from an
[`AudioNode`](#AudioNode)
means putting it in a state where other
[`AudioNode`](#AudioNode)s
connected to this [`AudioNode`](#AudioNode) can safely read from it.

 For example, implementations can choose to allocate a
new buffer, or have a more elaborate mechanism, reusing an existing
buffer that is now unused.

[Recording the input] of an
[`AudioNode`](#AudioNode)
means copying the input data of this
[`AudioNode`](#AudioNode)
for future usage.

[Computing a block of audio] means running the algorithm for
this [`AudioNode`](#AudioNode) to produce
[`[[render quantum size]]`](#dom-baseaudiocontext-render-quantum-size-slot) sample-frames.

[Processing an input buffer] means running the algorithm for
an [`AudioNode`](#AudioNode), using an [input
buffer](#input-buffer) and the
value(s) of the [`AudioParam`](#AudioParam)(s) of this
[`AudioNode`](#AudioNode)
as the input for this algorithm.

### 2.7. Handling an interruption on the [`AudioContext`]
An [interruption] is an event generated by the user agent when it needs to
halt audio playback for an
[`AudioContext`](#AudioContext). For example, The user agent may create an interruption
when another application requests exclusive access to the audio output
hardware.

When an [interruption](#interruption) happens, the user agent MUST [queue a control
message](#queuing) to interrupt the
[`AudioContext`](#AudioContext).

Running a [control message](#control-message) to
[`interrupt an `[`AudioContext`](#AudioContext)] `context` means running these steps
on the [rendering thread](#rendering-thread):

1. If the `context`'s
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) is
 [`closed`](#dom-audiocontextstate-closed) or
 [`interrupted`](#dom-audiocontextstate-interrupted), abort these steps.

2. If the `context`'s
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) is
 [`running`](#dom-audiocontextstate-running):

 1. Attempt to [release system
 resources](#releasing).

 2. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to execute the following steps:

 1. Set the `context`'s
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) to
 [`interrupted`](#dom-audiocontextstate-interrupted).

 2. Set the `context`'s
 [`[[state before interruption]]`](#dom-baseaudiocontext-state-before-interruption-slot) slot to
 \"[`running`](#dom-audiocontextstate-running)\".

 3. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`statechange`](#eventdef-baseaudiocontext-statechange) at the `context`.

3. If the `context`'s
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) is
 [`suspended`](#dom-audiocontextstate-suspended):

 1. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to execute the following steps:

 1. Set the `context`'s
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) to
 [`interrupted`](#dom-audiocontextstate-interrupted).

 2. Set the `context`'s
 [`[[state before interruption]]`](#dom-baseaudiocontext-state-before-interruption-slot) slot to
 \"[`suspended`](#dom-audiocontextstate-suspended)\".

4. Set the `context`'s
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) to
 [`interrupted`](#dom-audiocontextstate-interrupted).

 If the
[`AudioContext`](#AudioContext) is
[`suspended`](#dom-audiocontextstate-suspended) a
[`statechange`](#eventdef-baseaudiocontext-statechange) event is not fired for privacy reasons to avoid
over-sharing user activity - e.g. when a phone call comes in or when the
screen gets locked.

When an [interruption](#interruption) ends, the user agent MUST [queue a control
message](#queuing) to
[`end the `[`AudioContext`](#AudioContext)` interruption`].

Running a [control message](#control-message) to end an
[`AudioContext`](#AudioContext) `context`
[interruption](#interruption)
means running these steps on the [rendering
thread](#rendering-thread):

1. If the `context`'s
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) is not
 [`interrupted`](#dom-audiocontextstate-interrupted), abort these steps.

2. If the `context`'s
 [`[[state before interruption]]`](#dom-baseaudiocontext-state-before-interruption-slot) is
 \"[`running`](#dom-audiocontextstate-running)\":

 1. Attempt to [acquire system
 resources](#acquiring).

 2. Set the
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) on the
 [`AudioContext`](#AudioContext) to
 \"[`running`](#dom-audiocontextstate-running)\".

 3. Start [rendering the audio graph](#rendering-loop).

 4. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to execute the following steps:

 1. If the
 [`state`](#dom-baseaudiocontext-state) attribute of the
 [`AudioContext`](#AudioContext) is not already
 \"[`running`](#dom-audiocontextstate-running)\":

 1. Set the `context`'s
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) to
 \"[`running`](#dom-audiocontextstate-running)\".

 2. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`statechange`](#eventdef-baseaudiocontext-statechange) at the `context`.

3. If the `context`'s
 [`[[state before interruption]]`](#dom-baseaudiocontext-state-before-interruption-slot) is
 \"[`suspended`](#dom-audiocontextstate-suspended)\"

 1. Set the
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) on the
 [`AudioContext`](#AudioContext) to `suspended`.

 2. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to execute the following steps:

 1. Set the `context`'s
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) to `suspended`.

4. Set the `context`'s
 [`[[state before interruption]]`](#dom-baseaudiocontext-state-before-interruption-slot) to `null`.

### 2.8. Handling an error from System Audio Resources on the [`AudioContext`]
The [`AudioContext`](#AudioContext) `audioContext` performs the following steps
on [rendering thread](#rendering-thread) in the event of an audio system resource error.

1. If the `audioContext`'s
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) is `running` or `interrupted`:

 1. Attempt to [release system
 resources](#releasing).

 2. Set the `audioContext`'s
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) to `suspended`.

 3. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task) to execute the following steps:

 1. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`error`](#eventdef-audiocontext-error) at `audioContext`.

 2. Set the `audioContext`'s
 [`[[suspended by user]]`](#dom-audiocontext-suspended-by-user-slot) to `false`.

 3. Set the `audioContext`'s
 [`[[control thread state]]`](#dom-baseaudiocontext-control-thread-state-slot) to `suspended`.

 4. Set the `audioContext`'s
 [`state`](#dom-baseaudiocontext-state) attribute to
 \"[`suspended`](#dom-audiocontextstate-suspended)\".

 5. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`statechange`](#eventdef-baseaudiocontext-statechange) at the `audioContext`.

 4. Abort these steps.

2. If the `audioContext`'s
 [`[[rendering thread state]]`](#dom-baseaudiocontext-rendering-thread-state-slot) is `suspended`:

 1. [Queue a media element
 task](https://html.spec.whatwg.org/multipage/media.html#queue-a-media-element-task)to execute the following steps:

 1. [Fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) named
 [`error`](#eventdef-audiocontext-error) at `audioContext`.

 An example of system audio resource errors would be
when an external or wireless audio device becoming disconnected during
the active rendering of the
[`AudioContext`](#AudioContext).

### 2.9. Unloading a document

Additional [unloading document cleanup
steps](https://html.spec.whatwg.org/#unloading-document-cleanup-steps)
are defined for documents that use
[`BaseAudioContext`](#BaseAudioContext):

1. Reject all the promises of
 [`[[pending promises]]`](#dom-baseaudiocontext-pending-promises-slot) with `InvalidStateError`, for each
 [`AudioContext`](#AudioContext) and
 [`OfflineAudioContext`](#OfflineAudioContext) whose relevant global object is the same as the
 document's associated Window.

2. Stop all
 [`decoding thread`](#dom-baseaudiocontext-decoding-thread)s.

3. [Queue a control message](#queuing) to
 [`close()`](#dom-audiocontext-close) the
 [`AudioContext`](#AudioContext) or
 [`OfflineAudioContext`](#OfflineAudioContext).

## 3. Dynamic Lifetime

### 3.1. Background

 The normative description of
[`AudioContext`](#AudioContext) and
[`AudioNode`](#AudioNode)
lifetime characteristics is described by the [AudioContext
lifetime](#lifetime-AudioContext) and [AudioNode
lifetime](#AudioNode-actively-processing).

*This section is non-normative.*

In addition to allowing the creation of static routing configurations,
it should also be possible to do custom effect routing on dynamically
allocated voices which have a limited lifetime. For the purposes of this
discussion, let's call these short-lived voices \"notes\". Many audio
applications incorporate the ideas of notes, examples being drum
machines, sequencers, and 3D games with many one-shot sounds being
triggered according to game play.

In a traditional software synthesizer, notes are dynamically allocated
and released from a pool of available resources. The note is allocated
when a MIDI note-on message is received. It is released when the note
has finished playing either due to it having reached the end of its
sample-data (if non-looping), it having reached a sustain phase of its
envelope which is zero, or due to a MIDI note-off message putting it
into the release phase of its envelope. In the MIDI note-off case, the
note is not released immediately, but only when the release envelope
phase has finished. At any given time, there can be a large number of
notes playing but the set of notes is constantly changing as new notes
are added into the routing graph, and old ones are released.

The audio system automatically deals with tearing-down the part of the
routing graph for individual \"note\" events. A \"note\" is represented
by an
[`AudioBufferSourceNode`](#AudioBufferSourceNode), which can be directly connected to other processing
nodes. When the note has finished playing, the context will
automatically release the reference to the
[`AudioBufferSourceNode`](#AudioBufferSourceNode), which in turn will release references to any nodes it
is connected to, and so on. The nodes will automatically get
disconnected from the graph and will be deleted when they have no more
references. Nodes in the graph which are long-lived and shared between
dynamic voices can be managed explicitly. Although it sounds
complicated, this all happens automatically with no extra handling
required.

### 3.2. Example

![A graph featuring a subgraph that will be released
early.](images/dynamic-allocation.png){a
height="221" width="671"}

The low-pass filter, panner, and second gain nodes are directly
connected from the one-shot sound. So when it has finished playing the
context will automatically release them (everything within the dotted
line). If there are no longer any references to the one-shot sound and
connected nodes, then they will be immediately removed from the graph
and deleted. The streaming source has a global reference and will remain
connected until it is explicitly disconnected. Here's how it might look
in JavaScript:

```
let context = 0;let compressor = 0;let gainNode1 = 0;let streamingAudioSource = 0;// Initial setup of the "long-lived" part of the routing graphfunction setupAudioContext() { context = new AudioContext(); compressor = context.createDynamicsCompressor(); gainNode1 = context.createGain(); // Create a streaming audio source. const audioElement = document.getElementById('audioTagID'); streamingAudioSource = context.createMediaElementSource(audioElement); streamingAudioSource.connect(gainNode1); gainNode1.connect(compressor); compressor.connect(context.destination);}// Later in response to some user action (typically mouse or key event)// a one-shot sound can be played.function playSound() { const oneShotSound = context.createBufferSource(); oneShotSound.buffer = dogBarkingBuffer; // Create a filter, panner, and gain node. const lowpass = context.createBiquadFilter(); const panner = context.createPanner(); const gainNode2 = context.createGain(); // Make connections oneShotSound.connect(lowpass); lowpass.connect(panner); panner.connect(gainNode2); gainNode2.connect(compressor); // Play 0.75 seconds from now (to play immediately pass in 0) oneShotSound.start(context.currentTime + 0.75);}
```

## 4. Channel Up-Mixing and Down-Mixing

*This section is normative.*

An AudioNode input has [mixing rules] for combining the channels from all of the
connections to it. As a simple example, if an input is connected from a
mono output and a stereo output, then the mono connection will usually
be up-mixed to stereo and summed with the stereo connection. But, of
course, it's important to define the exact [mixing
rules](#mixing-rules) for every
input to every [`AudioNode`](#AudioNode). The default mixing rules for all of the inputs have
been chosen so that things \"just work\" without worrying too much about
the details, especially in the very common case of mono and stereo
streams. Of course, the rules can be changed for advanced use cases,
especially multi-channel.

To define some terms, [up-mixing] refers to the process of taking a stream
with a smaller number of channels and converting it to a stream with a
larger number of channels. [down-mixing] refers to the process of taking a stream
with a larger number of channels and converting it to a stream with a
smaller number of channels.

An [`AudioNode`](#AudioNode) input needs to mix all the outputs connected to this
input. As part of this process it computes an internal value
[computedNumberOfChannels](#computednumberofchannels) representing the actual number of channels of the input
at any given time.

For each input of an
[`AudioNode`](#AudioNode),
an implementation MUST:

1. Compute
 [computedNumberOfChannels](#computednumberofchannels).

2. For each connection to the input:

 1. [up-mix](#up-mixing) or
 [down-mix](#down-mixing)
 the connection to
 [computedNumberOfChannels](#computednumberofchannels) according to the
 [`ChannelInterpretation`](#enumdef-channelinterpretation) value given by the node's
 [`channelInterpretation`](#dom-audionode-channelinterpretation) attribute.

 2. Mix it together with all of the other mixed streams (from other
 connections). This is a straight-forward summing together of
 each of the corresponding channels that have been
 [up-mixed](#up-mixing) or
 [down-mixed](#down-mixing) in step 1 for each connection.

### 4.1. Speaker Channel Layouts

When
[`channelInterpretation`](#dom-audionode-channelinterpretation) is
\"[`speakers`](#dom-channelinterpretation-speakers)\" then the [up-mixing](#up-mixing) and [down-mixing](#down-mixing) is defined for specific channel layouts.

Mono (one channel), stereo (two channels), quad (four channels), and 5.1
(six channels) MUST be supported. Other channel layouts may be supported
in future version of this specification.

### 4.2. Channel Ordering

Channel ordering is defined by the following table. Individual
multichannel formats MAY not support all intermediate channels.
Implementations MUST present the channels provided in the order defined
below, skipping over those channels not present.

Order

Label

Mono

Stereo

Quad

5.1

0

SPEAKER_FRONT_LEFT

0

0

0

0

1

SPEAKER_FRONT_RIGHT

1

1

1

2

SPEAKER_FRONT_CENTER

2

3

SPEAKER_LOW_FREQUENCY

3

4

SPEAKER_BACK_LEFT

2

4

5

SPEAKER_BACK_RIGHT

3

5

6

SPEAKER_FRONT_LEFT_OF_CENTER

7

SPEAKER_FRONT_RIGHT_OF_CENTER

8

SPEAKER_BACK_CENTER

9

SPEAKER_SIDE_LEFT

10

SPEAKER_SIDE_RIGHT

11

SPEAKER_TOP_CENTER

12

SPEAKER_TOP_FRONT_LEFT

13

SPEAKER_TOP_FRONT_CENTER

14

SPEAKER_TOP_FRONT_RIGHT

15

SPEAKER_TOP_BACK_LEFT

16

SPEAKER_TOP_BACK_CENTER

17

SPEAKER_TOP_BACK_RIGHT

### 4.3. Implication of tail-time on input and output channel count

When an [`AudioNode`](#AudioNode) has a non-zero
[tail-time](#tail-time), and an
output channel count that depends on the input channels count, the
[`AudioNode`](#AudioNode)'s
[tail-time](#tail-time) must be
taken into account when the input channel count changes.

When there is a decrease in input channel count, the change in output
channel count MUST happen when the input that was received with greater
channel count no longer affects the output.

When there is an increase in input channel count, the behavior depends
on the [`AudioNode`](#AudioNode) type:

- For a [`DelayNode`](#DelayNode) or a
 [`DynamicsCompressorNode`](#DynamicsCompressorNode), the number of output channels MUST increase when the
 input that was received with greater channel count begins to affect
 the output.

- For other [`AudioNode`](#AudioNode)s that have a
 [tail-time](#tail-time), the
 number of output channels MUST increase immediately.

 For a
 [`ConvolverNode`](#ConvolverNode), this only applies to the case where the impulse
 response is mono. Otherwise, the
 [`ConvolverNode`](#ConvolverNode) always outputs a stereo signal regardless of its
 input channel count.

 Intuitively, this allows not losing stereo information
as part of processing: when multiple input render quanta of different
channel count contribute to an output render quantum then the output
render quantum's channel count is a superset of the input channel count
of the input render quantums.

### 4.4. Up Mixing Speaker Layouts

 Mono up-mix:

 1 -> 2 : up-mix from mono to stereo
 output.L = input;
 output.R = input;

 1 -> 4 : up-mix from mono to quad
 output.L = input;
 output.R = input;
 output.SL = 0;
 output.SR = 0;

 1 -> 5.1 : up-mix from mono to 5.1
 output.L = 0;
 output.R = 0;
 output.C = input; // put in center channel
 output.LFE = 0;
 output.SL = 0;
 output.SR = 0;

 Stereo up-mix:

 2 -> 4 : up-mix from stereo to quad
 output.L = input.L;
 output.R = input.R;
 output.SL = 0;
 output.SR = 0;

 2 -> 5.1 : up-mix from stereo to 5.1
 output.L = input.L;
 output.R = input.R;
 output.C = 0;
 output.LFE = 0;
 output.SL = 0;
 output.SR = 0;

 Quad up-mix:

 4 -> 5.1 : up-mix from quad to 5.1
 output.L = input.L;
 output.R = input.R;
 output.C = 0;
 output.LFE = 0;
 output.SL = input.SL;
 output.SR = input.SR;

### 4.5. Down Mixing Speaker Layouts

A down-mix will be necessary, for example, if processing 5.1 source
material, but playing back stereo.

 Mono down-mix:

 2 -> 1 : stereo to mono
 output = 0.5 * (input.L + input.R);

 4 -> 1 : quad to mono
 output = 0.25 * (input.L + input.R + input.SL + input.SR);

 5.1 -> 1 : 5.1 to mono
 output = sqrt(0.5) * (input.L + input.R) + input.C + 0.5 * (input.SL + input.SR)

 Stereo down-mix:

 4 -> 2 : quad to stereo
 output.L = 0.5 * (input.L + input.SL);
 output.R = 0.5 * (input.R + input.SR);

 5.1 -> 2 : 5.1 to stereo
 output.L = L + sqrt(0.5) * (input.C + input.SL)
 output.R = R + sqrt(0.5) * (input.C + input.SR)

 Quad down-mix:

 5.1 -> 4 : 5.1 to quad
 output.L = L + sqrt(0.5) * input.C
 output.R = R + sqrt(0.5) * input.C
 output.SL = input.SL
 output.SR = input.SR

### 4.6. Channel Rules Examples

```
// Set gain node to explicit 2-channels (stereo).gain.channelCount = 2;gain.channelCountMode = "explicit";gain.channelInterpretation = "speakers";// Set "hardware output" to 4-channels for DJ-app with two stereo output busses.context.destination.channelCount = 4;context.destination.channelCountMode = "explicit";context.destination.channelInterpretation = "discrete";// Set "hardware output" to 8-channels for custom multi-channel speaker array// with custom matrix mixing.context.destination.channelCount = 8;context.destination.channelCountMode = "explicit";context.destination.channelInterpretation = "discrete";// Set "hardware output" to 5.1 to play an HTMLAudioElement.context.destination.channelCount = 6;context.destination.channelCountMode = "explicit";context.destination.channelInterpretation = "speakers";// Explicitly down-mix to mono.gain.channelCount = 1;gain.channelCountMode = "explicit";gain.channelInterpretation = "speakers";
```

## 5. Audio Signal Values

### 5.1. Audio sample format

[Linear pulse code modulation] (linear PCM) describes a
format where the audio values are sampled at a regular interval, and
where the quantization levels between two successive values are linearly
uniform.

Whenever signal values are exposed to script in this specification, they
are in linear 32-bit floating point pulse code modulation format (linear
32-bit float PCM), often in the form of
[`Float32Array`](https://webidl.spec.whatwg.org/#idl-Float32Array) objects.

### 5.2. Rendering

The range of all audio signals at a destination node of any audio graph
is nominally \[-1, 1\]. The audio rendition of signal values outside
this range, or of the values `NaN`, positive infinity or negative
infinity, is undefined by this specification.

## 6. Spatialization/Panning

### 6.1. Background

A common feature requirement for modern 3D games is the ability to
dynamically spatialize and move multiple audio sources in 3D space. For
example [OpenAL](https://openal.org) has this ability.

Using a [`PannerNode`](#PannerNode), an audio stream can be spatialized or positioned in
space relative to an
[`AudioListener`](#AudioListener). A
[`BaseAudioContext`](#BaseAudioContext) will contain a single
[`AudioListener`](#AudioListener). Both panners and listeners have a position in 3D space
using a right-handed cartesian coordinate system. The units used in the
coordinate system are not defined, and do not need to be because the
effects calculated with these coordinates are independent/invariant of
any particular units such as meters or feet.
[`PannerNode`](#PannerNode)
objects (representing the source stream) have an *orientation* vector
representing in which direction the sound is projecting. Additionally,
they have a *sound cone* representing how directional the sound is. For
example, the sound could be omnidirectional, in which case it would be
heard anywhere regardless of its orientation, or it can be more
directional and heard only if it is facing the listener.
[`AudioListener`](#AudioListener) objects (representing a person's ears) have
[forward](#audiolistener-forward) and [up](#audiolistener-up) vectors representing in which direction the person is
facing.

The coordinate system for spatialization is shown in the diagram below,
with the default values shown. The locations for the
[`AudioListener`](#AudioListener) and
[`PannerNode`](#PannerNode)
are moved from the default positions so we can see things better.

![Diagram of the coordinate system with AudioListener and PannerNode
attributes shown.](images/panner-coord.svg){a}

During rendering, the
[`PannerNode`](#PannerNode)
calculates an *azimuth* and *elevation*. These values are used
internally by the implementation in order to render the spatialization
effect. See the [Panning Algorithm](#Spatialization-panning-algorithm)
section for details of how these values are used.

### 6.2. Azimuth and Elevation

The following algorithm MUST be used to calculate the *azimuth* and
*elevation* for the
[`PannerNode`](#PannerNode). The implementation must appropriately account for
whether the various
[`AudioParam`](#AudioParam)s below are
\"[`a-rate`](#dom-automationrate-a-rate)\" or
\"[`k-rate`](#dom-automationrate-k-rate)\".

```
// Let |context| be a BaseAudioContext and let |panner| be a// PannerNode created in |context|.// Calculate the source-listener vector.const listener = context.listener;const sourcePosition = new Vec3(panner.positionX.value, panner.positionY.value, panner.positionZ.value);const listenerPosition = new Vec3(listener.positionX.value, listener.positionY.value, listener.positionZ.value);const sourceListener = sourcePosition.diff(listenerPosition).normalize();if (sourceListener.magnitude == 0) { // Handle degenerate case if source and listener are at the same point. azimuth = 0; elevation = 0; return;}// Align axes.const listenerForward = new Vec3(listener.forwardX.value, listener.forwardY.value, listener.forwardZ.value);const listenerUp = new Vec3(listener.upX.value, listener.upY.value, listener.upZ.value);const listenerRight = listenerForward.cross(listenerUp);if (listenerRight.magnitude == 0) { // Handle the case where listener's 'up' and 'forward' vectors are linearly // dependent, in which case 'right' cannot be determined azimuth = 0; elevation = 0; return;}// Determine a unit vector orthogonal to listener's right, forwardconst listenerRightNorm = listenerRight.normalize();const listenerForwardNorm = listenerForward.normalize();const up = listenerRightNorm.cross(listenerForwardNorm);const upProjection = sourceListener.dot(up);const projectedSource = sourceListener.diff(up.scale(upProjection)).normalize();azimuth = 180 * Math.acos(projectedSource.dot(listenerRightNorm)) / Math.PI;// Source in front or behind the listener.const frontBack = projectedSource.dot(listenerForwardNorm);if (frontBack < 0) azimuth = 360 - azimuth;// Make azimuth relative to "forward" and not "right" listener vector.if ((azimuth >= 0) && (azimuth <= 270)) azimuth = 90 - azimuth;else azimuth = 450 - azimuth;elevation = 90 - 180 * Math.acos(sourceListener.dot(up)) / Math.PI;if (elevation > 90) elevation = 180 - elevation;else if (elevation < -90) elevation = -180 - elevation;
```

### 6.3. Panning Algorithm

*Mono-to-stereo* and *stereo-to-stereo* panning MUST be supported.
*Mono-to-stereo* processing is used when all connections to the input
are mono. Otherwise *stereo-to-stereo* processing is used.

#### 6.3.1. PannerNode \"equalpower\" Panning

This is a simple and relatively inexpensive algorithm which provides
basic, but reasonable results. It is used for the
[`PannerNode`](#PannerNode)
when the
[`panningModel`](#dom-pannernode-panningmodel) attribute is set to
\"[`equalpower`](#dom-panningmodeltype-equalpower)\", in which case the *elevation* value is ignored. This
algorithm MUST be implemented using the appropriate rate as specified by
the
[`automationRate`](#dom-audioparam-automationrate). If any of the
[`PannerNode`](#PannerNode)'s
[`AudioParam`](#AudioParam)s or the
[`AudioListener`](#AudioListener)'s
[`AudioParam`](#AudioParam)s are
\"[`a-rate`](#dom-automationrate-a-rate)\", [a-rate](#a-rate)
processing must be used.

1. For each sample to be computed by this
 [`AudioNode`](#AudioNode):

 1. Let `azimuth` be the value computed in the [azimuth
 and elevation](#azimuth-elevation) section.

 2. The `azimuth` value is first contained to be within
 the range \[-90, 90\] according to:

 ``` highlight
 // First, clamp azimuth to allowed range of [-180, 180].
 azimuth = max(-180, azimuth);
 azimuth = min(180, azimuth);

 // Then wrap to range [-90, 90].
 if (azimuth < -90)
 azimuth = -180 - azimuth;
 else if (azimuth > 90)
 azimuth = 180 - azimuth;
 ```

 3. A normalized value *x* is calculated from `azimuth`
 for a mono input as:

 ``` highlight
 x = (azimuth + 90) / 180;
 ```

 Or for a stereo input as:

 ``` highlight
 if (azimuth <= 0) { // -90 -> 0
 // Transform the azimuth value from [-90, 0] degrees into the range [-90, 90].
 x = (azimuth + 90) / 90;
 } else { // 0 -> 90
 // Transform the azimuth value from [0, 90] degrees into the range [-90, 90].
 x = azimuth / 90;
 }
 ```

 4. Left and right gain values are calculated as:

 ``` highlight
 gainL = cos(x * Math.PI / 2);
 gainR = sin(x * Math.PI / 2);
 ```

 5. For mono input, the stereo output is calculated as:

 ``` highlight
 outputL = input * gainL;
 outputR = input * gainR;
 ```

 Else for stereo input, the output is calculated as:

 ``` highlight
 if (azimuth <= 0) {
 outputL = inputL + inputR * gainL;
 outputR = inputR * gainR;
 } else {
 outputL = inputL * gainL;
 outputR = inputR + inputL * gainR;
 }
 ```

 6. Apply the distance gain and cone gain where the computation of
 the distance is described in [Distance
 Effects](#Spatialization-distance-effects) and the cone gain is
 described in [Sound Cones](#Spatialization-sound-cones):

 ``` highlight
 let distance = distance();
 let distanceGain = distanceModel(distance);
 let totalGain = coneGain() * distanceGain();
 outputL = totalGain * outputL;
 outputR = totalGain * outputR;
 ```

#### 6.3.2. PannerNode \"HRTF\" Panning (Stereo Only)

This requires a set of
[HRTF](https://en.wikipedia.org/wiki/Head-related_transfer_function)
(Head-related Transfer Function) impulse responses recorded at a variety
of azimuths and elevations. The implementation requires a highly
optimized convolution function. It is somewhat more costly than
\"equalpower\", but provides more perceptually spatialized sound.

![A diagram showing the process of panning a source using
HRTF.](images/HRTF_panner.png){height="419" width="644"}

#### 6.3.3. StereoPannerNode Panning

For a
[`StereoPannerNode`](#stereopannernode), the following algorithm MUST be implemented.

1. For each sample to be computed by this
 [`AudioNode`](#AudioNode)

 1. Let `pan` be the
 [computedValue](#computedvalue) of the `pan`
 [`AudioParam`](#AudioParam) of this
 [`StereoPannerNode`](#stereopannernode).

 2. Clamp `pan` to \[-1, 1\].

 ``` highlight
 pan = max(-1, pan);
 pan = min(1, pan);
 ```

 3. Calculate *x* by normalizing `pan` value to \[0, 1\].
 For mono input:

 ``` highlight
 x = (pan + 1) / 2;
 ```

 For stereo input:

 ``` highlight
 if (pan <= 0)
 x = pan + 1;
 else
 x = pan;
 ```

 4. Left and right gain values are calculated as:

 ``` highlight
 gainL = cos(x * Math.PI / 2);
 gainR = sin(x * Math.PI / 2);
 ```

 5. For mono input, the stereo output is calculated as:

 ``` highlight
 outputL = input * gainL;
 outputR = input * gainR;
 ```

 Else for stereo input, the output is calculated as:

 ``` highlight
 if (pan <= 0) {
 outputL = inputL + inputR * gainL;
 outputR = inputR * gainR;
 } else {
 outputL = inputL * gainL;
 outputR = inputR + inputL * gainR;
 }
 ```

### 6.4. Distance Effects

Sounds which are closer are louder, while sounds further away are
quieter. Exactly *how* a sound's volume changes according to distance
from the listener depends on the
[`distanceModel`](#dom-pannernode-distancemodel) attribute.

During audio rendering, a *distance* value will be calculated based on
the panner and listener positions according to:

```
function distance(panner) { const pannerPosition = new Vec3(panner.positionX.value, panner.positionY.value, panner.positionZ.value); const listener = context.listener; const listenerPosition = new Vec3(listener.positionX.value, listener.positionY.value, listener.positionZ.value); return pannerPosition.diff(listenerPosition).magnitude;}
```

*distance* will then be used to calculate *distanceGain* which depends
on the
[`distanceModel`](#dom-pannernode-distancemodel) attribute. See the
[`DistanceModelType`](#enumdef-distancemodeltype) section for details of how this is calculated for each
distance model.

As part of its processing, the
[`PannerNode`](#PannerNode)
scales/multiplies the input audio signal by *distanceGain* to make
distant sounds quieter and nearer ones louder.

### 6.5. Sound Cones

The listener and each sound source have an orientation vector describing
which way they are facing. Each sound source's sound projection
characteristics are described by an inner and outer \"cone\" describing
the sound intensity as a function of the source/listener angle from the
source's orientation vector. Thus, a sound source pointing directly at
the listener will be louder than if it is pointed off-axis. Sound
sources can also be omni-directional.

The following diagram ilustrates the relationship between the source's
cone with respect to the listener. In the diagram,
[`coneInnerAngle`](#dom-pannernode-coneinnerangle)` = 50` and
[`coneOuterAngle`](#dom-pannernode-coneouterangle)` = 120`. That is, the inner cone extends 25 deg on each
side of the direction vector. Similarly, the outer cone is 60 deg on
each side.

![Cone angles for a source in relationship to the source orientation and
the listeners position and
orientation.](images/cone-diagram.svg){a}

The following algorithm MUST be used to calculate the gain contribution
due to the cone effect, given the source (the
[`PannerNode`](#PannerNode)) and the listener:

```
function coneGain() { const sourceOrientation = new Vec3(source.orientationX, source.orientationY, source.orientationZ); if (sourceOrientation.magnitude == 0 || ((source.coneInnerAngle == 360) && (source.coneOuterAngle == 360))) return 1; // no cone specified - unity gain // Normalized source-listener vector const sourcePosition = new Vec3(panner.positionX.value, panner.positionY.value, panner.positionZ.value); const listenerPosition = new Vec3(listener.positionX.value, listener.positionY.value, listener.positionZ.value); const sourceToListener = sourcePosition.diff(listenerPosition).normalize(); const normalizedSourceOrientation = sourceOrientation.normalize(); // Angle between the source orientation vector and the source-listener vector const angle = 180 * Math.acos(sourceToListener.dot(normalizedSourceOrientation)) / Math.PI; const absAngle = Math.abs(angle); // Divide by 2 here since API is entire angle (not half-angle) const absInnerAngle = Math.abs(source.coneInnerAngle) / 2; const absOuterAngle = Math.abs(source.coneOuterAngle) / 2; let gain = 1; if (absAngle <= absInnerAngle) { // No attenuation gain = 1; } else if (absAngle >= absOuterAngle) { // Max attenuation gain = source.coneOuterGain; } else { // Between inner and outer cones // inner -> outer, x goes from 0 -> 1 const x = (absAngle - absInnerAngle) / (absOuterAngle - absInnerAngle); gain = (1 - x) + source.coneOuterGain * x; } return gain;}
```

## 7. Performance Considerations

### 7.1. Latency

![Use cases in which the latency can be
important](images/latency.png){a height="201" width="700"}

For web applications, the time delay between mouse and keyboard events
(keydown, mousedown, etc.) and a sound being heard is important.

This time delay is called latency and is caused by several factors
(input device latency, internal buffering latency, DSP processing
latency, output device latency, distance of user's ears from speakers,
etc.), and is cumulative. The larger this latency is, the less
satisfying the user's experience is going to be. In the extreme, it can
make musical production or game-play impossible. At moderate levels it
can affect timing and give the impression of sounds lagging behind or
the game being non-responsive. For musical applications the timing
problems affect rhythm. For gaming, the timing problems affect precision
of gameplay. For interactive applications, it generally cheapens the
users experience much in the same way that very low animation
frame-rates do. Depending on the application, a reasonable latency can
be from as low as 3-6 milliseconds to 25-50 milliseconds.

Implementations will generally seek to minimize overall latency.

Along with minimizing overall latency, implementations will generally
seek to minimize the difference between an
[`AudioContext`](#AudioContext)'s `currentTime` and an
[`AudioProcessingEvent`](#AudioProcessingEvent)'s `playbackTime`. Deprecation of
[`ScriptProcessorNode`](#ScriptProcessorNode) will make this consideration less important over time.

Additionally, some [`AudioNode`](#AudioNode)s can add latency to some paths of the audio graph,
notably:

- The
 [`AudioWorkletNode`](#AudioWorkletNode) can run a script that buffers internally, adding
 delay to the signal path.

- The [`DelayNode`](#DelayNode), whose role is to add controlled latency time.

- The
 [`BiquadFilterNode`](#BiquadFilterNode) and
 [`IIRFilterNode`](#IIRFilterNode) filter design can delay incoming samples, as a
 natural consequence of the causal filtering process.

- The [`ConvolverNode`](#ConvolverNode) depending on the impulse, can delay incoming samples,
 as a natural result of the convolution operation.

- The
 [`DynamicsCompressorNode`](#DynamicsCompressorNode) has a look ahead algorithm that causes delay in the
 signal path.

- The
 [`MediaStreamAudioSourceNode`](#MediaStreamAudioSourceNode),
 [`MediaStreamTrackAudioSourceNode`](#MediaStreamTrackAudioSourceNode) and
 [`MediaStreamAudioDestinationNode`](#MediaStreamAudioDestinationNode), depending on the implementation, can add buffers
 internally that add delays.

- The
 [`ScriptProcessorNode`](#ScriptProcessorNode) can have buffers between the control thread and the
 rendering thread.

- The
 [`WaveShaperNode`](#WaveShaperNode), when oversampling, and depending on the oversampling
 technique, add delays to the signal path.

### 7.2. Audio Buffer Copying

When an [acquire the
content](#acquire-the-content) operation
is performed on an
[`AudioBuffer`](#AudioBuffer), the entire operation can usually be implemented
without copying channel data. In particular, the last step SHOULD be
performed lazily at the next
[`getChannelData()`](#dom-audiobuffer-getchanneldata) call. That means a sequence of consecutive [acquire the
contents](#acquire-the-content)
operations with no intervening
[`getChannelData()`](#dom-audiobuffer-getchanneldata) (e.g. multiple
[`AudioBufferSourceNode`](#AudioBufferSourceNode)s playing the same
[`AudioBuffer`](#AudioBuffer)) can be implemented with no allocations or copying.

Implementations can perform an additional optimization: if
[`getChannelData()`](#dom-audiobuffer-getchanneldata) is called on an
[`AudioBuffer`](#AudioBuffer), fresh
[`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer)s have not yet been allocated, but all invokers of
previous [acquire the
content](#acquire-the-content)
operations on an
[`AudioBuffer`](#AudioBuffer) have stopped using the
[`AudioBuffer`](#AudioBuffer)'s data, the raw data buffers can be recycled for use
with new [`AudioBuffer`](#AudioBuffer)s, avoiding any reallocation or copying of the channel
data.

### 7.3. AudioParam Transitions

While no automatic smoothing is done when directly setting the
[`value`](#dom-audioparam-value) attribute of an
[`AudioParam`](#AudioParam), for certain parameters, smooth transition are
preferable to directly setting the value.

Using the
[`setTargetAtTime()`](#dom-audioparam-settargetattime) method with a low `timeConstant` allows authors to
perform a smooth transition.

### 7.4. Audio Glitching

Audio glitches are caused by an interruption of the normal continuous
audio stream, resulting in loud clicks and pops. It is considered to be
a catastrophic failure of a multi-media system and MUST be avoided. It
can be caused by problems with the threads responsible for delivering
the audio stream to the hardware, such as scheduling latencies caused by
threads not having the proper priority and time-constraints. It can also
be caused by the audio DSP trying to do more work than is possible in
real-time given the CPU's speed.

## 8. Privacy Considerations

Per the [Self-Review Questionnaire: Security and Privacy
§ questions](https://w3c.github.io/security-questionnaire/#questions):

1. Does this specification deal with personally-identifiable
 information?

 It would be possible to perform a hearing test using Web Audio API,
 thus revealing the range of frequencies audible to a person (this
 decreases with age). It is difficult to see how this could be done
 without the realization and consent of the user, as it requires
 active particpation.

2. Does this specification deal with high-value data?

 No. Credit card information and the like is not used in Web Audio.
 It is possible to use Web Audio to process or analyze voice data,
 which might be a privacy concern, but access to the user's
 microphone is permission-based via
 [`getUserMedia()`](https://www.w3.org/TR/mediacapture-streams/#dom-mediadevices-getusermedia).

3. Does this specification introduce new state for an origin that
 persists across browsing sessions?

 No. AudioWorklet does not persist across browsing sessions.

4. Does this specification expose persistent, cross-origin state to the
 web?

 Yes, the supported audio sample rate(s) and the output device
 channel count are exposed. See
 [`AudioContext`](#AudioContext).

5. Does this specification expose any other data to an origin that it
 doesn't currently have access to?

 Yes. When giving various information on available
 [`AudioNode`](#AudioNode)s, the Web Audio API potentially exposes information
 on characteristic features of the client (such as audio hardware
 sample-rate) to any page that makes use of the
 [`AudioNode`](#AudioNode) interface. Additionally, timing information can be
 collected through the
 [`AnalyserNode`](#AnalyserNode) or
 [`ScriptProcessorNode`](#ScriptProcessorNode) interface. The information could subsequently be
 used to create a fingerprint of the client.

 Research by Princeton CITP's [Web Transparency and Accountability
 Project](https://audiofingerprint.openwpm.com/) has shown that
 [`DynamicsCompressorNode`](#DynamicsCompressorNode) and
 [`OscillatorNode`](#OscillatorNode) can be used to gather entropy from a client to
 fingerprint a device. This is due to small, and normally inaudible,
 differences in DSP architecture, resampling strategies and rounding
 trade-offs between differing implementations. The precise compiler
 flags used and also the CPU architecture (ARM vs. x86) contribute to
 this entropy.

 In practice however, this merely allows deduction of information
 already readily available by easier means (User Agent string), such
 as \"this is browser X running on platform Y\". However, to reduce
 the possibility of additional fingerprinting, we mandate browsers
 take action to mitigate fingerprinting issues that might be possible
 from the output of any node.

 Fingerprinting via clock skew [has been described by Steven J
 Murdoch and Sebastian
 Zander](https://murdoch.is/talks/eurobsdcon07hotornot.pdf). It might
 be possible to determine this from
 [`getOutputTimestamp`](#dom-audiocontext-getoutputtimestamp). Skew-based fingerprinting has also been
 demonstrated [by Nakibly et. al. for
 HTML](https://pdfs.semanticscholar.org/cfd2/6a17234696593919df3f880a235d6ac5871d.pdf).
 The [High Resolution Time §  10. Privacy
 Considerations](https://w3c.github.io/hr-time/#sec-privacy) section
 should be consulted for further information on clock resolution and
 drift.

 Fingerprinting via latency is also possible; it might be possible to
 deduce this from
 [`baseLatency`](#dom-audiocontext-baselatency) and
 [`outputLatency`](#dom-audiocontext-outputlatency). Mitigation strategies include adding jitter
 (dithering) and quantization so that the exact skew is incorrectly
 reported. Note however that most audio systems aim for [low
 latency](https://padenot.github.io/web-audio-perf/#latency), to
 synchronise the audio generated by WebAudio to other audio or video
 sources or to visual cues (for example in a game, or an audio
 recording or music making environment). Excessive latency decreases
 usability and may be an accessibility issue.

 Fingerprining via the sample rate of the
 [`AudioContext`](#AudioContext) is also possible. We recommend the following steps
 to be taken to minimize this:

 1. 44.1 kHz and 48 kHz are allowed as default rates; the system
 will choose between them for best applicability. (Obviously, if
 the audio device is natively 44.1, 44.1 will be chosen, etc.,
 but also the system may choose the most \"compatible\"
 rate---e.g. if the system is natively 96kHz, 48kHz would likely
 be chosen, not 44.1kHz.

 2. The system should resample to one of those two rates for devices
 that are natively at different rates, despite the fact that this
 may cause extra battery drain due to resampled audio. (Again,
 the system will choose the most compatible rate---e.g. if the
 native system is 16kHz, it's expected that 48kHz would be
 chosen.)

 3. It is expected (though not mandated) that browsers would offer a
 user affordance to force use of the native rate---e.g. by
 setting a flag in the browser on the device. This setting would
 not be exposed in the API.

 4. It is also expected behavior that a different rate could be
 explicitly requested in the constructor for
 [`AudioContext`](#AudioContext) (this is already in the specification; it
 normally causes the audio rendering to be done at the requested
 sampleRate, and then up- or down-sampled to the device output),
 and if that rate is natively supported, the rendering could be
 passed straight through. This would enable apps to render to
 higher rates without user intervention (although it's not
 observable from Web Audio that the audio output is not
 downsampled on output)---for example, if
 [`MediaDevices`](https://w3c.github.io/mediacapture-main/#dom-mediadevices) capabilities were read (with user intervention)
 and indicated a higher rate was supported.

 Fingerprinting via the render quantum size of the
 [`AudioContext`](#AudioContext) is possible when the `"hardware"` hint is used, as
 it exposes information about the user's default audio hardware
 buffer size. To minimize this risk,
 [`renderQuantumSize`](#dom-baseaudiocontext-renderquantumsize) returns 0 until the
 [`AudioContext`](#AudioContext) transitions to the `"running"` state. Once the
 [`AudioContext`](#AudioContext) has transitioned to the `"running"` state the
 actual render quantum size is returned. A running AudioContext can
 be used to infer the user's audio hardware buffer size via
 [`AudioWorklet`](#AudioWorklet) timing, so this does not expose any new
 information.

 Fingerprinting via the number of output channels for the
 [`AudioContext`](#AudioContext) is possible as well. We recommend that
 [`maxChannelCount`](#dom-audiodestinationnode-maxchannelcount) be set to two (stereo). Stereo is by far the most
 common number of channels.

6. Does this specification allow an origin access to a user's location?

 No.

7. Does this specification allow an origin access to sensors on a
 user's device?

 Not directly. Currently, audio input is not specified in this
 document, but it will involve gaining access to the client machine's
 audio input or microphone. This will require asking the user for
 permission in an appropriate way, probably via the
 [`getUserMedia()`](https://www.w3.org/TR/mediacapture-streams/#dom-mediadevices-getusermedia) API.

 Additionally, the security and privacy considerations from the
 [Media Capture and
 Streams](https://www.w3.org/TR/mediacapture-streams/) specification
 should be noted. In particular, analysis of ambient audio or playing
 unique audio may enable identification of user location down to the
 level of a room or even simultaneous occupation of a room by
 disparate users or devices. Access to both audio output and audio
 input might also enable communication between otherwise partitioned
 contexts in one browser.

8. Does this specification allow an origin access to aspects of a
 user's local computing environment?

 Not directly; all requested sample rates are supported, with
 upsampling if needed. It is possible to use Media Capture and
 Streams to probe for supported audio sample rates with
 [MediaTrackSupportedConstraints](https://www.w3.org/TR/mediacapture-streams/#media-track-supported-constraints).
 This requires explicit user consent. This does provide a small
 measure of fingerprinting. However, in practice most consumer and
 prosumer devices use one of two standardized sample rates: 44.1kHz
 (originally used by CD) and 48kHz (originally used by DAT). Highly
 resource constrained devices may support the speech-quality 11kHz
 sample rate, and higher-end devices often support 88.2, 96, or even
 the audiophile 192kHz rate.

 Requiring all implementations to upsample to a single,
 commonly-supported rate such as 48kHz would increase CPU cost for no
 particular benefit, and requiring higher-end devices to use a lower
 rate would merely result in Web Audio being labelled as unsuitable
 for professional use.

9. Does this specification expose temporary identifiers to the web?

 No.

10. Does this specification distinguish between behavior in first-party
 and third-party contexts?

 No.

11. How should this specification work in the context of a user agent's
 \"incognito\" mode?

 Not differently.

12. Does this specification persist data to a user's local device?

 No.

13. Does this specification have a \"Security Considerations\" and
 \"Privacy Considerations\" section?

 Yes (you are reading it).

## 9. Security Considerations

Per the [Self-Review Questionnaire: Security and Privacy
§ questions](https://w3c.github.io/security-questionnaire/#questions):

1. Does this specification enable new script execution/loading
 mechanisms?

 No. It does use the
 [\[HTML\]](#biblio-html "HTML Standard") script
 execution method, defined in that specification.

2. Does this specification allow an origin access to other devices?

 It typically does not allow access to other networked devices (an
 exception in a high-end recording studio might be Dante networked
 devices, although these typically use a separate, dedicated
 network). It does of necessity allow access to the user's audio
 output device or devices, which are sometimes separate units to the
 computer.

 For voice or sound-actuated devices, Web Audio API *might* be used
 to control other devices. In addition, if the sound-operated device
 is sensitive to near ultrasonic frequencies, such control might not
 be audible. This possibility also exists with HTML, through either
 the \<audio\> or \<video\> element. At common audio sampling rates,
 there is (by design) insufficient headroom for much ultrasonic
 information:

 The limit of human hearing is usually stated as 20kHz. For a 44.1kHz
 sampling rate, the Nyquist limit is 22.05kHz. Given that a true
 brickwall filter cannot be physically realized, the space between
 20kHz and 22.05kHz is used for a rapid rolloff filter to strongly
 attenuate all frequencies above Nyquist.

 At 48kHz sampling rate, there is still rapid attenuation in the
 20kHz to 24kHz band (but it is easier to avoid phase ripple errors
 in the passband).

3. Does this specification allow an origin some measure of control over
 a user agent's native UI?

 If the UI has audio components, such as a voice assistant or
 screenreader, Web Audio API might be used to emulate aspects of the
 native UI to make an attack seem more like a local system event.
 This possibility also exists with HTML, through the \<audio\>
 element.

4. Does this specification allow downgrading default security
 characteristics?

 No.

## 10. Requirements and Use Cases

Please see
[\[webaudio-usecases\]](#biblio-webaudio-usecases "Web Audio Processing: Use Cases and Requirements").

## 11. Common Definitions for Specification Code

This section describes common functions and classes employed by
JavaScript code used within this specification.

```
// Three dimensional vector class.class Vec3 { // Construct from 3 coordinates. constructor(x, y, z) { this.x = x; this.y = y; this.z = z; } // Dot product with another vector. dot(v) { return (this.x * v.x) + (this.y * v.y) + (this.z * v.z); } // Cross product with another vector. cross(v) { return new Vec3((this.y * v.z) - (this.z * v.y), (this.z * v.x) - (this.x * v.z), (this.x * v.y) - (this.y * v.x)); } // Difference with another vector. diff(v) { return new Vec3(this.x - v.x, this.y - v.y, this.z - v.z); } // Get the magnitude of this vector. get magnitude() { return Math.sqrt(dot(this)); } // Get a copy of this vector multiplied by a scalar. scale(s) { return new Vec3(this.x * s, this.y * s, this.z * s); } // Get a normalized copy of this vector. normalize() { const m = magnitude; if (m == 0) { return new Vec3(0, 0, 0); } return scale(1 / m); }}
```

## 12. Change Log

### 12.1. Since First Public Working Draft of 05 November 2024

- [PR 2688](https://github.com/WebAudio/web-audio-api/pull/2688):
 Speculative PR preview fix
- [PR 2686](https://github.com/WebAudio/web-audio-api/pull/2686): Split
 Privacy Considerations and Security Considerations into separate
 sections
- [PR 2679](https://github.com/WebAudio/web-audio-api/pull/2679): Add
 Slack register link
- [PR 2676](https://github.com/WebAudio/web-audio-api/pull/2676): Update
 expected-errs.txt format
- [PR 2675](https://github.com/WebAudio/web-audio-api/pull/2675):
 OfflineAudioContext incremental/chunked rendering
- [PR 2667](https://github.com/WebAudio/web-audio-api/pull/2667):
 Specify render quantum size range constraints and renderSizeHint
 handling
- [PR 2657](https://github.com/WebAudio/web-audio-api/pull/2657):
 Require implementations support sample rate range \[3000, 768000\] Hz
- [PR 2656](https://github.com/WebAudio/web-audio-api/pull/2656): Fix
 expected-errs.txt
- [PR 2654](https://github.com/WebAudio/web-audio-api/pull/2654): Fix
 fundamental typo
- [PR 2633](https://github.com/WebAudio/web-audio-api/pull/2633): Add
 interrupted state and error handling for sink ID
- [PR 2617](https://github.com/WebAudio/web-audio-api/pull/2617): Revise
 wording for currentTime

## 13. Acknowledgements

This specification is the collective work of the W3C [Audio Working
Group](http://www.w3.org/2011/audio/).

Members and former members of the Working Group and contributors to the
specification are (at the time of writing, and by alphabetical order):\
Adenot, Paul (Mozilla Foundation) - Specification Co-editor; Akhgari,
Ehsan (Mozilla Foundation); Becker, Steven (Microsoft Corporation);
Berkovitz, Joe (Invited Expert, affiliated with Noteflight/Hal
Leonard) - WG co-chair from September 2013 to December 2017); Bossart,
Pierre (Intel Corporation); Borins, Myles (Google, Inc); Buffa, Michel
(NSAU); Caceres, Marcos (Invited Expert); Cardoso, Gabriel (INRIA);
Carlson, Eric (Apple, Inc); Chen, Bin (Baidu, Inc); Choi, Hongchan
(Google, Inc) - Specification Co-editor; Collichio, Lisa (Qualcomm);
Geelnard, Marcus (Opera Software); Gehring, Todd (Dolby Laboratories);
Goode, Adam (Google, Inc); Gregan, Matthew (Mozilla Foundation); Hikawa,
Kazuo (AMEI); Hofmann, Bill (Dolby Laboratories); Jägenstedt, Philip
(Google, Inc); Jeong, Paul Changjin (HTML5 Converged Technology Forum);
Kalliokoski, Jussi (Invited Expert); Lee, WonSuk (Electronics and
Telecommunications Research Institute); Kakishita, Masahiro (AMEI);
Kawai, Ryoya (AMEI); Kostiainen, Anssi (Intel Corporation); Lilley,
Chris (W3C Staff); Lowis, Chris (Invited Expert) - WG co-chair from
December 2012 to September 2013, affiliated with British Broadcasting
Corporation; MacDonald, Alistair (W3C Invited Experts) --- WG co-chair
from March 2011 to July 2012; Mandyam, Giridhar (Qualcomm Innovation
Center, Inc); Michel, Thierry (W3C/ERCIM); Nair, Varun (Facebook);
Needham, Chris (British Broadcasting Corporation); Noble, Jer (Apple,
Inc); O'Callahan, Robert(Mozilla Foundation); Onumonu, Anthony (British
Broadcasting Corporation); Paradis, Matthew (British Broadcasting
Corporation) - WG co-chair from September 2013 to present; Pozdnyakov,
Mikhail (Intel Corporation); Raman, T.V. (Google, Inc); Rogers, Chris
(Google, Inc); Schepers, Doug (W3C/MIT); Schmitz, Alexander (JS
Foundation); Shires, Glen (Google, Inc); Smith, Jerry (Microsoft
Corporation); Smith, Michael (W3C/Keio); Thereaux, Olivier (British
Broadcasting Corporation); Toy, Raymond (Google, Inc.) - WG co-chair
from December 2017 - Present; Toyoshima, Takashi (Google, Inc); Troncy,
Raphael (Institut Telecom); Verdie, Jean-Charles (MStar Semiconductor,
Inc.); Wei, James (Intel Corporation); Weitnauer, Michael (IRT); Wilson,
Chris (Google,Inc); Zergaoui, Mohamed (INNOVIMAX)
