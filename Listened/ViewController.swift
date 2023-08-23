//
//  ViewController.swift
//  AdvGame
//
//  Created by Koji Murata on 6/30/20.
//

import SwiftUI
import UIKit
import SpriteKit
import SceneKit
import AVFoundation
import GameController


class SettingsController: UIViewController {
    
    @IBOutlet var settingsTitleLabel: UILabel!
    
    @IBOutlet var dpadLabel: UILabel!
    @IBOutlet var dpadSettingBtn: UIButton!
    
    @IBOutlet var optPerformanceLabel: UILabel!
    @IBOutlet var optPerfSettingBtn: UIButton!
    
    @IBOutlet var listenVOLabel: UILabel!
    @IBOutlet var listenVOSettingBtn: UIButton!
    
    
    @IBAction func didChangeSetting(_ sender: UIButton) {
        //
        if sender == dpadSettingBtn {
            
            
        }
        if sender == optPerfSettingBtn {
            
            
        }
        if sender == listenVOSettingBtn {
            
            
        }
        //
    }
    
    @IBAction func closeView(_ sender: Any) {
        self.dismiss(animated: true) {
        }
    }
}

class InGameMenuController: UIViewController {
    
    @IBOutlet var bgView: UIView!
    
    @IBOutlet var backToHomeBtn: UIButton!
    @IBOutlet var dismissBtn: UIButton!
    @IBOutlet var openSettingBtn: UIButton!
    
    @IBOutlet var actionABtn: [UIButton]!
    @IBOutlet var regAnimLayer: UIImageView!
    
    weak var gameVC:GameScene?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // let the buttons hide
        // all actions are reset by this moment
        for btn in actionABtn {
            btn.isEnabled = false
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        self.gameVC?.setNpcControls(allow: false)
        
        if self.view.tag == 0 {
            // open menu normally
            self.backToHomeBtn.isEnabled = true
            self.dismissBtn.isEnabled = true
            self.openSettingBtn.isEnabled = true
            
            // enable action available buttons only
            for btn in actionABtn {
                if btn.accessibilityLabel != nil {
                    btn.isEnabled = true
                } else {
                    btn.isEnabled = false
                }
            }
            
        } else if self.view.tag == 1 {
            
            self.backToHomeBtn.isEnabled = false
            self.dismissBtn.isEnabled = false
            self.openSettingBtn.isEnabled = false
            
            for btn in actionABtn {
                if btn.accessibilityLabel != nil {
                    btn.isEnabled = true
                } else {
                    btn.isEnabled = false
                }
            }
            
            //actionABtn.alpha = 0.0
            //actionABtn.transform = CGAffineTransform(scaleX: 0.0, y: 0.0)
            
        }
        
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
    }
    
    @IBAction func backToHome(_ sender: Any) {
        
        self.gameVC?.spriteScene?.run((self.gameVC?.parentVC!.tapSound)!)
        
        self.dismiss(animated: true) {
            self.gameVC?.menuButton.isHidden = false
            self.gameVC?.eventCtrl.prepareEvent(event: "promptDiscardGame")
            self.gameVC?.present((self.gameVC?.eventCtrl)!, animated: true)
        }
        
    }
    
    @IBAction func openSettings(_ sender: Any) {
        
    }
    
    @IBAction func closeView(_ sender: Any) {
        //
        self.gameVC?.sfx(name: "deselect.wav")
        
        self.dismiss(animated: true) {
            self.gameVC?.menuButton.isHidden = false
            self.gameVC?.setNpcControls(allow: true)
            self.gameVC?.gameState = 0
        }
    }
    
