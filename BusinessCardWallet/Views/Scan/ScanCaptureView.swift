import SwiftUI
import UIKit
import AVFoundation
import Photos
import Vision
import CoreImage

struct ScanCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedImage: UIImage?

    @State private var isShowingAutoScanner = false
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
                                    Text("명함을 가이드 안에 두면 자동으로 스캔됩니다")
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
            .fullScreenCover(isPresented: $isShowingAutoScanner) {
                AutoScanCameraContainer(
                    onCancel: { isShowingAutoScanner = false },
                    onCapture: { image in
                        selectedImage = image
                        isShowingAutoScanner = false
                        Task { await runOCRIfPossible() }
                    },
                    onError: { message in
                        isShowingAutoScanner = false
                        errorMessage = message
                    }
                )
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
            isShowingAutoScanner = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        isShowingAutoScanner = true
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
        guard !isProcessing else { return }

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
                parkingInfo: result.parkingInfo ?? "",
                parkingCandidates: result.parkingCandidates,
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

private struct AutoScanCameraContainer: View {
    let onCancel: () -> Void
    let onCapture: (UIImage) -> Void
    let onError: (String) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            AutoScanCameraRepresentable(onCapture: onCapture, onError: onError)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Button("닫기") {
                        onCancel()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())

                    Spacer()
                }

                Text("명함을 프레임 안에 맞추면 자동 스캔됩니다")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding()
        }
    }
}

private struct AutoScanCameraRepresentable: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> AutoScanCameraViewController {
        AutoScanCameraViewController(onCapture: onCapture, onError: onError)
    }

    func updateUIViewController(_ uiViewController: AutoScanCameraViewController, context: Context) {}
}

