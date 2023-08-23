//
//  GameScene.swift
//  AdvGame
//
//  Created by Koji Murata on 6/30/20.
//

import Foundation
import SceneKit
import SpriteKit
import AVFoundation
import CoreImage
import GameController


class GameScene: UIViewController, SCNSceneRendererDelegate, UIGestureRecognizerDelegate, SCNPhysicsContactDelegate {
    
    // OUTLETS
    @IBOutlet var sceneView: SCNView!
    
    @IBOutlet var aButton:UIButton!
    @IBOutlet var menuButton:UIButton!
    @IBOutlet var aBtnTapEllipse:UIImageView!
    @IBOutlet var loadingSprites:UIImageView!
    @IBOutlet var areaTitlingView:UIView!
    @IBOutlet var atBG1:UIImageView!
    @IBOutlet var atBG2:UIImageView!
    @IBOutlet var areaTitle:UILabel!
    
    // Sprite
    var spriteScene:SKScene?
    var notificationText:SKLabelNode?
    
    // Input values
    var currentGameData:NSDictionary!
    var playerLastPosition:String!
    
    // External Class
    var parentVC:ViewController?
    var eventCtrl:EventController!
    var shaders:AdvShader!
    var sk:SKGameScene?
    var player = NPCNode()
    var gameMenu:InGameMenuController!
    
    // Reference Scene
    var igaScene:SCNScene!
    
    let npcPlayers:NSMutableArray? = NSMutableArray()
    var angleCorrection:Float = 0.0;
    var camAxis:SCNNode!
    var frontNode:SCNNode?
    
    
    // Camera Functions
    var standardCamera:SCNNode!
    
    // 360 camera
    var allows360Cam:Bool! = false
    var cameraPan:Float! = 0.0
    var cameraPanIndex:simd_float2! = simd_float2(0.0, 0.0)
    var isPanning:Bool! = false
    var rPadTapPoint: CGPoint! = CGPoint.zero
    var rAngle:Float! = 0.0
    var distConst:SCNDistanceConstraint?
    
    // D-Pad
    var allowNpcControls: Bool! = false
    var tapped: Bool! = false
    var tapPoint: CGPoint! = CGPoint.zero
    var dpadAngle: Float! = 0.0
    var dpadDistance: Float! = 0.0
    var playerIsMoving: Bool! = false
    var walkSpeedPercent:Float = 0.0
    
    // Misc
    var mapProfile:NSDictionary?
    var texIntensity:CGFloat = 0.25 // default
    var eventTriggerAfterMapMove:String? // Mostly nil, but some event will be triggered automatically
    var owBGM:String?
    var isMapMove:Bool! = false
    var randomEncount:NSDictionary?
    var randomEncountCounter = 0
    let groundMeshBitMask = 0x4;
    let collisionMeshBitMask = 2;
    
    /// gameState 0:Normal field user playable / 1:Encounter / 2:Event / 3:Loading
    var gameState = 3
    
    // Map files
    var map:SCNScene? // "game map file" instance that SceneKit will open to load game map
    let maps = ["Map0","Map1","Map2","Map3","Map4","Map5"] // names of all game maps available in the game
    
    //
    //------------------- Area Titling
    func displayAreaTitle(titleString: String) {
        
        sk?.showAreaTitle(txt: titleString)
        
        // start_line
        areaTitlingView.alpha = 0.0
        areaTitlingView.isHidden = true
        //
        areaTitle.alpha = 0.0
        atBG1.alpha = 0.0
        atBG1.transform = CGAffineTransform.init(translationX: +200, y: 0)
        atBG2.alpha = 0.0
        atBG2.transform = CGAffineTransform.init(translationX: +200, y: 0)
        areaTitle.text = titleString
        areaTitlingView.alpha = 1.0
        areaTitlingView.isHidden = false
        //
        UIView.animate(withDuration: 0.4, delay: 0.0, options: [.beginFromCurrentState, .curveEaseOut]) {
            self.atBG1.alpha = 1.0
            self.atBG1.transform = CGAffineTransform.init(translationX: 0, y: 0)
        }
        UIView.animate(withDuration: 0.5, delay: 0.2, options: .curveEaseOut) {
            self.atBG2.alpha = 1.0
            self.atBG2.transform = CGAffineTransform.init(translationX: 0, y: 0)
        } completion: { completed in
            // fade in text
            UIView.animate(withDuration: 1.0) {
                self.areaTitle.alpha = 1.0
            } completion: { comp in
                //
                UIView.animate(withDuration: 0.5, delay: 2.0, options: []) {
                    self.areaTitle.alpha = 0.0
                } completion: { comp2 in
                    UIView.animate(withDuration: 0.4, delay: 0.0, options: .curveEaseIn) {
                        self.atBG2.alpha = 0.0
                        self.atBG2.transform = CGAffineTransform.init(translationX: 300, y: 0)
                    }
                    UIView.animate(withDuration: 0.3, delay: 0.15, options: .curveEaseIn) {
                        self.atBG1.alpha = 0.0
                        self.atBG1.transform = CGAffineTransform.init(translationX: 300, y: 0)
                    } completion: { comp3 in
                        self.areaTitlingView.isHidden = true
                    }
                }
            }
        }
    }
    
    //
    //------------------- Main Game Func
    
