~tone = (
    tight_metal: (
        fxUnit: \dry,
        synths: [
            (
                type: \filter,
                synthName: \filt_rlpf,
                preset: \dark,
                amount: 0.6
            ),
            (
                type: \overdrive,
                synthName: \od_overdrive,
                preset: \kick,
                amount: 0.7
            )
        ]
    ),
    distorted: (
        fxUnit: \dry,
        synths: [
            (
                type: \overdrive,
                synthName: \od_fuzz,
                preset: \banshee,
                amount: 0.5
            ),
            (
                type: \filter,
                synthName: \filt_rlpf,
                preset: \warm,
                amount: 0.0
            )
        ]
    ),
    low_pass: (
        fxUnit: \spacious,
        synths: [
            (
                type: \overdrive,
                synthName: \od_overdrive,
                preset: \soft,
                amount: 0.0
            ),
            (
                type: \filter,
                synthName: \filt_rlpf,
                preset: \dry,
                amount: 0.15
            )
        ]
    ),
    flat: (
        fxUnit: \dry,
        synths: [
            (
                type: \filter,
                synthName: \filt_rlpf,
                preset: \dry,
                amount: 0.0
            ),
            (
                type: \overdrive,
                synthName: \od_overdrive,
                preset: \soft,
                amount: 0.0
            )
        ]
    )
)
