//
//  SceneFunctions.swift
//  AdvGame
//
//  Created by Koji Murata on 7/5/20.
//

import Foundation
import UIKit
import SceneKit
import SpriteKit
import Metal

class AdvShader: NSObject {
    
    weak var parentVC:GameScene?
    var fogColor:UIColor = .white;
    var fogNear:CGFloat = 10;
    var fogFar:CGFloat = 1000;
    var buttonPulseAnim:CAAnimation?
    
    
    
    
    override init() {
        super.init()
    }
    
    func cleanUpScene(scene:SCNScene) {
        scene.rootNode.enumerateHierarchy { node, stop in
            // remove dev trash files
            if let ndName = node.name {
                if ndName.contains("Sampler") {
                    node.removeFromParentNode()
                }
            }
            // remove light
            if node.light != nil {
                node.light = nil;
                node.removeFromParentNode();
            }
        }
    }
    
    func preloadingScene(spItem: NSDictionary) {
        
        if spItem.object(forKey: "ost") != nil {// run ost
            parentVC!.owBGM = spItem.object(forKey: "ost") as? String
        }
        
        // set event-based Node Control
        if let nodeSettings = spItem.object(forKey: "nodeSetting") {
            
            for nodeCmd in nodeSettings as! NSArray {
                
                let cmd = nodeCmd as! NSDictionary
                let nodeName = cmd.object(forKey: "name") as? String ?? "__//nilNode//__"
                let node:SCNNode? = self.parentVC!.sceneView.scene?.rootNode.childNode(withName: nodeName, recursively: true)
                
                if node != nil {
                    if (cmd.object(forKey: "opacity") != nil) {
                        let opacity = Float(cmd.object(forKey: "opacity") as! String)
                        node!.opacity = CGFloat(opacity!)
                    }
                    if (cmd.object(forKey: "hidden") != nil) {
                        let dcmd = Bool(cmd.object(forKey: "hidden") as! Bool)
                        node!.isHidden = dcmd
                    }
                    if (cmd.object(forKey: "setEvent") != nil) {
                        let eventName = cmd.object(forKey: "setEvent") as! String
                        node!.accessibilityLabel = eventName
                        print("nodeAction eventSetTo Node:\(String(describing: node?.name)) eventID:\(String(describing: node?.accessibilityLabel))")
                    }
                    if (cmd.object(forKey: "setObjectID") != nil) {
                        let objectID = cmd.object(forKey: "setObjectID") as! String
                        node!.accessibilityValue = objectID
                    }
                    if let posSimd = cmd.object(forKey: "position.simd") {
                        let posSimdCmd = (posSimd as! String).components(separatedBy: "/")
                        let pscVec:SCNVector3 = SCNVector3Make(Float(posSimdCmd[0])!, Float(posSimdCmd[1])!, Float(posSimdCmd[2])!)
                        node?.position = pscVec
                    }
                    if let posSimd = cmd.object(forKey: "rotation.simd") {
                        let posSimdCmd = (posSimd as! String).components(separatedBy: "/")
                        let pscVec:SCNVector3 = SCNVector3Make(self.radians(degrees: Float(posSimdCmd[0])!), self.radians(degrees: Float(posSimdCmd[1])!), self.radians(degrees: Float(posSimdCmd[2])!))
                        node?.eulerAngles = pscVec
                    }
                }
            }
        }
        
    }
    
    func setupSceneProfile(profileDat: NSDictionary) {
                
        print("setting Scene Profile \(profileDat)")
        
        // Profile FOG
        if let fogSetting = profileDat.object(forKey: "fogSetting") {
            // affects entire scene
            self.overrideFogSetting(inputDat: fogSetting as! String)
        }
        
        // Profile LIGHTS
        if let lightSetting = profileDat.object(forKey: "lightSetting") {
            // affects entire scene
            self.overrideLightSettings(dat_lightSetting: lightSetting as! NSDictionary)
        }
        
        // Profile Camera Setting
        if let cameraSetting = profileDat.object(forKey: "cameraSetting") {
            // affects node
            self.overrideCameraSettings(dat_cameraSetting: cameraSetting as! NSDictionary)
            
            // Setup default perspective
            let defaultPOV = (cameraSetting as! NSDictionary).object(forKey: "defaultCam") as? String ?? "camera-player"
            parentVC?.setOverworldPOV(cameraNode: defaultPOV, duration: 0.0)
            
        } else {
            // Always default
            parentVC?.setOverworldPOV(cameraNode: "camera-player-top", duration: 0.0)
        }
        
        // Profile Texture Intensity
        if let texIntDat = profileDat.object(forKey: "textureIntensity") {
            let datTx = Float(texIntDat as! String)
            parentVC?.texIntensity = CGFloat(datTx!)
        }
        
        // Profile Overlay
        if let overlaySetting = profileDat.object(forKey: "overlaySetting") {
            let dat_overlayImageName = overlaySetting as! String
            let overlayImg = UIImage(named: "ListenedGameAssets.scnassets/\(dat_overlayImageName)")
            if overlayImg != nil {
                let overlayTexture = SKTexture.init(image: overlayImg!)
                let overlayNode = SKSpriteNode.init(texture: overlayTexture, size: (parentVC?.sceneView.bounds.size)!)
                overlayNode.blendMode = .add
                overlayNode.alpha = 0.3
                overlayNode.anchorPoint = CGPoint(x: 0.0, y: 1.0)
                parentVC?.spriteScene?.addChild(overlayNode)
            }
        }
        
        // Profile background
        if let backgroundSetting = profileDat.object(forKey: "sceneBackground") {
            // get HEX
            parentVC?.sceneView.scene?.background.contents = UIImage(named: "ListenedGameAssets.scnassets/\(backgroundSetting as! String)")
        }
        
        // only background color
        if let backgroundColor = profileDat.object(forKey: "backgroundColor") {
            let clrHex = backgroundColor as! String
            print("backgroundColor Detected \(clrHex)")
            parentVC?.sceneView.scene?.background.contents = UIColor.black
        }
        
    }
    
