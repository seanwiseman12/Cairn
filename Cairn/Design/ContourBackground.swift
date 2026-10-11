import SwiftUI

/// Taupe background covered in dark-brown topographic contour lines.
///
/// The lines are real contours: the app invents a smooth "terrain" height field
/// (layered value noise plus a gentle slope) and traces lines of equal height
/// with marching squares. That gives the organic, flowing shapes and small
/// closed loops of a hand-drawn topo map. Paths are cached per screen size.
struct ContourBackground: View {
    var body: some View {
        Canvas { context, size in
            context.stroke(
                ContourMap.path(for: size),
                with: .color(Theme.contourLine),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .background(Theme.khaki)
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

enum ContourMap {
    /// Height difference between neighbouring lines. Smaller means denser lines.
    private static let levelSpacing = 0.075
    /// Grid resolution in points for tracing.
    private static let step = 5.0

    private final class PathBox {
        let path: Path
        init(_ path: Path) { self.path = path }
    }

    private static let cache = NSCache<NSString, PathBox>()

    static func path(for size: CGSize) -> Path {
        let key = "\(Int(size.width))x\(Int(size.height))" as NSString
        if let cached = cache.object(forKey: key) { return cached.path }
        let path = trace(size)
        cache.setObject(PathBox(path), forKey: key)
        return path
    }

    /// The invented terrain: two layers of noise plus a diagonal slope, so lines
    /// mostly flow across the screen with the odd hill or hollow.
    private static func height(_ x: Double, _ y: Double) -> Double {
        let scale = 160.0
        let broad = ValueNoise.sample(x / scale, y / scale, seed: 11)
        let detail = ValueNoise.sample(x / (scale * 0.45), y / (scale * 0.45), seed: 29)
        let slope = (x * 0.55 + y) / 900
        return broad + 0.45 * detail + slope
    }

    /// Marching squares: for each height level, walk the grid and draw the line
    /// segment where the terrain crosses that level inside each cell.
    private static func trace(_ size: CGSize) -> Path {
        let cols = Int(size.width / step) + 2
        let rows = Int(size.height / step) + 2
        var values = [Double](repeating: 0, count: cols * rows)
        var low = Double.infinity
        var high = -Double.infinity
        for row in 0..<rows {
            for col in 0..<cols {
                let value = height(Double(col) * step, Double(row) * step)
                values[row * cols + col] = value
                low = min(low, value)
                high = max(high, value)
            }
        }

        var path = Path()
        func segment(_ from: CGPoint, _ to: CGPoint) {
            path.move(to: from)
            path.addLine(to: to)
        }

        var level = (low / levelSpacing).rounded(.up) * levelSpacing
        while level < high {
            for row in 0..<(rows - 1) {
                for col in 0..<(cols - 1) {
                    // Corners: a top-left, b top-right, c bottom-right, d bottom-left.
                    let a = values[row * cols + col]
                    let b = values[row * cols + col + 1]
                    let c = values[(row + 1) * cols + col + 1]
                    let d = values[(row + 1) * cols + col]

                    var index = 0
                    if a > level { index |= 8 }
                    if b > level { index |= 4 }
                    if c > level { index |= 2 }
                    if d > level { index |= 1 }
                    if index == 0 || index == 15 { continue }

                    let x = Double(col) * step
                    let y = Double(row) * step
                    func t(_ v1: Double, _ v2: Double) -> Double { (level - v1) / (v2 - v1) }
                    let top = CGPoint(x: x + step * t(a, b), y: y)
                    let right = CGPoint(x: x + step, y: y + step * t(b, c))
                    let bottom = CGPoint(x: x + step * t(d, c), y: y + step)
                    let left = CGPoint(x: x, y: y + step * t(a, d))

                    switch index {
                    case 1, 14: segment(left, bottom)
                    case 2, 13: segment(bottom, right)
                    case 3, 12: segment(left, right)
                    case 4, 11: segment(top, right)
                    case 6, 9: segment(top, bottom)
                    case 7, 8: segment(left, top)
                    case 5: segment(left, top); segment(bottom, right)
                    case 10: segment(left, bottom); segment(top, right)
                    default: break
                    }
                }
            }
            level += levelSpacing
        }
        return path
    }
}

/// Smooth pseudo-random noise in 0...1: random values on a grid, blended with a
/// quintic curve. The same inputs always give the same output.
enum ValueNoise {
    static func sample(_ x: Double, _ y: Double, seed: UInt64) -> Double {
        let x0 = floor(x), y0 = floor(y)
        let fx = fade(x - x0), fy = fade(y - y0)
        let i = Int(x0), j = Int(y0)
        let top = lerp(hash(i, j, seed), hash(i + 1, j, seed), fx)
        let bottom = lerp(hash(i, j + 1, seed), hash(i + 1, j + 1, seed), fx)
        return lerp(top, bottom, fy)
    }

    private static func fade(_ t: Double) -> Double { t * t * t * (t * (t * 6 - 15) + 10) }
    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    private static func hash(_ i: Int, _ j: Int, _ seed: UInt64) -> Double {
        var h = (UInt64(bitPattern: Int64(i)) &* 0x9E37_79B9_7F4A_7C15)
            ^ (UInt64(bitPattern: Int64(j)) &* 0xC2B2_AE3D_27D4_EB4F)
            ^ seed
        h ^= h >> 33
        h = h &* 0xFF51_AFD7_ED55_8CCD
        h ^= h >> 33
        return Double(h & 0xFF_FFFF) / Double(0xFF_FFFF)
    }
}

/// Tiny random dots, used by `.speckled()` to give lettering a worn print texture.
struct Speckle: View {
    var color: Color
    /// Dots per square point.
    var density = 0.05

    var body: some View {
        Canvas { context, size in
            var random = SeededRandom(seed: 7)
            var dots = Path()
            let count = Int(size.width * size.height * density)
            for _ in 0..<count {
                let x = random.next() * size.width
                let y = random.next() * size.height
                let r = 0.3 + random.next() * 0.7
                dots.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            context.fill(dots, with: .color(color))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Deterministic random numbers (SplitMix64), so textures look the same every launch.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    /// A value in 0..<1.
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
}

#Preview {
    ContourBackground()
}
