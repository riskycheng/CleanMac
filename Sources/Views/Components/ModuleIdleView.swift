import SwiftUI

struct ModuleIdleView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let buttonText: String
    let action: () -> Void
    @State private var pulse = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Gradient icon
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [iconColor.opacity(0.15), iconColor.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: iconColor.opacity(0.15), radius: 20, x: 0, y: 8)
                    
                    Image(systemName: icon)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [iconColor, iconColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(pulse ? 1.02 : 0.98)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: pulse)
                
                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 36, weight: .black))
                        .foregroundColor(Color(hex: "111827"))
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "6B7280"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 420)
                }
                
                Button(action: action) {
                    Text(buttonText)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(hex: "1C1C1E"))
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { pulse = true }
    }
}
