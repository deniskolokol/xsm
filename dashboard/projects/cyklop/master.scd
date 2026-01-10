~master = (
    master01: (
        outputChannel: (
            \bus: 0,
            \level: 0.8,
            \pan: 0.0,
            \wide: 0.6,
            \mode: \stereo
        ),
        synths: [
            (
                synthName: \proc_compressor,
                preset: \flat,
                amount: 0.25
            ),
            (
                synthName: \proc_parametric_eq,
                preset: \vocal_boost,
                amount: 0.3
            ),
            (
                synthName: \proc_limiter,
                preset: \hard,
                amount: 0.5
            )
        ]
    ),
    master23: (
        outputChannel: (
            bus: 2,
            level: 0.8,
            pan: 0.4,
            wide: 0.2,
            mode: \stereo
        ),
        synths: [
            (
                synthName: \proc_compressor,
                preset: \punchy,
                amount: 0.3
            ),
            (
                synthName: \proc_eq,
                preset: \bass_boost,
                amount: 0.4
            )
        ]
    ),
    master45: (
        outputChannel: (
            bus: 4,
            level: 0.7,
            pan: -0.2,
            wide: 0.4,
            mode: \stereo
        ),
        synths: [
            (
                synthName: \proc_compressor,
                preset: \smooth,
                amount: 0.2
            ),
            (
                synthName: \proc_parametric_eq,
                preset: \treble_cut,
                amount: 0.35
            ),
            (
                synthName: \proc_limiter,
                preset: \soft,
                amount: 0.4
            )
        ]
    ),
    master67: (
        outputChannel: (
            bus: 6,
            level: 0.9,
            pan: 0.1,
            wide: 0.5,
            mode: \stereo
        ),
        synths: [
            (
                synthName: \proc_compressor,
                preset: \gentle,
                amount: 0.15
            ),
            (
                synthName: \proc_eq,
                preset: \mid_scoop,
                amount: 0.25
            )
        ]

    )
)