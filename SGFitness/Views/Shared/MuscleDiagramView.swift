import SwiftUI

// MARK: - MuscleDiagramView
//
// Renders two miniature humanoid silhouettes side-by-side — front view (left)
// and back view (right) — drawn from polygon paths, resembling the anatomical
// diagrams found on gym machines. The targeted muscle group is highlighted in
// the group's accent colour on the relevant panel(s); all other body parts are
// rendered in a muted secondary tone.
//
// A tinted rounded-square background (group accent at low opacity) provides the
// same coloured-badge appearance as the previous icon badges.
//
// All panel-local coordinates are normalised (0–1 within each half-panel).

struct MuscleDiagramView: View {

    let muscleGroup: MuscleGroup
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            // ── Tinted background ──────────────────────────────────────
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(muscleGroup.color.opacity(0.14))

            // ── Body diagram ───────────────────────────────────────────
            Canvas { ctx, canvas in
                let w = canvas.width
                let h = canvas.height

                // Two side-by-side panels, each 44 % of canvas width.
                // Front figure on the left, back figure on the right.
                let fL: CGFloat = 0.04   // front panel — normalised left edge
                let bL: CGFloat = 0.52   // back  panel — normalised left edge
                let pW: CGFloat = 0.44   // panel width (same for both)

                // Convert panel-local (lx, ly) → canvas CGPoint
                func fp(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                    CGPoint(x: (fL + x * pW) * w, y: y * h)
                }
                func bp(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                    CGPoint(x: (bL + x * pW) * w, y: y * h)
                }

                // Closed polygon helper
                func fPoly(_ pts: [(CGFloat, CGFloat)]) -> Path {
                    var p = Path()
                    guard let f = pts.first else { return p }
                    p.move(to: fp(f.0, f.1))
                    for pt in pts.dropFirst() { p.addLine(to: fp(pt.0, pt.1)) }
                    p.closeSubpath()
                    return p
                }
                func bPoly(_ pts: [(CGFloat, CGFloat)]) -> Path {
                    var p = Path()
                    guard let f = pts.first else { return p }
                    p.move(to: bp(f.0, f.1))
                    for pt in pts.dropFirst() { p.addLine(to: bp(pt.0, pt.1)) }
                    p.closeSubpath()
                    return p
                }

                // Ellipse (head) via panel-local normalised centre + radii
                func fHead() -> Path {
                    Path(ellipseIn: CGRect(
                        x: (fL + (0.50 - 0.155) * pW) * w, y: 0.015 * h,
                        width: 0.31 * pW * w, height: 0.145 * h))
                }
                func bHead() -> Path {
                    Path(ellipseIn: CGRect(
                        x: (bL + (0.50 - 0.155) * pW) * w, y: 0.015 * h,
                        width: 0.31 * pW * w, height: 0.145 * h))
                }

                let muted = GraphicsContext.Shading.color(Color.secondary.opacity(0.28))
                let lit   = GraphicsContext.Shading.color(muscleGroup.color)

                // ── Body-part polygon coordinates (panel-local 0-1) ────
                // Neck
                let neck: [(CGFloat, CGFloat)] = [
                    (0.39, 0.16), (0.61, 0.16), (0.57, 0.225), (0.43, 0.225)
                ]
                // Torso — wide at shoulders, tapers toward hips
                let torso: [(CGFloat, CGFloat)] = [
                    (0.10, 0.225), (0.90, 0.225), (0.82, 0.565), (0.18, 0.565)
                ]
                // Left upper arm
                let lUA: [(CGFloat, CGFloat)] = [
                    (0.10, 0.225), (0.00, 0.26), (0.00, 0.445), (0.10, 0.41)
                ]
                // Right upper arm (mirror)
                let rUA: [(CGFloat, CGFloat)] = [
                    (0.90, 0.225), (1.00, 0.26), (1.00, 0.445), (0.90, 0.41)
                ]
                // Left forearm
                let lFA: [(CGFloat, CGFloat)] = [
                    (0.10, 0.41), (0.00, 0.445), (0.02, 0.605), (0.12, 0.57)
                ]
                // Right forearm
                let rFA: [(CGFloat, CGFloat)] = [
                    (0.90, 0.41), (1.00, 0.445), (0.98, 0.605), (0.88, 0.57)
                ]
                // Left upper leg
                let lUL: [(CGFloat, CGFloat)] = [
                    (0.18, 0.565), (0.51, 0.565), (0.50, 0.785), (0.17, 0.785)
                ]
                // Right upper leg
                let rUL: [(CGFloat, CGFloat)] = [
                    (0.49, 0.565), (0.82, 0.565), (0.83, 0.785), (0.50, 0.785)
                ]
                // Left lower leg
                let lLL: [(CGFloat, CGFloat)] = [
                    (0.17, 0.785), (0.50, 0.785), (0.49, 0.985), (0.16, 0.985)
                ]
                // Right lower leg
                let rLL: [(CGFloat, CGFloat)] = [
                    (0.50, 0.785), (0.83, 0.785), (0.84, 0.985), (0.51, 0.985)
                ]

                // Fill all parts in muted colour for both panels
                let parts = [neck, torso, lUA, rUA, lFA, rFA, lUL, rUL, lLL, rLL]
                for pts in parts {
                    ctx.fill(fPoly(pts), with: muted)
                    ctx.fill(bPoly(pts), with: muted)
                }
                ctx.fill(fHead(), with: muted)
                ctx.fill(bHead(), with: muted)

                // ── Muscle-group highlights ────────────────────────────

                switch muscleGroup {

                case .chest:
                    // Upper pectoral band on front panel only
                    ctx.fill(fPoly([
                        (0.10, 0.225), (0.90, 0.225), (0.83, 0.395), (0.17, 0.395)
                    ]), with: lit)

                case .back:
                    // Trapezius band + lateral lat sweep on back panel
                    ctx.fill(bPoly([
                        (0.20, 0.225), (0.80, 0.225), (0.74, 0.33), (0.26, 0.33)
                    ]), with: lit)  // trap
                    ctx.fill(bPoly([
                        (0.10, 0.225), (0.21, 0.225), (0.21, 0.565), (0.18, 0.565)
                    ]), with: lit)  // left lat
                    ctx.fill(bPoly([
                        (0.79, 0.225), (0.90, 0.225), (0.82, 0.565), (0.79, 0.565)
                    ]), with: lit)  // right lat

                case .shoulders:
                    // Deltoid caps — top portion of each upper arm, both panels
                    let lDelt: [(CGFloat, CGFloat)] = [
                        (0.10, 0.225), (0.00, 0.26), (0.01, 0.335), (0.11, 0.30)
                    ]
                    let rDelt: [(CGFloat, CGFloat)] = [
                        (0.90, 0.225), (1.00, 0.26), (0.99, 0.335), (0.89, 0.30)
                    ]
                    ctx.fill(fPoly(lDelt), with: lit)
                    ctx.fill(fPoly(rDelt), with: lit)
                    ctx.fill(bPoly(lDelt), with: lit)
                    ctx.fill(bPoly(rDelt), with: lit)

                case .arms:
                    // Full upper + lower arms on both panels
                    // (biceps visible front, triceps visible back)
                    for pts in [lUA, rUA, lFA, rFA] {
                        ctx.fill(fPoly(pts), with: lit)
                        ctx.fill(bPoly(pts), with: lit)
                    }

                case .legs:
                    // Full legs on both panels (quads front, hamstrings back)
                    for pts in [lUL, rUL, lLL, rLL] {
                        ctx.fill(fPoly(pts), with: lit)
                        ctx.fill(bPoly(pts), with: lit)
                    }

                case .core:
                    // Abdominals on front, lumbar on back
                    ctx.fill(fPoly([
                        (0.17, 0.395), (0.83, 0.395), (0.82, 0.565), (0.18, 0.565)
                    ]), with: lit)
                    ctx.fill(bPoly([
                        (0.24, 0.435), (0.76, 0.435), (0.82, 0.565), (0.18, 0.565)
                    ]), with: lit)
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
