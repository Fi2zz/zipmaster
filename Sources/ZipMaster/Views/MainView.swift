import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @StateObject private var model = AppModel()

    // 压缩
    @State private var sources: [URL] = []
    @State private var format: ArchiveFormat = .zip
    @State private var outputPath = ""

    // 解压
    @State private var archive: URL?
    @State private var extractPath = ""

    @State private var importingSources = false
    @State private var importingArchive = false
    @State private var importingDir = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("ZipMaster").font(.largeTitle.bold())

            compressSection
            Divider()
            extractSection

            if let job = model.job {
                JobProgressView(job: job, onCancel: { model.cancel() })
            }

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 520)
        .alert("出错了", isPresented: errorBinding) {
            Button("好", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .fileImporter(isPresented: $importingSources, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                sources = urls
                outputPath = defaultArchivePath()
            }
        }
        .fileImporter(isPresented: $importingArchive, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let first = urls.first {
                archive = first
                extractPath = defaultExtractPath(for: first)
            }
        }
        .fileImporter(isPresented: $importingDir, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let first = urls.first {
                extractPath = first.path
            }
        }
    }

    private var isRunning: Bool { model.job?.state == .running }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }

    // MARK: - 压缩

    private var compressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("压缩").font(.headline)
            HStack {
                Button("选择文件或文件夹…") { importingSources = true }
                Text(sources.isEmpty ? "未选择" : "已选 \(sources.count) 项")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("格式")
                FormatPicker(format: $format)
            }
            HStack {
                Text("输出")
                TextField("输出路径", text: $outputPath)
                    .textFieldStyle(.roundedBorder)
            }
            Button("开始压缩") {
                guard !sources.isEmpty, !outputPath.isEmpty else { return }
                model.create(archive: URL(fileURLWithPath: outputPath), from: sources, format: format)
            }
            .disabled(sources.isEmpty || outputPath.isEmpty || isRunning)

            dropZone(title: "或把文件/文件夹拖到这里压缩") { urls in
                sources = urls
                outputPath = defaultArchivePath()
            }
        }
    }

    // MARK: - 解压

    private var extractSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("解压").font(.headline)
            HStack {
                Button("选择压缩包…") { importingArchive = true }
                Text(archive?.lastPathComponent ?? "未选择").foregroundStyle(.secondary)
            }
            HStack {
                Text("输出目录")
                TextField("输出目录", text: $extractPath)
                    .textFieldStyle(.roundedBorder)
                Button("选择…") { importingDir = true }
            }
            Button("开始解压") {
                guard let archive, !extractPath.isEmpty else { return }
                model.extract(archive: archive, to: URL(fileURLWithPath: extractPath))
            }
            .disabled(archive == nil || extractPath.isEmpty || isRunning)

            dropZone(title: "或把压缩包拖到这里解压") { urls in
                if let first = urls.first {
                    archive = first
                    extractPath = defaultExtractPath(for: first)
                }
            }
        }
    }

    // MARK: - 拖拽

    private func dropZone(title: String, onDropURLs: @escaping ([URL]) -> Void) -> some View {
        Text(title)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 8).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])))
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                loadURLs(from: providers, completion: onDropURLs)
                return true
            }
    }

    private func loadURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }
                if let url { lock.lock(); urls.append(url); lock.unlock() }
            }
        }

        group.notify(queue: .main) { completion(urls) }
    }

    // MARK: - 默认路径

    private func defaultArchivePath() -> String {
        guard let first = sources.first else { return "" }
        let base = first.deletingPathExtension().lastPathComponent
        return first.deletingLastPathComponent()
            .appendingPathComponent("\(base).\(format.fileExtension)").path
    }

    private func defaultExtractPath(for archive: URL) -> String {
        archive.deletingLastPathComponent()
            .appendingPathComponent(archive.deletingPathExtension().lastPathComponent).path
    }
}
