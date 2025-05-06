(
var currentDir = PathName(thisProcess.nowExecutingPath).pathOnly;

// MIDI/Controls containers.
var makeMIDI, midiFunc=List.new;
var midiMapCC=#[ // for XSession - continous control
    24, 25, 26, 12, // Knobs 1, 2, 3 Left
    27, 28, 29, 11, // Knobs Hi, Mid, Low Left
    34, 35, 36, 14, // Knobs 1, 2, 3 Right
    31, 32, 33, 15, // Knobs Hi, Mid, Low Right
    17, // Crossfader (normal)
	];
var midiMapNO=#[ // for XSession - note on
    44, // Headphone Button Left
    46, 43, // << & >> Buttons Left
    70, // Play Button Left
    58, // Cue Button Left
    45, // Headphone Button Right
    56, 57, // << & >> Buttons Right
    69, // Play Button Right
    59, // Cue Button Right
	];
var midiNoteOnMap = Dictionary[ // for XSession - note on
    44 -> Dictionary[\descr -> "Headphone Button Left"],
    46 -> Dictionary[\descr -> "<< Button Left"],
    43 -> Dictionary[\descr -> ">> Button Left"],
    70 -> Dictionary[\descr -> "Play Button Left"],
    58 -> Dictionary[\descr -> "Cue Button Left"],
    45 -> Dictionary[\descr -> "Headphone Button Right"],
    56 -> Dictionary[\descr -> "<< Button Right"],
    57 -> Dictionary[\descr -> ">> Button Right"],
    69 -> Dictionary[\descr -> "Play Button Right"],
    59 -> Dictionary[\descr -> "Cue Button Right"]
];
var ctrlsList=Array.fill(midiMapCC.size, {nil});
var ctlBus=Array.fill(midiMapCC.size, {Bus.control(s)});
var currCtrl=0;

// Plates and decks.
var plates = List.new;

// Synth control.
var changeSynth = { |deck, plate=0|
    postf(
        "Placeholder for changing the synth on the deck %, plate %!\n",
        deck,
        plate
    );
};

// Control flow.
var cleanup;

// GUI.
var win;
var width=1600; // Window.screenBounds.width;
var height=900; // Window.screenBounds.height;

var gap=5, margin=5;
var pane, paneL, paneR, paneStatus;
var paneLctrlKnob, paneRctrlKnob, paneLctrlSlid, paneRctrlSlid, paneLctrlBt, paneRctrlBt;
var knobWidth=115, knobHeight=115;
var makeCtlStripe, makeTranspStripe;

var colorBg=Color.grey(0.15);
var colorPane=Color.grey(0.1);
var colorBtLabel=Color.grey(0.2), colorBtUp=Color.grey(0.6),
    colorBtDown=Color.blue;
var colorInProgress=Color.red;
var transparent=Color.grey(alpha:0.0);

var fontHead=Font("Monospace", 20);
var fontLabel=Font("Helvetica", 14);
var fontControl=Font("Helvetica", 12);

