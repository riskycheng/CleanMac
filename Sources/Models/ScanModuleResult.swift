import Foundation
import SwiftUI

enum ScanModuleType: String, CaseIterable, Identifiable {
    case cleanup = "Cleanup"
    case protection = "Protection"
    case performance = "Performance"
    case applications = "Applications"
    case myClutter = "My Clutter"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .cleanup: return "bubbles.and.sparkles"
        case .protection: return "hand.raised.fill"
        case .performance: return "bolt.fill"
        case .applications: return "square.grid.2x2"
        case .myClutter: return "folder.fill"
        }
    }
    
    var gradient: Gradient {
        switch self {
        case .cleanup:
            return Gradient(colors: [Color(hex: "1B5E20").opacity(0.6), Color(hex: "0D2810").opacity(0.4)])
        case .protection:
            return Gradient(colors: [Color(hex: "880E4F").opacity(0.6), Color(hex: "330018").opacity(0.4)])
        case .performance:
            return Gradient(colors: [Color(hex: "E65100").opacity(0.6), Color(hex: "3E1C00").opacity(0.4)])
        case .applications:
            return Gradient(colors: [Color(hex: "0D47A1").opacity(0.6), Color(hex: "001233").opacity(0.4)])
        case .myClutter:
            return Gradient(colors: [Color(hex: "006064").opacity(0.6), Color(hex: "001F22").opacity(0.4)])
        }
    }
    
    var accent: Color {
        switch self {
        case .cleanup: return Color(hex: "69F0AE")
        case .protection: return Color(hex: "FF4081")
        case .performance: return Color(hex: "FFAB40")
        case .applications: return Color(hex: "448AFF")
        case .myClutter: return Color(hex: "18FFFF")
        }
    }
    
    var scanningTitle: String {
        switch self {
        case .cleanup: return "Looking for junk..."
        case .protection: return "Scanning for threats..."
        case .performance: return "Checking performance..."
        case .applications: return "Analyzing applications..."
        case .myClutter: return "Analyzing your storage..."
        }
    }
    
    var processingTitle: String {
        switch self {
        case .cleanup: return "Cleaning junk..."
        case .protection: return "Removing threats..."
        case .performance: return "Optimizing performance..."
        case .applications: return "Updating applications..."
        case .myClutter: return "Removing clutter..."
        }
    }
}

struct ScanModuleResult: Identifiable {
    let id = UUID()
    let type: ScanModuleType
    var isSelected: Bool
    let hasIssues: Bool
    let primaryText: String
    let secondaryText: String
    var detailItems: [ScanDetailItem]
}

struct ScanDetailItem: Identifiable {
    let id = UUID()
    let name: String
    let size: Int64
    var status: ProcessingStatus
}

enum ProcessingStatus {
    case pending
    case processing
    case done
    
    var icon: String {
        switch self {
        case .pending: return "circle"
        case .processing: return "arrow.triangle.2.circlepath"
        case .done: return "checkmark"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .white.opacity(0.3)
        case .processing: return .white
        case .done: return .green
        }
    }
}

enum SmartCarePhase {
    case idle
    case scanning(moduleIndex: Int, currentPath: String)
    case results([ScanModuleResult])
    case processing(moduleIndex: Int, itemIndex: Int)
    case complete
}