    func setSceneFogHex(hexColor: String, near: CGFloat, far: CGFloat) {
        let clr = UIColor(hexaString: "#\(hexColor)")
        fogColor = clr
        fogNear = near
        fogFar = far
        
        // set it to scenekit
        parentVC?.sceneView.scene?.fogColor = fogColor
        parentVC?.sceneView.scene?.fogStartDistance = near
        parentVC?.sceneView.scene?.fogEndDistance = far
    }
    
    func setSceneFog(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat, near: CGFloat, far: CGFloat) {
        fogColor = UIColor(displayP3Red: r, green: g, blue: b, alpha: 1.0)
        fogNear = near
        fogFar = far
        
        // set it to scenekit
        parentVC?.sceneView.scene?.fogColor = fogColor
        parentVC?.sceneView.scene?.fogStartDistance = near
        parentVC?.sceneView.scene?.fogEndDistance = far
    }
    
    func panOWCamera(angle: CGPoint, param: Float) {
        
        var currentParam = param;
        if param >= 5.0 {
            currentParam = 5.0 // max speed
        }
        
        // parameters to be added
        var xCalc = (angle.x * 5.0)*CGFloat(currentParam); // angle to be added
        let currentXAngle = degrees(radians:parentVC!.camAxis.eulerAngles.y); // up down
        if xCalc >= 15.0 {
            xCalc = 15.0;
        } else if xCalc <= -15.0 {
            xCalc = -15.0;
        }
        let targetXAngle = currentXAngle - Float(xCalc);
        
        // compute X-axis camera movement limit
        let yCalc = (angle.y * 0.2)*CGFloat(currentParam); // angle to be added <has upper/lower limit>
        let yAngle = degrees(radians:parentVC!.camAxis.eulerAngles.x); // up down
        var targetYVal = yAngle-Float(yCalc);
        
        if targetYVal <= -60.0 {
            targetYVal = -60.0
        } else if targetYVal >= -5.0 {
            targetYVal = -5.0
        }
        
        let targetVec = SCNVector3Make(radians(degrees: targetYVal), radians(degrees: targetXAngle), 0.0);
        let rotAction = SCNAction.rotateTo(x: CGFloat(targetVec.x), y: CGFloat(targetVec.y), z: CGFloat(targetVec.z), duration: 0.05);
        rotAction.timingMode = SCNActionTimingMode.easeOut;
        self.parentVC!.camAxis.runAction(rotAction);
        
    }

    
    
    // SHADERS
    func treeShader() -> String {
        return "float offset = _geometry.color.x * (sin(1.3 * u_time + (_geometry.position.x + _geometry.position.z) * 4.0) + 0.5) * 0.02;" +
        "_geometry.position.x += offset;" +
        "vec3 offset2 = vec3(0.1 * (scn_frame.cosTime * (0.0 - _geometry.texcoords[0].y)) * sin( _geometry.position.x),  0.1 * (scn_frame.sinTime * (0.0 - _geometry.texcoords[0].y)) * sin( _geometry.position.x), 0);" +
        "_geometry.position.xyz += offset2;";
    }
    
    func discard() -> String {
        return "float cutoff = 0.5;" +
        "if (_output.color.a <= cutoff) {" +
        "_output.color.a = 0.0;" +
        "} else {" +
        "if (_output.color.a < 1.0) {" +
        "_output.color.a = 1.0;" +
        "}" +
        "}"
    }
    func sharpDiscard() -> String {
        return "float cutoff = 0.9;\n" +
        "if (_output.color.a < cutoff) {discard;}\n";
    }
    
    func treeTrunkDither() -> String {
        return "float4x4 thresholdMatrix = {" +
        "1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0," +
        "13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0," +
        "4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0," +
        "16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0};" +
        "float4 black = float4(1.0);" +
        "float2 spos = (in.fragmentPosition.x/scn_frame.inverseResolution)*1.15;" +
        "int x = int(spos.x);" +
        "int y = int(spos.y);" +
        "float3 fix = black.rgb - thresholdMatrix[x % 4][y % 4];" +
        "float2 spos2 = (in.fragmentPosition.y/scn_frame.inverseResolution)*1.15;" +
        "int x2 = int(spos2.x);" +
        "int y2 = int(spos2.y);" +
        "float3 fix2 = fix - thresholdMatrix[x2 % 4][y2 % 4];" +
        "float minDistance = -6.0;" +
        "float maxDistance = 6.0;" +
        "float dist = in.fragmentPosition.z*100;" +
        "float percentile = (minDistance+dist)/maxDistance;" +
        "float clmp = clamp(percentile,0.0,1.0);" +
        "float inputValue = clmp;" +
        "float opacity = mix(-0.3,1.0,inputValue);" +
        "if (fix2.r < opacity && fix2.g < opacity && fix2.b < opacity) {" +
        "_output.color.a = 0;" +
        "}"
        
        //        "//_output.color.a = 0;" +
    }
    
    func nearObjDithering() -> String {
        return "float4x4 thresholdMatrix = {" +
        "1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0," +
        "13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0," +
        "4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0," +
        "16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0};" +
        "float4 black = float4(1.0);" +
        "float2 spos = (in.fragmentPosition.x/scn_frame.inverseResolution)*1.15;" +
        "int x = int(spos.x);" +
        "int y = int(spos.y);" +
        "float3 fix = black.rgb - thresholdMatrix[x % 4][y % 4];" +
        "float2 spos2 = (in.fragmentPosition.y/scn_frame.inverseResolution)*1.15;" +
        "int x2 = int(spos2.x);" +
        "int y2 = int(spos2.y);" +
        "float3 fix2 = fix - thresholdMatrix[x2 % 4][y2 % 4];" +
        "_output.color.rgb = fix2;" +
        "float minDistance = -3.0;" +
        "float maxDistance = 4.0;" +
        "float dist = in.fragmentPosition.z*100;" +
        "float percentile = (minDistance+dist)/maxDistance;" +
        "float clmp = clamp(percentile,0.0,1.0);" +
        "float inputValue = clmp;" +
        "float opacity = mix(-0.3,1.0,inputValue);" +
        "if (fix2.r < opacity && fix2.g < opacity && fix2.b < opacity) {" +
        "_output.color.a = 0;" +
        "}"
        
        //        "//_output.color.a = 0;" +
    }
    
