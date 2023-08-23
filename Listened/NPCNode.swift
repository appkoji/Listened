//
//  NPCNode.swift
//  AdvGame
//
//  Created by Koji Murata on 2022/03/06.
//

import Foundation
import SceneKit
import SpriteKit
import AVFoundation
import CoreImage
import GameController
import GameplayKit

class NPCNode: SCNNode {
    
    weak var gameSceneVC:GameScene?
    var isPlayer:Bool = false
    
    var npcName:String!
    var npcIdentifier:String?
    
    var zroot:SCNNode!
    var body:SCNNode!
    var front:SCNNode!
    var headTop:SCNNode!
    var neck:SCNNode?
    var head:SCNNode?
    var headTrack:SCNLookAtConstraint?
    
    // field enemy setting
    var enemyAxis:SCNNode?
    var playerDetectable:Bool = false;
    weak var target:NPCNode?
    
    // wander function
    var wanderState = 0
    var wanderCtr = 0
    var wander_destinationPoint = SCNVector3Zero
    var wanderWait = 1
    
    // required animations
    var walkAnim:CAAnimation!
    var runAnim:CAAnimation!
    
    var travelSpeed:Float = 0.08;
    var chasingSpeed:Float = 0.04
    var maxPenetration:CGFloat = 0.0;
    var repPos:SCNVector3 = SCNVector3(0,0,0);
    var hitWall:Bool = false;
    var loadedAnimation:CAAnimation?
    var detectGround:Bool = true
    var fallSpeed:Float = 0.0;
    
    var defFace:String?
    var faceMat:SCNMaterial?
    var talkMat:SCNMaterial?
    var currentFacialExpression:String?
    var npcTalkTimer:Timer?
    
    var splashNode:SCNNode?
    
    // step sound
    var stepGrass_land:SCNAction?
    
    // creature
    /// Variable enemy:  Default - false
    var enemy:Bool = false;
    
    /* NPC state:
        0:idle
        1:walking/searching
        2:chasing
        3:encountering
        4:Following
        5:Cliff hopping
        6.Surfing
        11:target lost
        99:invalidated
     */
    /// State of character 0:idle 5:CliffJumping
    var state:Int = 0;
    
    enum playerState: Int {
        case idle
        case walking
        case running
        case damaged
        case fainted
        case cutscene
    }
    
    func loadTxt(fileName:String) -> String {
        let filePath = Bundle.main.path(forResource: "ListenedGameAssets.scnassets/\(fileName)", ofType: "txt")
        return try! String(contentsOfFile: filePath!, encoding: .utf8)
    }
    
    // InIt Implementation
    override init() {
        super.init()
        print("override init")
    }
    
    init(geometry: SCNGeometry?) {
        super.init()
        self.geometry = geometry
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init has not been implemented")
    }
    
