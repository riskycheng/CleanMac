import SwiftUI

struct ModernProgressView: View {
    let progress: Double
    let stage: String
    let subStage: String
    let accentColor: Color
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                // Progress bar
                VStack(spacing: 12) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: "E5E7EB"))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(accentColor)
                                .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 6)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(width: 280, height: 6)
                    
                    Text(subStage.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "9CA3AF"))
                    
                    Text(stage)
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(Color(hex: "111827"))
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TerminalScanView: View {
    let progress: Double
    let stage: String
    let logs: [String]
    let accentColor: Color
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Terminal window
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("_ KERNEL PROBE ACTIVE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: "1a1a1a"))
                
                Divider().background(Color.white.opacity(0.06))
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(logs.suffix(8), id: \.self) { log in
                            Text(log)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.green.opacity(0.8))
                        }
                    }
                    .padding(16)
                }
                .frame(height: 220)
                .background(Color(hex: "111111"))
            }
            .background(Color(hex: "111111"))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.15), radius: 24, x: 0, y: 12)
            .frame(width: 640)
            
            // Progress
            VStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "E5E7EB"))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accentColor)
                            .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 6)
                    }
                }
                .frame(width: 400, height: 6)
                
                Text("DEEP SCANNING SYSTEM...")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "9CA3AF"))
                
                Text("\(Int(progress * 100))% Complete")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(Color(hex: "111827"))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
