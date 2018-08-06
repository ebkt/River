// the overall layout of this code and its structure involving 'setup'/'cleanup'/'main loop'-esque functions
// is inspired by Eli Fieldsteel's youtube tutorials
// the tutorials are available at:
// https://www.youtube.com/watch?v=yRzsOOiJ_p4&list=PLPYzvS8A_rTaNDweXe6PX4CXSGq4iEWYC

(
  ///////////////////////////////
 //     CONFIGURATION         //
///////////////////////////////
// declare the server and configure outputs, inputs, sample rate, memory allocation, etc
s = Server.local;
s.options.outDevice_(
	"Built-in Output"
);
s.options.numOutputBusChannels_(2);
s.options.sampleRate_(44100);
s.options.memSize_(2.pow(20)); // declare plenty of memory for hungry buffers and reverb
s.newBusAllocators;

// remove everything attached to the ServerBoot/Tree/Quit evaluations for a clean slate
// we will add functions to these later, but we want them to be empty at first
ServerBoot.removeAll;
ServerTree.removeAll;
ServerQuit.removeAll;

// initialize global variables
~out = 0;
~tideLevel = 0;

// create a path to this folder and then go into the next folder, "Samples/" to find audio to be loaded into buffers for playback
~path = PathName(thisProcess.nowExecutingPath).parentPath++"Samples/";

// define functions to create buffers and busses
// this makes a dictionary to store each of the folders contained within the "Samples/" folder
// this way, adding/removing samples is easy, and subfolders can be referred to by name – easier than memorising numbers
~makeBuffers = {
	b = Dictionary.new;
	PathName(~path).entries.do{
		arg subfolder;
		b.add(
			subfolder.folderName.asSymbol ->
			Array.fill(
				subfolder.entries.size,
				{
					arg i;
					Buffer.read(s, subfolder.entries[i].fullPath);
				}
			)
		);
	};
};

// create a reverb bus as a send effect – here we're creating a dictionary of buses
// that way we can also refer to our output buses by name, not numbers
// e.g. signals we want to go to the reverb get sent to \reverb

~makeBusses = {
	~bus = Dictionary.new;
	~bus.add(\reverb -> Bus.audio(s,2));
};

// cleanup function to be run when we boot the server, panic button (cmd + .) and when we quit the server

~cleanup = {
	s.newBusAllocators;
	ServerBoot.removeAll;
	ServerTree.removeAll;
	ServerQuit.removeAll;
};

// create our nodes/groups
// this is necessary for audio to be sent to the reverb bus without running into errors

~makeNodes = {
	s.bind({
		~mainGrp = Group.new;
		~reverbGrp = Group.after(~mainGrp);
		~reverbSynth = Synth.new(
			\reverb,
			[
				\amp, 1,
				\predelay, 0.2,
				\revtime, 2.3,
				\lpf, 4500,
				\mix, 0.8,
				\in, ~bus[\reverb],
				\out, ~out,
			],
			~reverbGrp
		);
	});
};

// create a dictionary of events so that supercollider knows how to respond depending on the tide level it receives

~makeEvents = {
	e = Dictionary.new;

// events 1 to 4 are controlled by the tide level
// when the tide level moves, it changes which samples are available to be played and which instrument/SynthDef is selected,
// allowing a lot of variety in the mood of sounds
// at high tide, more water sounds are made audible
// at low tide, more sounds of day to day life, people and construction are audible
// a lot of the time buffers will be run through different types of filters which emphasise certain resonant frequencies according to how they are set


	e.add(\lowTide -> { // create a new event for \lowTide – when the tide level is mapped 0-100, this is from 0 to 25
		// first, stop all other patterns from other tide levels playing
		// the samples that are already playing will fade out but it'll take a few seconds,
		// so the new samples will have faded in by then, giving a nice unnoticeable crossfade
		~highTideWaves.stop;
		~marimba.stop;
		~midHighIndustry.stop;
		~simpleRings.stop;
		~waves.stop;
		"low tide playing".postln;    // post what event is playing to the console
		   ~people = Pbind( // create a Pbind, which is like a "pattern", where inf is the number of steps in the pattern.
			                // The Pbind will stop at the smallest number of steps provided,
			                // so passing inf (which is the default) to all means the pattern will run indefinitely
			    // the instrument used for this pattern is \bpfbuf – a SynthDef which runs buffers through resonant bandpass filters
				\instrument, \bpfbuf,

                // the duration of the "clock" for triggering the next step in the pattern: random between 0.1 and 1.5 seconds
			    \dur, Pexprand(0.1, 1.5),

			    // the duration of the attack stage of the envelope applied to the amplitude: random between 0.8 and 4 seconds
				\atk, Pexprand(0.8, 4),

			    // the duration of the release stage of the envelope applied to the amplitude
				\rel, Pexprand(5, 7),

			    // nested sequence – select five samples from the \Industry folder, then five from the \Social folder, repeat indefinitely
			   \buf, Pseq([Prand(b[\Industry][0..b[\Industry].size], 5), Prand(b[\Social][0..b[\Social].size], 5)], inf),

			    // each step, the selected sample should be played back at a random rate between 0.9 and 1.1
				\rate, Pwhite(0.9, 1.1),

			    // random sample startpos between 0 and the end of the sample minus the length of the current step in the Pbind
				\spos, Pwhite(0, Pkey(\buf).collect(_.numFrames) - Pkey(\dur), inf),

			    // random amplitude between these numbers
				\amp, Pexprand(0.2, 0.6),

			    // random panning – -1.0 is hard left, 1.0 is hard right
				\pan, Pwhite(-1.0, 1.0),

			    // random resonance on the filter – lower numbers result in higher resonance, creating clear pitches
				\rq, Pwhite(0.001, 0.008),

			    // randomly select filter frequencies in the phrygian mode, and randomly select normal pitch or up/down an octave
				\freq, Prand((Scale.phrygian.degrees+63).midicps,inf) * Pxrand([0.5, 1, 2], inf),

			    // random mix values – 0.0 is raw samples, 1.0 is full bandpass filter mix
				\bpfmix, Pwhite(0.5, 1.0),

			    // this synth should be in the main group, so it can be sent to the \reverb send
				\group, ~mainGrp,

			    // the output bus is the reverb send
				\out, ~bus[\reverb],
		    ).play; // play this when the criteria for this event are filled by the tidal information sent in, ie. it's low tide
		});

	// similar to above, an event to be called at mid-low tide – 25 to 50 when the tide level is mapped from 0 to 100
	e.add(\midLow -> {

		// stop any other events which are currently playing
		~people.stop;
		~highTideWaves.stop;
		~marimba.stop;
		~midHighIndustry.stop;
		~simpleRings.stop;

		"midlow tide playing".postln;

			~waves = Pbind(
				\instrument, \bpfbuf,
				\dur, Pexprand(0.1, 1.5),
				\atk, Pexprand(0.8, 4),
				\rel, Pexprand(5, 7),
				\buf, Prand(b[\Social][0..b[\Social].size], inf),
				\rate, Pwhite(0.9, 1.1),
			    \spos, Pwhite(0, Pkey(\buf).collect(_.numFrames) - Pkey(\dur), inf),
				\amp, Pexprand(0.7, 1),
				\pan, Pwhite(-1.0, 1.0, inf),
				\rq, Pwhite(0.002, 0.008),
				\freq, Prand((Scale.phrygian.degrees+66).midicps,inf) * Pxrand([1, 2], inf),
				\bpfmix, Pwhite(0.4, 1.0),
				\group, ~mainGrp,
				\out, ~bus[\reverb],
			).play;
	});


	e.add(\midHigh -> {
		~people.stop;
		~waves.stop;
		~highTideWaves.stop;
		~marimba.stop;
		"mid high tide playing".postln;
			~midHighIndustry = Pbind(
				\instrument, \bpfbuf,
				\dur, Pexprand(1.0, 3.5),
				\atk, Pwhite(1.0, 5.0),
				\rel, Pwhite(4.0, 6.0),
		        \buf, Prand(b[\Nature][0..b[\Nature].size]++b[\Industry][0..b[\Industry].size], inf),
				\rate, Pwhite(-1.0,1.0),
				\spos, Pwhite(0, Pkey(\buf).collect(_.numFrames) - Pkey(\dur), inf),
				\amp, Pexprand(0.5, 1.5, inf),
				\bpfmix, Pwhite(0.2, 1.0),
				\rq, Pwhite(0.002, 0.02),
			    \freq, Prand((Scale.phrygian.degrees+69).midicps,inf) * Pxrand([1, 2, 3], inf),
				\group, ~mainGrp,
				\out, ~bus[\reverb],
			).play;

			~simpleRings = Pbind(
				\instrument, \resonator,
			    \dur, Pwhite(0.5, 6.0),
				\atk, Pwhite(1.0, 5.0),
				\sus, Pwhite(4.0, 6.0),
				\rel, Pwhite(0.5, 7.0),
			    \buf, Pseq([
				            Prand(b[\Industry][0..b[\Industry].size], 1),
				            Prand(b[\Social][0..b[\Social].size], 2),
				            Prand(b[\Nature][0..b[\Nature].size], 4)
			              ],
			         inf),
			    \spos, Pwhite(0, Pkey(\buf).collect(_.numFrames) - Pkey(\dur), inf),
		        \freq, Prand((Scale.phrygian.degrees+69).midicps,inf) * Pxrand([0.5, 1, 2], inf),
			    \mix, Pwhite(0.3, 1.0),
				\decay, Pkey(\mix * 1.5),
				\amp, Pexprand(0.1, 0.5),
				\group, ~mainGrp,
				\out, ~bus[\reverb],
			).play;
		});

	e.add(\highTide -> {
		~people.stop;
		~waves.stop;
		~midHighIndustry.stop;
		~simpleRings.stop;
		"high tide playing".postln;
			~marimba = Pbind(
				\instrument, \bpfsaw,
				\dur, Pwhite(0.2, 0.5),
				\freq, Prand([1/5, 1/3, 2/5], inf),
				\rqmin, Pwhite(0.00015, 0.002),
				\rqmax, Pkey(\rqmin),
			    \cfmin, Prand((Scale.phrygian.degrees+60).midicps, inf) * Prand([0.5, 1, 2, 3], inf),
				\cfmax, Pkey(\cfmin),
				\atk, 3,
				\sus, 1,
				\rel, 5,
				\amp, Pwhite(0.5, 1.5, inf),
				\group, ~mainGrp,
				\out, ~bus[\reverb],
			).play;

		   ~highTideWaves = Pbind(
				\instrument, \bpfbuf,
			    \dur, Pseq([1, 0.5, 1.2, 2.1], inf),
				\atk, Pwhite(2.0, 8.0),
				\rel, Pwhite(4.0, 10.0),
			    \buf, Pxrand(b[\Nature][0..b[\Nature].size], inf),
				\rate, Pwhite(-0.08,0.08).midiratio,
				\spos, Pwhite(0, Pkey(\buf).collect(_.numFrames) - Pkey(\dur), inf),
			    \pan, Pwhite(-1.0, 1.0),
				\amp, Pexprand(0.6, 1.0),
				\bpfmix, Pwhite(0.7, 0.9),
			    \freq, Prand((Scale.phrygian.degrees+72).midicps,inf) * Pxrand([1, 1.5, 2], inf),
			    \rq, Pwhite(0.002, 0.05),
				\group, ~mainGrp,
				\out, ~bus[\reverb],
			).play;
		});

	// the next three events are oneshot events, which will be randomly played when a new value is received
	// as a little audible signal that the visualisation is about to move
	e.add(\oneshot1 -> {
		"playing one shot 1".postln;
		20.do{
			Synth(
				\bpfsaw,
				[
					\atk, exprand(1.5, 5.0),
					\rel, exprand(8.0, 15.0),
					\c1, exprand(4,10.0),
					\c2, exprand(2.0,5).neg,
					\freq, exprand(0.05, 19.0),
					\detune, rrand(0.1,4),
					\cfmin, 1000,
					\cfmax, 2500,
					\rqmin, 0.2,
					\rqmax, 0.02,
					\amp, exprand(0.6, 1.5),
					\pan, rrand(-1.0,1.0),
					\out, ~bus[\reverb],
				],
				~mainGrp
			);
		};
	});

	e.add(\oneshot2 -> {
		"playing one shot 2".postln;
		15.do{
			Synth(
				\resonator,
				[
					\atk, rrand(1.0, 3.0),
					\sus, 0,
					\rel, rrand(3.0, 4.0),
					\rate, rrand(-1.0, 1.0),
					\freq, rrand(250, 2500).round(50),
					\buf, b[\Industry][0..b[\Industry].size]++b[\Social][0..b[\Social].size]++b[\Nature][0..b[\Nature].size].choose,
					\spos, rrand(0, Pkey(\buf).collect(_.numFrames) - Pkey(\dur), inf),
					\decay, rrand(0.1, 0.5),
					\pan, rrand(-5.0, 0.5),
					\mix, exprand(0.2, 1.0),
					\amp, exprand(0.001, 0.002),
					\out, ~bus[\reverb]
				],
				~mainGrp
			);
		};
	});

	e.add(\oneshot3 -> {
		"playing one shot 3".postln;
		15.do{
			Synth(
				\bpfsaw,
				[
					\atk, rrand(0.1, 3.0),
					\sus, rrand(0.2, 2.0),
					\rel, exprand(1.0, 6.0),
					\freq, exprand(0.4,40.0),
					\bpfmix, 0,
					\rqmin, 0.08,
					\rqmax, 0.03,
					\cfhzmin, 5,
					\cfhzmax, 3000,
					\amp, exprand(0.2,0.7),
					\pan, rrand(-0.9,0.9),
					\out, ~bus[\reverb]
				],
				~mainGrp
			);
		};
	});

	// declare our OSCdef for receiving the tide level from the python script (on the other raspberry pi, controlling the visualisation)
	// via osc, and map it to a more legible/usable range – 0 to 100
	// 0 - 25 = low tide
	// 25 - 50 = low mid
	// 50 - 75 = mid high
	// 75 - 100 = high tide

	OSCdef.new(\tideLevel, { // the OSCdef key is \tideLevel
		| msg | // although we receive a lot more information, this is the only bit we care about
		~tideLevel = msg[1].linlin(-2.79, 3.65, 0, 100).round; // assign the global ~tideLevel variable to the amount received from the python script

		// after mapping it to a more usable range (0-100), print it out
		~tideLevel.postln;

		// choose a random oneshot event to play
		[e[\oneshot1], e[\oneshot2], e[\oneshot3]].choose.value;

		// case statements telling the program which event to run, depending on what the ~tideLevel value is
		case
		{~tideLevel >= 0 && ~tideLevel <= 25}   {e[\lowTide].value;}
		{~tideLevel >= 25 && ~tideLevel <= 50}  {e[\midLow].value;}
		{~tideLevel >= 50 && ~tideLevel <= 75}  {e[\midHigh].value;}
		{~tideLevel >= 75 && ~tideLevel <= 100} {e[\highTide].value;}
	},
	'/pySend' // /pySend is the name of the dispatcher – in this case, the python script
	);
};

// add functions so that they are called at ServerBoot and ServerQuit, respectively
ServerBoot.add(~makeBuffers);
ServerBoot.add(~makeBusses);
ServerQuit.add(~cleanup);

// After the "setup" above, we declare all of our synths and osc communication
// also, boot the server
s.waitForBoot({

	// once all asynchronous tasks have been completed (sometimes this can take few seconds) evaluate the code beneath s.sync
	s.sync;

	// the bpfsaw, bpfbuf and reverb synthdefs are also inspired by Eli Fieldsteel's tutorials, linked at the top

	// sound generator synth def – flexible use of this one "recipe" can yield wildly different results by
	// playing with filter frequency as well as the actual sawtooth wave's frequency and amplitude
	SynthDef(\bpfsaw, { // name the synthdef

		// arguments for attack, sustain, release, envelope curve
		// frequency, detune, pan, frequency min and max for the randomness
		// centre frequency min and max for the bandpass filter, resonance quality min and max
		// low shelf eq frequency, low frequency level, amp and output
		| atk=2, sus=0, rel=3, c1=1, c2=(-1),
		freq=500, detune=0.2, pan=0, cfhzmin=0.1, cfhzmax=0.3,
		cfmin=500, cfmax=2000, rqmin=0.1, rqmax=0.2,
		lsf=200, ldb=0, amp=1, out=0 |

		// create signal and envelope variables
		var sig, env;

		// create an amplitude envelope – doneAction:2 means it will remove itself from the server once it has completed
		env = EnvGen.kr(Env([0,1,1,0],[atk,sus,rel],[c1,0,c2]),doneAction:2);

		// the main signal is a sawtooth wave with a very slightly randomised pitch
		// !2 duplicates the signal so we don't just have it in one ear
		// in supercollider this duplication is called multichannel expansion and
		// the server knows to send the signal to both outputs
		sig = Saw.ar(freq * {LFNoise1.kr(0.5,detune).midiratio}!2);

		// send the sawtooth wave through a randomly modulated bandpass filter
		// we can change the amount of randomness through setting arguments when we declare the synths
		sig = BPF.ar(
			sig,
			{LFNoise1.kr(
				LFNoise1.kr(4).exprange(cfhzmin,cfhzmax)
			).exprange(cfmin,cfmax)}!2,
			{LFNoise1.kr(0.1).exprange(rqmin,rqmax)}!2
		);

		// eq to increase or decrease low frequencies, which can be lost when filter resonance is turned up
		sig = BLowShelf.ar(sig, lsf, 0.5, ldb);

		// balance the two signals across the stereo field
		sig = Balance2.ar(sig[0], sig[1], pan);

		// multiply the signal by the envelope, and also by the amp argument
		sig = sig * env * amp;

		// send the signal to the chosen output
		Out.ar(out, sig);
	}).add;


	// Ringz resonator SynthDef for samples to be played through
	SynthDef(\resonator, {

		// arguments for attack, sustain, release, envelope shape (c1 & c2), buffer to be played,
		// frequency of the resonator, rate of the sample, start position of the sample
		// decay time of the resonator, pan,
		// mix (refers to what is sent to the resonator, not the amount of the resonator that is heard),
		// amp, and output
		| atk=2, sus=0, rel=3, c1=1, c2=(-1), buf = 0,
		freq=500, rate = 1, spos = 0, decay = 1, pan=0,
		mix = 1, amp=0.5, out=0 |

		// create signal and envelope variables
		var sig, env;

		// create a 3 stage envelope with variable curve that frees itself from the server once it is complete
		env = EnvGen.kr(Env([0,0.5,0.5,0],[atk,sus,rel],[c1,0,c2]),doneAction:2);

		// play the selected 2 channel (stereo) buffer at its correct rate (in case the sampleRate doesn't match), from the declared start position
		sig = PlayBuf.ar(2, buf, rate*BufRateScale.ir(buf),startPos:spos);

		// the input to the Ringz resonator ugen is decided by a crossfade
		// 0.0 is the raw sample input
		// 1.0 is input from the Dust ugen, which creates random impulses
		// clicks like this run through the resonator make nice pitched percussion sounds
		sig = Ringz.ar(XFade2.ar(sig, Dust.ar(6, 0.2), mix*2-1), freq, decay, amp);

		// multiply the signal by the envelope and amp
		sig = sig * env * amp;

		Out.ar(out, sig);
	}).add;

	//
	// synthdef for playback and manipulation of buffers
	SynthDef(\bpfbuf, {
		// arguments for attack, sustain, release, envelope curve,
		// buffer, rate, start position, frequency, filter resonance, filter mix,
		// pan, amplitude and output
		| atk=0, sus=0, rel=3, c1=1, c2=(-1),
		buf=0, rate=1, spos=0, freq=440, rq=1, bpfmix=0,
		pan=0, amp=1, out=0 |

		// create signal and envelope variables
		var sig, env;

		// see previous synthdef for description of envelope
		env = EnvGen.kr(Env([0,1,1,0],[atk,sus,rel],[c1,0,c2]),doneAction:2);

		// play the selected 2 channel (stereo) buffer at its correct rate (in case the sampleRate doesn't match), from the declared start position
		sig = PlayBuf.ar(2, buf, rate*BufRateScale.ir(buf),startPos:spos);

		// use the bpfmix argument to mix between raw sample at 0.0 and full bpf sound at 1.0
		// bpfmix*2-1 is to scale and offset the mix so that it goes from 0.0 to 1, instead of -1.0 to 1.0
		sig = XFade2.ar(sig, BPF.ar(sig, freq, rq, 1/rq.sqrt), bpfmix*2-1);

		// multiply the signal by the envelope to fade it in and out
		sig = sig * env;

		// pan these 2 channels to where we tell them to go
		sig = Pan2.ar(sig, pan, amp);

		Out.ar(out, sig);
	}).add;

	/*~bass = 3.do{Pbind(
		\instrument, \swells,
		\dur, Pwhite(1.0, 3.0, inf),
		\atk, Pwhite(3.0, 6.0),
		\sus, Pwhite(0.0, 2.0),
		\rel, Pwhite(4.0, 7.0),
		\modamt, Pwhite(0.1, 0.4),
		\carpartial, Pxrand([0.5, 1, 1.5, 2.0], inf),
		\modpartial, Pwhite(-6, 4, inf).round(2),
		\freq, Prand((Scale.phrygian.degrees+48).midicps, inf) * Pxrand([0.5, 1], inf),
		\bpffreq, 300,
		\rq, Pexprand(0.001, 0.002, inf),
		\pan, Pwhite(-1.0, 1.0),
		\amp, 1.0,
		\out, ~bus[\reverb],
		\group, ~mainGrp,
	).play;
	}*/

	SynthDef(\swells, {
		| carpartial = 1, modpartial = 1, index = 3, mul = 0.05, modamt = 0.5, bpffreq = 200, rq = 0.5,
		atk = 2, sus = 0, rel = 3, freq, amp, pan = 0, out |
		var mod, car;
		var sig, env;

		env = EnvGen.kr(Env([0, 1, 1, 0], [atk, sus, rel]), doneAction:2);
		mod = SinOsc.ar(freq * modpartial, 0, modamt);
		car = SinOsc.ar((freq * carpartial) + mod, 0, amp)!2;
		sig = car + mod;
		sig = sig * env * amp;
		sig = BPF.ar(sig, bpffreq, rq, amp);
		sig = Pan2.ar(sig, pan, amp);

		Out.ar(out, sig);

	}).add;

	// synthdef for reverb effect send
	SynthDef(\reverb, {

		// arguments for input, predelay, reverb time,
		// lowpass filter, mix, amplitude and output
		| in, predelay=0.1, revtime=1.8,
		lpf=4500, mix=0.7, amp=1, out=0 |

		// create variables for dry, wet, temporary signal and signal
		var dry, wet, temp, sig;

		// input the dry signal – 2 channels
		dry = In.ar(in,2);

		// write the dry signal to the temp signal which will get continuously overwritten as we make the reverb signal
		temp = In.ar(in,2);

		// set wet to zero, so we can use it in mathematical functions, otherwise it would be nil and we couldn't use it
		wet = 0;

		// set predelay up
		temp = DelayN.ar(temp, 0, 2, predelay);

		// send the temp signal through an allpass filter with feedback (N means no interpolation)
		// a max delay time of 0.05 seconds
		// then create a unique stereo pair of delay times between 1ms and 50ms
		// decay time is our reverb time – we can change it when we instantiate the reverb synth
		16.do{
			temp = AllpassN.ar(temp, 0.05, {Rand(0.001,0.05)}!2, revtime);
			// use a lowpass filter to imitate natural damping of sound – high frequencies reflected less
			temp = LPF.ar(temp, lpf);
			wet = wet + temp;
		};
		// use XFade2 so we can mix between wet and dry
		sig = XFade2.ar(dry, wet, mix*2-1, amp);

		Out.ar(out, sig);
	}).add;

	s.sync;

	// register functions to run when [cmd + .] is called, ie. when the server frees everything on it
	ServerTree.add(~makeNodes);
	ServerTree.add(~makeEvents);

	// this is what runs when you press [cmd + .]
	// when we do it now, all of the above functions we registered with ServerTree.add will be called
	s.freeAll;

	// wait for all the above to finish
	s.sync;

	// post done in the console
	"done".postln;
});
)