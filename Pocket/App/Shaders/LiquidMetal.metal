// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
//
// The splash's liquid metal glass: a mercury droplet springs in over the
// Satu Visual star, bends it through its rim into colour, mirrors a studio
// whose light flows round it, then lets go and leaves the star.
//
// The glass optics (superellipse tile, rim refraction with spectral
// dispersion, corner focus, double bevel, specular, sheen, halo, ripple) are
// ported from zanwei/glass-icon-reveal, MIT licence, Copyright (c) zanwei
// (https://github.com/zanwei/glass-icon-reveal), by way of the WebGL2 port in
// p441z.my.id's GlassLogoReveal. New here: the star as an analytic distance
// field (no texture), and the chrome: a flowing studio reflection, split per
// channel at the rim, laid over the glass.
//
// Coordinates follow the original: `p` is y-up with the tile's half-width
// as 1, so the plate at scale 1 spans -1…1.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// The order of the uniforms in the float array. Keep in step with
// `GlassUniform` in GlassTimeline.swift.
enum {
    U_CX, U_CY, U_TILE, U_TIME, U_PLATE_SCALE, U_SHAPE_N, U_CORNER_N, U_OPTICS, U_PLATE_ALPHA, U_LOGO_HALF,
    U_BOLD, U_BLUR, U_FROST, U_DOME, U_DROP, U_PINCH, U_TILT, U_RIM, U_HALO, U_SHADOW, U_GHOST, U_RIP_R, U_RIP_A,
    U_BARE, U_REACH, U_CORNER_PULL, U_STREAK, U_WIDEN, U_SLAB, U_ETA_SPREAD, U_FOCUS, U_FOCUS_K, U_FOCUS_SPLIT,
    U_RIM_LINE, U_CORNER_ON, U_DISSOLVE, U_GLOW, U_FACE_DISP, U_VIVID, U_DISP, U_DOUBLE, U_BEVEL_W, U_SPEC,
    U_ICON_PLATE, U_LIGHT_SCENE, U_LIGHT_GLASS, U_KEEP, U_SHEEN, U_SWEEP, U_LIGHT_ANG, U_METAL, U_SCALE, U_COUNT
};

