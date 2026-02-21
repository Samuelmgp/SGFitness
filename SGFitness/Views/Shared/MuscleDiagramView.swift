import SwiftUI

// MARK: - MuscleDiagramView
//
// Renders a single humanoid silhouette in the style of gym machine anatomy diagrams.
//
// View selection:
//   Front view — Chest, Core, Arms, Legs, Shoulders
//   Back  view — Back only
//
// Shapes are drawn as sharp polygons to produce a "shredded" anatomical look:
//   • Deltoids   — angular triangular caps at the shoulders
//   • Pectorals  — wedge/fan shapes from shoulder to sternum (front)
//   • Abdominals — 3×2 grid of rectangles (classic 6-pack, front)
//   • Trapezius  — large diamond from neck to mid-back (back)
//   • Lats       — wide triangular sweeps on each side (back)
//   • Erectors   — two narrow vertical columns (back)
//   • Limbs      — angular parallelograms
//
// The targeted muscle group is highlighted in its accent colour; all other body
// parts are rendered muted. A tinted rounded-square background (accent at low
// opacity) matches the coloured-badge appearance used elsewhere in the app.
//
// All coordinates are normalised (0–1) and scaled to the canvas at render time.

struct MuscleDiagramView: View {

    let muscleGroup: MuscleGroup
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            // ── Tinted background ──────────────────────────────────────────
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(muscleGroup.color.opacity(0.14))

            // ── Body diagram ───────────────────────────────────────────────
            Canvas { ctx, canvas in
                let w = canvas.width
                let h = canvas.height

                // Scale normalised (0–1) coordinate to canvas point
                func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                    CGPoint(x: x * w, y: y * h)
                }

                // Build a closed filled polygon from normalised coords
                func poly(_ coords: [(CGFloat, CGFloat)]) -> Path {
                    var path = Path()
                    guard let first = coords.first else { return path }
                    path.move(to: pt(first.0, first.1))
                    for c in coords.dropFirst() { path.addLine(to: pt(c.0, c.1)) }
                    path.closeSubpath()
                    return path
                }

                let muted = GraphicsContext.Shading.color(Color.secondary.opacity(0.30))
                let lit   = GraphicsContext.Shading.color(muscleGroup.color)

                // ── Shared shapes (present in both views) ─────────────────

                // Head
                let headRect = CGRect(
                    x: 0.365 * w, y: 0.010 * h,
                    width: 0.270 * w, height: 0.122 * h)

                // Neck
                let neck: [(CGFloat, CGFloat)] = [
                    (0.42, 0.132), (0.58, 0.132), (0.55, 0.182), (0.45, 0.182)
                ]

                // Deltoid caps — angular triangular shapes at shoulders
                let lDelt: [(CGFloat, CGFloat)] = [
                    (0.14, 0.182), (0.01, 0.244), (0.07, 0.368), (0.21, 0.312)
                ]
                let rDelt: [(CGFloat, CGFloat)] = [
                    (0.86, 0.182), (0.99, 0.244), (0.93, 0.368), (0.79, 0.312)
                ]

                // Upper arms (biceps / triceps)
                let lUA: [(CGFloat, CGFloat)] = [
                    (0.21, 0.312), (0.07, 0.368), (0.09, 0.510), (0.23, 0.456)
                ]
                let rUA: [(CGFloat, CGFloat)] = [
                    (0.79, 0.312), (0.93, 0.368), (0.91, 0.510), (0.77, 0.456)
                ]

                // Forearms — taper toward wrist
                let lFA: [(CGFloat, CGFloat)] = [
                    (0.23, 0.456), (0.09, 0.510), (0.12, 0.638), (0.26, 0.598)
                ]
                let rFA: [(CGFloat, CGFloat)] = [
                    (0.77, 0.456), (0.91, 0.510), (0.88, 0.638), (0.74, 0.598)
                ]

