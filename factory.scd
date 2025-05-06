(
~currentDir = PathName(thisProcess.nowExecutingPath).pathOnly;
"Loading synth definitions...".postln;
if (this.executeFile(~currentDir +/+ "synthdef.scd").isNil.not) {
    postf("OK\n\n")
} {
    postf("\nWARNING: could not load SynthDef(s)!\n\n")
};

"Loading synth params...".postln;
if (this.executeFile(~currentDir +/+ "synth_params.scd").isNil.not) {
    postf("OK\n\n")
} {
    postf("\nWARNING: could not load Synth Params!\n\n")
};

// Abstractions:
// - `plate` - a surface consisting of 2 decks: Left and Right.
//   A plate can be of the type Gen (generator) or FX (effect)
// - `deck` - a container of a synth, its current settings (params) and presets
~plateFactory = (

);

~deckFactory = { arg
    synthName=nil,
    in=0, // for FX synths
    out=0, // default is the first channel
    outFX=Server.default.options.numOutputBusChannels, // default is the next one after audio output
    bufnum=nil; // for Granular and Waveshaping synths

    // Deck object prototype
    var deck = (
        synthName: synthName,
        in: in,
        out: out,
        outFX: outFX,
        bufnum: bufnum,
        synth: nil,
        presets: List.new, // all presets
        preset: nil, // current preset

        setSynth: {arg self, synthName, params;
            self.synthName = synthName;
        },

        activate: { arg self, synthName, params;
            self.synth = Synth(self.synthName, params);
            self.presets = self.loadPresets.()
        },

        loadPresets: { arg self;

        },

        selectPreset: {

        },
    );

    deck; // return deck
};
)

d


// TODO:
deckLeft = ~deckFactory.(\fm, out:0) // should load presets along
deckLeft.activate(lag:0.2); // activate with fade-in
deckLeft.isActive; // boolean
deckLeft.out = 2; // re-route audio
deckLeft.outFX = 12; // re-route FX
deckLeft.preset = 2; // index in self.presets
deckLeft.params.reset(); // reset to default
deckLeft.params.randomize();
deckLeft.savePreset(); // save current params to a new preset
deckLeft.mute(); // the synth is running - simply set /amp, 0
deckLeft.deactivate(); // remove the synth from the server
deckLeft.setSynth(\cmb); // change synth (should re-load presets)

deckRight = ~deckFactory.(\probe);

plates = List.new;
plate0 = ~plateFactory.();

plate0.deckLeft = deckLeft
plate0.deckRight = deckRight;
plate0.makeGUI();
plates.add(plate0);

plate1 = plate0.duplicate();
plate1.deckLeft.params[\mod] = 8; // call this from gui element action as well as MIDI CC or NoteON/OFF
plates.add(plate1);

plates.remove(0); // by index - check if it's a current plate being removed,
                  // the next one should become a current one,
                  // and makeGUI for the current plate
