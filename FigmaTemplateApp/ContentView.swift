import AVFoundation
import SwiftUI
import Accelerate
import Charts

enum Constants {
    static let sampleAmount: Int = 200
    static let downsampleFactor = 8
    static let magnitudeLimit: Float = 100
}
struct ContentView: View {
    
    private var monitor = AudioModel.shared
    private let chartGradient = LinearGradient(
        gradient: Gradient(colors: [.blue, .purple, .red]),
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 20){
            
            Button(action: {
                if monitor.isMonitoring {
                    monitor.stopMonitoring()
                } else {
                    Task { await monitor.startMonitoring() }
                }
            }) {
                Label(monitor.isMonitoring ? "Stop" : "Start", systemImage: monitor.isMonitoring ? "stop.fill" : "waveform")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(monitor.isMonitoring ? Color.red : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            }
            
            Chart(monitor.downsampleMagnitudes.indices, id: \.self) {index in
                LineMark(
                    x: .value("Frequency", index * Constants.downsampleFactor),
                    y: .value("Magnitude", monitor.downsampleMagnitudes[index])
                )
                
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3))
                .foregroundStyle(chartGradient)
            }
            .chartYScale(domain: 0...max(monitor.fftMagnitudes.max() ?? 0, Constants.magnitudeLimit))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 300)
            .padding()
            
            .animation(.easeOut, value: monitor.downsampleMagnitudes)
            
        }
        .padding(.bottom, 20)
        .padding()
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
    var isMonitoring = false
    private var audioEngine = AVAudioEngine()
    private let bufferSize = 8192
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
        // digital signal peocessing routines on large vectors
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, UInt(self.bufferSize), .FORWARD)
        
        let audioStream = AsyncStream<[Float]> { continuation in
            inputNode.installTap(onBus: 0, bufferSize: UInt32(self.bufferSize), format: inputFormat) {
                @Sendable buffer, _ in
                let channelData = buffer.floatChannelData?[0] // channel number [1, 2] idx zero always has value
                let frameCount = Int(buffer.frameLength)
                
                let floatData = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
                
                continuation.yield(floatData)
            }
        }
        
        do {
            try audioEngine.start()
            isMonitoring = true
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
            return
        }
        
        for await floatData in audioStream {
            self.fftMagnitudes = await performFFT(data: floatData)
        }
    }
    
    func stopMonitoring() {
        audioEngine.stop()
        
        audioEngine.inputNode.removeTap(onBus: 0)
        
        fftMagnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
        
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
            fftSetup = nil
        }
        
        isMonitoring = false;
        
    }
    
    func performFFT(data: [Float]) async -> [Float] {
        // performs the FFT transformation, responsible for extracting the strength
        // of different frequencies from the raw waveform given by the microphone.
        guard let setup = fftSetup else {
            return [Float](repeating: 0, count: Constants.sampleAmount)
        }
            
        var realIn = data
        var imagIn = [Float](repeating: 0, count: bufferSize)
        var realOut = [Float](repeating: 0, count: bufferSize)
        var imagOut = [Float](repeating: 0, count: bufferSize)
        
        var magnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
        
        realIn.withUnsafeMutableBufferPointer { realInPtr in
            imagIn.withUnsafeMutableBufferPointer { imagInPtr in
                realOut.withUnsafeMutableBufferPointer { realOutPtr in
                    imagOut.withUnsafeMutableBufferPointer { imagOutPtr in
                        // Discrete Fourier Transform
                        vDSP_DFT_Execute(setup, realInPtr.baseAddress!, imagInPtr.baseAddress!, realOutPtr.baseAddress!, imagOutPtr.baseAddress!)
                        
                        var complex = DSPSplitComplex(realp: realOutPtr.baseAddress!, imagp: imagOutPtr.baseAddress!)
                        
                        // magnitude = sqrt(realOut^2 + imagOut^2)
                        vDSP_zvabs(&complex, 1, &magnitudes, 1, UInt(Constants.sampleAmount))
                        
                    }
                }
                
            }
        }
        return magnitudes.map {min($0, Constants.magnitudeLimit)}
    }
}
