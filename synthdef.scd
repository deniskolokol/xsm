(
//fm synth
SynthDef("fm", {
    arg freq=500, mRatio=1, cRatio=1,
    index=1, iScale=5, cAtk=4, cRel=(-4),
    amp=0.2, atk=0.01, rel=3, pan=0,
    out=0, fx=0, fxsend=(-25);

    var car, mod, env, iEnv;

    //index of modulation
    iEnv = EnvGen.kr(
        Env(
            [index, index*iScale, index],
            [atk, rel],
            [cAtk, cRel]
        )
    );

    //amplitude envelope
    env = EnvGen.kr(Env.perc(atk,rel,curve:[cAtk,cRel]),doneAction:2);

    //modulator/carrier
    mod = SinOsc.ar(freq * mRatio, mul:freq * mRatio * iEnv);
    car = SinOsc.ar(freq * cRatio + mod) * env * amp;

    car = Pan2.ar(car, pan);

    //direct out
    Out.ar(out, car);

    // FX send
    Out.ar(fx, car * fxsend.dbamp);
}).add;


SynthDef("cmb", {
    arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0, rate=1,
    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr=(-3),
    fx=0, fxsend=(-25);

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

    //direct out
    Out.ar(out, signal);

    // FX send
    Out.ar(fx, signal * fxsend.dbamp);
}).add;


SynthDef("probe", {
    arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0, rate=0.1,
    gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr=(-3),
    offset=36, scope=12, fx=0, fxsend=(-25);
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
    2.do({ raw = AllpassN.ar(raw, 0.05, [0.01, 0.05], 3.0.rand, amp) });
    signal = Limiter.ar(MidEQ.ar(Mix(raw), 1400, 0.7, 8), 0.8);

    //direct out
    Out.ar(out, signal);

    // FX send
    Out.ar(fx, signal * fxsend.dbamp);
}).add;

)