    func grass_small() -> String {
        return "float random = 1.0;" +
        "vec3 offset = vec3(0.15 * (scn_frame.sinTime * (1.8 * (_geometry.texcoords[0].y-0.45))) * sin(_geometry.position.y + random), 0.0, 0.0);" +
        "_geometry.position.xyz += offset;"
    }
    func grass_mid() -> String {
        return "float random = 1.0;" +
        "vec3 offset = vec3(0.15 * (scn_frame.sinTime * (1.8 * (_geometry.texcoords[0].y-1.048))) * sin(_geometry.position.y + random), 0.0, 0.0);" +
        "_geometry.position.xyz += offset;"
    }
    func tree_leaves1() -> String {
        return "vec4 pos = u_modelTransform * _geometry.position;\n" +
        "_geometry.position.z += sin(u_time + pos.z) * 0.01 * _geometry.color.r;\n" +
        "_geometry.position.x += cos((u_time * 1.2) + pos.x) * 0.015 * _geometry.color.r;\n";
    }
    
    func tree_leaves_pbr() -> String {
        return "float offset = _geometry.color.x * (sin(1.3 * u_time + (_geometry.position.x + _geometry.position.z) * 4.0) + 0.5) * 0.02;\n" +
        "_geometry.position.x += offset;\n" +
        "vec3 offset2 = vec3(0.1 * (scn_frame.cosTime * (0.0 - _geometry.texcoords[0].y)) * sin( _geometry.position.x),  0.1 * (scn_frame.sinTime * (0.0 - _geometry.texcoords[0].y)) * sin( _geometry.position.x), 0);\n" +
        "_geometry.position.xyz += offset2;";
    }
    
    func smallRiverEdge() -> String {
        return "_geometry.texcoords[1].x -= scn_frame.time * 0.5;" +
        "_geometry.texcoords[1].y += (scn_frame.sinTime * 0.1);"
    }
    
    func underWaterWarp() -> String {
        return "float Amplitude = 0.05;" +
        "float Frequency = 10000;" +
        "vec2 nrm = _geometry.position.xz;" +
        "float len = length(nrm)+10;" +
        "nrm /= len;" +
        "float a = len + Amplitude*sin(Frequency * _geometry.position.z - u_time * 10);" +
        "_geometry.position.xz = nrm * a;"
    }
    
    func darken_grass() -> String {
        return "_geometry.color.rgb -= 0.3;";
    }
    
    func waterGeometry() -> String {
        return "float Amplitude = 0.1;\n" +
        "float Frequency = 35.0;\n" +
        "vec2 nrm = _geometry.position.xz;\n" +
        "float len = length(nrm)+0.0001;\n" +
        "nrm /= len;\n" +
        "float a = len + Amplitude*sin(Frequency * _geometry.position.z + u_time * 1.0);\n" +
        "_geometry.position.xz = nrm * a;\n" +
        "_geometry.texcoords[0].x += u_time*0.2;\n" +
        "_geometry.texcoords[1].x += u_time*0.1;\n";
    }
    
    func water_fall() -> String {
        return "_geometry.texcoords[0].y -= 1.5*u_time;\n" +
        "float Amplitude = 0.1;\n" +
        "float Frequency = 200.0;\n" +
        "vec2 nrm = _geometry.position.xz;\n" +
        "float len = length(nrm)+0.01;\n" +
        "nrm /= len;\n" +
        "float a = len + Amplitude*sin(Frequency * _geometry.position.z + u_time * 5.0);\n" +
        "_geometry.position.xz = nrm * a;\n";
    }
    
    /// moveUV_Yaxis - creates geometry shader modifier at y axis uvSpeed (String) this denotes the speed of the UV to surpass
    func moveUV_Yaxis(uvSpeed: String?) -> String {
        let uv = uvSpeed ?? "1.5"
        return "_geometry.texcoords[0].y -= \(uv)*u_time;\n";
    }
    func moveUV_Xaxis(uvSpeed: String?) -> String {
        let uv = uvSpeed ?? "1.5"
        return "_geometry.texcoords[0].x -= \(uv)*u_time;\n";
    }
    
    func water_norm() -> String {
           return "_geometry.texcoords[0].y -= 1.0*u_time;\n";
       }
    
    /// monitoredNodeRemoveAllAttributes: will remove all animation/particle/positional audio and remove from monitored node list
    func removeAttributesFromNode(nodeName: String) {
        
        let nodeToMonitor = self.parentVC?.sceneView.scene?.rootNode.childNode(withName: nodeName, recursively: true)
        if let nd = nodeToMonitor {
            nd.removeAllAnimations()
            nd.removeAllActions()
            nd.removeAllParticleSystems()
            nd.removeAllAudioPlayers()
            
        }
    }
    
    
    // _output.color.rgb = currentRgb * (shdrOutput * 1.5);
    func waterFragMod() -> String {
        return "float3 origP = _surface.position;\n" +
        "float3 n = _surface.normal;\n" +
        "float3 p = float3(origP.x,origP.y,origP.z);\n" +
        "float3 v = normalize(-p);\n" +
        "float vdn = 1.0 - max(dot(v,n), 0.0);\n" +
        "float3 shdrOutput = float3(smoothstep(0.3,1.0, vdn));\n" +
        "float3 currentRgb = _output.color.rgb;\n" +
        "_output.color.rgb = currentRgb * (shdrOutput * 1.5);\n" +
        "const float4 currentVC = in.vertexColor;\n" +
        "_output.color.rgb = _output.color.rgb * currentVC.rgb;\n" +
        "float3 cCorrection = _output.color.rgb * (_lightingContribution.diffuse + _lightingContribution.ambient);\n" +
        "float4 gl_Position = scn_frame.viewTransform * float4(_surface.position, 0.0);\n" +
        "float fogDistance = length(gl_Position.xyz);\n" +
        "float3 fp = scn_frame.fogParameters;\n" +
        "float3 fogParam = clamp(fogDistance * fp.x + fp.y, 0.0, fp.z);\n" +
        "float3 fogColoring = scn_frame.fogColor.rgb;\n" +
        "_output.color.rgb = mix(cCorrection, fogColoring, fogParam);\n";
    }
    
