(
// Connect MiniLab 3 to Wavetable synth in SuperCollider
// Start by booting the server
Server.default = s = Server.local;
s.boot;

~rbus = Bus.audio(s, 2);
~synthname = "moogff__s2"; // "osc";

s.waitForBoot({

    //10 wavetables with increasing complexity
    ~wt_sig = 10.collect { |i|

        //random number of envelope segments
        var numSegs = i.linexp(0, 9, 4, 40).round;

        Env(
            //env always begins and ends with zero
            //inner points are random from -1.0 to 1.0
            [0]++({1.0.rand}.dup(numSegs-1) * [1,-1]).scramble++[0],

            //greater segment duration variety in higher-index wavetables
            {exprand(1,i.linexp(0,9,1,50))}.dup(numSegs),

            //low-index wavetables tend to be sinusoidal
            //high index wavetables tend to have sharp angles and corners
            {[\sine,0,exprand(1,20) * [1,-1].choose].wchoose([9-i,3,i].normalizeSum)}.dup(numSegs)
        ).asSignal(1024);
    };

    //load into 10 buffers in wavetable format
    ~wt_buf = Buffer.allocConsecutive(10, s, 2048, 1, {
        arg buf, index;
        buf.setnMsg(0, ~wt_sig[index].asWavetable);
    });

    // Add the generator SynthDef
    SynthDef(\osc, {
        arg buf=0, freq=220, detune=0.2, gate=1,
        mRatio=1, index=1, iScale=5,
        atk=0.01, decay=0.3, sus=1, rel=0.01, cAtk=4, cRel=(-4),
        amp=0.2, pan=0, out=0, fx=0, fxsend=(-20);

		// Index of modulation
		var iEnv = EnvGen.kr(
			Env(
				[index, index*iScale, index],
				[atk, rel],
				[cAtk, cRel]
			)
		);

        // ADSR envelope
        var env = EnvGen.kr(
            Env.adsr(
                attackTime: atk,
                decayTime: decay,
                sustainLevel: sus,
                releaseTime: rel,
                curve: [cAtk, cRel, cRel]
            ),
            gate: gate,
            doneAction: 2
        );

        // Array of eight Oscs with unique detune frequencies
        // and unique initial phase offsets
        var detuneCtrl = LFNoise1.kr(0.1 ! 8).bipolar(detune).midiratio;

		// Modulator
		var modulator = SinOsc.ar(freq * mRatio, mul:freq * mRatio * iEnv);

        // Carrier
        var signal = Osc.ar(buf, freq * detuneCtrl + modulator, { Rand(0, 2pi) } ! 8);

        signal = Splay.ar(signal); //spread 8 signals over stereo field
        signal = LeakDC.ar(signal); //remove DC bias
        signal = Balance2.ar(signal[0], signal[1], pan, amp); // L/R balance (pan)
        signal = signal * env;

        // Direct output
        Out.ar(out, signal);

        //"post-fader" send to reverb
        Out.ar(fx, signal * fxsend.dbamp);
    }).add;


    // Add FX synths
    // Reverb
    SynthDef(\reverb, {
        arg in=0, out=0, dec=4, lpf=1500;
        var sig;
        sig = In.ar(in, 2).sum;
        sig = DelayN.ar(sig, 0.03, 0.03);
        sig = CombN.ar(sig, 0.1, {Rand(0.01,0.099)}!32, dec);
        sig = SplayAz.ar(2, sig);
        sig = LPF.ar(sig, lpf);
        5.do{sig = AllpassN.ar(sig, 0.1, {Rand(0.01,0.099)}!2, 3)};
        sig = LPF.ar(sig, lpf);
        sig = LeakDC.ar(sig);
        Out.ar(out, sig);
    }).add;

    s.sync;

    // Instantiate reverb
    Synth(\reverb, [\in, ~rbus]);

    s.sync;

    // Define global variables to track parameter values
    ~detune = 1;
    ~filtFreq=440;
    ~filtParam=1.0;
    ~filtType=0;
    ~distance=0.1;
    ~revDamp=0.5;
    ~revMix=0.25;
    ~param7 = 1; // vacant
    ~fxsend = -20;
    ~cAtk = 4;
    ~cRel = -4;
    ~atk = 0.01;
    ~decay = 0.3;
    ~sus = 0.5;
    ~rel = 1;
    ~pan = 0;

    // Dictionary to store active notes and synths
    ~notes = Dictionary.new;
    ~synths = Dictionary.new;

    // List all available MIDI devices
    MIDIClient.init;
    MIDIClient.sources;  // display all MIDI input devices

    // Connect to all MIDI devices (or select specific ones if needed)
    MIDIIn.connectAll;

    ~postMIDI = { |val, num, chan, src, setParm, setVal|
        var ln = format("src  %\tchan  %\tnum  % ", src, chan, num);
        if (setParm.isNil) {
            ln = ln + format(" | val: %", val);
        } {
            if (setVal.isFloat) { setVal = setVal.round(0.0001) };
            ln = ln + format(" | val: % -> %  (%)", val, setVal, setParm);
        };
        postf("%\n", ln)
    };

    // MIDI Note On handler function
    MIDIdef.noteOn(\noteOn, { |vel, num, chan, src|
        var freq, synth;

        switch(chan)
        // Channel 0 is a keyboard
        { 0 } {
            // Convert MIDI note number to frequency
            freq = num.midicps;

            // Create a new synth with the current parameter values
            synth = Synth(~synthname, [
                \freq, freq,
                \buf, ~wt_buf[0..3].choose,
                \detune, ~detune,
                \fx, ~rbus,
                \fxsend, ~fxsend,
                \cAtk, ~cAtk,
                \cRel, ~cRel,
                \amp, (vel / 127 * 0.8), // Scale velocity to amplitude
                \atk, ~atk,
                \decay, ~decay,
                \sus, ~sus,
                \rel, ~rel,
                \pan, ~pan,
                \distance, ~distance,
                \revDamp, ~revDamp,
                \revMix, ~revMix,
                \filtFreq, ~filtFreq,
                \filtParam, ~filtParam,
				\filtType, ~filtType
            ]);

            // Store the synth in the dictionary with the note number as key
            ~synths[num] = synth;
        }

        // Channel 9 is a keypad
        { 9 } { nil }

        // Default function
        { nil };

        // Post MIDI event
        ~postMIDI.(vel, num, chan, src, "Note ON", num);
    });

    // MIDI Note Off handler function
    MIDIdef.noteOff(\noteOff, { |vel, num, chan, src|

        // If there's a synth playing for this note, release it
        if (~synths[num].notNil) { ~synths[num].set(\gate, 0) };

        // Remove from tracking dictionary
        ~synths.removeAt(num);
    });

    // MIDI CC handler function for knobs and sliders
	MIDIdef.cc(\ccHandler, { |val, num, chan, src|
		// Map CC numbers to synth parameters based on MiniLab 3 controls:
		// update all playing synths with the new param value or simply
		// display MIDI event info.

		var setParm=nil, setVal=nil;
		var filtType = (
			0: "LPF",
			1: "BPF",
			2: "BRF",
			3: "HPF",
			4: "RLPF",
			5: "Resonz"
		);

		switch(num)
		// Sliders 1-4 for ADSR envelope control
		{ 82 } { // Slider 1 for Attack time
			setVal = ~atk = val.linexp(0, 127, 0.001, 2);
			setParm = "Attack";
			~synths.do({ |synth| synth.set(\atk, ~atk) });
		}
		{ 83 } { // Slider 2 for Decay time
			setVal = ~decay = val.linexp(0, 127, 0.01, 3);
			setParm = "Decay";
			~synths.do({ |synth| synth.set(\decay, ~decay) });
		}
		{ 85 } { // Slider 3 for Sustain level
			setVal = ~sus = val.linlin(0, 127, 0.0, 1.0);
			setParm = "Sustain";
			~synths.do({ |synth| synth.set(\sus, ~sus) });
		}
		{ 17 } { // Slider 4 for Release time
			setVal = ~rel = val.linexp(0, 127, 0.01, 10);
			setParm = "Release";
			~synths.do({ |synth| synth.set(\rel, ~rel) });
		}

		// Knobs for other parameters
		{ 1 } { // CC 1 (Mod Wheel) to modulator ratio
			setVal = ~mRatio = val.linlin(0, 127, 0.5, 8);
			setParm = "mRatio";
			~synths.do({ |synth| synth.set(\mRatio, ~mRatio) });
		}
		{ 74 } { // CC 74 (Knob 1) to detune
			setVal = ~detune = val.linlin(0, 127, 0.5, 8);
			setParm = "Detune";
			~synths.do({ |synth| synth.set(\detune, ~detune) });
		}
		{ 16 } { // CC 16 (Knob 8) to fxsend
			setVal = ~fxsend = if (val == 0) {-120} {\db.asSpec.map(val.linexp(0, 127, 0.001, 1.0))};
			setParm = "FX send";
			~synths.do({ |synth| synth.set(\fxsend, ~fxsend) });
		}
		{ 86 } { // CC 86 (Knob 1) to distance (reverb room)
			setVal = ~distance = val.linlin(0, 127, 0, 2.sqrt);
			setParm = "Reverb room";
			~synths.do({ |synth| synth.set(\distance, ~distance) });
		}
		{ 87 } { // CC 87 (Knob 2) to revDamp
			setVal = ~revDamp = val.linlin(0, 127, 0, 1);
			setParm = "Reverb damp";
			~synths.do({ |synth| synth.set(\revDamp, ~revDamp) });
		}
		{ 89 } { // CC 89 (Knob 3) to revMix
			setVal = ~revMix = val.linlin(0, 127, 0, 1);
			setParm = "Reverb mix (dry/wet)";
			~synths.do({ |synth| synth.set(\revMix, ~revMix) });
		}
		{ 110 } { // CC 110 (Knob 5) to filtFreq
			setVal = ~filtFreq = val.linexp(0, 127, 20, 5000);
			setParm = "Filter Freq";
			~synths.do({ |synth| synth.set(\filtFreq, ~filtFreq) });
		}
		{ 111 } { // CC 110 (Knob 6) to filtParam (RQ)
			setVal = ~filtParam = val.linexp(0, 127, 0.01, 1.00);
			setParm = "Filter RQ";
			~synths.do({ |synth| synth.set(\filtParam, ~filtParam) });
		}
		{ 116 } { // CC 116 (Knob 7) to filtType
			~filtType = val.linlin(0, 127, 0, 5.499999);
			setParm = "Filter Type";
			setVal = filtType.at(~filtType.round.asInteger);
			~synths.do({ |synth| synth.set(\filtType, ~filtType) });
		};

		// Post MIDI event
		~postMIDI.(val, num, chan, src, setParm, setVal);
	});

    // Function to display current parameters
    ~showParams = {
        "Current Parameters:".postln;
        ("mRatio: " ++ ~mRatio).postln;
        ("index: " ++ ~index).postln;
        ("iScale: " ++ ~iScale).postln;
        ("cAtk: " ++ ~cAtk).postln;
        ("cRel: " ++ ~cRel).postln;
        ("Attack: " ++ ~atk).postln;
        ("Decay: " ++ ~decay).postln;
        ("Sustain: " ++ ~sus).postln;
        ("Release: " ++ ~rel).postln;
        ("pan: " ++ ~pan).postln;
    };

    // Display initial parameters
    ~showParams.value;

    // Print instructions
    "Synth MIDI Setup Complete!".postln;
    "Play your MiniLab 3 keyboard to trigger notes.".postln;
    "ADSR Envelope Controls:".postln;
    "  - Slider 1: Attack time".postln;
    "  - Slider 2: Decay time".postln;
    "  - Slider 3: Sustain level".postln;
    "  - Slider 4: Release time".postln;
    "Other Controls:".postln;
    //    "  - CC 1 (Mod Wheel): Modulator Ratio".postln;
    "  - CC 74 (Knob 1): Detune".postln;
    // "  - CC 71 (Knob 2): Modulation Index".postln;
    // "  - CC 76 (Knob 3): Index Scale".postln;
    // "  - CC 73 (Knob 6): Attack Curve".postln;
    // "  - CC 75 (Knob 7): Release Curve".postln;
    // "  - CC 10: Pan".postln;
    "".postln;
    "Run ~testFM.value to play a test tone with sustain.".postln;
    "Run ~showParams.value to see current parameter values.".postln;

    // Add a function to verify the actual CC numbers of your sliders
    "Run ~findCCs.value to identify the actual CC numbers of your controller's knobs/sliders.".postln;

    ~findCCs = {
        MIDIdef.cc(\findCCs, {|val, num, chan, src|
            ("CC #" ++ num ++ " value: " ++ val).postln;
        });
        "Move knobs and sliders on your MiniLab 3 to see their CC numbers...".postln;
        "When finished, run MIDIdef(\\findCCs).free; to stop monitoring.".postln;
    };

    CmdPeriod.doOnce({
        "Clean up on exit...".post;
        MIDIIn.disconnectAll;
        " done".postln;
    });

});
)