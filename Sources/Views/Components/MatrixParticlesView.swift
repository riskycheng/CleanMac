import SwiftUI

struct MatrixParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speed: CGFloat
    var char: String
}

struct MatrixParticlesView: View {
    @State private var particles: [MatrixParticle] = []
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    let chars = ["0","1","A","B","C","D","E","F","α","β","γ","δ","ε","∑","∆","∞","λ","π","Ω","µ","∫","√","≈","≠","≤","≥","◊","●","○","◐","◑","▣","▤","▥","▦","▧","▨","▩","◈","◇","◆"]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Text(particle.char)
                        .font(.system(size: particle.size, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan.opacity(particle.opacity))
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                spawnParticles(in: geo.size)
            }
            .onReceive(timer) { _ in
                updateParticles(in: geo.size)
            }
        }
    }
    
    func spawnParticles(in size: CGSize) {
        let count = 50
        particles = (0..<count).map { _ in
            MatrixParticle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -100...size.height),
                size: CGFloat.random(in: 8...16),
                opacity: Double.random(in: 0.05...0.35),
                speed: CGFloat.random(in: 0.3...1.5),
                char: chars.randomElement()!
            )
        }
    }
    
    func updateParticles(in size: CGSize) {
        for i in particles.indices {
            particles[i].y += particles[i].speed
            if particles[i].y > size.height + 50 {
                particles[i].y = -50
                particles[i].x = CGFloat.random(in: 0...size.width)
                particles[i].char = chars.randomElement()!
                particles[i].opacity = Double.random(in: 0.05...0.35)
            }
        }
    }
}

struct DataStreamView: View {
    @State private var lines: [DataLine] = []
    let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()
    
    struct DataLine: Identifiable {
        let id = UUID()
        var text: String
        var x: CGFloat
        var y: CGFloat
        var opacity: Double
        var speed: CGFloat
    }
    
    let prefixes = ["SCAN", "READ", "PARSE", "HASH", "SYNC", "INDEX", "CHECK", "CLEAN"]
    let suffixes = [
        "0x7FF3A2B1C4D5", "0x00FA12BC34DE", "0xFF0011223344",
        "/usr/local/bin", "~/Library/Caches", "/var/log",
        "bundle: com.apple.Safari", "size: 2.4MB", "entries: 1,284",
        "permission: rwxr-xr-x", "uid: 501, gid: 20",
        "md5: a3f7c2d1e5b8", "status: OK", "latency: 12ms"
    ]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(lines) { line in
                    Text(line.text)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.green.opacity(line.opacity))
                        .position(x: line.x, y: line.y)
                }
            }
            .onAppear {
                spawnLines(in: geo.size)
            }
            .onReceive(timer) { _ in
                updateLines(in: geo.size)
            }
        }
    }
    
    func spawnLines(in size: CGSize) {
        let count = 20
        lines = (0..<count).map { _ in
            DataLine(
                text: generateLine(),
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -200...size.height),
                opacity: Double.random(in: 0.05...0.25),
                speed: CGFloat.random(in: 0.5...2.0)
            )
        }
    }
    
    func updateLines(in size: CGSize) {
        for i in lines.indices {
            lines[i].y += lines[i].speed
            if lines[i].y > size.height + 30 {
                lines[i].y = -30
                lines[i].x = CGFloat.random(in: 0...size.width)
                lines[i].text = generateLine()
                lines[i].opacity = Double.random(in: 0.05...0.25)
            }
        }
    }
    
    func generateLine() -> String {
        let prefix = prefixes.randomElement()!
        let suffix = suffixes.randomElement()!
        return "[\(prefix)] \(suffix)"
    }
}