    func fogShader() -> String {
                
        return "float fogDat = pow(clamp(length(_surface.position.xyz) * scn_frame.fogParameters.x + scn_frame.fogParameters.y, 0., scn_frame.fogColor.a), scn_frame.fogParameters.z);" +
        "_output.color.rgb = mix(_output.color.rgb, scn_frame.fogColor.rgb * _output.color.a, fogDat);" +
        "_output.color *= in.vertexColor;"
    }
    
    func waterSurfaceMod() -> String {
        
        /*
         
         */
        
        return "float waterSpeed = u_time * -0.1;\n" +
        "vec2 uvs = _surface.normalTexcoord;\n" +
        "uvs.x *= 2;\n" +
        "vec3 tn = texture2D(u_normalTexture, vec2(uvs.x, uvs.y + waterSpeed)).xyz;\n" +
        "tn = tn * 2 - 1;\n" +
        "vec3 tn2 = texture2D(u_normalTexture, vec2(uvs.x + 10.0 , uvs.y + 1.35 + (waterSpeed * 1.3))).xyz;\n" +
        "tn2 = tn2 * 2 - 1;\n" +
        "vec3 rn = (tn + tn2) * 0.5;\n" +
        "mat3 ts = mat3(_surface.tangent, _surface.bitangent, _surface.geometryNormal);\n" +
        "_surface.normal = normalize(ts * rn);\n";
        
    }
    
    func tGake() -> String {
        
        return "#pragma arguments\n" +
        "texture2d underGake;\n" +
        "#pragma transparent\n" +
        "#pragma body\n" +
        "constexpr sampler noiseSampler(filter::linear, address::repeat);\n" +
        "float2 texCoord = _surface.ambientTexcoord;\n" +
        "const float4 currentVC = in.vertexColor;\n" +
        "const float3 edgeTop = _surface.diffuse.rgb;\n" +
        "_output.color.a = 1.0;\n" +
        "const float3 edgeUnder = underGake.sample(noiseSampler, texCoord).rgb * currentVC.rgb;\n" +
        "float3 mixed = mix(edgeUnder, edgeTop, _surface.transparent.a);\n" +
        "float3 cCorrection = mixed * (_lightingContribution.diffuse + _lightingContribution.ambient);\n" +
        "_output.color.rgb = cCorrection;\n" +
        "float4 gl_Position = scn_frame.viewTransform * float4(_surface.position, 0.0);\n" +
        "float3 origP = _surface.position;\n" +
        "float3 n = _surface.normal;\n" +
        "float3 p = float3(origP.x,origP.y,origP.z);\n" +
        "float3 v = normalize(-p);\n" +
        "float vdn = 1.0 - max(dot(v,n), 0.0);\n" +
        "float3 shdrOutput = float3(smoothstep(0.9,1.0, vdn));\n" +
        "_output.color.rgb = _output.color.rgb + (shdrOutput*0.05);\n" +
        "float fogDistance = length(gl_Position.xyz);\n" +
        "float3 fp = scn_frame.fogParameters;\n" +
        "float3 fogParam = clamp(fogDistance * fp.x + fp.y, 0.0, fp.z);\n" +
        "float3 fogColoring = scn_frame.fogColor.rgb;\n" +
        "_output.color.rgb = mix(_output.color.rgb, fogColoring, fogParam);\n" +
        "float4x4 thresholdMatrix = {" +
        "1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0," +
        "13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0," +
        "4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0," +
        "16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0};" +
        "float4 black = float4(1.0);" +
        "float2 spos = (in.fragmentPosition.x/scn_frame.inverseResolution)*1.15;" +
        "int x = int(spos.x);" +
        "int y = int(spos.y);" +
        "float3 fix = black.rgb - thresholdMatrix[x % 4][y % 4];" +
        "float2 spos2 = (in.fragmentPosition.y/scn_frame.inverseResolution)*1.15;" +
        "int x2 = int(spos2.x);" +
        "int y2 = int(spos2.y);" +
        "float3 fix2 = fix - thresholdMatrix[x2 % 4][y2 % 4];" +
        "float minDistance = -6.0;" +
        "float maxDistance = 6.0;" +
        "float dist = in.fragmentPosition.z*100;" +
        "float percentile = (minDistance+dist)/maxDistance;" +
        "float clmp = clamp(percentile,0.0,1.0);" +
        "float inputValue = clmp;" +
        "float opacity = mix(-0.3,1.0,inputValue);" +
        "if (fix2.r < opacity && fix2.g < opacity && fix2.b < opacity) {" +
        "_output.color.a = 0;" +
        "}";
        
    }
    
