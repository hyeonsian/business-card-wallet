import SwiftUI
import UIKit
import AVFoundation
import Photos

struct ScanCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedImage: UIImage?

    @State private var isShowingCameraPicker = false
    @State private var isShowingPhotoPicker = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var permissionAlert: PermissionAlert?

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
                        handleCameraTap()
                    } label: {
                        Label("카메라", systemImage: "camera")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)

                    Button {
                        handlePhotoLibraryTap()
                    } label: {
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
            .sheet(isPresented: $isShowingCameraPicker) {
                CameraPickerView(selectedImage: $selectedImage, sourceType: .camera)
            }
            .sheet(isPresented: $isShowingPhotoPicker) {
                CameraPickerView(selectedImage: $selectedImage, sourceType: .photoLibrary)
            }
            .alert(item: $permissionAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("설정 열기"), action: openSettings),
                    secondaryButton: .cancel(Text("취소"))
                )
            }
        }
    }

    private func handleCameraTap() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "이 기기에서는 카메라를 사용할 수 없습니다."
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isShowingCameraPicker = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        isShowingCameraPicker = true
                    } else {
                        permissionAlert = PermissionAlert(
                            title: "카메라 권한 필요",
                            message: "명함 촬영을 위해 카메라 권한이 필요합니다. 설정에서 권한을 허용해주세요."
                        )
                    }
                }
            }
        case .denied, .restricted:
            permissionAlert = PermissionAlert(
                title: "카메라 권한 필요",
                message: "명함 촬영을 위해 카메라 권한이 필요합니다. 설정에서 권한을 허용해주세요."
            )
        @unknown default:
            errorMessage = "카메라 권한 상태를 확인할 수 없습니다."
        }
    }

    private func handlePhotoLibraryTap() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            isShowingPhotoPicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        isShowingPhotoPicker = true
                    } else {
                        permissionAlert = PermissionAlert(
                            title: "사진 접근 권한 필요",
                            message: "사진첩에서 명함을 선택하려면 사진 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요."
                        )
                    }
                }
            }
        case .denied, .restricted:
            permissionAlert = PermissionAlert(
                title: "사진 접근 권한 필요",
                message: "사진첩에서 명함을 선택하려면 사진 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요."
            )
        @unknown default:
            errorMessage = "사진 접근 권한 상태를 확인할 수 없습니다."
        }
    }

    @MainActor
    private func runOCRIfPossible() async {
        guard let selectedImage else { return }
        isProcessing = true
        errorMessage = nil

        do {
            let imagePath = try ImageStore.saveJPEG(selectedImage)
            let thumbnailPath = try ImageStore.saveThumbnailJPEG(selectedImage)
            let result = try await VisionOCRService.shared.extract(from: selectedImage)

            let draft = NewCardDraft(
                imageLocalPath: imagePath,
                thumbnailLocalPath: thumbnailPath,
                fullText: result.fullText,
                name: result.name ?? "",
                company: result.company ?? "",
                jobTitle: result.jobTitle ?? "",
                phone: result.phone ?? "",
                email: result.email ?? "",
                emailCandidates: result.emailCandidates,
                address: result.address ?? "",
                website: result.website ?? "",
                websiteCandidates: result.websiteCandidates,
                phoneCandidates: result.phoneCandidates,
                memo: ""
            )

            isProcessing = false
            onScanComplete(draft)
        } catch {
            isProcessing = false
            errorMessage = "OCR 처리에 실패했습니다. 다시 시도해주세요. (\(error.localizedDescription))"
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct PermissionAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
