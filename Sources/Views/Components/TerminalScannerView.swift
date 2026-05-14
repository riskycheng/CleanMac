import SwiftUI

struct MatrixRainColumn: Identifiable {
    let id = UUID()
    var x: CGFloat
    var chars: [MatrixChar]
    var speed: CGFloat
    var length: Int
}

struct MatrixChar: Identifiable {
    let id = UUID()
    var char: String
    var brightness: Double
}

struct TerminalScannerView: View {
    let progress: Double
    let stage: String
    let logLines: [String]
    
    @State private var columns: [MatrixRainColumn] = []
    @State private var typedStage: String = ""
    @State private var cursorVisible: Bool = true
    
    let matrixChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()_+-=[]{}|;:,.<>?/~`"
    let timer = Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()
    let cursorTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Matrix rain background
                ForEach(columns) { col in
                    VStack(spacing: 0) {
                        ForEach(col.chars) { ch in
                            Text(ch.char)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.green.opacity(ch.brightness))
                                .frame(width: 12, height: 14)
                        }
                    }
                    .position(x: col.x, y: geo.size.height / 2)
                }
                
                // Dark overlay for readability
                LinearGradient(
                    colors: [.black.opacity(0.7), .black.opacity(0.5), .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
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
                        Text("cleanmac — scan — 80x24")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.4))
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // Terminal content
                    HStack(spacing: 0) {
                        // Line numbers
                        VStack(alignment: .trailing, spacing: 2) {
                            ForEach(0..<min(logLines.count, 24), id: \.self) { i in
                                Text(String(format: "%3d", i + 1))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.15))
                                    .frame(height: 16)
                            }
                        }
                        .frame(width: 36)
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
                                        .foregroundColor(.green.opacity(0.6))
                                    Text(typedStage)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(.cyan)
                                    Rectangle()
                                        .fill(cursorVisible ? Color.cyan : Color.clear)
                                        .frame(width: 8, height: 14)
                                }
                                .frame(height: 16)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // Progress bar (terminal style)
                    HStack(spacing: 8) {
                        Text("[")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        
                        GeometryReader { barGeo in
                            let filled = Int((barGeo.size.width / 8) * progress)
                            let total = Int(barGeo.size.width / 8)
                            HStack(spacing: 0) {
                                Text(String(repeating: "=", count: max(0, filled)))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                                Text(String(repeating: "-", count: max(0, total - filled)))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.15))
                            }
                        }
                        .frame(height: 14)
                        
                        Text("]")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                            .frame(width: 40)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.4))
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.15), lineWidth: 1)
                        )
                )
                .padding(20)
            }
            .onAppear {
                spawnColumns(in: geo.size)
                animateTyping()
            }
            .onReceive(timer) { _ in
                updateColumns(in: geo.size)
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
    
    func spawnColumns(in size: CGSize) {
        let count = Int(size.width / 14)
        columns = (0..<count).map { _ in
            let length = Int.random(in: 5...20)
            return MatrixRainColumn(
                x: CGFloat.random(in: 0...size.width),
                chars: (0..<length).map { _ in
                    MatrixChar(
                        char: String(matrixChars.randomElement()!),
                        brightness: Double.random(in: 0.05...0.3)
                    )
                },
                speed: CGFloat.random(in: 1...3),
                length: length
            )
        }
    }
    
    func updateColumns(in size: CGSize) {
        for i in columns.indices {
            // Randomly change chars
            for j in columns[i].chars.indices {
                if Double.random(in: 0...1) < 0.1 {
                    columns[i].chars[j].char = String(matrixChars.randomElement()!)
                }
                // Fade brightness
                columns[i].chars[j].brightness = Double.random(in: 0.05...0.25)
            }
            // Occasionally respawn column
            if Double.random(in: 0...1) < 0.02 {
                let length = Int.random(in: 5...20)
                columns[i].x = CGFloat.random(in: 0...size.width)
                columns[i].chars = (0..<length).map { _ in
                    MatrixChar(
                        char: String(matrixChars.randomElement()!),
                        brightness: Double.random(in: 0.05...0.3)
                    )
                }
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
                        .foregroundColor(.green.opacity(0.5))
                    Text(String(parts[1]))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text(text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

struct TerminalIdleView: View {
    let onStart: () -> Void
    @State private var lines: [String] = []
    @State private var showPrompt: Bool = false
    
    let bootSequence = [
        "[BOOT] CleanMac Intelligent Cleanup Engine v2.0",
        "[BOOT] Loading system scan modules...",
        "[BOOT] Junk detector: READY",
        "[BOOT] App analyzer: READY",
        "[BOOT] Leftover finder: READY",
        "[BOOT] Cache scanner: READY",
        "[BOOT] Log parser: READY",
        "[INIT] Memory allocated: 24MB",
        "[INIT] Thread pool: 8 workers",
        "[INIT] Ready to scan system",
        "",
        "Type 'scan' to begin intelligent cleanup...",
    ]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Subtle matrix background
                DataStreamView()
                    .opacity(0.08)
                
                VStack(spacing: 0) {
                    // Terminal header
                    HStack {
                        HStack(spacing: 6) {
                            Circle().fill(Color.red.opacity(0.8)).frame(width: 10, height: 10)
                            Circle().fill(Color.yellow.opacity(0.8)).frame(width: 10, height: 10)
                            Circle().fill(Color.green.opacity(0.8)).frame(width: 10, height: 10)
                        }
                        Spacer()
                        Text("cleanmac — bash — 80x24")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.4))
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // Boot sequence
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(lines, id: \.self) { line in
                                TerminalLogLine(text: line)
                            }
                            
                            if showPrompt {
                                HStack(spacing: 6) {
                                    Text("jiancheng@macbook")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.green.opacity(0.7))
                                    Text("~")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.cyan.opacity(0.7))
                                    Text("$")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    Button(action: onStart) {
                                        Text("scan")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(.cyan)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.cyan.opacity(0.1))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 4)
                                                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 4)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                    }
                    
                    Spacer()
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.15), lineWidth: 1)
                        )
                )
                .padding(20)
            }
            .onAppear {
                typeBootSequence()
            }
        }
    }
    
    func typeBootSequence() {
        lines.removeAll()
        for (index, line) in bootSequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                lines.append(line)
                if index == bootSequence.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showPrompt = true
                    }
                }
            }
        }
    }
}