    func tGakeClear() -> String {
        
        return "#pragma arguments\n" +
        "texture2d underGake;\n" +
        "#pragma transparent\n" +
        "#pragma body\n" +
        "constexpr sampler noiseSampler(filter::linear, address::repeat);\n" +
        "float2 texCoord = _surface.ambientTexcoord;\n" +
        "const float4 currentVC = in.vertexColor;\n" +
        "const float3 edgeTop = _surface.diffuse.rgb;\n" +
        "_output.color.a = 1.0;\n" +
        "const float3 edgeUnder = underGake.sample(noiseSampler, texCoord).rgb * currentVC.rgb;\n" +
        "float3 mixed = mix(edgeUnder, edgeTop, _surface.transparent.a);\n" +
        "float4 gl_Position = scn_frame.viewTransform * float4(_surface.position, 0.0);\n" +
        "float3 origP = _surface.position;\n" +
        "float3 n = _surface.normal;\n" +
        "float3 p = float3(origP.x,origP.y,origP.z);\n" +
        "float3 v = normalize(-p);\n" +
        "float vdn = 1.0 - max(dot(v,n), 0.0);\n" +
        "float3 shdrOutput = float3(smoothstep(0.9,1.0, vdn));\n" +
        "_output.color.rgb = _output.color.rgb + (shdrOutput*0.05);\n" +
        "_output.color.a = _surface.transparent.a;" +
        "if (_output.color.a <= 0.6) {" +
        "_output.color.a = 0.0;" +
        "} else if (_output.color.a > 0.6 && _output.color.a < 1.0) {" +
        "_output.color.a = 1.0;" +
        "}" +
        "float4x4 thresholdMatrix = {" +
        "1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0," +
        "13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0," +
        "4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0," +
        "16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0};" +
        "float4 black = float4(1.0);" +
        "float2 spos = (in.fragmentPosition.x/scn_frame.inverseResolution)*1.15;" +
        "int x = int(spos.x);" +
        "int y = int(spos.y);" +
        "float3 fix = black.rgb - thresholdMatrix[x % 4][y % 4];" +
        "float2 spos2 = (in.fragmentPosition.y/scn_frame.inverseResolution)*1.15;" +
        "int x2 = int(spos2.x);" +
        "int y2 = int(spos2.y);" +
        "float3 fix2 = fix - thresholdMatrix[x2 % 4][y2 % 4];" +
        "float minDistance = -6.0;" +
        "float maxDistance = 6.0;" +
        "float dist = in.fragmentPosition.z*100;" +
        "float percentile = (minDistance+dist)/maxDistance;" +
        "float clmp = clamp(percentile,0.0,1.0);" +
        "float inputValue = clmp;" +
        "float opacity = mix(-0.3,1.0,inputValue);" +
        "if (fix2.r < opacity && fix2.g < opacity && fix2.b < opacity) {" +
        "_output.color.a = 0;" +
        "}";
        
    }
    
    func normalSetupForGround() -> String {
        
        return "float3 origP = _surface.position;\n" +
        "float3 n = _surface.normal;\n" +
        "float3 p = float3(origP.x,origP.y,origP.z);\n" +
        "float3 v = normalize(-p);\n" +
        "float vdn = 1.0 - max(dot(v,n), 0.0);\n" +
        "float3 shdrOutput = float3(smoothstep(0.9,1.0, vdn));\n" +
        "float3 currentRgb = _output.color.rgb;\n" +
        "_output.color.rgb = currentRgb + (shdrOutput*0.05);\n";
        
    }
    
    func normalShineFra() -> String {
                
        return "float3 origP = _surface.position;\n" +
        "float3 n = _surface.normal;\n" +
        "float3 p = float3(origP.x,origP.y+0.5,origP.z);\n" +
        "float3 v = normalize(-p);\n" +
        "float vdn = 1.0 - max(dot(v,n), 0.0);\n" +
        "float3 shdrOutput = float3(smoothstep(0.2,0.99, vdn));\n" +
        "float3 currentRgb = _output.color.rgb;\n" +
        "_output.color.rgb = currentRgb + (shdrOutput*0.05);\n" +
        "float4 gl_Position = scn_frame.viewTransform * float4(_surface.position, 0.0);\n" +
        "float fogDistance = length(gl_Position.xyz);\n" +
        "float3 fp = scn_frame.fogParameters;\n" +
        "float3 fogParam = clamp(fogDistance * fp.x + fp.y, 0.0, fp.z);\n" +
        "float3 fogColoring = scn_frame.fogColor.rgb;\n" +
        "_output.color.rgb = mix(_output.color.rgb, fogColoring, fogParam);\n";
        
        // do not ignore the fog
    }
    
    
    
    
    
    /// spawnEnemiesInScene : Spawns Enemy within the scene
    func spawnEnemiesInScene(scene: SCNScene?) {
        
        // load scene
        scene?.rootNode.enumerateChildNodes({ (node, nil) in
            
            // find axis
            if let name = node.name {
                
                if node.isHidden == false {
                    if name.contains("Spawn") {
                        // run spawn command and add into the scene
                        
                        // decode axis information
                        let axisDat = name.components(separatedBy: "-")
                        // Sample: Spawn-Hatebo-yb1250a
                        
                        let enemyName = axisDat[1] // Hatebo
                        let event = axisDat[2]
                        let npcEnemy = parentVC?.spawnFieldEnemy(npcName: enemyName, position: node.name, event: event, identifier: event, axisInfo: node)
                        
                        // get walk speed
                        let charProfile = (parentVC?.parentVC?.dat.object(forKey: "characterProfile") as! NSDictionary).object(forKey: enemyName as Any) as! NSDictionary
                        
                        npcEnemy?.chasingSpeed = Float(charProfile.object(forKey: "chaseSpeed") as? String ?? "0.03")!
                                                
                    }
                }
                
            }
        })
    }
    