var paneWidth = { |par, scale=1| (par.bounds.width * scale - 6).floor };
var paneHeight = { |par, scale=1| (par.bounds.height * scale - 6).floor };
var compView = { |par, scaleW=1, scaleH=1, color|
    if (color.isNil) { color = transparent };
    CompositeView(par,
        paneWidth.(par, scaleW)@paneHeight.(par, scaleH)
    ).background_(color);
};
var compViewFlow = { |par, scaleW=1, scaleH=1, color, margin=5, gap=5|
    var vw;
    vw = compView.(par, scaleW, scaleH, color);
    vw.decorator = FlowLayout(vw.bounds, margin@margin, gap@gap);
    vw
};
var knob = { |par, label, spec, action, initVal, layout=\vert2, bounds|
    if (initVal.isNil) { initVal = spec.default };
    EZKnob(par, bounds, " " ++ label.asString, spec,
        { |ez| action.(ez.value) },
        initVal, layout: layout
    )
    .font_(fontControl)
    .setColors(
        stringColor:Color.white,
        numBackground:Color.grey,
        knobColors:[Color.white, Color.grey, Color.white, Color.red],
        numNormalColor:Color.yellow,
    )
};
var slider = { |par, label, spec, action, initVal, layout='horz', scaleW=1, scaleH=1, numberWidth=45, margin|
    var labelWidth=0;
    var bounds=paneWidth.(par)@20;
    margin = margin ? 5@5;
    if (label.isNil.not) { labelWidth = label.size * 5 };
    bounds = (paneWidth.(par, scaleW))@(paneHeight.(par, scaleH));
    if (layout == 'horz') { numberWidth = 30 } { numberWidth = 45 };
    if (initVal.isNil) { initVal = spec.default };
    EZSlider(
        par, bounds, label, spec,
        { |ez| action.(ez.value) },
        initVal,
        labelWidth: labelWidth,
        numberWidth: numberWidth,
        unitWidth: 30,
        layout: layout,
        margin: margin
    )
    .setColors(
        stringColor:Color.white,
        numBackground:Color.grey,
        numNormalColor:Color.yellow,
        knobColor:Color.red
    )
    .font_(fontControl)
};
var button = { |par, label, action, scaleW=1, scaleH=1, colorLabel, colorBg|
    // TODO:
    // - nice label
    // - round button
    colorLabel = colorLabel ? colorBtLabel;
    colorBg = colorBg ? colorBtUp;
    Button(par, paneWidth.(par, scaleW)@paneHeight.(par, scaleH)).states_([
        [label, colorLabel, colorBg]
    ])
    .font_(fontLabel)
    .action_(action)
    // .action_({ |bt| action.(bt.value) })
    .canFocus_(false);
};
var dropdown = { |par, label, items, action, initVal=0, scale=1|
    var labelWidth=0;
    if (label.isNil.not) { labelWidth = label.size * 9};
    EZPopUpMenu(par,
        bounds: paneWidth.(par, scale)@40,
        label: label,
        items: items,
        globalAction: action,
        initVal: initVal,
        labelWidth: labelWidth
    )
    .setColors(
        menuStringColor:Color.white,
        menuBackground: colorBg,
        background: transparent,
    )
    .font_(fontHead)
};


"Loading synth definitions...".postln;
if (this.executeFile(currentDir +/+ "synthdef.scd").isNil.not) {
    postf("OK\n\n")
} {
    postf("\nWARNING: could not load SynthDef(s)!\n\n")
};

"Loading synth params...".postln;
if (this.executeFile(currentDir +/+ "synth_params.scd").isNil.not) {
    postf("OK\n\n")
} {
    postf("\nWARNING: could not load Synth Params!\n\n")
};

// Plates and decks.
// Plate is always a pair of decks: 0 is Left, 1 is Right.
// -- bookmark --
plates.add([]);

// GUI.
win = Window("XSM 0.01", Rect(0, 0, width, height)).background_(colorBg);
win.view.decorator = FlowLayout(win.view.bounds, margin@margin, gap@gap);

paneL = compViewFlow.(win, 0.35, 0.95, colorPane);
paneR = compViewFlow.(win, 0.648, 0.95, colorPane);
paneStatus = compViewFlow.(win, 0.998, 0.047, colorPane);

// GUI: synth ctrl section.
makeCtlStripe = { |place, deck|
    var pn;
    var parent = compViewFlow.(place, 0.498, 0.9);

    // Synth selector.
    dropdown.(parent,
        items: ~synthParams.values.collect(_.at(\name)),
        initVal: deck,
        action: { |dd| dd.postln },
    );

    // Stripes of knobs.
    2.do {
        pn = compViewFlow.(parent, 0.498, 0.49);
        3.do { |j|
            // The same number of elements as in midiMapCC
            ctrlsList.put(
                currCtrl,
                knob.(
                    pn,
                    " test ",
                    \freq.asSpec,
                    { |ez| ctlBus[currCtrl].value = ez.value },
                    bounds:knobWidth@knobHeight
                );
            );

            // The same idea, but indexing ctrl buses.
            currCtrl = currCtrl + 1;
        };
    };

    // Button.
    compViewFlow.(parent, 0.3, 0.05);
    pn = compViewFlow.(parent, 0.69, 0.05);

    // TODO: Proper labels:
    //       Left deck:
    //       - if current deck == 0: disabled
    //       - otherwise enabled and label "< PLATE"
    //       Right deck:
    //       - if current deck == maxDecks: disabled
    //       - if current deck is the last created, label "PLATE +"
    //       - if current deck is not the last created, label "PLATE >"
    button.(pn, "< PLATE", { |bt| bt.value.postln }, 0.5, 0.9);

    // 2 sliders.
    2.do { |j|
        compViewFlow.(parent, 0.15, 0.3); // panel before
        pn = compViewFlow.(parent, 0.208, 0.3);
        // the same number of elements as in midiMapCC
        ctrlsList.put(
            currCtrl,
            slider.(
                pn,
                " Vol  ",
                \db.asSpec.step_(0.01),
                { |ez| ctlBus[currCtrl].value = ez.value },
                layout: \vert
            )
        );
        compViewFlow.(parent, 0.15, 0.3); // panel after

        currCtrl = currCtrl+1; // the same idea, but indexing ctrl buses
    };

    // Presets buttons.
    pn = compViewFlow.(parent, 0.99, 0.1);
    // TODO: toggle buttons
    10.do { |j| button.(pn, (j+1).asString, { |bt| bt.value.postln }, 0.1, 0.1)};
};

