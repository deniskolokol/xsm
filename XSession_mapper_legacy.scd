(
var synthParams = ( // synths dictionary
	cmb: (
		name: "CMB",
		def: \nv_cmb,
		sliders: (
			rate: #[0.2, 20, \lin, 0, 2].asSpec,
			amp: \amp.asSpec
			)
		),
	probe: (
		name: "Probe",
		def: \nv_probe,
		knobs: (
			rate: \unipolar.asSpec,
			delayl: [0.0001, 0.05, \lin, 0, 0.3, units: " secs"].asSpec,
			delayr: [0.0001, 0.05, \lin, 0, 0.3, units: " secs"].asSpec,
			pan: \pan.asSpec
			),
		sliders: (
			amp: \amp.asSpec,
			fbase: \midfreq.asSpec
			)
		)
	);

//--window setup
// Server.default = s = Server.internal;
s.waitForBoot{
	var synDecks=2;
	var width=500, height=800;
	var fontLabel=Font("Helvetica", 13);
	var fontControl=Font("Helvetica", 10);
	var win;
	var uvSynths=List.new, uvRouts=List.new, stSynthSelect=List.new;
	var knobsOnDeck=3, slidersOnDeck=2, knobs=List.new, sliders=List.new;
	var midiMap=[
		24, 25, 26, 12,
		27, 28, 29, 11,
		34, 35, 36, 14,
		31, 32, 33, 15,
		17
	];
	var stripeSynthData=Array.fill(synDecks, {nil});
	var ctrlsList=Array.fill(midiMap.size, {nil});
	var ctlBus=Array.fill(midiMap.size, {Bus.control(s)});
	var ccResp_xSessionPro, nOnResp_xSessionPro, nOffResp_xSessionPro,
		ccResp_eobody, xSessionPro= -1410198277, eobody=2104456446;
	var currCtrl=0;
	var getSpec, getSynthName, getSynthKey, changeSynth;
	var synthList=List.new;
	var stripeWidth, knobWidth, knobHeight;

	// global list for easy access
	synthParams.keysValuesDo {|k, v| synthList.add(v.matchAt(\def))};

	synDecks.do {|i| knobs.add(List.new); sliders.add(List.new)};

	// GUI.
	win = Window("novox 0.01", width@height);
	win.background = Color.black;
	win.view.decorator = FlowLayout(win.view.bounds, 5@5, 5@5);
	stripeWidth = (win.bounds.width / synDecks) * 0.8;
	knobWidth = stripeWidth * 0.6;
	knobHeight = knobWidth * 1.2;

	//synths ctrls
	synDecks.do { |i|
		var panel;
		var currCtrlElt, currSynthKey;

		panel = FlowView(win, stripeWidth@(height*0.99))
		.background_(Color.grey(0.8));

		// Label for synth selection.
		stSynthSelect.add(
			StaticText(panel, 40@20)
				.font_(fontLabel)
				.string_(getSynthName.value(i))
		);

		//current synth data
		currSynthKey = getSynthKey.value(i);

		knobsOnDeck.do { |j|
			currCtrlElt = EZKnob(
				panel,
				knobWidth@knobHeight,
				" test ",
				\freq,
				{ |ez| ctlBus[currCtrl].value = ez.value },
				layout:\vert, margin: m)
			.font_(fontControl)
			.setColors(
				Color.grey,
				Color.white,
				Color.grey,
				Color.white,
				Color.yellow,
				nil,
				nil,
				Color.grey(0.7)
			);
			knobs[i].add(currCtrlElt);

			// The same number of elements as in midiMap.
			ctrlsList.put(currCtrl, currCtrlElt);

			// The same idea, but indexing ctrl buses.
			currCtrl = currCtrl + 1;
		};

		slidersOnDeck.do { |j|
			currCtrlElt = EZSlider(
				panel,
				(stripeWidth*0.85)@200,
				" Vol  ", \db.asSpec.step_(0.01),
				{ |ez| ctlBus[currCtrl].value = ez.value },
				unitWidth:30, numberWidth:60, layout:\vert, margin: m
			)
			.font_(fontControl)
			.setColors(
				Color.grey,
				Color.white,
				Color.grey(0.7),
				Color.grey,
				Color.white,
				Color.yellow,
				nil,
				nil,
				Color.grey(0.7)
			);
			sliders[i].add(currCtrlElt);
			ctrlsList.put(currCtrl, currCtrlElt); // the same number of elements as in midiMap
			currCtrl = currCtrl+1; // the same idea, but indexing ctrl buses
		};
	};

	// The last slider - Xfade.
	ctrlsList.put(
		currCtrl,
		EZSlider(
			win,
			(stripeWidth*2-10)@20,
			" xfade ", [-1,1].asSpec.step_(0.01),
			{ |ez| ctlBus[currCtrl].value = ez.value },
			0, unitWidth:30, numberWidth:60, layout:\horz, margin: m)
		.font_(Font("Helvetica", 10))
		.setColors(Color.grey,Color.white, Color.grey(0.7), Color.grey,
			Color.white, Color.yellow,nil,nil, Color.grey(0.7));
	);

	//
	getSynthKey = { |synthIndex|
		var key = nil, sName = nil;
		try{ key = synthParams.keys.asArray.at(synthIndex) };
		key
	};

	getSynthName = { |synthIndex|
		var key = nil, sName = nil;
		key = getSynthKey.value(synthIndex);
		if {key.isNilnot} {sName = synthParams.matchAt(key).matchAt(\name)};
		sName
	};

	changeSynth = { |deck, dir = 1|
		synthList
	};

	// MIDI: X-Session Pro
	ccResp_xSessionPro = CCResponder({ |src, chan, num, val|
		var midiMapIndex = -1, errCode=0;
//		[src,chan,num,val].postln;
		try { midiMapIndex = midiMap.indexOf(num) }{ errCode = 1 };
		if(errCode.booleanValue.not, {
			[num, midiMapIndex].postln;
			{ ctrlsList[midiMapIndex].valueAction_(val.linlin(0, 127, 0, 1)) }.defer;
		});
	},
	xSessionPro, nil, nil, nil // X-Session Pro
	);
	nOnResp_xSessionPro = NoteOnResponder({|src, chan, num, val|
	//	[src,chan,num,val].postln;
		case
			{ num == 44 } { // [Headphone Button Left]

			}
			{ num == 45 } { // [Headphone Button Right]

			}
			{ num == 46 } {  // << Button Left
				changeSynth.value(deck:0, dir:-1);
			}
		},
		xSessionPro, nil, nil, nil
	);

	win.onClose = {
		ccResp_xSessionPro.remove
		};
	win.front;

	CmdPeriod.doOnce({
		win.close;
		});
}
)



