#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Draws the home-screen globe, one pixel at a time on the GPU.
//
// For each pixel: work out which spot on Earth it shows (an orthographic
// projection, run backwards), look up that spot's elevation in the relief
// texture, then draw contour lines wherever the elevation crosses a round number.
// The relief texture stores elevation as a 16-bit number split over two
// channels: value = (elevation + 11000 m) / 20000 m * 65535, R = high byte,
// G = low byte. Hardware filtering would blend the bytes separately, so the
// shader reads raw texels and blends them itself.

namespace {

/// Screen point -> latitude/longitude (radians). `z` is how much the spot faces
/// the viewer (1 at the center, 0 at the rim). Returns false off the globe.
bool unproject(float2 p, float2 center, float radius, float centerLon, float centerLat,
               thread float &lat, thread float &lon, thread float &z) {
    float2 q = (p - center) / radius;
    float r2 = dot(q, q);
    if (r2 > 1.0) return false;
    float x = q.x;
    float y = -q.y;
    z = sqrt(1.0 - r2);
    float cosLat = cos(centerLat);
    float sinLat = sin(centerLat);
    float worldY = y * cosLat + z * sinLat;
    float worldZ = -y * sinLat + z * cosLat;
    lat = asin(clamp(worldY, -1.0, 1.0));
    lon = centerLon + atan2(x, worldZ);
    return true;
}

/// Elevation in metres stored at one texel. Longitude wraps; latitude clamps.
float texelElevation(texture2d<half> tex, int x, int y) {
    int width = int(tex.get_width());
    int height = int(tex.get_height());
    x = ((x % width) + width) % width;
    y = clamp(y, 0, height - 1);
    half4 c = tex.read(uint2(x, y));
    float value = round(float(c.r) * 255.0) * 256.0 + round(float(c.g) * 255.0);
    return value / 65535.0 * 20000.0 - 11000.0;
}

/// Elevation in metres at a spot: positive on land, negative under the sea.
/// Blends the four nearest texels.
float elevation(texture2d<half> tex, float lat, float lon) {
    float x = (lon / (2.0 * M_PI_F) + 0.5) * float(tex.get_width()) - 0.5;
    float y = (0.5 - lat / M_PI_F) * float(tex.get_height()) - 0.5;
    float x0 = floor(x);
    float y0 = floor(y);
    float fx = x - x0;
    float fy = y - y0;
    int ix = int(x0);
    int iy = int(y0);
    float top = mix(texelElevation(tex, ix, iy), texelElevation(tex, ix + 1, iy), fx);
    float bottom = mix(texelElevation(tex, ix, iy + 1), texelElevation(tex, ix + 1, iy + 1), fx);
    return mix(top, bottom, fy);
}

/// Coverage (0-1) of lines drawn wherever `value` hits a multiple of `interval`.
/// `perPoint` is how much `value` changes per screen point, which turns the
/// distance to the line into points so lines stay `width` points wide.
float isolines(float value, float interval, float perPoint, float width) {
    float distance = abs(fract(value / interval + 0.5) - 0.5) * interval;
    float points = distance / max(perPoint, 1e-6);
    return 1.0 - smoothstep(width * 0.5 - 0.5, width * 0.5 + 0.5, points);
}

/// Coverage of a single line where `value` crosses `target`.
float lineAt(float value, float target, float perPoint, float width) {
    float points = abs(value - target) / max(perPoint, 1e-6);
    return 1.0 - smoothstep(width * 0.5 - 0.5, width * 0.5 + 0.5, points);
}

float wrapAngle(float a) {
    return a - 2.0 * M_PI_F * round(a / (2.0 * M_PI_F));
}

} // namespace

