import SwiftUI

// MARK: - DiagramSide
// Chooses which anatomical view to render.
// Small list badges (32–38 pt) pass a single side driven by the muscle group.
// Large detail views (≥ 200 pt) render both sides separately in a HStack.
enum DiagramSide {
    case front
    case back
}

// MARK: - MuscleDiagramView
//
// Geometric anatomy diagram icon styled after gym machine muscle diagrams.
// Every region is a rectangle or trapezoid — no curves — for a modern,
// clean block-anatomy look that reads clearly at any size.
//
// Front view layout (top → bottom):
//   Head (ellipse) → Collar (trapezoid) → Deltoids (rect caps)
//   Arms (rect, beside body) | Pectorals (2 trapezoids) | →
//   Obliques (2 side trapezoids) + Abs 3×2 grid (6 rects) →
//   V-taper (trapezoid) → Upper legs (2 rects) → Lower legs (2 rects)
//
// Back view layout:
//   Head → Collar → Deltoids → Arms (rect, beside body)
//   Lats (2 long trapezoids) → Rear V-taper (small trapezoid) →
//   Glutes (2 rects) → Upper legs (2 rects) → Lower legs (2 rects)
//
// The target muscle group is highlighted in its accent colour; all other
// regions are muted. Tinted rounded-square background (accent at 14 %).

struct MuscleDiagramView: View {

    let muscleGroup: MuscleGroup
    let side: DiagramSide
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            // Tinted background
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(muscleGroup.color.opacity(0.14))

            Canvas { ctx, canvas in
                let w = canvas.width
                let h = canvas.height

                // Scale normalised coordinate to canvas point
                func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                    CGPoint(x: x * w, y: y * h)
                }

                // Closed straight-edged polygon (for trapezoids)
                func poly(_ c: [(CGFloat, CGFloat)]) -> Path {
                    var p = Path()
                    guard let f = c.first else { return p }
                    p.move(to: pt(f.0, f.1))
                    for v in c.dropFirst() { p.addLine(to: pt(v.0, v.1)) }
                    p.closeSubpath()
                    return p
                }

                // Rounded rectangle (for block shapes)
                let cr = size * 0.055  // corner radius — scales with icon size
                func rRect(_ x: CGFloat, _ y: CGFloat,
                           _ rw: CGFloat, _ rh: CGFloat) -> Path {
                    Path(roundedRect: CGRect(x: x * w, y: y * h,
                                            width: rw * w, height: rh * h),
                         cornerRadius: cr)
                }

                let muted = GraphicsContext.Shading.color(Color.secondary.opacity(0.28))
                let lit   = GraphicsContext.Shading.color(muscleGroup.color)

                func draw(_ path: Path, active: Bool) {
                    ctx.fill(path, with: active ? lit : muted)
                }

                // ── Shared shapes (identical in both views) ───────────────

                // Head
                let head = Path(ellipseIn: CGRect(
                    x: 0.370 * w, y: 0.010 * h,
                    width: 0.260 * w, height: 0.112 * h))

                // Collar / neck — trapezoid, wider at top
                let collar = poly([
                    (0.402, 0.130), (0.598, 0.130),
                    (0.562, 0.182), (0.438, 0.182)
                ])

                // Deltoid caps — square-ish blocks at shoulder junctions
                let lDelt = rRect(0.062, 0.182, 0.138, 0.082)
                let rDelt = rRect(0.800, 0.182, 0.138, 0.082)

                // Arms — tall rectangles hanging from deltoids
                // (same height for both views so the silhouette matches)
                let lArm  = rRect(0.078, 0.272, 0.104, 0.448)   // ends ≈ 0.720
                let rArm  = rRect(0.818, 0.272, 0.104, 0.448)

                // ── View-specific shapes ───────────────────────────────────

