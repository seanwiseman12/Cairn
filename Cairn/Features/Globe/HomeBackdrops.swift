import Foundation

/// The home screen's opening photo: a famous mountain picked at random each
/// time the app launches, before any search. Hand-picked from peaks whose
/// Wikimedia Commons photo is a good landscape shot at least 1,500 px tall,
/// so it stays sharp cropped to a full portrait screen (see
/// tools/add_peak_photos.py); the ids are GeoNames ids from peaks.sqlite.
enum HomeBackdrops {
    static let peakIDs: [Int64] = [
        1283416, // Mount Everest
        1114951, // K2
        6941998, // Ama Dablam
        1169384, // Nanga Parbat
        1280882, // Mount Kailash
        5868589, // Denali
        5844913, // Mount Fairweather
        6079778, // Mount Assiniboine
        5807840, // Mount Rainier
        5571124, // Mount Shasta
        5731780, // Mount Hood
        5579295, // Longs Peak
        5094284, // Mount Washington
        3659238, // Chimborazo
        3866949, // Aconcagua
        157452,  // Kilimanjaro
        191421,  // Mount Kenya
        3360688, // Table Mountain
        325164,  // Mount Ararat
        2659729, // Matterhorn
        2658027, // Weisshorn
        2660928, // Eiger
        3165272, // Tre Cime di Lavaredo
        1736632, // Mount Kinabalu
        1629610, // Mount Rinjani
        2192136, // Aoraki / Mount Cook
        2191423, // Mount Taranaki
    ]

    static func randomPeakID() -> Int64 {
        DebugLaunch.backdropPeakID ?? peakIDs.randomElement() ?? 2659729
    }
}