[[ stitchable ]] half4 topoGlobe(float2 position, half4 color,
                                 float2 center, float radius, float zoom,
                                 float centerLon, float centerLat,
                                 texture2d<half> tex,
                                 half4 landColor, half4 seaColor, half4 landInk, half4 seaInk) {
    // Extra detail fades in as you zoom (0 at normal size, 1 from about 5x).
    float detail = smoothstep(2.5, 5.0, zoom);

    radius -= 1.5;
    float2 offset = position - center;
    float fromEdge = radius - length(offset); // points inside the rim
    if (fromEdge < -1.0) return half4(0.0);

    // Sample slightly inside the rim so edge pixels still land on the globe.
    float2 p = fromEdge < 0.5 ? center + offset * ((radius - 0.5) / max(length(offset), 1e-3)) : position;

    float lat, lon, z;
    unproject(p, center, radius, centerLon, centerLat, lat, lon, z);
    float here = elevation(tex, lat, lon);

    // Neighbouring points (two points right, two points down) to measure how fast
    // things change across the screen; measuring over 2 points keeps line widths
    // even despite the texture's 8-bit steps. Fall back to "no change" past the rim.
    const float step = 2.0;
    float latX = lat, lonX = lon, latY = lat, lonY = lon, zN;
    unproject(p + float2(step, 0.0), center, radius, centerLon, centerLat, latX, lonX, zN);
    unproject(p + float2(0.0, step), center, radius, centerLon, centerLat, latY, lonY, zN);
    float right = elevation(tex, latX, lonX);
    float below = elevation(tex, latY, lonY);
    // Metres of elevation change per screen point.
    float rate = length(float2(right - here, below - here)) / step;

    // Land and sea split exactly at 0 m, anti-aliased to about a point.
    float isLand = clamp(here / max(rate, 1e-4) + 0.5, 0.0, 1.0);
    half4 base = mix(seaColor, landColor, half(isLand));

    float land = max(here, 0.0);
    float depth = max(-here, 0.0);

    // Land: a line every 500 m, a heavier one every 2000 m, and when zoomed in,
    // lighter lines every 100 m.
    float landLines = max(max(isolines(land, 500.0, rate, 0.8),
                              isolines(land, 2000.0, rate, 1.3)),
                          isolines(land, 100.0, rate, 0.6) * detail * 0.55) * isLand;
    // Coastline: the 0 m contour, drawn heaviest.
    float coast = lineAt(here, 0.0, rate, 1.5);
    // Ocean: faint depth lines every 1500 m (every 500 m when zoomed in).
    float seaLines = max(isolines(depth, 1500.0, rate, 0.8) * 0.4,
                         isolines(depth, 500.0, rate, 0.6) * detail * 0.25) * (1.0 - isLand);

    // Faint latitude/longitude grid every 30 degrees, plus every 10 when zoomed in.
    float toDeg = 180.0 / M_PI_F;
    float latRate = length(float2(latX - lat, latY - lat)) * toDeg / step;
    float lonRate = length(float2(wrapAngle(lonX - lon), wrapAngle(lonY - lon))) * toDeg / step;
    float grid = max(max(isolines(lat * toDeg, 30.0, latRate, 0.7),
                         isolines(wrapAngle(lon) * toDeg, 30.0, lonRate, 0.7)) * 0.2,
                     max(isolines(lat * toDeg, 10.0, latRate, 0.6),
                         isolines(wrapAngle(lon) * toDeg, 10.0, lonRate, 0.6)) * detail * 0.12);

    // Lines on land use the land ink; depth lines and the grid use the sea ink.
    half4 result = mix(base, seaInk, half(max(seaLines, grid)));
    result = mix(result, landInk, half(max(landLines, coast)));

    // Gentle darkening toward the rim so it reads as a ball, not a disc.
    result.rgb *= half(mix(0.8, 1.0, sqrt(z)));

    // Thin pale ring around the globe, then anti-alias the outer edge.
    float rim = 1.0 - smoothstep(0.6, 1.8, fromEdge);
    result = mix(result, landColor, half(rim * 0.6));
    float coverage = clamp(fromEdge + 1.0, 0.0, 1.0);
    return result * half(coverage);
}