    func walkForever(npc:NPCNode) {
        
        if npc.state == 1 {
            return
        }
        npc.state = 1;
        
        // default setting
        if npc.enemyAxis != nil {
            npc.goTo(axis: npc.enemyAxis!)
        }
        
        // get walk speed of NPC
        let charProfile = (self.parentVC?.parentVC?.dat.object(forKey: "characterProfile") as! NSDictionary).object(forKey: npc.name!) as! NSDictionary
        let walkSpeed = Float(charProfile.object(forKey: "walkSpeed") as! String)!
        
        var axes: Array<SCNNode> = []
        
        npc.enemyAxis!.enumerateChildNodes { (childAxis, nil) in
            axes.append(childAxis)
        }
        // sort for patterned walk direction
        axes = axes.sorted(by: { (Obj1, Obj2) -> Bool in
            let Obj1_Name = Obj1.name ?? ""
            let Obj2_Name = Obj2.name ?? ""
            return (Obj1_Name.localizedCaseInsensitiveCompare(Obj2_Name) == .orderedAscending)
        })
        
        axes.append(npc.enemyAxis!)
        
        // create stacked array of scnaction
        var actionStack: Array<SCNAction> = []
        var axisBefore:SCNNode? = npc.enemyAxis!
        
        for axs in axes {
            
            // calculate distance to get walk duration
            let dist = self.parentVC?.pointDistF(p1: simd_float2(axisBefore!.worldPosition.x, axisBefore!.worldPosition.z), p2: simd_float2(axs.worldPosition.x, axs.worldPosition.z))
            // get duration
            let duration = dist!/walkSpeed
            
            // get face angle + action with animation
            let faceAction = self.faceAction(fromAxis: axisBefore!, toAxis: axs)
            
            // walkAction
            let nextPosition = SCNVector3Make(axs.worldPosition.x, 0.0, axs.worldPosition.z)
            let walkAction = SCNAction.move(to: nextPosition, duration: TimeInterval(duration))
            
            // combineAction
            let seq = SCNAction.group([faceAction, walkAction])
            actionStack.append(seq)
                        
            axisBefore = axs
        }
        
        let groupedAction = SCNAction.sequence(actionStack)
        
        npc.runAction(SCNAction.repeatForever(groupedAction))
        npc.walk(run: false)
        
    }
    
    func faceAction(fromAxis: SCNNode, toAxis: SCNNode) -> SCNAction {
        let duration = 0.3
        let pt2 = self.pointAngleFrom(p1: fromAxis.worldPosition, p2: toAxis.worldPosition)
        return SCNAction.rotateTo(x: 0, y: CGFloat(pt2), z: 0, duration: duration, usesShortestUnitArc: true)
        
    }
    
    // monitor last update
    var wasBeingChased = false
    
