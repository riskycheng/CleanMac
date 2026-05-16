import SwiftUI

/// Horizontal bar chart showing file access time distribution.
/// Inspired by Lume's zombie file heatmap.
struct AccessTimeHeatmapView: View {
    let buckets: [LargeFileScanner.Bucket]
    
    var totalSize: Int64 {
        buckets.reduce(0) { $0 + $1.totalSize }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FILE ACTIVITY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(Color(hex: "9CA3AF"))
                Spacer()
                Text("\(ByteFormatter.string(from: totalSize)) total")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "D1D5DB"))
            }
            
            VStack(spacing: 6) {
                ForEach(buckets, id: \.label) { bucket in
                    BucketBar(bucket: bucket, totalSize: totalSize)
                }
            }
        }
        .padding(16)
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

private struct BucketBar: View {
    let bucket: LargeFileScanner.Bucket
    let totalSize: Int64
    
    var fraction: Double {
        guard totalSize > 0 else { return 0 }
        return Double(bucket.totalSize) / Double(totalSize)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(bucket.label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: bucket.color))
                .frame(width: 50, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "F3F4F6"))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: bucket.color))
                        .frame(width: max(4, geo.size.width * CGFloat(fraction)), height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(bucket.count)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "6B7280"))
                .frame(width: 30, alignment: .trailing)
            
            Text(ByteFormatter.string(from: bucket.totalSize))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "9CA3AF"))
                .frame(width: 50, alignment: .trailing)
        }
    }
}
