MIDIClient.init;
MIDIIn.connectAll;

~midiFunc = List.new;
~synthL = nil;


(
~midiFunc.add(
    MIDIFunc.noteOn({ |val, num|
        if (~synthL.isNil) {
            ~synthL = Synth(\fm, [\freq, 225])
        } {
            ~synthL.set(\gate, 0);
            ~synthL = nil;
        }
    },
    noteNum:70
    )
);

~midiFunc = ~midiFunc ++ [
    MIDIFunc.cc({ |val| ~synthL.set(\mRatio, val.linlin(0, 127, 0.1, 10))}, 24),
    MIDIFunc.cc({ |val| ~synthL.set(\cRatio, val.linlin(0, 127, 1, 50))}, 25),
    MIDIFunc.cc({ |val| ~synthL.set(\index, val.linlin(0, 127, 0.1, 2.0))}, 26),
    MIDIFunc.cc({ |val| ~synthL.set(\amp, val.linlin(0, 127, 0, 1))}, 12),
    MIDIFunc.cc({ |val, num| [val, num].postln}),
];
)

~midiFunc.do(_.free);