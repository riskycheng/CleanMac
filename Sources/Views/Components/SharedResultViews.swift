import SwiftUI

struct CleaningView: View {
    let progress: Double
    let stage: String
    let itemsProcessed: Int
    let spaceReclaimed: Int64
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 4)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color(hex: "22C55E"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "111827"))
                    Text("Cleaning...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            }
            .frame(height: 160)
            
            VStack(spacing: 10) {
                Text(stage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "6B7280"))
                
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Text("\(itemsProcessed)")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(Color(hex: "22C55E"))
                        Text("items")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "9CA3AF"))
                    }
                    
                    HStack(spacing: 4) {
                        Text(ByteFormatter.string(from: spaceReclaimed))
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(Color(hex: "22C55E"))
                        Text("reclaimed")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "9CA3AF"))
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CompleteView: View {
    let itemsRemoved: Int
    let spaceReclaimed: Int64
    let onReset: () -> Void
    @State private var appear = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(hex: "22C55E").opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "22C55E"))
            }
            .scaleEffect(appear ? 1 : 0.5)
            .opacity(appear ? 1 : 0)
            
            VStack(spacing: 8) {
                Text("Cleanup Complete")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(Color(hex: "111827"))
                Text("Your Mac has been optimized")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "9CA3AF"))
            }
            
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(itemsRemoved)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "111827"))
                    Text("Items Removed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
                
                Divider()
                    .frame(height: 40)
                    .background(Color.black.opacity(0.06))
                
                VStack(spacing: 4) {
                    Text(ByteFormatter.string(from: spaceReclaimed))
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "111827"))
                    Text("Space Reclaimed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
            )
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 15)
            
            Spacer()
            
            Button(action: onReset) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                    Text("Scan Again")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(hex: "1C1C1E"))
                )
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) {
                appear = true
            }
        }
    }
}