    init(named:String) {
        super.init()
        npcName = named
        let cs:Float = 0.7 // common scale
        
        guard let playerScene = SCNScene(named: "ListenedGameAssets.scnassets/Characters/\(named)/\(named)-idle.dae")
        else {
            fatalError("Fatal Error")
        }
        print("Running init loading<named>:\(named)")
        zroot = playerScene.rootNode.childNode(withName: "\(named)-MRoot", recursively: true)?.clone()
        
        let noiseTex = UIImage(named: "ListenedGameAssets.scnassets/noiseTexture.jpg")
        
        let currentScale:SCNVector3 = zroot.scale
        zroot.scale = SCNVector3Make(currentScale.x*cs, currentScale.y*cs, currentScale.z*cs)
        
        self.name = named
        
        self.position = SCNVector3Zero
        zroot.position = SCNVector3Zero
        self.addChildNode(zroot)
        zroot.removeAllAnimations()
        
        // load player physics
        zroot.enumerateHierarchy { (node, nil) in
            
            if let nodeName = node.name {
                if node.geometry != nil {
                    
                    // run material for brightness adjustment
                    for mat in node.geometry!.materials  {
                        
                        mat.lightingModel = .physicallyBased
                        mat.selfIllumination.contents = UIColor.gray
                        mat.selfIllumination.intensity = 1.0
                        mat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment: normalShineFrag()]
                        mat.metalness.contents = UIColor.black
                        mat.roughness.contents = UIColor.lightGray
                        
                        // add noise revealage
                        mat.setValue(SCNMaterialProperty(contents: noiseTex), forKey: "noiseTexture")
                        //mat.setValue(SCNMaterialProperty(contents: Float(1.0)), forKey: "revealage")
                        mat.setValue(Float(1.0), forKey: "revealage")
                        let modifierString = self.loadTxt(fileName: "dissolve-fragment")
                        mat.shaderModifiers = [
                            SCNShaderModifierEntryPoint.fragment : modifierString
                        ]
                        
                        // assign material
                        if let matName = mat.name {
                            if matName.contains("FaceMat") || matName.contains("Face") {
                                faceMat = mat
                            } else if matName.contains("TalkMat") || matName.contains("Mouth") {
                                talkMat = mat
                            } else if matName.contains("TagMat") {
                                let imageName = matName.components(separatedBy: "-")[1]
                                mat.diffuse.contents = UIImage(named: "ListenedGameAssets.scnassets/\(imageName).jpg")
                                mat.diffuse.mappingChannel = 0
                                mat.transparent.contents = UIImage(named: "ListenedGameAssets.scnassets/alphaGradient.png")
                                mat.transparent.mappingChannel = 1
                                //
                                mat.diffuse.intensity = 1.0;
                                mat.isDoubleSided = true
                                mat.writesToDepthBuffer = false
                                mat.transparency = 1.0
                                mat.blendMode = .add
                            }
                        }
                    }
                    
                    if nodeName.contains("OW") == true {
                                                
                        var characterSphereSize:CGFloat = 0.3
                        
                        if self.name?.contains("Zack") == false {
                            characterSphereSize = 0.45
                        }
                        
                        node.physicsBody = SCNPhysicsBody(type: .kinematic, shape: .init(geometry: SCNSphere(radius: characterSphereSize), options: [:]))
                        node.physicsBody?.categoryBitMask = 2;
                        self.body = node;
                        
                        
                    } else if nodeName.contains("EW") == true {
                        
                        let characterSphereSize:CGFloat = 0.2
                        
                        node.physicsBody = SCNPhysicsBody(type: .kinematic, shape: .init(geometry: SCNSphere(radius: characterSphereSize), options: [:]))
                        node.physicsBody?.categoryBitMask = 2;
                        self.body = node;
                        
                    } else if nodeName.contains("detector") == true {
                        node.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(node: node, options: [SCNPhysicsShape.Option.type : SCNPhysicsShape.ShapeType.convexHull]))
                        node.physicsBody?.categoryBitMask = 2;
                        self.front = node;
                        self.front.opacity = 0.0
                    } else if nodeName.contains("HeadTop") == true {
                        self.headTop = node;
                    } else if nodeName.contains("uvMoveObj") == true {
                        self.headTop = node;
                    } else {
                        node.isHidden = true
                    }
                }
            }
        }
        
        self.head = zroot.childNode(withName: "Neck", recursively: true)
        self.neck = zroot.childNode(withName: "HeadTracking", recursively: true)
        self.headTop = zroot.childNode(withName: "HeadTop", recursively: true)
        
        walkAnim = loadAnimation(animName: "walk")
        walkAnim.fadeInDuration = 0.4
        runAnim = loadAnimation(animName: "run", speed: 1.0)
        runAnim.fadeInDuration = 0.4
        
        // grass step run sound effect
        
        //        let stepGrass_run_L = SCNAudioSource(fileNamed: "ListenedGameAssets.scnassets/bgm/step0.wav")
        
        let stepGrass_run_L = SKAction.playSoundFileNamed("ListenedGameAssets.scnassets/bgm/step0.wav", waitForCompletion: false)
        
        let stepGrass_run_R = SKAction.playSoundFileNamed("ListenedGameAssets.scnassets/bgm/step1.wav", waitForCompletion: false)
        
        // wood step sound effect
        let stepWood_Walk = SCNAudioSource(fileNamed: "ListenedGameAssets.scnassets/bgm/woodWalkB.wav")
        
        let stepWood_run_L = SCNAudioSource(fileNamed: "ListenedGameAssets.scnassets/bgm/step-wood-1.wav")
        
        let stepWood_run_R = SCNAudioSource(fileNamed: "ListenedGameAssets.scnassets/bgm/step-wood-1.wav")
        
        // water step run sound effect
        let stepWater_run_L = SKAction.playSoundFileNamed("ListenedGameAssets.scnassets/bgm/step-water-1.wav", waitForCompletion: false)
        //SCNAudioSource(fileNamed: "ListenedGameAssets.scnassets/bgm/step-water-1.wav")
        
        let stepWater_run_R = SKAction.playSoundFileNamed("ListenedGameAssets.scnassets/bgm/step-water-1.wav", waitForCompletion: false)
        //SCNAudioSource(fileNamed: "ListenedGameAssets.scnassets/bgm/step-water-1.wav")
        
        // extra sound
        if stepGrass_run_L != nil {
            //stepGrass_land = SCNAction.playAudio(stepGrass_run_L!, waitForCompletion: false)
        }
        
        // load nodes first
        splashNode = scnFX(name: "splashSprite")
        self.gameSceneVC?.sceneView.scene?.rootNode.addChildNode(splashNode!)
        self.gameSceneVC?.sceneView.prepare([splashNode], completionHandler: { comp in
            print("prepared splash node")
        })
        
        // For WALKING
        let step1wlk = SCNAnimationEvent(keyTime: 0.3) { (animation, object, playingBackwards) in
            
            let node = object as! SCNNode
            let playerSteppingOn = self.gameSceneVC?.getObjectWherePlayerIsOn(npc: self)
            
            if node.animationPlayer(forKey: "walk") != nil {
                // alternate play step audio
                if let stepping = playerSteppingOn {
                    if stepping.contains("wtr") == true {
                        //self.runAction(SCNAction.playAudio(stepWater_run_L!, waitForCompletion: true))
                        self.gameSceneVC?.spriteScene?.run(stepWater_run_L)
                        self.step_waterFX()
                    } else if stepping.contains("wood") == true {
                        self.runAction(SCNAction.playAudio(stepWood_Walk!, waitForCompletion: true))
                    } else {
                        self.gameSceneVC?.spriteScene?.run(stepGrass_run_L)
                        //self.runAction(SCNAction.playAudio(stepGrass_run_L!, waitForCompletion: true))
                        //self.gameSceneVC?.spriteScene?.run(d)
                    }
                }
            }
        }
        let step2wlk = SCNAnimationEvent(keyTime: 0.8) { (animation, object, playingBackwards) in
            
            let node = object as! SCNNode
            let playerSteppingOn = self.gameSceneVC?.getObjectWherePlayerIsOn(npc: self)
            
            if node.animationPlayer(forKey: "walk") != nil {
                
                // play step audio
                if let stepping = playerSteppingOn {
                    if stepping.contains("wtr") == true {
                        //self.runAction(SCNAction.playAudio(stepWater_run_R!, waitForCompletion: true))
                        self.gameSceneVC?.spriteScene?.run(stepWater_run_R)
                        self.step_waterFX()
                    } else if stepping.contains("wood") == true {
                        self.runAction(SCNAction.playAudio(stepWood_Walk!, waitForCompletion: true))
                    } else {
                        self.gameSceneVC?.spriteScene?.run(stepGrass_run_R)
                        //self.runAction(SCNAction.playAudio(stepGrass_run_R!, waitForCompletion: true))
                    }
                }
                
                
            }
        }
        
        // For RUNNING
        let step1 = SCNAnimationEvent(keyTime: 0.3) { (animation, object, playingBackwards) in
                        
            let node = object as! SCNNode
            let playerSteppingOn = self.gameSceneVC?.getObjectWherePlayerIsOn(npc: self)
            
            if node.animationPlayer(forKey: "run") != nil {
                // alternate play step audio
                if let stepping = playerSteppingOn {
                    if stepping.contains("wtr") == true {
                        //self.runAction(SCNAction.playAudio(stepWater_run_L!, waitForCompletion: true))
                        self.gameSceneVC?.spriteScene?.run(stepWater_run_L)
                        self.step_waterFX()
                    } else if stepping.contains("wood") == true {
                        self.runAction(SCNAction.playAudio(stepWood_run_L!, waitForCompletion: true))
                    } else {
                        self.gameSceneVC?.spriteScene?.run(stepGrass_run_L)
                        //self.runAction(SCNAction.playAudio(stepGrass_run_L!, waitForCompletion: true))
                    }
                }
            }
        }
        let step2 = SCNAnimationEvent(keyTime: 0.8) { (animation, object, playingBackwards) in
            
            let node = object as! SCNNode
            let playerSteppingOn = self.gameSceneVC?.getObjectWherePlayerIsOn(npc: self)
            
            if node.animationPlayer(forKey: "run") != nil {
                
                // play step audio
                if let stepping = playerSteppingOn {
                    if stepping.contains("wtr") == true {
                        //self.runAction(SCNAction.playAudio(stepWater_run_R!, waitForCompletion: true))
                        self.gameSceneVC?.spriteScene?.run(stepWater_run_R)
                        self.step_waterFX()
                    } else if stepping.contains("wood") == true {
                        self.runAction(SCNAction.playAudio(stepWood_run_R!, waitForCompletion: true))
                    } else {
                        self.gameSceneVC?.spriteScene?.run(stepGrass_run_R)
                        //self.runAction(SCNAction.playAudio(stepGrass_run_R!, waitForCompletion: true))
                    }
                }
            }
        }
                
        // Facial Expression
        currentFacialExpression = "ふつう"
        
        if self.name?.contains("Zack") == true {
            //
            isPlayer = true
            walkAnim.animationEvents = [step1wlk, step2wlk]
            runAnim.animationEvents = [step1, step2]
        }
        
    }
    
    func headLookTo(nodeName:String) {
        
        // setup headTracking
        if self.neck != nil {
            
            if self.headTrack == nil {
                // if nil, add constraint
                let lookAt = SCNLookAtConstraint(target: nil)
                lookAt.isGimbalLockEnabled = true
                //lookAt.worldUp = (self.gameSceneVC?.sceneView.scene?.rootNode.worldUp)!
                lookAt.influenceFactor = 1.0
                self.headTrack = lookAt
                self.neck!.constraints = [lookAt]
            }
            
        }
        
        // Turn heads, detect if it is a NPC
        var targetNpc:NPCNode?
        
        let possibleNPCNode = self.gameSceneVC?.sceneView.scene?.rootNode.childNode(withName: nodeName , recursively: true)
        if possibleNPCNode != nil {
            targetNpc = possibleNPCNode as? NPCNode
        }
                
        if let target = targetNpc {
            // is a NPC or Player
            
            let opHead = target.neck
            self.headTrack?.target = opHead
            
            if self.headTrack?.target == nil {
                self.headTrack?.target = target.head
            }
            if self.headTrack?.target == nil {
                self.headTrack?.target = target.headTop
            }
            if self.headTrack?.target == nil {
                self.headTrack?.target = target.body
            }
            
            
        } else {
            // object
            let node = self.gameSceneVC?.sceneView.scene?.rootNode.childNode(withName: nodeName, recursively: true)
            if node != nil {
                self.headTrack?.target = node!
            }
        }
        
        print("Headlook called neck:\(self.neck) const:\(headTrack) target:\(headTrack?.target)")
        
    }
    
    func headLookRelease() {
        if self.headTrack != nil {
            self.headTrack?.target = nil
        }
    }
    
    func step_waterFX() {
        //
        let splashSprite = splashNode?.clone()
        splashSprite?.setValue("dtl", forKey: "3dsprite")
        splashSprite?.position = self.realWorldPosition()
        // if walk,
        if self.animationKeys.contains(["walk"]) == true {
            splashSprite?.scale = SCNVector3(x: 0.7, y: 0.2, z: 0.7)
            let nd = splashSprite?.childNode(withName: "splashSprite_1", recursively: true)
            nd?.geometry?.firstMaterial?.transparency = 0.15
            //nd?.isHidden = true
        }
        
        self.gameSceneVC?.sceneView.scene?.rootNode.addChildNode(splashSprite!)
        
        let wait = SCNAction.wait(duration: 4.0)
        let block = SCNAction.run { subjNode in
            //let child = subjNode.childNodes
            
            subjNode.removeFromParentNode()
        }
        let paction = SCNAction.sequence([wait, block])
        splashSprite?.runAction(paction)
    }
    
    func scnFX(name:String) -> SCNNode {
        guard let footSplash = SCNScene(named: "ListenedGameAssets.scnassets/\(name).scn")
        else {
            fatalError("Fatal Error")
        }
        return footSplash.rootNode
    }
    
    func convertToEnemy(isPlayerDetectable: Bool){
        
        self.playerDetectable = isPlayerDetectable
        
        if let npcName = self.body.name {
            self.body.name = npcName.replacingOccurrences(of: "OW", with: "EW")
        }
        
        if isPlayerDetectable == true {
            let detectionCamera = SCNCamera()
            detectionCamera.usesOrthographicProjection = false
            detectionCamera.focalLength = CGFloat(28.972)
            detectionCamera.fieldOfView = CGFloat(60)
            detectionCamera.sensorHeight = CGFloat(24)
            detectionCamera.zNear = Double(0.5)
            detectionCamera.zFar = Double(2.0)
            
            if neck != nil {
                neck?.camera = detectionCamera
            } else {
                head?.camera = detectionCamera
            }
            
            print("detectionCameraAdded \(String(describing: head?.camera))")
        }
        
    }
    
    func dissolvePlayer(duration: CFTimeInterval?) {
        
        self.state = 99;
        // Display something around it
        
        let revealAnimation = CABasicAnimation(keyPath: "revealage")
        revealAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        revealAnimation.duration = duration ?? 2.5
        revealAnimation.fromValue = 1.0
        revealAnimation.toValue = 0.0
        
        let scnRevealAnimation = SCNAnimation(caAnimation: revealAnimation)
        scnRevealAnimation.isRemovedOnCompletion = false
                
        zroot.enumerateHierarchy { (node, nil) in
            if node.geometry != nil {
                for mat in node.geometry!.materials  {
                    
                    mat.addAnimation(scnRevealAnimation, forKey: "Dissolve")
                    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + duration!) {
                        mat.setValue(Float(0.0), forKey: "revealage")
                    }
                }
            }
        }
        
        let fadeOut = SCNAction.fadeOut(duration: 0.3)
        let wait = SCNAction.wait(duration: 2.0)
        self.runAction(SCNAction.sequence([wait, fadeOut]))
        
    }
    
    func talk() {
        var seq = 0
        npcTalkTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true, block: { [self] timer in
            
            if self.currentFacialExpression == "おこる" || self.currentFacialExpression == "ぎもん" || self.currentFacialExpression == "おどろく" || self.currentFacialExpression == "こわい" {
                
                if seq == 0 {
                    talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.25, 0.25, 0.0)
                } else if seq == 1 {
                    talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.5, 0.25, 0.0)
                } else if seq == 2 {
                    talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.25, 0.25, 0.0)
                } else if seq == 3 {
                    talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.0, 0.25, 0.0)
                    seq = -1
                }
                
            } else {
                if seq == 0 {
                    talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.25, 0.0, 0.0)
                } else if seq == 1 {
                    talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.5, 0.0, 0.0)
                } else if seq == 2 {
                    talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.25, 0.0, 0.0)
                } else if seq == 3 {
                    talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.0, 0.0, 0.0)
                    seq = -1
                }
            }
            
            seq += 1
        })
        npcTalkTimer!.fire()
    }
    
    func stopTalk() {
        npcTalkTimer?.invalidate()
        
        if self.currentFacialExpression == "おこる" || self.currentFacialExpression == "ぎもん" || self.currentFacialExpression == "おどろく" || self.currentFacialExpression == "こわい" {
            self.talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.0, 0.25, 0.0)
            
        } else {
            self.talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.0, 0.0, 0.0)
        }
        
    }
    
    func setFacialExpression(expression:String, blinkBeforeChanging:Bool) {
        
        currentFacialExpression = expression
        var delay = Double(0.0)
        
        if blinkBeforeChanging == true {
            delay = Double(0.15)
            self.faceMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.25, 0.0, 0.0);
            self.talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.0, 0.0, 0.0);
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.currentFacialExpression == "ふつう" {
                self.faceMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.0, 0.0, 0.0);
                self.talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.0, 0.0, 0.0);
            }
            if self.currentFacialExpression == "まばたき" {
                self.faceMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.25, 0.0, 0.0);
            }
            if self.currentFacialExpression == "うれしい" {
                self.faceMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.5, 0.0, 0.0);
                self.talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.5, 0.0, 0.0);
            }
            if self.currentFacialExpression == "けつい" {
                self.faceMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.75, 0.0, 0.0);
                self.talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.0, 0.25, 0.0);
            }
            if self.currentFacialExpression == "おこる" {
                self.faceMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.0, 0.25, 0.0);
            }
            if self.currentFacialExpression == "ぎもん" {
                self.faceMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.25, 0.25, 0.0);
            }
            if self.currentFacialExpression == "おどろく" {
                self.faceMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.5, 0.25, 0.0);
                self.talkMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.5, 0.25, 0.0);
            }
            if self.currentFacialExpression == "こわい" {
                self.faceMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.75, 0.25, 0.0);
            }
            if self.currentFacialExpression == "かなしい" {
                self.faceMat?.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.25, 0.5, 0.0);
            }
        }
    }
    
    func expressionPattern(name: String) {
        
        if name == "shocked" {
            self.setFacialExpression(expression: "おどろく", blinkBeforeChanging: true)
        }
        
    }
    
    func realWorldPosition () -> SCNVector3 {
        return SCNVector3Make(self.presentation.worldPosition.x, self.zroot.presentation.worldPosition.y, self.presentation.worldPosition.z)
    }
    
    func goTo(pos: SCNVector3) {
        // Y-UP axis
        print("player - axis \(pos)")
        self.position = SCNVector3Make(pos.x, 0.0, pos.z)
        zroot?.position = SCNVector3Make(0.0, pos.y, 0.0)
    }
    
    func goTo(axis: SCNNode) {
        // Y-UP axis
        let pos = axis.worldPosition
        self.goTo(pos: pos)
        // this will face to the angle where node is facing
        print("player\(self.name) goToAxis\(axis) facing npc to angle y:\(axis.eulerAngles.y) deg:")
    }
    
    func walkTo(point: SCNVector3) {
        
        //(name: nodeName).worldPosition ?? nextPos!
        
        // get walk speed
        let charProfile = (self.gameSceneVC?.parentVC?.dat.object(forKey: "characterProfile") as! NSDictionary).object(forKey: npcName as Any) as! NSDictionary
        
        let walkSpeed = Float(charProfile.object(forKey: "walkSpeed") as! String)!
        
        // calculate duration
        let dist = self.gameSceneVC?.pointDistF(p1: simd_float2(self.worldPosition.x, self.worldPosition.z), p2: simd_float2(point.x, point.z))
        let walkDuration = dist!/walkSpeed
        
        // face first
        _ = face(axis: point, duration: 0.3)
        
        // animations
        let nextPos = SCNVector3Make(point.x, 0.0, point.z)
        let walkAction = SCNAction.move(to: nextPos, duration: TimeInterval(walkDuration))
        
        print("walkTo>> nextPos:\(nextPos) dist\(String(describing: dist)) duration\(walkDuration)")
        
        // apply
        walk(run: false)
        addAnimation(walkAnim, forKey: "owalk")
        self.runAction(walkAction, forKey: "owalk") {
            self.removeAnimation(forKey: "owalk", blendOutDuration: 0.2)
            self.wanderState = 3
        }
    }
    
    func climbTo(ladderNode:SCNNode, climbUp: Bool) {
        
        // player should not detect ground at this point
        detectGround = false
        
        // get climb speed
        let charProfile = (self.gameSceneVC?.parentVC?.dat.object(forKey: "characterProfile") as! NSDictionary).object(forKey: npcName as Any) as! NSDictionary

        let climbSpeed = Float(charProfile.object(forKey: "climbSpeed") as! String)!
        
        let p1 = GLKVector3Make(worldPosition.x, zroot.worldPosition.y, worldPosition.z) // current point
        let p2 = GLKVector3Make(ladderNode.worldPosition.x, ladderNode.worldPosition.y, ladderNode.worldPosition.z)
        let dist = GLKVector3Distance(p1, p2)
        
        // get duration
        let duration = dist/climbSpeed
        
        // Player should start at that certain height
        var anim:CAAnimation?
        
        if climbUp == true {
            anim = loadAnimation(animName: "climpUp")
        } else {
            anim = loadAnimation(animName: "climbDown")
        }
        
        // face
        let rotateAction = SCNAction.rotateTo(x: 0, y: CGFloat(ladderNode.eulerAngles.y), z: 0, duration: 0.2)
        self.runAction(rotateAction)
        
        // get destination point
        
        let nextPos = SCNVector3Make(0, p2.y, 0)
        let action = SCNAction.move(to: nextPos, duration: TimeInterval(duration))
        print("climbTo>> nextPos:\(nextPos) dist\(String(describing: dist)) duration\(duration)")
        
        // apply
        addAnimation(anim!, forKey: "oclimb") //animation will be added to player itself
        // zroot will run the action because oclimb, since it deals with y-axis movement. self only deals with x,z
        zroot.runAction(action, forKey: "oclimb") {
            self.removeAnimation(forKey: "oclimb", blendOutDuration: 0.2)
            self.wanderState = 3
            self.detectGround = true
        }
        
        
    }
    
    func face(axis: SCNVector3, duration: Double) -> Float {
        let pt2 = gameSceneVC?.shaders.pointAngleFrom(p1: self.presentation.position, p2: axis)
        self.runAction(SCNAction.rotateTo(x: 0, y: CGFloat(pt2!), z: 0, duration: duration))
        return pt2!
    }
    
    func face_instantly(axis: SCNVector3) -> Float {
        let pt2 = gameSceneVC?.shaders.pointAngleFrom(p1: self.presentation.position, p2: axis)
        self.runAction(SCNAction.rotateTo(x: 0, y: CGFloat(pt2!), z: 0, duration: 0.0))
        return pt2!
    }
    
    /// face to absolute angle using shortestUnitArc. The to: value 0 is left. 1 is back. 2 is right. and others are all down.
    func face(to:Int, duration:TimeInterval) {
        var rad = Float(0.0)
        if to == 0 {
            //Left
            rad = GLKMathDegreesToRadians(-90)
        } else if to == 1 {
            //Back
            rad = GLKMathDegreesToRadians(-180)
        } else if to == 2 {
            //Right
            rad = GLKMathDegreesToRadians(+90)
        } else {
            //Down
            rad = GLKMathDegreesToRadians(0)
        }
        
        self.runAction(SCNAction.rotateTo(x: 0, y: CGFloat(rad), z: 0, duration: duration, usesShortestUnitArc: true))
        
    }
    
    func walk(run: Bool) {
                
        if run == true {
            
            if self.animationKeys.contains("run") == true {
                return
            }
            removeAnimation(forKey: "walk", blendOutDuration: CGFloat(0.25));
            self.addAnimation(runAnim, forKey: "run")
            
        } else {
            
            if self.animationKeys.contains("walk") == true {
                return
            }
            removeAnimation(forKey: "run", blendOutDuration: CGFloat(0.25));
            self.addAnimation(walkAnim, forKey: "walk")
            
            
        }
    }
    
    func stop() {
        
        if self.animationKeys.contains("run") == true {
            self.removeAnimation(forKey: "run", blendOutDuration: CGFloat(0.5));
        }
        if self.animationKeys.contains("walk") == true {
            self.removeAnimation(forKey: "walk", blendOutDuration: CGFloat(0.35));
        }
        
    }
    
    func stopAnimAction(){
        
        if self.hasActions == true {
            self.removeAllActions()
        }
        
        if self.animationKeys.count > 0 {
            self.removeAllAnimations()
        }
        
    }
    
    func registerEvent(eventId: String) {
        if eventId == "" {
            // fail safe
            body.accessibilityLabel = nil
        } else {
            body.accessibilityLabel = eventId
        }
    }
    
    func prepareSingleAnimation(animName: String) {
        loadedAnimation = nil
        loadedAnimation = loadSingleAnimation(animName: animName)
    }
    
    func runLoadedAnimation() {
        if loadedAnimation != nil {
            self.addAnimation(loadedAnimation!, forKey:nil)
        } else {
            print("ERROR! animation was not pre-loaded")
        }
    }
    
    func overrideAnimation(anim: String) {
        
        self.removeAllAnimations()
        let animation = self.loadAnimation(animName: anim)
        self.addAnimation(animation!, forKey: "overrideAnimation")
        
    }
    
    /// anim:(nameOfAnimation)/sfxName:(nameOfSFX with extension)/timing:(timing when animation action occur in the animation)/subjectNodeName:(node name where positional sfx will be applied)/particleAction:(nodeNameWith specific particle|time:birthrate;time:birthrate;...)
    func overrideAnimationWithSoundEvent(anim: String, sfxName: String, timing: Float, subjectNodeName: String, particleAction: String?) {
        
        self.removeAllAnimations()
        let animation = self.loadAnimation(animName: anim)
        
        if animation == nil {
            return
        }
        //  add positional sound
        var sfx:SCNAudioPlayer?
        if let source = SCNAudioSource(fileNamed: "ListenedGameAssets.scnassets/bgm/\(sfxName)")
        {
            source.volume = 1.5
            source.rate = 1.0
            source.reverbBlend = 10.0
            source.isPositional = true
            source.shouldStream = false
            source.loops = true
            source.load()
            sfx = SCNAudioPlayer(source: source)
        }
        
        // get subject node
        let subjNode = self.gameSceneVC?.sceneView.scene?.rootNode.childNode(withName: subjectNodeName, recursively: true)
        
        if sfx != nil {
            // process sfx to animation event
            
            let animEvent = SCNAnimationEvent(keyTime: CGFloat(timing)) { (animation, object, playingBackwards) in
                
                if let source = SCNAudioSource(fileNamed: "ListenedGameAssets.scnassets/bgm/\(sfxName)")
                {
                    source.volume = 1.5
                    source.rate = 1.0
                    source.reverbBlend = 10.0
                    source.isPositional = true
                    source.shouldStream = false
                    source.loops = false
                    source.load()
                    
                    let audioPlayer = SCNAudioPlayer(source: source)
                    if let nodeToPlayAudio = subjNode {
                        nodeToPlayAudio.addAudioPlayer(audioPlayer)
                    }
                }
                
                // get particle
                if let pname = particleAction {
                                        
                    //particle command "particleName|time:birthRate;time:birthRate"
                    // e.g lightFuseParticle|0.0:200;4.4:0.0
                    let pcmd = pname.components(separatedBy: "|")
                    let particleName = pcmd[0]
                    
                    let particle = self.gameSceneVC?.sceneView.scene?.rootNode.childNode(withName: particleName, recursively: true)?.particleSystems?.first
                    
                    if particle != nil {
                        
                        // remove first before adding
                        subjNode?.removeAllParticleSystems()
                        subjNode?.addParticleSystem(particle!)
                                                
                        if pcmd.count > 0 {
                            
                            let timingFunction = pcmd[1]
                            let keyFrames = timingFunction.components(separatedBy: ";")
                            
                            if keyFrames.count > 0 {
                                
                                for singleKeyFrame in keyFrames {
                                    
                                    let aframe = singleKeyFrame.description.components(separatedBy: ":")
                                    
                                    if aframe.count > 0 {
                                        let time = TimeInterval(aframe[0])!
                                        let birthRateDat = Float(aframe[1])!
                                        let birthRate = CGFloat(birthRateDat)
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
                                            particle?.birthRate = birthRate
                                        })
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            animation!.animationEvents = [animEvent]
        }
        
        self.addAnimation(animation!, forKey: "overrideAnimation")

    }
    
    // Plays animation only once and pauses at the last frame without removing after completion.
    func playPauseSingleAnim(anim: String) {
        
        let animExtName = "\(npcName!)-\(anim)-1"
        let assetUrl = "ListenedGameAssets.scnassets/Characters/\(npcName!)/\(npcName!)-\(anim)"
        let url = Bundle.main.url(forResource: assetUrl, withExtension: "dae")
        if url != nil {
            let scnSource = SCNSceneSource(url: url!, options: nil)
            let animation = scnSource?.entryWithIdentifier(animExtName, withClass: CAAnimation.self)
            animation?.fadeInDuration = 0.2
            animation?.fadeOutDuration = 0.2
            animation?.repeatCount = 0
            animation?.speed = 1.0
            animation?.isRemovedOnCompletion = false
            
            self.addAnimation(animation!, forKey: "playPauseAnim")
            // this animation will apply
        }
        
    }
    
    // This animation is designed to play continuously
    func loadAnimation(animName: String) -> CAAnimation? {
        
        let animExtName = "\(npcName!)-\(animName)-1"
        let assetUrl = "ListenedGameAssets.scnassets/Characters/\(npcName!)/\(npcName!)-\(animName)"
        let url = Bundle.main.url(forResource: assetUrl, withExtension: "dae")
        let scnSource = SCNSceneSource(url: url!, options: nil)
        let animation = scnSource?.entryWithIdentifier(animExtName, withClass: CAAnimation.self)
        animation?.fadeInDuration = 0.15
        animation?.fadeOutDuration = 0.2
        //animation?.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation?.repeatCount = HUGE
        animation?.speed = 1.0
        
        return animation
    }
    
    /// create animation instance only
    func loadAnimation(animName: String, speed: Float) -> CAAnimation? {
        let animExtName = "\(npcName!)-\(animName)-1"
        let assetUrl = "ListenedGameAssets.scnassets/Characters/\(npcName!)/\(npcName!)-\(animName)"
        let url = Bundle.main.url(forResource: assetUrl, withExtension: "dae")
        let scnSource = SCNSceneSource(url: url!, options: nil)
        let animation = scnSource?.entryWithIdentifier(animExtName, withClass: CAAnimation.self)
        animation?.fadeInDuration = 0.1
        animation?.fadeOutDuration = 0.1
        animation?.repeatCount = HUGE
        animation?.speed = speed
        return animation
    }
    
    // This animation is design to play once.
    func loadSingleAnimation(animName: String) -> CAAnimation? {
        let animExtName = "\(npcName!)-\(animName)-1"
        let assetUrl = "ListenedGameAssets.scnassets/Characters/\(npcName!)/\(npcName!)-\(animName)"
        let url = Bundle.main.url(forResource: assetUrl, withExtension: "dae")
        
        if url == nil {
            return nil
        }
        
        let scnSource = SCNSceneSource(url: url!, options: nil)
        let animation = scnSource?.entryWithIdentifier(animExtName, withClass: CAAnimation.self)
        animation?.fadeInDuration = 0.0
        animation?.fadeOutDuration = 0.2
        animation?.repeatCount = 0
        animation?.isRemovedOnCompletion = true
        animation?.speed = 1.0
        return animation
    }
    
    func normalShineFrag() -> String {
        return "float3 origP = _surface.position;\n" +
        "float3 n = _surface.normal;\n" +
        "float3 p = float3(origP.x,origP.y+0.5,origP.z);\n" +
        "float3 v = normalize(-p);\n" +
        "float vdn = 1.0 - max(dot(v,n), 0.0);\n" +
        "float3 shdrOutput = float3(smoothstep(0.2,0.99, vdn));\n" +
        "float3 currentRgb = _output.color.rgb;\n" +
        "_output.color.rgb = currentRgb + (shdrOutput*0.05);\n";
    }
    
    /// updates this NPC
    var counter = 0
    
    func wanderMap() {
        
        if self.state != 1 {
            return
        }
        if wanderState == 0 {
            // stop... get next point
            wander_destinationPoint = getWanderRandomPt(radius: 2)
            wanderCtr = 0 //reset wander counter
            wanderWait = Int.random(in: 0 ..< 10)
            
            wanderState = 1; // move state
        }
        if wanderState == 1 {
            // wait before moving
            //print("wanderState 1")
            if wanderCtr >= 25 + wanderWait {
                // count under
                wanderState = 2
            }
            
        }
        if wanderState == 2 {
            // walk FIRE!
            chasePoint()
            wanderState = 10
        }
        if wanderState == 3 {
            // STOP!! remove animation and remove from wander
            self.stopAnimAction()
            wanderState = 0; // reset to find next point
        }
        if wanderState == 5 {
            // Go back to designated point
            wanderState = 6; // reset to find next point
            walkTo(point: enemyAxis!.worldPosition)
            
        }
        if wanderState == 10 {
            // enemy is walking
            chasePoint()
        }
        // keep counting
        wanderCtr += 1; // start counting
    }
    
    func warpTo(position: SCNVector3) {
        
        // set position
        self.goTo(axis: enemyAxis!)
        self.rotation = SCNVector4Zero
        
        // wait for few seconds
        let wait = SCNAction.wait(duration: 10.0)
        let run = SCNAction.run { node in
            self.opacity = 1.0
            self.state = 12
            self.detectGround = true
        }
        let seq = SCNAction.sequence([wait,run])
        self.runAction(seq)
        
        // store scale value, scale down to zero
        //let originalScale = self.scale
        
        //self.scale.y = 0.0
        
        // scale up action
        //let scaleUp = SCNAction.scale(by: CGFloat(originalScale.y), duration: 0.5)
        //let fade = SCNAction.fadeIn(duration: 0.5)
        //let grp = SCNAction.group([scaleUp, fade])
        
        /*
        self.runAction(grp) {
            
            self.detectGround = true
            self.state = 12
            //self.wanderState = 3
        }
         */
        
        //print("warpEnemy toAxis:\(enemyAxis) - scaleY:\(scaleUp)")
    }
    
    /// gets wander point
    func getWanderRandomPt(radius: Float) -> SCNVector3{
        
        let anchor = simd_float2((enemyAxis?.position.x)!, (enemyAxis?.position.z)!)
        let xVal = Float.random(in: anchor.x - radius ..< anchor.x + radius)
        let yVal = Float.random(in: anchor.y - radius ..< anchor.y + radius)
        return SCNVector3Make(xVal, 0, yVal)
        
    }
    
    // search for player in camera
    func searchPlayer(sceneView: SCNView) {
        
        let playerBody = self.gameSceneVC?.player.body
        
        if playerBody == nil {
            return
        }
        
        var playerDetected = false
        let detector:SCNNode = neck ?? head!
        
        let detectedItems = sceneView.nodesInsideFrustum(of: detector)
        for node in detectedItems {
            if node == playerBody {
                
                // hit test first to confirm if player is not hidden behind stones or walls
                let options :[String: Any] = [SCNHitTestOption.firstFoundOnly.rawValue: true]
                if let hitResults = sceneView.scene?.rootNode.hitTestWithSegment(from: detector.worldPosition, to: playerBody!.worldPosition, options: options) {
                    if ((hitResults.first?.node.name?.contains("Kenny")) != nil) {
                        playerDetected = true
                    }
                }
                break;
            }
        }
        
        if playerDetected == true {
            // This is when EnemyNPC will recogize Player
            self.stopAnimAction()
            state = 100
            counter = 0
            target = self.gameSceneVC!.player
            _ = face_instantly(axis: (target?.realWorldPosition())!)
            self.gameSceneVC?.sfx(name: "shock.wav")
            let jumpAction = jump()
            self.runAction(jumpAction) {
                self.state = 2 // chase state
            }
        }
        
    }

    // check if player is still in sight
    func checkTarget(sceneView: SCNView) {
        
        let playerBody = self.gameSceneVC?.player.body
        
        if playerBody == nil {
            return
        }
        
        var playerDetected = false
        
        /*
        let detector:SCNNode = neck ?? head!
        let detectedItems = sceneView.nodesInsideFrustum(of: detector)
        for node in detectedItems {
            if node == playerBody {
                // check if enemy is visible within the camera
                if let pointOfView = sceneView.pointOfView {
                    let isMaybeVisible = sceneView.isNode(self.body, insideFrustumOf: pointOfView)
                    playerDetected = true
                    break;
                }
                
            }
        }*/
        
        let dist = self.worldPosition.distance(to: target!.worldPosition)
        
        if dist < 5.0 {
            // if more than 4.0 distance, lost target
            playerDetected = true
        }
        
        if playerDetected == false {
            // lost target
            target = nil
            state = 0
        }
        
    }
    
    // jump
    func jump() -> SCNAction {
        let jumpUp = SCNAction.moveBy(x: 0, y: 0.25, z: 0, duration: 0.12)
        jumpUp.timingMode = .easeOut
        let jumpDown = SCNAction.moveBy(x: 0, y: -0.25, z: 0, duration: 0.12)
        jumpDown.timingMode = .easeIn
        let jump = SCNAction.sequence([jumpUp, jumpDown])
        return jump
    }
    
    // chase
    func chasePoint() {
        self.walk(run: false)
        let cAngle = face(axis: wander_destinationPoint, duration: 0.1)
        let dAngle = self.gameSceneVC?.shaders.degrees(radians: cAngle)
        
        let y = 0 + 1 * cos((self.gameSceneVC?.shaders.radians(degrees: dAngle!))!)
        let x = 0 + 1 * sin((self.gameSceneVC?.shaders.radians(degrees: dAngle!))!)
        let point = CGPoint(x: Double(x * 0.02), y: Double(y * 0.02))
        
        let moveAction = SCNAction.moveBy(x: point.x, y: 0.0, z: point.y, duration: 1/60)
        
        if self.hitWall == true {
            self.position = SCNVector3Make(self.repPos.x, 0.0, self.repPos.z)
            //self.wanderState = 3
            self.wanderState = 5 // if hit wall, go back to
        }
        
        let dist = self.gameSceneVC?.pointDistF(p1: simd_float2(self.worldPosition.x, self.worldPosition.z), p2: simd_float2(wander_destinationPoint.x, wander_destinationPoint.z))
        if dist! < 0.3 {
            self.wanderState = 3
        }
        
        self.runAction(moveAction)
    }
    
    func chaseTarget() {
                
        if target != nil {
                        
            // run
            self.walk(run: true)
            
            if self.state == 2 {
                // chasing
                self.opacity = 1.0
                //chasingSpeed = Float(0.04)
            }
            if self.state == 19 {
                self.opacity = 0.1
                //chasingSpeed = Float(0.4)
            }
            
            let cAngle = face_instantly(axis: (target?.realWorldPosition())!)
            let dAngle = self.gameSceneVC?.shaders.degrees(radians: cAngle)
                        
            let y = 0 + 1 * cos(GLKMathDegreesToRadians(dAngle!))
            let x = 0 + 1 * sin(GLKMathDegreesToRadians(dAngle!))
            
            let point = CGPoint(x: Double(x * chasingSpeed), y: Double(y * chasingSpeed))
            
            let moveAction = SCNAction.moveBy(x: point.x, y: 0.0, z: point.y, duration: 1/60)
            
            if self.hitWall == true {
                self.position = SCNVector3Make(self.repPos.x, 0.0, self.repPos.z)
            }
            
            self.runAction(moveAction)
            
        } else {
            self.state = 11
        }
    }
    
    /* Chase function can be used both for enemies chasing down protagonist, and characters following other characters at for some event...
    */
    
    func wallDetect(plyr:NPCNode, contact:SCNPhysicsContact) {
        
        let adj:CGFloat = CGFloat(plyr.travelSpeed * 10)
        if plyr.maxPenetration > contact.penetrationDistance { //本当は、contact.penetrationDistance
            return
        }
                
        plyr.maxPenetration = contact.penetrationDistance * adj
        var characterPos:vector_float3 = vector_float3(plyr.position)
        var posOffset:vector_float3 = vector_float3(contact.contactNormal)
        posOffset.x = contact.contactNormal.x * Float((contact.penetrationDistance * adj))
        posOffset.y = 0
        posOffset.z = contact.contactNormal.z * Float((contact.penetrationDistance * adj))
        characterPos += posOffset
        plyr.repPos = SCNVector3(characterPos)
        plyr.hitWall = true
                
    }
    
    /// UPDATE() Function
    func update(sceneView:SCNView) {
        
        //print("NPC:\(name) target:\(target?.name) state:\(self.state) gameState:\(gameSceneVC?.gameState)")
        
        if self.enemy == true {
            
            if self.playerDetectable == true && self.gameSceneVC?.gameState == 0 {
                
                self.hitWall = false
                self.maxPenetration = 0.0
                
                // Idle State
                if self.state == 0 {
                    self.stop()
                    self.wanderState = 0
                    self.state = 1 // switch to searching state...
                }
                
                // Searching State
                if self.state == 1 {
                    
                    // run search script. detect if there are enemy in this scene
                    searchPlayer(sceneView: sceneView)
                    
                    let contacts = sceneView.scene!.physicsWorld.contactTest(with: self.body.physicsBody!, options: [SCNPhysicsWorld.TestOption.collisionBitMask : self.gameSceneVC!.collisionMeshBitMask])
                    
                    for contact in contacts {
                        if let nodeName = contact.nodeB.name {
                            if (nodeName.contains("wall") || nodeName.contains("enemyblock")) && contact.nodeB.isHidden == false && contact.nodeB.opacity > 0.0 {
                                self.wallDetect(plyr: self, contact: contact)
                            }
                        }
                    }
                    wanderMap()
                    counter = 0
                }
                
                // Detected -> Start chasing player
                if self.state == 2 {
                    
                    let contacts = sceneView.scene!.physicsWorld.contactTest(with: self.body.physicsBody!, options: [SCNPhysicsWorld.TestOption.collisionBitMask : self.gameSceneVC!.collisionMeshBitMask])
                    
                    for contact in contacts {
                        if let nodeName = contact.nodeB.name {
                            if (nodeName.contains("wall") || nodeName.contains("EW") || nodeName.contains("enemyblock")) && contact.nodeB.isHidden == false && contact.nodeB.opacity > 0.0 {
                                self.wallDetect(plyr: self, contact: contact)
                            }
                        }
                    }
                    
                    // chase
                    chaseTarget()
                    
                    counter += 1
                    
                    // recount every 1.0 seconds
                    if counter >= 60 {
                        checkTarget(sceneView: (self.gameSceneVC?.sceneView!)!)
                    }
                    
                }
                
                // Caught/Encountering
                if self.state == 3 {
                    // encountering/
                    self.goTo(axis: enemyAxis!)
                    self.rotation = SCNVector4Zero
                }
                
                // Lost but question mark
                if self.state == 3 {
                    // encountering/
                    self.goTo(axis: enemyAxis!)
                    self.rotation = SCNVector4Zero
                }
                
                // Target Lost
                if self.state == 11 {
                    // lost state
                    counter = 0
                    self.state = 12
                }
                
                // Recover to Idle State
                if self.state == 12 {
                    // recover
                    counter += 1
                    if counter >= 30 {
                        self.state = 0;
                    }
                }
                //
                
                if self.state == 99{
                    // set destination back to main postion
                }
                if self.state == 100{
                    // blank state. does nothing. use this for brief timing
                    counter += 1
                    if counter >= 30 {
                        self.state = 2;
                    }
                }
                // Warp to start position again
                if self.state == 777 {
                    self.state = 778
                    self.detectGround = false
                    self.zroot.removeAllActions()
                    self.zroot.position.y = 0.0
                    // lost state
                    self.stopAnimAction()
                    counter = 0
                    self.opacity = 0.0
                    // reset position
                    self.warpTo(position: enemyAxis!.worldPosition)
                    
                    
                }
                //
            }
            return
        }
        
        else if self.enemy == false {
            
            if name == "Zack" {
                return
            }
            
            // if in event, stop player from walking (expect owalk)
            if self.gameSceneVC?.gameState == 1 || self.gameSceneVC?.gameState == 2 {
                self.stop()
                return
            }
                        
            if self.gameSceneVC?.gameState == 0  && self.target != nil {
                
                // non enemy with chase characteristic
                self.hitWall = false
                self.maxPenetration = 0.0
                
                if self.state == 0 {
                    // state when NPC gets too close to another player
                    self.stop()
                    self.state = 1 // switch to waiting state...
                    self.opacity = 1.0
                    return
                }
                
                // actively finding
                if self.state == 1 {
                    
                    // Only activate distance calculation when controller is tapped
                    if self.gameSceneVC?.tapped == false {
                        return
                    }
                    
                    // calculate distance only when player is moving, and too far
                    let dist = self.worldPosition.distance(to: target!.worldPosition)
                    
                    if dist > 1.0 {
                        self.state = 2
                    }
                    return
                }
                
                // chase
                if self.state == 2 {
                    
                    // if paused, no need to calculate distance between player and
                    if self.isPaused == true {
                        return
                    }
                    
                    
                    // Detect wall for chasing player
                    var contacts = sceneView.scene?.physicsWorld.contactTest(with: self.body.physicsBody!, options: [SCNPhysicsWorld.TestOption.collisionBitMask : self.gameSceneVC!.collisionMeshBitMask])
                    
                    if contacts != nil {
                        for contact in contacts! {
                            if let nodeName = contact.nodeB.name {
                                if (nodeName.contains("wall")) && contact.nodeB.isHidden == false && contact.nodeB.opacity > 0.0 {
                                    self.wallDetect(plyr: self, contact: contact)
                                }
                                if (nodeName.contains("Kenny")) {
                                    self.state = 0
                                }
                            }
                        }
                    }
                    
                    
                    var dist:Float = 0.0
                    
                    
                    // calculate distance only when player is moving, and too far
                    DispatchQueue.background(background: { [weak self] in
                        // do something in background
                        dist = self!.worldPosition.distance(to: self!.target!.worldPosition)
                        
                    }, completion:{
                        // when background job finished, do something in main thread
                        if dist > 3.0 {
                            self.state = 19
                        }
                    })
                    
                    contacts = nil
                    
                    // chase
                    chaseTarget()
                    return
                }
                
                // Too far, thus will warp close to Target
                if self.state == 19 {
                    
                    self.state = -1 // nil state to ensure this command run only once
                    
                    // stop running
                    self.stop()
                    
                    // get closest position to player
                    let tp = target?.realWorldPosition()
                    
                    let cAngle = face_instantly(axis: (target?.realWorldPosition())!)
                    let dAngle = self.gameSceneVC?.shaders.degrees(radians: cAngle)
                                
                    let y = 0 + 1 * cos(GLKMathDegreesToRadians(dAngle!))
                    let x = 0 + 1 * sin(GLKMathDegreesToRadians(dAngle!))
                    
                    let relPt = simd_float2(x: x*0.3, y: y*0.3)
                    let destPos = SCNVector3(x: tp!.x - relPt.x, y: 0.0, z: tp!.z - relPt.y)
                    
                    let origScale = self.scale
                    self.opacity = 0.0
                    self.scale = SCNVector3Zero
                    
                    // set relative position
                    self.position.x = destPos.x
                    self.zroot.position.y = tp!.y
                    self.position.z = destPos.z
                    
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.2
                    SCNTransaction.completionBlock = {
                        self.state = 0;
                    }
                    self.opacity = 1.0
                    self.scale = origScale
                    SCNTransaction.commit()
                    /*
                    let move = SCNAction.run { node in
                        node.position.x = destPos.x
                        node.position.y = destPos.y
                        node.opacity = 1.0
                        node.simdScale = origScale
                    }
                    
                    self.runAction(move) {
                        self.zroot.position.y = tp!.y
                    }*/
                    
                    
                    
                }
                
                
            }
            else if self.gameSceneVC?.gameState == 1 {
                
            }
            
            
            
        }
        
    }
    
}

extension SCNVector3 {
     func distance(to vector: SCNVector3) -> Float {
         return simd_distance(simd_float3(self), simd_float3(vector))
     }
 }

extension DispatchQueue {

    static func background(delay: Double = 0.0, background: (()->Void)? = nil, completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            background?()
            if let completion = completion {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: {
                    completion()
                })
            }
        }
    }

}