    func deviceConfig() {
        
        let deviceDetail = UIDevice().userInterfaceIdiom
        let deviceClass = UIDevice.deviceClass
        
        if deviceDetail == .phone {
            
            if deviceClass == "1" {
                // New Device
                sceneView.contentScaleFactor = 1.5;
            } else if deviceClass == "2" {
                // Performance Based
                sceneView.contentScaleFactor = 1.5;
            } else {
                sceneView.contentScaleFactor = 1.5;
            }
        } else if deviceDetail == .pad {
            if deviceClass == "1" {
                // Highest
                sceneView.contentScaleFactor = 1.75;
            } else if deviceClass == "2" {
                // Optimized
                sceneView.contentScaleFactor = 1.5;
            } else {
                sceneView.contentScaleFactor = 1.25;
            }
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.ObserveForGameControllers()
        
        // Load Default Scenes
        let scene = SCNScene(named: "ListenedGameAssets.scnassets/GameScene.scn")!
        camAxis = scene.rootNode.childNode(withName: "camAxis", recursively: true) // find camera axis from the loaded scene
        igaScene = SCNScene(named: "ListenedGameAssets.scnassets/InGameActions.scn")!
        
        // INITIALIZE CLASSES
        shaders = AdvShader()
        shaders.parentVC = self;
        shaders.fogColor = scene.fogColor as! UIColor
        shaders.fogNear = scene.fogStartDistance
        shaders.fogFar = scene.fogEndDistance
        
        eventCtrl = self.storyboard?.instantiateViewController(identifier: "EventController")
        eventCtrl.gameScene = self;
        eventCtrl.sceneFunctions = shaders
        
        sk = SKGameScene()
        sk?.parentVC = self;
        
        gameMenu = self.storyboard?.instantiateViewController(identifier: "InGameMenuController")
        gameMenu.gameVC = self
        
        
        // Scenekit Config
        sceneView.scene = scene;
        sceneView.scene?.isPaused = true;
        sceneView.alpha = 0.0
        
        // Change Resolution Depending on User Device iPhone
        //self.deviceConfig()
        self.sceneView.contentScaleFactor = 1.75
        
        
        
        // SET loading sprites
        var spriteImageNo = 1
        var spriteImages = [UIImage]()
        while spriteImageNo <= 24 {
            let spImg = UIImage(named: String(format: "%04d", spriteImageNo))
            if spImg != nil {
                spriteImages.append(spImg!)
                spriteImageNo += 1
            } else {
                break;
            }
        }
        
        loadingSprites.animationImages = spriteImages
        loadingSprites.startAnimating()
        
        self.view.isUserInteractionEnabled = true;
        
        // LOAD SAVE
        // Get Current Progress from save data to see last position/event
        playerLastPosition = parentVC?.tempPlayerData["lastPosition"] as? String
        let playerLastProgress = parentVC?.tempPlayerData["gameProgress"] as! String
        
        if playerLastPosition == "" {
            // from *moveMap*
            self.currentGameData = (parentVC?.dat.object(forKey: "loadGame") as! NSDictionary).object(forKey: playerLastProgress) as? NSDictionary
            playerLastPosition = self.currentGameData.object(forKey: "entryAxis") as? String
        } else {
            if playerLastPosition == "10" { // 10 means transfer between maps from cutscene
                playerLastPosition = self.parentVC!.gameScene.currentGameData.object(forKey: "entryAxis") as? String
            }
        }
        
        // FIND AXIS from MAPS (.dae world file)
        var foundInMap = ""
        for map in maps {
            var tempLoadedArea = SCNScene(named: "ListenedGameAssets.scnassets/\(map).dae")
            if tempLoadedArea!.rootNode.childNode(withName: playerLastPosition, recursively: true) != nil {
                foundInMap = map
                tempLoadedArea = nil
                break;
            }
            tempLoadedArea = nil
        }
        
        
        // PREPARE 3D SCENE
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            
            if self.view.tag == 0 {
                self.view.tag = 1;
                
                self.spriteScene = SKScene(fileNamed: "mainSprite")
                self.sceneView.overlaySKScene = self.spriteScene
                self.spriteScene?.isUserInteractionEnabled = false
                self.spriteScene?.anchorPoint = CGPoint(x: 0.0, y: 1.0)
                self.sk?.spriteSceneDidLoad()
                self.spriteScene?.isPaused = false
                
                self.notificationText = self.spriteScene?.childNode(withName: "sk_notificationText") as? SKLabelNode
                
                // remove all geometries from igaScene
                self.igaScene.rootNode.enumerateChildNodes { node, stop in
                    //node.geometry = nil
                }
                
                self.sceneView.prepare([scene, self.igaScene!]) { completed in
                    self.player = NPCNode(named: "Zack")
                    self.player.gameSceneVC = self
                    self.sceneView.alpha = 0.0
                    
                    // Set Current Map Profile
                    self.mapProfile = (self.parentVC?.dat.object(forKey: "mapProfile") as! NSDictionary).object(forKey: foundInMap) as? NSDictionary
                    
                    self.loadScene(areaName: foundInMap)
                }
            }
        }
    }
        
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        if aBtnTapEllipse.tag == 0 {
            aBtnTapEllipse.tag = 1
            aBtnTapEllipse.layer.compositingFilter = "addBlendMode"
            aBtnTapEllipse.layer.add(shaders.pulseAnim(), forKey: "pulse")
        }
        
    }
    
    
    // Load scene from file.  This function only runs once *REQUIRED
    func loadScene(areaName: String) {
        
        // load battleField
        let battleFieldArea = SCNScene(named: "ListenedGameAssets.scnassets/BattleField.dae")!
        shaders.cleanUpScene(scene: battleFieldArea)
        
        // LOAD Map File (.dae)
        let area = SCNScene(named: "ListenedGameAssets.scnassets/\(areaName).dae")!
        shaders.cleanUpScene(scene: area)
        
        randomEncount = nil
        
        map = area
        
        //  SETUP SCENE CAMERA
        self.allows360Cam = mapProfile?.object(forKey: "enabled360Cam") as? Bool ?? false
        
        if self.allows360Cam == true {
            
            standardCamera = node(name: "followCamPlyr")
            sceneView.pointOfView = standardCamera
            
            // setup audio for -> camPlayerPers
            let audioCam = node(name: "camPlayerPers")
            sceneView.audioListener = audioCam
            
            // change axis top height depending on map setting
            if let axisHeightConfig = mapProfile?.object(forKey: "3DCamAxisHeight") {
                let val = axisHeightConfig as! String
                let refAxis = node(name: "axisTop")
                refAxis.position.y = Float(val)!
            }
            
            // change max distance to player
            if let axisHeightConfig = mapProfile?.object(forKey: "3DCamDistance") {
                let val = axisHeightConfig as! String
                let dist = Float(val)!
                // get constraint
                if let constIn3dCam = standardCamera.constraints {
                    for const in constIn3dCam {
                        if const is SCNDistanceConstraint {
                            distConst = (const as! SCNDistanceConstraint)
                            distConst!.minimumDistance = CGFloat(dist)
                            distConst!.maximumDistance = CGFloat(dist)
                        }
                    }
                }
            }
            
            standardCamera.camera?.zFar = 800
            sceneView.contentScaleFactor = 1.5
            sceneView.antialiasingMode = .multisampling2X
            
            // configure a constraint to maintain a constant altitude relative to the character
            let lowest = abs(standardCamera!.simdWorldPosition.y) + 1.5

            weak var weakSelf = self
            
            // keep non
            let avoidOcclude = SCNAvoidOccluderConstraint(target: node(name: "axisTop2"))
            //avoidOcclude.occluderCategoryBitMask = 2
            avoidOcclude.bias = 0.000000000000000000001
            avoidOcclude.influenceFactor = 0.000001
            avoidOcclude.isIncremental = true
            standardCamera.constraints?.append(avoidOcclude)
            
            
            // keep altitude
            let keepAltitude = SCNTransformConstraint.positionConstraint(inWorldSpace: true, with: {(_ node: SCNNode, _ position: SCNVector3) -> SCNVector3 in
                guard let strongSelf = weakSelf else { return position }
                var position = simd_float3(position)
                if self.player.zroot != nil {
                    position.y = strongSelf.player.zroot.presentation.position.y + lowest
                }
                return SCNVector3( position )
            })
            keepAltitude.isIncremental = true
            keepAltitude.influenceFactor = 0.01
            standardCamera.constraints?.append(keepAltitude)
            
        } else {
            
            sceneView.contentScaleFactor = 1.0
            sceneView.antialiasingMode = .multisampling2X
            
            node(name: "followCamPlyr").constraints = nil
            node(name: "followCamPlyr").removeFromParentNode()
            standardCamera = node(name: "camera")
            sceneView.pointOfView = standardCamera
            sceneView.audioListener = standardCamera
        }
        
                        
        // configure random enemy encounter func
        randomEncount = mapProfile?.object(forKey: "randomEncount") as? NSDictionary
        
        let defaultProfileKey = mapProfile?.object(forKey: "sceneProfile") // Get default map scene profile
        var profile = (parentVC?.dat.object(forKey: "sceneProfile") as! NSDictionary).object(forKey: defaultProfileKey!) as! NSDictionary // setup profile
        
        // add eventBased profile
        let sceneProgSet = mapProfile?.object(forKey: "sceneProgressSetting") as? Array<NSDictionary>
        
        let gameProg = self.parentVC?.tempPlayerData["gameProgress"] as? String
        
        if sceneProgSet != nil {
            for spItem in sceneProgSet! {
                
                let eventValue = spItem.object(forKey: "eventValue") as? String
                
                if eventValue != nil {
                    if eventValue! == gameProg {
                        if spItem.object(forKey: "sceneProfile") != nil {
                            let currentEventProfileKey = spItem.object(forKey: "sceneProfile") // Get default map scene profile
                            profile = (parentVC?.dat.object(forKey: "sceneProfile") as! NSDictionary).object(forKey: currentEventProfileKey!) as! NSDictionary
                        }
                    }
                }
            }
        }
        
        // apply
        self.shaders.setupSceneProfile(profileDat: profile)
        
        sceneView.scene?.rootNode.addChildNode(battleFieldArea.rootNode.clone());
        sceneView.scene?.rootNode.addChildNode(map!.rootNode.clone());
        
        // Load Map Profile DEFAULT        
        let owProg = self.parentVC?.tempPlayerData["overworld_progress"] as? [String]
        if owProg != nil {
            for strVal in owProg! {
                let strString = strVal
                print("Overworld Progress READ -> \(strString)")
                // check if these items exists in this map, and remove from scene
                let owProgNode = self.sceneView.scene?.rootNode.childNode(withName: strString, recursively: true)
                owProgNode?.isHidden = true // hide node that already gone through progress
            }
        }
        
        // reset eventTriggerAfterMapMove
        eventTriggerAfterMapMove = nil
        // get runEvent number from plist
        let gameDatas:NSDictionary = self.parentVC?.dat.object(forKey: "loadGame") as! NSDictionary
        self.currentGameData = (gameDatas.object(forKey: gameProg!) as! NSDictionary)
        let runEvent = self.currentGameData.object(forKey: "runEvent") as? String
        // set run event
        eventTriggerAfterMapMove = runEvent
        
        // Load Map Profile Based on Event PROGRESS
        if mapProfile?.object(forKey: "sceneProgressSetting") != nil {
            
            let mpProgArray = mapProfile?.object(forKey: "sceneProgressSetting") as! Array<NSDictionary>
            let userProgress = self.parentVC?.tempPlayerData["gameProgress"] as! String
            
            // load default state i.e peaceful
            for progressItem in mpProgArray {
                // sceneProgressSetting without eventValue/eventValues are considered default value
                if progressItem.object(forKey: "eventValue") == nil && progressItem.object(forKey: "eventValues") == nil {
                    shaders.preloadingScene(spItem: progressItem)
                } else {
                    // case when eventValue exists
                    if let eventVal = progressItem.object(forKey: "eventValue") as? String {
                        if eventVal == userProgress {
                            shaders.preloadingScene(spItem: progressItem)
                        }
                        break; // break loop
                    }
                    // case when eventValues exists
                    if let eventValsDats = progressItem.object(forKey: "eventValues") as? String {

                        let eventVals = eventValsDats.components(separatedBy: "/")
                        for evnt in eventVals {
                            if evnt == userProgress {
                                shaders.preloadingScene(spItem: progressItem)
                            }
                        }
                        
                        break; // break loop
                    }
                }
            }
            
        }
        
        // check for noOst
        if self.currentGameData.object(forKey: "noOST") != nil {
            self.parentVC?.fadeBGM(toVolume: 0.0, duration: 1.0)
        }
        
        
        // Load textures
        let grsEdge = UIImage(named: "ListenedGameAssets.scnassets/tex-cliff-shading.png")!
        
        // Environmental World Textures
        let dirtGroundTexture = UIImage(named: "ListenedGameAssets.scnassets/grass-t1.jpg")!     // g2Tex
        let greenGrassTexture = UIImage(named: "ListenedGameAssets.scnassets/grass-t2.png")!     //
        let wallStoneTexture = UIImage(named: "ListenedGameAssets.scnassets/gake-t1b.jpg")!    // g1Tex
        let stonyTexture = UIImage(named: "ListenedGameAssets.scnassets/gake-t3.jpg")!     //
        let stonyTextureNormal = UIImage(named: "ListenedGameAssets.scnassets/gake-t1b-normal.jpg")!     //

        
        let leavesNrm = UIImage(named: "ListenedGameAssets.scnassets/green-tex-normal.png")!
        //                        //woodtrunk-t2-alpha-normal.png
        let oldWoolNrm = UIImage(named: "ListenedGameAssets.scnassets/woodtrunk-t2-alpha-normal.png")!
        
        let leafParticle = sceneView.scene?.rootNode.childNode(withName: "leafParticle", recursively: true)?.particleSystems?.first
        
        let wtrClr = UIImage(named: "ListenedGameAssets.scnassets/wtr-clr.png")
        let waterDif = UIImage(named: "ListenedGameAssets.scnassets/waterNoiseTex.jpg")
        let waterRef = UIImage(named: "ListenedGameAssets.scnassets/waterBg.png")
        let waterNrm = UIImage(named: "ListenedGameAssets.scnassets/norm-t1.jpg")
        
        // 2 textures mixed in one material
        let wallStoneMatProperty = SCNMaterialProperty(contents: wallStoneTexture)
        let dirtGroundMatProperty = SCNMaterialProperty(contents: dirtGroundTexture)
        let clearMatProperty = SCNMaterialProperty(contents: UIColor.clear)
        
        let wtrMatProperty = SCNMaterialProperty(contents: waterNrm!)
        let maxQ:Bool = true
        
        sceneView.scene?.rootNode.enumerateHierarchy({ (node, nil) in
            
            if let nodeName = node.name {
                
                // setup for non-geometry depending nodes
                if nodeName.contains("plr") {
                    node.isHidden = true
                }
                
                // setup for custom camera objects
                if node.camera != nil {
                    if let name = node.name {
                        if name.hasPrefix(" BF") {
                            // BF camera
                            self.shaders.setIndividualCameraProfile(camNode: node, currentProfile: profile)
                        }
                    }
                }
                
                // setup for geometry nodes
                if node.geometry != nil {
                    
                    // Get Ground Mapping
                    if nodeName.contains("sndps") {
                        shaders.addSound(filename: "closeCallSfx.wav", node: node, volume: 0.1)
                    }
                    
                    // Get Water Special Effect
                    if nodeName.contains("wtr02prog") {
                        
                        node.geometry!.firstMaterial!.diffuse.contents = wtrClr
                        node.geometry!.firstMaterial!.setValue(wtrMatProperty, forKey: "normalSampler")// G2 Texture
                        
                        let program = SCNProgram()
                        program.vertexFunctionName = "myVertex"
                        program.fragmentFunctionName = "myFragment"
                        node.geometry!.program = program
                        
                        
                        
                    }
                    
                    if let mats = node.geometry?.materials {
                        for mat in mats {
                            if let matName = mat.name {
                                
                                if matName.contains("trnsMat") {
                                    mat.transparency = 0.0
                                    mat.transparent.intensity = 0.0
                                    //node.opacity = 0.0
                                }
                                
                                if matName == "waterEdge" {
                                    mat.lightingModel = .physicallyBased
                                    mat.metalness.contents = UIColor.black
                                    mat.roughness.contents = UIColor.white
                                    mat.blendMode = .screen;
                                    mat.diffuse.mappingChannel = 1;
                                    mat.transparency = 1.0;
                                    mat.transparencyMode = .singleLayer;
                                    mat.writesToDepthBuffer = false;
                                    mat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment: shaders.fogShader()];
                                    
                                    if nodeName.contains("riverArea") {
                                        node.geometry?.shaderModifiers = [SCNShaderModifierEntryPoint.geometry : shaders.smallRiverEdge()];
                                        node.renderingOrder = 2;
                                    }
                                }
                                
                                if matName.contains("hnt") {
                                    //mat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment: shaders.sharpDiscard()]
                                }
                                
                                if matName.contains("shinyObjectGrad") {
                                    mat.lightingModel = .lambert
                                    mat.selfIllumination.contents = UIColor.white
                                    mat.selfIllumination.intensity = 10.0
                                }
                                
                                if matName.contains("grstx") {
                                    mat.diffuse.intensity = texIntensity
                                    mat.lightingModel = .constant
                                    mat.isDoubleSided = true
                                    mat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment : shaders.discard()]
                                }
                                // Target Material "TagMat", always have transparent image
                                if matName.contains("TagMat") {
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
                                    
                                    node.renderingOrder = 100;
                                    // all FX related textures shall be set to 100th rendering order.
                                }
                                //silverLine
                                if matName.contains("silverLine") {
                                    node.castsShadow = false
                                    mat.blendMode = .add
                                    mat.isDoubleSided = true
                                    mat.writesToDepthBuffer = false
                                    mat.transparency = 0.5
                                    node.geometry?.shaderModifiers = [SCNShaderModifierEntryPoint.geometry : shaders.moveUV_Xaxis(uvSpeed:"0.07")]
                                    node.renderingOrder = 2
                                }
                                // Rendering PBR Textures
                                if matName.contains("PBRTx") {
                                    mat.lightingModel = .physicallyBased
                                    
                                    if matName.contains("MTL") {
                                        mat.metalness.contents = UIColor.init(hexaString:"#B9B9B9")
                                        mat.roughness.contents = UIColor.init(hexaString: "#4D4D4D")
                                    }
                                }
                                // Bloomed Lights constantly looking at camera
                                if matName.contains("LFlare") {
                                    mat.lightingModel = .constant
                                    mat.blendMode = .add
                                    mat.writesToDepthBuffer = false
                                    mat.isDoubleSided = true
                                    node.constraints = [SCNBillboardConstraint.init()]
                                    node.renderingOrder = 10
                                }
                                // Leaves on high tree natural shading
                                if matName.contains("tleaves") {
                                    //
                                    node.castsShadow = true
                                    // animate leaves
                                    mat.isDoubleSided = true
                                    mat.lightingModel = .physicallyBased
                                    mat.diffuse.intensity = texIntensity //texIntensity
                                    mat.diffuse.mipFilter = .none
                                    mat.diffuse.magnificationFilter = .none
                                    mat.diffuse.minificationFilter = .none
                                    mat.transparent.contents = nil
                                    mat.normal.contents = leavesNrm
                                    mat.normal.intensity = 1.0
                                    mat.selfIllumination.contents = UIColor.white.cgColor
                                    mat.metalness.contents = UIColor.white.cgColor
                                    mat.roughness.contents = UIColor.white.cgColor
                                    mat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment: shaders.discard()]
                                    
                                    node.geometry?.shaderModifiers = [SCNShaderModifierEntryPoint.geometry: shaders.tree_leaves_pbr()]
                                    node.geometry?.levelsOfDetail = [SCNLevelOfDetail(geometry: nil, worldSpaceDistance: 30.0)];
                                    
                                    
                                    //
                                }
                                // automatically map materials using its name
                                if matName.contains("Mat-Tga") {
                                    
                                    //
                                    node.castsShadow = true

                                    mat.lightingModel = .physicallyBased
                                    
                                    
                                    
                                    // check for diffuse content
                                    if mat.diffuse.contents == nil {
                                        let diffuseMatName = "ListenedGameAssets.scnassets/" + matName + "-Diffuse.png";
                                        if let diffuseMap = UIImage(named: diffuseMatName) {
                                            mat.diffuse.contents = diffuseMap
                                        }
                                    }
                                    
                                    mat.diffuse.intensity = 1.0 //texIntensity
                                    mat.diffuse.mipFilter = .nearest
                                    mat.diffuse.magnificationFilter = .linear
                                    mat.diffuse.minificationFilter = .linear
                                    
                                    // check for normal content
                                    if mat.normal.contents == nil {
                                        let normMatName = "ListenedGameAssets.scnassets/" + matName + "-Normal.png";
                                        if let normalMap = UIImage(named: normMatName) {
                                            mat.normal.contents = normalMap
                                        }
                                    }
                                   

                                    mat.selfIllumination.contents = UIColor.white.cgColor
                                    mat.metalness.contents = UIColor.black.cgColor
                                    mat.roughness.contents = UIColor.gray.cgColor
                                    
                                    //
                                }
                            }
                        }
                    }
                    
                    
                    if nodeName.contains("gnd") || nodeName.contains("hopStep") {
                        // Working
                        node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: node, options: [SCNPhysicsShape.Option.type : SCNPhysicsShape.ShapeType.concavePolyhedron]))
                        node.categoryBitMask = groundMeshBitMask
                        node.physicsBody?.categoryBitMask = groundMeshBitMask
                        node.physicsBody?.collisionBitMask = groundMeshBitMask
                    }
                    if nodeName.contains("wall") || nodeName.contains("enemyblock") {
                        // Working
                        node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: node, options: [SCNPhysicsShape.Option.type : SCNPhysicsShape.ShapeType.concavePolyhedron]))
                        //node.categoryBitMask = 2
                        node.physicsBody?.categoryBitMask = 2
                        node.physicsBody?.collisionBitMask = 2
                    }
                    if nodeName.contains("HDN") {
                        // Hidden node from the beginning
                        node.opacity = 0.0;
                    }
                    if nodeName.contains("evnt") || nodeName.contains("OItem") || nodeName.contains("trigger") || nodeName.contains("moveToMap") || nodeName.contains("camMovD") || nodeName.contains("camPers") || nodeName.contains("ostShift") {
                        // Working
                        node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: node, options: [SCNPhysicsShape.Option.type : SCNPhysicsShape.ShapeType.concavePolyhedron])) // MUST BE CONCAVE POLYHEDRON! PC wont detect evnt object(s) in-front...
                        node.categoryBitMask = 2
                        node.physicsBody?.categoryBitMask = 2
                        node.physicsBody?.collisionBitMask = 2
                    }
                    
                    if nodeName.contains("Tree-t") {
                        // add physics body on trunk
                        node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: node, options: [SCNPhysicsShape.Option.type : SCNPhysicsShape.ShapeType.concavePolyhedron]))
                        //node.categoryBitMask = 2
                        
                        node.physicsBody?.categoryBitMask = 2
                        node.physicsBody?.collisionBitMask = 2
                        
                        node.geometry?.firstMaterial?.lightingModel = .physicallyBased
                        node.geometry?.firstMaterial?.metalness.contents = UIColor.white
                        node.geometry?.firstMaterial?.roughness.contents = UIColor.white
                        node.geometry?.firstMaterial!.transparencyMode = .singleLayer
                        
                        node.geometry?.firstMaterial?.normal.contents = oldWoolNrm
                        node.geometry?.firstMaterial?.normal.intensity = 1.0
                        node.geometry?.firstMaterial?.normal.wrapS = SCNWrapMode.repeat
                        node.geometry?.firstMaterial?.normal.wrapT = SCNWrapMode.repeat
                        node.geometry?.firstMaterial?.normal.magnificationFilter = SCNFilterMode.nearest
                        node.geometry?.firstMaterial?.normal.minificationFilter = SCNFilterMode.nearest
                        node.geometry?.firstMaterial?.normal.mipFilter = SCNFilterMode.nearest
                        
                        node.castsShadow = true
                        
                        // all trees will receive dither effect
                        for mat in node.geometry!.materials {
                            if mat.name! != "trnsMat" {
                                mat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment : shaders.treeTrunkDither()]
                            }
                        }
                        
                    }
                    
                    if nodeName.contains("lflAxis") {
                        let particle = leafParticle?.copy() as! SCNParticleSystem
                        node.renderingOrder = 1
                        node.addParticleSystem(particle)
                        particle.birthRate = 10
                    }
                    
                    // grass-plane
                    if nodeName.contains("smgrs") {
                        node.geometry?.firstMaterial?.shaderModifiers = [SCNShaderModifierEntryPoint.fragment : shaders.discard()]
                        node.castsShadow = true
                        let look = SCNBillboardConstraint()
                        look.freeAxes = .Y
                        node.constraints = [look]
                    }
                    
                    // grass-plane
                    if nodeName.contains("grass-s") {
                        if maxQ == true {
                            node.geometry?.shaderModifiers = [SCNShaderModifierEntryPoint.geometry : shaders.grass_small()]
                        }
                        node.geometry?.firstMaterial?.isDoubleSided = true
                        node.geometry?.firstMaterial?.shaderModifiers = [SCNShaderModifierEntryPoint.fragment : shaders.discard()]
                        node.castsShadow = true
                    }
                    
                    if nodeName.contains("grass-m") {
                        if maxQ == true {
                            node.geometry?.shaderModifiers = [SCNShaderModifierEntryPoint.geometry : self.shaders.grass_mid()]
                        }
                        node.geometry?.firstMaterial?.isDoubleSided = true
                        node.geometry?.firstMaterial?.shaderModifiers = [SCNShaderModifierEntryPoint.fragment : shaders.discard()]
                        node.physicsBody = SCNPhysicsBody(type: .static, shape: .init(geometry: SCNSphere(radius: 0.2), options: [:]))
                        node.categoryBitMask = 2
                        node.physicsBody?.categoryBitMask = 2
                        node.physicsBody?.collisionBitMask = 2
                        //node.constraints = [SCNBillboardConstraint()]
                        node.castsShadow = true
                        
                    }
                    
                    // water fall
                    if nodeName.contains("wfall") {
                        node.geometry?.firstMaterial?.lightingModel = .physicallyBased
                        node.geometry?.shaderModifiers = [SCNShaderModifierEntryPoint.geometry : shaders.water_fall()]
                        node.geometry?.firstMaterial?.diffuse.intensity = 1.0;
                        node.geometry?.firstMaterial?.isDoubleSided = true
                        node.geometry?.firstMaterial?.transparent.mappingChannel = 1;
                        node.geometry?.firstMaterial?.writesToDepthBuffer = false;
                        node.geometry?.firstMaterial?.transparency = 0.5
                        node.renderingOrder = 1;
                        // add 3D sound
                        if nodeName.contains("sn") {
                            shaders.addSound(filename: "falls.wav", node: node, volume: 1.0);
                        } else {
                            //shaders.addSound(filename: "falls.wav", node: node, volume: 1.0);
                        }
                    }
                    
                    if nodeName.contains("uvMoveObj") {
                        // e.g. uvMoveObj-xUV-5-001 (make sure not to put the term "water" when defining this object
                        let getspeed = nodeName.components(separatedBy: "-")
                        let speed = getspeed[2]
                        if getspeed[1].contains("xUV") {
                            node.geometry?.shaderModifiers = [SCNShaderModifierEntryPoint.geometry : shaders.moveUV_Xaxis(uvSpeed: speed)]
                        } else {
                            node.geometry?.shaderModifiers = [SCNShaderModifierEntryPoint.geometry : shaders.moveUV_Yaxis(uvSpeed: speed)]
                        }
                        //
                        node.geometry?.firstMaterial?.diffuse.intensity = 1.0;
                        node.geometry?.firstMaterial?.isDoubleSided = true
                        node.geometry?.firstMaterial?.transparent.mappingChannel = 1;
                        node.geometry?.firstMaterial?.writesToDepthBuffer = false;
                        node.geometry?.firstMaterial?.transparency = 1.0
                        node.geometry?.firstMaterial?.blendMode = .add
                        node.renderingOrder = 1;
                        // add 3D sound
                    }
                    
                    if nodeName.contains("wsplash") {
                        node.geometry?.shaderModifiers = [SCNShaderModifierEntryPoint.geometry : shaders.water_norm()]
                        node.geometry?.firstMaterial?.diffuse.intensity = 1.0;
                        node.geometry?.firstMaterial?.isDoubleSided = true
                        node.geometry?.firstMaterial?.transparent.mappingChannel = 1;
                        node.geometry?.firstMaterial?.writesToDepthBuffer = false;
                        node.geometry?.firstMaterial?.transparency = 1.0
                        node.geometry?.firstMaterial?.blendMode = .screen
                        node.renderingOrder = 1;
                        node.opacity = 0
                    }
                    
                    if nodeName.contains("water") {
                        
                        node.geometry?.firstMaterial?.isDoubleSided = true;
                        
                        node.geometry?.firstMaterial?.lightingModel = .physicallyBased
                        
                        node.geometry?.firstMaterial?.diffuse.contents = waterDif
                        node.geometry?.firstMaterial?.diffuse.intensity = 0.2;
                        node.geometry?.firstMaterial?.diffuse.mappingChannel = 0;
                        
                        node.geometry?.firstMaterial?.metalness.contents = UIColor.init(hexaString:"#545454", alpha:1.0)
                        node.geometry?.firstMaterial?.roughness.contents = UIColor.black
                        
                        node.geometry?.firstMaterial?.normal.contents = waterNrm
                        node.geometry?.firstMaterial?.normal.intensity = 3.0
                        node.geometry?.firstMaterial?.normal.mappingChannel = 1
                        
                        node.geometry?.firstMaterial?.selfIllumination.contents = UIColor.black
                        
                        node.geometry?.firstMaterial?.transparency = 0.2
                        node.geometry?.firstMaterial?.transparencyMode = .singleLayer
                        //node.geometry?.firstMaterial?.blendMode = .screen
                        node.geometry?.firstMaterial?.writesToDepthBuffer = false;
                        
                        node.geometry?.firstMaterial?.shaderModifiers = [SCNShaderModifierEntryPoint.surface : shaders.waterSurfaceMod(), SCNShaderModifierEntryPoint.fragment : shaders.waterFragMod()]
                        node.renderingOrder = 2
                        
                        // add 3D sound
                        if nodeName.contains("sn") {
                            shaders.addSound(filename: "farPond.wav", node: node, volume: 1.0);
                        }
                    }
                    
                    if nodeName.contains("darkWater") {
                        
                        node.geometry?.firstMaterial?.isDoubleSided = true;
                        
                        node.geometry?.shaderModifiers = [SCNShaderModifierEntryPoint.geometry : shaders.waterGeometry()]
                        node.geometry?.firstMaterial?.diffuse.contents = waterDif
                        node.geometry?.firstMaterial?.diffuse.intensity = 1.0;
                        node.geometry?.firstMaterial?.diffuse.mappingChannel = 0;
                        node.geometry?.firstMaterial?.reflective.contents = waterRef
                        node.geometry?.firstMaterial?.reflective.intensity = 0.5;
                        node.geometry?.firstMaterial?.normal.contents = waterNrm
                        node.geometry?.firstMaterial?.normal.intensity = 2.0
                        node.geometry?.firstMaterial?.normal.mappingChannel = 1
                        node.geometry?.firstMaterial?.transparency = 1.0
                        node.geometry?.firstMaterial?.blendMode = .screen
                        node.geometry?.firstMaterial?.shaderModifiers = [SCNShaderModifierEntryPoint.fragment : shaders.waterFragMod()]
                        node.geometry?.firstMaterial?.writesToDepthBuffer = false;
                        node.renderingOrder = 1
                        
                        // add 3D sound
                        if nodeName.contains("sn") {
                            shaders.addSound(filename: "farPond.wav", node: node, volume: 1.0);
                        }
                    }
                    
                    if nodeName.contains("Wtrtype-Pnd") {
                        
                        node.geometry?.firstMaterial?.isDoubleSided = true;
                        
                        node.geometry?.shaderModifiers = [SCNShaderModifierEntryPoint.geometry : shaders.waterGeometry()]
                        node.geometry?.firstMaterial?.diffuse.contents = waterDif
                        node.geometry?.firstMaterial?.diffuse.intensity = 0.2;
                        node.geometry?.firstMaterial?.diffuse.mappingChannel = 0;
                        node.geometry?.firstMaterial?.reflective.contents = waterRef
                        node.geometry?.firstMaterial?.reflective.intensity = 0.03;
                        node.geometry?.firstMaterial?.normal.contents = waterNrm
                        node.geometry?.firstMaterial?.normal.intensity = 0.5
                        node.geometry?.firstMaterial?.normal.mappingChannel = 1
                        node.geometry?.firstMaterial?.transparency = 0.5
                        node.geometry?.firstMaterial?.blendMode = .screen
                        node.geometry?.firstMaterial?.shaderModifiers = [SCNShaderModifierEntryPoint.fragment : shaders.waterFragMod()]
                        node.geometry?.firstMaterial?.writesToDepthBuffer = false;
                        node.renderingOrder = 1
                        
                    }
                    
                    if nodeName.contains("tlvs") {
                        node.geometry?.shaderModifiers = [SCNShaderModifierEntryPoint.geometry : self.shaders.tree_leaves1()]
                        node.geometry?.firstMaterial?.isDoubleSided = true
                        node.castsShadow = true
                        //
                    }
                    
                    // Hiding Objects Far Away
                    if nodeName.contains("grass") || nodeName.contains("grs") {
                        node.geometry?.levelsOfDetail = [SCNLevelOfDetail(geometry: nil, worldSpaceDistance: 20.0)];
                    }
                    
                    if nodeName.contains("Tree") || nodeName.contains("Fence") {
                        node.geometry?.levelsOfDetail = [SCNLevelOfDetail(geometry: nil, worldSpaceDistance: 50.0)];
                    }
                    
                    
                    // Gake Setting
                    if nodeName.contains("World") {
                        
                        if let mats = node.geometry?.materials {
                            for mat in mats {
                                if nodeName.contains("NDS") == false {
                                    mat.isDoubleSided = true
                                    mat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment : shaders.treeTrunkDither()]
                                }
                                
                                mat.lightingModel = .physicallyBased
                                
                                if let matName = mat.name {
                                    //
                                    
                                    if matName == "gake-t1" {
                                        mat.diffuse.contents = wallStoneTexture
                                        mat.diffuse.mappingChannel = 2
                                        //mat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment: shaders.normalSetupForGround()]
                                    }
                                    
                                    if matName == "gake-t2" {
                                        mat.diffuse.contents = stonyTexture
                                        mat.diffuse.mappingChannel = 2
                                        //mat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment: shaders.normalSetupForGround()]
                                    }
                                    //
                                    if matName == "Black" {
                                        mat.isDoubleSided = false
                                        mat.metalness.contents = nil
                                        mat.roughness.contents = nil
                                        mat.shaderModifiers = [:]
                                    }
                                    // blended cliff
                                    if matName == "grass-t1-gake" {
                                        mat.diffuse.contents = greenGrassTexture // top material
                                        mat.diffuse.mappingChannel = 0
                                        mat.transparent.contents = grsEdge
                                        mat.transparent.mappingChannel = 1
                                        //mat.ambient.contents = outlineTex
                                        mat.ambient.mappingChannel = 0// wallAreaMap
                                        mat.setValue(dirtGroundMatProperty, forKey: "underGake")    // G1 Texture
                                        mat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment: shaders.tGake()]
                                        
                                    }
                                    if matName == "grass-t2-gake" {
                                        mat.diffuse.contents = greenGrassTexture // top material
                                        mat.diffuse.mappingChannel = 0
                                        mat.transparent.contents = grsEdge
                                        mat.transparent.mappingChannel = 1
                                        mat.ambient.mappingChannel = 2// wallAreaMap
                                        //mat.normal.contents = stonyTextureNormal
                                        mat.setValue(wallStoneMatProperty, forKey: "underGake")    // G2 Texture
                                        mat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment: shaders.tGake()]
                                        mat.isDoubleSided = false
                                    }
                                    if matName == "grass-t3-gake" {
                                        mat.diffuse.contents = dirtGroundTexture // top material
                                        mat.diffuse.mappingChannel = 0
                                        mat.transparent.contents = grsEdge
                                        mat.transparent.mappingChannel = 1
                                        mat.ambient.mappingChannel = 2// wallAreaMap
                                        //mat.normal.contents = stonyTextureNormal
                                        mat.setValue(wallStoneMatProperty, forKey: "underGake")
                                        mat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment: shaders.tGake()]
                                        mat.isDoubleSided = false
                                    }
                                    if matName == "grass-t4-gakeClear" {
                                        mat.diffuse.contents = dirtGroundTexture // top material
                                        mat.diffuse.mappingChannel = 0
                                        mat.transparent.contents = grsEdge
                                        mat.transparent.mappingChannel = 1
                                        mat.ambient.mappingChannel = 2// wallAreaMap
                                        mat.setValue(clearMatProperty, forKey: "underGake")    // G2 Texture
                                        mat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment: shaders.tGakeClear()]
                                        mat.isDoubleSided = false
                                    }
                                    
                                    //mat.normal.contents = stonyTextureNormal
                                    mat.normal.wrapS = .repeat
                                    mat.normal.wrapT = .repeat
                                    mat.normal.intensity = 2.0
                                    mat.normal.mappingChannel = 0
                                    
                                    mat.metalness.contents = UIColor.black
                                    mat.roughness.contents = UIColor.white
                                    
                                    //mat.displacement.contents = stonyTextureDisplacement
                                    //mat.displacement.intensity = 0.1
                                    //mat.displacement.mappingChannel = 2
                                    //mat.displacement.wrapS = .repeat
                                    //mat.displacement.wrapT = .repeat
                                }
                            }
                        }
                        
                        // register
                        if nodeName.contains("lod") {
                            // register its child as far node
                            
                            //node.geometry?.levelsOfDetail = [SCNLevelOfDetail(geometry: nil, worldSpaceDistance: 20.0)];
                            if node.childNodes.count > 0 {
                                node.enumerateChildNodes { childNode, stop in
                                    if let childNodeName = childNode.name {
                                        if childNodeName.contains("farChild") {
                                            childNode.isHidden = true
                                            node.geometry?.levelsOfDetail = [SCNLevelOfDetail(geometry: childNode.geometry, worldSpaceDistance: 40.0)]
                                        }
                                    }
                                }
                            }
                        }
                        if nodeName.contains("wtr") {
                            node.geometry?.shaderModifiers = [SCNShaderModifierEntryPoint.geometry : shaders.underWaterWarp()]
                        }
                    }
                }
            }
        })
        
        // Add Playable Character (Zack)
        sceneView.scene?.rootNode.addChildNode(player)
        npcPlayers?.add(player)
        
        // setup const add a constraint
        let lookAt = SCNLookAtConstraint(target: nil)
        lookAt.isGimbalLockEnabled = true
        lookAt.worldUp = (self.sceneView.scene?.rootNode.worldUp)!
        lookAt.influenceFactor = 1.0
        self.player.headTrack = lookAt
        self.player.neck!.constraints = [lookAt]
        
        // Setup player default position depending on entryPoint
        player.goTo(axis: node(name: playerLastPosition))
        
        if let entryPts = mapProfile?.object(forKey: "entryPointSetting") {
            if let epSetting = (entryPts as! NSDictionary).object(forKey: playerLastPosition!) {
                //
                let playerAngle = Float(((epSetting as? NSDictionary)?.object(forKey: "faceAngle") as? String) ?? "0.0")
                player.eulerAngles.y = shaders.radians(degrees: playerAngle ?? Float(0.0))
                //
                //pov
                let pov = (epSetting as! NSDictionary).object(forKey: "pov") as? String ?? "camera-player"
                setOverworldPOV(cameraNode: pov, duration: 0.0)
                //
                camAxis.position = SCNVector3Make(player.position.x, player.zroot.position.y, player.position.z);
            }
        }
        
        camAxis.position = SCNVector3Make(player.position.x, player.zroot.position.y, player.position.z);
        
        // Add Non-Playable Characters (Basama, Ojisan, Luna, etc)
        if let npcSetupData = currentGameData.object(forKey: "npcSetup") {
            let npcCmd = npcSetupData as! Array<NSDictionary>
            for npcSetting in npcCmd {
                eventCtrl.runNpc(functions: npcSetting)
            }
        }
        
        // Spawn enemies
        shaders.spawnEnemiesInScene(scene: sceneView.scene)
        
        // find fall catch
        
        let fallCatchNode = self.sceneView.scene?.rootNode.childNode(withName: "trigger-fallCatch", recursively: true)
        if fallCatchNode != nil {
            fallCatchNode!.accessibilityLabel = "fallCatch"
        }
        
        // Prepare
        sceneView.prepare([sceneView.scene!]) { completed in
            if completed == true {
                self.openScene()
            }
        }
    }
    
    
    /// addFieldEnemy() Spawns new enemy only if identifier is unique in the scene to avoid doubling
    func spawnFieldEnemy(npcName: String, position: String?, event: String?, identifier: String?, axisInfo: SCNNode?) -> NPCNode {
        
        var enemyNode:NPCNode
        
        if let recurringNPC = self.npc(owName: npcName) {
            if recurringNPC.npcIdentifier == identifier {
                return recurringNPC
            }
        }
        
        enemyNode = NPCNode(named: npcName) // create new & initialize
        enemyNode.gameSceneVC = self
        enemyNode.enemy = true
        enemyNode.state = 0 // start searching
        enemyNode.npcIdentifier = identifier
        
        if axisInfo != nil {
            enemyNode.enemyAxis = axisInfo
            if (axisInfo?.childNodes.count)! == 0 {
                enemyNode.convertToEnemy(isPlayerDetectable: true)
            }
        }
        
        enemyNode.position = SCNVector3Zero
        enemyNode.rotation = SCNVector4Zero
        if position != nil {
            enemyNode.goTo(axis: self.node(name: position!))
        }
        if event != nil {
            enemyNode.registerEvent(eventId: event!)
        }
        
        // Use axisInfo to control enemyNode behavior
        npcPlayers?.add(enemyNode)
        sceneView.scene?.rootNode.addChildNode(enemyNode)
        print("Spawned Enemy \(enemyNode)")
        return enemyNode
    }
    
    
    // Open Scene - This is where game starts
    @objc
    func openScene() {
        
        sceneView.scene?.isPaused = false;
        sceneView.rendersContinuously = true;
        sceneView.isPlaying = true;
        
        // start callign delegates
        sceneView.delegate = self;
        sceneView.scene?.physicsWorld.contactDelegate = self;
        //sceneView.scene?.physicsWorld.grav
        
        loadingSprites.stopAnimating()
        loadingSprites.removeFromSuperview()// remove unnecessary UIView
        
        // get Map Title
        var mapTitle = self.mapProfile?.object(forKey: "titleEN") as! String
        let lang = UserDefaults.standard.string(forKey: "user_lang")
        if lang?.hasPrefix("JA") == true {
            mapTitle = self.mapProfile?.object(forKey: "titleJA") as! String
        }
        
        
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            
            //run event
            var dat_runEvent = self.currentGameData.object(forKey: "runEvent") as? String
            
            if self.eventTriggerAfterMapMove != nil {
                dat_runEvent = self.eventTriggerAfterMapMove
            }
            
            // find event from gameEvent
            if dat_runEvent != nil {
                self.present(self.eventCtrl, animated: true) {
                    self.gameState = 2
                    self.eventCtrl.prepareEvent(event: dat_runEvent!)
                    self.eventCtrl.areaTitle = mapTitle
                }
            } else {
                
                if self.owBGM != nil {
                    self.parentVC?.fadeToBGM(bgmId: self.owBGM, duration: 2.0, volume: 1.0);
                }
                
                UIView.animate(withDuration: 1.0, animations: {
                    self.sceneView.alpha = 1.0;
                }) { completed in
                    self.gameState = 0
                    self.setNpcControls(allow: true)
                    self.displayAreaTitle(titleString: mapTitle)
                }
            }
        }
    }
    
    func loadStage(stageName: String) {
        
        unloadGameScene()
        
        // close view
        parentVC?.view.tag = 10
        
        self.dismiss(animated: true) {
            // stop music. load menu
            
            self.parentVC?.tempPlayerData["lastPosition"] = "10"
            
            self.sceneView = nil
            self.parentVC?.loadGameStage(stageName: stageName)
        }
    }
    //
    func repeatStage() {
                
        unloadGameScene()
        
        // close view
        parentVC?.view.tag = 2
        
        self.dismiss(animated: true) {
            self.parentVC?.tempPlayerData["lastPosition"] = "10"
            self.sceneView = nil
        }
    }
    //
    func unloadGameScene() {
        
        sceneView.scene?.isPaused = true
        sceneView.isPlaying = false
        sceneView.delegate = nil
        sceneView.scene?.physicsWorld.contactDelegate = nil
        
        // remove reference
        eventCtrl = nil
        shaders = nil
        
        npcPlayers?.removeAllObjects() // remove reference
        sceneView.audioListener = nil
        sceneView.pointOfView = nil
        sceneView.scene?.background.contents = nil
        sceneView.scene?.rootNode.enumerateHierarchy({ node, stop in
            
            // remove character
            if node is NPCNode {
                let p = node as! NPCNode
                p.npcName = nil
                p.zroot = nil
                p.body = nil
                p.front = nil
                p.headTop = nil
                p.walkAnim = nil
                p.runAnim = nil
                p.loadedAnimation = nil
                p.faceMat?.diffuse.contents = nil
                p.faceMat = nil
                p.talkMat?.diffuse.contents = nil
                p.talkMat = nil
            }
            
            node.removeAllAudioPlayers()
            node.removeAllActions()
            node.removeAllParticleSystems()
            node.removeAllAnimations()
            node.constraints?.removeAll()
            
            if node.skinner != nil {
                node.skinner = nil
            }
            if node.morpher != nil {
                node.morpher = nil
            }
            if node.physicsBody != nil {
                node.physicsBody?.physicsShape = nil
                node.physicsBody = nil
            }
            if node.light != nil {
                node.light = nil
            }
            if node.camera != nil {
                node.camera = nil
            }
            
            if node.geometry != nil {
                if let gNode = node.geometry {
                    gNode.shaderModifiers = [:]
                    if gNode.materials.count > 0 {
                        // release material contents
                        for mat in gNode.materials {
                            
                            mat.diffuse.contents = nil
                            mat.emission.contents = nil
                            mat.transparent.contents = nil
                            mat.multiply.contents = nil
                            mat.metalness.contents = nil
                            mat.roughness.contents = nil
                            mat.shaderModifiers = [:]
                            // mat.setValue(g2Tex, forKey: "underGake")    // G1 Texture
                            
                        }
                        // unload material references
                        gNode.materials.removeAll()
                    }
                }
                node.geometry?.levelsOfDetail?.removeAll()
                node.geometry = nil // remove geometry
            }
        })
        sceneView.scene?.rootNode.enumerateChildNodes({ node, stop in
            node.removeFromParentNode()
        })
        sceneView.scene?.rootNode.removeFromParentNode()
        sceneView.scene = nil
    }
    
    func backToMenu() {
        
        self.parentVC?.view.tag = 1
        unloadGameScene()
        // always fade out bgm
        self.parentVC?.fadeBGM(toVolume: 0.0, duration: 0.5);
        
        self.dismiss(animated: true) {
            self.sceneView = nil
        }
    }
    
    func setNpcControls(allow: Bool) {
        if allow == true {
            // ALLOW
            
            //dpadDisplay.isHidden = false
            sk?.dPad?.isPaused = false
            
            self.allowNpcControls = true
            
            //self.dpadDisplay.alpha = 1.0
            sk?.dPadDisp?.alpha = 1.0
            menuButton.isHidden = false
            menuButton.isEnabled = true
            
            UIView.animate(withDuration: 0.4, animations: {
                //self.dpadDisplay.alpha = 0.2
                self.sk?.dPadDisp?.alpha = 0.2
            }) { completed in
            }
            
        } else {
            // DISABLE
            DispatchQueue.main.async { [self] in
                allowNpcControls = false
                menuButton.isHidden = true
                menuButton.isEnabled = false
                //dpadDisplay.isHidden = true
                sk?.dPadDisp?.isHidden = true
                //dpadDragPoint.isHidden = true
                sk?.dPad?.isHidden = true
                aButton.isHidden = true
            }
        }
    }
    
    func setOverworldPOV(cameraNode: String, duration: Double) {
                
        // ignore is standard camera is already in this position
        if standardCamera.accessibilityLabel == cameraNode {
            return
        }
        
        // set pov name to avoid override
        standardCamera.accessibilityLabel = cameraNode
        let nextPov = self.node(name: cameraNode)
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        standardCamera.position = nextPov.position
        standardCamera.eulerAngles = nextPov.eulerAngles
        SCNTransaction.commit()
    }
    
    func panToPOV(cameraNode: String, duration: Double) {
        // this will not replace the camera, it will set overworld camera to its destination position/angle perspective
        
        // extract name of destination camera name
        /*
         
         input val : camPers$camera
         
         <Possible Camera Names:>
            camera
            camera-player
            camera-player-R1
            camera-player-far
            camera-player-near
            camera-player-top
         */
        
        
        let camName = cameraNode.components(separatedBy: "¥")[1]
        let nextPov = self.node(name: camName)
        
        // ignore is standard camera is already in this position
        if standardCamera.accessibilityLabel == nextPov.name {
            return
        }
        
        // set pov name to avoid override
        standardCamera.accessibilityLabel = nextPov.name
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        standardCamera.position = nextPov.position
        standardCamera.eulerAngles = nextPov.eulerAngles
        SCNTransaction.commit()
    }
    
    func interpolateOverworldPOV(pov1: SCNNode, pov2: SCNNode, percentage: Float, duration: Double) {
        
        let firstPosition = GLKVector3(v:(pov1.position.x, pov1.position.y, pov1.position.z))
        let secondPosition = GLKVector3(v:(pov2.position.x, pov2.position.y, pov2.position.z))
        let positionLerp = GLKVector3Lerp(firstPosition, secondPosition, percentage)
        
        let firstAngle = GLKVector3(v:(pov1.eulerAngles.x, pov1.eulerAngles.y, pov1.eulerAngles.z))
        let secondAngle = GLKVector3(v:(pov2.eulerAngles.x, pov2.eulerAngles.y, pov2.eulerAngles.z))
        let angleLerp = GLKVector3Lerp(firstAngle, secondAngle, percentage)
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
        standardCamera.position = SCNVector3FromGLKVector3(positionLerp)
        standardCamera.eulerAngles = SCNVector3FromGLKVector3(angleLerp)
        SCNTransaction.commit()
        
    }
    
    func setCamera(cameraNodeName:String, duration:CFTimeInterval) {
        let nextPOV = self.node(name: cameraNodeName)
        //print("Setting camera with name \(cameraNodeName) node dat \(nextPOV)")
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        sceneView.pointOfView = nextPOV
        SCNTransaction.commit()
    }
    
    // Rendering - Scenekit LIFECYCLE ORDER
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        var camMovDX = false
        var camMovDY = false
        var camMovNode:SCNNode? = nil
        var d:Double = 0.0
        
        if allowNpcControls == false {
            d = 1.5
        }
        
        // reset NODE CONDITION
        sceneView.scene?.rootNode.enumerateHierarchy({ node, stop in
            
            if let nodeName = node.name {
                // interactive nodes
                if nodeName.contains("plr") {
                    if let nameOfNodeToAttach = node.accessibilityValue {
                        let nodeToAttach = self.node(name: nameOfNodeToAttach)
                        node.position = nodeToAttach.worldPosition
                    }
                }
                if nodeName.contains("grass-m") {
                    // Reset grass
                    node.accessibilityLabel = nil
                }
                if nodeName.contains("interpolateCam") && allowNpcControls == true {
                    // interpolate camera ; smooth transition between two cameras using z <walking up/down> axis distance between two
                    // e.g commandAxis -> interpolateCam¥camera-player¥camera-player-top¥15¥
                    let cmd = nodeName.components(separatedBy: "¥")
                    let cam1 = self.node(name: cmd[2])
                    let cam2 = self.node(name: cmd[1])
                    
                    let maxDistanceIndex = Float(cmd[3])
                    let currentDist = abs(node.worldPosition.z) - abs(player.position.z)
                    let percnt = currentDist / maxDistanceIndex!
                    
                    // start interpolating only when within its distance
                    var duration = 0.2 // walking/running
                    if tapped == false {
                        duration = 1.0
                    }
                    
                    if percnt < 1 && percnt > 0 {
                        interpolateOverworldPOV(pov1: cam1, pov2: cam2, percentage: percnt, duration: duration)
                    }
                }
                if nodeName.contains("intrapolateCam") && allowNpcControls == true {
                    // interpolate camera ; smooth transition between two cameras using y <walking left/right> axis distance between two
                    // e.g commandAxis -> interpolateCam¥camera-player¥camera-player-top¥15¥
                    let cmd = nodeName.components(separatedBy: "¥")
                    let cam1 = self.node(name: cmd[2])
                    let cam2 = self.node(name: cmd[1])
                    
                    let maxDistanceIndex = Float(cmd[3])
                    let currentDist = abs(node.worldPosition.x) - abs(player.position.x)
                    let percnt = currentDist / maxDistanceIndex!
                    
                    // start interpolating only when within its distance
                    var duration = 0.2 // walking/running
                    if tapped == false {
                        duration = 1.0
                    }
                    
                    if percnt < 1 && percnt > 0 {
                        interpolateOverworldPOV(pov1: cam1, pov2: cam2, percentage: percnt, duration: duration)
                    }
                }
            }
        })
        
        player.hitWall = false
        player.maxPenetration = 0.0
        
        // CONTACT WITH PLAYER (i.e, walls, trees)
        let contacts = sceneView.scene?.physicsWorld.contactTest(with: player.body.physicsBody!, options: [SCNPhysicsWorld.TestOption.collisionBitMask : collisionMeshBitMask])
        
        if contacts != nil {
            for contact in contacts! {
                if let nodeName = contact.nodeB.name {
                    if nodeName.contains("wall") && contact.nodeB.isHidden == false && contact.nodeB.opacity > 0.0 {
                        
                        /*
                        if nodeName.contains("deadItem") {
                            // bring main thread
                            DispatchQueue.main.async {
                                if self.eventCtrl.isBeingPresented == true {
                                    /// - in any case when player contacts a deathItem, it should end the game immediately
                                    self.allowNpcControls = false
                                    self.eventCtrl.prepareEvent(event: "fallCatch")
                                }
                            }
                            break;
                        }*/
                        
                        // oncinue
                        wallDetect(plyr: player, contact: contact)
                    }
                    
                    
                    if nodeName.contains("OW") && contact.nodeB.isHidden == false {
                        // contact with NPC
                        let npcNd = npc(owName: nodeName)
                        if npcNd?.target == nil {
                            wallDetect(plyr: player, contact: contact)
                        }
                    }
                    if nodeName.contains("camMovDX") == true {
                        camMovNode = contact.nodeB
                        camMovDX = true
                    }
                    if nodeName.contains("camMovDY") == true {
                        camMovNode = contact.nodeB
                        camMovDY = true
                    }
                    if nodeName.contains("EW") && contact.nodeB.isHidden == false {
                        
                        let enemyEWNode = self.getEnemy(owNode: contact.nodeB)
                        
                        if let npcNode = enemyEWNode{
                            if npcNode.enemy == true && (npcNode.state == 1 || npcNode.state == 2) {
                                
                                self.gameState = 3 // loading - not battle field yet...
                                npcNode.state = 3
                                
                                // stop
                                DispatchQueue.main.asyncAfter(deadline: .now()) {
                                    
                                    self.eventCtrl.shudder(node: self.standardCamera, rate: 0.7)
                                    
                                    
                                    // run game over with Kenny's scream!
                                    if self.eventCtrl.isBeingPresented == false && self.eventCtrl.isInEvent == false {
                                        //
                                        self.allowNpcControls = false
                                        self.present(self.eventCtrl, animated: false) {
                                            self.eventCtrl.prepareEvent(event: "enemyCatch")
                                        }
                                        //
                                    }
                                    
                                }
                                
                                
                            }
                        }
                        
                    }
                    
                    if nodeName.contains("grass-m") {
                        contact.nodeB.accessibilityLabel = "B"
                        
                        if tapped == true {
                            
                            if randomEncount != nil {
                                // grass encounter
                                randomEncountCounter = randomEncountCounter + 1
                                
                                if randomEncountCounter > 100 && self.gameState == 0 {
                                    randomEncountFunc()
                                    randomEncountCounter = 0 // reset
                                }
                            }
                        }
                        
                    }
                }
            }
        }
        
        // Apply effects
        sceneView.scene?.rootNode.enumerateHierarchy({ node, stop in
            if let nodeName = node.name {
                
                // GRASS
                if nodeName.contains("grass-m") {
                    if node.accessibilityLabel == "B" {
                        // grass stepped
                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = 0.2
                        node.scale.y = 0.5
                        SCNTransaction.commit()
                    } else {
                        // back to normal state
                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = 1.0
                        node.scale.y = 1.0
                        SCNTransaction.commit()
                    }
                }
            }
        })
        
        
        
        if allowNpcControls == true {
            
            move(angle: dpadAngle)
            
            // rpad
            if isPanning == true {
                let speed:Float = 0.05
                var cAngle:Float = 0.0
                if rAngle > 0 {
                    cAngle = 90
                } else {
                    cAngle = -90
                }
                // Get value of the angled reference camere
                var currentCameraAngle = shaders.degrees(radians: standardCamera.presentation.simdEulerAngles.y)
                let orientation = abs(GLKMathRadiansToDegrees(standardCamera.presentation.eulerAngles.z))
                
                // fix camera angle - MUST
                if currentCameraAngle == 90 {
                    currentCameraAngle = -90
                } else if currentCameraAngle == -90 {
                    currentCameraAngle = 90
                }
                // fix orientation
                if orientation > 90 {
                    let cl = 180 - currentCameraAngle
                    currentCameraAngle = cl
                }
                
                // fix angle difference
                cAngle += currentCameraAngle
                
                // calculate where the camera should transform towards
                let y = 0 + speed * cos(shaders.radians(degrees: cAngle))
                let x = 0 + speed * sin(shaders.radians(degrees: cAngle))
                
                cameraPanIndex = simd_float2(x: x, y: y)
                
                standardCamera.runAction(SCNAction.moveBy(x: CGFloat(cameraPanIndex.x), y: 0, z: CGFloat(cameraPanIndex.y), duration: 0.0))
                
            }
            
        } else {
            player.stop()
        }
        
        if allows360Cam == true {

            // set audio camera
            if let audioCam = sceneView.audioListener {
                audioCam.rotation = standardCamera.presentation.rotation
            }
        }
        
        
        // OWCamera should FOLLOW player's position
        SCNTransaction.begin();
        SCNTransaction.animationDuration = d;
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut);
        
        if allowNpcControls == false && camMovNode != nil {
            print("reset camera position center to Playable Character")
            camAxis.position = SCNVector3Make((camMovNode?.presentation.position.x)!, player.zroot.position.y, (camMovNode?.presentation.position.z)!);
        }
        
        if camMovDX == true {
            camAxis.position = SCNVector3Make(camAxis.position.x, player.zroot.position.y, player.position.z);
        } else if camMovDY == true {
            camAxis.position = SCNVector3Make(player.position.x, player.zroot.position.y, camAxis.position.z);
        } else if camMovDX == true && camMovDY == true {
            camAxis.position = SCNVector3Make(camAxis.position.x, player.zroot.position.y, camAxis.position.z);
        } else {
            // normal camera movement
            camAxis.position = SCNVector3Make(player.position.x, player.zroot.position.y, player.position.z);
        }
        
        SCNTransaction.commit();
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
        
        // DETECT objects in-front of player in real time
        if eventCtrl != nil {
            
            if eventCtrl.isInEvent == false {
                
                
                let frontContact = sceneView.scene?.physicsWorld.contactTest(with: player.front.physicsBody!, options: [SCNPhysicsWorld.TestOption.collisionBitMask : collisionMeshBitMask])
                
                if frontContact != nil {
                    
                    for contact in frontContact! {
                        
                        if let nodeName = contact.nodeB.name {
                            
                            if nodeName.contains("evnt") == true {
                                if contact.nodeB.accessibilityLabel != nil {
                                    frontNode = contact.nodeB
                                }
                            }
                            if nodeName.contains("OItem") == true  {
                                if contact.nodeB.accessibilityValue != nil {
                                    // this must be displayed, not transparent
                                    if contact.nodeB.opacity > 0.0 {
                                        frontNode = contact.nodeB
                                    }
                                }
                            }
                            if nodeName.contains("OW") == true  {
                                
                                if let contactTo = contact.nodeB.accessibilityLabel {
                                    // check if event is trigger-based (#) will start event automatically;
                                    if contactTo.contains("#") {
                                        // event will start automatically as player goes close
                                        eventTriggerFrom(contact: contact)
                                    } else {
                                        // event will start only after player taps the character
                                        frontNode = contact.nodeB
                                    }
                                }
                            }
                            if nodeName.contains("camPers") == true  {
                                
                                self.panToPOV(cameraNode: nodeName, duration: 3.0)
                                
                            }
                            if nodeName.contains("ostShift") == true  {
                                
                                let ostName = nodeName.components(separatedBy: "-")[1]
                                if self.parentVC?.currentBGMID != ostName {
                                    if ostName != "nil" {
                                        self.parentVC?.fadeToBGM(bgmId: ostName, duration: 2.0, volume: 1.0)
                                    } else {
                                        self.parentVC?.fadeToBGM(bgmId: nil , duration: 2.0, volume: 1.0)
                                    }
                                    
                                }
                                
                            }
                            // Trigger entry point to run event
                            if nodeName.contains("trigger") == true  {
                                // for event that starts by itself, when player detects trigger-based event
                                eventTriggerFrom(contact: contact)
                            }
                            // Transfer to another scene
                            if nodeName.contains("moveToMap") == true {
                                
                                let cmd = nodeName.components(separatedBy: "-")
                                DispatchQueue.main.async {
                                    self.startMapMove(nextNode: cmd.last!)
                                }
                            }
                            
                        }
                    }
                }
                
                // try to detect object infront of player almost real time
                if frontNode != nil {
                    // there is front node
                    if let eventNode = frontNode {
                        
                        var target = eventNode
                        var isZack = false
                        
                        if let targetNpcOW = npc(owName: target.name ?? "") {
                            
                            if targetNpcOW.name?.contains("Zack") == true {
                                isZack = true
                            }
                            
                            if let head = targetNpcOW.head {
                                target = head
                            } else {
                                target = targetNpcOW
                            }
                            
                        }
                        
                        // event attached to the frontNode
                        DispatchQueue.main.async {
                            
                            // enable head track, but only for
                            if self.player.headTrack?.target == nil {
                                
                                self.player.headTrack?.influenceFactor = 0.0
                                self.player.headTrack?.isIncremental = true
                                self.player.headTrack?.target = target
                                
                            } else {
                                
                                if self.player.headTrack!.influenceFactor <= 0.75 && isZack == false {
                                    self.player.headTrack?.influenceFactor += 0.05
                                }
                            }
                            
                            // validate worldpoint for event detection
                            let uprPoint = self.organizeFrontNodePoint(refNode: eventNode)?.worldPosition
                            
                            if uprPoint != nil && self.gameState == 0 {
                                let prjPoint = self.sceneView.projectPoint(uprPoint!)
                                self.aButton.center = CGPoint(x: CGFloat(prjPoint.x), y: CGFloat(prjPoint.y))
                                self.aBtnTapEllipse.center = self.aButton.center
                                self.aButton.isHidden = false
                                self.aBtnTapEllipse.isHidden = false
                            }
                        }
                        //
                        //
                    } else {
                        
                        // hide button since unrelated
                        DispatchQueue.main.async {
                            self.aButton.isHidden = true
                            self.aBtnTapEllipse.isHidden = true
                            
                            // gradually remove target
                            if self.player.headTrack?.target != nil {
                                if self.player.headTrack!.influenceFactor > 0.0 {
                                    self.player.headTrack?.influenceFactor -= 0.05
                                } else {
                                    self.player.headTrack?.target = nil
                                }
                            }
                            
                        }
                    }
                    
                } else {
                    DispatchQueue.main.async {
                        self.aButton.isHidden = true
                        self.aBtnTapEllipse.isHidden = true
                        
                        // gradually remove target
                        if self.player.headTrack?.target != nil {
                            if self.player.headTrack!.influenceFactor > 0.0 {
                                self.player.headTrack?.influenceFactor -= 0.05
                            } else {
                                self.player.headTrack?.target = nil
                            }
                        }
                    }
                }
            
            } else {
                DispatchQueue.main.async {
                    self.aButton.isHidden = true
                    self.aBtnTapEllipse.isHidden = true
                }
            }
        }
        
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        
        var beingChased = false
        
        if npcPlayers != nil {
            
            for npc in npcPlayers! {
                
                let thePlayer = npc as! NPCNode
                
                thePlayer.update(sceneView: self.sceneView)
                
                // let enemy with idle state walk
                if thePlayer.enemy == true {
                    
                    if self.gameState == 0 {
                        
                        if thePlayer.state == 2 {
                            // this is when enemy is chasing
                            beingChased = true
                        }
                        
                        if thePlayer.playerDetectable == false {
                            if thePlayer.state == 0 {
                                if thePlayer.enemyAxis != nil {
                                    self.shaders.walkForever(npc: thePlayer)
                                }
                            }
                            if thePlayer.state == 1 {
                                thePlayer.walk(run: false)
                            }
                        }
                        
                        thePlayer.isPaused = false
                        
                    } else if self.gameState == 1 {
                        // currently encountering
                        if thePlayer.state == 3 {
                            
                            // make player occassionally return orientation
                            thePlayer.rotation = SCNVector4Zero
                            
                        } else if thePlayer.state == 99 {
                            // invalidated player
                        } else {
                            // pause other enemies that are not being encountered..
                            thePlayer.state = 0
                            thePlayer.stopAnimAction()
                        }
                    } else if self.gameState == 2 {
                        // while player is in event, all enemy must be paused to avoid encountering during event...
                        //player.stopAnimAction()
                        thePlayer.isPaused = true
                        
                    }  else if self.gameState == 3 {
                        // ALL enemies must stop moving
                        if thePlayer.hasActions == true {
                            thePlayer.stopAnimAction()
                        }
                    }
                    
                }
                
                if thePlayer.detectGround == true {
                    
                    let p1 = SCNVector3Make(thePlayer.position.x, thePlayer.zroot.position.y+0.5, thePlayer.position.z)
                    let p2 = SCNVector3Make(thePlayer.position.x, thePlayer.zroot.position.y-0.5, thePlayer.position.z)
                    
                    let options :[String: Any] = [
                        SCNHitTestOption.categoryBitMask.rawValue: self.groundMeshBitMask,
                        SCNHitTestOption.firstFoundOnly.rawValue: true,
                        SCNHitTestOption.ignoreHiddenNodes.rawValue: true]
                    
                    var detectedGround = false
                    var highestGround:Float = -9999.0
                    
                    if let hitResults = sceneView.scene?.rootNode.hitTestWithSegment(from: p1, to: p2, options: options) {
                        
                        
                        for result in hitResults {
                            
                            if result.node.name?.contains("hopStep") == true && thePlayer.state == 0 {
                                
                                let hpNode = result.node
                                                                    
                                if hpNode.position.y < thePlayer.zroot.position.y && allowNpcControls == true {
                                    
                                    if result.node.name?.contains("StepL") == true {
                                        if hpNode.position.x + 0.5 <= thePlayer.worldPosition.x && hpNode.position.x + 1.0 > thePlayer.worldPosition.x {
                                            runHopStep(angle: 0, node: result.node, hoppingPlayer: thePlayer)
                                            // do not detect ground while falling
                                            return
                                        }
                                    }
                                    if result.node.name?.contains("StepR") == true {
                                        if hpNode.position.x - 0.5 >= thePlayer.worldPosition.x && hpNode.position.x - 1.0 < thePlayer.worldPosition.x {
                                            runHopStep(angle: 2, node: result.node, hoppingPlayer: thePlayer)
                                            // do not detect ground while falling
                                            return
                                        }
                                    }
                                    if result.node.name?.contains("StepD") == true {
                                        if hpNode.position.z - 0.5 >= thePlayer.worldPosition.z && hpNode.position.z - 1.0 < thePlayer.worldPosition.z {
                                            runHopStep(angle: 3, node: result.node, hoppingPlayer: thePlayer)
                                            // do not detect ground while falling
                                            return
                                        }
                                    }
                                }

                                thePlayer.zroot.position.y = result.worldCoordinates.y
                                return
                            }
                            
                            if result.node.name?.contains("gnd") == true {
                                
                                if highestGround < result.worldCoordinates.y {
                                    highestGround = result.worldCoordinates.y
                                    detectedGround = true
                                }
                                
                            }
                        }
                        

                    }
                    
                    if detectedGround == false {
                        // fall
                        let fallAction = SCNAction.moveBy(x: 0, y: -CGFloat(thePlayer.fallSpeed), z: 0, duration:0.0);
                        thePlayer.zroot.runAction(fallAction)
                        if thePlayer.fallSpeed < 0.6 {
                            thePlayer.fallSpeed += 0.003
                        }
                        
                        if thePlayer.enemy == true {
                            // respawn
                            if thePlayer.fallSpeed > 0.4 {
                                // full fall speed
                                thePlayer.state = 777
                            }
                        }
                    } else {
                        thePlayer.fallSpeed = 0
                        thePlayer.zroot.position.y = highestGround
                    }
                }
            }
        }
        
        
        self.shaders.controlChasedBGM(beingChased: beingChased)
        
    }
    
    /// Begin boat ride sequence
    func beginBoatride() {
        
    }
    
    /// runHopStep -> a field action that jumps player from oneway cliff
    func runHopStep(angle: Int, node: SCNNode, hoppingPlayer: NPCNode) {
        
        if hoppingPlayer.state == 5 {
            return
        }
        hoppingPlayer.state = 5
        // must disable user control
        if hoppingPlayer == self.player {
            allowNpcControls = false
            //
            for npcs in npcPlayers! {
                let theNpc = npcs as! NPCNode
                if theNpc.npcName.contains("Zack") == false {
                    theNpc.isPaused = true
                }
            }
            //
        } else {
            
        }
        
        let nodePos = node.worldPosition
        hoppingPlayer.prepareSingleAnimation(animName: "cliffJump")
        hoppingPlayer.face(to: angle, duration: 0.2)
        
        if angle == 0 || angle == 2 {
            // hop Left or Right
            // start jumping to position
            let moveXZ = SCNAction.move(to: SCNVector3(nodePos.x, 0, hoppingPlayer.worldPosition.z), duration: 0.6)
            hoppingPlayer.runAction(moveXZ)
        }
        if angle == 1 || angle == 3 {
            // hop Left
            // start jumping to position
            let moveXZ = SCNAction.move(to: SCNVector3(hoppingPlayer.worldPosition.x, 0, nodePos.z), duration: 0.6)
            hoppingPlayer.runAction(moveXZ)
        }
        
        
        let wait = SCNAction.wait(duration: 0.4)
        if let landSound = hoppingPlayer.stepGrass_land {
            let actionSeq = SCNAction.sequence([wait, landSound])
            hoppingPlayer.runAction(actionSeq)
        }
        
        
        
        // run Y animation
        let moveY = SCNAction.move(to: SCNVector3(0, nodePos.y, 0), duration: 0.6)
        hoppingPlayer.zroot.runAction(moveY)
        // run cliff jump animation
        hoppingPlayer.runLoadedAnimation()
        // play audio
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.sfx(name: "mudfall.mp3")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.allowNpcControls = true
            hoppingPlayer.state = 0
            
            for npcs in self.npcPlayers! {
                let theNpc = npcs as! NPCNode
                if theNpc.npcName.contains("Zack") == false {
                    theNpc.isPaused = false
                }
            }
            
        }
        
    }
    
    ///  digUnder -> a field action where player will dig ground where he is standing
    
    
    
    // Event Trigger from Physical Contact
    func eventTriggerFrom(contact: SCNPhysicsContact) {
        if let nodeCommand = contact.nodeB.accessibilityLabel {
            allowNpcControls = false
            DispatchQueue.main.async {
                if self.eventCtrl.isBeingPresented == false && self.eventCtrl.isInEvent == false {
                    self.present(self.eventCtrl, animated: false) {
                        if contact.nodeB.accessibilityLabel?.contains("$") == false {
                            contact.nodeB.accessibilityLabel = nil;
                        }
                        self.eventCtrl.prepareEvent(event: nodeCommand)
                    }
                }
            }
        }
    }
    
    // Random Encount
    func randomEncountFunc() {
        
        let n = Int.random(in: 1...6)
        print("random encount called n:\(n)")
        if n != 2 {
            return
        }
        
        // エンカウント 確定!!
        randomEncountCounter = -30
        
        // get creature name randomly
        let creatureList = randomEncount?.object(forKey: "creatures") as? [String]
        let quizList = randomEncount?.object(forKey: "quizes") as? [String]
        
        if creatureList != nil && quizList != nil {
            
            let enemyName = creatureList!.randomElement()!
            let event = quizList!.randomElement()!
            
            // create creature
            let npcNode = spawnFieldEnemy(npcName: enemyName, position: nil, event: event, identifier: event, axisInfo: nil)
            
            // load creature and run encounter sequence
            if npcNode.enemy == true {
                self.gameState = 3
                npcNode.state = 3
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    if self.eventCtrl.isBeingPresented == false && self.eventCtrl.isInEvent == false {
                        self.allowNpcControls = false
                        self.present(self.eventCtrl, animated: false) {
                            self.eventCtrl.runFieldEnemyEncounter(enemyNode: npcNode)
                        }
                    }
                }
            }
        }
        
        //
        //
    }
    
    // Animating Scenes - Scenekit
    
    func loadInGameActions(name: String, node: SCNNode, action: Bool) {
        
        // find and load scene
        let igaNode = self.igaScene.rootNode.childNode(withName: name, recursively: true)
        
        // load action only
        if igaNode != nil {
            if action == true {
                for actionKey in igaNode!.actionKeys {
                    node.runAction((igaNode?.action(forKey: actionKey))!)
                    print("running action \(actionKey)")
                }
            } else {
                // set position
                igaNode?.position = node.worldPosition
                self.sceneView.scene?.rootNode.addChildNode(igaNode!)
            }
        }
    }
    
    func organizeFrontNodePoint(refNode: Any) -> SCNNode? {
        
        let refName = (refNode as! SCNNode).name
        let owName = refName?.components(separatedBy: "-").first
        
        // check for npc
        for theNPC in npcPlayers! {
                        
            if (theNPC as! SCNNode).name == owName {
                
                let currentNPC = theNPC as! NPCNode
                
                if currentNPC.enemy == true {
                    return nil
                } else {
                    return currentNPC.headTop.presentation
                }
            }
        }
        
        
        
        // check for indicatorAxis (indicatorAxis)
        if let children = (refNode as? SCNNode)?.childNodes {
            for child in children {
                if ((child.name?.contains("indicatorAxis")) != nil) {
                    return child
                }
            }
        }
        
        return refNode as? SCNNode
    }
    
    //
    //
    // Player Control (SCREEN) (GAME CONTROLLER)
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        super.touchesBegan(touches, with: event)
        
        if allowNpcControls == true {
            
            let firstTapPt = touches.first?.location(in: sceneView)
            if firstTapPt != nil {
                
                // if no hit testing detected, start dpad
                let leftSideScreen = UIScreen.main.bounds.size.width * 0.3
                
                if firstTapPt!.x < leftSideScreen {
                    tapPoint = firstTapPt
                    
                    //dpadDragPoint.center = tapPoint
                    sk?.dPad?.position = spriteScene!.convertPoint(fromView: tapPoint!)
                    //dpadDisplay.center = tapPoint
                    sk?.dPadDisp?.position = spriteScene!.convertPoint(fromView: tapPoint!)
                    
                    //dpadDisplay.isHidden = false;
                    sk?.dPadDisp?.isHidden = false
                    //dpadDisplay.alpha = 1.0;
                    sk?.dPadDisp?.alpha = 1.0
                    //dpadDragPoint.isHidden = false;
                    sk?.dPad?.isHidden = false
                    
                    tapped = false
                    updateCAngle();
                } else {
                    
                    if allows360Cam == true {
                                                
                        isPanning = false
                        rPadTapPoint = firstTapPt
                        
                    }
                    
                }
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        super.touchesMoved(touches, with: event)
        
        // only detect dpad only once movement from tap point was detected
        
        if allowNpcControls == true {
            
            let leftSideScreen = UIScreen.main.bounds.size.width * 0.5
            
            // only do this when dpad is activated
            if sk!.dPadDisp!.isHidden == false {
                
                let dragPt = touches.first?.location(in: self.view)
                let convertedDpadAngle = shaders.degrees(radians: Float(shaders.getDragPoint(start: tapPoint, end: dragPt!)))
                dpadDistance = shaders.pointDist(p1: tapPoint, p2: dragPt!)
                sk?.dPad?.position =  spriteScene!.convertPoint(fromView: dragPt!)
                if dpadDistance > 5 && dragPt!.x < leftSideScreen {
                    dpadAngle = convertedDpadAngle;
                    tapped = true
                }
            } else {
                
                if allows360Cam == true {
                    
                    let dragPt = touches.first?.location(in: self.view)
                    rAngle = shaders.degrees(radians: Float(shaders.getDragPoint(start: rPadTapPoint, end: dragPt!)))
                    cameraPan = shaders.pointDist(p1: rPadTapPoint, p2: dragPt!) // distance between rpad and drag point
                    
                    if dragPt!.x > leftSideScreen {
                        if cameraPan > 5 {
                            isPanning = true
                        }
                    }
                    
                    
                }
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        dpadDistance = Float(1.0)
        playerIsMoving = false
        //dpadDisplay.isHidden = true;
        sk?.dPadDisp?.isHidden = true
        //dpadDragPoint.isHidden = true;
        sk?.dPad?.isHidden = true
        player.travelSpeed = 0.0;
        tapped = false
        isPanning = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        dpadDistance = Float(1.0)
        playerIsMoving = false
        //dpadDisplay.isHidden = true;
        sk?.dPadDisp?.isHidden = true
        //dpadDragPoint.isHidden = true;
        sk?.dPad?.isHidden = true
        player.travelSpeed = 0.0;
        tapped = false
        isPanning = false
    }
    
    func ObserveForGameControllers() {
        NotificationCenter.default.addObserver(self, selector: #selector(connectControllers), name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disconnectControllers), name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
    }
    
    @objc func connectControllers() {
            
    //Unpause the Game if it is currently paused
    //self.sceneView.scene?.isPaused = false
    //Used to register the Nimbus Controllers to a specific Player Number
    var indexNumber = 0
    // Run through each controller currently connected to the system
    for controller in GCController.controllers() {
        //Check to see whether it is an extended Game Controller (Such as a Nimbus)
        if controller.extendedGamepad != nil {
            controller.playerIndex = GCControllerPlayerIndex.init(rawValue: indexNumber)!
            indexNumber += 1
            setupControllerControls(controller: controller)
        }
    }
}
    
    @objc func disconnectControllers() {
        // Pause the Game if a controller is disconnected ~ This is mandated by Apple
        //self.sceneView.scene?.isPaused = true
    }
    
    func setupControllerControls(controller: GCController) {
        
        //Function that check the controller when anything is moved or pressed on it
        controller.extendedGamepad?.valueChangedHandler = {
        (gamepad: GCExtendedGamepad, element: GCControllerElement) in
            // Add movement in here for sprites of the controllers
            self.controllerInputDetected(gamepad: gamepad, element: element, index: controller.playerIndex.rawValue)
        }
    }
    
    func controllerInputDetected(gamepad: GCExtendedGamepad, element: GCControllerElement, index: Int) {
        
        // Left Thumbstick
        if (gamepad.leftThumbstick == element) {
            
            if allowNpcControls == true {
                
                let xVal = gamepad.leftThumbstick.xAxis.value
                let yVal = gamepad.leftThumbstick.yAxis.value
                let dragPt = CGPoint(x: CGFloat(xVal), y: CGFloat(-yVal))
                let convertedDpadAngle = shaders.degrees(radians: Float(shaders.getDragPoint(start: CGPoint.zero, end: dragPt)))
                
                dpadDistance = shaders.pointDist(p1: CGPoint.zero, p2: dragPt) * 100
                
                if gamepad.leftThumbstick.xAxis.value != 0 || gamepad.leftThumbstick.yAxis.value != 0 {
                    dpadAngle = convertedDpadAngle
                    tapped = true
                }
            }
            
            if gamepad.leftThumbstick.yAxis.value == 0 && gamepad.leftThumbstick.xAxis.value == 0 {
                // stop player from moving
                playerIsMoving = false
                //dpadDisplay.isHidden = true;
                sk?.dPadDisp?.isHidden = true
                //dpadDragPoint.isHidden = true;
                sk?.dPad?.isHidden = true
                player.travelSpeed = 0.0;
                tapped = false
                isPanning = false
            }
            
        }
        
        // Right Thumbstick
        if (gamepad.rightThumbstick == element) {
            if (gamepad.rightThumbstick.xAxis.value != 0) {
                    print("Controller: \(index), rightThumbstickXAxis: \(gamepad.rightThumbstick.xAxis)")
            }
        }
        
        // D-Pad
        else if (gamepad.dpad == element) {
            if (gamepad.dpad.xAxis.value != 0) {
                    print("Controller: \(index), D-PadXAxis: \(gamepad.rightThumbstick.xAxis)")
            }
            else if (gamepad.dpad.xAxis.value == 0) {
                // YOU CAN PUT CODE HERE TO STOP YOUR PLAYER FROM MOVING
            }
        }
        
        // A-Button
        else if (gamepad.buttonA == element) {
            
            if (gamepad.buttonA.value != 0) {
                print("Controller: \(index), A-Button Pressed!")
                if eventCtrl.isInEvent == true {
                    eventCtrl.nextBtnTapped(gamepad.buttonA)
                } else {
                    if allowNpcControls == true {
                        controlButtonTapped(gamepad.buttonA)
                    }
                }
            }
        }
        
        // B-Button
        else if (gamepad.buttonB == element) {
            if (gamepad.buttonB.value != 0) {
                print("Controller: \(index), B-Button Pressed!")
            }
        }
        else if (gamepad.buttonY == element) {
            if (gamepad.buttonY.value != 0) {
                print("Controller: \(index), Y-Button Pressed!")
            }
        }
        else if (gamepad.buttonX == element) {
            if (gamepad.buttonX.value != 0) {
                print("Controller: \(index), X-Button Pressed!")
            }
        }
    }
    
    //
    //
    //
    
    /// Function progressData(cmd: String!) manages custom game progress. cmd must contain "type of command/valueForKey "
    func progressData(cmd:NSDictionary) {
        
        print("progressData -> \(cmd)")
        
        let key = cmd.object(forKey: "key") as! String
        let data = cmd.object(forKey: "data")
        let newlyCreated = cmd.object(forKey: "new") as? Bool ?? false
        // check if current key already exists in users current progress
        var currentProgKey = self.parentVC?.gameProgressOf(key: key)
        
        // create new progress entry
        if newlyCreated == true {
            print("newlyCreated(true) called - progress Data")
            self.parentVC?.setGameProgressOf(key: key, data: data!)
            currentProgKey = self.parentVC?.gameProgressOf(key: key)
        }
        
        
        // progress data update
        if currentProgKey != nil {
            
            // add number to existing entry
            if let add = (cmd.object(forKey: "add") as? NSNumber) {
                var existingValue = currentProgKey as! NSNumber
                let calc = existingValue.intValue + add.intValue
                existingValue = NSNumber(value: calc)
                self.parentVC?.setGameProgressOf(key: key, data: existingValue)
            }
            
            // subtract number to existing entry
            
        }
        
        print("progressData current:\(String(describing: currentProgKey))")
        
    }
    
    
    
    @IBAction func controlButtonTapped(_ sender: Any) {
        
        spriteScene?.run(parentVC!.tapSound)
        
        if frontNode != nil {
            
            // for non-event node <e.g. object>
            if (frontNode?.accessibilityValue) != nil {
                // for name identifier attached node
                if let nodeName = frontNode?.name {
                    if nodeName.contains("OItem") {
                        aBtnTapEllipse.isHidden = true;
                        //self.pickUpItem(itemNode: frontNode!)
                        if let event = frontNode?.accessibilityLabel {
                            // this object also contains event
                            self.present(self.eventCtrl, animated: false) {
                                self.frontNode?.accessibilityLabel = nil; // remove event attached on node
                                self.eventCtrl.prepareEvent(event: event)
                            }
                        }
                        frontNode = nil
                    }
                }
                
                
                return
            }
            
            // for event based node
            if let nodeCommand = frontNode?.accessibilityLabel {
                //
                aButton.isHidden = true;
                aBtnTapEllipse.isHidden = true;
                //
                // front node have
                if nodeCommand.contains("/") {
                    // this command contains functions that requires item
                    let itemCmd = nodeCommand.components(separatedBy: "/")
                    if itemCmd.count > 0 {
                        // This is when item is the key to start next event
                        if itemCmd.first == "item" {
                            
                        }
                    }
                    
                } else {
                    // run event normally when tapped at this object
                    if self.frontNode?.accessibilityLabel == nil {
                        return
                    }
                    // execute command
                    self.present(self.eventCtrl, animated: false) {
                        // only remove event when no "¥" mark
                        var cmdFn:Bool = false
                        if self.frontNode?.accessibilityLabel?.contains("¥") == true {
                            // player should face each other
                            cmdFn = true
                        } else if self.frontNode?.accessibilityLabel?.contains("$") == true {
                            // this player will not face to each other
                        } else {
                            self.frontNode?.accessibilityLabel = nil; // remove event attached on node
                        }
                        
                        
                        
                        
                        if self.frontNode?.name?.contains("OW") == true {
                            // player faces each other
                            
                            let opponent = self.npc(owName: (self.frontNode?.name)!)
                            
                            
                            
                            if opponent != nil {
                                // opponent will face player if event initial is "¥"
                                if cmdFn == true {
                                    self.faceNPC(npc: opponent!, toPosition: self.player.name!, animated: true)
                                }
                                // player will face opponent
                                self.faceNPC(npc: self.player, toPosition: opponent!.name!, animated: true)
                            }
                            
                            //
                            DispatchQueue.main.asyncAfter(deadline: .now()) {
                                self.eventCtrl.prepareEvent(event: nodeCommand)
                            }
                            
                        } else {
                            // start event right away
                            self.eventCtrl.prepareEvent(event: nodeCommand)
                        }
                        
                    }
                }
            }
            
            
            
            
        }
        
    }
    
    
    // menu scheme
    
    @IBAction func menuButtonTapped(_ sender: Any) {
              
        // open game menu
        gameMenu.view.tag = 0
        menuButton.isHidden = true
        self.gameState = 2
        self.sfx(name: "menuOpen.mp3")
        self.present(gameMenu, animated: true)
        
    }
    
    func beginActionRegisterSequence(actionCmd:String) {
        gameMenu.view.tag = 1
        menuButton.isHidden = true
        self.sfx(name: "option.mp3")
        self.present(gameMenu, animated: true) {
            self.gameMenu.registerAction(actionCommand: actionCmd)
        }
    }
    
    
// SCENE CONTROLS
    
    func setPlayerPosition(axisName: String, axisTurn: Bool) {
        
        let axis = node(name: axisName)
        player.position.x = axis.worldPosition.x
        player.position.z = axis.worldPosition.z
        player.zroot.position.y = axis.worldPosition.y
        
        if axisTurn == true {
            player.eulerAngles.y = axis.eulerAngles.y
        }
        
    }
    
    func setNPCPosition(npc:NPCNode, axis: String, faceAxis: String?) {
        
        if let positionNode = self.sceneView.scene?.rootNode.childNode(withName: axis, recursively: true) {
            
            let axisNode = positionNode
            
            npc.position.x = axisNode.worldPosition.x
            npc.position.z = axisNode.worldPosition.z
            npc.zroot.position.y = axisNode.worldPosition.y
            
            if faceAxis != nil {
                faceNPC(npc: npc, toPosition: faceAxis!, animated: false)
            }
        }
        
    }
    
    func faceNPC(npc: NPCNode, toPosition: String, animated: Bool) {
        
        if let axis = self.sceneView.scene?.rootNode.childNode(withName: toPosition, recursively: true) {
            
            let pt2 = shaders.pointAngleFrom(p1: npc.position, p2: axis.worldPosition)
            
            if animated == true {
                npc.addAnimation(npc.walkAnim, forKey: "turn")
                let duration = 0.3
                npc.runAction(SCNAction.rotateTo(x: 0, y: CGFloat(pt2), z: 0, duration: duration, usesShortestUnitArc: true)) {
                    if animated == true {
                        npc.removeAnimation(forKey: "turn", blendOutDuration: 0.2)
                    }
                }
            } else {
                npc.runAction(SCNAction.rotateTo(x: 0, y: CGFloat(pt2), z: 0, duration: 0, usesShortestUnitArc: true))
            }
        }
        
    }
    
    func startMapMove(nextNode: String?) {
        
        if self.view.tag != 179 {
            self.view.tag = 179
            
            // music fades to 50%
            self.parentVC?.fadeBGM(toVolume: 0.3, duration: 0.5)
            self.setNpcControls(allow: false)
            
            // Step 1: Blackout
            UIView.animate(withDuration:0.7) {
                self.sceneView.alpha = 0.0
            } completion: { completed in
                
                // must disable player to walk to stop player from walking
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Step 2: Save Temporary Data to prepare for next scene
                    self.parentVC?.tempPlayerData["lastPosition"] = nextNode
                    // Step 3: Unload Current Scene
                    self.parentVC?.view.tag = 3
                    self.unloadGameScene()
                    //
                    self.dismiss(animated: true) {
                        self.sceneView = nil
                    }
                }
            }
        }
    }
    
    func move(angle: Float) {
                
        // this method is being called constantly 1/60
        frontNode = nil
        
        let onlyWalk = mapProfile!.object(forKey: "noRun") as? Bool ?? false
        let runThreshold:Float = 50.0
        
        if tapped == true {
            
            // delay command to walk/run
            if walkSpeedPercent < 1.0 {
                walkSpeedPercent = walkSpeedPercent + 0.03
            } else {
                walkSpeedPercent = 1.0
            }
            
        } else {
            
            // delay command to stop
            if walkSpeedPercent < 0.1 {
                walkSpeedPercent = 0.0
            } else {
                walkSpeedPercent = walkSpeedPercent - 0.04
            }
        }
        
        //print("move called - percent", walkSpeedPercent)
        
        
        if dpadDistance > runThreshold && onlyWalk == false {
            // run
            self.player.travelSpeed = 0.042;
        } else {
            // walk
            self.player.travelSpeed = 0.018;
        }
        
        //always try to follow the angle
        var cAngle = angle
        
        if allows360Cam == true {
            // FUNCITON: SUCCESS!!
            
            // apply player's angle to walk
            var currentCameraAngle = shaders.degrees(radians: standardCamera.presentation.simdEulerAngles.y)
            let orientation = abs(GLKMathRadiansToDegrees(standardCamera.presentation.eulerAngles.z))
            // fix camera angle
            if currentCameraAngle == 90 {
                currentCameraAngle = -90
            } else if currentCameraAngle == -90 {
                currentCameraAngle = 90
            }
            // check for negative orientation
            if orientation > 90 {
                let cl = 180 - currentCameraAngle
                currentCameraAngle = cl
            }
            
            // apply
            cAngle = angle + currentCameraAngle
            //
        }
        
        // walk towards angle at set amount of speed
        let y = 0 + 1 * cos(shaders.radians(degrees: cAngle))
        let x = 0 + 1 * sin(shaders.radians(degrees: cAngle))
                
        // Add Delay Action
        let delayBlock = SCNAction.run { node in
            self.playerIsMoving = true
        }
        
        // Rotate
        let rotateAction = SCNAction.rotateTo(x: 0, y: CGFloat(shaders.radians(degrees: cAngle)), z: 0, duration: 0.08, usesShortestUnitArc: true)
        
        // get walk percentage for more natural movement
        
        
        // hit wall
        if player.hitWall == true && dpadDistance < 150 {
            player.position = SCNVector3Make(player.repPos.x, 0.0, player.repPos.z)
            //walkSpeedPercent = 0.5
        }
        
        let finalPlayerTravelSpeed = player.travelSpeed * walkSpeedPercent
        let point = CGPoint(x: Double(x * finalPlayerTravelSpeed), y: Double(y * finalPlayerTravelSpeed))
        
        // Move
        let moveAction = SCNAction.moveBy(x: point.x, y: 0.0, z: point.y, duration: 1/60)
        let animateAction = SCNAction.run { node in
            if self.tapped == true {
                if self.dpadDistance > runThreshold && onlyWalk == false {
                    // run
                    self.player.walk(run: true)
                } else {
                    // walk
                    self.player.walk(run: false)
                }
            } else {
                self.player.stop()
            }
        }
        
        let grp = SCNAction.group([rotateAction, moveAction, animateAction])
        
        player.runAction(SCNAction.run({ playerNode in
            
            playerNode.runAction(grp)

            
        }))
        
    }
    
    func getObjectWherePlayerIsOn(npc: NPCNode?) -> String? {
        
        if let plyr = npc {
            
            let p1 = SCNVector3Make(plyr.presentation.worldPosition.x, plyr.zroot.presentation.worldPosition.y+0.3, plyr.presentation.worldPosition.z)
            let p2 = SCNVector3Make(plyr.presentation.worldPosition.x, plyr.zroot.presentation.worldPosition.y-0.3, plyr.presentation.worldPosition.z)
            
            let options :[String: Any] = [SCNHitTestOption.ignoreHiddenNodes.rawValue: false, SCNHitTestOption.categoryBitMask.rawValue: groundMeshBitMask]
            let hitResult = sceneView.scene?.rootNode.hitTestWithSegment(from: p1, to: p2, options: options)
            
            if hitResult != nil {
                if hitResult!.count > 0 {
                    for result in hitResult! {
                        if result.node.name?.contains("gnd") == true {
                            return result.node.name
                        } else if result.node.name?.contains("hopStep") == true {
                            return result.node.name
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    func wallDetect(plyr:NPCNode, contact:SCNPhysicsContact) {
        
        // detect deathItem?
        
        let adj:CGFloat = CGFloat(plyr.travelSpeed * 10)
        if plyr.maxPenetration > contact.penetrationDistance * adj  {
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
    
    func displayObjectHint(style: Int, onNode: SCNNode) {
        
        if style == 1 {
            //let plrNode = node(name: "plr-1") // Circle recommending user to tap on the button
            
        }
        if style == 2 {
            // exclamate/ show ! sign briefly on object
            let plrNode = node(name: "plr-2") // Circle recommending user to tap on the button
            
            // animate
            plrNode.accessibilityValue = onNode.name // register
            
            
            let prep = SCNAction.run { theNode in
                theNode.scale = SCNVector3Make(1.0, 1.0, 1.0)
                theNode.opacity = 1.0
                theNode.isHidden = false
                self.sfx(name: "exclamate.wav")
            }
            let scaleAction = SCNAction.scale(to: 2.0, duration: 0.3)
            let scaleDownAction = SCNAction.scale(to: 1.6, duration: 0.3)
            
            let wait = SCNAction.wait(duration: 1.4)
            let after = SCNAction.run { theNode in
                theNode.isHidden = true
                theNode.opacity = 0.0
                theNode.accessibilityValue = nil
            }
            let action = SCNAction.sequence([prep, scaleAction, scaleDownAction, wait, after])
            
            plrNode.runAction(action)
            
            
        }
        if style == 3 {
            // continous arrow display, gives hint to what user should do
            let plrNode = node(name: "plr-3") // Circle recommending user to tap on the button
            plrNode.enumerateChildNodes { child, stop in
                child.opacity = 1.0
                child.isHidden = false
            }
            plrNode.accessibilityValue = onNode.name // register
            
        }
        
    }
    
    func resetCamAxisPosition() {
        camAxis.position = SCNVector3Make(player.position.x, player.zroot.position.y, player.position.z);
    }
    
    // Data Functions
    func updateCAngle() {
        
        var camDeg = shaders.degrees(radians: standardCamera.presentation.simdEulerAngles.y)
        
        // calc diff
        if camDeg < 0 {
            // turn to positive value
            camDeg += 360
        }
        
        angleCorrection = camDeg
    }
    
    func pointDistF(p1: simd_float2, p2: simd_float2) -> Float {
        let x = (p2.x - p1.x);
        let y = (p2.y - p1.y);
        return sqrtf((x*x) + (y*y))
    }
    
    func node(name: String) -> SCNNode {
        let searchNode = sceneView.scene?.rootNode.childNode(withName: name, recursively: true)
        if searchNode == nil {
            print("!!ERROR!! Node Nil \(name)") //
        }
        return searchNode!
    }
    
    func npc(owName: String) -> NPCNode? {
        
        let npcName = owName.components(separatedBy: "-").first
        let foundNode:SCNNode? = sceneView.scene?.rootNode.childNode(withName: npcName!, recursively: true)
        if foundNode == nil {
            return nil
        }
        if foundNode is NPCNode {
            //print("found NPCNode \(String(describing: npcName))")
            return foundNode as? NPCNode
        }
        
        return nil
    }
    
    func getEnemy(owNode: SCNNode) -> NPCNode? {
        for npc in npcPlayers! {
            
            let npcNode = npc as! NPCNode
            if npcNode.enemy == true {
                if owNode == npcNode.body {
                    return npcNode
                }
            }
        }
        
        return nil
        
    }
    
    /// sfx(name:String) instantly plays sound effects. Must include extension e.g. exclamate.wav
    func sfx(name: String) {
        print("sfx -> \(name)")
        spriteScene?.run(SKAction.playSoundFileNamed("ListenedGameAssets.scnassets/bgm/\(name)", waitForCompletion: false))
    }
    
    func loadTxt(fileName:String) -> String {
        let filePath = Bundle.main.path(forResource: "ListenedGameAssets.scnassets/\(fileName)", ofType: "txt")
        return try! String(contentsOfFile: filePath!, encoding: .utf8)
    }
    
    // System
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .all
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        let mode = newCollection.userInterfaceStyle
        if mode == .dark {
            print("Device became dark")
        } else {
            print("Device became bright")
        }
    }
    
}



//
//
//








extension UIColor {
    convenience init(hexaString: String, alpha: CGFloat = 1) {
        let chars = Array(hexaString.dropFirst())
        self.init(red:   .init(strtoul(String(chars[0...1]),nil,16))/255,
                  green: .init(strtoul(String(chars[2...3]),nil,16))/255,
                  blue:  .init(strtoul(String(chars[4...5]),nil,16))/255,
                  alpha: alpha)}
}

public extension UIDevice {

    static let deviceClass: String = {
        
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // Get Device Class
        //
        func mapToDevice(identifier: String) -> String { // swiftlint:disable:this cyclomatic_complexity
            #if os(iOS)
            switch identifier {
            
            // iOS 14 Compatible Devices Only
            /*
             Class 3 - Low Graphic Setting
             Class 2 - Mid Graphic Setting
             Class 1 - Highest Graphic Setting
             */
            
            case "iPod9,1":                                 return "3"//"iPod touch (7th generation)"

            case "iPhone8,1":                               return "3"//"iPhone 6s"
            case "iPhone8,2":                               return "3"//"iPhone 6s Plus"
            case "iPhone8,4":                               return "3"//"iPhone SE"
            case "iPhone9,1", "iPhone9,3":                  return "3"//"iPhone 7"
            case "iPhone9,2", "iPhone9,4":                  return "3"//"iPhone 7 Plus"
            case "iPhone10,1", "iPhone10,4":                return "2"//"iPhone 8"
            case "iPhone10,2", "iPhone10,5":                return "2"//"iPhone 8 Plus"
            case "iPhone10,3", "iPhone10,6":                return "2"//"iPhone X"
            case "iPhone11,2":                              return "1"//"iPhone XS"
            case "iPhone11,4", "iPhone11,6":                return "1"//"iPhone XS Max"
            case "iPhone11,8":                              return "1"//"iPhone XR"
            case "iPhone12,1":                              return "1"//"iPhone 11"
            case "iPhone12,3":                              return "1"//"iPhone 11 Pro"
            case "iPhone12,5":                              return "1"//"iPhone 11 Pro Max"
            case "iPhone12,8":                              return "1"//"iPhone SE (2nd generation)"
            case "iPhone13,1":                              return "1"//"iPhone 12 mini"
            case "iPhone13,2":                              return "1"//"iPhone 12"
            case "iPhone13,3":                              return "1"//"iPhone 12 Pro"
            case "iPhone13,4":                              return "1"//"iPhone 12 Pro Max"
                
            case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "3"//"iPad 2"
            case "iPad3,1", "iPad3,2", "iPad3,3":           return "3"//"iPad (3rd generation)"
            case "iPad3,4", "iPad3,5", "iPad3,6":           return "3"//"iPad (4th generation)"
            case "iPad6,11", "iPad6,12":                    return "3"//"iPad (5th generation)"
            case "iPad7,5", "iPad7,6":                      return "2"//"iPad (6th generation)"
            case "iPad7,11", "iPad7,12":                    return "2"//"iPad (7th generation)"
            case "iPad11,6", "iPad11,7":                    return "1"//"iPad (8th generation)"
            case "iPad4,1", "iPad4,2", "iPad4,3":           return "3"//"iPad Air"
                
            case "iPad5,3", "iPad5,4":                      return "3"//"iPad Air 2"
            case "iPad11,3", "iPad11,4":                    return "3"//"iPad Air (3rd generation)"
            case "iPad13,1", "iPad13,2":                    return "3"//"iPad Air (4th generation)"
            case "iPad2,5", "iPad2,6", "iPad2,7":           return "3"//"iPad mini"
            case "iPad4,4", "iPad4,5", "iPad4,6":           return "3"//"iPad mini 2"
            case "iPad4,7", "iPad4,8", "iPad4,9":           return "2"//"iPad mini 3"
            case "iPad5,1", "iPad5,2":                      return "2"//"iPad mini 4"
            case "iPad11,1", "iPad11,2":                    return "1"//"iPad mini (5th generation)"
                
            case "iPad6,3", "iPad6,4":                      return "2"//"iPad Pro (9.7-inch)"
            case "iPad7,3", "iPad7,4":                      return "2"//"iPad Pro (10.5-inch)"
            case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4":return "1"//"iPad Pro (11-inch) (1st generation)"
            case "iPad8,9", "iPad8,10":                     return "1"//"iPad Pro (11-inch) (2nd generation)"
            case "iPad6,7", "iPad6,8":                      return "2"//"iPad Pro (12.9-inch) (1st generation)"
            case "iPad7,1", "iPad7,2":                      return "2"//"iPad Pro (12.9-inch) (2nd generation)"
            case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8":return "1"//"iPad Pro (12.9-inch) (3rd generation)"
            case "iPad8,11", "iPad8,12":                    return "1"//"iPad Pro (12.9-inch) (4th generation+LiDAR Scanner)"
                
            case "AppleTV5,3":                              return "0"//"Apple TV"
            case "AppleTV6,2":                              return "0"//"Apple TV 4K"
            case "AudioAccessory1,1":                       return "0"//"HomePod"
            case "AudioAccessory5,1":                       return "0"//"HomePod mini"
                
            case "i386", "x86_64":                          return "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iOS"))"
            default:                                        return identifier
            }
            #elseif os(tvOS)
            switch identifier {
            case "AppleTV5,3": return "Apple TV 4"
            case "AppleTV6,2": return "Apple TV 4K"
            case "i386", "x86_64": return "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "tvOS"))"
            default: return identifier
            }
            #endif
        }

        return mapToDevice(identifier: identifier)
    }()

}
