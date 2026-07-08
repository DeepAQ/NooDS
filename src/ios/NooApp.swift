/*
    Copyright 2019-2025 Hydr8gon

    This file is part of NooDS.

    NooDS is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    NooDS is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with NooDS. If not, see <https://www.gnu.org/licenses/>.
*/

import SwiftUI
import AVFAudio

@main
struct NooApp: App {
    @State var running = false
    @State var ndsPath = String()
    @State var gbaPath = String()
    let audio = AVAudioEngine()

    init() {
        // Initialize settings using the app's documents folder
        let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        CoreBridge.loadSettings(docsUrl.path + "/noods")

        // Configure the audio session for playback
        let session = AVAudioSession.sharedInstance()
        try! session.setCategory(.playback, mode: .moviePlayback)
        try! session.setActive(true)

        // Hook up the audio callback and start playing
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100, channels: 2, interleaved: true)!
        let source = AVAudioSourceNode(format: format, renderBlock: audioCb)
        audio.attach(source)
        audio.connect(source, to: audio.outputNode, format: format)
        audio.prepare()
        try! audio.start()
    }

    var body: some Scene {
        // Choose the current window based on run state
        WindowGroup {
            if running {
                NooView(running: $running, ndsPath: ndsPath, gbaPath: gbaPath)
            }
            else {
                FileBrowser(running: $running, ndsPath: $ndsPath, gbaPath: $gbaPath)
            }
        }
    }

    func audioCb(isSilence: UnsafeMutablePointer<ObjCBool>, timestamp: UnsafePointer<AudioTimeStamp>,
        frameCount: AVAudioFrameCount, outputData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        // Get the core to fill the audio buffer
        CoreBridge.getSamples(outputData.pointee.mBuffers.mData, frameCount)
        return noErr
    }
}
