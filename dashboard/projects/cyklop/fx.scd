~fx = (
    eerie: (
        processing: \chain,
        synths: [
            (
                synthName: \fx_delay,
                preset: \long,
                amount: 0.25
            ),
            (
                synthName: \fx_reverb,
                preset: \large,
                amount: 0.4
            )
        ]
    ),
    spacious: (
        processing: \parallel,
        synths: [
            (
                synthName: \fx_delay,
                preset: \short,
                amount: 0.15
            ),
            (
                synthName: \fx_reverb,
                preset: \large,
                amount: 0.2
            ),
            (
                synthName: \fx_flanger,
                preset: \default,
                amount: 0.0
            )
        ]
    ),
    dry: (
        processing: \chain,
        synths: [
            (
                synthName: \fx_reverb,
                preset: \dry,
                amount: 0.0
            )
        ]
    )
)