// GUI: synth ctrl section.
makeTranspStripe = { |parent|
    var pn, scaleW=0.33, scaleH=0.1;

    // Transpost/Control buttons Left.
    pn = compViewFlow.(parent, scaleW, scaleH);
    button.(pn, "<<", { |bt| bt.value.postln }, 0.49, 0.4);
    button.(pn, ">>", { |bt| bt.value.postln }, 0.49, 0.4);
    button.(pn, ">/||", { |bt| bt.value.postln }, 0.49, 0.58);
    midiNoteOnMap.at(58).put(
        \gui,
        button.(pn, "_V_", { |bt| changeSynth.(0) }, 0.49, 0.58)
    );

    // Mix slider.
    pn = compViewFlow.(parent, scaleW, scaleH);
    ctrlsList.put(
        currCtrl,
        slider.(
            pn,
            " MIX ",
            \bipolar.asSpec,
            { |ez| ctlBus[currCtrl].value = ez.value },
            layout:\line2,
            scaleH:0.9
        )
    );

    // Transpost/Control buttons Right.
    pn = compViewFlow.(parent, scaleW, scaleH);
    button.(pn, "<<", { |bt| bt.value.postln }, 0.49, 0.4);
    button.(pn, ">>", { |bt| bt.value.postln }, 0.49, 0.4);
    button.(pn, ">/||", { |bt| bt.value.postln }, 0.49, 0.58);
    midiNoteOnMap.at(59).put(
        \gui,
        button.(pn, "_V_", { |bt| changeSynth.(1) }, 0.49, 0.58)
    );
};

makeCtlStripe.value(paneL, 0);
makeCtlStripe.value(paneL, 1);
makeTranspStripe.value(paneL);

win.fullScreen;
win.front;


// Wait for Server to boot
Server.default.waitForBoot {

};


// MIDI.
makeMIDI = {
    "> Initializing MIDI sources...".postln;
    if(MIDIClient.initialized.not) {
        MIDIClient.init;
    } {
        MIDIClient.list;
    };
    MIDIIn.connectAll;
};

midiFunc.add(
    // MIDI control messages.
    MIDIFunc.cc({
        arg ...args;
        (["CC"] ++ args).postln;
        // |val, num|
        // var midiMapCCIndex = -1, errCode=0;
        // [val, num].postln;
        // try { midiMapCCIndex = midiMapCC.indexOf(num) }{ errCode = 1 };
        // if(errCode.booleanValue.not, {
        //     [num, midiMapCCIndex].postln;
        //     { ctrlsList[midiMapCCIndex].valueAction_(val.linlin(0, 127, 0, 1)) }.defer;
        // });
    })
);

midiFunc.add(
    // MIDI Note On messages.
    MIDIFunc.noteOn({
        |val, num|
        midiNoteOnMap.at(num).at(\gui).valueAction.(1);
    })
);

midiFunc.add(
    // MIDI Note On messages.
    MIDIFunc.noteOff({
        arg ...args;
        (["note OFF"] ++ args).postln;
        // |val, num|
        // ["note OFF", val, num].postln;
        // midiNoteOnMap.at(num).at(\gui).action.(0);
    })
);

// Initialize MIDI.
makeMIDI.();

//
cleanup = {
    "> Cleaning up...".postln;
    "> Resetting bus counter...".postln;
    s.newBusAllocators;

    "> Freeing MIDI...".postln;
    midiFunc.do(_.free);

    "> Removing all functions...".postln;
    ServerBoot.removeAll;
    ServerTree.removeAll;
    ServerQuit.removeAll;
};


// What should be done when the window is closed.
win.onClose = {
    cleanup.()
};

CmdPeriod.doOnce({
    win.close;
});
)
