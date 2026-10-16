import SwiftUI

/// 显示一次任务的进度、结果与取消按钮。
struct JobProgressView: View {
    @ObservedObject var job: ArchiveJob
    let onCancel: () -> Void

    var body: some View {
        switch job.state {
        case .idle:
            EmptyView()
        case .running:
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: job.progress)
                HStack {
                    Text("进行中…")
                    Spacer()
                    Button("取消", action: onCancel)
                }
            }
        case .succeeded:
            Label("完成", systemImage: "checkmark.circle").foregroundStyle(.green)
        case .cancelled:
            Label("已取消", systemImage: "xmark.circle").foregroundStyle(.secondary)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
        }
    }
}
