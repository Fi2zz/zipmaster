import SwiftUI

struct FormatPicker: View {
    @Binding var format: ArchiveFormat

    var body: some View {
        Picker("格式", selection: $format) {
            ForEach(ArchiveFormat.allCases, id: \.self) { format in
                Text(format.fileExtension).tag(format)
            }
        }
        .labelsHidden()
        .frame(width: 120)
    }
}
