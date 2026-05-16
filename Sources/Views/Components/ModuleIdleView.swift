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
            
            VStack(spacing: 32) {
                // Large squircle icon — light background, purple icon, soft shadow
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 140, height: 140)
                        .shadow(color: Color.black.opacity(0.06), radius: 24, x: 0, y: 12)
                    
                    Image(systemName: icon)
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                .scaleEffect(pulse ? 1.02 : 0.98)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: pulse)
                
                VStack(spacing: 14) {
                    Text(title)
                        .font(.system(size: 42, weight: .black))
                        .foregroundColor(Color(hex: "111827"))
                    
                    Text(subtitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(hex: "6B7280"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .frame(maxWidth: 420)
                }
                
                Button(action: action) {
                    Text(buttonText)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color(hex: "1C1C1E"))
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { pulse = true }
    }
}
