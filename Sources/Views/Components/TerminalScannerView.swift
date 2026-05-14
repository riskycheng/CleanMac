import SwiftUI

struct TerminalScannerView: View {
    let progress: Double
    let stage: String
    let logLines: [String]
    
    @State private var typedStage: String = ""
    @State private var cursorVisible: Bool = true
    
    let cursorTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Subtle ambient glow
                RadialGradient(
                    colors: [.green.opacity(0.03), .clear],
                    center: .center,
                    startRadius: 50,
                    endRadius: 400
                )
                
                // Main content
                VStack(spacing: 0) {
                    // Header bar
                    HStack {
                        HStack(spacing: 6) {
                            Circle().fill(Color.red.opacity(0.8)).frame(width: 10, height: 10)
                            Circle().fill(Color.yellow.opacity(0.8)).frame(width: 10, height: 10)
                            Circle().fill(Color.green.opacity(0.8)).frame(width: 10, height: 10)
                        }
                        Spacer()
                        Text("cleanmac — scan")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                        Spacer()
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.3))
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    // Terminal content
                    HStack(spacing: 0) {
                        // Line numbers
                        VStack(alignment: .trailing, spacing: 2) {
                            ForEach(0..<min(logLines.count, 24), id: \.self) { i in
                                Text(String(format: "%3d", i + 1))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.12))
                                    .frame(height: 16)
                            }
                        }
                        .frame(width: 32)
                        .padding(.leading, 8)
                        .padding(.vertical, 8)
                        
                        // Log content
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(logLines.suffix(24), id: \.self) { line in
                                    TerminalLogLine(text: line)
                                        .frame(height: 16)
                                }
                                
                                // Current typing line
                                HStack(spacing: 2) {
                                    Text("$")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.green.opacity(0.5))
                                    Text(typedStage)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(.green.opacity(0.8))
                                    Rectangle()
                                        .fill(cursorVisible ? Color.green.opacity(0.7) : Color.clear)
                                        .frame(width: 7, height: 13)
                                }
                                .frame(height: 16)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    // Progress bar (terminal style)
                    HStack(spacing: 8) {
                        Text("[")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                        
                        GeometryReader { barGeo in
                            let filled = Int((barGeo.size.width / 8) * progress)
                            let total = Int(barGeo.size.width / 8)
                            HStack(spacing: 0) {
                                Text(String(repeating: "=", count: max(0, filled)))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.green)
                                Text(String(repeating: "-", count: max(0, total - filled)))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.1))
                            }
                        }
                        .frame(height: 14)
                        
                        Text("]")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                            .frame(width: 40)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.3))
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
                .padding(24)
            }
            .onAppear {
                animateTyping()
            }
            .onReceive(cursorTimer) { _ in
                cursorVisible.toggle()
            }
            .onChange(of: stage) { _, _ in
                typedStage = ""
                animateTyping()
            }
        }
    }
    
    func animateTyping() {
        let fullText = stage
        typedStage = ""
        for (index, char) in fullText.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.02) {
                typedStage.append(char)
            }
        }
    }
}

struct TerminalLogLine: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 0) {
            if text.hasPrefix("[") {
                let parts = text.split(separator: "]", maxSplits: 1)
                if parts.count == 2 {
                    Text(String(parts[0]) + "]")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green.opacity(0.4))
                    Text(String(parts[1]))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text(text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
            } else if text.hasPrefix(">") {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
            } else {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}
