//
//  SKGameScene.swift
//  AdvGame
//
//  Created by Koji Murata on 2022/03/06.
//

import Foundation
import SceneKit
import SpriteKit
import AVFoundation

class SKGameScene: NSObject {
    
    // Outlet Nodes
    var notificationText:SKLabelNode?
    var dPad:SKSpriteNode?
    var dPadDisp:SKSpriteNode?
    var areaTitle:SKLabelNode?
    var encIcon:SKSpriteNode?
    var atUnderline:SKSpriteNode?
    
    weak var parentVC:GameScene?
    
    override init() {
        super.init()
    }
    
    // SpriteScene - DidLoad : Initialize main sprites that functions throughout the game
    func spriteSceneDidLoad() {
        
        notificationText = parentVC?.spriteScene?.childNode(withName: "sk_notificationText") as? SKLabelNode
        dPad = parentVC?.spriteScene?.childNode(withName: "dPadPoint") as? SKSpriteNode
        areaTitle = parentVC?.spriteScene?.childNode(withName: "areaTitle") as? SKLabelNode
        areaTitle?.position.x = border_r() - 20
        areaTitle?.text = "text"
        areaTitle?.alpha = 0.0
        atUnderline = parentVC?.spriteScene?.childNode(withName: "atUnderline") as? SKSpriteNode
        atUnderline?.position.x = border_r()
        atUnderline?.size.width = 0
        atUnderline?.alpha = 1.0
        encIcon = parentVC?.spriteScene?.childNode(withName: "encounteredIcon") as? SKSpriteNode
        encIcon?.position.x = screenCenter().x
        encIcon?.alpha = 0.0
        //
        //let rangeToLeftBorder = SKRange(lowerLimit: 10.0, upperLimit: 150.0)
        //let distanceConstraint = SKConstraint.distance(rangeToLeftBorder, to: (parentVC?.spriteScene)!)
        //dPad!.constraints = [distanceConstraint]
        
        dPadDisp = parentVC?.spriteScene?.childNode(withName: "dPadDisp") as? SKSpriteNode
        
    }
    
    func showNotification(txt:String) {
        
        notificationText?.text = txt
        notificationText?.alpha = 0.5
        notificationText?.isHidden = false
        
        let fadeIn = SKAction.fadeIn(withDuration: 1.0)
        let wait = SKAction.wait(forDuration: 3.0)
        let fadeOut = SKAction.fadeOut(withDuration: 1.5)
        let animationSeq = SKAction.sequence([fadeIn, wait, fadeOut])
        
        notificationText?.run(animationSeq, completion: {
            self.notificationText?.isHidden = true
            self.notificationText?.text = ""
        })
    }
    
    func showAreaTitle(txt:String?) {
        
        let str = txt ?? "シリワレ山"
        areaTitle?.text = str
        let txtWidth = (areaTitle?.calculateAccumulatedFrame().width)!
        
        print("txtWidth :\(txtWidth) at-xScale:\(areaTitle?.xScale) at:\(areaTitle?.frame)")
        
        let wait = SKAction.wait(forDuration: 0.6)
        let fadeIn = SKAction.fadeIn(withDuration: 1.0)
        let widthUp = SKAction.resize(toWidth: txtWidth+40, duration: 0.6)
        widthUp.timingMode = .easeIn
        let fadeLineIn = SKAction.group([fadeIn,widthUp])
        let wait2 = SKAction.wait(forDuration: 3.0)
        let fadeOut = SKAction.fadeOut(withDuration: 1.5)
        
        let txtSeq = SKAction.sequence([wait,fadeIn, wait2, fadeOut])
        let lineSeq = SKAction.sequence([fadeLineIn,wait, wait2, fadeOut])
        
        areaTitle?.run(txtSeq)
        atUnderline?.run(lineSeq)
        
    }
    
    func showEncounteredIcon(show:Bool) {
        
        if show == true {
            let fade = SKAction.fadeIn(withDuration: 0.5)
            encIcon?.run(fade)
        } else {
            let fade = SKAction.fadeOut(withDuration: 0.5)
            encIcon?.run(fade)
        }
        
    }
    
    
    
    
    
    
    func screenCenter() -> CGPoint {
        return (parentVC?.spriteScene?.view!.center)!
    }
    
    func border_r() -> CGFloat {
        return (parentVC?.spriteScene?.view?.bounds.size.width)!
    }
    
    
    
    
    
    
    
    
}
