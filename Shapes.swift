struct HeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let width = rect.minX
        let height = rect.minY
        
        let origin = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: origin)
        p.addArc(center: origin, radius: 50, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        p.closeSubpath()
        
        return p;
    }
}

struct DeltoidShape: Shape {
    let side: Side
    let percentWidth: CGFloat = 0.33;
    let percentHeight: CGFloat = 0.15;
    
    func leftDeltoid(in rect: CGRect) -> Path {
        var p = Path()
        
        let lengthX = rect.width * percentWidth
        let lengthY = rect.height * percentHeight

        // Define anchor points for a stylized deltoid (shoulder) on the left side
        let origin = CGPoint(x: rect.midX + lengthX, y: rect.midY)
        let b = CGPoint(x: rect.midX - lengthX, y: rect.midY)
        let c = CGPoint(x: rect.midX + lengthX / 2, y: rect.midY - lengthY)
        let curveP = CGPoint(x: rect.midX - lengthX, y: rect.midY - lengthY/2)
        
        p.move(to: origin)
        p.addLine(to: b)
        p.addQuadCurve(to: c, control: curveP)
        p.closeSubpath()
        
        return p
    }
    
    func collar (in rect: CGRect) -> Path {
        var p = Path()
        let lengthX_base = rect.width * percentWidth * 1.5;
        let lengthX_top = rect.width * (percentWidth * 2)
        let height = rect.height * percentHeight
        
        // Base
        let baseL = CGPoint(x: rect.midX - lengthX_base, y: rect.midY)
        let baseR = CGPoint(x: rect.midX + lengthX_base, y: rect.midY)
        
        // Top
        let topL = CGPoint(x: rect.midX - lengthX_top, y: rect.midY - height)
        let topR = CGPoint(x: rect.midX + lengthX_top, y: rect.midY - height)
        
        p.move(to: baseL)
        p.addLine(to: baseR)
        p.addLine(to: topR)
        p.addLine(to: topL)
        p.closeSubpath()
        
        return p
    }
    
    func rightDeltoid(in rect: CGRect) -> Path {
        var p = Path()
        
        let lengthX = rect.width * percentWidth
        let lengthY = rect.height * percentHeight

        // Define anchor points for a stylized deltoid (shoulder) on the left side
        let origin = CGPoint(x: rect.midX - lengthX, y: rect.midY)
        let b = CGPoint(x: rect.midX + lengthX, y: rect.midY)
        let c = CGPoint(x: rect.midX - lengthX / 2, y: rect.midY - lengthY)
        let curveP = CGPoint(x: rect.midX + lengthX, y: rect.midY - lengthY/2)
        
        p.move(to: origin)
        p.addLine(to: b)
        p.addQuadCurve(to: c, control: curveP)
        p.closeSubpath()
        
        return p
    }
    
    func path(in rect: CGRect) -> Path {
        switch side {
        case .left:
            return leftDeltoid(in: rect)
        case .center:
            return collar(in: rect)
        case .right:
            return rightDeltoid(in: rect)
        }
    }
}

struct Custom: View {
    
    var body: some View {
        VStack(spacing: 0){
            HeadShape()
                .fill(.green.opacity(0.3))
            HStack(spacing: 0) {
                DeltoidShape(side: .left)
                    .fill(.blue.opacity(0.4))
                DeltoidShape(side: .center)
                    .fill(.red.opacity(0.3))
                DeltoidShape(side: .right)
                    .fill(.yellow.opacity(0.4))
            }
            
        }
    }
}

#Preview {
    Custom()
}