                switch side {

                // ── FRONT VIEW ────────────────────────────────────────────
                case .front:

                    // Pectorals — 2 trapezoids under collar
                    // Wider at shoulder line, slightly narrower at bottom
                    let lPec = poly([
                        (0.208, 0.190), (0.490, 0.190),
                        (0.468, 0.370), (0.252, 0.370)
                    ])
                    let rPec = poly([
                        (0.510, 0.190), (0.792, 0.190),
                        (0.748, 0.370), (0.532, 0.370)
                    ])

                    // Obliques — 2 side trapezoids, outer edge vertical,
                    // inner edge tapers slightly inward toward waist
                    let lObl = poly([
                        (0.208, 0.378), (0.296, 0.378),
                        (0.280, 0.562), (0.208, 0.562)
                    ])
                    let rObl = poly([
                        (0.704, 0.378), (0.792, 0.378),
                        (0.792, 0.562), (0.720, 0.562)
                    ])

                    // Abdominals — 3 rows × 2 columns of rounded squares
                    // Col starts: left = 0.308, right = 0.538 (width each = 0.154)
                    // Row starts: 0.378, 0.442, 0.506  (height each = 0.054, gap 0.010)
                    let a1L = rRect(0.308, 0.378, 0.154, 0.054)
                    let a1R = rRect(0.538, 0.378, 0.154, 0.054)
                    let a2L = rRect(0.308, 0.442, 0.154, 0.054)
                    let a2R = rRect(0.538, 0.442, 0.154, 0.054)
                    let a3L = rRect(0.308, 0.506, 0.154, 0.054)
                    let a3R = rRect(0.538, 0.506, 0.154, 0.054)

                    // V-taper — trapezoid connecting torso to legs
                    // Full torso width at top, narrows to leg-gap width at bottom
                    let vTaper = poly([
                        (0.208, 0.562), (0.792, 0.562),
                        (0.614, 0.642), (0.386, 0.642)
                    ])

                    // Legs — 4 rectangles (upper + lower per side)
                    let lUL = rRect(0.208, 0.650, 0.280, 0.166)
                    let rUL = rRect(0.512, 0.650, 0.280, 0.166)
                    let lLL = rRect(0.224, 0.824, 0.248, 0.164)
                    let rLL = rRect(0.528, 0.824, 0.248, 0.164)

                    // Draw all shapes, muted by default
                    ctx.fill(head, with: muted)
                    for p in [collar, lDelt, rDelt, lPec, rPec,
                              lObl, rObl,
                              a1L, a1R, a2L, a2R, a3L, a3R,
                              vTaper, lArm, rArm,
                              lUL, rUL, lLL, rLL] {
                        ctx.fill(p, with: muted)
                    }

                    // Apply highlights
                    switch muscleGroup {
                    case .chest:
                        draw(lPec,  active: true)
                        draw(rPec,  active: true)
                    case .core:
                        draw(lObl,  active: true)
                        draw(rObl,  active: true)
                        draw(a1L,   active: true); draw(a1R, active: true)
                        draw(a2L,   active: true); draw(a2R, active: true)
                        draw(a3L,   active: true); draw(a3R, active: true)
                    case .arms:
                        draw(lArm,  active: true)
                        draw(rArm,  active: true)
                    case .legs:
                        draw(lUL,   active: true); draw(rUL, active: true)
                        draw(lLL,   active: true); draw(rLL, active: true)
                    case .shoulders:
                        draw(lDelt, active: true)
                        draw(rDelt, active: true)
                    case .back:
                        break  // back muscles not visible from front
                    }

                // ── BACK VIEW ─────────────────────────────────────────────
                case .back:

                    // Lats — 2 longer trapezoids
                    // Wide at shoulder line, taper toward waist (V-taper effect)
                    let lLat = poly([
                        (0.208, 0.190), (0.490, 0.190),
                        (0.380, 0.530), (0.208, 0.530)
                    ])
                    let rLat = poly([
                        (0.510, 0.190), (0.792, 0.190),
                        (0.792, 0.530), (0.620, 0.530)
                    ])

                    // Rear V-taper — small trapezoid (lower back / lumbar)
                    // Fills the gap between lat bottoms, narrows further
                    let rearV = poly([
                        (0.380, 0.530), (0.620, 0.530),
                        (0.572, 0.612), (0.428, 0.612)
                    ])

                    // Glutes — 2 rectangles
                    let lGlute = rRect(0.208, 0.620, 0.280, 0.104)
                    let rGlute = rRect(0.512, 0.620, 0.280, 0.104)

                    // Legs — 4 rectangles (upper + lower per side)
                    let lUL = rRect(0.208, 0.732, 0.280, 0.130)
                    let rUL = rRect(0.512, 0.732, 0.280, 0.130)
                    let lLL = rRect(0.224, 0.870, 0.248, 0.118)
                    let rLL = rRect(0.528, 0.870, 0.248, 0.118)

                    // Draw all shapes, muted by default
                    ctx.fill(head, with: muted)
                    for p in [collar, lDelt, rDelt, lArm, rArm,
                              lLat, rLat, rearV,
                              lGlute, rGlute,
                              lUL, rUL, lLL, rLL] {
                        ctx.fill(p, with: muted)
                    }

                    // Apply highlights
                    switch muscleGroup {
                    case .back:
                        draw(lLat,   active: true)
                        draw(rLat,   active: true)
                        draw(rearV,  active: true)
                    case .arms:
                        draw(lArm,   active: true)
                        draw(rArm,   active: true)
                    case .legs:
                        draw(lUL,    active: true); draw(rUL, active: true)
                        draw(lLL,    active: true); draw(rLL, active: true)
                    case .shoulders:
                        draw(lDelt,  active: true)
                        draw(rDelt,  active: true)
                    case .chest, .core:
                        break  // chest/core not visible from back
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Small icons (list badge size)
        HStack(spacing: 12) {
            ForEach(MuscleGroup.allCases, id: \.self) { group in
                VStack(spacing: 4) {
                    MuscleDiagramView(
                        muscleGroup: group,
                        side: group == .back ? .back : .front,
                        size: 50)
                    Text(group.rawValue).font(.caption2)
                }
            }
        }

        // Large front + back pair (detail view size)
        HStack(spacing: 16) {
            MuscleDiagramView(muscleGroup: .chest,    side: .front, size: 120)
            MuscleDiagramView(muscleGroup: .back,     side: .back,  size: 120)
            MuscleDiagramView(muscleGroup: .legs,     side: .front, size: 120)
            MuscleDiagramView(muscleGroup: .core,     side: .front, size: 120)
        }
    }
    .padding()
}
