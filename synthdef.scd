(
// GENERATORS
var makeSynthDefADSR = { |name, outCodeFunc|
    // silent synth
    SynthDef("silent__" ++ name, {
        arg amp=0, out=0, trigID=80,
        filtFreq=440, filtParam=1.0, filtType=0, revDamp=0.5, revMix=0.25,
        atk=0.01, dec=0.5, sus=1, rel=0.5, cAtk=3, cRel=(-3),
        azimuth= -0.5pi, distance=0.1, elevation=0, depth=5, elevClip=0.01pi;

        var signal = Silent.ar();

        outCodeFunc.(
            signal, amp, out, trigID, azimuth, distance, elevation, elevClip, depth,
            filtFreq, filtParam, filtType, revDamp, revMix,
            atk, dec, sus, rel, cAtk, cRel
        );
    }).add;

    // audio-through
    SynthDef("audiothrough__" ++ name, {
        arg bufnum=0, in=0, out=0, trigID=80, amp=1,
        filtFreq=440, filtParam=1.0, filtType=0, revDamp=0.5, revMix=0.25,
        atk=0.01, dec=0.5, sus=1, rel=0.5, cAtk=3, cRel=(-3),
        azimuth= -0.5pi, distance=0.1, elevation=0, depth=5, elevClip=0.01pi;

        var input = InFeedback.ar(in, 1);
        var ds = distance/3.44;
        var reverb = FreeVerb.ar(input, distance.clip(0.01, 1), ds, 0.2);
        var delayed = DelayL.ar(reverb, 0.3, ds);
        var signal = RLPF.ar(delayed, distance.linlin(0, 2.sqrt, 10000, 1000), 0.5);

        outCodeFunc.(
            signal, amp, out, trigID, azimuth, distance, elevation, elevClip, depth,
            filtFreq, filtParam, filtType, revDamp, revMix,
            atk, dec, sus, rel, cAtk, cRel
        );
    }).add;

    //fm synth
    SynthDef("fm__" ++ name, {
        arg freq=500, amp=0.2, out=0, trigID=80,
        filtFreq=440, filtParam=1.0, filtType=0, revDamp=0.5, revMix=0.25,
        atk=0.01, dec=0.5, sus=0.5, rel=1, cAtk=4, cRel=(-4),
        azimuth= -0.5pi, distance=0.1, elevation=0, depth=5, elevClip=0.01pi,

        // synth specific
        mRatio=1, cRatio=1, index=1, iScale=5;

        var signal, mod, env, iEnv;

        //index of modulation
        iEnv = EnvGen.kr(
            Env(
                [index, index*iScale, index],
                [atk, rel],
                [cAtk, cRel]
            )
        );

        //modulator/carrier
        mod = SinOsc.ar(freq * mRatio, mul:freq * mRatio * iEnv);
        signal = SinOsc.ar(freq * cRatio + mod);

        outCodeFunc.(
            signal, amp, out, trigID, azimuth, distance, elevation, elevClip, depth,
            filtFreq, filtParam, filtType, revDamp, revMix,
            atk, dec, sus, rel, cAtk, cRel
        );
    }).add;

    // Moog emulation
    SynthDef("moogff__" ++ name, {
        // common args
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
        filtFreq=440, filtParam=1.0, filtType=0, revDamp=0.5, revMix=0.25,
        atk=0.01, dec=0.5, sus=1, rel=0.5, cAtk=3, cRel=(-3),
        azimuth= -0.5pi, distance=0.1, elevation=0, depth=5, elevClip=0.01pi,

        // synth specific args
        cutoff=1000, gain=2.5, reset=0;

        var signal = Saw.ar(freq * { Rand(-0.1, 0.1).midiratio }.dup(4));
        signal = Mix.ar(signal);
        signal = MoogFF.ar(signal, cutoff, gain, reset);

        outCodeFunc.(
            signal, amp, out, trigID, azimuth, distance, elevation, elevClip, depth,
            filtFreq, filtParam, filtType, revDamp, revMix,
            atk, dec, sus, rel, cAtk, cRel
        );
    }).add;


	SynthDef(\osc, {
		arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,

		arg buf=0, freq=200, detune=0.2,
		amp=0.2, pan=0, out=0, rout=0, rsend=(-20),
		atk=0.01, sus=1, rel=0.01, c0=1, c1=(-1);
		var sig, env, detuneCtrl;
		env = EnvGen.ar(
			Env([0,1,1,0],[atk,sus,rel],[c0,0,c1]),
			doneAction:2
		);

		//array of eight Oscs with uniquely detune frequencies
		//and unique initial phase offsets
		detuneCtrl = LFNoise1.kr(0.1!8).bipolar(detune).midiratio;
		sig = Osc.ar(buf, freq * detuneCtrl, {Rand(0,2pi)}!8);

		sig = Splay.ar(sig); //spread 8 signals over stereo field
		sig = LeakDC.ar(sig); //remove DC bias
		sig = Balance2.ar(sig[0], sig[1], pan, amp); //L/R balance (pan)
		sig = sig * env;
		Out.ar(out, sig);
		Out.ar(rout, sig * rsend.dbamp); //"post-fader" send to reverb
	}).add;


    SynthDef("cmb__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0, rate=1,
        filtFreq=440, filtParam=1.0, filtType=0, revDamp=0.5, revMix=0.25,
        atk=0.01, dec=0.5, sus=1, rel=0.5, cAtk=3, cRel=(-3),
        azimuth= -0.5pi, distance=0.1, elevation=0, depth=5, elevClip=0.01pi;

        var raw, signal;
        var delayL, delayR, pos=0.0, pulse, mix, n=8;
        pulse = LFNoise0.kr(rrand(0.2,1.0), 1,1).squared * rate;
        mix = Klank.ar(
            `[Array.fill(n, {exprand(1.0,20.0)}),
                nil,
                Array.fill(n, {0.2.rand})
            ],
            Blip.ar(pulse, [rrand(2,5), rrand(2,5)], 0.1)
        ).fold2(0.2).cubed * 12;
        raw = Mix.fill(3, {CombL.ar(mix, 0.1, 0.03.linrand, 4.0.linrand)});
        raw = raw.distort * 0.5;
        6.do({ raw= AllpassN.ar(raw, 0.05, [0.05.rand, 0.05.rand], 3) });
        signal = LeakDC.ar(raw * 0.5);

        outCodeFunc.(
            signal, amp, out, trigID, azimuth, distance, elevation, elevClip, depth,
            filtFreq, filtParam, filtType, revDamp, revMix,
            atk, dec, sus, rel, cAtk, cRel
        );
    }).add;


    SynthDef("probe__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0, rate=0.1,
        filtFreq=440, filtParam=1.0, filtType=0, revDamp=0.5, revMix=0.25,
        atk=0.01, dec=0.5, sus=1, rel=0.5, cAtk=3, cRel=(-3),
        azimuth= -0.5pi, distance=0.1, elevation=0, depth=5, elevClip=0.01pi,

        // synth specific
        offset=36, scope=12;

        var signal;
        var raw = LPZ2.ar(
            LFPulse.ar(
                freq, 2pi.rand, 0.1,
                (
                    Mix.ar(SinOsc.ar(rate * [rrand(0.7, 1.3), 1], [2pi.rand, 2pi.rand], 0.04)).max(0)
                    * Mix.ar(SinOsc.ar(exprand(6,24) * [rrand(0.7, 1.3), 1], [2pi.rand, 2pi.rand])).abs
                )
            )
        );
        2.do({ raw = AllpassN.ar(raw, 0.05, [0.01, 0.05], 3.0.rand) });
        signal = Limiter.ar(MidEQ.ar(Mix(raw), 1400, 0.7, 8), 0.8);

        outCodeFunc.(
            signal, amp, out, trigID, azimuth, distance, elevation, elevClip, depth,
            filtFreq, filtParam, filtType, revDamp, revMix,
            atk, dec, sus, rel, cAtk, cRel
        );
    }).add;
};

// default speaker placement configurations
// naming synths: "a<N>" ("a" for "ambisonic", <N> - num of channels)
var spatialConf = (
    "a2": (
        azim: #[-0.25pi, -0.75pi],
        elev: #[0, 0],
        dist: #[2, 2],
        maxDist: 2
    ),
    "a4": (
        azim: #[-0.25pi, -0.75pi, 0.75pi, 0.25pi],
        elev: #[0, 0, 0, 0],
        dist: #[2, 2, 2, 2],
        maxDist: 2
    ),
    "a6": (
        azim: #[-0.25pi, -0.5pi, -0.75pi, 0.75pi, 0.5pi, 0.25pi],
        elev: #[0, 0, 0, 0, 0, 0],
        dist: #[2, 2, 2, 2, 2, 2],
        maxDist: 2
    ),
    "a8": (
        azim: #[-0.25pi, -0.5pi, -0.75pi, 1pi, 0.75pi, 0.5pi, 0.25pi, 0],
        elev: #[0, 0, 0, 0, 0, 0, 0, 0],
        dist: #[2, 2, 2, 2, 2, 2, 2, 2],
        maxDist: 2
    ),
    "a10": (
        azim: #[-0.15, -0.25pi, -0.5pi, -0.75pi, 1pi, 0.75pi, 0.5pi, 0.25pi, 0.15pi, 0],
        elev: #[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        dist: #[2, 2, 2, 2, 2, 2, 2, 2, 2, 2],
        maxDist: 2
    ),
);


// add synths for stereo output
// name "s2": "s" for "stereo", 2 - num of channels
makeSynthDefADSR.("s2", {
    // Function for simple stereo output.
    arg signal, amp=1, out=0, trigID=80,
    // pan params, etc.
    azimuth=0, // converted to `center` in Splay (-1..1)
    distance=0.1, // converted to CombN's `decaytime` (input: 0..2.sqrt, output: 0.5..4)
    elevation=0, // - unused -
    elevClip=0.01pi, // - unused -
    depth=0.3, // => converted to Splay `spread` (0..1)
    // filter params
    filtFreq=440, // filter frequency, Hz (20..4000)
    filtParam=1.0, // filter RQ (for RL(H)PF), BWR (for Rezonz), decaytime (for Ringz) - CONVERT BEFORE SENDING!
    filtType=0, // 0: LPF, 1: BPF, 2: BRF, 3: HPF, 4: RLPF, 5: Resonz
    revDamp=0.5, // FreeVerb `damp` (0..1)
    revMix=0.25, // FreeVerb `mix`, i.e. dry/wet balance (0..1)
    // env params
    atk=0.01, decay=0.3, sus=0.8, rel=0.5, cAtk=3, cRel=(-3);

    var decaytime = distance.linexp(0, 2.sqrt, 0.5, 4.0);

    // input signal
    var sig = Mix.ar(signal);

    var env = Env.adsr(atk, decay, sus, rel, curve:[cAtk, cRel, cRel]).ar(Done.freeSelf, \gate.kr(1));

	// filtered signal with smooth parameter changes
	var filtTypeSmooth = Lag.kr(filtType.round, 0.5);

	var filtered = SelectX.ar(
		filtTypeSmooth, [
			LPF.ar(signal, filtFreq),               // 0: LPF
			BPF.ar(signal, filtFreq, filtParam),    // 1: BPF (rq)
			BRF.ar(signal, filtFreq, filtParam),    // 2: BRF (rq)
			HPF.ar(signal, filtFreq),               // 3: HPF (rq)
			RLPF.ar(signal, filtFreq, filtParam),   // 4: RLPF (rq)
			Resonz.ar(signal, filtFreq, filtParam), // 5: Resonz (bwr)
		]
	);

    // reverb
    var reverb = DelayN.ar(filtered, 0.03, 0.03);
    reverb = CombN.ar(reverb, 0.1, {Rand(0.01, 0.099)} ! 32, decay);
    reverb = SplayAz.ar(2, reverb);
	reverb = LPF.ar(reverb, filtFreq);
    5.do { reverb = AllpassN.ar(reverb, 0.1, {Rand(0.01,0.099)} ! 2, decay*0.75) };
	reverb = LPF.ar(reverb, filtFreq);

    filtered = (reverb * revMix) + (filtered * (1 - revMix));

    filtered = filtered * env * amp;

    // report (single channel after effects before Splay)
    SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(filtered));

    Out.ar(out, Splay.ar(filtered, spread:depth, center:azimuth))
});


// Warning: at the moment all synths are being created.
// TODO: make the choice between stereo and ambisonics depending on the configuration
spatialConf.keysValuesDo { |name, conf|
    // call SynthDef creation
    // `name` - name of spatial configuration
    // function - functionality of spatial configuration

    // synths based on ADSR
    // WARNING! Make this coice before adding SynthDefs
    makeSynthDefADSR.(name, {
        // Function for output second order ambisonic signal.
        arg signal, amp=1, out=0, trigID=80,
        // spatial params
        azimuth= -0.5pi, distance=0.1, elevation=0, elevClip=0.01pi, depth=5,
        // - unused -
        filtFreq=440, filtParam=1.0, filtType=0, revDamp=0.5, revMix=0.25,
        // env params
        atk=0.01, decay=0.3, sus=0.8, rel=0.5, cAtk=3, cRel=(-3);

        var elev=elevation.linlin(-0.5pi, 0.5pi, elevClip.neg, elevClip);
        var mix=distance.linexp(0, 2.sqrt, 0.001, 1.0);
        var room=distance.linexp(0, 2.sqrt, 0.001, 1.0);
        var dist=distance.linlin(0, 2.sqrt, 0, depth);
        var w, x, y, z, r, s, t, u, v;

        // envelope, reverb, filter
        var env = Env.adsr(atk, decay, sus, rel, curve:[cAtk, cRel, cRel]).ar(Done.freeSelf, \gate.kr(1));
        var reverb = FreeVerb.ar(Mix.ar(signal), mix, room, 0.2);
        var filtered = RLPF.ar(reverb, distance.linlin(0, 2.sqrt, 10000, 1000), 0.5);
        var output = filtered * env * amp;

        // report (single channel after effects before spatialisation)
        SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(output));

        // spatialisation
        #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(output, azimuth, elev, dist);

        Out.ar(out,
            FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
                azimuth: \azim.kr(conf.azim),
                elevation: \elev.kr(conf.elev),
                distance: \dist.kr(conf.dist),
                maxDist: \maxDist.kr(conf.maxDist),
            )
        );
    });
};
)