struct HexDumpView: View {
    @State private var hexLines: [String] = []
    @State private var offset: Int = 0
    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(hexLines.indices, id: \.self) { i in
                Text(hexLines[i])
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(i == hexLines.count - 1 ? .cyan.opacity(0.9) : .cyan.opacity(0.15))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            hexLines = (0..<30).map { _ in generateHexLine() }
        }
        .onReceive(timer) { _ in
            hexLines.removeFirst()
            hexLines.append(generateHexLine())
        }
    }
    
    func generateHexLine() -> String {
        let addr = String(format: "%08X", offset)
        offset += 16
        let bytes = (0..<16).map { _ in String(format: "%02X", Int.random(in: 0...255)) }
        let ascii = bytes.map { byte in
            let val = Int(byte, radix: 16) ?? 0x2E
            return String(UnicodeScalar(val >= 32 && val < 127 ? val : 0x2E)!)
        }.joined()
        return "\(addr)  \(bytes.prefix(8).joined(separator: " "))  \(bytes.suffix(8).joined(separator: " "))  |\(ascii)|"
    }
}

struct ScanningRing: View {
    @State private var rotation: Double = 0
    @State private var pulse: Bool = false
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.cyan.opacity(0.1), .cyan, .cyan.opacity(0.1)],
                        center: .center,
                        angle: .degrees(0)
                    ),
                    lineWidth: 2
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(rotation))
                .shadow(color: .cyan.opacity(0.3), radius: 10)
            
            // Middle ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.green.opacity(0.1), .green, .green.opacity(0.1)],
                        center: .center,
                        angle: .degrees(120)
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(-rotation * 1.5))
            
            // Inner ring
            Circle()
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                .frame(width: 100, height: 100)
                .scaleEffect(pulse ? 1.1 : 0.95)
                .opacity(pulse ? 0.6 : 1.0)
            
            // Center glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.cyan.opacity(0.4), .clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 50
                    )
                )
                .frame(width: 60, height: 60)
                .blur(radius: 10)
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct ProgressPulseBar: View {
    let progress: Double
    let color: Color
    @State private var shimmer: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.6), color, color.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * progress), height: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(shimmer ? 0.3 : 0), .white.opacity(shimmer ? 0 : 0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * progress), height: 6)
                    )
                    .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0)
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

struct AnimatedNumberView: View {
    let value: Int64
    let formatter: (Int64) -> String
    @State private var displayValue: Int64 = 0
    
    var body: some View {
        Text(formatter(displayValue))
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .onAppear {
                animateValue()
            }
            .onChange(of: value) { _, newValue in
                animateValue()
            }
    }
    
    private func animateValue() {
        let duration: Double = 1.0
        let steps = 30
        let stepDuration = duration / Double(steps)
        let increment = Double(value) / Double(steps)
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stepDuration) {
                displayValue = min(value, Int64(Double(i) * increment))
            }
        }
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    let accent: Color
    
    init(accent: Color = .cyan, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
                    .background(
                        VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                            .opacity(0.3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [accent.opacity(0.4), accent.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }
}

struct GlowButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var hover: Bool = false
    @State private var press: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.4), color.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(color.opacity(hover ? 0.8 : 0.4), lineWidth: 1.5)
                    )
                    .shadow(color: color.opacity(hover ? 0.4 : 0.2), radius: hover ? 20 : 10)
            )
            .scaleEffect(press ? 0.95 : hover ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHover in
            withAnimation(.spring(response: 0.3)) {
                hover = isHover
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in press = true }
                .onEnded { _ in press = false }
        )
    }
}

struct CategoryPill: View {
    let icon: String
    let label: String
    let count: Int
    let size: Int64
    let isActive: Bool
    let color: Color
    @State private var appear: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isActive ? color : .white.opacity(0.4))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isActive ? color.opacity(0.15) : Color.white.opacity(0.03))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(isActive ? 0.9 : 0.5))
                Text("\(count) items · \(ByteFormatter.string(from: size))")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? color.opacity(0.06) : Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? color.opacity(0.2) : Color.white.opacity(0.04), lineWidth: 1)
                )
        )
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(Double.random(in: 0...0.3))) {
                appear = true
            }
        }
    }
}
