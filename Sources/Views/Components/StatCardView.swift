import SwiftUI

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let subValue: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(Color(hex: "9CA3AF"))
                
                Text(value)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(Color(hex: "111827"))
                
                if let subValue = subValue {
                    Text(subValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
    }
}

struct CategoryResultCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(Color(hex: "9CA3AF"))
                    Text(value)
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(Color(hex: "111827"))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "D1D5DB"))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? iconColor.opacity(0.3) : Color.black.opacity(0.03), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ActionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let buttonText: String
    let buttonAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(iconColor.opacity(0.08))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(Color(hex: "111827"))
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "6B7280"))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
                    .lineSpacing(3)
            }
            
            Button(action: buttonAction) {
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
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
    }
}
