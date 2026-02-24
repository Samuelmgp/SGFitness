import SwiftUI

// MARK: - DiagramSide
// Chooses which anatomical view to render.
// Small list badges (32–38 pt) pass a single side driven by the muscle group.
// Large detail views (≥ 200 pt) render a single side chosen by the caller.
enum DiagramSide {
    case front
    case back
}

// MARK: - MuscleDiagramView
//
// Geometric anatomy diagram icon styled after gym machine muscle diagrams.
// All regions are sharp polygons (no rounded corners) — no curves — for a modern,
// clean block-anatomy look that reads clearly at any size.
//
// Front view layout (top → bottom):
//   Head (ellipse) → Collar (trapezoid)
//   Deltoids (pizza-slice triangles, in line with collar bottom)
//   Arms (upper arm + forearm — 2 sharp trapezoids per side, beside the torso)
//   Pectorals (2 trapezoids) | Obliques (2 side trapezoids) + Abs 3×2 grid
//   V-taper (trapezoid) → Upper legs (2 rects) → Lower legs (2 rects)
//
// Back view layout:
//   Head → Collar → Deltoids (pizza slice) → Arms (2 parts per side)
//   Lats (2 wide trapezoids spreading outward at shoulder, tapering at waist)
//   Rear V-taper (small trapezoid) → Glutes (2 rects) → Legs (4 rects)
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

                // Closed straight-edged polygon (sharp corners — no curves)
                func poly(_ c: [(CGFloat, CGFloat)]) -> Path {
                    var p = Path()
                    guard let f = c.first else { return p }
                    p.move(to: pt(f.0, f.1))
                    for v in c.dropFirst() { p.addLine(to: pt(v.0, v.1)) }
                    p.closeSubpath()
                    return p
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
                    width: 0.260 * w, height: 0.110 * h))

                // Collar / neck — trapezoid wider at top, narrower at bottom
                let collar = poly([
                    (0.400, 0.128), (0.600, 0.128),
                    (0.562, 0.180), (0.438, 0.180)
                ])

                // Deltoids — pizza-slice triangles at shoulder line.
                // Short top edge spans from torso edge to shoulder outer;
                // long inner diagonal runs from torso edge down to the tip;
                // short outer edge is nearly vertical.
                // Both sit flush at collar-bottom level (y = 0.180).
                let lDelt = poly([
                    (0.058, 0.180), (0.208, 0.180),  // top edge: outer → inner (short)
                    (0.066, 0.288)                    // tip pointing down-outer
                ])
                let rDelt = poly([
                    (0.792, 0.180), (0.942, 0.180),  // top edge: inner → outer (short)
                    (0.934, 0.288)                    // tip pointing down-outer
                ])

                // Arms — two sharp trapezoid sections per side (upper arm + forearm).
                // Both taper slightly inward toward the wrist.
                // Separated from deltoid tip by an 0.008 gap (y 0.288 → 0.296).

                let lUA = poly([                      // left upper arm
                    (0.058, 0.296), (0.194, 0.296),
                    (0.186, 0.468), (0.066, 0.468)
                ])
                let rUA = poly([                      // right upper arm
                    (0.806, 0.296), (0.942, 0.296),
                    (0.934, 0.468), (0.814, 0.468)
                ])
                let lFA = poly([                      // left forearm
                    (0.066, 0.476), (0.182, 0.476),
                    (0.170, 0.638), (0.074, 0.638)
                ])
                let rFA = poly([                      // right forearm
                    (0.818, 0.476), (0.934, 0.476),
                    (0.926, 0.638), (0.830, 0.638)
                ])

                // ── View-specific shapes ───────────────────────────────────

                switch side {

                // ── FRONT VIEW ────────────────────────────────────────────
                case .front:

                    // Pectorals — 2 trapezoids under collar.
                    // Wider at shoulder line, slightly narrower toward the waist.
                    let lPec = poly([
                        (0.216, 0.188), (0.490, 0.188),
                        (0.468, 0.368), (0.252, 0.368)
                    ])
                    let rPec = poly([
                        (0.510, 0.188), (0.784, 0.188),
                        (0.748, 0.368), (0.532, 0.368)
                    ])

                    // Obliques — narrow side trapezoids.
                    // Outer edge vertical, inner edge tapers inward toward waist.
                    let lObl = poly([
                        (0.216, 0.376), (0.304, 0.376),
                        (0.288, 0.560), (0.216, 0.560)
                    ])
                    let rObl = poly([
                        (0.696, 0.376), (0.784, 0.376),
                        (0.784, 0.560), (0.712, 0.560)
                    ])

                    // Abdominals — 3 rows × 2 cols of sharp rectangles.
                    // Left col x: 0.312–0.466  |  Right col x: 0.534–0.688
                    // Row y starts: 0.376, 0.438, 0.500  (height 0.054, gap 0.008)
                    let a1L = poly([(0.312, 0.376), (0.466, 0.376), (0.466, 0.430), (0.312, 0.430)])
                    let a1R = poly([(0.534, 0.376), (0.688, 0.376), (0.688, 0.430), (0.534, 0.430)])
                    let a2L = poly([(0.312, 0.438), (0.466, 0.438), (0.466, 0.492), (0.312, 0.492)])
                    let a2R = poly([(0.534, 0.438), (0.688, 0.438), (0.688, 0.492), (0.534, 0.492)])
                    let a3L = poly([(0.312, 0.500), (0.466, 0.500), (0.466, 0.554), (0.312, 0.554)])
                    let a3R = poly([(0.534, 0.500), (0.688, 0.500), (0.688, 0.554), (0.534, 0.554)])

                    // V-taper — trapezoid connecting torso to legs.
                    // Full torso width at top, narrows to leg-gap width at bottom.
                    let vTaper = poly([
                        (0.216, 0.562), (0.784, 0.562),
                        (0.612, 0.642), (0.388, 0.642)
                    ])

                    // Legs — 4 sharp rectangles (upper + lower per side).
                    let lUL = poly([(0.216, 0.650), (0.490, 0.650), (0.490, 0.818), (0.216, 0.818)])
                    let rUL = poly([(0.510, 0.650), (0.784, 0.650), (0.784, 0.818), (0.510, 0.818)])
                    let lLL = poly([(0.232, 0.826), (0.474, 0.826), (0.474, 0.990), (0.232, 0.990)])
                    let rLL = poly([(0.526, 0.826), (0.768, 0.826), (0.768, 0.990), (0.526, 0.990)])

                    // Draw all shapes muted.
                    // Order: torso → deltoids → arms → head (arms render on top of deltoids).
                    for p in [collar,
                               lPec, rPec, lObl, rObl,
                               a1L, a1R, a2L, a2R, a3L, a3R,
                               vTaper, lUL, rUL, lLL, rLL,
                               lDelt, rDelt,
                               lUA, rUA, lFA, rFA] {
                        ctx.fill(p, with: muted)
                    }
                    ctx.fill(head, with: muted)

                    // Apply highlights
                    switch muscleGroup {
                    case .chest:
                        draw(lPec, active: true); draw(rPec, active: true)
                    case .core:
                        draw(lObl, active: true); draw(rObl, active: true)
                        draw(a1L, active: true); draw(a1R, active: true)
                        draw(a2L, active: true); draw(a2R, active: true)
                        draw(a3L, active: true); draw(a3R, active: true)
                    case .arms:
                        draw(lUA, active: true); draw(rUA, active: true)
                        draw(lFA, active: true); draw(rFA, active: true)
                    case .legs:
                        draw(lUL, active: true); draw(rUL, active: true)
                        draw(lLL, active: true); draw(rLL, active: true)
                    case .shoulders:
                        draw(lDelt, active: true); draw(rDelt, active: true)
                    case .back:
                        break  // back muscles not visible from front
                    }

                // ── BACK VIEW ─────────────────────────────────────────────
                case .back:

                    // Lats — wide trapezoids that spread outward at shoulder level
                    // (outer edge reaches toward the arm zone) and taper inward at the waist.
                    // This produces the characteristic V-taper wing shape.
                    let lLat = poly([
                        (0.100, 0.188), (0.490, 0.188),  // top: outer–inner (wide at shoulder)
                        (0.378, 0.528), (0.208, 0.528)   // bottom: inner–outer (narrow at waist)
                    ])
                    let rLat = poly([
                        (0.510, 0.188), (0.900, 0.188),
                        (0.792, 0.528), (0.622, 0.528)
                    ])

                    // Rear V-taper (lower back / lumbar).
                    // Fills the gap between lat bottoms, tapering further downward.
                    let rearV = poly([
                        (0.386, 0.536), (0.614, 0.536),
                        (0.572, 0.616), (0.428, 0.616)
                    ])

                    // Glutes — 2 sharp rectangles
                    let lGlute = poly([(0.216, 0.624), (0.490, 0.624), (0.490, 0.730), (0.216, 0.730)])
                    let rGlute = poly([(0.510, 0.624), (0.784, 0.624), (0.784, 0.730), (0.510, 0.730)])

                    // Legs — 4 sharp rectangles (upper + lower per side)
                    let lUL = poly([(0.216, 0.738), (0.490, 0.738), (0.490, 0.858), (0.216, 0.858)])
                    let rUL = poly([(0.510, 0.738), (0.784, 0.738), (0.784, 0.858), (0.510, 0.858)])
                    let lLL = poly([(0.232, 0.866), (0.474, 0.866), (0.474, 0.990), (0.232, 0.990)])
                    let rLL = poly([(0.526, 0.866), (0.768, 0.866), (0.768, 0.990), (0.526, 0.990)])

                    // Draw all shapes muted.
                    // Order: lats → glutes/legs → deltoids → arms → head
                    // (deltoids cover the lat shoulder overlap; arms render on top of deltoids).
                    for p in [collar,
                               lLat, rLat, rearV,
                               lGlute, rGlute,
                               lUL, rUL, lLL, rLL,
                               lDelt, rDelt,
                               lUA, rUA, lFA, rFA] {
                        ctx.fill(p, with: muted)
                    }
                    ctx.fill(head, with: muted)

                    // Apply highlights
                    switch muscleGroup {
                    case .back:
                        draw(lLat, active: true); draw(rLat, active: true)
                        draw(rearV, active: true)
                    case .arms:
                        draw(lUA, active: true); draw(rUA, active: true)
                        draw(lFA, active: true); draw(rFA, active: true)
                    case .legs:
                        draw(lUL, active: true); draw(rUL, active: true)
                        draw(lLL, active: true); draw(rLL, active: true)
                    case .shoulders:
                        draw(lDelt, active: true); draw(rDelt, active: true)
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
