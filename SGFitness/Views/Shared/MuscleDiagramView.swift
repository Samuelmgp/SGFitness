import SwiftUI

// MARK: - DiagramSide
enum DiagramSide {
    case front
    case back
}

// MARK: - MuscleDiagramView
//
// Renders a front or back humanoid figure by stacking SVG asset layers,
// each extracted from the matching composite SVG (HumanoidFrontView.svg /
// HumanoidBackView.svg).
//
// Every layer asset uses the same 210 × 461 viewBox, so they compose
// perfectly at equal size with no offset math — just a plain ZStack.
//
// Template rendering lets `.foregroundStyle()` drive each layer's fill:
//   active group  → muscleGroup.color
//   inactive      → secondary grey (0.28 opacity)
//
// `size` = icon HEIGHT.  Width = size × (210 / 461) ≈ size × 0.455.

struct MuscleDiagramView: View {

    let muscleGroup: MuscleGroup
    let side: DiagramSide
    var size: CGFloat = 38

    // ── Layout ─────────────────────────────────────────────────────────────

    private let canvasW: CGFloat = 210
    private let canvasH: CGFloat = 461

    private var scale: CGFloat  { size / canvasH }
    private var iconW: CGFloat  { canvasW * scale }

    private var muted: Color    { Color.secondary.opacity(0.28) }
    private var lit:   Color    { muscleGroup.color }

    // ── View ───────────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: iconW * 0.18)
                .fill(muscleGroup.color.opacity(0.14))

            switch side {
            case .front: frontBody
            case .back:  backBody
            }
        }
        .frame(width: iconW, height: size)
    }

    // ── Front layers (bottom → top) ────────────────────────────────────────

    private var frontBody: some View {
        ZStack {
            bodyLayer("BodyFront_Legs",      active: muscleGroup == .legs)
            bodyLayer("BodyFront_Abs",       active: muscleGroup == .core)
            bodyLayer("BodyFront_Chest",     active: muscleGroup == .chest)
            bodyLayer("BodyFront_Arms",      active: muscleGroup == .arms)
            bodyLayer("BodyFront_Shoulders", active: muscleGroup == .shoulders)
            bodyLayer("BodyFront_Head",      active: false)
        }
    }

    // ── Back layers (bottom → top) ─────────────────────────────────────────

    private var backBody: some View {
        ZStack {
            bodyLayer("BodyBack_Legs",      active: muscleGroup == .legs)
            bodyLayer("BodyBack_Back",      active: muscleGroup == .back)
            bodyLayer("BodyBack_Arms",      active: muscleGroup == .arms)
            bodyLayer("BodyBack_Shoulders", active: muscleGroup == .shoulders)
            bodyLayer("BodyBack_Head",      active: false)
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    /// Single SVG layer — template image fills the full icon frame.
    /// Because every asset shares the 210 × 461 viewBox, no offset is needed.
    private func bodyLayer(_ name: String, active: Bool) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .foregroundStyle(active ? lit : muted)
            .frame(width: iconW, height: size)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 32) {

            // Badge size — all muscle groups
            HStack(spacing: 14) {
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    VStack(spacing: 6) {
                        MuscleDiagramView(
                            muscleGroup: group,
                            side: group == .back ? .back : .front,
                            size: 90)
                        Text(group.rawValue)
                            .font(.caption2)
                    }
                }
            }

            Divider()

            // Large detail size — front and back
            HStack(spacing: 24) {
                ForEach([MuscleGroup.chest, .back, .legs, .core], id: \.self) { group in
                    MuscleDiagramView(
                        muscleGroup: group,
                        side: group == .back ? .back : .front,
                        size: 220)
                }
            }
        }
        .padding()
    }
}
