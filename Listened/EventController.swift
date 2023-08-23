//
//  EventController.swift
//  AdvGame
//
//  Created by Koji Murata on 7/10/20.
//

import Foundation
import SceneKit
import SpriteKit
import AVFoundation
import CoreImage

class ADVTextInputController: UIViewController {
    
    @IBOutlet var lineDisplay: UILabel!
    @IBOutlet var textInput: UITextField!
    weak var parentVC:EventController?
    var promptDataObj: NSDictionary?
    var answerString: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let lang = Locale.preferredLanguages.first
        if lang?.hasPrefix("ja") == true {
            lineDisplay.text = promptDataObj!.object(forKey: "lineJA") as? String
        } else {
            lineDisplay.text = promptDataObj!.object(forKey: "line") as? String
        }
        
        answerString = promptDataObj!.object(forKey: "answer") as? String
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // focus to keyboard
        self.focusTextField()
        
    }
    
    func focusTextField() {
        textInput.becomeFirstResponder()
    }
    
    @objc
    @IBAction func confirmAction(_ sender: Any?) {
        //
        self.dismiss(animated: true) {
            if let str = self.answerString {
                if self.textInput.text == str {
                    let sEvnt = self.promptDataObj!.object(forKey: "successEvnt") as? String
                    self.parentVC?.textPromptDidEnter(succeedingEvent: sEvnt)
                } else {
                    self.parentVC?.textPromptDidEnter(succeedingEvent: nil)
                }
            }
        }
        //
    }
    
}



class EventController: UIViewController {
    
    @IBOutlet var removableItems: [Any]!
    
    @IBOutlet var textAreaBG: UIImageView!
    @IBOutlet var lineDisplay: UILabel!
    @IBOutlet var centerLineDisplay: UILabel!
    @IBOutlet var nextBtn: UIButton!
    
    // on screen view
    @IBOutlet var tapEllipse: UIImageView!
    @IBOutlet var tapEllipseCenter: UIImageView!
    @IBOutlet var centerImageDispay: UIImageView! // displays image in the center of the screen. can be used for showing sprites
    
    // quiz view
    @IBOutlet var mutipleChoiceView: UIView!
    @IBOutlet var choiceBtns: [UIButton]!
    
    // narrate related area
    @IBOutlet var narrateTextAreaBG: [Any]!
    @IBOutlet var narratorName: UILabel!
    
    var currentNarrator:String?
    var currentNarratorID:String?
    var speakingNpcName:String?
    
    // text related functions
    var tCtr = 0
    var textTimer:Timer?
    var currentLineText:String?
    var defaultTextFont:UIFont?
    
    // Controlls Event using a dialog module
    var currentEvent:Array<Any>?
    var eventPointer:Int = 0; // Always start from 0
    var inputText:String?; // used for text input quizes
    
    weak var gameScene:GameScene?
    weak var sceneFunctions:AdvShader?
    
    var sceneFilter:CIFilter?
    var lineReadAction:SKAction?
    
    var isInEvent:Bool = false
    var eventSoundPlayer:AVAudioPlayer?
    var areaTitle:String?
    
    let noiseTex = UIImage(named: "ListenedGameAssets.scnassets/noiseTexture.jpg")
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        // this view will load as soon as GameScene is loaded
        self.view.backgroundColor = UIColor.clear
        for item in removableItems {
            if item is UIView {
                (item as! UIView).removeFromSuperview()
            }
        }
        defaultTextFont = lineDisplay.font
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(true)
        isInEvent = false
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        print("EventController is displayed")
        isInEvent = true
        // setup pulse animation
        if tapEllipse.tag == 0 {
            tapEllipse.tag = 1
            tapEllipse.layer.compositingFilter = CIFilter(name: "CIAdditionCompositing")
            tapEllipse.layer.add((gameScene?.shaders.pulseAnim())!, forKey: "pulse")
            tapEllipse.isHidden = true
        } // setup pulse animation
        if tapEllipseCenter.tag == 0 {
            tapEllipseCenter.tag = 1
            tapEllipseCenter.layer.compositingFilter = CIFilter(name: "CIAdditionCompositing")
            tapEllipseCenter.layer.add((gameScene?.shaders.pulseAnim())!, forKey: "pulse")
            tapEllipseCenter.isHidden = true
        }
        
        for bg in narrateTextAreaBG {
            if bg is UIImageView {
                (bg as! UIImageView).isHidden = true
            }
        }
        