    func dynamicCloseView() {
        
        self.gameVC?.sfx(name: "deselect.wav")
        
        self.dismiss(animated: true) {
            self.gameVC?.menuButton.isHidden = false
            self.gameVC?.menuButton.isEnabled = false
            
            UIView.animate(withDuration: 0.3) {
                self.gameVC?.menuButton.transform = CGAffineTransform(scaleX: 1.8, y: 1.8)
            } completion: { thebool in
                UIView.animate(withDuration: 0.3) {
                    self.gameVC?.menuButton.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                } completion: { bool2 in
                    UIView.animate(withDuration: 0.2) {
                        self.gameVC?.menuButton.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                    } completion: { thebool in
                        UIView.animate(withDuration: 0.15) {
                            self.gameVC?.menuButton.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                        } completion: { bool2 in
                            //
                            //self.gameVC?.menuButton.isEnabled = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                self.gameVC?.present((self.gameVC?.eventCtrl)!, animated: true)
                            }
                            //
                        }
                    }
                }
            }
        }
        
        
        
        
        
        
    }
    
    //
    
    @IBAction func gameActions(_ sender: Any) {
        
        self.gameVC?.sfx(name: "hudSelection.mp3")
        
        if sender is UIButton {
            
            let btn = sender as! UIButton
            
            if btn.accessibilityLabel != nil {
                self.dismiss(animated: true) {
                    self.gameVC?.present((self.gameVC?.eventCtrl)!, animated: false) {
                        self.gameVC?.eventCtrl.prepareEvent(event: btn.accessibilityLabel!)
                    }
                    
                }
            }
            
        }
        
        
        
    }
    
    func registerAction(actionCommand: String) {
        
        //
        let cmd = actionCommand.components(separatedBy: "/")
        
        if cmd.count > 0 {
            //
            
            // go through each to check which button has no action registered
            
            for x in 0..<actionABtn.count {
                
                let theActionButton = actionABtn[x]
                
                if theActionButton.accessibilityLabel == nil {
                    
                    // register action
                    let icnImg = UIImage(named: "ListenedGameAssets.scnassets/\(cmd.first!)")
                    theActionButton.accessibilityLabel = cmd.last
                    //
                    
                    regAnimLayer.alpha = 0.0
                    regAnimLayer.center = theActionButton.center
                    
                    regAnimLayer.transform = CGAffineTransformMakeScale(1.0, 1.0)
                    regAnimLayer.alpha = 1.0
                    
                    UIView.animate(withDuration: 0.5) {
                        self.gameVC?.sfx(name: "exclamate.wav")
                        theActionButton.setImage(icnImg, for: .normal)
                        
                        self.regAnimLayer.transform = CGAffineTransformMakeScale(1.5, 1.5)
                        self.regAnimLayer.alpha = 0.0
                        
                    } completion: { thebool in
                        
                        self.regAnimLayer.transform = CGAffineTransformMakeScale(1.0, 1.0)
                        self.regAnimLayer.alpha = 1.0
                        
                        UIView.animate(withDuration: 0.5) {
                            self.regAnimLayer.transform = CGAffineTransformMakeScale(1.5, 1.5)
                            self.regAnimLayer.alpha = 0.0
                            
                        } completion: { thebook2 in
                            self.regAnimLayer.transform = CGAffineTransformMakeScale(1.0, 1.0)
                            
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.dynamicCloseView()
                        }
                    }
                    
                    break;
                    
                }
                
            }
            
            
        } else {
            // failsafe
            print("Failsafe!! could not register action due to wrong actionCommand: ", actionCommand)
        }
        
        
        
    }
    
    func removeRegisteredaction(name: String) {
        
        for btn in actionABtn {
            if btn.accessibilityLabel == name {
                btn.accessibilityLabel = nil
            }
            // update non registered buttons
            if btn.accessibilityLabel == nil {
                btn.setImage(UIImage(named: "emptyActionBtn"), for: .normal)
                btn.isEnabled = false
            }
        }
        
    }
    
    
}

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    
    var dat: NSDictionary!
    var gameScene:GameScene!
    
    var tempPlayerData: [String:Any]!   //temporary user's data...
    var currentEvent: NSDictionary!
    var selectedGameKey: String?
    
    // default sounds
    let lineRead:SKAction = SKAction.playSoundFileNamed("ListenedGameAssets.scnassets/bgm/text.wav", waitForCompletion:true)
    
    let tapSound:SKAction = SKAction.playSoundFileNamed("ListenedGameAssets.scnassets/bgm/nextSelect.mp3", waitForCompletion:false)
    let itemSound:SKAction = SKAction.playSoundFileNamed("ListenedGameAssets.scnassets/bgm/pickUpItem.mp3", waitForCompletion: false)
    
    ///////////////////////////////  METHODS & FUNCTIONS
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.tag = 1; // Loads Menu Scene
        
        // Load Game Data
        let path = Bundle.main.path(forResource: "gameDat", ofType: "plist");
        dat = NSDictionary(contentsOfFile: path!)
        
        // Load User Data
        tempPlayerData = system_loadSaveData()
        print("saveDataLoaded \(String(describing: tempPlayerData))")
        
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification , object: nil, queue: .main) { notification in
            
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        if self.view.tag == 1 {
            
            self.view.tag = 2
            
            // SHOW debug menu - prepare menu data
            let keys = dat.object(forKey: "loadGame") as! NSDictionary
            
            var keyDat = keys.allKeys as! [String]
            keyDat.sort()
            
            var keysSorted = [String]()
            var i = 0
            for keyStr in keyDat {
                let theKey = keys.object(forKey: "\(keyStr)") as! NSDictionary
                let title = theKey.object(forKey: "title") ?? "No title"
                let output_str = "\(keyStr): \(title)"
                if keyStr != "moveMap" {
                    keysSorted.append(output_str)
                }
                i += 1;
            }
            
            keysSorted.sort {$0.localizedStandardCompare($1) == .orderedAscending}
            
            // display debug menu
            let selectionMenu = self.storyboard?.instantiateViewController(identifier: "KMMenuScreen") as! KMMenuScreen
            selectionMenu.dataPointer = keysSorted
            selectionMenu.parentVc = self
            self.present(selectionMenu, animated: true, completion: nil)
            
        } else if self.view.tag == 2 {
            self.view.tag = 3 // This scene will load next scene under current gameState
            let gameState = tempPlayerData["gameProgress"] as! String
            loadGameStage(stageName: gameState)
        } else if self.view.tag == 3 {
            self.view.tag = 3
            // moveMap
            loadGameStage(stageName: "moveMap")
        }
    }
    
    func splashDidFinishedPlaying() {
        
        // Show Menu Scene
        
        
    }
    
    // SCENE MANAGEMENT
    func titleDidLoad_startGame() {
        
        print("Chapter Selected: selectedGameKey - \(selectedGameKey)")
        
        // This is where ViewController will run command to start a specific scene <NOT FROM SAVE DATA>
        if selectedGameKey != "moveMap" {
            tempPlayerData["lastPosition"] = "";
        }
        if selectedGameKey == "continue" {
            selectedGameKey = tempPlayerData["gameProgress"] as? String
        }
        
        // save reset current gameStage
        print("current - SelectedGameKey:\(String(describing: selectedGameKey))")
        self.setGameStage(stageName: selectedGameKey!)
        
        loadGameStage(stageName: tempPlayerData["gameProgress"] as! String)
    }
    
    func loadGameStage(stageName: String) {
        //
        gameScene = nil
        //
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            //
            self.gameScene = self.storyboard?.instantiateViewController(identifier: "GameScene")
            self.gameScene.parentVC = self
            let gameDatas:NSDictionary = self.dat.object(forKey: "loadGame") as! NSDictionary
            self.gameScene.currentGameData = (gameDatas.object(forKey: stageName) as! NSDictionary)
            if stageName == "moveMap" {
                self.gameScene.isMapMove = true;
                print("!! moveMap detected");
            }
            self.perform(#selector(self.loadGameScene), with: nil, afterDelay: 0.5);
            //
        }
        //
    }
    
    
    /// saves current Game Data
    func saveGameData() {
        
        print(" ...... SAVE GAME DATA ..... ")
        
        // save
        let saveFunc = UserDefaults.standard
        saveFunc.setValue(tempPlayerData, forKey: "saveData")
        saveFunc.synchronize()
        // reload
        tempPlayerData = saveFunc.dictionary(forKey: "saveData")
        
        print("SAVEDData -> \(String(describing: tempPlayerData))")
        
    }
    
    func readSaveData() {
        let saveFunc = UserDefaults.standard
        tempPlayerData = saveFunc.dictionary(forKey: "saveData")
        print("READ SaveData -> \(String(describing: tempPlayerData))")
    }
    
    func setGameStage(stageName: String) {
        // Forcibly Set to specified <stageName> Game Stage
        tempPlayerData["gameProgress"] = stageName
        print("setGameStage -> \(String(describing: tempPlayerData["gameProgress"]))")
        saveGameData()
    }
    
    
    /// setOverworldProgress saves specific node name, and will hide
    func setOverworldProgress(key: String) {
        
        var currentOWProg = tempPlayerData["overworld_progress"] as? [String]
        
        // if nil, create new
        if currentOWProg == nil {
            currentOWProg = [String]()  // create new if nil
        }
        
        if currentOWProg?.contains(key) == false {
            currentOWProg?.append(key)      // add to existing overworld_progress
        }
        
        // replace data
        tempPlayerData["overworld_progress"] = currentOWProg
        
        print("overworld_progress -> \(String(describing: currentOWProg))")
        
    }
    
    /// gameProgressOf(key: String) will return key. If empty, it will automatically add new key.
    func gameProgressOf(key: String) -> Any? {
        
        // get progress_key or create new if non
        var existingProgKeys = self.tempPlayerData["progress_keys"] as? [String:Any] ?? [String:Any]()
        
        // if progress_keys data was empty, add
        if tempPlayerData["progress_keys"] == nil {
            tempPlayerData["progress_keys"] = existingProgKeys
        }
        
        // in the progress key, get from existing, or create new
        return existingProgKeys[key]
    }
    
    func setGameProgressOf(key:String, data:Any) {
        
        var existingProgKeys = self.tempPlayerData["progress_keys"] as? [String:Any] ?? [String:Any]()
        // set Data
        existingProgKeys[key] = data
        // update
        self.tempPlayerData["progress_keys"] = existingProgKeys
        print("setGameProg key:\(key) data:\(data) existing:\(existingProgKeys) tempData:\(tempPlayerData["progress_keys"])")
    }
    
    //
    //
    //
    
    func updateSaveData() {
        let saveFunc = UserDefaults.standard
        tempPlayerData = saveFunc.dictionary(forKey: "saveData")
        print("updateSaveDat - progress:\(tempPlayerData["overworld_progress"])")
    }
    
    @objc
    func loadGameScene() {
        self.present(gameScene, animated: true) {
            self.view.tag = 2; // open debug menu when game closed
        };
    }
    
    // SAVE DATA MANAGEMENT
    func system_loadSaveData() -> [String:Any] {
        
        let saveData = UserDefaults.standard.dictionary(forKey: "saveData")
        if let progress = saveData {
            return progress
        }
        
        return dat.object(forKey: "defaultPlayerData") as! [String:Any]
    }
    
    
    
    // AUDIO MANAGEMENT
    var introAudio:AVAudioPlayer?
    var loopAudio:AVAudioPlayer?
    
    //
    var environmentAudioIntro:AVAudioPlayer?
    var environmentAudioLoop:AVAudioPlayer?
    
    var bgmAudio:AVAudioPlayer?
    var bgmVolume:Float = 1.0
    var envVolume:Float = 1.0
    
    var currentBGMID:String?
    var currentENVID:String?
    
    //let maxVolume:Float = 0.5;
    
    /// changeBGM(bgmId: String!) will abruptly change music without checking if currently played music is same.
    func changeBGM(bgmId: String!) {
        
        introAudio?.setVolume(0.0, fadeDuration: 0.5)
        loopAudio?.setVolume(0.0, fadeDuration: 0.5)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
            self.playAudio(bgmId: bgmId)
        })
    }
    
    func changeBGM(bgmId: String!, duration: Double) {
        
        introAudio?.setVolume(0.0, fadeDuration: duration)
        loopAudio?.setVolume(0.0, fadeDuration: duration)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1, execute: {
            self.playAudio(bgmId: bgmId)
        })
    }
    
    func fadeToBGM(bgmId: String?, duration: Double, volume: Float) {
        
        print("FadeToBGM called inputVol:\(volume) bgmId:\(bgmId ?? "non") currentBGMID:\(currentBGMID ?? "non")")
        
        if bgmId == nil {
            return
        }
        
        if volume <= 0.1 {
            currentBGMID = nil;
        }
        
        if introAudio!.volume < 0.1 || loopAudio!.volume < 0.1 {
            currentBGMID = nil;
        }
        
        // check if already same bgm
        if bgmId == currentBGMID {
            print("same bgm detected")
            return
        }
        if bgmId == "" {
            print("detected blank bgmID")
            return
        }
        
        currentBGMID = bgmId // update to current BGM
        
        if volume <= 0.5 {
            bgmVolume = volume
        } else {
            bgmVolume = 0.5
        }
        
        introAudio?.setVolume(0.0, fadeDuration: duration)
        loopAudio?.setVolume(0.0, fadeDuration: duration)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1, execute: {
            
            //
            if bgmId != nil {
                // next song is ready
                if volume == 0 {
                    self.introAudio?.stop()
                    self.loopAudio?.stop()
                }
                self.playAudio(bgmId: bgmId)
            } else {
                // no next song
            }
            //
            //
        })
        
    }
    
    func fadeBGM(toVolume: Float, duration: Double) {
        
        if toVolume <= 0.1 {
            //currentBGMID = nil;
        }
        
        if toVolume <= 0.5 {
            bgmVolume = toVolume
        } else {
            bgmVolume = 0.5
        }
        
        let volume:Float = bgmVolume
        
        introAudio?.setVolume(volume, fadeDuration: duration)
        loopAudio?.setVolume(volume, fadeDuration: duration)
        
    }
    
    func playAudio(bgmId: String!) {
                
        let volume:Float = 0.5;
        bgmVolume = volume
        
        let audioFile = dat.object(forKey: "bgm") as? NSDictionary
        let audioDirectory = audioFile?.object(forKey: bgmId!) as? String
        let adFnc = audioDirectory?.components(separatedBy: "/")
        
        let path1 = Bundle.main.path(forResource: "ListenedGameAssets.scnassets/bgm/\(adFnc![0]).mp3", ofType: nil)
        let path2 = Bundle.main.path(forResource: "ListenedGameAssets.scnassets/bgm/\(adFnc![1]).mp3", ofType: nil)
        
        let url1 = URL(fileURLWithPath: path1!)
        let url2 = URL(fileURLWithPath: path2!)
        
        print("PlayBGM <bgmVol:\(bgmVolume)> Vol:\(volume) File:\([adFnc?.first]) path \(String(describing: path1))")
        
        // Setup AVAudioPlayer
        try! introAudio = AVAudioPlayer(contentsOf: url1)
        try! loopAudio = AVAudioPlayer(contentsOf: url2)
        
        introAudio?.stop()
        loopAudio?.stop()
        introAudio?.prepareToPlay()
        loopAudio?.prepareToPlay()
        //
        introAudio?.setVolume(volume, fadeDuration: 0.0)
        loopAudio?.setVolume(0.0, fadeDuration: 0.0)
        loopAudio?.numberOfLoops = -1
        //
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
            
            self.loopAudio?.play()
            self.introAudio?.play()
            self.loopAudio?.stop()
            self.loopAudio?.play(atTime: self.loopAudio!.deviceCurrentTime + self.introAudio!.duration)
            self.loopAudio?.setVolume(volume, fadeDuration: 0.0)
            
        })
    }
    
    
    
    func fadeToENV(bgmId: String?, duration: Double, volume: Float) {
        
        print("FadeToENV called inputVol:\(volume) bgmId:\(bgmId ?? "non") currentBGMID:\(currentENVID ?? "non")")
        
        if bgmId == nil {
            return
        }
        
        if bgmId == "" {
            print("detected blank envID")
            return
        }
                
        if volume <= 0.5 {
            envVolume = volume
        } else {
            envVolume = 0.5
        }
        
        environmentAudioIntro?.setVolume(0.0, fadeDuration: duration)
        environmentAudioLoop?.setVolume(0.0, fadeDuration: duration)
        
        // check if already same bgm. only control fade
        if bgmId == currentENVID {
            print("same ENV detected")
            return
        }
        
        currentENVID = bgmId // update to current BGM
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1, execute: {
            
            if volume <= 0.1 {
                // only set currentENVID to nil, after fading the sound to silence
                self.currentENVID = nil;
            }
            
            if bgmId != nil {
                // next song is ready
                if volume == 0 {
                    self.environmentAudioIntro?.stop()
                    self.environmentAudioLoop?.stop()
                }
                self.playEnvironmentAudio(bgmId: bgmId)
            }
        })
        
    }

    
    func fadeENV(toVolume: Float, duration: Double) {
        
        if currentENVID == nil {
            // do not fade out if event id is already nil, chances are the env might faded out already.
            return
        }
        
        if toVolume <= 0.1 {
            currentENVID = nil;
        }
        
        if toVolume <= 0.5 {
            envVolume = toVolume
        } else {
            envVolume = 0.5
        }
        
        let volume:Float = envVolume
        
        environmentAudioIntro?.setVolume(volume, fadeDuration: duration)
        environmentAudioLoop?.setVolume(volume, fadeDuration: duration)
        
    }
    
    func playEnvironmentAudio(bgmId: String!) {
        let volume:Float = 0.5;
        envVolume = volume
        
        let audioFile = dat.object(forKey: "bgm") as? NSDictionary
        let audioDirectory = audioFile?.object(forKey: bgmId!) as? String
        let adFnc = audioDirectory?.components(separatedBy: "/")
        
        let path1 = Bundle.main.path(forResource: "ListenedGameAssets.scnassets/bgm/\(adFnc![0]).mp3", ofType: nil)
        let path2 = Bundle.main.path(forResource: "ListenedGameAssets.scnassets/bgm/\(adFnc![1]).mp3", ofType: nil)
        
        let url1 = URL(fileURLWithPath: path1!)
        let url2 = URL(fileURLWithPath: path2!)
        
        print("PlayENV <envVol:\(envVolume)> Vol:\(volume) File:\([adFnc?.first]) path \(String(describing: path1))")
        
        // Setup AVAudioPlayer
        try! environmentAudioIntro = AVAudioPlayer(contentsOf: url1)
        try! environmentAudioLoop = AVAudioPlayer(contentsOf: url2)
        
        environmentAudioIntro?.stop()
        environmentAudioLoop?.stop()
        environmentAudioIntro?.prepareToPlay()
        environmentAudioLoop?.prepareToPlay()
        //
        environmentAudioIntro?.setVolume(volume, fadeDuration: 0.0)
        environmentAudioLoop?.setVolume(0.0, fadeDuration: 0.0)
        environmentAudioLoop?.numberOfLoops = -1
        //
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
            
            self.environmentAudioLoop?.play()
            self.environmentAudioIntro?.play()
            self.environmentAudioLoop?.stop()
            self.environmentAudioLoop?.play(atTime: self.environmentAudioLoop!.deviceCurrentTime + self.environmentAudioIntro!.duration)
            self.environmentAudioLoop?.setVolume(volume, fadeDuration: 0.0)
            
        })
    }
    
    
    
    
    
    
    
    
    func playSound(fileName:String?, fileExtension:String?, volume:Float) {
        
        if let fn = fileName {
            if let fe = fileExtension {
                let path1 = Bundle.main.path(forResource: "ListenedGameAssets.scnassets/bgm/\(fn).\(fe)", ofType: nil)
                let url1 = URL(fileURLWithPath: path1!)
                try! bgmAudio = AVAudioPlayer(contentsOf: url1)
                bgmAudio!.play()
            }
        }
        
    }
    
    // OTHER METHODS
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .all
    }
    
}

