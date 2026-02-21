import SwiftUI

// MARK: - MuscleDiagramView
//
// Renders a simplified front-facing body silhouette (head, torso, arms, legs)
// with the targeted muscle group highlighted in the group's accent colour.
//
// All coordinates are normalised (0–1) so the diagram scales cleanly to any
// frame size. Used in exercise list rows, workout cards, and picker cells.
//
// Back muscles (lats/traps) are not fully visible from the front, so the "back"
// case highlights the outer lateral flanks of the torso — the closest anatomical
// approximation in a single-view front silhouette.

struct MuscleDiagramView: View {

    let muscleGroup: MuscleGroup
    var size: CGFloat = 38

    var body: some View {
        Canvas { ctx, canvas in
            let w = canvas.width
            let h = canvas.height

            // Convert normalised rect → canvas-space Path with rounded corners.
            func rr(
                _ nx: CGFloat, _ ny: CGFloat,
                _ nw: CGFloat, _ nh: CGFloat,
                cr: CGFloat = 0.04
            ) -> Path {
                Path(
                    roundedRect: CGRect(x: nx * w, y: ny * h, width: nw * w, height: nh * h),
                    cornerRadius: cr * min(w, h)
                )
            }

            // Convert normalised circle → canvas-space Path.
            func circ(_ nx: CGFloat, _ ny: CGFloat, _ nr: CGFloat) -> Path {
                Path(ellipseIn: CGRect(
                    x: (nx - nr) * w, y: (ny - nr) * h,
                    width: 2 * nr * w, height: 2 * nr * h
                ))
            }

            let muted = GraphicsContext.Shading.color(.secondary.opacity(0.18))
            let lit   = GraphicsContext.Shading.color(muscleGroup.color)

            // ── Baseline body parts (all in muted grey) ───────────────────────────
            //  Head             torso               left arm          right arm
            //  left leg         right leg

            let head     = circ(0.50, 0.10, 0.09)
            let torso    = rr(0.28, 0.21, 0.44, 0.34)
            let leftArm  = rr(0.10, 0.21, 0.16, 0.28)
            let rightArm = rr(0.74, 0.21, 0.16, 0.28)
            let leftLeg  = rr(0.31, 0.57, 0.16, 0.39)
            let rightLeg = rr(0.53, 0.57, 0.16, 0.39)

            for part in [head, torso, leftArm, rightArm, leftLeg, rightLeg] {
                ctx.fill(part, with: muted)
            }

            // ── Muscle group highlight ─────────────────────────────────────────────
            switch muscleGroup {

            case .chest:
                // Upper pectoral band across the torso
                ctx.fill(rr(0.28, 0.21, 0.44, 0.15), with: lit)

            case .back:
                // Lateral flanks (visible lats region) — two slim vertical bars
                // on either side of the torso, representing the lat sweep visible
                // from the front.
                ctx.fill(rr(0.28, 0.21, 0.09, 0.28), with: lit)   // left flank
                ctx.fill(rr(0.63, 0.21, 0.09, 0.28), with: lit)   // right flank

            case .legs:
                ctx.fill(leftLeg,  with: lit)
                ctx.fill(rightLeg, with: lit)

            case .shoulders:
                // Deltoid caps — top portion of each arm
                ctx.fill(rr(0.10, 0.21, 0.16, 0.11), with: lit)   // left delt
                ctx.fill(rr(0.74, 0.21, 0.16, 0.11), with: lit)   // right delt

            case .arms:
                ctx.fill(leftArm,  with: lit)
                ctx.fill(rightArm, with: lit)

            case .core:
                // Lower abdominal band
                ctx.fill(rr(0.28, 0.37, 0.44, 0.18), with: lit)
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
