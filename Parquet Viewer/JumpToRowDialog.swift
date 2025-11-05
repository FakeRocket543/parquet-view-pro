// Jump To Row Dialog
// Dialog for jumping to specific row in large datasets
// SM-X: Navigation Feature

import SwiftUI

struct JumpToRowDialog: View {
    @Binding var jumpToRowNumber: String
    @Binding var jumpRowCount: String
    let totalRows: Int
    let onJump: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Jump to Row")
                .font(.title2)
                .bold()
            
            // Row number input
            VStack(alignment: .leading, spacing: 8) {
                Text("Row Number (1 to \(totalRows)):")
                    .font(.headline)
                TextField("Enter row number", text: $jumpToRowNumber)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
            }
            
            // Rows to load input
            VStack(alignment: .leading, spacing: 8) {
                Text("Number of Rows to Load:")
                    .font(.headline)
                TextField("Default: 1000", text: $jumpRowCount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                Text("(Recommended: 1000-10000)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Info
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Data will be loaded from the specified row onwards")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Jump") {
                    onJump()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValidInput)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 400)
    }
    
    private var isValidInput: Bool {
        guard let rowNum = Int(jumpToRowNumber),
              let rowCount = Int(jumpRowCount) else {
            return false
        }
        
        return rowNum > 0 && rowNum <= totalRows && rowCount > 0 && rowCount <= 100000
    }
}

// MARK: - Preview

#Preview {
    JumpToRowDialog(
        jumpToRowNumber: .constant("1000"),
        jumpRowCount: .constant("1000"),
        totalRows: 1000000,
        onJump: {},
        onCancel: {}
    )
}
