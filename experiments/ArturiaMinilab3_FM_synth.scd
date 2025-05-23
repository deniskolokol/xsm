(
// Connect MiniLab 3 to FM Synth in SuperCollider
// Start by booting the server
s.boot;

// First, let's list all available MIDI devices
MIDIClient.init;
MIDIClient.sources;  // This will show all MIDI input devices

// Connect to all MIDI devices (or you can select specific ones if needed)
MIDIIn.connectAll;

// Store the existing FM SynthDef
SynthDef(\fm, {
    arg freq=500, mRatio=1, cRatio=1,
    index=1, iScale=5, cAtk=4, cRel=(-4),
    amp=0.2, atk=0.01, decay=0.3, sus=0.5, rel=1, pan=0,
    out=0, fx=0, fxsend=(-25), gate=1;
    var car, mod, env, iEnv;

    //index of modulation
    iEnv = EnvGen.kr(
        Env(
            [index, index*iScale, index],
            [atk, rel],
            [cAtk, cRel]
        )
    );

    //amplitude envelope (now using ADSR)
    env = EnvGen.kr(
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

    //modulator/carrier
    mod = SinOsc.ar(freq * mRatio, mul:freq * mRatio * iEnv);
    car = SinOsc.ar(freq * cRatio + mod) * env * amp;

    car = Pan2.ar(car, pan);
    Out.ar(out, car);
}).add;


// Define global variables to track parameter values
~mRatio = 1;
~cRatio = 1;
~index = 1;
~iScale = 5;
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

// MIDI Note On handler function
MIDIdef.noteOn(\noteOn, {
    arg vel, num, chan, src;
    var freq, synth;

    // Convert MIDI note number to frequency
    freq = num.midicps;

    // Create a new synth with the current parameter values
    synth = Synth(\fm, [
        \freq, freq,
        \mRatio, ~mRatio,
        \cRatio, ~cRatio,
        \index, ~index,
        \iScale, ~iScale,
        \cAtk, ~cAtk,
        \cRel, ~cRel,
        \amp, (vel / 127 * 0.5), // Scale velocity to amplitude
        \atk, ~atk,
        \decay, ~decay,
        \sus, ~sus,
        \rel, ~rel,
        \pan, ~pan
    ]);

    // Store the synth in the dictionary with the note number as key
    ~synths[num] = synth;

    // Print information for debugging
    ("Note On: MIDI " ++ num ++ " (freq: " ++ freq ++ " Hz), Velocity: " ++ vel).postln;
});

// MIDI Note Off handler function
MIDIdef.noteOff(\noteOff, {
    arg vel, num, chan, src;
    var synth;

    // Get the synth associated with this note
    synth = ~synths[num];

    // If there's a synth playing for this note, release it
    if(synth.notNil, {
        synth.set(\gate, 0); // Release the note
        ("Note Off: MIDI " ++ num).postln;
    });

    // Remove from our tracking dictionary
    ~synths.removeAt(num);
});

// MIDI CC handler function for knobs and sliders
MIDIdef.cc(\ccHandler, {
    arg val, num, chan, src;

    // Map CC numbers to synth parameters based on MiniLab 3 controls
    switch(num,
        // Sliders 1-4 for ADSR envelope control
        82, { // Slider 1 for Attack time
            ~atk = val.linexp(0, 127, 0.001, 2);
            ("Attack: " ++ ~atk).postln;
            // Update all playing synths with the new attack time
            ~synths.do({ |synth| synth.set(\atk, ~atk) });
        },
        83, { // Slider 2 for Decay time
            ~decay = val.linexp(0, 127, 0.01, 3);
            ("Decay: " ++ ~decay).postln;
            // Update all playing synths with the new decay time
            ~synths.do({ |synth| synth.set(\decay, ~decay) });
        },
        85, { // Slider 3 for Sustain level
            ~sus = val.linlin(0, 127, 0.0, 1.0);
            ("Sustain: " ++ ~sus).postln;
            // Update all playing synths with the new sustain level
            ~synths.do({ |synth| synth.set(\sus, ~sus) });
        },
        17, { // Slider 4 for Release time
            ~rel = val.linexp(0, 127, 0.01, 10);
            ("Release: " ++ ~rel).postln;
            // Update all playing synths with the new release time
            ~synths.do({ |synth| synth.set(\rel, ~rel) });
        },

        // Knobs for other FM parameters
        1, { // CC 1 (often Mod Wheel) to modulator ratio
            ~mRatio = val.linlin(0, 127, 0.5, 8);
            ("mRatio: " ++ ~mRatio).postln;
            // Update all playing synths with the new mRatio
            ~synths.do({ |synth| synth.set(\mRatio, ~mRatio) });
        },
        74, { // CC 74 (Knob 1) to carrier ratio
            ~cRatio = val.linlin(0, 127, 0.5, 8);
            ("cRatio: " ++ ~cRatio).postln;
            // Update all playing synths with the new cRatio
            ~synths.do({ |synth| synth.set(\cRatio, ~cRatio) });
        },
        71, { // CC 71 (Knob 2) to iScale
            ~iScale = val.linlin(0, 127, 1, 15);
            ("iScale: " ++ ~iScale).postln;
            // Update all playing synths with the new iScale
            ~synths.do({ |synth| synth.set(\iScale, ~iScale) });
        },
        76, { // CC 76 (Knob 3) to index
            ~index = val.linlin(0, 127, 0.1, 10);
            ("index: " ++ ~index).postln;
            // Update all playing synths with the new index
            ~synths.do({ |synth| synth.set(\index, ~index) });
        },
        77, { // CC 10 (often Pan) to pan
            ~pan = val.linlin(0, 127, -1, 1);
            ("pan: " ++ ~pan).postln;
            // Update all playing synths with the new pan
            ~synths.do({ |synth| synth.set(\pan, ~pan) });
        }
    );
});

// Simple function to test the synth without MIDI
~testFM = {
    var synth = Synth(\fm, [
        \freq, 440,
        \mRatio, ~mRatio,
        \cRatio, ~cRatio,
        \index, ~index,
        \iScale, ~iScale,
        \cAtk, ~cAtk,
        \cRel, ~cRel,
        \amp, 0.8,
        \atk, ~atk,
        \decay, ~decay,
        \sus, ~sus,
        \rel, ~rel,
        \pan, ~pan
    ]);
    "Test tone playing - press Enter to release".postln;

    // Wait for Enter to be pressed
    "\nPress Enter to release the test tone...".postln;
    1.yield;

    // Release the synth
    synth.set(\gate, 0);
    "Test tone released".postln;

    synth
};

// Function to display current parameters
~showParams = {
    "Current Parameters:".postln;
    ("mRatio: " ++ ~mRatio).postln;
    ("cRatio: " ++ ~cRatio).postln;
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
"FM Synth MIDI Setup Complete!".postln;
"Play your MiniLab 3 keyboard to trigger notes.".postln;
"ADSR Envelope Controls:".postln;
"  - Slider 1: Attack time".postln;
"  - Slider 2: Decay time".postln;
"  - Slider 3: Sustain level".postln;
"  - Slider 4: Release time".postln;
"Other FM Controls:".postln;
"  - CC 1 (Mod Wheel): Modulator Ratio".postln;
"  - CC 74 (Knob 1): Carrier Ratio".postln;
"  - CC 71 (Knob 2): Modulation Index".postln;
"  - CC 76 (Knob 3): Index Scale".postln;
"  - CC 73 (Knob 6): Attack Curve".postln;
"  - CC 75 (Knob 7): Release Curve".postln;
"  - CC 10: Pan".postln;
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
)