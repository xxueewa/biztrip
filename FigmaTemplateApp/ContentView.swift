import AVFoundation
import SwiftUI

enum Constants {
    static let sampleAmount: Int = 200
    static let downsampleFactor = 8
    static let magnitudeLimit: Float = 100
}
struct ContentView: View {

    var body: some View {
        FlowPager()
            .preferredColorScheme(.light)
    }
}

private struct FlowPager: View {

    var body: some View {
        TabView {
            PhoneScreen {
                CenterRecordingScreen()
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black)
        .ignoresSafeArea()
    }
}

private struct PhoneScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
    }
}

private struct CenterRecordingScreen: View {

    var body: some View {
    }
}

@MainActor
@Observable
private final class AudioModel {
    static let shared = AudioModel()
    private var isMonitoring = false
    private var audioEngine = AVAudioEngine()
    private let buffersize = 8192
    private var fftSetup: OpaquePointer?
    
    private init() {}
    
    
    
    var fftMagnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
    
    var downsampleMagnitudes: [Float] {
        fftMagnitudes.lazy.enumerated().compactMap { index, value in
            index.isMultiple(of: Constants.downsampleFactor) ? value : nil
        }
    }
    
    func startMonitoring() async {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        fftSetup = vDSP_DFT_zop_CreateSetup(nil as vDSP_DFT_Setup?, 8192, vDSP_DFT_Direction.FORWARD)
    }
    
    func stopMonitoring() {
        
    }
    
    func performFFT(data: [Float]) async -> [Float] {
        
    }
}
