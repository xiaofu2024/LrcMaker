//
//  LyricsView.swift
//  LrcMaker
//
//  Created by Eru on 15/12/5.
//  Copyright © 2015年 Eru. All rights reserved.
//

import Cocoa

class LyricsView: NSView {
    
    var lyricsLayers: [CATextLayer]!
    var height: CGFloat!
    var attrs: [String:AnyObject]!
    var highlightedAttrs: [String:AnyObject]!
    var currentHighLightedIndex: Int!
    var maxWidth: CGFloat!
    
    //MARK: - Init & Override
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        didWhenInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        didWhenInit()
    }
    
    func didWhenInit() {
        self.layer = CALayer()
        self.wantsLayer = true
        
        attrs = [NSFontAttributeName : NSFont(name: "HiraginoSansGB-W3", size: 17)!]
        attrs[NSForegroundColorAttributeName] = NSColor.blackColor()
        
        highlightedAttrs = [NSFontAttributeName : NSFont(name: "HiraginoSansGB-W6", size: 19)!]
        highlightedAttrs[NSForegroundColorAttributeName] = NSColor.redColor()
        
        lyricsLayers = [CATextLayer]()
        height = (self.frame.height - 5) / 8
    }
    
    override var flipped:Bool {
        get {
            return true
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    // Lyrics Methods
    
    func setLyricsLayerWithArray(lyricsArray: [String]) {
        for anLayer in lyricsLayers {
            anLayer.removeFromSuperlayer()
        }
        lyricsLayers.removeAll()
        maxWidth = 0
        
        for var i = 0; i < lyricsArray.count; ++i {
            let lyrics: String = lyricsArray[i]
            let layer: CATextLayer = CATextLayer()
            self.layer?.addSublayer(layer)
            layer.anchorPoint = NSZeroPoint
            layer.shadowColor = NSColor.orangeColor().CGColor
            layer.shadowRadius = 4
            layer.shadowOpacity = 0
            layer.shadowOffset = CGSizeMake(0,0)
            
            let attributedStr: NSAttributedString = NSAttributedString(string: lyrics, attributes: attrs)
            layer.string = attributedStr
            let w = attributedStr.size().width
            if w > maxWidth {
                maxWidth = w
            }
            layer.frame = NSMakeRect(5, 5 + CGFloat(i) * height, w, height)
            lyricsLayers.append(layer)
            
        }
        self.setFrameSize(NSMakeSize(5 + maxWidth, 5 + CGFloat(lyricsArray.count) * height))
        currentHighLightedIndex = -1
    }
    
    func setHighlightedLyricsLayerAtIndex(index: Int) {
        if currentHighLightedIndex != -1 {
            let str: String = lyricsLayers[currentHighLightedIndex].string as! String
            let attributedStr = NSAttributedString(string: str, attributes: attrs)
            lyricsLayers[currentHighLightedIndex].string = attributedStr
            lyricsLayers[currentHighLightedIndex].shadowOpacity = 0
        }
        currentHighLightedIndex = index
        let str: String = lyricsLayers[index].string as! String
        let attributedStr = NSAttributedString(string: str, attributes: highlightedAttrs)
        let w = attributedStr.size().width
        if w > lyricsLayers[index].frame.width {
            lyricsLayers[index].frame = NSMakeRect(5, CGFloat(index) * height, w, height)
        }
        if w > maxWidth {
            maxWidth = w
            self.setFrameSize(NSMakeSize(5 + maxWidth, 5 + self.frame.height))
        }
        lyricsLayers[index].string = attributedStr
        lyricsLayers[index].shadowOpacity = 1
    }
    
}
