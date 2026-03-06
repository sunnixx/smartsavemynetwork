import SwiftUI

struct ReminderPickerView: View {
    @Binding var selectedDate: Date?
    let onConfirm: () -> Void
    @State private var pickedDate = Date().addingTimeInterval(86400)

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(
                    "Follow-up Date",
                    selection: $pickedDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(.accentColor)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Set Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onConfirm() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        selectedDate = pickedDate
                        onConfirm()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
