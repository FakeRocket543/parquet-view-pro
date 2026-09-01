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
            Text("jump.title".localized)
                .font(.title2)
                .bold()
            
            // Row number input
            VStack(alignment: .leading, spacing: 8) {
                Text("jump.row_number".localizedWithFormat(totalRows))
                    .font(.headline)
                TextField("jump.row_placeholder".localized, text: $jumpToRowNumber)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                    .onSubmit { if isValidInput { onJump() } }
            }

            // Rows to load input
            VStack(alignment: .leading, spacing: 8) {
                Text("jump.rows_to_load".localized)
                    .font(.headline)
                TextField("jump.rows_placeholder".localized, text: $jumpRowCount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                    .onSubmit { if isValidInput { onJump() } }
                Text("jump.recommended".localizedWithFormat(DataConstants.maxMaxRows))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Info
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("jump.info".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            
            // Buttons
            HStack(spacing: 12) {
                Button("alert.cancel".localized) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("jump.action".localized) {
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

        return rowNum > 0 && rowNum <= totalRows
            && rowCount > 0 && rowCount <= DataConstants.maxMaxRows
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