private final class AutoScanCameraViewController: UIViewController, @preconcurrency AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let guideLayer = CAShapeLayer()
    private let detectedLayer = CAShapeLayer()
    private let detectionQueue = DispatchQueue(label: "camera.rectangle.detection.queue")
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let ciContext = CIContext(options: nil)

    private var isDetectingFrame = false
    private var hasCapturedImage = false
    private var frameCounter = 0
    private var stableFrameCount = 0
    private var textStableCount = 0
    private var lastBoundingBox: CGRect?

    private let onCapture: (UIImage) -> Void
    private let onError: (String) -> Void

    init(onCapture: @escaping (UIImage) -> Void, onError: @escaping (String) -> Void) {
        self.onCapture = onCapture
        self.onError = onError
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        guideLayer.fillColor = UIColor.clear.cgColor
        guideLayer.strokeColor = UIColor.white.withAlphaComponent(0.75).cgColor
        guideLayer.lineWidth = 2
        guideLayer.lineDashPattern = [10, 8]
        view.layer.addSublayer(guideLayer)

        detectedLayer.fillColor = UIColor.clear.cgColor
        detectedLayer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.95).cgColor
        detectedLayer.lineWidth = 3
        view.layer.addSublayer(detectedLayer)

        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        guideLayer.frame = view.bounds
        detectedLayer.frame = view.bounds
        updateGuidePath()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            onError("후면 카메라를 찾을 수 없습니다.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            session.commitConfiguration()
            onError("카메라 입력을 구성하지 못했습니다. (\(error.localizedDescription))")
            return
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        videoOutput.setSampleBufferDelegate(self, queue: detectionQueue)

        session.commitConfiguration()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !hasCapturedImage else { return }
        frameCounter += 1
        if frameCounter % 2 != 0 { return }

        guard !isDetectingFrame else { return }
        isDetectingFrame = true
        defer { isDetectingFrame = false }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 3
        request.minimumConfidence = 0.6
        request.minimumAspectRatio = 0.35
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.10
        request.quadratureTolerance = 25

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let rectangle = bestRectangle(from: request.results ?? []),
              isGoodCandidate(rectangle) else {
            stableFrameCount = 0
            lastBoundingBox = nil
            DispatchQueue.main.async {
                self.detectedLayer.path = nil
            }
            evaluateTextFallback(pixelBuffer: pixelBuffer)
            return
        }

        textStableCount = 0

        DispatchQueue.main.async {
            self.drawOverlay(for: rectangle)
        }

        if let previous = lastBoundingBox, isStable(from: previous, to: rectangle.boundingBox) {
            stableFrameCount += 1
        } else {
            stableFrameCount = 1
        }
        lastBoundingBox = rectangle.boundingBox

        if stableFrameCount >= 4 {
            captureCardImage(from: pixelBuffer, rectangle: rectangle)
        }
    }

    private func isGoodCandidate(_ observation: VNRectangleObservation) -> Bool {
        let box = observation.boundingBox
        let area = box.width * box.height
        if area < 0.08 { return false }

        let centerX = box.midX
        let centerY = box.midY
        if abs(centerX - 0.5) > 0.4 { return false }
        if abs(centerY - 0.5) > 0.4 { return false }

        return true
    }

    private func isStable(from previous: CGRect, to current: CGRect) -> Bool {
        let centerDelta = hypot(previous.midX - current.midX, previous.midY - current.midY)
        let sizeDelta = abs(previous.width - current.width) + abs(previous.height - current.height)
        return centerDelta < 0.05 && sizeDelta < 0.10
    }

    private func bestRectangle(from observations: [VNRectangleObservation]) -> VNRectangleObservation? {
        observations
            .filter(isGoodCandidate)
            .max { lhs, rhs in
                score(lhs) < score(rhs)
            }
    }

    private func score(_ observation: VNRectangleObservation) -> CGFloat {
        let box = observation.boundingBox
        let area = box.width * box.height
        let centerDistance = hypot(box.midX - 0.5, box.midY - 0.5)
        let aspectPenalty = abs((box.height / max(box.width, 0.001)) - 0.55)
        return area * 2 - centerDistance - aspectPenalty * 0.15
    }

    private func captureCardImage(from pixelBuffer: CVPixelBuffer, rectangle: VNRectangleObservation) {
        guard !hasCapturedImage else { return }
        hasCapturedImage = true

        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        let processed = Self.perspectiveAndColorAdjusted(ciImage: cameraImage, rectangle: rectangle) ?? cameraImage

        guard let cgImage = ciContext.createCGImage(processed, from: processed.extent) else {
            hasCapturedImage = false
            DispatchQueue.main.async {
                self.onError("스캔 이미지를 생성하지 못했습니다. 다시 시도해주세요.")
            }
            return
        }

        let finalImage = UIImage(cgImage: cgImage)

        DispatchQueue.main.async {
            self.onCapture(finalImage)
        }
    }

    private func evaluateTextFallback(pixelBuffer: CVPixelBuffer) {
        if frameCounter % 3 != 0 { return }
        guard isLikelyCardTextPresent(pixelBuffer: pixelBuffer) else {
            textStableCount = 0
            return
        }

        textStableCount += 1
        if textStableCount >= 3 {
            captureUsingGuideCrop(from: pixelBuffer)
        }
    }

    private func isLikelyCardTextPresent(pixelBuffer: CVPixelBuffer) -> Bool {
        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        let guideCrop = croppedGuideImage(from: cameraImage)

        guard let cgImage = ciContext.createCGImage(guideCrop, from: guideCrop.extent) else { return false }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.minimumTextHeight = 0.02

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return false
        }

        let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
        let count = observations.reduce(into: 0) { partial, observation in
            guard let candidate = observation.topCandidates(1).first else { return }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.count >= 2 && candidate.confidence > 0.30 {
                partial += 1
            }
        }
        return count >= 3
    }

    private func captureUsingGuideCrop(from pixelBuffer: CVPixelBuffer) {
        guard !hasCapturedImage else { return }
        hasCapturedImage = true

        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        let guideCrop = croppedGuideImage(from: cameraImage)

        let colorAdjusted = guideCrop.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 1.02,
            kCIInputContrastKey: 1.06,
            kCIInputBrightnessKey: 0.01
        ])

        guard let cgImage = ciContext.createCGImage(colorAdjusted, from: colorAdjusted.extent) else {
            hasCapturedImage = false
            return
        }

        DispatchQueue.main.async {
            self.onCapture(UIImage(cgImage: cgImage))
        }
    }

    private func croppedGuideImage(from cameraImage: CIImage) -> CIImage {
        let extent = cameraImage.extent
        let width = extent.width * 0.84
        let height = width / 1.72
        let x = extent.minX + (extent.width - width) * 0.5
        let y = extent.minY + (extent.height - height) * 0.5
        let cropRect = CGRect(x: x, y: y, width: width, height: height).intersection(extent)
        return cameraImage.cropped(to: cropRect)
    }

    private static func perspectiveAndColorAdjusted(ciImage: CIImage, rectangle: VNRectangleObservation) -> CIImage? {
        let extent = ciImage.extent

        func mapPoint(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: extent.origin.x + point.x * extent.width,
                y: extent.origin.y + point.y * extent.height
            )
        }

        let corrected = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: mapPoint(rectangle.topLeft)),
            "inputTopRight": CIVector(cgPoint: mapPoint(rectangle.topRight)),
            "inputBottomLeft": CIVector(cgPoint: mapPoint(rectangle.bottomLeft)),
            "inputBottomRight": CIVector(cgPoint: mapPoint(rectangle.bottomRight))
        ])

        let colorAdjusted = corrected.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 1.03,
            kCIInputContrastKey: 1.08,
            kCIInputBrightnessKey: 0.01
        ])

        let exposureAdjusted = colorAdjusted.applyingFilter("CIExposureAdjust", parameters: [
            kCIInputEVKey: 0.10
        ])

        return exposureAdjusted
    }

    private func drawOverlay(for observation: VNRectangleObservation) {
        let topLeft = previewPoint(from: observation.topLeft)
        let topRight = previewPoint(from: observation.topRight)
        let bottomRight = previewPoint(from: observation.bottomRight)
        let bottomLeft = previewPoint(from: observation.bottomLeft)

        let path = UIBezierPath()
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.close()

        detectedLayer.path = path.cgPath
    }

    private func updateGuidePath() {
        let guideRect = guideRectInView()
        guideLayer.path = UIBezierPath(roundedRect: guideRect, cornerRadius: 16).cgPath
    }

    private func guideRectInView() -> CGRect {
        let width = view.bounds.width * 0.84
        let height = width / 1.72
        let x = (view.bounds.width - width) * 0.5
        let y = (view.bounds.height - height) * 0.5
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func previewPoint(from normalizedVisionPoint: CGPoint) -> CGPoint {
        let capturePoint = CGPoint(x: normalizedVisionPoint.x, y: 1 - normalizedVisionPoint.y)
        return previewLayer.layerPointConverted(fromCaptureDevicePoint: capturePoint)
    }
}