    func controlChasedBGM(beingChased: Bool) {
        
        // must over ride if game is ending
        
        if self.parentVC?.gameState == 0 {
            if beingChased == true && wasBeingChased == false {
                //self.parentVC?.parentVC?.changeBGM(bgmId: "encountered")
                
                self.parentVC?.parentVC?.fadeBGM(toVolume: 0.0, duration: 0.6)
                self.parentVC?.parentVC?.fadeToENV(bgmId: "encountered", duration: 1.0, volume: 1.0)
                // show
                self.parentVC?.sk?.showEncounteredIcon(show: true)
                
                
            } else if beingChased == false && wasBeingChased == true {
                
                self.parentVC?.parentVC?.fadeENV(toVolume: 0.0, duration: 3.0)

                // check for few seconds before returing bgm
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
                    if beingChased == true || self.wasBeingChased == true {
                        self.parentVC?.parentVC?.fadeBGM(toVolume: 1.0, duration: 3.0)
                    }
                })
                // hide
                self.parentVC?.sk?.showEncounteredIcon(show: false)
            }
        } else {
            self.parentVC?.parentVC?.fadeENV(toVolume: 0.0, duration: 3.0)
        }
        
        wasBeingChased = beingChased
    }
    
    
    
    
    
    
    
    
    
    func colorToRGB(uiColor: UIColor) -> CIColor
    {
        return CIColor(color: uiColor)
    }
    
    /**
     Adds repeating sounds to the node.  (Must be Mono Audio) put extesion at the end (i.e, .wav .mp3 )
    */
    func addSound(filename: String, node: SCNNode, volume: Float) {
        //!@abstract Must

        //  add positional sound
        if let source = SCNAudioSource(fileNamed: "ListenedGameAssets.scnassets/bgm/\(filename)")
        {
            source.volume = volume
            source.rate = 1.0
            source.reverbBlend = 1.0
            source.isPositional = true
            source.shouldStream = false
            source.loops = true
            source.load()
            //
            let player = SCNAudioPlayer(source: source)
            node.addAudioPlayer(player)
            
            print("Added audio to \(String(describing: node.name))")
        }
    }
    
    func playSound(filename: String, node: SCNNode, volume: Float) {
        //!@abstract Must

        //  add positional sound
        if let source = SCNAudioSource(fileNamed: "ListenedGameAssets.scnassets/bgm/\(filename)")
        {
            source.volume = volume
            source.rate = 1.0
            source.reverbBlend = 1.0
            source.isPositional = true
            source.shouldStream = false
            source.loops = false
            
            source.load()
            //
            let player = SCNAudioPlayer(source: source)
            
            node.addAudioPlayer(player)
            
            print("Added audio to \(String(describing: node.name))")
        }
    }
    
    
    func degrees(radians:Float) -> Float {
        return (radians*(180.0/Float(Double.pi)));
    }
    
    func bearingDegree(input: Float) -> Float {
        
        return input * 180 / .pi
    }
    
    func radians(degrees:Float) -> Float {
        return (Float(Double.pi)*degrees)/180;
    }
    
    func getDragPoint(start: CGPoint, end:CGPoint) -> CGFloat {
        let origin = CGPoint(x: end.x - start.x, y: end.y - start.y)
        return atan2(origin.x, origin.y)
    }
    
    func pointDist(p1: CGPoint, p2: CGPoint) -> Float {
        let x = (p2.x - p1.x);
        let y = (p2.y - p1.y);
        return sqrtf(Float((x*x) + (y*y)))
    }
    
    func pointAngleFrom(p1: SCNVector3, p2: SCNVector3) -> Float {
        let origin:simd_float2 = simd_make_float2(p2.x - p1.x, p2.z - p1.z)
        let bearingRad = atan2f(origin.y, origin.x) // get bearing in radians
        var bearingDeg = (bearingRad * (180/Float.pi)) + 90
        bearingDeg = -bearingDeg + 180
        return radians(degrees: bearingDeg)
    }
    
    func nodeUnder(player: NPCNode) -> SCNNode? {
        
        let p1 = SCNVector3Make(player.presentation.position.x, player.zroot.presentation.position.y+0.3, player.presentation.position.z)
        let p2 = SCNVector3Make(player.presentation.position.x, player.zroot.presentation.position.y-0.3, player.presentation.position.z)
        
        let options :[String: Any] = [
            SCNHitTestOption.categoryBitMask.rawValue: 2,
            SCNHitTestOption.ignoreHiddenNodes.rawValue: false]
        
        let hitResult = self.parentVC!.sceneView.scene?.rootNode.hitTestWithSegment(from: p1, to: p2, options: options).first
        if hitResult != nil {
            return hitResult?.node
        }
        
        return nil
    }
    
    func overrideFogSetting(inputDat: String) {
        let dat_fogSetting = inputDat.components(separatedBy: "/")
        let fogClr = dat_fogSetting[0]
        let fogStrDist = CGFloat(Float(dat_fogSetting[1]) ?? 0)
        let fogEndDist = CGFloat(Float(dat_fogSetting[2]) ?? 0)
        setSceneFogHex(hexColor: fogClr, near: fogStrDist, far: fogEndDist)
    }
    
    func overrideCameraSettings(dat_cameraSetting: NSDictionary) {
                
        //let duration = Double(dat_cameraSetting.object(forKey: "saturation") as? String ?? "0.0") ?? 0.0
        
        let hdr = dat_cameraSetting.object(forKey: "hdr") as? Bool ?? false
        let cSat = Float(dat_cameraSetting.object(forKey: "saturation") as! String)
        let cCont = Float(dat_cameraSetting.object(forKey: "contrast") as! String)
        let cTemp = Float(dat_cameraSetting.object(forKey: "temperature") as! String)
        let cAvgGray = Float(dat_cameraSetting.object(forKey: "averageGray") as! String)
        let cExpMin = Float(dat_cameraSetting.object(forKey: "exposureMinimum") as! String)
        let cExpMax = Float(dat_cameraSetting.object(forKey: "exposureMaximum") as! String)
        let cTint = Float(dat_cameraSetting.object(forKey: "tint") as? String ?? "1.0")
        var fStop:CGFloat = 2.0
        var bloom:CGFloat = 1
        var maxQ:Bool = false
        
        if UIDevice.deviceClass == "1" {
            maxQ = true
        }
        
        let deviceDetail = UIDevice().userInterfaceIdiom
        if deviceDetail == .pad {
            fStop = 3.5
            bloom = 0.3
        }
        
        self.parentVC?.map!.rootNode.enumerateHierarchy({ node, stop in
            
            if node.camera != nil {
                
                //print("configuring camera \(String(describing: node.name))")
                
                node.camera?.wantsHDR = hdr
                node.camera?.zFar = 300 // default
                node.camera?.saturation = CGFloat(cSat!)
                node.camera?.contrast = CGFloat(cCont!)
                node.camera?.whiteBalanceTemperature = CGFloat(cTemp!)
                node.camera?.averageGray = CGFloat(cAvgGray!)
                node.camera?.minimumExposure = CGFloat(cExpMin!)
                node.camera?.maximumExposure = CGFloat(cExpMax!)
                node.camera?.wantsDepthOfField = true
                if cTint != nil {
                    node.camera?.whiteBalanceTint = CGFloat(cTint!)
                }
                //
                // Possible Issue right here <Over blur when running on iPad>
                node.camera?.focusDistance = 1
                node.camera?.fStop = fStop
                node.camera?.apertureBladeCount = 5;
                node.camera?.focalBlurSampleCount = 4
                
                if maxQ == true {
                    node.camera?.bloomIntensity = bloom
                    node.camera?.bloomThreshold = 0.5
                    node.camera?.bloomBlurRadius = 13.6
                    node.camera?.bloomIterationCount = 1
                    node.camera?.bloomIterationSpread = 0
                } else {
                    node.camera?.wantsHDR = false
                    node.camera?.wantsDepthOfField = false
                }
            }
        });
        
        self.parentVC?.sceneView.scene?.rootNode.enumerateHierarchy({ node, stop in
            
            if node.camera != nil {
                
                //print("configuring camera \(String(describing: node.name))")
                
                node.camera?.wantsHDR = hdr
                node.camera?.zFar = 300 // default
                node.camera?.saturation = CGFloat(cSat!)
                node.camera?.contrast = CGFloat(cCont!)
                node.camera?.whiteBalanceTemperature = CGFloat(cTemp!)
                node.camera?.averageGray = CGFloat(cAvgGray!)
                node.camera?.minimumExposure = CGFloat(cExpMin!)
                node.camera?.maximumExposure = CGFloat(cExpMax!)
                node.camera?.wantsDepthOfField = true
                if cTint != nil {
                    node.camera?.whiteBalanceTint = CGFloat(cTint!)
                }
                //
                // Possible Issue right here <Over blur when running on iPad>
                node.camera?.focusDistance = 1
                node.camera?.fStop = fStop
                node.camera?.apertureBladeCount = 5;
                node.camera?.focalBlurSampleCount = 4
                
                if maxQ == true {
                    node.camera?.bloomIntensity = bloom
                    node.camera?.bloomThreshold = 0.5
                    node.camera?.bloomBlurRadius = 13.6
                    node.camera?.bloomIterationCount = 1
                    node.camera?.bloomIterationSpread = 0
                } else {
                    node.camera?.wantsHDR = false
                    node.camera?.wantsDepthOfField = false
                }
            }
        });
    }
    
    func setIndividualCameraProfile(camNode: SCNNode?, currentProfile: NSDictionary) {
        
        let dat_cameraSetting = currentProfile.object(forKey: "cameraSetting") as! NSDictionary
        
        let hdr = dat_cameraSetting.object(forKey: "hdr") as? Bool ?? false
        let cSat = Float(dat_cameraSetting.object(forKey: "saturation") as! String)
        let cCont = Float(dat_cameraSetting.object(forKey: "contrast") as! String)
        let cTemp = Float(dat_cameraSetting.object(forKey: "temperature") as! String)
        let cAvgGray = Float(dat_cameraSetting.object(forKey: "averageGray") as! String)
        let cExpMin = Float(dat_cameraSetting.object(forKey: "exposureMinimum") as! String)
        let cExpMax = Float(dat_cameraSetting.object(forKey: "exposureMaximum") as! String)
        let cTint = Float(dat_cameraSetting.object(forKey: "tint") as? String ?? "1.0")
        var fStop:CGFloat = 2.0
        var bloom:CGFloat = 1
        var maxQ:Bool = false
        
        if UIDevice.deviceClass == "1" {
            maxQ = true
        }
        
        let deviceDetail = UIDevice().userInterfaceIdiom
        if deviceDetail == .pad {
            fStop = 3.5
            bloom = 0.3
        }
        
        if let cameraNode = camNode {
            if cameraNode.camera != nil {
                
                //print("configuring camera \(cameraNode)")
                
                cameraNode.camera?.wantsHDR = hdr
                cameraNode.camera?.zFar = 300 // default
                cameraNode.camera?.saturation = CGFloat(cSat!)
                cameraNode.camera?.contrast = CGFloat(cCont!)
                cameraNode.camera?.whiteBalanceTemperature = CGFloat(cTemp!)
                cameraNode.camera?.averageGray = CGFloat(cAvgGray!)
                cameraNode.camera?.minimumExposure = CGFloat(cExpMin!)
                cameraNode.camera?.maximumExposure = CGFloat(cExpMax!)
                cameraNode.camera?.wantsDepthOfField = true
                if cTint != nil {
                    cameraNode.camera?.whiteBalanceTint = CGFloat(cTint!)
                }
                //
                // Possible Issue right here <Over blur when running on iPad>
                cameraNode.camera?.focusDistance = 1
                cameraNode.camera?.fStop = fStop
                cameraNode.camera?.apertureBladeCount = 5;
                cameraNode.camera?.focalBlurSampleCount = 4
                
                if maxQ == true {
                    cameraNode.camera?.bloomIntensity = bloom
                    cameraNode.camera?.bloomThreshold = 0.5
                    cameraNode.camera?.bloomBlurRadius = 13.6
                    cameraNode.camera?.bloomIterationCount = 1
                    cameraNode.camera?.bloomIterationSpread = 0
                } else {
                    cameraNode.camera?.wantsHDR = false
                    cameraNode.camera?.wantsDepthOfField = false
                }
            }
        }
    }
    
    func overrideLightSettings(dat_lightSetting: NSDictionary) {
        
        let duration = Double(dat_lightSetting.object(forKey: "duration") as? String ?? "0.0") ?? 0.0
        let defColor = dat_lightSetting.object(forKey: "DEFColor") as! String
        let defIntensity = Float(dat_lightSetting.object(forKey: "DEFIntensity") as! String)
        let snnColor = dat_lightSetting.object(forKey: "SNNColor") as! String
        let snnIntensity = Float(dat_lightSetting.object(forKey: "SNNIntensity") as! String)
        let defLight = parentVC!.node(name: "DEFLight")
        let snnLight = parentVC!.node(name: "SNNLight")
        
        if UIDevice.deviceClass == "1" {
            // High Res
            snnLight.light?.shadowSampleCount = 16
            snnLight.light?.shadowRadius = 3
        } else {
            // Low Res
            snnLight.light?.shadowSampleCount = 5
            snnLight.light?.shadowRadius = 3
        }
        
        // apply
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        defLight.light?.color = UIColor(hexaString: "#\(defColor)")
        defLight.light?.intensity = CGFloat(defIntensity!)
        snnLight.light?.color = UIColor(hexaString: "#\(snnColor)")
        snnLight.light?.intensity = CGFloat(snnIntensity!)
        SCNTransaction.commit()
    }
    
    
    // ONLY ONE TIME FUNCTION <Pulsating animation
    func pulseAnim() -> CAAnimation {
        //
        if buttonPulseAnim != nil {
            return buttonPulseAnim!
        }
        //
        let pulseAnim = CABasicAnimation(keyPath: "transform.scale")
        pulseAnim.duration = 3.0
        pulseAnim.fromValue = NSNumber(value: 0.25)
        pulseAnim.toValue = NSNumber(value: 1.25)
        pulseAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        //
        let opacityPulse = CAKeyframeAnimation(keyPath: "opacity")
        opacityPulse.values = [NSNumber(value: 0.0),NSNumber(value: 1.0),NSNumber(value: 0.5),NSNumber(value: 0.1),NSNumber(value: 0.0)];
        opacityPulse.keyTimes = [NSNumber(value: 0.0),NSNumber(value: 0.2),NSNumber(value: 0.5),NSNumber(value: 0.8),NSNumber(value: 1.0)];
        opacityPulse.duration = 3.0;
        //
        let tapPulse = CAAnimationGroup()
        tapPulse.duration = 3.0
        tapPulse.repeatCount = HUGE
        tapPulse.autoreverses = false
        tapPulse.animations = [pulseAnim, opacityPulse]
        //
        buttonPulseAnim = tapPulse
        return buttonPulseAnim!
        //
    }
    
    
}

