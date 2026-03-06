import SwiftUI
import PhotosUI
import UIKit

struct ScanCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    @State private var isShowingCamera = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    let onScanComplete: (NewCardDraft) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Group {
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.gray.opacity(0.3)))
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.gray.opacity(0.12))
                            .frame(height: 220)
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "person.text.rectangle")
                                        .font(.system(size: 52))
                                        .foregroundStyle(.secondary)
                                    Text("명함 이미지를 촬영하거나 선택하세요")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        isShowingCamera = true
                    } label: {
                        Label("카메라", systemImage: "camera")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera) || isProcessing)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        Label("사진첩", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
                }

                Button {
                    Task { await runOCRIfPossible() }
                } label: {
                    if isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("OCR 분석 시작")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedImage == nil || isProcessing)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("명함 스캔")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraPickerView(selectedImage: $selectedImage)
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    do {
                        if let data = try await newValue.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                        }
                    } catch {
                        errorMessage = "사진 불러오기에 실패했습니다: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    @MainActor
    private func runOCRIfPossible() async {
        guard let selectedImage else { return }
        isProcessing = true
        errorMessage = nil

        do {
            let imagePath = try ImageStore.saveJPEG(selectedImage)
            let result = try await VisionOCRService.shared.extract(from: selectedImage)

            let draft = NewCardDraft(
                imageLocalPath: imagePath,
                fullText: result.fullText,
                name: result.name ?? "",
                company: result.company ?? "",
                jobTitle: result.jobTitle ?? "",
                phone: result.phone ?? "",
                email: result.email ?? "",
                address: result.address ?? "",
                website: result.website ?? "",
                memo: ""
            )

            isProcessing = false
            onScanComplete(draft)
        } catch {
            isProcessing = false
            errorMessage = "OCR 처리에 실패했습니다. 다시 시도해주세요. (\(error.localizedDescription))"
        }
    }
}