(
SynthDef(\nv_cmb, { |outbus=0, rate=1, amp=1|
	var mix, out, pulse, n = 8;
	pulse = LFNoise0.kr(rrand(0.2,1.0), 1,1).squared * rate;
	mix = Klank.ar(
		`[Array.fill(n, {exprand(1.0,20.0)}),
			nil,
			Array.fill(n, {0.2.rand})
			],
		Blip.ar(pulse, [rrand(2,5),rrand(2,5)], 0.1)
	).fold2(0.2).cubed * 12;
	mix = Mix.arFill(3, { CombL.ar(mix, 0.1, 0.03.linrand, 4.0.linrand) });
	out = mix.distort * 0.5;
	6.do({out = AllpassN.ar(out, 0.05, [0.05.rand, 0.05.rand], 3)});
	out = LeakDC.ar(out);
	Out.ar(outbus, out)
}).send(s);

SynthDef(\nv_probe, { |outbus=0, rate=0.1, amp=1, fbase=80, pan=0, dtl=0.01, dtr=0.05|
	var mix;
	var rateRnd = rate.max(0.1) * exprand(3,8);
	mix = LPZ2.ar(
		LFPulse.ar( // populate the sin w/SinOsc
			fbase, 2pi.rand, 0.1,
			(Mix.ar(SinOsc.ar(rateRnd * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand], 0.04)).max(0)
			* Mix.ar(SinOsc.ar(exprand(6,24) * [rrand(0.7,1.3),1], [2pi.rand,2pi.rand])).abs)
			)
		);
	2.do({ mix = AllpassN.ar(mix, 0.05, [dtl,dtr], 3.0.rand, 2); });
	Out.ar(outbus, Pan2.ar(mix, pan, amp))
}).send(s);
)

a = Synth(\nv_cmb, [\amp, 0.5]);
a.set(\rate, 0.2)

b = Synth(\nv_probe, [\amp, 0.5]);
b.set(\fbase, 51)

c = Synth(\nv_probe, [\amp, 0.5]);
c.set(\fbase, 36)

a.free;
b.free;
c.free;

(
MIDIClient.init; // intialize the client
4.do({ arg i; MIDIIn.connect(i, MIDIClient.sources.at(i)); });
MIDIIn.control = {|src, chan, num, val|
	switch(num.postln,
		24, {~radius = val.linlin(0, 127, 0, 50)},		//ctrl number 1 sets the size
		25, {~dir = ~dir.put(0, val.linlin(0, 127, -pi, pi))},
		26, {~dir = ~dir.put(1, val.linlin(0, 127, -pi, pi))},
		17, {~layers = val.linlin(0, 127, 1, 50)},

		31, { b.set(\rate, val.linlin(0, 127, 0, 1)) },
		32, { b.set(\dtl, val.linlin(0, 127, 0.0001, 0.05)) },
		33, { b.set(\dtr, val.linlin(0, 127, 0.0001, 0.05)) },
		15, { b.set(\fbase, val.linlin(0, 127, 25, 4000)) },
		14, { b.set(\amp, val.linlin(0, 127, 0, 1)) },

		34, { c.set(\rt, val.linlin(0, 127, 0, 1)) },
		35, { c.set(\dtl, val.linlin(0, 127, 0.0001, 0.05)) },
		36, { c.set(\dtr, val.linlin(0, 127, 0.0001, 0.05)) }
	);
};
MIDIIn.noteOn = {|src, chan, num, vel|
	~dir = [
		num.linlin(0, 127, -pi, pi),				//note affects horizontal speed
		vel.linlin(0, 127, -pi, pi)					//velocity vertical speed
	];
	if(vel>115, {									//very high velocity rearranges
		~balls = {|i| [i*num%640, i*7%480, i%~layers]}.dup(400);
	});
};
)