namespace liquid {

float2 rot(float2 v, float a) { float c = cos(a), s = sin(a); return float2(c * v.x - s * v.y, s * v.x + c * v.y); }

float sdBox(float2 p, float2 b) {
    float2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

/// The Satu Visual star in its own units (the 203.6-point square of
/// logo-satu-visual.svg, centred): two straight and two diagonal bars,
/// less the small X at its heart. Measured from the path in make-icon.swift.
float sdStar(float2 p) {
    float2 r = float2(p.x + p.y, p.y - p.x) * 0.70710678;
    float bars = min(min(sdBox(p, float2(101.8, 13.95)), sdBox(p, float2(13.95, 101.8))),
                     min(sdBox(r, float2(101.65, 13.95)), sdBox(r, float2(13.95, 101.65))));
    float hole = min(sdBox(r, float2(28.15, 5.57)), sdBox(r, float2(5.57, 28.15)));
    return max(bars, -hole);
}

/// The star's coverage at `q`, its half-size `halfSize`, softened by `blur`.
float logoAt(float2 q, float blur, float aa, float halfSize, float bold) {
    float k = 101.8 / halfSize;
    float d = sdStar(q * k) / k;
    float w = 0.75 * aa + blur;
    return 1.0 - smoothstep(-w, w, d - bold * halfSize);
}

/// A superellipse of exponent `n`: its signed distance, outward normal,
/// level `g` and gradient `dg`.
float shape(float2 p, float scale, float n, thread float2 &nOut, thread float &g, thread float2 &dg) {
    float2 pp = p / scale;
    float2 a = max(abs(pp), float2(1e-6));
    g = pow(pow(a.x, n) + pow(a.y, n), 1.0 / n);
    dg = sign(pp) * pow(a, float2(n - 1.0)) * pow(max(g, 1e-6), 1.0 - n);
    float dgl = max(length(dg), 1e-6);
    nOut = dg / dgl;
    return (g - 1.0) / dgl * scale;
}

float contourRadius(float2 p, float scale, float n) {
    float2 a = max(abs(p / scale), float2(1e-4));
    float2 a1 = pow(a, float2(n - 1.0));
    float2 a2 = pow(a, float2(n - 2.0));
    float k = (n - 1.0) * (a2.x * a1.y * a1.y + a2.y * a1.x * a1.x) / pow(max(dot(a1, a1), 1e-30), 1.5);
    return scale / max(k, 1e-3);
}

/// Where a ray through the bevel at depth `x` lands on the star, for a
/// refractive index `eta` (Snell through a rounded slab).
float2 refractSample(float x, float bwF, float eta, float R, float2 dirOut, float2 p, float dome, float offMul,
                     float slab, float optics) {
    float u = clamp(1.0 - x, 0.0, 0.995);
    float th = asin(u), thr = asin(u / eta);
    float z = slab + bwF * sqrt(1.0 - u * u);
    float off = offMul * z * tan(th - thr);
    off = off / (1.0 + off / (6.0 * R));
    return p - (dirOut * off + p * dome) * optics;
}

float gauss(float x, float c, float w) { float d = (x - c) / w; return exp(-0.5 * d * d); }
float band(float x, float a, float b, float w) { return smoothstep(a - w, a, x) * (1.0 - smoothstep(b, b + w, x)); }

/// Weights of one wavelength (0 red … 1 violet) in red, green and blue.
float3 spectrum(float x) {
    return float3(gauss(x, 0.34, 0.2) + 0.08 * gauss(x, 0.93, 0.05), gauss(x, 0.58, 0.1), gauss(x, 0.8, 0.11));
}

float hash(float2 p) { return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }

/// The studio the metal mirrors, seen along `r` (z toward the viewer): a
/// bright sky over a dark floor, split by a horizon that bends and flows,
/// and two softbox strips sliding across. `ang` turns the whole room.
float studio(float3 r, float ang, float t) {
    float2 d = rot(r.xy, ang);
    float h = d.y + 0.16 * sin(d.x * 3.1 + t * 1.7) + 0.08 * sin(d.x * 7.3 - t * 2.3);
    float sky = mix(0.62, 1.0, smoothstep(0.0, 0.8, h));
    float ground = mix(0.03, 0.24, smoothstep(-0.9, 0.0, h));
    float v = mix(ground, sky, smoothstep(-0.035, 0.035, h));
    float s1 = exp(-pow((d.x - 0.5 - 0.25 * sin(t * 0.9)) / 0.07, 2.0)) * smoothstep(-0.2, 0.4, d.y);
    float s2 = exp(-pow((d.x + 0.55 - 0.2 * sin(t * 1.3 + 1.0)) / 0.05, 2.0));
    return v + 0.9 * s1 + 0.5 * s2;
}

} // namespace liquid

using namespace liquid;

/// SwiftUI `colorEffect`: `color` is the screen's background where the
/// shader draws; `u` the frame's uniforms; `plateIn` the tile's colour under
/// the dark look; `logoIn` the star's ink.
[[ stitchable ]] half4 liquidMetal(float2 position, half4 color, device const float *u, int count,
                                  half4 plateIn, half4 logoIn) {
    if (count < U_COUNT) return color;
    float3 uBg = float3(color.rgb);
    float3 uPlateCol = float3(plateIn.rgb);
    float3 uLogoCol = float3(logoIn.rgb);

    float tile = u[U_TILE];
    float px = 2.0 / (tile * u[U_SCALE]);
    float2 p = float2(position.x - u[U_CX], u[U_CY] - position.y) * (2.0 / tile);

    float plateScale = u[U_PLATE_SCALE], shapeN = u[U_SHAPE_N], optics = u[U_OPTICS];
    float logoHalf = u[U_LOGO_HALF], bold = u[U_BOLD], blur = u[U_BLUR];
    float lightScene = u[U_LIGHT_SCENE], lightGlass = u[U_LIGHT_GLASS], keep = u[U_KEEP];

    float lg = logoAt(p, blur, px, logoHalf, bold);
    float3 plain = mix(uBg, uLogoCol, lg * u[U_BARE]);

    float2 nOut, dg; float g;
    float sd = shape(p, plateScale, shapeN, nOut, g, dg);
    float s = -sd;
    float bw = max(u[U_BEVEL_W], 0.004) * plateScale;
    float x = clamp(s / bw, 0.0, 1.0);

    // Everything outside the glass: the background, its halo, shadow and ripple.
    float3 bg = uBg;
    float3 lift = mix(uBg + float3(0.06), mix(uBg, float3(1.0), 0.55), lightScene);
    float ghost = u[U_GHOST];
    if (ghost > 0.001) {
        float2 gn, gdg; float gg;
        float gsd = shape(p, 1.0, u[U_CORNER_N], gn, gg, gdg);
        bg = mix(bg, lift, ghost * 0.12 * (1.0 - smoothstep(-0.16, 0.14, gsd)));
        bg *= 1.0 - ghost * 0.03 * lightScene * exp(-max(gsd, 0.0) / 0.12) * step(0.0, gsd);
    }
    float outside = max(sd, 0.0);
    float ripA = u[U_RIP_A];
    if (ripA > 0.001) {
        float d0 = (u[U_RIP_R] - 1.0) * plateScale;
        float rx = (sd - d0) / 0.022;
        float ring = exp(-rx * rx);
        bg += ripA * ring * (0.04 * (0.55 + 0.45 * dot(nOut, normalize(float2(-0.5, 0.8))))) * mix(0.5, 1.0, lightScene);
        bg -= ripA * 0.016 * lightScene * exp(-(rx - 1.6) * (rx - 1.6));
    }
    float shadowFall = max(sd, 0.0) / (0.9 * plateScale);
    bg *= 1.0 - u[U_SHADOW] * 0.03 * exp(-shadowFall * shadowFall) * step(0.0, sd);
    float3 haloCol = mix(float3(0.62, 0.69, 0.80), float3(1.0), lightScene);
    bg = mix(bg, haloCol, clamp(u[U_HALO] * (0.30 * exp(-outside / (0.025 * plateScale)) + 0.07 * exp(-outside / (0.12 * plateScale))), 0.0, 1.0) * step(0.0, sd));

    float3 col = bg;
    float dissolve = u[U_DISSOLVE];
    float soft = px + blur * 0.8 + 0.06 * dissolve * (1.0 - keep) * plateScale;
    if (sd < soft) {
        // The glass: how the surface slopes (bevel, second bevel, dome)…
        float R = contourRadius(p, plateScale, shapeN);
        float2 pq = p * p;
        float diag = 4.0 * pq.x * pq.y / max((pq.x + pq.y) * (pq.x + pq.y), 1e-6);
        float tilt = mix(1.0 - u[U_TILT], 1.0, smoothstep(-0.02, 0.02, p.x * p.y));
        float pinchPart = u[U_PINCH] * min(g * g, 1.0) * diag * diag * tilt;
        float dome = u[U_DOME] * (1.0 - min(g * g, 1.0)) + pinchPart;
        float2 dirOut = normalize(mix(nOut, p / max(length(p), 1e-4), 0.2));
        float cornerOn = u[U_CORNER_ON];
        float cornerness = max(smoothstep(0.1, 0.9, 4.0 * nOut.x * nOut.x * nOut.y * nOut.y), smoothstep(0.15, 0.75, diag));
        float offMul = 1.0 + 0.4 * max(u[U_CORNER_PULL] - 1.0, 0.0) * tilt * cornerness * cornerOn;
        float2 focus = sign(p) * (pow(0.5, 1.0 / shapeN) - u[U_FOCUS] * 0.70710678) * plateScale;
        float focusW = tilt * cornerness * optics * cornerOn;
        float bwF = max(u[U_REACH], 0.004) * (1.0 + u[U_WIDEN] * tilt * cornerness * cornerOn);
        float xf = clamp(s / bwF, 0.0, 1.0);
        float slab = u[U_SLAB];
        float2 qc = refractSample(xf, bwF, 1.5, R, dirOut, p, dome, offMul, slab, optics);
        float foot = px * (1.0 + 2.0 * optics * (1.0 - xf));

        float y1 = 1.0 - x;
        const float K = 2.6;
        float base1 = max(1.0 - pow(y1, K), 1e-4);
        float db = min(pow(y1, K - 1.0) * pow(base1, 1.0 / K - 1.0), 25.0);
        float s1 = bw * 0.62;
        float w2 = bw * 0.22;
        float t2 = clamp((s - s1) / w2, -1.0, 1.0);
        float dh2 = u[U_DOUBLE] * bw * 0.16;
        float dd = dh2 * 0.5 * cos(t2 * 1.5707963) * 1.5707963 / w2 * step(abs(t2), 0.999);
        float2 gDome = -u[U_DOME] * 2.0 * g * dg * step(g, 1.0);
        float2 grad = -(db + dd) * nOut + gDome;

        // …what it lets through: the star, bent at the rim and split into
        // its spectrum, one wavelength per sample…
        float3 back = mix(uBg, uPlateCol, u[U_ICON_PLATE]);
        float3 liftG = mix(back + float3(0.06), mix(back, float3(1.0), 0.55), lightGlass);
        float rblur = blur + 0.05 * length(qc - p) + min(u[U_GLOW] * optics * (1.0 - xf) * foot / px, 0.04);
        float cornerW = smoothstep(0.1, 0.9, 4.0 * nOut.x * nOut.x * nOut.y * nOut.y);
        float streak = 0.35 * u[U_STREAK] * bw * mix(0.15, 1.0, cornerW) * pow(1.0 - xf, 1.5) * optics;
        float2 tangent = float2(-nOut.y, nOut.x);
        float disp = u[U_DISP], faceDisp = u[U_FACE_DISP], etaSpread = u[U_ETA_SPREAD];
        float3 acc = float3(0.0), wsum = float3(0.0);
        const int samples = 14;
        for (int i = 0; i < samples; i++) {
            float lam = (float(i) + 0.5) / float(samples);
            float c = disp * (1.0 - 2.0 * lam);
            float2 along = tangent * (streak * 2.0 * (fract(float(i) * 0.618034 + 0.31) - 0.5));
            float cf = c * (lam > 0.5 ? 1.0 : 0.5);
            float2 sp = refractSample(xf, bwF, 1.5 + etaSpread * c, R, dirOut, p + along, dome + pinchPart * 0.3 * c, offMul, slab, optics);
            float2 focusL = focus - sign(p) * (0.70710678 * u[U_FOCUS_SPLIT] * c * plateScale);
            float wFocus = pow(1.0 - xf, u[U_FOCUS_K]) * smoothstep(0.0, u[U_RIM_LINE] * (1.0 + 0.6 * c), xf);
            sp = mix(sp, mix(p + along, focusL, wFocus), focusW);
            float faceOnly = smoothstep(0.7, 1.0, xf) * optics;
            sp *= 1.0 + faceDisp * cf * faceOnly;
            float l = logoAt(sp, rblur + 0.12 * streak + faceDisp * 0.5 * max(c, 0.0) * faceOnly, foot, logoHalf, bold);
            float3 w = spectrum(lam);
            acc += mix(back, uLogoCol, l) * w;
            wsum += w;
        }
        float3 trans = acc / wsum;
        float tl = dot(trans, float3(0.2126, 0.7152, 0.0722));
        trans = clamp(tl + (trans - tl) * (1.0 + u[U_VIVID] * optics), 0.0, 1.0);
        float hazeLum = dot(trans, float3(0.2126, 0.7152, 0.0722));
        float hazeGate = mix(1.0 - smoothstep(0.25, 0.75, hazeLum), smoothstep(0.25, 0.75, hazeLum), lightGlass);
        trans = mix(trans, liftG, u[U_FROST] * 0.45 * hazeGate);

        // …and the light on it: rim glow, edge line, lip, Fresnel, specular.
        float glassAmt = pow(1.0 - dissolve, 1.5);
        float lit = u[U_SPEC] * glassAmt;
        float drop = u[U_DROP];
        float lightAng = u[U_LIGHT_ANG];
        float3 rimCol = mix(float3(0.80, 0.87, 0.97), float3(1.0), lightGlass);
        float sc = plateScale;
        float tLum = dot(trans, float3(0.2126, 0.7152, 0.0722));
        float lightOnly = smoothstep(0.35, 0.85, tLum);
        float hw = smoothstep(-0.85, 0.5, dot(nOut, rot(float2(0.5, 0.866), lightAng)));
        float tileBand = band(s, 0.016 * sc, 0.075 * sc, 0.022 * sc);
        float dropBand = (1.0 - smoothstep(0.06 * sc, 0.13 * sc, s)) * smoothstep(0.0, 0.004 * sc, s);
        float glow = mix(0.32 * tileBand, 0.75 * dropBand, drop) * lightOnly;
        float edgeLine = gauss(s, 0.005 * sc, 0.0045 * sc);
        float lip = gauss(s, 0.15 * sc, 0.007 * sc) * u[U_DOUBLE] * (1.0 - drop);
        float3 lightG = mix(trans, float3(1.0), glow * glassAmt);
        lightG += (0.075 * hw * edgeLine + 0.06 * (0.4 + 0.6 * hw) * lip) * lit;
        lightG *= 1.0 - 0.05 * (1.0 - hw) * edgeLine * glassAmt * (1.0 - drop);
        lightG = mix(lightG, float3(1.0), 0.55 * drop * glassAmt * edgeLine);

        float3 Nl = normalize(float3(-grad, 1.0));
        float edge = 1.0 - Nl.z;
        float2 ldir = rot(normalize(float2(-0.62, 0.78)), lightAng);
        float side = dot(nOut, ldir);
        float fres = pow(edge, 1.5);
        float3 rim = rimCol * fres * (0.35 + 0.65 * max(side, -side * 0.8)) * u[U_RIM] * 0.65;
        float3 Hv = normalize(normalize(float3(-0.45, 0.6, 0.66)) + float3(0.0, 0.0, 1.0));
        float spc = pow(max(dot(Nl, Hv), 0.0), 140.0) * 0.8 * smoothstep(0.0, 0.25, y1);
        float3 darkG = trans * (1.0 - 0.25 * fres) + (rim + float3(spc)) * lit;
        darkG = mix(darkG, rimCol, drop * 0.4 * u[U_SPEC] * (1.0 - smoothstep(0.0, 0.1 * plateScale, s)));
        float3 glass = mix(darkG, lightG, lightGlass);

        // Liquid metal: the surface mirrors a studio. Each channel reflects
        // off a slightly different slope, so the rim's reflection splits
        // into colour too. The young droplet is mostly mercury; the held
        // tile clears in its face so the star reads, and stays chrome at the rim.
        float metalAmt = u[U_METAL] * glassAmt;
        if (metalAmt > 0.001) {
            float t = u[U_TIME];
            float split = 0.09 * disp * edge;
            float3 rr = reflect(float3(0.0, 0.0, -1.0), normalize(float3(Nl.xy * (1.0 + split), Nl.z)));
            float3 rg = reflect(float3(0.0, 0.0, -1.0), Nl);
            float3 rb = reflect(float3(0.0, 0.0, -1.0), normalize(float3(Nl.xy * (1.0 - split), Nl.z)));
            float3 env = float3(studio(rr, lightAng, t), studio(rg, lightAng, t), studio(rb, lightAng, t));
            env *= mix(float3(0.93, 0.96, 1.03), float3(1.0, 0.99, 0.97), lightScene);
            float face = mix(0.14, 0.42, drop);
            float m = metalAmt * clamp(face + (1.0 - face) * smoothstep(0.0, 0.35, edge), 0.0, 1.0);
            glass = mix(glass, env, m);
            glass += float3(spc) * lit * 0.6;
        }

        float sweepD = dot(p / plateScale, normalize(float2(0.8, 0.6))) - u[U_SWEEP];
        float sheen = u[U_SHEEN] * glassAmt * exp(-sweepD * sweepD / 0.03) * (0.55 + 0.45 * (1.0 - x));
        glass = mix(glass, float3(1.0), sheen * mix(0.22, 0.42, lightGlass));

        float cov = clamp(0.5 - sd / soft, 0.0, 1.0);
        col = mix(bg, glass, cov);
    }

    float3 outc = mix(plain, col, u[U_PLATE_ALPHA]);
    outc += (hash(position * u[U_SCALE]) - 0.5) / 255.0;
    return half4(half3(clamp(outc, 0.0, 1.0)), 1.0h);
}
