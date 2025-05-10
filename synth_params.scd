(
// All SynthDefs must have the following args (not included into `~synthParams`):
// - out=0 out bus
// - fx=0 ctrl bus
// - fxsend=(-25) db
// - pan
// - amp
//
// TODO:
//
// Logic behind ~synthParams:
// - The first 6 params are knobs on a panel of XSession
// - There can be more than 6 parameters, but starting from 7th
//   they are ignored in the main 6-knobs panel
// - Sliders panel contain \amp and \pan, unless filled with param defs
//   (i.e. if a synth dictionary's key \sliders is empty or absent,
//   use them for amp and pan)
~synthParams = ( // synths dictionary
    fm: (
        name: "FM",
        def: \nv_fm,
		knobs: (
			freq: (
                spec: [20, 2000, \exp, 0.1, 500, units: " Hz"],
                label: "FREQ"
            ),
			car: (
                spec: [0.1, 10, \lin, 0.1, 1, units: ""],
                label: "CAR RATIO"
            ),
			mRatio: (
                spec: [0.1, 10, \lin, 0.1, 1, units: ""],
                label: "MOD RATIO"
            ),
			cRatio: (
                spec: [0.1, 10, \lin, 0.1, 1, units: ""],
                label: "CTL RATIO"
            ),
			index: (
                spec: [0.1, 10, \lin, 0.1, 1, units: ""],
                label: "index"
            ),
            iScale: (
                spec: [1, 10, \lin, 0.1, 5, units: ""],
                label: "IDX SCALE"
            )
        ),
        presets: [ ]
    ),
	cmb: (
		name: "CMB",
		def: \nv_cmb,
		sliders: (
			rate: #[0.2, 20, \lin, 0, 2].asSpec,
			amp: \amp.asSpec
			),
        presets: [ ]
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
			),
        presets: [ ]
		)
	)
)