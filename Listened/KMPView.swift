//
//  KMPView.swift
//  AdvGame
//
//  Created by Koji Murata on 8/23/20.
//


import UIKit
import AVKit
import AVFoundation

class KMPView: UIViewController {
    
    @IBOutlet var skipButton: UIButton!
    var player:AVPlayer?
    var playerLayer:AVPlayerLayer?
    weak var parentVc:ViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        playVideo()
    }
    
    private func playVideo() {
        
        guard let path = Bundle.main.path(forResource: "splashVideo", ofType:"mp4") else {
            debugPrint("video.m4v not found")
            return
        }
        
        player = AVPlayer(url: URL(fileURLWithPath: path))
        NotificationCenter.default.addObserver(self, selector: #selector(skipPressed(_:)), name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer!.frame = self.view.bounds
        self.view.layer.addSublayer(playerLayer!)
        playerLayer?.videoGravity = .resizeAspectFill
        
        player!.play()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.skipButton.isEnabled = true
        }
        
    }
    
    //
    
    @objc
    @IBAction func skipPressed(_ sender: Any) {
        skipButton.isEnabled = false
        print("Title Menu Played")
        
        player!.pause()
        playerLayer!.removeFromSuperlayer()
        
        // Close View
        self.dismiss(animated: false) {
            self.parentVc?.splashDidFinishedPlaying()
        }
    }
    
    //
    //
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .all
    }
    
}
