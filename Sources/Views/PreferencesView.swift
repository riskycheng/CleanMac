import SwiftUI

struct PreferencesView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "E5E7EB").opacity(0.5))
                    .frame(width: 80, height: 80)
                Image(systemName: "gearshape")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color(hex: "6B7280"))
            }
            
            VStack(spacing: 8) {
                Text("Preferences")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(Color(hex: "111827"))
                Text("Settings and configuration options will be available here in a future update.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "9CA3AF"))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
