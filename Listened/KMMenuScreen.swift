//
//  KMMenuScreen.swift
//  AdvGame
//
//  Created by Koji Murata on 2/6/21.
//

import Foundation
import UIKit

class KMCell: UICollectionViewCell {
    
    @IBOutlet var backgroundImageView:UIImageView!
}

class KMMenuScreen: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    
    @IBOutlet var background:UIImageView!
    @IBOutlet var titleLogo:UIImageView!
    @IBOutlet var tableBG:UIImageView!
    @IBOutlet var tableGradientMask:UIImageView!
    
    @IBOutlet var stageMenu: UICollectionView!
    @IBOutlet var continueButton: UIButton!
    
    var dataPointer: [Any]?
    var elements_count:Int = 0
    
    weak var parentVc:ViewController?
    
    @IBAction func `continue`(_ sender: Any) {
        
        parentVc?.selectedGameKey = "continue"
        parentVc?.view.tag = 5 // ready to play game
        self.parentVc?.playSound(fileName: "mysteryRiff", fileExtension: "mp3", volume: 0.5)
        self.parentVc?.fadeBGM(toVolume: 0.0, duration: 2.0)
        
        UIView.animate(withDuration: 1.0, delay: 1.0, options: .curveEaseInOut) {
            self.view.alpha = 0.0
        } completion: { comp in
            // Prepare to start game
            self.dismiss(animated: false) {
                self.parentVc?.titleDidLoad_startGame()
            }
        }
        
    }
    
    /*
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var text = dataPointer![indexPath.row] as? String
        
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "theCell", for: indexPath)
        cell.textLabel?.textAlignment = .left
        
        if text?.contains("#") == true {
            // main title
            text = text?.replacingOccurrences(of: "#", with: "")
            cell.textLabel?.font = UIFont(name: "Avenir Next Medium", size: 16.0);
            cell.textLabel?.text = text
            cell.textLabel?.textColor = UIColor.black
        } else {
            cell.textLabel?.font = UIFont(name: "Avenir Next", size: 14.0);
            cell.textLabel?.text = "     " + text!;
            cell.textLabel?.textColor = UIColor.gray
        }
        
        return cell
        
    }
    */
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        stageMenu.delegate = self
        stageMenu.dataSource = self
        //stageMenu.register(KMCell.self, forCellWithReuseIdentifier: "theCell")
        
        
        background.alpha = 0.0
        background.transform = CGAffineTransform.init(scaleX: 1.2, y: 1.2)
        titleLogo.alpha = 0.0
        tableBG.alpha = 0.0
        tableBG.transform = CGAffineTransform.init(translationX: 30, y: 0)
        tableGradientMask.alpha = 0.0
        
        stageMenu.alpha = 0.0
        continueButton.alpha = 0.0
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseInOut) {
            self.background.alpha = 1.0
        } completion: { comp in
            
            self.parentVc?.playAudio(bgmId: "town")
            
            UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseInOut) {
                self.titleLogo.alpha = 1.0
            } completion: { comp in
                
                UIView.animate(withDuration: 0.2, delay: 0.2, options: .curveEaseInOut) {
                    self.tableBG.alpha = 1.0
                    self.tableBG.transform = CGAffineTransform.init(translationX: 0, y: 0)
                } completion: { comp in
                    self.tableGradientMask.alpha = 1.0
                    UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseInOut) {
                        self.stageMenu.alpha = 1.0
                        self.continueButton.alpha = 1.0
                        
                    }
                }
            }
        }
        
        UIView.animate(withDuration: 3.0) {
            self.background.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        elements_count = (dataPointer!.count * 2) - 1
        return elements_count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // create cell
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "theCell", for: indexPath) as! KMCell
        
        // detect odd number
        if indexPath.row % 2 == 0 {
            // even - display stage button
            let index = indexPath.row / 2
            var actionBtnImage = UIImage(named: "stg\(index).png")
            
            if actionBtnImage == nil {
                actionBtnImage = UIImage(named: "lockedStage.png")
            }
            cell.backgroundImageView.image = actionBtnImage
            cell.backgroundImageView.layer.masksToBounds = true
            cell.backgroundImageView.layer.cornerRadius = cell.frame.size.width/2
        } else {
            let actionBtnImage = UIImage(named: "stage-between.png")
            cell.backgroundImageView.image = actionBtnImage
        }
        
        return cell
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        //
        if indexPath.row % 2 == 0 {
            let index = indexPath.row / 2
            self.parentVc?.selectedGameKey = (dataPointer![index] as? String)?.components(separatedBy: ":").first
            parentVc?.view.tag = 5
            //
            self.parentVc?.playSound(fileName: "mysteryRiff", fileExtension: "mp3", volume: 0.5)
            self.parentVc?.fadeBGM(toVolume: 0.0, duration: 2.0)
            //
            UIView.animate(withDuration: 1.0, delay: 1.0, options: .curveEaseInOut) {
                self.view.alpha = 0.0
            } completion: { comp in
                // Prepare to start game
                self.dismiss(animated: false) {
                    self.parentVc?.titleDidLoad_startGame()
                }
            }
            //
        }
        //
    }
    
    /*
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (dataPointer!.count * 2)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // Set Selected Game Key
        parentVc?.selectedGameKey = (dataPointer![indexPath.row] as? String)?.components(separatedBy: ":").first
        parentVc?.view.tag = 5 // ready to play game
        
        self.parentVc?.playSound(fileName: "mysteryRiff", fileExtension: "mp3", volume: 0.5)
        self.parentVc?.fadeBGM(toVolume: 0.0, duration: 2.0)
        
        UIView.animate(withDuration: 1.0, delay: 1.0, options: .curveEaseInOut) {
            self.view.alpha = 0.0
        } completion: { comp in
            // Prepare to start game
            self.dismiss(animated: false) {
                self.parentVc?.titleDidLoad_startGame()
            }
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 45.0
    }*/
    
}

