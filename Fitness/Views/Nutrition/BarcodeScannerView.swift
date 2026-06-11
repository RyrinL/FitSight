import SwiftUI
import AVFoundation

// MARK: - Scanned food result

struct ScannedFood {
    let name: String
    let calories100g: Double
    let protein100g: Double
    let carbs100g: Double
    let fat100g: Double
}

// MARK: - View

struct BarcodeScannerView: View {
    let onFood: (ScannedFood) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = BarcodeScanner()
    @State private var isLooking = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            BarcodeCameraPreview(session: scanner.session)
                .ignoresSafeArea()

            // Viewfinder
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.mint, lineWidth: 2)
                .frame(width: 280, height: 130)
                .shadow(color: .mint.opacity(0.4), radius: 8)

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
                Spacer()
                VStack(spacing: 8) {
                    if isLooking {
                        ProgressView().tint(.mint)
                        Text("Looking up product…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    } else if let err = errorMessage {
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(Color.fitRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("Try again") {
                            errorMessage = nil
                            scanner.resume()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.mint)
                    } else {
                        Text("Point camera at a barcode")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear { scanner.start() }
        .onDisappear { scanner.stop() }
        .onChange(of: scanner.detectedCode) { code in
            guard let code, !isLooking else { return }
            isLooking = true
            scanner.pause()
            Task {
                do {
                    let food = try await OpenFoodFactsService.lookup(barcode: code)
                    await MainActor.run {
                        isLooking = false
                        onFood(food)
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isLooking = false
                        errorMessage = "Product not found. Try entering manually."
                    }
                }
            }
        }
    }
}

// MARK: - Camera preview

private struct BarcodeCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView { PreviewView() }
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session      = session
        uiView.previewLayer.videoGravity = .resizeAspectFill
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Scanner engine

final class BarcodeScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var detectedCode: String?

    let session = AVCaptureSession()
    private var isConfigured = false
    private let sessionQueue = DispatchQueue(label: "fitsight.barcode.session")

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func pause() { stop() }

    func resume() {
        detectedCode = nil
        start()
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.beginConfiguration()
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .qr]
        }
        session.commitConfiguration()
        isConfigured = true
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue,
              detectedCode == nil else { return }
        detectedCode = code
    }
}

// MARK: - OpenFoodFacts API

enum OpenFoodFactsService {
    private struct Response: Decodable {
        let status: Int
        let product: Product?

        struct Product: Decodable {
            let product_name: String?
            let nutriments: Nutriments?

            struct Nutriments: Decodable {
                let energy_kcal_100g:    Double?
                let proteins_100g:       Double?
                let carbohydrates_100g:  Double?
                let fat_100g:            Double?

                private enum CodingKeys: String, CodingKey {
                    case energy_kcal_100g   = "energy-kcal_100g"
                    case proteins_100g
                    case carbohydrates_100g
                    case fat_100g
                }
            }
        }
    }

    enum LookupError: Error { case notFound, badData }

    static func lookup(barcode: String) async throws -> ScannedFood {
        let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response  = try JSONDecoder().decode(Response.self, from: data)

        guard response.status == 1,
              let product = response.product,
              let name    = product.product_name, !name.isEmpty else {
            throw LookupError.notFound
        }

        let n = product.nutriments
        return ScannedFood(
            name:         name,
            calories100g: n?.energy_kcal_100g   ?? 0,
            protein100g:  n?.proteins_100g       ?? 0,
            carbs100g:    n?.carbohydrates_100g  ?? 0,
            fat100g:      n?.fat_100g            ?? 0
        )
    }
}
