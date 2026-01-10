~UnitFX = (
    eerie: (
        groupID: nil,       // <Integer> group ID for the FX group (set upon creation)
        busInternal: nil,   // <Bus> private bus for the FX group (set upon creation)
        busIn: nil,         // <Bus> input bus for the FX group (set upon creation)
        busOut: nil,        // <Bus> output bus for the FX group (set upon creation)
        processing: \chain, // <Symbol> processing type: \chain or \parallel
        effects: (
            delay: (
                nodeID: nil,           // <Integer> node ID of the delay synth instance (set upon creation)
                synthName: \fx_delay,  // <Symbol> name of the delay synthdef
                preset: \long,         // <Symbol> variant of the delay (as defined in the delay library)
                amount: 0.25           // <Float> wet/dry mix amount 0.0 to 1.0 (technically it's a synth argument, should override the preset)
            ),
            reverb: (
                nodeID: nil,
                synthName: \fx_reverb,
                preset: \large,
                amount: 0.4
            )
        )
    ),
    spacious: (
        groupID: nil,
        busInternal: nil,
        busIn: nil,
        busOut: nil,
        processing: \parallel,
        effects: (
            delay: (
                nodeID: nil,
                synthName: \fx_delay,
                preset: \short,
                amount: 0.15
            ),
            reverb: (
                nodeID: nil,
                synthName: \fx_reverb,
                preset: \large,
                amount: 0.2
            )
        )
    ),
    dry: (
        groupID: nil,
        busInternal: nil,
        busIn: nil,
        busOut: nil,
        processing: \chain,
        effects: (
            reverb: (
                nodeID: nil,
                synthName: \fx_reverb,
                preset: \dry,
                amount: 0.0
            )
        )
    )
);

// The filters are sequentially applied to the audio signal on a private bus.
// The output of the filter group is routed to the FX private bus.
~Filters = (
    distorted: (
        groupID: nil, // <Integer> group ID for the filter group (set upon creation)
        route: nil,   // <Bus> private bus for the filter group (set upon creation)
        fxUnit: \dry, // <Symbol> name of the unit FX to route the output to
        filter: (
            nodeID: nil,           // <Integer> node ID of the filter synth instance (set upon creation)
            synthName: \filt_rlpf, // <Symbol> name of the filter synthdef
            preset: \warm,         // <Symbol> variant of the filter (as defined in the filter library)
            amount: 0.0            // <Float> wet/dry mix amount 0.0 to 1.0 (technically it's a synth argument, should override the preset)
        ),
        overdrive: (
            nodeID: nil,
            synthName: \Difuzz,
            preset: \banshee,
            amount: 0.5
        )
    ),
    low_pass: (
        groupID: nil,
        route: nil,
        fxUnit: \spacious,
        filter: (
            nodeID: nil,
            synthName: \filt_lpf,
            preset: \dry,
            amount: 0.15
        ),
        overdrive: (
            synthName: \dist_overdrive,
            preset: \soft,
            amount: 0.0
        )
    ),
    mid_boost: (
        groupID: nil,
        route: nil,
        fxUnit: \spacious,
        filter: (
            nodeID: nil,
            synthName: \filt_bpf,
            preset: \punch,
            amount: 0.3
        ),
        overdrive: (
            nodeID: nil,
            synthName: \dist_overdrive,
            preset: \crisp,
            amount: 0.2
        )
    ),
    flat: (
        groupID: nil,
        route: nil,
        fxUnit: \dry,
        filter: (
            nodeID: nil,
            synthName: \filt_lpf,
            preset: \dry,
            amount: 0.0
        ),
        overdrive: (
            nodeID: nil,
            synthName: \dist_overdrive,
            preset: \soft,
            amount: 0.0
        )
    )
);

~Patterns = (
    p_beat: (
        patterns: [ // <Array> list of pattern names as defined in the pattern library (Pdef or Pbindef)
            beat_x1,
            beat_x2,
        ],
        filter: \distorted, // <Symbol> name of the filter configuration to apply (from the ~Filters context)
    ),
    p_pad: (
        patterns: [
            pad,
            pad_s,
        ],
        filter: \low_pass
    ),
    p_bass: (
        patterns: [
            bass
        ],
        filter: \flat
    ),
    p_melody: (
        patterns: [
            pulse,
            melody,
        ],
        filter: \mid_boost
    )
);