        // Set narrator -> dialog mode
        narratorName.isHidden = true
        lineDisplay.textColor = UIColor.white
        
        
    }
    
    //
    func setDefaultSceneBlocking() {
        
        // default items functions
        
        // default enemy functions
        
    }
    
    // Quiz Battle Scene
    
    // save default paramenters
    var lastPosition: SCNVector3?
    var lastEulerAngle: SCNVector3?
    var lastAudio: String?
    var lastZoom: CGFloat?
    var quizCounter = 0
    var maxNumberOfQuiz = 0
    
    var currentEnemyNode: NPCNode?
    var currentCompanionNode: NPCNode?
    
    var currentEnemyDat: NSDictionary?
    var playerAnswerChoiceTitle: String?
    var btlCamTimer:Timer?
    var btlTimerCtr = 0
    var recurringEvent: String?
    var failedPositionWarpTo: String?
    var failedEvent: String?
    var quizSuccess = false
    //
    // --
    func lookAt(node:String) -> SCNLookAtConstraint {
        let lookAt = SCNLookAtConstraint(target: self.gameScene?.node(name: node))
        lookAt.isGimbalLockEnabled = true
        lookAt.influenceFactor = 0.75
        return lookAt
    }
    
    // ---- Battle Scene VFX
    var vfx1:SCNAction?
    var vfx2:SCNAction?
    var vfx3:SCNAction?
    var vfx4:SCNAction?
    var vfx5:SCNAction?
    var vfx6:SCNAction?
    var vfx7:SCNAction?
    
    func initializeVFXNodes() {
        let ring = gameScene?.node(name: "enemySpark1-a")
        ring?.opacity = 0.0
        ring?.scale = SCNVector3Make(0.1, 0.1, 0.1)
        ring?.isHidden = false
        
        let ringInner1 = gameScene?.node(name: "enemySpark1-b")
        ringInner1?.opacity = 0.0
        ringInner1?.scale = SCNVector3Make(0.1, 0.1, 0.1)
        ringInner1?.isHidden = false
        
        let ringInner2 = gameScene?.node(name: "enemySpark1-c")
        ringInner2?.opacity = 0.0
        ringInner2?.scale = SCNVector3Zero
        ringInner2?.isHidden = false
        
        let shineLine = gameScene?.node(name: "enemySpark1-shineLine")
        shineLine?.opacity = 0.0
        shineLine?.isHidden = false
        
        let bgSpark = gameScene?.node(name: "uvMoveObj-yUV-1-bgSpark")
        bgSpark?.opacity = 0.0
        bgSpark?.isHidden = false
        
        let dissolveSpark = gameScene?.node(name: "uvMoveObj-yUV-1-dissolveSpark")
        dissolveSpark?.opacity = 0.0
        dissolveSpark?.isHidden = false
        
        let enemySpark2 = gameScene?.node(name: "uvMoveObj-yUV-2-enemySpark2")
        enemySpark2?.opacity = 0.0
        enemySpark2?.scale = SCNVector3Make(2, 2, 2)
        enemySpark2?.isHidden = false
        
        // set initial position
        let mainAxis = gameScene?.node(name: "vfx-axisPos")
        let enemyPos = gameScene?.node(name: "battleField-enemyPos")
        mainAxis?.position = enemyPos!.worldPosition
        
        // Prepare VFX SCNAction
        if vfx1 == nil {
            vfx1 = SCNAction.run({ node in
                
                // Timeline:A
                let fadeIn = SCNAction.fadeOpacity(to: 1.0, duration: 0.157)
                let fadeout = SCNAction.fadeOpacity(to: 0.0, duration: 0.336)
                let wait = SCNAction.wait(duration: 0.642)
                let fadeIn2 = SCNAction.fadeOpacity(to: 1.0, duration: 0.308)
                let fadeOut2 = SCNAction.fadeOpacity(to: 0.0, duration: 0.362)
                let fadeIn3 = SCNAction.fadeOpacity(to: 1.0, duration: 0.068)
                let wait2 = SCNAction.wait(duration: 0.143)
                let fadeOut3 = SCNAction.fadeOpacity(to: 0.0, duration: 0.049)
                
                let seq_a = SCNAction.sequence([fadeIn, fadeout, wait, fadeIn2, fadeOut2, fadeIn3, wait2, fadeOut3])
                
                // Timeline:B
                let scale = SCNAction.scale(to: 3.0, duration: 0.495)
                let wait_b = SCNAction.wait(duration: 0.791)
                let scale2 = SCNAction.scale(to: 0.1, duration: 0.519)
                let scale3 = SCNAction.scale(to: 3.0, duration: 0.26)
                
                let seq_b = SCNAction.sequence([scale, wait_b, scale2, scale3])
                
                node.runAction(SCNAction.group([seq_a, seq_b]))
                
            })
        }
        if vfx2 == nil {
            vfx2 = SCNAction.run({ node in
                
                // Timeline:A
                let waita1 = SCNAction.wait(duration: 0.091)
                let scale1 = SCNAction.scale(to: 4.0, duration: 0.605)
                let seq_a = SCNAction.sequence([waita1, scale1])
                
                // Timeline:B
                let waitb1 = SCNAction.wait(duration: 0.091)
                let fade1 = SCNAction.fadeOpacity(to: 1.0, duration: 0.095)
                let waitb2 = SCNAction.wait(duration: 0.226)
                let fade2 = SCNAction.fadeOpacity(to: 0.0, duration: 0.346)
                let seq_b = SCNAction.sequence([waitb1, fade1, waitb2, fade2])
                
                node.runAction(SCNAction.group([seq_a, seq_b]))
                
            })
        }
        if vfx3 == nil {
            vfx3 = SCNAction.run({ node in
                
                // Timeline:A
                let waita1 = SCNAction.wait(duration: 0.178)
                let scale1 = SCNAction.scale(to: 5.0, duration: 0.621)
                let seq_a = SCNAction.sequence([waita1, scale1])
                
                // Timeline:B
                let waitb1 = SCNAction.wait(duration: 0.178)
                let fade1 = SCNAction.fadeOpacity(to: 1.0, duration: 0.182)
                let waitb2 = SCNAction.wait(duration: 0.061)
                let fade2 = SCNAction.fadeOpacity(to: 0.0, duration: 0.379)
                let seq_b = SCNAction.sequence([waitb1, fade1, waitb2, fade2])
                
                node.runAction(SCNAction.group([seq_a, seq_b]))
                
            })
        }
        if vfx4 == nil {
            vfx4 = SCNAction.run({ node in
                
                // Timeline:A
                let waita1 = SCNAction.wait(duration: 0.25)
                let fade1 = SCNAction.fadeOpacity(to: 0.5, duration: 0.937)
                //1.187
                let waita2 = SCNAction.wait(duration: 1.577-1.187)
                let fade2 = SCNAction.fadeOpacity(to: 0.0, duration: 0.225)
                
                node.runAction(SCNAction.sequence([waita1, fade1, waita2, fade2]))
            })
        }
        if vfx5 == nil {
            vfx5 = SCNAction.run({ node in
                
                // Timeline:A
                let waita1 = SCNAction.wait(duration: 0.235)
                let fade1 = SCNAction.fadeOpacity(to: 1.0, duration: 0.558)
                //0.793
                let waita2 = SCNAction.wait(duration: 0.981-0.793)
                let fade2 = SCNAction.fadeOpacity(to: 0.0, duration: 0.462)
                
                node.runAction(SCNAction.sequence([waita1, fade1, waita2, fade2]))
            })
        }
        if vfx6 == nil {
            vfx6 = SCNAction.run({ node in
                
                // Timeline:A
                let waita1 = SCNAction.wait(duration: 0.472)
                let fade1 = SCNAction.fadeOpacity(to: 1.0, duration: 0.414)
                let progdur = waita1.duration+fade1.duration
                //0.793
                let waita2 = SCNAction.wait(duration: 1.082-progdur)
                let fade2 = SCNAction.fadeOpacity(to: 0.0, duration: 0.277)
                
                node.runAction(SCNAction.sequence([waita1, fade1, waita2, fade2]))
            })
        }
        if vfx7 == nil {
            vfx7 = SCNAction.run({ node in
                
                // Timeline:A
                let waita1 = SCNAction.wait(duration: 0.7)
                let fade1 = SCNAction.fadeOpacity(to: 1.0, duration: 0.555)
                let progdur = waita1.duration+fade1.duration
                let waita2 = SCNAction.wait(duration: 1.365-progdur)
                let fade2 = SCNAction.fadeOpacity(to: 0.0, duration: 0.269)
                let seq_a = SCNAction.sequence([waita1, fade1, waita2, fade2])
                
                // Timeline:B
                let waitb1 = SCNAction.wait(duration: 1.365)
                let scale1 = SCNAction.scale(to: 0.5, duration: 0.269)
                let seq_b = SCNAction.sequence([waitb1,scale1])
                
                node.runAction(SCNAction.sequence([seq_a, seq_b]))
            })
        }
    }
    
    // dissolve enemy VFX
    func dissolveEnemyVFX() {
        
        // fully set position
        let enemyPos = gameScene?.node(name: "battleField-enemyPos")
        
        let mainAxis = gameScene?.node(name: "vfx-axisPos")
        mainAxis?.position = (currentEnemyNode?.realWorldPosition())!
        
        
        let ring = gameScene?.node(name: "enemySpark1-a")
        ring?.runAction(vfx1!)
        
        let ringInner1 = gameScene?.node(name: "enemySpark1-b")
        ringInner1?.runAction(vfx2!)
        
        let ringInner2 = gameScene?.node(name: "enemySpark1-c")
        ringInner2?.runAction(vfx3!)
        
        let shineLine = gameScene?.node(name: "enemySpark1-shineLine")
        shineLine?.runAction(vfx4!)
        
        let bgSpark = gameScene?.node(name: "uvMoveObj-yUV-1-bgSpark")
        bgSpark?.runAction(vfx5!)
        
        let dissolveSpark = gameScene?.node(name: "uvMoveObj-yUV-1-dissolveSpark")
        dissolveSpark?.runAction(vfx6!)
        
        let enemySpark2 = gameScene?.node(name: "uvMoveObj-yUV-2-enemySpark2")
        enemySpark2?.runAction(vfx7!)
        
    }
    
    // dissolve items
    func dissolveNode(aNode: SCNNode, duration: CFTimeInterval?) {
        //
        let revealAnimation = CABasicAnimation(keyPath: "revealage")
        revealAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        revealAnimation.duration = duration ?? 2.5
        revealAnimation.fromValue = 1.0
        revealAnimation.toValue = 0.0
        revealAnimation.isRemovedOnCompletion = false
        //
        if aNode.geometry != nil {
            for mat in aNode.geometry!.materials  {
                
                mat.setValue(SCNMaterialProperty(contents: noiseTex!), forKey: "noiseTexture");
                mat.setValue(Float(1.0), forKey: "revealage");
                let modifierString = self.gameScene!.loadTxt(fileName: "dissolve-fragment");
                mat.shaderModifiers = [
                    SCNShaderModifierEntryPoint.fragment : modifierString
                ]
                mat.addAnimation(revealAnimation, forKey: "reveal")
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + duration!) {
                    aNode.isHidden = true
                    aNode.removeAllAnimations()
                }
            }
        }
    }
    
    // ----
    
    
    func begin_camSeq() {
        
        self.btlTimerCtr = 0;
        
        let btlCamAxis = self.gameScene?.node(name: "battleFieldCenterCamAxis") // spin forever
        btlCamAxis?.eulerAngles.y = (self.gameScene?.shaders.radians(degrees: 0))!
        btlCamAxis?.removeAllActions()
        
        let action = SCNAction.rotateBy(x: 0, y: -1, z: 0, duration: 5.0)
        btlCamAxis?.runAction(SCNAction.repeatForever(action))
        
        // setup camera constraints
        let lookPlyrNode = lookAt(node: (gameScene?.player.head?.name)!)
        self.gameScene?.node(name: "BFC-PlyrCam-0").constraints = [lookPlyrNode]
        
        btlCamTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { timer in
            
            if self.btlTimerCtr == 1 && timer.isValid == true {
                self.gameScene?.sceneView.pointOfView = self.gameScene?.node(name: "BFC-far")
            }
            if self.btlTimerCtr == 6 && timer.isValid == true  {
                self.gameScene?.sceneView.pointOfView = self.gameScene?.node(name: "BFC-std2")
            }
            if self.btlTimerCtr == 12 && timer.isValid == true  {
                self.gameScene?.sceneView.pointOfView = self.gameScene?.node(name: "BFC-far2")
            }
            if self.btlTimerCtr == 16 && timer.isValid == true  {
                self.gameScene?.sceneView.pointOfView = self.gameScene?.node(name: "BFC-std")
            }
            if self.btlTimerCtr == 21 && timer.isValid == true  {
                self.gameScene?.sceneView.pointOfView = self.gameScene?.node(name: "BFC-Plyr2Enm")
            }
            if self.btlTimerCtr == 23 && timer.isValid == true  {
                self.gameScene?.sceneView.pointOfView = self.gameScene?.node(name: "BFC-Enm2Plyr")
            }
            if self.btlTimerCtr == 26 && timer.isValid == true  {
                self.gameScene?.sceneView.pointOfView = self.gameScene?.node(name: "BF-Cam0")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.gameScene?.setCamera(cameraNodeName: "BF-Cam0-zoom", duration: 0.7)
                }
            }
            if self.btlTimerCtr == 28 && timer.isValid == true  {
                self.gameScene?.sceneView.pointOfView = self.gameScene?.node(name: "BFC-PlyrCam-0")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.gameScene?.setCamera(cameraNodeName: "BFC-PlyrCam-0-zoom", duration: 0.7)
                }
            }
            
            
            if self.btlTimerCtr == 30 {
                self.btlTimerCtr = 0;
            }
            self.btlTimerCtr += 1;
        })
        btlCamTimer!.fire()
        
    }
        
    func encounter(enemyID:String) {
        
        currentEnemyDat = ((self.gameScene?.parentVC?.dat.object(forKey: "quizEnemy") as! NSDictionary).object(forKey: enemyID) as! NSDictionary)
        
        // save preEncounter Data
        lastPosition = gameScene?.player.realWorldPosition()
        lastEulerAngle = gameScene?.player.eulerAngles
        lastAudio = gameScene?.parentVC?.currentBGMID
        lastZoom = gameScene?.sceneView.pointOfView?.camera!.fieldOfView
        maxNumberOfQuiz = (currentEnemyDat?.object(forKey: "quizes") as! Array<Any>).count
        failedPositionWarpTo = currentEnemyDat?.object(forKey: "failedEvnt") as? String
        recurringEvent = currentEnemyDat?.object(forKey: "successEvnt") as? String
        quizSuccess = false
        print("encountered - numberOfQuiz\(maxNumberOfQuiz) contents \(String(describing: currentEnemyDat))")
        
        // set enemyPosition
        let enemyNodeName = currentEnemyNode!.name!
        let enemyDispName = ((gameScene?.parentVC?.dat.object(forKey: "characterProfile") as? NSDictionary)?.object(forKey: currentEnemyNode?.name! as Any) as? NSDictionary)?.object(forKey: "displayName") as? String
        
        
        
        initializeVFXNodes()
        
        // set battleField : battleScene
        // hide other battle fields
        gameScene?.sceneView.scene?.rootNode.enumerateChildNodes({ (node, nil) in
            if let nodeName = node.name {
                if nodeName.contains("World-battleFieldScene") {
                    node.isHidden = true
                }
            }
        })
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        let bf_ParentNodeName = gameScene?.mapProfile?.object(forKey: "battleScene") as? String ?? "World-battleFieldScene01"
        let bf_parentNode = gameScene?.node(name: bf_ParentNodeName)
        let btl_CamAxis = gameScene?.node(name: "bF_mainCamAxis")
        btl_CamAxis?.position = (bf_parentNode?.position)!
        bf_parentNode?.isHidden = false
        SCNTransaction.commit()
        
        //currentEnemyNode?.constraints = [self.lookAt(node: gameScene!.player.name!)]
        self.gameScene?.frontNode = currentEnemyNode?.neck
        
        print("currentEnemyNode \(String(describing: currentEnemyNode))")
        
        lineDisplay.text = ""
        nextBtn.isEnabled = false;
        eventPointer = 0
        quizCounter = 0
        
        // Check if this specific player has anything to do prior to battle
        let priorCustomEvents = currentEnemyDat?.object(forKey: "customEvents") as? Array<NSDictionary>
        
        let audio = currentEnemyDat?.object(forKey: "ost") as? String ?? "pmkBattle"
        
        let battleSceneArray: Array<Any> = [
            [//0
                "BGM": "\(audio)", // start bgm immediately
                "autoTapAfter": "0.2"
            ],
            [//1
                "encouterFX": "",  // effects denoting the start of a quiz session
                "autoTapAfter": "3.0"
            ],
            [//2
                "camera":"BF-Cam0",
                "npcFunction":[//Array
                    [//Dic
                        "overrideAnimation":"charge",
                        "position":"battleField-playerPos",
                        "face":"battleField-enemyPos"],
                    [//Dic
                        "delay":"0.1",
                        "face!":"battleField-enemyPos"]
                ],
                "autoTapAfter": "2.0" // This is where you can do some preparations
            ],
            [//3
                "fadeIn"    :   "1.0",
                "panCamera": [
                    "camera":"BF-Cam0-1",
                    "duration":"15"
                ],
                "autoTapAfter":"0.5"
            ],
            [//4
                "clearNarrator":"",
                "line":"\(enemyDispName ?? "$イベントNPC") is challenging you for a quiz battle!",
                "lineJA":"\(enemyDispName ?? "$イベントNPC") がクイズバトルであなたに勝負をしかけている",
                "autoTapAfter":"2.5"
            ],
            [//5
                "enterQuiz":enemyID
            ],
            [//6 Ending Sequence
                "blackOut":"0.4",
                "autoTapAfter":"0.5"
            ],
            [//7 Code What to End Here
                "defaultCamera":"",
                "autoTapAfter":"0.3",
                "npcFunction":[//Dictionary
                    "removeAllAnimations":""
                ]
            ],
            [//7 Code What to End Here
                "endBattleSeq"    :   "1.0", // add next event for succession
            ]
        ]
        
        // add customArray if there is
        
        // set array
        currentEvent = battleSceneArray
        
        if priorCustomEvents != nil {
            print("custom event found")
            currentEvent?.insert(contentsOf: priorCustomEvents!, at: 4)
        }
                
        if eventPointer < currentEvent!.count {
            self.runEvent()
        }
    }
    
    func qb_addQuizSeq(enemyId:String) {
        
        // start camera sequence
        if btlCamTimer == nil {
            begin_camSeq()
        } else {
            if let btlCTmr = btlCamTimer {
                if btlCTmr.isValid == false {
                    begin_camSeq()
                }
            }
        }
        
        // load quiz data
        let currentQuiz = (currentEnemyDat?.object(forKey: "quizes") as! Array<Any>)[quizCounter] as! NSDictionary
        var encodeAnswers = currentQuiz.object(forKey: "answers") as! Array<NSDictionary>
        let functions = currentQuiz.object(forKey: "func") as? Dictionary<String, Any>
        var enemyDispName = ((gameScene?.parentVC?.dat.object(forKey: "narrator") as? NSDictionary)?.object(forKey: currentEnemyNode?.name) as? NSDictionary)?.object(forKey: "displayName_EN") as? String
        
        // if JA
        let lang = UserDefaults.standard.string(forKey: "user_lang")
        if lang?.hasPrefix("JA") == true {
            enemyDispName = ((gameScene?.parentVC?.dat.object(forKey: "narrator") as? NSDictionary)?.object(forKey: currentEnemyNode?.name) as? NSDictionary)?.object(forKey: "displayName_JA") as? String
        }
        
        encodeAnswers.shuffle()
        encodeAnswers.shuffle()
        
        let wholeQuizDat = currentEnemyDat?.object(forKey: "quizes") as? Array<Any>
        
        var questionDispText = "#!QUESTION \(quizCounter+1)"
        if wholeQuizDat!.count - 1 == quizCounter {
            questionDispText = "#!LAST QUESTION"
        }
        
        let questionJA = currentQuiz.object(forKey: "questionJA")
        let typeInQuiz = currentQuiz.object(forKey: "questionTypeIn") as? String
        
        var quizForm: Array<Dictionary<String,Any>> = [
            [ //0
                "sfx"       :   "drumHit.wav",
                "centerText":   questionDispText,
                "autoTapAfter": "1.7"
            ],
            [ //1
                "narrator"  :   "\(enemyDispName ?? "$イベントNPC")",
                "line"      :   currentQuiz.object(forKey: "question") as Any,
                "lineJA"      :   questionJA ?? currentQuiz.object(forKey: "question") as Any
            ],
            [ //2
                "questionFunc": encodeAnswers
            ]
        ]
        
        if typeInQuiz != nil {
            quizForm = [
                [ //0
                    "sfx"       :   "drumHit.wav",
                    "centerText":   questionDispText,
                    "autoTapAfter": "1.7"
                ],
                [ //1
                    "narrator"  :   "\(enemyDispName ?? "$イベントNPC")",
                    "line"      :   currentQuiz.object(forKey: "question") as Any
                ],
                [ //2
                    "questionFunc": encodeAnswers
                ]
            ]
        }
        
        // quiz insertion
        if functions != nil {
            var dic = quizForm[1]// copy from existing
            for (name, path) in functions! {
                dic[name] = path // Add key value to existing
            }
            // replace
            quizForm[1] = dic // implicitly replace
        }
        
        print("quizForm content \(quizForm)")
        
        quizCounter += 1;
        currentEvent?.insert(contentsOf: quizForm, at: eventPointer + 1)
        
    }
    
    func qb_addCorrectSeq() {
        
        let currentQuiz = (currentEnemyDat?.object(forKey: "quizes") as! Array<Any>)[quizCounter-1] as! NSDictionary
        let encodeAnswers = currentQuiz.object(forKey: "answers") as! Array<NSDictionary>
        var kaisetsu = "Correct..."
        var kaisetsuJA = "正解..."
        for theAns in encodeAnswers {
            let quizTitle = theAns.object(forKey: "title") as! String
            if quizTitle == playerAnswerChoiceTitle! {
                kaisetsu = theAns.object(forKey: "description") as! String
                kaisetsuJA = theAns.object(forKey: "descriptionJA") as? String ?? "正解..."
                break
            }
        }
        
        let seq: Array<Any> = [
            [
                "sfx"       :   "correct.mp3",
                "displayImage"       :   "ListenedGameAssets.scnassets/correctTex.png",
                "autoTapAfter":   "2.0"
            ],
            [
                "narrator"  :   "\(currentEnemyNode!.name!)",
                "line"      :   "\(kaisetsu)",
                "lineJA"      :   "\(kaisetsuJA)"
            ],
            [//5 try to repeat for next quiz || end session
                "enterQuiz":""
            ]
        ]
        //currentEvent?.insert(wrongSeq, at: eventPointer + 1)
        currentEvent?.insert(contentsOf: seq, at: eventPointer + 1)
    }
    
    func qb_addSuccessSeq() {
        
        let enemyNodeName = currentEnemyNode!.name!
        
        let enemyseq: Array<Any> = [
            [   // camera faces enemy for removal,
                "enableBattleCamera"    :    false,
                "camera"  :   "BF-Cam0-zoom",
                "dissolveEnemy": true,
                "npcFunction":[//Array
                    [//Dic
                        "npc":enemyNodeName,
                        "sfx":"enemyDissolve.mp3"
                    ]
                ],
                "autoTapAfter":   "3.2"
            ],
            [   // camera faces player,
                "enableBattleCamera"    :    false,
                "camera"  :   "BFC-PlyrCam-0",
                "fadeBGM"   :   "0.0/0.5",
                "autoTapAfter":   "0.4"
            ],
            [
                //Dictionary
                "npcFunction":[
                    "playPauseAnimation":"success",
                    "delay":"0.0"
                ],
                "sfx"      :   "cleared.mp3",
                "autoTapAfter":"2.5"
            ]
        ]
        let seq: Array<Any> = [
            [   // camera faces player,
                "enableBattleCamera"    :    false,
                "camera"  :   "BFC-PlyrCam-0",
                "fadeBGM"   :   "0.0/0.5",
                "autoTapAfter":   "1.5"
            ]
        ]
        
        if currentEnemyNode?.enemy == true {
            currentEvent?.insert(contentsOf: enemyseq, at: eventPointer + 1)
        } else {
            currentEvent?.insert(contentsOf: seq, at: eventPointer + 1)
        }
    }
    
    func qb_addWrongSeq() {
        // Failed
        let currentQuiz = (currentEnemyDat?.object(forKey: "quizes") as! Array<Any>)[quizCounter-1] as! NSDictionary
        let encodeAnswers = currentQuiz.object(forKey: "answers") as! Array<NSDictionary>
        var kaisetsu = ".........."
        var kaisetsuJA = ".........."
        for theAns in encodeAnswers {
            let quizTitle = theAns.object(forKey: "title") as! String
            if quizTitle == playerAnswerChoiceTitle! {
                kaisetsu = theAns.object(forKey: "description") as! String
                kaisetsuJA = theAns.object(forKey: "descriptionJA") as? String ?? ".........."
                break
            }
        }
        
        let seq: Array<Any> = [
            [
                "sfx"       :   "wrong.mp3",
                "displayImage"       :   "ListenedGameAssets.scnassets/wrongTex.png",
                "autoTapAfter":   "2.0"
            ],
            [
                "narrator"  :   "\(currentEnemyNode!.name!)",
                "enableBattleCamera"  :   false,
                "camera"  :   "BF-Cam0-1",
                "line"      :   "\(kaisetsu)",
                "lineJA"      :   "\(kaisetsuJA)"
            ],
            [
                "npcFunction":[//Dictionary
                    "playPauseAnimation":"toDie",
                    "delay":"0.3"
                ],
                "camera":"BFC-PlyrCam-0",
                "sfx":"kv-world1.mp3",
                "autoTapAfter":"2.0",
                "narrator"  :   "Kenny",
                "line"      :   "What in the world...",
                "lineJA"      :   "何と言うことでしょう..."
            ],
            [
                "blackOut"  :   "1.0",
                "fadeBGM"   :   "0.0/0.2",
                "sfx"      :   "gameOver.mp3",
                "autoTapAfter":"0.5"
            ],
            [
                "centerText": "Game over!",
                "centerTextJA": "ゲームオーバー!"
            ]
        ]
        
        currentEvent?.insert(contentsOf: seq, at: eventPointer + 1)
        
    }
    
    // fixed event pattern
    func add_barricadeRemovalEvent(barricadeId: String) {
        
        let seq: Array<Any> = [
            [
                "setInstantCam": "Zack",
                "autoTapAfter":   "1.0"
            ],
            [
                // must pan to the barricade (takes 2.0 secs)
                "panInstantCam"  :   "dtreewallbarricade-\(barricadeId)",
                "autoTapAfter"      :   "2.5"
            ],
            [
                // remove barricade
                "nodeFunction":[//Dictionary
                    "name":"dtreewallbarricade-\(barricadeId)",
                    "position":"dtreebarricadeBase-\(barricadeId)",
                    "duration":"5.3",
                    "sfx":"eQuake.mp3"
                ],
                "shudderCamera":"",
                "autoTapAfter":"4.0"
            ],
            [
                "sfx"      :   "mysteryRiff.mp3",
                "saveData"      :   true,
                "autoTapAfter":"1.0"
            ]
        ]
        
        currentEvent?.insert(contentsOf: seq, at: eventPointer + 1)
        
    }
    
    func talkToNpc(npcName: String) {
        
        print("talkToNpc")
        
        // reset tripod angle
        let fcuAxis = self.gameScene?.node(name: "fcuAxis")
        fcuAxis!.eulerAngles.y = 0 // reset angle of fcuAxis
        
        let seq: Array<Any> = [
            [
                "blackOut"       :   "0.9",
                "autoTapAfter"       :   "1.0"
            ],
            [
                "camera"       :   "npcTalkCam1",
                "autoTapAfter"       :   "1.0",
                "nodeFunction"              :   [
                    [
                        "name"      :   "fcuAxis",
                        "npcPosition"  :   "\(npcName)"
                    ]
                ],
                "npcFunction"              :   [
                    [
                        "position!"  :   "npcFcuAxisPos", //Kenny
                        "face!"      :   "\(npcName)", // face Klinnita
                        "delay"     :   "0.1"
                    ],
                    [
                        "npc"      :   "\(npcName)", // Klinnita
                        "face!"     :   "Zack",    // face
                        "delay"     :   "0.15"
                    ]
                ]
            ],
            [
                "fadeIn": "1.0",
                "autoTapAfter": "1.0"
            ]
        ]
        
        currentEvent?.insert(contentsOf: seq, at: eventPointer + 1)
        
        eventPointer = eventPointer + 1;
        if eventPointer < currentEvent!.count {
            self.runEvent()
        }
        
    }
    
    func zoomUpToNPC(npcName: String) {
        
        // tripod
        let fcuAxis = self.gameScene?.node(name: "fcuAxis")
        fcuAxis!.eulerAngles.y = 0 // reset angle of fcuAxis
        
        // person to close up
        let person = self.gameScene?.npc(owName: npcName)
        fcuAxis!.position = person!.worldPosition
        fcuAxis!.eulerAngles.y = person!.eulerAngles.y
        
        // setup camera
        let cam = self.gameScene?.node(name: "npcTalkCam2")
        cam?.position.y = (person?.head?.worldPosition.y)! + 0.1
        
        let seq: Array<Any> = [
            [
                "camera"       :   "npcTalkCam2",
                "autoTapAfter": "0.02"
            ]
        ]
        
        currentEvent?.insert(contentsOf: seq, at: eventPointer + 1)
        
        eventPointer = eventPointer + 1;
        if eventPointer < currentEvent!.count {
            self.runEvent()
        }
        
    }
    
    // textInput prompt management
    func textPromptDidEnter(succeedingEvent: String?) {
        
        var evnt = ""
        if let inputEvent = succeedingEvent {
            evnt = inputEvent
        }
        
        let negativeSeq: Array<Any> = [
            [
                "sfx"       :   "wrong.mp3",
                "displayImage"       :   "ListenedGameAssets.scnassets/wrongTex.png",
                "autoTapAfter":   "2.0"
            ],
            [
                "line": "My answer seems to be wrong..."
            ]
        ]
        let positiveSeq: Array<Any> = [
            [
                "sfx"       :   "correct.mp3",
                "displayImage"       :   "ListenedGameAssets.scnassets/correctTex.png",
                "autoTapAfter":   "2.0"
            ],
            [
                "jumpEvent": "\(evnt)"
            ]
        ]
        
        if succeedingEvent != nil {
            // player got it right
            currentEvent?.insert(contentsOf: positiveSeq, at: eventPointer + 1)
        }
        else {
            // wrong answer
            currentEvent?.insert(contentsOf: negativeSeq, at: eventPointer + 1)
        }
        
        eventPointer = eventPointer + 1;
        if eventPointer < currentEvent!.count {
            self.runEvent()
        }
        
    }
    
    @objc
    func runFieldEnemyEncounter(enemyNode:NPCNode) {
        
        currentEnemyNode = enemyNode
        
        // initial preparation
        lineDisplay.text = ""
        nextBtn.isEnabled = false;
        eventPointer = 0
        
        // loadEvent
        currentEvent = [//Array
            [// Dictionary
                "battleEncounter": enemyNode.npcIdentifier
            ],
        ]
        
        if currentEvent != nil {
            if eventPointer < currentEvent!.count {
                self.runEvent()
            }
        }
    }
    //
    //
    //
    func narrator(narratorID: String) -> String? {
        
        let dic = (self.gameScene?.parentVC?.dat.object(forKey: "narrator") as? NSDictionary)?.object(forKey: narratorID) as? NSDictionary
        let prefLang = UserDefaults.standard.string(forKey: "user_lang")
        
        if prefLang?.hasPrefix("JA") == true {
            return dic?.object(forKey: "displayName_JA") as? String
        }
        return dic?.object(forKey: "displayName_EN") as? String
    }
    
    func setNarrator(narratorID: String) {
        
        speakingNpcName = narratorID
        
        // fetch narrator name
        let narratorDic = self.gameScene?.parentVC?.dat.object(forKey: "narrator") as? NSDictionary
        let dispNameDic = narratorDic?.object(forKey: narratorID) as? NSDictionary
        currentNarratorID = dispNameDic?.object(forKey: "npc") as? String
        
        var narratorDisplayText:String? = "???"
        narratorDisplayText = narrator(narratorID: narratorID)
        
        if narratorDisplayText == nil || narratorDisplayText?.isEmpty == true || narratorDisplayText == "" {
            narratorDisplayText = narratorID
        }
        
        // get UI ready!
        narratorName.text = narratorDisplayText;
        for bg in narrateTextAreaBG {
            if bg is UIImageView {
                (bg as! UIImageView).isHidden = false
            }
        }
        narratorName.isHidden = false
        narratorName.textColor = UIColor.darkGray
        lineDisplay.textColor = UIColor.darkGray
    }
    
    func clearNarrator() {
        for bg in narrateTextAreaBG {
            if bg is UIImageView {
                (bg as! UIImageView).isHidden = true
            }
        }
        narratorName.isHidden = true
        lineDisplay.textColor = UIColor.white
        speakingNpcName = nil
    }
    
    func npcReadLineFunc(fileName: String) {
        
        // load line read file
        let player = self.loadLineSoundFile(name: fileName, isMp3: true)
        
        // load npc who will be talking
        player.play()
        
    }
    
    func event(eventId:String) -> Array<Any> {
        let path = Bundle.main.path(forResource: "gameDat", ofType: "plist");
        let dat = NSDictionary(contentsOfFile: path!)
        print("prepareEvent : eventId \(eventId)")
        return ((dat?.object(forKey: "gameEvent") as! NSDictionary) .object(forKey: eventId) as! Array<Any>)
    }
        
    //
    //
    //
    /// Entry point to start an event
    @objc
    func prepareEvent(event: String) {
        
        self.gameScene?.gameState = 2
        
        // initial preparation
        lineDisplay.text = ""
        nextBtn.isEnabled = false;
        eventPointer = 0
        
        // load event
        currentEvent = self.event(eventId: event)
        
        // read initial data
        let firstDat = currentEvent![0] as! NSDictionary // first check if this event allow dpadControls
        
        // Read progress data when assigned, to see if this condition is met
        if let cmd = firstDat.object(forKey: "loadProgress") {
            
            // 1. Read progress data first before running event.
            let readProgressDat = cmd as! NSDictionary
            
            // 2. prepare variables
            let currentKey = readProgressDat.object(forKey: "key") as! String
            let equalsToNumber = readProgressDat.object(forKey: "equalsToNumber") as? NSNumber
            var conditionMet:Bool = false
            let incompleteEvent = readProgressDat.object(forKey: "incompleteEvent") as! String
            let progressKeys = self.gameScene?.parentVC?.tempPlayerData["progress_keys"] as? [String:Any]
            
            // NSNumber comparison
            if equalsToNumber != nil {
                let valueInProgress = progressKeys![currentKey] as! NSNumber
                if valueInProgress == equalsToNumber! {
                    conditionMet = true
                }
            }
            
            if conditionMet == true {
                
                print("condition MET")
                // load next event
                eventPointer += 1
                
                // run event as usual
                if firstDat.object(forKey: "dpadAllow") == nil {
                    gameScene?.setNpcControls(allow: false)
                }
                if currentEvent != nil {
                    if eventPointer < currentEvent!.count {
                        self.runEvent()
                    }
                }
                
            } else {
                print("condition UNMET")
                self.prepareEvent(event: incompleteEvent)
            }
            
        } else {
            
            // run event as usual
            if firstDat.object(forKey: "dpadAllow") == nil {
                gameScene?.setNpcControls(allow: false)
            }
            if currentEvent != nil {
                if eventPointer < currentEvent!.count {
                    self.runEvent()
                }
            }
            
        }
        
    }
    //
    //
    //
    //
    
    func runEvent() {
        
        // Some event (i.e, Tutorials) does not require any text area to be shown. Thus, npc in GameScene.sceneView is still controllable)
        let currentDat = currentEvent![eventPointer] as! NSDictionary
        
        if currentDat.object(forKey: "readSaveData") != nil {
            self.gameScene?.parentVC?.readSaveData()
        }
        
        if currentDat.object(forKey: "saveData") != nil {
            self.gameScene?.parentVC?.saveGameData()
            self.gameScene?.sk?.showNotification(txt: "Saving Data...")
        }
        
        //
        // update Progress
        if let updateProgress = currentDat.object(forKey: "updateProgress") as? NSDictionary {
            self.gameScene?.progressData(cmd: updateProgress)
        }
        
        // update setting data (this will access UserDefaults directly)
        if let updateProgress = currentDat.object(forKey: "updateSetting") as? NSDictionary {
            let key = updateProgress.object(forKey: "key") as! String
            let data = updateProgress.object(forKey: "data")
            let saveData = UserDefaults.standard
            saveData.set(data, forKey: key)
            saveData.synchronize()
        }
        
        //
        //
        //
        
        if let cmd = currentDat.object(forKey: "enterQuiz") as? String {
            
            if quizCounter < maxNumberOfQuiz {
                self.qb_addQuizSeq(enemyId: cmd)
                self.perform(#selector(nextBtnTapped(_:)), with:nil, afterDelay: 1.0)
            } else {
                // end of quiz, - player success.
                failedPositionWarpTo = nil
                quizSuccess = true
                self.qb_addSuccessSeq()
                self.perform(#selector(nextBtnTapped(_:)), with:nil, afterDelay: 0.1)
            }
            return
        }
        
        if currentDat.object(forKey: "removeItemInfront") != nil {
            self.gameScene?.frontNode?.opacity = 0.0
            self.gameScene?.frontNode?.accessibilityLabel = nil
        }
        
        if currentDat.object(forKey: "dissolveEnemy") != nil {
            self.currentEnemyNode?.dissolvePlayer(duration: Double(2.5))
            self.dissolveEnemyVFX()
        }
        
        if (currentDat.object(forKey: "endBattleSeq") as? String) != nil {
            
            // last position
            self.gameScene?.player.goTo(pos: self.lastPosition!)
            // last rotation
            self.gameScene?.player.eulerAngles.y = self.lastEulerAngle!.y
            self.gameScene?.resetCamAxisPosition()
            print("RESET-CamAxisPosition player.pos\(String(describing: self.gameScene?.player.worldPosition)) camPos:\(String(describing: self.gameScene?.camAxis.worldPosition))")
            
            btlCamTimer?.invalidate()
            let btlCamAxis = self.gameScene?.node(name: "battleFieldCenterCamAxis")
            btlCamAxis?.removeAllActions()
            btlCamAxis?.rotation = SCNVector4Zero
            
            // QUIZ success
            if quizSuccess == true {
                
                // temporarily get enemy name
                let enemyAxisName = currentEnemyNode?.enemyAxis?.name
                
                // remove enemy from scene
                currentEnemyNode?.state = 99
                gameScene?.npcPlayers?.remove(currentEnemyNode!)
                currentEnemyNode?.removeFromParentNode()
                
                // Check if has recurring Event
                if recurringEvent != nil {
                    self.prepareEvent(event: recurringEvent!)
                    recurringEvent = nil
                    //
                } else {
                    // no recurring custom event
                    let barricadeName = enemyAxisName?.components(separatedBy: "-").last ?? "invalid"
                    
                    // barricade removal
                    if barricadeName.contains("barricade") == true {
                        add_barricadeRemovalEvent(barricadeId: barricadeName)
                        // removes this enemy indefinitely
                        self.gameScene?.parentVC?.setOverworldProgress(key: enemyAxisName!)
                        self.gameScene?.parentVC?.setOverworldProgress(key: "dtreewallbarricade-\(barricadeName)")
                    }
                    self.perform(#selector(nextBtnTapped(_:)), with:nil, afterDelay: 1.0)
                }
                
                currentEnemyNode = nil
                
            } else {
                
                self.dismiss(animated: false) {
                    self.gameScene?.repeatStage()
                }
                
                
            }
            
            return
            
        }
        
        if let cmd = currentDat.object(forKey: "enableBattleCamera") as? Bool {
            if cmd == true {
                begin_camSeq()
            } else if cmd == false {
                btlCamTimer?.invalidate()
                self.gameScene?.node(name: "battleFieldCenterCamAxis").removeAllActions()
            }
        }
        
        // Scene Controls
        if let cmd = currentDat.object(forKey: "blackOut") {
            let dur = Double(cmd as? String ?? "1.0") ?? 1.0
            self.gameScene?.view.backgroundColor = UIColor.black
            UIView.animate(withDuration:dur) {
                self.gameScene?.sceneView.alpha = 0.0
            }
        }
        
        if let cmd = currentDat.object(forKey: "whiteOut") {
            
            let dur = Double(cmd as? String ?? "1.0") ?? 1.0
            self.gameScene?.view.backgroundColor = UIColor.clear
            self.gameScene?.view.layer.backgroundColor = UIColor.white.cgColor
            UIView.animate(withDuration: dur, animations: {
                self.gameScene?.sceneView.alpha = 0.0
            }) { completed in
                UIView.animate(withDuration: dur, animations: {
                    self.gameScene?.view.layer.backgroundColor = UIColor.black.cgColor
                }) { completed in
                    
                }
            }
        }
        
        if currentDat.object(forKey: "encouterFX") != nil {
            
            // cg effect
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.2
            gameScene?.sceneView.pointOfView?.camera?.fieldOfView = lastZoom! * 0.65
            gameScene?.sceneView.pointOfView?.camera?.colorFringeStrength = 15.0
            gameScene?.sceneView.pointOfView?.camera?.colorFringeIntensity = 1.8
            SCNTransaction.commit()
            
            let dur = Double(0.15)
            self.gameScene?.view.backgroundColor = UIColor.clear
            self.gameScene?.view.layer.backgroundColor = UIColor.white.cgColor
            
            UIView.animate(withDuration: dur, animations: {
                self.gameScene?.sceneView.alpha = 0.5
            }) { completed in
                UIView.animate(withDuration: dur, animations: {
                    self.gameScene?.sceneView.alpha = 1.0
                }) { completed in
                    UIView.animate(withDuration: 0.5, animations: {
                        self.gameScene?.sceneView.alpha = 0.0 // DEBUG
                    }) { completed in
                        UIView.animate(withDuration: 1.0, animations: {
                            self.gameScene?.view.layer.backgroundColor = UIColor.black.cgColor
                        }) { completed in
                            
                            self.gameScene?.player.headTrack?.target = nil
                            
                            self.gameScene?.sceneView.pointOfView?.camera?.fieldOfView = self.lastZoom!
                            self.gameScene?.sceneView.pointOfView?.camera?.colorFringeStrength = 0.0
                            self.gameScene?.sceneView.pointOfView?.camera?.colorFringeIntensity = 1.0
                            
                            //
                            self.tapEllipseCenter.layer.removeAllAnimations()
                            self.tapEllipseCenter.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
                            self.tapEllipseCenter.alpha = 0.0
                            self.tapEllipseCenter.isHidden = false
                            
                            self.currentEnemyNode?.state = 3
                            
                            // set position
                            self.currentEnemyNode?.goTo(axis: (self.gameScene?.node(name: "battleField-enemyPos"))!)
                            // set rotation
                            self.currentEnemyNode?.rotation = SCNVector4Zero
                            
                            if self.currentCompanionNode != nil {
                                self.currentCompanionNode?.goTo(axis: (self.gameScene?.node(name: "battleField-companionPos"))!)
                                self.gameScene?.faceNPC(npc: self.currentCompanionNode!, toPosition: "battleField-enemyPos", animated: false)
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                UIView.animate(withDuration: 0.4) {
                                    self.tapEllipseCenter.transform = CGAffineTransform.init(scaleX: 20.0, y: 20.0)
                                    self.tapEllipseCenter.alpha = 1.0
                                } completion: { completed in
                                    self.tapEllipseCenter.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
                                    self.tapEllipseCenter.alpha = 0.0
                                    //
                                    UIView.animate(withDuration: 0.4) {
                                        self.tapEllipseCenter.transform = CGAffineTransform.init(scaleX: 20.0, y: 20.0)
                                        self.tapEllipseCenter.alpha = 1.0
                                    } completion: { completed in
                                        self.tapEllipseCenter.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
                                        self.tapEllipseCenter.alpha = 0.0
                                        
                                        //
                                        // This is where game state becomes "Encounter" from "Loading"
                                        self.gameScene?.gameState = 1
                                        //
                                        //
                                    }
                                }
                                //
                            }
                            
                        }
                    }
                }
            }
            
            //
        }
        
        if let cmd = currentDat.object(forKey: "whiteOutBriefly") {
            
            let dur = Double(cmd as? String ?? "0.5") ?? 0.5
            let calcDur = dur/2
            self.gameScene?.view.backgroundColor = UIColor.clear
            self.gameScene?.view.layer.backgroundColor = UIColor.white.cgColor
            UIView.animate(withDuration: calcDur, animations: {
                self.gameScene?.sceneView.alpha = 0.5
            }) { completed in
                UIView.animate(withDuration: calcDur, animations: {
                    self.gameScene?.sceneView.alpha = 1.0
                }) { completed in
                    self.gameScene?.view.layer.backgroundColor = UIColor.black.cgColor
                }
            }
        }
        
        if let cmd = currentDat.object(forKey: "fadeIn") {
            let dur = Double(cmd as? String ?? "1.0") ?? 0.0
            UIView.animate(withDuration:dur) {
                self.gameScene?.sceneView.alpha = 1.0
            }
        }
        
        /// on screen image display
        if var dispImg = currentDat.object(forKey: "displayImage") as? String {
            // check if directory is correct
            if dispImg.hasPrefix("ListenedGameAssets.scnassets/") == false {
                dispImg = "ListenedGameAssets.scnassets/" + dispImg
            }
            //
            centerImageDispay.alpha = 0.0
            centerImageDispay.isHidden = false
            centerImageDispay.image = UIImage(named: dispImg)
            // slightly fade in image
            UIView.animate(withDuration: 0.25) {
                self.centerImageDispay.alpha = 1.0
            }
            //
        } else if currentDat.object(forKey: "displayImageContinue") != nil {
            
        } else {
            if centerImageDispay.isHidden == false {
                UIView.animate(withDuration: 0.25) {
                    self.centerImageDispay.alpha = 0.0
                } completion: { completed in
                    self.centerImageDispay.isHidden = true
                }
            }
        }
        
        /// Camera Controls
        if currentDat.object(forKey: "defaultCamera") != nil {
            gameScene?.setCamera(cameraNodeName: (gameScene?.standardCamera.name)!, duration: 0.0)
        }
        if currentDat.object(forKey: "defaultCamera!") != nil {
            self.fadeToCam(cameraName: (gameScene?.standardCamera.name)!)
        }
        
        if let cmd = currentDat.object(forKey: "camera") {
            let cameraNodeName = cmd as! String
            print("Setting Camera \(cameraNodeName)")
            gameScene?.setCamera(cameraNodeName: cameraNodeName, duration: 0.0)
        }
        
        /// Fades to defined camera within 2.0 seconds...
        if let cmd = currentDat.object(forKey: "fadeToCam") {
            self.fadeToCam(cameraName: cmd as! String)
        }
        
        //
        if let cmd = currentDat.object(forKey: "crossFadeToCam") {
            
            let transition = SKTransition.crossFade(withDuration: 1.5)
            transition.pausesIncomingScene = false
            transition.pausesOutgoingScene = false
            
            let next_pov = self.gameScene!.node(name: cmd as! String)
            self.gameScene?.sceneView.present((self.gameScene?.sceneView.scene)!, with: transition, incomingPointOfView: next_pov, completionHandler:nil)
            
        }
        
        if currentDat.object(forKey: "shudderCamera") != nil {
            self.shudder(node: (self.gameScene?.sceneView.pointOfView)!, rate: 0.07)
        }
        
        /// a complex camera panning option
        if let cmd = currentDat.object(forKey: "panCamera") {
            let cameraCmd = cmd as! NSDictionary
            //
            if let input = cameraCmd.object(forKey: "preCam") {
                gameScene?.setCamera(cameraNodeName: input as! String, duration: 0.0)
            }
            //
            let duration = Double(cameraCmd.object(forKey:"duration") as? String ?? "0.0") ?? 0.0
            let delay = Double(cameraCmd.object(forKey:"delay") as? String ?? "0.0") ?? 0.0
            let waitAction = SCNAction.wait(duration: delay)
            
            if let input = cameraCmd.object(forKey: "camera") {
                
                gameScene?.setCamera(cameraNodeName: input as! String, duration: duration)
                
            }
            //
        }
        
        /// pan to next camera strictly 1 second pan. Cannot be customized
        if let cmd = currentDat.object(forKey: "panQuick") {
            
            // remove talk bar
            self.clearNarrator()
            textAreaBG.isHidden = true;
            lineDisplay.isHidden = true;
            
            // validate camera name
            let cameraNodeName = cmd as! String
            self.gameScene?.setCamera(cameraNodeName: cameraNodeName, duration: 1.0)
            
        }
        
        if let cmd = currentDat.object(forKey: "autoPanCam") {
            
            let camName = cmd as! String
            let cmd = camName.components(separatedBy: "-")
            
            var duration = 3.0
            if cmd.count > 2 {
                // contains duration
                duration = Double(cmd[2]) ?? 3.0
            }
            
            let precamNode = self.gameScene?.node(name: camName)
            let nextCamNode = precamNode?.childNodes.first
            
            //fade out
            UIView.animate(withDuration:0.4) {
                
                self.gameScene?.sceneView.alpha = 0.0
                
            } completion: { yes in
                
                // switch to preCam
                self.gameScene?.setCamera(cameraNodeName: camName, duration: 0.0)
                
                // start panning to next scene
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.gameScene?.setCamera(cameraNodeName: (nextCamNode?.name)!, duration: duration)
                    UIView.animate(withDuration:0.4) {
                        self.gameScene?.sceneView.alpha = 1.0
                    }
                }
            }
        }
        
        //
        // BY SCENE PROFILING
        //
        if let cmd = currentDat.object(forKey: "cameraSetting") {
            let cameraCmd = cmd as! NSDictionary
            gameScene?.shaders.overrideCameraSettings(dat_cameraSetting: cameraCmd)
        }
        if let cmd = currentDat.object(forKey: "lightSetting") {
            let thecmd = cmd as! NSDictionary
            gameScene?.shaders.overrideLightSettings(dat_lightSetting: thecmd)
        }
        if let cmd = currentDat.object(forKey: "fogSetting") {
            let thecmd = cmd as! String
            gameScene?.shaders.overrideFogSetting(inputDat: thecmd)
        }
        //
        if let cmd = currentDat.object(forKey: "setMotionBlur") as? Bool {
            if cmd == true {
                self.gameScene?.sceneView.scene?.rootNode.enumerateHierarchy({ node, hr in
                    if let cam = node.camera {
                        cam.motionBlurIntensity = 1.0;
                    }
                })
            } else {
                self.gameScene?.sceneView.scene?.rootNode.enumerateHierarchy({ node, hr in
                    if let cam = node.camera {
                        cam.motionBlurIntensity = 0.0;
                    }
                })
            }
        }
        
        // instant45Cam@ -> aligns and fade into up45Axis camera
        if let cmd = currentDat.object(forKey: "setInstantCam") {
            // Will not set camera, but only prepare to pan to this location
            
            let cmdAction = (cmd as! String).components(separatedBy: "/")
            
            let nodeToSet = self.gameScene?.node(name: cmdAction.first!)
            let camAxis = self.gameScene?.node(name: "up45Axis")
            
            if nodeToSet is NPCNode {
                let ndNpc = nodeToSet as! NPCNode
                camAxis?.position = ndNpc.zroot.worldPosition // only pans the camera into this position
            } else {
                camAxis?.position = nodeToSet!.worldPosition
            }
            
            var camName = "up45Cam"
            if cmdAction.count > 1 {
                camName = cmdAction.last!
            }
            self.fadeToCam(cameraName: camName)
        }
        
        // instant45Cam -> pans into new location
        if let cmd = currentDat.object(forKey: "panInstantCam") {
                        
            // initial position ->
            let camAxis = self.gameScene?.node(name: "up45Axis")
            let nodeToSet = self.gameScene?.node(name: cmd as! String)
            camAxis?.position = (gameScene?.player.realWorldPosition())!
            
            // change camera
            self.gameScene?.sceneView.pointOfView = self.gameScene?.node(name: "up45Cam")
            
            // animate
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 2.0
            if nodeToSet is NPCNode {
                let ndNpc = nodeToSet as! NPCNode
                camAxis?.position = ndNpc.zroot.worldPosition
            } else {
                camAxis?.position = nodeToSet!.worldPosition
            }
            SCNTransaction.commit()
            
        }
        
        // Playing Single Sound FX <without 3D positional audio>
        if let cmd = currentDat.object(forKey: "sfx") {
            let soundName = cmd as! String
            gameScene?.sfx(name: soundName)
        }
        
        // Play sound effect while fading out background song
        if let cmd = currentDat.object(forKey: "focusSfx") {
            let soundName = cmd as! String
            self.gameScene?.parentVC?.fadeBGM(toVolume: 0.0, duration: 0.3)
            
            let wait = SKAction.wait(forDuration: 0.3)
            let sound = SKAction.playSoundFileNamed("ListenedGameAssets.scnassets/bgm/\(soundName)", waitForCompletion: true)
            let action = SKAction.sequence([wait, sound])
            
            gameScene?.spriteScene?.run(action, completion: {
                self.gameScene?.parentVC?.fadeBGM(toVolume: 1.0, duration: 1.0)
            })
            
        }
        
        
        /// instantly plays audio without any crossfades
        if let bgmID = currentDat.object(forKey: "BGM") as? String {
            self.gameScene?.parentVC?.playAudio(bgmId: bgmID)
        }
        
        /// playBGM still fades audio
        if let cmd = currentDat.object(forKey: "playBGM") {
            
            let soundName = cmd as! String
            print("playBGM command \(soundName)")
            if soundName.contains("/") == true {
                let cmdsep = soundName.components(separatedBy: "/")
                let dur = Double(cmdsep.last!)
                var volume = Float(1.0)
                if cmdsep.count > 1 {
                    volume = Float(cmdsep.last!)!
                }
                self.gameScene?.parentVC?.fadeToBGM(bgmId: cmdsep.first, duration:dur!, volume: volume);
            } else {
                // no fade standard volume
                self.gameScene?.parentVC?.fadeToBGM(bgmId: soundName, duration: 0.3, volume: 1.0);
            }
        }
        if let cmd = currentDat.object(forKey: "fadeBGM") {
            // only fade to certain volume
            let cmdFade = (cmd as! String).components(separatedBy: "/")
            let volume = Float(cmdFade.first ?? "0.0")
            let dur = Double(cmdFade.last ?? "0.0")
            
            // apply volume fade
            self.gameScene?.parentVC?.fadeBGM(toVolume: volume ?? 0.0, duration: dur ?? 0.0)
        }
        
        if let cmd = currentDat.object(forKey: "nodeFunction") {
            // check if it's an array or a dictionary.  Array is a multiple sequene / dictionary only for single function
            if cmd is NSDictionary {
                // single function
                runNodeFunction(nodeFunction: cmd as? NSDictionary)
            } else {
                // multiple sequenced functions
                let functions = cmd as! Array<NSDictionary>
                for nodeFunction in functions {
                    runNodeFunction(nodeFunction: nodeFunction)
                }
            }
        }
        
        
        // FIXED FUNC
        if let cmd = currentDat.object(forKey: "runSeq-talkToNpc") {
            let npcName = cmd as! String
            self.talkToNpc(npcName: npcName)
        }
        if let cmd = currentDat.object(forKey: "runSeq-closeUpToNpc") {
            let npcName = cmd as! String
            self.zoomUpToNPC(npcName: npcName)
        }
        
        
        if let cmd = currentDat.object(forKey: "npcFunction") {
            // check if it's an array or a dictionary.  Array is a multiple sequene / dictionary only for single function
            if cmd is NSDictionary {
                runNpc(functions: cmd as? NSDictionary)
            } else {
                // multiple sequenced functions
                let functions = cmd as! Array<NSDictionary>
                for nodeFunction in functions {
                    runNpc(functions: nodeFunction)
                }
            }
        }
        
        if let cmd = currentDat.object(forKey: "promptEnter") {
            
            let cmdDic = cmd as! NSDictionary
            
            let textInputView = self.storyboard?.instantiateViewController(withIdentifier: "ADVTextInputController") as! ADVTextInputController
            textInputView.parentVC = self;
            textInputView.promptDataObj = cmdDic
            
            if textInputView.promptDataObj != nil {
                self.present(textInputView, animated: true, completion: nil)
            }
            // will display view dedicated for inputting text field
        }
        
        if let questionFunc = currentDat.object(forKey: "questionFunc") {
            
            // initialize
            for choiceBtn in choiceBtns {
                choiceBtn.setTitle("", for: .normal)
                choiceBtn.accessibilityValue = nil
                choiceBtn.accessibilityHint = nil
                choiceBtn.accessibilityLabel = nil
                choiceBtn.isHidden = true
                choiceBtn.alpha = 0.0
                choiceBtn.tag = 0
            }
            
            // show mcv
            mutipleChoiceView.isHidden = false
            
            //
            let functions = questionFunc as! Array<NSDictionary>
            
            var ci:Int = 0
            for function in functions {
                
                let qstn = function.object(forKey: "title") as! String
                let nxt = function.object(forKey: "next") as? String
                let correct = function.object(forKey: "correct") as? String
                let eventBattle = function.object(forKey: "battleEncounter") as? String
                
                choiceBtns[ci].setTitle(qstn, for: .normal)
                choiceBtns[ci].isHidden = false
                
                let delayCtr = Double(ci)
                
                // add functionality to choice buttons
                if let nextEvnt = nxt {
                    choiceBtns[ci].accessibilityLabel = nextEvnt
                }
                
                if eventBattle != nil {
                    choiceBtns[ci].accessibilityHint = eventBattle
                    self.perform(#selector(bubbleAppear(layer:)), with: choiceBtns[ci], afterDelay: delayCtr * 0.1)
                } else {
                    // Battle Mode
                    //self.gameScene?.sfx(name: "selectIdentifier.mp3")
                    self.perform(#selector(sideAppear(layer:)), with: choiceBtns[ci], afterDelay: delayCtr * 0.1)
                }
                
                if let ans = correct {
                    choiceBtns[ci].accessibilityValue = ans
                }
                
                ci += 1
            }
            
        } else {
            mutipleChoiceView.isHidden = true
            
            // initialize
            for choiceBtn in choiceBtns {
                choiceBtn.setTitle("", for: .normal)
                choiceBtn.accessibilityLabel = nil
                choiceBtn.isHidden = true
            }
        }
        
        // PRIORITY FUNCTION
        if let line = currentDat.object(forKey: "line") {
            // have line. display line
            
            
            // set default condition
            lineDisplay.text = "";
            tCtr = 0
            
            
            
            var delayToText:Double = 0
            
            //
            if let lcmd = currentDat.object(forKey: "delayLine") {
                let lcmdString = lcmd as! String
                delayToText = delayToText + Double(lcmdString)!
                
            }
            if currentDat.object(forKey: "fadeToCam") != nil {
                delayToText = delayToText + 2.5;
            }
            if currentDat.object(forKey: "panQuick") != nil {
                delayToText = delayToText + 1.25;
            }
            //
            
            if currentDat.object(forKey: "clearNarrator") != nil {
                speakingNpcName = nil
                self.clearNarrator()
            }
            
            
            // display text
            var textToDisplay:String? = ""
            
            // get user language
            let lang = UserDefaults.standard.string(forKey: "user_lang")
            //print("userLang -> \(lang)")
            
            if lang?.hasPrefix("JA") == true {
                // JAPANESE
                if currentDat.object(forKey: "lineJA") != nil {
                    textToDisplay = currentDat.object(forKey: "lineJA") as? String
                } else {
                    textToDisplay = currentDat.object(forKey: "line") as? String
                }
                
                if (currentDat.object(forKey: "angerText") != nil) {
                    lineDisplay.font = UIFont(name: lineDisplay.font.fontName, size: 21);
                }
                
            } else {
                // ENGLISH
                textToDisplay = currentDat.object(forKey: "line") as? String
                if (currentDat.object(forKey: "angerText") != nil) {
                    lineDisplay.font = UIFont(name: lineDisplay.font.fontName, size: 21);
                }
            }
            
            currentLineText = textToDisplay
                        
            DispatchQueue.main.asyncAfter(deadline: .now() + delayToText) { [self] in
                
                textAreaBG.isHidden = false;
                lineDisplay.isHidden = false;
                
                if let narratorID = currentDat.object(forKey: "narrator") {
                    // replace narrator / add new narrator
                    self.setNarrator(narratorID: narratorID as! String)
                    speakingNpcName = narratorID as! String
                }
                
                // check who is reading
                if let cmd = currentDat.object(forKey: "readLine") {
                    // get npc identifier
                    self.npcReadLineFunc(fileName: cmd as! String)
                }
                
                var npcToSpeak:NPCNode?
                if npcToSpeak == nil && speakingNpcName != nil {
                    let nd = self.gameScene?.sceneView.scene?.rootNode.childNode(withName: speakingNpcName!, recursively: true)
                    if nd != nil {
                        if nd is NPCNode {
                            let ndnpc = nd as? NPCNode
                            if (ndnpc?.talkMat) != nil {
                                npcToSpeak = ndnpc
                            }
                        }
                    }
                }
                
                //print("TEXT - npcToSpeak \(npcToSpeak) - currentNarratorID:\(currentNarratorID)")
                
                if (currentDat.object(forKey: "angerText") != nil) {
                    
                    lineDisplay.textAlignment = .center
                    var r3ctr = 0
                    
                    npcToSpeak?.talk()
                    
                    textTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { timer in
                        if self.tCtr < self.currentLineText!.count {
                            // when message adds text on line play sound "lineRead"
                            self.lineDisplay.text = self.lineDisplay.text! + "\(self.currentLineText![self.tCtr])"
                            self.tCtr += 1
                            
                            r3ctr += 1
                            if r3ctr >= 3 {
                                self.gameScene?.spriteScene?.run((self.gameScene?.parentVC!.lineRead)!)
                                r3ctr = 0
                            }
                        } else {
                            timer.invalidate()
                            npcToSpeak?.stopTalk()
                            if (currentDat.object(forKey: "autoTapAfter") != nil) {
                                // if autoTapAfter is available, must wait
                            } else if (currentDat.object(forKey: "conditional") != nil) {
                                // if conditional is available,
                            } else {
                                // if no autoTap, enable NEXT
                                self.nextBtn.isEnabled = true;
                                let p = self.tapEllipse.layer.animation(forKey: "pulse")
                                if p == nil {
                                    self.tapEllipse.layer.add((self.gameScene?.shaders.pulseAnim())!, forKey: "pulse")
                                }
                                self.tapEllipse.isHidden = false
                            }
                        }
                    })
                    textTimer?.fire()
                } else {
                    
                    lineDisplay.textAlignment = .left
                    lineDisplay.font = defaultTextFont
                    
                    npcToSpeak?.talk()
                    
                    var r3ctr = 0
                    textTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true, block: { timer in
                        if self.tCtr < self.currentLineText!.count {
                            self.lineDisplay.text = self.lineDisplay.text! + "\(self.currentLineText![self.tCtr])"
                            self.tCtr += 1
                            
                            r3ctr += 1
                            if r3ctr >= 3 {
                                gameScene?.spriteScene?.run((self.gameScene?.parentVC!.lineRead)!)
                                r3ctr = 0
                            }
                        } else {
                            timer.invalidate()
                            npcToSpeak?.stopTalk()
                            if (currentDat.object(forKey: "autoTapAfter") != nil) {
                                // if autoTapAfter is available, must wait
                            } else if (currentDat.object(forKey: "conditional") != nil) {
                                // if conditional is available,
                            } else {
                                // if no autoTap, enable NEXT
                                self.nextBtn.isEnabled = true;
                                let p = self.tapEllipse.layer.animation(forKey: "pulse")
                                if p == nil {
                                    self.tapEllipse.layer.add((self.gameScene?.shaders.pulseAnim())!, forKey: "pulse")
                                }
                                self.tapEllipse.isHidden = false
                            }
                        }
                    })
                    textTimer?.fire()
                }
            }
            
        }
        else {
            
            if currentDat.object(forKey: "questionFunc") != nil {
            } else {
                speakingNpcName = nil
                self.clearNarrator()
                textAreaBG.isHidden = true;
                lineDisplay.isHidden = true;
            }
            
        }
        
        // center text that will appear and disappear
        if currentDat.object(forKey: "centerText") != nil {
            centerLineDisplay.text = ""
            centerLineDisplay.alpha = 0.0
            
            // display text
            let lang = UserDefaults.standard.string(forKey: "user_lang")
            var textToDisplay:String? = ""
            if lang?.hasPrefix("JA") == true {
                // JAPANESE
                if currentDat.object(forKey: "centerTextJA") != nil {
                    textToDisplay = currentDat.object(forKey: "centerTextJA") as? String
                } else {
                    textToDisplay = currentDat.object(forKey: "centerText") as? String
                }
            } else {
                // ENGLISH
                textToDisplay = currentDat.object(forKey: "centerText") as? String
            }
            
            var dynamic = false
            if textToDisplay?.contains("#!") == true {
                textToDisplay = textToDisplay?.replacingOccurrences(of: "#!", with: "")
                dynamic = true
            }
            
            
            centerLineDisplay.text = textToDisplay;
            
            if dynamic == true {
                centerLineDisplay.transform = CGAffineTransform.init(scaleX: 3.0, y: 3.0)
            } else {
                centerLineDisplay.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
            }
            
            UIView.animate(withDuration: 0.5) {
                self.centerLineDisplay.alpha = 1.0
                if dynamic == true {
                    self.centerLineDisplay.transform = CGAffineTransform.init(scaleX: 1.5, y: 1.5)
                }
            } completion: { comp in
                //
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if (currentDat.object(forKey: "autoTapAfter") != nil) {
                        // if autoTapAfter is available, must wait
                    } else {
                        // if no autoTap, enable NEXT
                        self.nextBtn.isEnabled = true;
                        let p = self.tapEllipse.layer.animation(forKey: "pulse")
                        if p == nil {
                            self.tapEllipse.layer.add((self.gameScene?.shaders.pulseAnim())!, forKey: "pulse")
                        }
                        self.tapEllipse.isHidden = false
                    }
                }
            }
            
        }
        else {
            // auto hide if no centertext on the next go
            if centerLineDisplay.alpha == 1 {
                UIView.animate(withDuration: 0.5) {
                    self.centerLineDisplay.alpha = 0.0
                }
            }
        }
        
        //
        
        
        if currentDat.object(forKey: "displayCenterTapEllipse") != nil {
            self.nextBtn.isEnabled = true;
            self.tapEllipseCenter.isHidden = false
        }
        
        if currentDat.object(forKey: "closeAndLoadGameStage") != nil {
            let dat_cmd = currentDat.object(forKey: "closeAndLoadGameStage") as! String
            self.dismiss(animated: false) {
                self.gameScene?.loadStage(stageName: dat_cmd)
            }
        }
        
        if currentDat.object(forKey: "reloadStage") != nil {
            self.dismiss(animated: false) {
                self.gameScene?.repeatStage()
            }
        }
        
        if currentDat.object(forKey: "closeAndLoadMenu") != nil {
            self.dismiss(animated: false) {
                self.gameScene?.backToMenu()
            }
        }
        
        if currentDat.object(forKey: "moveToMap") != nil {
            let dat_cmd = currentDat.object(forKey: "moveToMap") as! String
            self.dismiss(animated: false) {
                self.gameScene?.startMapMove(nextNode: dat_cmd)
            }
        }
        
        if currentDat.object(forKey: "loadDefaultCamera") != nil {
            if gameScene?.sceneView.pointOfView != gameScene?.standardCamera {
                if gameScene?.sceneView.pointOfView?.name != gameScene?.standardCamera.name {
                    UIView.animate(withDuration: 0.5, animations: {
                        self.gameScene?.sceneView.alpha = 0.0
                    }) { completed in
                        self.gameScene?.sceneView.pointOfView = self.gameScene?.standardCamera
                        self.gameScene?.resetCamAxisPosition()
                        UIView.animate(withDuration:0.5) {
                            self.gameScene?.sceneView.alpha = 1.0
                        }
                    }
                }
            }
        }
        
        if let cmd = currentDat.object(forKey: "conditional") {
            // check for conditional jump/set another event. This can easily convert to another event
            
            // there can be multiple conditional functions where player will just yeah...
            
            if let positionOnTopOf = (cmd as! NSDictionary).object(forKey: "playerOnTopOf") {
                //
                let nodeUnderPlayer = self.gameScene?.shaders.nodeUnder(player: self.gameScene!.player)
                //
                if let nodeName = nodeUnderPlayer?.name {
                    if nodeName == (positionOnTopOf as! String) {
                        // player condition met. Event initiated when player stood up on this particular position
                        
                        
                        return
                    }
                }
            }
            
        }
        
        // registerAction -> ♦︎　Locate Key Tag/10100-KeyFind$
        if let key = currentDat.object(forKey: "registerAction") {
            self.dismiss(animated: true) {
                self.gameScene?.beginActionRegisterSequence(actionCmd: key as! String)
            }
        }
        
        //removeRegisterAction
        if let key = currentDat.object(forKey: "removeRegisterAction") {
            self.gameScene?.gameMenu.removeRegisteredaction(name: key as! String)
        }
        
        if currentDat.object(forKey: "closeMenu") != nil {
            self.gameScene?.gameMenu.dynamicCloseView()
        }
        
        if let key = currentDat.object(forKey: "checkContact") as? NSDictionary {
            
            // check contact only at this point
            
            /// check contact between the said node, and npc only. contact node must have name "wall"
            let contacts = self.gameScene!.sceneView.scene?.physicsWorld.contactTest(with: self.gameScene!.player.body.physicsBody!, options: [SCNPhysicsWorld.TestOption.collisionBitMask : self.gameScene!.collisionMeshBitMask])
            
            let nodeName = key.object(forKey: "node") as! String
            let even = key.object(forKey: "runEvent") as! String
            
            if let filt = contacts?.compactMap({ $0 }).filter({ $0.nodeB.name?.contains(nodeName) == true }) {
                let contSet: Set<SCNPhysicsContact> = Set(filt)
                if contSet.count > 0 {
                    print("detected deadItem on checkContact", contSet)
                    // check if node really hit with Kenny
                    if contSet.first?.nodeA.name?.contains("Kenny") == true || contSet.first?.nodeB.name?.contains("Kenny") == true {
                        print("detected Kenny upon checkContact")
                        self.prepareEvent(event: even)
                        return;
                    }
                }
            }
            
            
            
            
        }
        
        if let key = currentDat.object(forKey: "autoTapAfter") {
            let val = Double(key as? String ?? "0.1") ?? 0.1
            self.perform(#selector(nextBtnTapped(_:)), with:nil, afterDelay: val)
        }
        
        // count down event
        if let key = currentDat.object(forKey: "countDownEvent") as? NSDictionary {
            
            let time = key.object(forKey: "time") as! String
            let even = key.object(forKey: "event") as! String
            
            let waitAction = SCNAction.wait(duration: Double(time)!)
            let eventToRun = SCNAction.run { node in
                if self.gameScene?.gameState == 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        self.prepareEvent(event: even)
                    }
                }
            }
            let seq = SCNAction.sequence([waitAction, eventToRun])
            
            // close this first...
            self.dismiss(animated: true) {
                self.gameScene?.player.runAction(seq)
            }
            
        }
        
        
        // Setting Progress only
        if let key = currentDat.object(forKey: "setProgress") {
            let val = key as! String
            self.gameScene?.parentVC?.setGameStage(stageName: val)
        }
        if let key = currentDat.object(forKey: "setProgress#") {
            // set progress
            let val = key as! String
            self.gameScene?.parentVC?.setGameStage(stageName: val)
            // after setting progress, run event taken from get the runEvent value of that progress
            let gameProg = self.gameScene!.parentVC?.tempPlayerData["gameProgress"] as? String
            let gameDatas:NSDictionary = self.gameScene!.parentVC?.dat.object(forKey: "loadGame") as! NSDictionary
            self.gameScene!.currentGameData = (gameDatas.object(forKey: gameProg!) as! NSDictionary)
            let runEvent = self.gameScene!.currentGameData.object(forKey: "runEvent") as? String
            //
            if let evntToRun = runEvent {
                self.prepareEvent(event: evntToRun)
            }
        }
        
        // Set Overworld user progress
        if let key = currentDat.object(forKey: "setOverworldProgress") {
            //
            let val = key as! NSArray
            for str in val {
                let strVal = str as! String
                self.gameScene?.parentVC?.setOverworldProgress(key: strVal)
            }
            //
        }
        
        //self.prepareEvent(event: choiceBtn.accessibilityLabel!)
        if let key = currentDat.object(forKey: "jumpEvent") {
            self.prepareEvent(event: key as! String)
        }
        
        if let key = currentDat.object(forKey: "battleEncounter") {
            
            let enemyIdKey = key as! String
            self.encounter(enemyID: enemyIdKey)
            
        }
        
    }
    
    //
    //
    //
    //
    //
    //
    //
    //
    
    
    

    
    // All node animations within the scene
    func runNodeFunction(nodeFunction: NSDictionary?) {
        
        //        let nodeName = nodeFunction!.object(forKey: "name") as! String
        
        if let nodeName = nodeFunction!.object(forKey: "name") {
            let name = nodeName as! String
            let node = gameScene?.sceneView.scene?.rootNode.childNode(withName: name, recursively: true)
            if node != nil {
                nodeAction(node: node, nodeFunction: nodeFunction)
            }
        }
        if let val = nodeFunction!.object(forKey: "multiName") {
            let nodeName = val as! String
            gameScene?.sceneView.scene?.rootNode.enumerateHierarchy({ theNode, stop in
                // get nodename that contains almost same names
                if theNode.name != nil {
                    if (theNode.name?.contains(nodeName))! {
                        self.nodeAction(node: theNode, nodeFunction: nodeFunction)
                    }
                }
            })
        }
    }
    
    func nodeAction(node: SCNNode?, nodeFunction: NSDictionary?) {
        
        // apply functions
        let duration = Double(nodeFunction!.object(forKey: "duration") as? String ?? "0.0") ?? 0.0
        let delay = Double(nodeFunction!.object(forKey: "delay") as? String ?? "0.0") ?? 0.0
        let timing = nodeFunction?.object(forKey: "timing") as? NSNumber ?? 0
        // Linear:0/easeIn:1/easeOut:2/easeInEaseOut:3

        
        // non-animatable
        
        // SetObject ID for Pickable Object to be available on field
        if nodeFunction!.object(forKey: "setObjectID") != nil {
            node!.accessibilityValue = (nodeFunction!.object(forKey: "setObjectID") as! String)
        }
        // Setting Progress dat on objects
        if let cmd = nodeFunction!.object(forKey: "addProgressDat") {
            node!.accessibilityHint = "addProgressDat/\(cmd as! String)"
        }
        if nodeFunction!.object(forKey: "resetActions") != nil {
            node!.removeAllActions()
        }

        //
        if nodeFunction!.object(forKey: "objectSpin") != nil {
            // mario style object spinning
            let action = SCNAction.rotateBy(x: 0, y: 1, z: 0, duration: 0.2)
            node?.runAction(SCNAction.repeatForever(action))
        }
        //
        if nodeFunction!.object(forKey: "clearParticle") != nil {
            node?.removeAllParticleSystems()
        }
        //
        if nodeFunction!.object(forKey: "addParticle") != nil {
            let particleName = (nodeFunction!.object(forKey: "addParticle") as! String)
            
            // check if node already has particle
            
            // find
            let particleNode = self.gameScene?.sceneView.scene?.rootNode.childNode(withName: particleName, recursively: true)
            var particleSystem:SCNParticleSystem? = nil
            
            if particleNode == nil {
                let ptclFile = SCNParticleSystem.init(named: "\(particleName)", inDirectory: "ListenedGameAssets.scnassets")
                particleSystem = ptclFile
            } else {
                particleSystem = particleNode?.particleSystems?.first?.copy() as? SCNParticleSystem
                // duplicate from existing
            }
            
            if particleSystem != nil {
                node?.addParticleSystem(particleSystem!)
                node?.renderingOrder = 6
            }
        }
        if nodeFunction!.object(forKey: "particleBirthRate") != nil {
            //node!.accessibilityLabel = nil
            let birthRate = Double(nodeFunction!.object(forKey: "particleBirthRate") as? String ?? "0.0") ?? 0.0
            if (node?.particleSystems!.count)! > 0 {
                node?.particleSystems?.first?.birthRate = CGFloat(birthRate)
            }
        }
        //
        if nodeFunction!.object(forKey: "setEvent") != nil {
            // force item to display
            node?.opacity = 1.0
            node!.accessibilityLabel = (nodeFunction!.object(forKey: "setEvent") as! String)
            print("nodeAction eventSetTo Node:\(String(describing: node?.name)) eventID:\(String(describing: node?.accessibilityLabel))")
        }
        if nodeFunction!.object(forKey: "removeEvent") != nil {
            node!.accessibilityLabel = nil
        }
        if nodeFunction!.object(forKey: "uniCond") != nil {
            // Registers Universal Conditional
            /*
             With this function, system will start monitoring registered conditions whenever user passes by (trigger), or taps (evnt) node on the map.
             It will run the event only when the condition was met.
             */
            node!.accessibilityLabel = (nodeFunction!.object(forKey: "uniCond") as! String)
            print("nodeAction eventSetTo Node:\(String(describing: node?.name)) eventID:\(String(describing: node?.accessibilityLabel))")
        }
        //
        if nodeFunction!.object(forKey: "removePhysicsBody") != nil {
            node?.enumerateHierarchy({ hrnode, stop in
                hrnode.physicsBody = nil;
            })
        }
        // start after delay
        let act_delay = SCNAction.wait(duration: delay)
        //
        let block = SCNAction.run { theNode in
            //
            print("Action run for nodes \(String(describing: theNode.name))")
            //
            if nodeFunction!.object(forKey: "isHidden") != nil {
                node!.isHidden = nodeFunction!.object(forKey: "isHidden") as! Bool
            }
            //
            if nodeFunction!.object(forKey: "setCameraBlur") != nil {
                if let nodecam = node?.camera {
                    nodecam.motionBlurIntensity = 10.0
                }
            }
            //
            if nodeFunction!.object(forKey: "objectHint") != nil {
                let input = Int(nodeFunction!.object(forKey: "objectHint") as! String)
                self.gameScene?.displayObjectHint(style:input!, onNode: theNode)
            }
            //
            if nodeFunction!.object(forKey: "loadAction") != nil {
                let val = nodeFunction!.object(forKey: "loadAction") as! Bool
                if val == true {
                    // only actions
                    self.gameScene?.loadInGameActions(name: (node?.name)!, node: node!, action: true)
                } else {
                    // insert entire node
                    self.gameScene?.loadInGameActions(name: (node?.name)!, node: node!, action: false)
                }
            }
            //
            if nodeFunction!.object(forKey: "fogColor") != nil {
                
            }
            if nodeFunction!.object(forKey: "fogNear") != nil {
                let val = nodeFunction!.object(forKey: "fogNear") as! String
                let param = Float(val)
                SCNTransaction.begin()
                SCNTransaction.animationDuration = duration
                self.gameScene?.sceneView.scene?.fogStartDistance = CGFloat(param!)
                SCNTransaction.commit()
                
            }
            if nodeFunction!.object(forKey: "fogFar") != nil {
                let val = nodeFunction!.object(forKey: "fogFar") as! String
                let param = Float(val)
                SCNTransaction.begin()
                SCNTransaction.animationDuration = duration
                self.gameScene?.sceneView.scene?.fogStartDistance = CGFloat(param!)
                SCNTransaction.commit()
            }
            //
            if nodeFunction!.object(forKey: "opacity") != nil {
                let input = Float(nodeFunction!.object(forKey: "opacity") as! String)
                theNode.runAction(SCNAction.fadeOpacity(to: CGFloat(input!), duration: duration))
            }
            //
            if nodeFunction!.object(forKey: "runAction") != nil {
                let val = nodeFunction!.object(forKey: "runAction") as! String
                self.gameScene?.loadInGameActions(name: val, node: node!, action: true)
            }
            
            // adds repetitive 3D sound
            if nodeFunction!.object(forKey: "add3DSound") != nil {
                let input = nodeFunction!.object(forKey: "add3DSound") as! String// filename/volume
                let cmd = input.components(separatedBy: "/")
                let vol = Float(cmd[1]) ?? 0.2
                self.gameScene?.shaders.addSound(filename:cmd[0], node:theNode, volume: vol)
            }
            
            // plays sounds only once everytime its called
            if nodeFunction!.object(forKey: "play3DSound") != nil {
                if theNode.isHidden == false {
                    if theNode.opacity > 0.0 {
                        // play only if its opacity is visible
                        let input = nodeFunction!.object(forKey: "play3DSound") as! String// filename/volume
                        let cmd = input.components(separatedBy: "/")
                        if cmd.count > 1 {
                            let vol = Float(cmd[1]) ?? 0.2
                            self.gameScene?.shaders.playSound(filename: cmd[0], node: theNode, volume: vol)
                        } else {
                            self.gameScene?.shaders.playSound(filename: cmd[0], node: theNode, volume: 0.2)
                        }
                    }
                }
            }
            //
            if nodeFunction!.object(forKey: "scnSoundReset") != nil {
                node?.removeAllAudioPlayers()
            }
            //
            if nodeFunction!.object(forKey: "removeAllAttributes") != nil {
                node?.removeAllAudioPlayers()
                node?.removeAllParticleSystems()
                node?.removeAllAnimations()
                node?.removeAllActions()
            }
            //
            if nodeFunction!.object(forKey: "scale") != nil {
                let input = Float(nodeFunction!.object(forKey: "scale") as! String)
                let scaleAction = SCNAction.scale(to: CGFloat(input!), duration: duration)
                scaleAction.timingMode = SCNActionTimingMode.easeInEaseOut
                theNode.runAction(scaleAction)
            }
            //
            if nodeFunction!.object(forKey: "birthRate") != nil {
                let input = Float(nodeFunction!.object(forKey: "birthRate") as! String)
                if let ndParticle = theNode.particleSystems?.first {
                    
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = duration
                    ndParticle.birthRate = CGFloat(input!)
                    SCNTransaction.commit()
                }
            }
            //
            if nodeFunction!.object(forKey: "position") != nil {
                let input = nodeFunction!.object(forKey: "position") as! String
                let posNode = self.gameScene?.node(name: input)
                let moveAction = SCNAction.move(to: posNode!.worldPosition, duration: duration)
                moveAction.timingMode = SCNActionTimingMode.init(rawValue: timing.intValue)!
                theNode.runAction(moveAction)
            }
            if nodeFunction!.object(forKey: "localPosition") != nil {
                let input = nodeFunction!.object(forKey: "localPosition") as! String
                let posNode = self.gameScene?.node(name: input)
                let moveAction = SCNAction.move(to: posNode!.position, duration: duration)
                moveAction.timingMode = SCNActionTimingMode.init(rawValue: timing.intValue)!
                theNode.runAction(moveAction)
            }
            if nodeFunction!.object(forKey: "position-EI") != nil {
                let input = nodeFunction!.object(forKey: "position-EI") as! String
                let posNode = self.gameScene?.node(name: input)
                let moveAction = SCNAction.move(to: posNode!.worldPosition, duration: duration)
                moveAction.timingMode = SCNActionTimingMode.easeIn
                theNode.runAction(moveAction)
            }
            if nodeFunction!.object(forKey: "npcPosition") != nil {
                
                var npc:NPCNode?
                if let npcName = nodeFunction!.object(forKey: "npcPosition") {
                    let possibleNPCNode = self.gameScene?.sceneView.scene?.rootNode.childNode(withName: npcName as! String, recursively: true)
                    if possibleNPCNode != nil {
                        npc = possibleNPCNode as? NPCNode
                    }
                } else {
                    npc = self.gameScene?.player
                }
                if npc != nil {
                    let pos = npc?.realWorldPosition()
                    let moveAction = SCNAction.move(to: pos!, duration: duration)
                    moveAction.timingMode = SCNActionTimingMode.init(rawValue: timing.intValue)!
                    theNode.runAction(moveAction)
                }
                
            }
            if nodeFunction!.object(forKey: "eulerAngle") != nil {
                let input = nodeFunction!.object(forKey: "eulerAngle") as! String
                let angleDatas = input.components(separatedBy: "/") // x: y: z:
                
                // in angles
                let eaFX = Float(angleDatas[0])
                let eaFY = Float(angleDatas[1])
                let eaFZ = Float(angleDatas[2])
                
                let rdx = GLKMathDegreesToRadians(eaFX!)
                let rdy = GLKMathDegreesToRadians(eaFY!)
                let rdz = GLKMathDegreesToRadians(eaFZ!)
                
                let angleAction = SCNAction.rotateTo(x: CGFloat(rdx), y: CGFloat(rdy), z: CGFloat(rdz), duration: duration)
                angleAction.timingMode = SCNActionTimingMode.init(rawValue: timing.intValue)!
                theNode.runAction(angleAction)
            }
            if nodeFunction!.object(forKey: "copyAngle") != nil {
                let nodeToFollow = self.gameScene?.sceneView.scene?.rootNode.childNode(withName: nodeFunction!.object(forKey: "copyAngle") as! String, recursively: true)
                theNode.eulerAngles.y = (nodeToFollow?.eulerAngles.y)!
            }
            //
            if nodeFunction!.object(forKey: "sfx") != nil {
                let input = nodeFunction!.object(forKey: "sfx") as! String
                self.gameScene?.sfx(name: input)
            }
            //
            if nodeFunction!.object(forKey: "shudderCamera") != nil {
                // shudder camera, as if explosion/implosion . only happens briefly
                let input = Float(nodeFunction!.object(forKey: "shudderCamera") as! String) ?? Float(0.3)
                self.shudder(node: (self.gameScene?.sceneView.pointOfView)!, rate: input)
            }
            if nodeFunction!.object(forKey: "shake") != nil {
                // shudder camera, as if explosion/implosion will happen until player stops
                let input = Float(nodeFunction!.object(forKey: "shake") as! String)
                self.shake(node: (self.gameScene?.sceneView.pointOfView)!, rate: input!)
            }
            if nodeFunction!.object(forKey: "shakeAt") != nil {
                // shudder camera, as if explosion/implosion will happen until player stops
                let cmd = (nodeFunction?.object(forKey: "shakeAt") as! String).components(separatedBy: "/")
                var blendInDuration:Float = 0.0
                if cmd.count > 2 {
                    blendInDuration = Float(cmd[2])!
                }
                let speedOfShake = Float(cmd[0])!
                let rate = Float(cmd[1])!
                self.shakeAt(duration: CFTimeInterval(speedOfShake), node: (self.gameScene?.sceneView.pointOfView)!, rate: rate, fadeInDuration: blendInDuration)
            }
            if nodeFunction!.object(forKey: "stopShake") != nil {
                (self.gameScene?.sceneView.pointOfView)!.removeAnimation(forKey: "shake", blendOutDuration: CGFloat(duration))
            }
            //
            if nodeFunction!.object(forKey: "warpOutObject") != nil {
                //
                let moveAction = SCNAction.moveBy(x: 0, y: 0.5, z: 0, duration: 0.5)
                moveAction.timingMode = .easeIn
                let fadeoutAct = SCNAction.fadeOut(duration: 1.0)
                node?.runAction(SCNAction.group([moveAction, fadeoutAct]))
                self.gameScene?.sfx(name: "warpSFX.mp3")
                
                // implicit animation
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.4
                node?.scale = SCNVector3(0.2, 2.0, 0.2)
                SCNTransaction.commit()
                
                //
            }
            if nodeFunction!.object(forKey: "dissolve") != nil {
                self.dissolveNode(aNode: node!, duration: duration)
            }
            //
            /* Small Conditional Functions... a more quick solution */
            if nodeFunction!.object(forKey: "conditionalOnTop") != nil {
                DispatchQueue.main.async {
                    //
                    let nextEvent = nodeFunction!.object(forKey: "conditionalOnTop") as! String
                    _ = nodeFunction!.object(forKey: "conditionalOnTop")
                    
                    //check if player is on top of this node
                    let nodeUnder = self.gameScene?.shaders.nodeUnder(player: self.gameScene!.player)
                    if node == nodeUnder {
                        // jump event
                        self.prepareEvent(event: nextEvent)
                        self.eventPointer = 0
                    } else {
                        // just skip event. move
                        self.perform(#selector(self.nextBtnTapped(_:)), with:nil, afterDelay: 0.0)
                    }
                }
            }
            
        }
        
        let finalizedAction = SCNAction.sequence([act_delay, block])
        node?.runAction(finalizedAction)
        
    }
    
    func runNpc(functions: NSDictionary?) {
        //
        var npc:NPCNode?
        
        print("!! PC modifier - isMapMove:\(String(describing: gameScene?.isMapMove))")
        
        if let npcName = functions!.object(forKey: "npc") {
            if npcName as! String == "player" || npcName as! String == "Player" {
                if gameScene?.isMapMove == true {
                    return
                }
                npc = gameScene?.player
            } else {
                let possibleNPCNode = gameScene?.sceneView.scene?.rootNode.childNode(withName: npcName as! String, recursively: true)
                if possibleNPCNode != nil {
                    npc = possibleNPCNode as? NPCNode
                }
            }
        } else {
            if gameScene?.isMapMove == true {
                return
            }
            npc = gameScene?.player
        }
        
        // If still no node found, create new instantly
        if npc == nil {
            npc = self.createInstantNPC(name: functions?.object(forKey: "npc") as! String)
        }
        
        if npc == nil {
            return
        }
        
        if functions?.object(forKey: "resetActions") != nil {
            npc?.removeAllActions()
            npc?.removeAllAnimations()
        }
        if functions?.object(forKey: "resetHeadTrack") != nil {
            //
            if let headTrack = npc?.headTrack {
                headTrack.target = nil
            }
        }
        if let chaseFunc = functions?.object(forKey: "setChaseTarget") as? Bool {
            if chaseFunc == true {
                npc?.target = self.gameScene?.player
            } else {
                npc?.target = nil
            }
        }
        if functions?.object(forKey: "registerCompanion") != nil {
            self.currentCompanionNode = npc
        }
        if functions?.object(forKey: "removeCompanion") != nil {
            self.currentCompanionNode = nil
        }
        
        if let btlIdentifier = functions?.object(forKey: "encounterNPC") as? String {
            //self.currentEnemyNode = npc
            npc?.npcIdentifier = btlIdentifier
            runFieldEnemyEncounter(enemyNode: npc!)
        }
        
        if functions!.object(forKey: "axis") != nil {
            
            // cancel npc currently walking "owalk"
            npc?.removeAction(forKey: "owalk")
            npc?.removeAnimation(forKey: "owalk")

            // Set position & Face to where that axis is facing
            let node = (gameScene?.node(name: functions!.object(forKey: "axis") as! String))!
            npc!.goTo(pos: node.worldPosition)
            npc!.zroot.eulerAngles.y = node.eulerAngles.y
        }
        if functions?.object(forKey: "detectGnd") != nil {
            let detect = functions?.object(forKey: "detectGnd") as? Bool ?? true
            npc?.detectGround = detect
        }
        if functions!.object(forKey: "position") != nil {
            
            // cancel npc currently walking "owalk"
            npc?.removeAction(forKey: "owalk")
            npc?.removeAnimation(forKey: "owalk")
            
            // Set position & Face to where that axis is facing
            gameScene?.setNPCPosition(npc: npc!, axis: (functions!.object(forKey: "position")) as! String, faceAxis: nil)
            
            if npc == gameScene?.player {
                // if zack, reset camera position
                self.gameScene?.resetCamAxisPosition()
            }
            
        }
        if functions!.object(forKey: "face") != nil {
            // Set position & Face to where that axis is facing
            gameScene?.faceNPC(npc:npc!, toPosition: functions!.object(forKey: "face") as! String, animated: false)
        }
        if functions!.object(forKey: "angle") != nil {
            // Set position & Face to where that axis is facing
            let angle = Float(functions!.object(forKey: "angle") as? String ?? "0.0") ?? 0.0
            npc!.eulerAngles.y = (self.gameScene?.shaders.radians(degrees: angle))!
        }
        if functions!.object(forKey: "copyAngle") != nil {
            let nodeToFollow = self.gameScene?.sceneView.scene?.rootNode.childNode(withName: functions!.object(forKey: "copyAngle") as! String, recursively: true)
            npc!.eulerAngles.y = (nodeToFollow?.eulerAngles.y)!
        }
        if functions!.object(forKey: "randomParticle") != nil {
            // Only applicable with player NPC
            
            let particle_node = gameScene?.node(name: "RandomParticle")
            particle_node?.particleSystems?.first?.birthRate = 30
            gameScene?.player.addChildNode(particle_node!)
            
        }
        if functions!.object(forKey: "prepareSingleAnimation") != nil {
            let name = functions!.object(forKey: "prepareSingleAnimation") as! String
            npc!.prepareSingleAnimation(animName: name)
        }
        
        //
        let delay = Double(functions!.object(forKey: "delay") as? String ?? "0.0") ?? 0.0
        let duration = Double(functions!.object(forKey: "duration") as? String ?? "0.0") ?? 0.0
        
        let animationBlock = SCNAction.run { theNode in
            //
            if functions!.object(forKey: "position!") != nil {
                npc?.removeAction(forKey: "owalk")
                npc?.removeAnimation(forKey: "owalk")
                
                // retrive node to get axis
                let posAxis = self.gameScene?.sceneView.scene?.rootNode.childNode(withName: functions!.object(forKey: "position!") as! String, recursively: true)?.worldPosition ?? SCNVector3Zero
                npc?.position = SCNVector3Make(posAxis.x, 0.0, posAxis.z)
                npc?.zroot.position = SCNVector3Make(0.0, posAxis.y, 0.0)
            }
            
            if functions!.object(forKey: "face!") != nil {
                npc?.removeAction(forKey: "owalk")
                npc?.removeAnimation(forKey: "owalk")
                self.gameScene?.faceNPC(npc: npc!, toPosition: functions!.object(forKey: "face!") as! String, animated: true)
            }
            if functions!.object(forKey: "face#") != nil {
                npc?.removeAction(forKey: "owalk")
                npc?.stop()
                self.gameScene?.faceNPC(npc: npc!, toPosition: functions!.object(forKey: "face#") as! String, animated: false)
            }
            if functions!.object(forKey: "facePlayer") != nil {
                // Only npc will face main player
                self.gameScene?.faceNPC(npc:npc!, toPosition: self.gameScene!.player.name!, animated: true)
            }
            if functions!.object(forKey: "faceEachOther") != nil {
                // Both will face eachother
                self.gameScene?.faceNPC(npc:npc!, toPosition: self.gameScene!.player.name!, animated: true)
                self.gameScene?.faceNPC(npc: self.gameScene!.player, toPosition: npc!.name!, animated: true)
            }
            if functions!.object(forKey: "headLook") != nil {
                let name = functions!.object(forKey: "headLook") as! String
                npc?.headLookTo(nodeName: name)
            }
            if functions!.object(forKey: "headLookRelease") != nil {
                npc?.headLookRelease()
            }
            if functions!.object(forKey: "exclamate") != nil {
                // Exclamate <Player will show exclamation mark on top>
                self.exclamate(onPlayer: npc!)
            }
            if functions!.object(forKey: "isHidden") != nil {
                npc?.isHidden = functions!.object(forKey: "isHidden") as! Bool
            }
            if functions!.object(forKey: "sfx") != nil {
                let cmd = functions!.object(forKey: "sfx") as! String
                self.gameScene?.sfx(name: cmd)
            }
            if functions!.object(forKey: "setEvent") != nil {
                let cmd = functions!.object(forKey: "setEvent") as! String
                npc?.registerEvent(eventId: cmd)
            }
            if functions!.object(forKey: "dissolve") != nil {
                npc?.dissolvePlayer(duration: duration)
                
            }
            if functions!.object(forKey: "showObject") != nil {
                let objectName = functions!.object(forKey: "showObject") as! String
                let node = npc!.childNode(withName: objectName, recursively: true)
                node?.isHidden = false
            }
            if functions!.object(forKey: "hideObject") != nil {
                let objectName = functions!.object(forKey: "hideObject") as! String
                let node = npc!.childNode(withName: objectName, recursively: true)
                node?.isHidden = true
            }
            if functions!.object(forKey: "runLoadedAnimation") != nil {
                // this command will be ignored, if no animation is prepared in "prepareSingleAnimation"
                npc!.runLoadedAnimation()
            }
            if functions!.object(forKey: "overrideAnimation") != nil {
                let name = functions!.object(forKey: "overrideAnimation") as! String
                npc!.overrideAnimation(anim: name)
            }
            
            //overrideAnimationWithSoundEvent(anim: String, sfxName: String, timing: Float)
            if functions!.object(forKey: "overrideAnimationWithSFX") != nil {
                let name = functions!.object(forKey: "overrideAnimationWithSFX") as! String
                let cmd = name.components(separatedBy: "/")
                if cmd.count > 0 {
                    let animstr = cmd[0]
                    let sfxName = cmd[1]
                    let timing = Float(cmd[2])!
                    let subjectNode = cmd[3]
                    let particleAction = cmd.last
                    
                    //overrideAnimationWithSoundEvent(anim: String, sfxName: String, timing: Float, subjectNodeName: String, particleAction: String?) {
                    
                    npc?.overrideAnimationWithSoundEvent(anim: animstr, sfxName: sfxName, timing: timing, subjectNodeName: subjectNode, particleAction: particleAction)
                    
                }
                //npc!.overrideAnimation(anim: name)
                
            }
            if functions!.object(forKey: "playPauseAnimation") != nil {
                let name = functions!.object(forKey: "playPauseAnimation") as! String
                npc!.playPauseSingleAnim(anim: name)
            }
            if functions!.object(forKey: "playSingleAnimation") != nil {
                let name = functions!.object(forKey: "playSingleAnimation") as! String
                npc?.prepareSingleAnimation(animName: name)
                npc!.runLoadedAnimation()
            }
            if functions?.object(forKey: "removeAnimation") != nil {
                let key = functions!.object(forKey: "removeAnimation") as! String
                npc!.removeAnimation(forKey: key, blendOutDuration: 0.2)
            }
            if functions?.object(forKey: "removeAllAnimations") != nil {
                let val = Float(functions?.object(forKey: "removeAllAnimations") as? String ?? "0.2") ?? 0.2
                npc!.removeAllAnimations(withBlendOutDuration: CGFloat(val))
            }
            if functions?.object(forKey: "removeAllActions") != nil {
                npc!.removeAllActions()
                npc?.zroot.removeAllActions()
            }
            if functions?.object(forKey: "setFacialExpression") != nil {
                let str = functions?.object(forKey: "setFacialExpression") as! String
                npc?.setFacialExpression(expression: str, blinkBeforeChanging: false)
            }
            if functions?.object(forKey: "setFacialExpression!") != nil {
                let str = functions?.object(forKey: "setFacialExpression!") as! String
                npc?.setFacialExpression(expression: str, blinkBeforeChanging: true)
            }
            
            if functions?.object(forKey: "quickJump") != nil {
                let jumpUp = SCNAction.moveBy(x: 0, y: 0.3, z: 0, duration: 0.12)
                jumpUp.timingMode = .easeOut
                let jumpDown = SCNAction.moveBy(x: 0, y: -0.3, z: 0, duration: 0.12)
                jumpDown.timingMode = .easeIn
                let jump = SCNAction.sequence([jumpUp, jumpDown])
                
                npc?.runAction(jump)
            }
            if functions?.object(forKey: "quickJump2") != nil {
                let jumpUp = SCNAction.moveBy(x: 0, y: 0.3, z: 0, duration: 0.12)
                jumpUp.timingMode = .easeOut
                let sfx1 = SCNAction.playAudio(SCNAudioSource(named: "ListenedGameAssets.scnassets/bgm/jump.wav")!, waitForCompletion: false)
                let jumpupComb = SCNAction.group([jumpUp, sfx1])
                let jumpDown = SCNAction.moveBy(x: 0, y: -0.3, z: 0, duration: 0.12)
                jumpDown.timingMode = .easeIn
                
                let jump = SCNAction.sequence([jumpupComb, jumpDown, jumpupComb, jumpDown])
                npc?.runAction(jump)
                
            }
            
            
            if functions?.object(forKey: "moveTo") != nil {
                let moveToAxsName = functions!.object(forKey: "moveTo") as? String
                if moveToAxsName != nil {
                    let toNode = self.gameScene?.node(name: moveToAxsName!)
                    let rootPos = SCNVector3Make(toNode!.worldPosition.x, 0.0, toNode!.worldPosition.z)
                    let zRootPos = SCNVector3Make(0.0, toNode!.worldPosition.y, 0.0)
                    
                    let rMoveAction = SCNAction.move(to: rootPos, duration: duration)
                    let zMoveAction = SCNAction.move(to: zRootPos, duration: duration)
                    
                    npc?.runAction(rMoveAction)
                    npc?.zroot.runAction(zMoveAction)
                    
                }
            }
            
            // Walk to point!! <Very Useful Animation>. This will be terminated if this event finishes
            if functions?.object(forKey: "walkTo") != nil {
                //player will face to that position and start walking towards that specific point
                let cmd = (functions?.object(forKey: "walkTo") as! String).components(separatedBy: "/")
                let axis = self.gameScene?.node(name: cmd.first!)
                
                // get walk speed
                let charProfile = (self.gameScene?.parentVC?.dat.object(forKey: "characterProfile") as! NSDictionary).object(forKey: npc!.name!) as! NSDictionary
                
                
                let walkSpeed = Float(charProfile.object(forKey: "walkSpeed") as! String)!
                
                // calculate duration
                let dist = self.gameScene?.pointDistF(p1: simd_float2(npc!.worldPosition.x, npc!.worldPosition.z), p2: simd_float2(axis!.worldPosition.x, axis!.worldPosition.z))
                let walkDuration = dist!/walkSpeed
                
                // face first
                self.gameScene?.faceNPC(npc: npc!, toPosition: (axis?.name)!, animated: true)
                
                // animations
                let nextPos = SCNVector3Make(axis!.worldPosition.x, 0.0, axis!.worldPosition.z)
                let walkAction = SCNAction.move(to: nextPos, duration: TimeInterval(walkDuration))
                
                print("walkTo>> nextPos:\(nextPos) dist\(String(describing: dist)) duration\(walkDuration)")
                
                // apply
                //npc?.walk(run: false)
                npc!.addAnimation(npc!.walkAnim, forKey: "owalk")
                npc!.runAction(walkAction, forKey: "owalk") {
                    //npc?.stop()
                    npc!.removeAnimation(forKey: "owalk", blendOutDuration: 0.2)
                }
                
            }
            
            if functions?.object(forKey: "runTo") != nil {
                //player will face to that position and start walking towards that specific point
                let cmd = (functions?.object(forKey: "runTo") as! String).components(separatedBy: "/")
                let axis = self.gameScene?.node(name: cmd.first!)
                // 1.3 <walk speed of normal character> 0.9 <walk speed of slow character>
                var walkSpeed:Double = 2.8//standard
                if cmd.count > 1 {
                    let wsStr = cmd[1]
                    walkSpeed = Double(wsStr)!
                }
                
                // calculate duration
                let dist = self.gameScene?.pointDistF(p1: simd_float2(npc!.worldPosition.x, npc!.worldPosition.z), p2: simd_float2(axis!.worldPosition.x, axis!.worldPosition.z))
                let walkDuration = dist!/Float(walkSpeed)
                
                // face first
                self.gameScene?.faceNPC(npc: npc!, toPosition: (axis?.name)!, animated: true)
                
                // animations
                let nextPos = SCNVector3Make(axis!.worldPosition.x, 0.0, axis!.worldPosition.z)
                let walkAction = SCNAction.move(to: nextPos, duration: TimeInterval(walkDuration))
                                
                // apply
                //npc?.walk(run: false)
                npc!.addAnimation(npc!.runAnim, forKey: "owalk")
                npc!.runAction(walkAction, forKey: "owalk") {
                    npc!.removeAnimation(forKey: "owalk", blendOutDuration: 0.2)
                }
                
            }
            
            if functions?.object(forKey: "climbUpTo") != nil {
                let cmd = functions?.object(forKey: "climbUpTo") as! String
                let ladderNode = self.gameScene!.node(name: cmd)
                npc?.climbTo(ladderNode: ladderNode, climbUp: true)
            }
            if functions?.object(forKey: "climbDownTo") != nil {
                let cmd = functions?.object(forKey: "climbDownTo") as! String
                let ladderNode = self.gameScene!.node(name: cmd)
                npc?.climbTo(ladderNode: ladderNode, climbUp: false)
            }
            
            // UNUSED
            if functions!.object(forKey: "resetOverridenAnim") != nil {
                self.gameScene?.player.removeAllAnimations()
                if let animKeys = self.gameScene?.player.animationKeys {
                    for _ in animKeys {
                        //self.gameScene?.player.removeAnimation(forKey: animKey, blendOutDuration: 0.2)
                    }
                }
            }
            //
        }
        
        let act_delay = SCNAction.wait(duration: delay)
        let finalizedAction = SCNAction.sequence([act_delay, animationBlock])
        gameScene?.player.runAction(finalizedAction)
        
    }
    
    func createInstantNPC(name: String) -> NPCNode {
        let newNpc = NPCNode(named: name)
        newNpc.gameSceneVC = self.gameScene
        // add to scene / register instance
        gameScene?.npcPlayers?.add(newNpc)
        gameScene?.sceneView.scene?.rootNode.addChildNode(newNpc)
        return newNpc
    }
    
    @objc
    @IBAction func nextBtnTapped(_ sender: Any?) {
        //
        var delay = 0.0
        //
        nextBtn.isEnabled = false;
        tapEllipse.isHidden = true
        tapEllipseCenter.isHidden = true
        
        // centerText is shown, slowly fade that out first before moving next
        if centerLineDisplay.alpha == 1 {
            delay = 1.0
            UIView.animate(withDuration: 1.0) {
                self.centerLineDisplay.alpha = 0.0
            }
        } else {
            // Play Tap Sound only when in Line mode, not Center Line Display.
            if sender != nil {
                let tap = self.gameScene?.parentVC?.tapSound;
                gameScene?.spriteScene?.run(tap!) // play tap sound
            }
            
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
            // run event
            eventPointer += 1; // add
            
            if currentEvent != nil {
                if eventPointer < currentEvent!.count {
                    runEvent()
                    return
                } else {
                    // no more next item <DISMISS>
                    
                    // always reset camera <no need to reset camera, is it is already standardCamera
                    if gameScene?.sceneView.pointOfView != gameScene?.standardCamera {
                        
                        if gameScene?.sceneView.pointOfView?.name != gameScene?.standardCamera.name {
                            UIView.animate(withDuration: 0.5, animations: {
                                self.gameScene?.sceneView.alpha = 0.0
                            }) { completed in
                                self.gameScene?.sceneView.pointOfView = self.gameScene?.standardCamera
                                self.gameScene?.resetCamAxisPosition()
                                UIView.animate(withDuration:0.5) {
                                    self.gameScene?.sceneView.alpha = 1.0
                                }
                            }
                        }
                        //
                    } else {
                        UIView.animate(withDuration:0.5) {
                            self.gameScene?.sceneView.alpha = 1.0
                        }
                    }
                    //
                    for bg in narrateTextAreaBG {
                        if bg is UIImageView {
                            (bg as! UIImageView).isHidden = true
                        }
                    }
                    textAreaBG.isHidden = true;
                    lineDisplay.isHidden = true;
                    // remove from view
                    self.dismiss(animated: true) {
                        self.gameScene?.isMapMove = false
                        self.gameScene?.frontNode = nil
                        self.gameScene?.setNpcControls(allow: true)
                        self.gameScene?.gameState = 0
                        self.gameScene?.parentVC?.fadeToBGM(bgmId: self.gameScene?.owBGM, duration: 0.5, volume: 1.0);
                        
                        // display area title
                        if let areaTitleString = areaTitle {
                            self.gameScene?.displayAreaTitle(titleString: areaTitleString)
                            self.areaTitle = nil
                        }
                        //self.gameScene?.sk?.showNotification(txt: "Saving Adventure...")
                    }
                    return
                    //
                }
            }
            //
            self.dismiss(animated: true) {
            }
            //
        }
        
    }
    
    @objc
    @IBAction func choiceTapped(_ sender: Any?) {
        
        let choiceBtn = sender as! UIButton
        self.gameScene?.spriteScene?.run((self.gameScene?.parentVC!.tapSound)!) // play tap sound
        
        if choiceBtn.accessibilityLabel != nil {
            
            // case 1 - Blank accessibility means no event. just close event
            if choiceBtn.accessibilityLabel == "" {
                closeEventControllerView()
                return
            } else {
                if choiceBtn.accessibilityLabel == nil {
                    closeEventControllerView()
                    return
                }
                
                // just moveToNext
                if choiceBtn.accessibilityLabel?.contains("next") == true {
                    eventPointer += 1; // add
                    if eventPointer < currentEvent!.count {
                        runEvent()
                    } else {
                        closeEventControllerView()
                    }
                    return
                }
                
                // shift to another event
                self.prepareEvent(event: choiceBtn.accessibilityLabel!)
            }
            
        }
        
        // check for another program
        if choiceBtn.accessibilityHint != nil {
            print("encounter start")
            self.encounter(enemyID: choiceBtn.accessibilityHint!)
        }
        
        // This is for Quiz Mode Choice
        if let answerValue = choiceBtn.accessibilityValue {
            //
            if answerValue == "YES" {
                playerAnswerChoiceTitle = choiceBtn.currentTitle
                self.qb_addCorrectSeq()
                eventPointer += 1; // add
                if eventPointer < currentEvent!.count {
                    runEvent()
                } else {
                    closeEventControllerView()
                }
                
            } else if answerValue == "NO" {
                playerAnswerChoiceTitle = choiceBtn.currentTitle
                choiceBtn.accessibilityValue = choiceBtn.titleLabel?.text
                self.qb_addWrongSeq()
                eventPointer += 1; // add
                if eventPointer < currentEvent!.count {
                    runEvent()
                } else {
                    closeEventControllerView()
                }
                
            } else {
                eventPointer += 1; // add
                if eventPointer < currentEvent!.count {
                    runEvent()
                } else {
                    closeEventControllerView()
                }
            }
            
        }
    }
    
    func closeEventControllerView() {
        
        gameScene?.spriteScene?.run((self.gameScene?.parentVC!.tapSound)!) // play tap sound
        
        // reset to default camera
        if gameScene?.sceneView.pointOfView != gameScene?.standardCamera {
            if gameScene?.sceneView.pointOfView?.name != gameScene?.standardCamera.name {
                UIView.animate(withDuration: 0.5, animations: {
                    self.gameScene?.sceneView.alpha = 0.0
                }) { completed in
                    self.gameScene?.resetCamAxisPosition()
                    self.gameScene?.sceneView.pointOfView = self.gameScene?.standardCamera
                    UIView.animate(withDuration:0.5) {
                        self.gameScene?.sceneView.alpha = 1.0
                    }
                }
            }
            //
        } else {
            UIView.animate(withDuration:0.5) {
                self.gameScene?.sceneView.alpha = 1.0
            }
        }
        //
        for bg in narrateTextAreaBG {
            if bg is UIImageView {
                (bg as! UIImageView).isHidden = true
            }
        }
        textAreaBG.isHidden = true;
        lineDisplay.isHidden = true;
        // remove from view
        self.dismiss(animated: true) {
            self.gameScene?.gameState = 0
            self.gameScene?.frontNode = nil
            self.gameScene?.setNpcControls(allow: true)
        }
        
    }
    
    
    
    // System
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .all
    }
    
    
    // Function Blocks
    func fadeToCam(cameraName: String) {
        // remove talk bar
        self.clearNarrator()
        textAreaBG.isHidden = true;
        lineDisplay.isHidden = true;
        
        // validate camera name
        let cameraNodeName = cameraName
        // set background color
        self.gameScene?.view.backgroundColor = UIColor.black
        // fade out
        UIView.animate(withDuration:1.0) {
            self.gameScene?.sceneView.alpha = 0.0
        } completion: { completed in
            // change camera
            self.gameScene?.setCamera(cameraNodeName: cameraNodeName, duration: 0.0)
            UIView.animate(withDuration:1.0) {
                // fade in
                self.gameScene?.sceneView.alpha = 1.0
            } completion: { completed in
            }
        }
    }
    
    func fadeToCam(cameraName: String, duration: Double) {
        // remove talk bar
        self.clearNarrator()
        textAreaBG.isHidden = true;
        lineDisplay.isHidden = true;
        
        // validate camera name
        let cameraNodeName = cameraName
        // set background color
        self.gameScene?.view.backgroundColor = UIColor.black
        // fade out
        let ldur = duration * 0.5
        
        UIView.animate(withDuration:ldur) {
            self.gameScene?.sceneView.alpha = 0.0
        } completion: { completed in
            // change camera
            self.gameScene?.setCamera(cameraNodeName: cameraNodeName, duration: 0.0)
            UIView.animate(withDuration:ldur) {
                // fade in
                self.gameScene?.sceneView.alpha = 1.0
            } completion: { completed in
            }
        }
    }
    
    @objc
    func bubbleAppear(layer:UIView) {
        
        layer.alpha = 0.0
        layer.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.2) {
            // scale up + fadein
            layer.alpha = 1.0
            layer.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        } completion: { completed in
            UIView.animate(withDuration: 0.2) {
                layer.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }
        }
    }
    
    @objc
    func sideAppear(layer:UIView) {
        
        layer.alpha = 0.0
        layer.transform = CGAffineTransform(translationX: 50, y: 0)
        
        UIView.animate(withDuration: 0.2) {
            // scale up + fadein
            layer.alpha = 1.0
            layer.transform = CGAffineTransform(translationX: 0, y: 0)
        }
        
    }
    
    
    // shake
    func shudder(node: SCNNode, rate: Float) {
        
        print("shudder called - node:", node)
        
        let anim = CABasicAnimation(keyPath: "eulerAngles")
        let rateAdj = rate * 0.08
        anim.duration = 0.06
        anim.timingFunction = CAMediaTimingFunction.init(name: .easeInEaseOut)
        anim.repeatCount = HUGE
        anim.autoreverses = true
        anim.fromValue = NSValue(scnVector3: SCNVector3Make(node.eulerAngles.x, node.eulerAngles.y + rateAdj, node.eulerAngles.z))
        anim.toValue = NSValue(scnVector3: SCNVector3Make(node.eulerAngles.x, node.eulerAngles.y - rateAdj, node.eulerAngles.z))
        
        node.addAnimation(anim, forKey: "shudder")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            node.removeAnimation(forKey: "shudder", blendOutDuration: 2.0)
        }
        
    }
    
    // will shake camera forever
    func shake(node: SCNNode, rate: Float) {
        
        let anim = CABasicAnimation(keyPath: "eulerAngles")
        let rateAdj = rate * 0.08
        anim.duration = 0.06
        anim.timingFunction = CAMediaTimingFunction.init(name: .easeInEaseOut)
        anim.repeatCount = HUGE
        anim.autoreverses = true
        anim.fromValue = NSValue(scnVector3: SCNVector3Make(node.eulerAngles.x, node.eulerAngles.y + rateAdj, node.eulerAngles.z))
        anim.toValue = NSValue(scnVector3: SCNVector3Make(node.eulerAngles.x, node.eulerAngles.y - rateAdj, node.eulerAngles.z))
        
        node.addAnimation(anim, forKey: "shake")
        
        // must remove via
        // node.removeAnimation(forKey: "shudder", blendOutDuration: 2.0)
    }
    
    // will shake camera forever
    func shakeAt(duration:CFTimeInterval, node: SCNNode, rate: Float, fadeInDuration:Float) {
        
        let anim = CABasicAnimation(keyPath: "eulerAngles")
        let rateAdj = rate * 0.08
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction.init(name: .easeInEaseOut)
        anim.repeatCount = HUGE
        anim.autoreverses = true
        anim.fromValue = NSValue(scnVector3: SCNVector3Make(node.eulerAngles.x, node.eulerAngles.y + rateAdj, node.eulerAngles.z))
        anim.toValue = NSValue(scnVector3: SCNVector3Make(node.eulerAngles.x, node.eulerAngles.y - rateAdj, node.eulerAngles.z))
        anim.fadeInDuration = CGFloat(fadeInDuration)
        node.addAnimation(anim, forKey: "shake")
        
        // must remove via
        // node.removeAnimation(forKey: "shudder", blendOutDuration: 2.0)
    }
    // a function where player reads the line out loud (playing mp3 file)
    func readLine(name: String) {
        //
        lineReadAction = SKAction.playSoundFileNamed("ListenedGameAssets.scnassets/bgm/line/\(name).mp3", waitForCompletion: false)
        
        self.gameScene?.spriteScene?.run(lineReadAction!)
        //
        
        //let audNode = SKAudioNode(fileNamed: "ListenedGameAssets.scnassets/bgm/line/\(name).mp3")
        
        
    }
    
    func loadLineSoundFile(name: String, isMp3: Bool) -> AVAudioPlayer {
        
        if eventSoundPlayer != nil {
            eventSoundPlayer?.stop()
        }
        
        if isMp3 == true {
            // mp3
            let url = Bundle.main.url(forResource: "ListenedGameAssets.scnassets/bgm/line/\(name)", withExtension: "mp3")
            if url != nil {
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)
                    eventSoundPlayer = try AVAudioPlayer(contentsOf: url!, fileTypeHint: AVFileType.mp3.rawValue)
                    eventSoundPlayer!.prepareToPlay()
                } catch  {
                    print("error")
                }
            }
            
        } else {
            // wav
            let url = Bundle.main.url(forResource: "ListenedGameAssets.scnassets/bgm/line/\(name)", withExtension: "wav")
            if url != nil {
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)
                    eventSoundPlayer = try AVAudioPlayer(contentsOf: url!, fileTypeHint: AVFileType.wav.rawValue)
                    eventSoundPlayer!.prepareToPlay()
                } catch  {
                    print("error")
                }
            }
        }
        return eventSoundPlayer!
    }
    
    func exclamate(onPlayer: NPCNode) {
        
        // exclamate/ show ! sign briefly on object
        let exclmNode = self.gameScene!.node(name: "exclamateNode") // Circle recommending user to tap on the button
        
        // set permanent position
        exclmNode.opacity = 0.0
        exclmNode.position = onPlayer.headTop.presentation.worldPosition
        exclmNode.renderingOrder = 10
        
        let prewait = SCNAction.wait(duration: 0.3)
        let prep = SCNAction.run { theNode in
            theNode.scale = SCNVector3Make(1.0, 1.0, 1.0)
            theNode.opacity = 1.0
            theNode.isHidden = false
            self.gameScene!.sfx(name: "exclamate.wav")
        }
        let scaleAction = SCNAction.scale(to: 2.0, duration: 0.3)
        let scaleDownAction = SCNAction.scale(to: 1.6, duration: 0.3)
        
        let wait = SCNAction.wait(duration: 0.7)
        let fade = SCNAction.fadeOut(duration: 0.7)
        let after = SCNAction.run { theNode in
            theNode.isHidden = true
            theNode.opacity = 0.0
        }
        let action = SCNAction.sequence([prewait, prep, scaleAction, scaleDownAction, wait, fade, after])
        
        exclmNode.runAction(action)
        
    }

}


extension String {

    var length: Int {
        return count
    }

    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}
