//
//  ViewController.swift
//  MergeTwoVideoBasic
//
//  Created by Tushar Khandaker on 4/8/23.
//

import UIKit
import Photos
import AVFoundation

class ViewController: UIViewController {
    
    var audioAsset: AVAsset? = AVAsset(url: Bundle.main.url(forResource: "audio", withExtension: "mp3")!)
    var firstAsset: AVAsset? = AVAsset(url: Bundle.main.url(forResource: "video2", withExtension: "mp4")!)
    var secondAsset:AVAsset? = AVAsset(url: Bundle.main.url(forResource: "video1", withExtension: "mp4")!)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mergeTwoVideo()
        
    }
    
    func mergeTwoVideo() {
        // 1
        let mixComposition = AVMutableComposition()
        // 2
        let firstTrack = makeFirstTrack(mixComposition: mixComposition)!
        // 3
        let secondTrack = makeSecondTrack(mixComposition: mixComposition)!
        // 4
        makeAudioTrack(with: audioAsset!, mixComposition: mixComposition)!
        // 5
        let mainInstruction = setMainInstruction(firstTrack: firstTrack, secondTrack: secondTrack)
        // 6
        let mainVideoComposition = getMainVideoComposition(mainInstruction: mainInstruction)
        // 7
        let url = makeVideoUrl()!
        // 8
        exportFinalVideo(with: mixComposition, and: mainVideoComposition, videoUrl: url)
        
    }
    
    func exportDidFinish(_ session: AVAssetExportSession) {

        guard
            session.status == AVAssetExportSession.Status.completed,
            let outputURL = session.outputURL
        else { return }
        
        let saveVideoToPhotos = {
            let changes: () -> Void = {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
            }
            PHPhotoLibrary.shared().performChanges(changes) { saved, error in
                DispatchQueue.main.async {
                    let success = saved && (error == nil)
                    let title = success ? "Success" : "Error"
                    let message = success ? "Video saved" : "Failed to save video"
                    
                    let alert = UIAlertController(
                        title: title,
                        message: message,
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(
                        title: "OK",
                        style: UIAlertAction.Style.cancel,
                        handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    saveVideoToPhotos()
                }
            }
        } else {
            saveVideoToPhotos()
        }
    }
}


extension ViewController {
    
    // MARK: - Make AVMutableCompositionTrack for 1st asset
    func makeFirstTrack(mixComposition: AVMutableComposition)-> AVMutableCompositionTrack? {
        
        guard let firstTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        else { return  nil }
        
        do {
            try firstTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: firstAsset!.duration), of: firstAsset!.tracks(withMediaType: .video)[0], at: .zero)
            return firstTrack
        } catch {
            print("Failed to load first track")
        }
        return nil
    }
    
    
    // MARK: - Make AVMutableCompositionTrack for 2nd asset
    func makeSecondTrack(mixComposition: AVMutableComposition)-> AVMutableCompositionTrack? {
        
        guard let secondTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { return  nil}
        do {
            try secondTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: secondAsset!.duration), of: secondAsset!.tracks(withMediaType: .video)[0], at: firstAsset!.duration)
            return secondTrack
        } catch {
            print("Failed to load second track")
        }
        return nil
    }
    
    
    // MARK: - Make AVMutableCompositionTrack for audio asset
    func makeAudioTrack(with loadedAudioAsset: AVAsset, mixComposition: AVMutableComposition)-> AVMutableCompositionTrack? {
        
        let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: 0)
        do {
            try audioTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: CMTimeAdd(firstAsset!.duration,secondAsset!.duration)),
                of: loadedAudioAsset.tracks(withMediaType: .audio)[0],
                at: .zero)
            return audioTrack
        } catch {
            print("Failed to load Audio track")
        }
        return nil
    }
    
    
    // MARK: - Set AV-Mutable-Video-Composition-Instruction
    func setMainInstruction(firstTrack: AVMutableCompositionTrack, secondTrack: AVMutableCompositionTrack)-> AVMutableVideoCompositionInstruction {
        
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: CMTimeAdd(firstAsset!.duration, secondAsset!.duration))
        
        let firstInstruction = AVMutableVideoCompositionLayerInstruction(
            assetTrack: firstTrack)
        firstInstruction.setOpacity(0.0, at: firstAsset!.duration)
        
        let secondInstruction = AVMutableVideoCompositionLayerInstruction(
            assetTrack: secondTrack)
        
        mainInstruction.layerInstructions = [firstInstruction, secondInstruction]
        return mainInstruction
    }
    
    
    // MARK: - Get AV-Mutable-Video-Composition
    func getMainVideoComposition(mainInstruction: AVMutableVideoCompositionInstruction)-> AVMutableVideoComposition {
        
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30) // fps
        
        let videoAssetTrack = secondAsset!.tracks(withMediaType: .video)[0]
        let naturalSize : CGSize = videoAssetTrack.naturalSize

        ///Rendering  video size
        let renderWidth = naturalSize.width
        let renderHeight = naturalSize.height
        
        mainComposition.renderSize = CGSize(width: renderWidth, height: renderHeight)
        return mainComposition
    }
    
    
    // MARK: - Configure Video URL
    func makeVideoUrl()-> URL? {
        
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let date = dateFormatter.string(from: Date())
        let url = documentDirectory.appendingPathComponent("mergeVideo-\(date).mov")
        return url
    }
    
    
    // MARK: - Let's Export
    func exportFinalVideo(with mixComposition: AVMutableComposition, and mainVideoComposition: AVMutableVideoComposition, videoUrl: URL) {
        
        guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { return }
        exporter.outputURL = videoUrl
        exporter.outputFileType = AVFileType.mov
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = mainVideoComposition
        
        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                self.exportDidFinish(exporter)
            }
        }
    }
    
}