                switch muscleGroup {

                // ── BACK VIEW ─────────────────────────────────────────────
                case .back:
                    // Trapezius — large diamond from neck down to mid-back
                    let trap: [(CGFloat, CGFloat)] = [
                        (0.42, 0.132), (0.58, 0.132),
                        (0.83, 0.218), (0.75, 0.448),
                        (0.50, 0.488), (0.25, 0.448), (0.17, 0.218)
                    ]

                    // Latissimus dorsi — wide triangular sweeps flanking the trap
                    let lLat: [(CGFloat, CGFloat)] = [
                        (0.17, 0.218), (0.25, 0.218), (0.26, 0.558), (0.13, 0.558)
                    ]
                    let rLat: [(CGFloat, CGFloat)] = [
                        (0.83, 0.218), (0.75, 0.218), (0.74, 0.558), (0.87, 0.558)
                    ]

                    // Erector spinae — two vertical columns either side of spine
                    let lES: [(CGFloat, CGFloat)] = [
                        (0.36, 0.488), (0.49, 0.488), (0.49, 0.612), (0.36, 0.612)
                    ]
                    let rES: [(CGFloat, CGFloat)] = [
                        (0.51, 0.488), (0.64, 0.488), (0.64, 0.612), (0.51, 0.612)
                    ]

                    // Glutes
                    let lGlute: [(CGFloat, CGFloat)] = [
                        (0.23, 0.612), (0.50, 0.612), (0.49, 0.702), (0.21, 0.702)
                    ]
                    let rGlute: [(CGFloat, CGFloat)] = [
                        (0.50, 0.612), (0.77, 0.612), (0.79, 0.702), (0.51, 0.702)
                    ]

                    // Hamstrings
                    let lHam: [(CGFloat, CGFloat)] = [
                        (0.21, 0.702), (0.49, 0.702), (0.47, 0.826), (0.19, 0.826)
                    ]
                    let rHam: [(CGFloat, CGFloat)] = [
                        (0.51, 0.702), (0.79, 0.702), (0.81, 0.826), (0.53, 0.826)
                    ]

                    // Calves
                    let lCalf: [(CGFloat, CGFloat)] = [
                        (0.19, 0.826), (0.47, 0.826), (0.44, 0.986), (0.17, 0.986)
                    ]
                    let rCalf: [(CGFloat, CGFloat)] = [
                        (0.53, 0.826), (0.81, 0.826), (0.83, 0.986), (0.57, 0.986)
                    ]

                    // Draw everything muted first
                    for shape in [neck, lDelt, rDelt, lUA, rUA, lFA, rFA,
                                  trap, lLat, rLat, lES, rES,
                                  lGlute, rGlute, lHam, rHam, lCalf, rCalf] {
                        ctx.fill(poly(shape), with: muted)
                    }
                    ctx.fill(Path(ellipseIn: headRect), with: muted)

                    // Highlight: trapezius + lats + erector spinae
                    for shape in [trap, lLat, rLat, lES, rES] {
                        ctx.fill(poly(shape), with: lit)
                    }

                // ── FRONT VIEW (all other groups) ─────────────────────────
                default:
                    // Pectorals — wedge shapes from shoulder to sternum
                    let lPec: [(CGFloat, CGFloat)] = [
                        (0.14, 0.182), (0.50, 0.192),
                        (0.47, 0.406), (0.24, 0.422), (0.14, 0.322)
                    ]
                    let rPec: [(CGFloat, CGFloat)] = [
                        (0.86, 0.182), (0.50, 0.192),
                        (0.53, 0.406), (0.76, 0.422), (0.86, 0.322)
                    ]

                    // Abdominals — 3 rows × 2 columns of rectangles (6-pack)
                    let abs1L: [(CGFloat, CGFloat)] = [
                        (0.32, 0.422), (0.47, 0.422), (0.47, 0.474), (0.32, 0.474)
                    ]
                    let abs1R: [(CGFloat, CGFloat)] = [
                        (0.53, 0.422), (0.68, 0.422), (0.68, 0.474), (0.53, 0.474)
                    ]
                    let abs2L: [(CGFloat, CGFloat)] = [
                        (0.31, 0.482), (0.46, 0.482), (0.46, 0.536), (0.31, 0.536)
                    ]
                    let abs2R: [(CGFloat, CGFloat)] = [
                        (0.54, 0.482), (0.69, 0.482), (0.69, 0.536), (0.54, 0.536)
                    ]
                    let abs3L: [(CGFloat, CGFloat)] = [
                        (0.30, 0.544), (0.45, 0.544), (0.45, 0.598), (0.30, 0.598)
                    ]
                    let abs3R: [(CGFloat, CGFloat)] = [
                        (0.55, 0.544), (0.70, 0.544), (0.70, 0.598), (0.55, 0.598)
                    ]
                    let absAll: [[(CGFloat, CGFloat)]] = [
                        abs1L, abs1R, abs2L, abs2R, abs3L, abs3R
                    ]

                    // Pelvis / hip band
                    let pelvis: [(CGFloat, CGFloat)] = [
                        (0.22, 0.598), (0.78, 0.598), (0.80, 0.658), (0.20, 0.658)
                    ]

                    // Upper legs — quads, taper toward knee
                    let lUL: [(CGFloat, CGFloat)] = [
                        (0.20, 0.658), (0.50, 0.658), (0.48, 0.824), (0.18, 0.824)
                    ]
                    let rUL: [(CGFloat, CGFloat)] = [
                        (0.50, 0.658), (0.80, 0.658), (0.82, 0.824), (0.52, 0.824)
                    ]

                    // Lower legs — shins, sharper taper
                    let lLL: [(CGFloat, CGFloat)] = [
                        (0.18, 0.824), (0.48, 0.824), (0.45, 0.986), (0.16, 0.986)
                    ]
                    let rLL: [(CGFloat, CGFloat)] = [
                        (0.52, 0.824), (0.82, 0.824), (0.84, 0.986), (0.56, 0.986)
                    ]

                    // Draw everything muted first
                    for shape in [neck, lDelt, rDelt, lUA, rUA, lFA, rFA,
                                  lPec, rPec,
                                  abs1L, abs1R, abs2L, abs2R, abs3L, abs3R,
                                  pelvis, lUL, rUL, lLL, rLL] {
                        ctx.fill(poly(shape), with: muted)
                    }
                    ctx.fill(Path(ellipseIn: headRect), with: muted)

                    // Highlights per group
                    switch muscleGroup {
                    case .chest:
                        ctx.fill(poly(lPec), with: lit)
                        ctx.fill(poly(rPec), with: lit)
                    case .core:
                        for shape in absAll { ctx.fill(poly(shape), with: lit) }
                    case .arms:
                        for shape in [lUA, rUA, lFA, rFA] {
                            ctx.fill(poly(shape), with: lit)
                        }
                    case .legs:
                        for shape in [lUL, rUL, lLL, rLL] {
                            ctx.fill(poly(shape), with: lit)
                        }
                    case .shoulders:
                        ctx.fill(poly(lDelt), with: lit)
                        ctx.fill(poly(rDelt), with: lit)
                    default:
                        break
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(MuscleGroup.allCases, id: \.self) { group in
            VStack(spacing: 4) {
                MuscleDiagramView(muscleGroup: group, size: 50)
                Text(group.rawValue)
                    .font(.caption2)
            }
        }
    }
    .padding()
}
