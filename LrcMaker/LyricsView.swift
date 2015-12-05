//
//  LyricsView.swift
//  LrcMaker
//
//  Created by Eru on 15/12/5.
//  Copyright © 2015年 Eru. All rights reserved.
//

import Cocoa

class LyricsView: NSView {
    
    var textLayers: [CATextLayer]!
    
    required init?(coder: NSCoder) {
        
        super.init(coder: coder)
        
        self.layer = CALayer()
        self.wantsLayer = true
        textLayers = [CATextLayer]()
        
        let h: CGFloat = self.bounds.height / 8
        for var i=0; i<8; ++i {
            let layer = CATextLayer()
            self.layer?.addSublayer(layer)
            layer.anchorPoint = NSZeroPoint
            layer.frame = NSMakeRect(0, CGFloat(i) * h, self.bounds.width, h)
            layer.alignmentMode = kCAAlignmentCenter
            layer.font = NSFont.userFontOfSize(15)
            layer.foregroundColor = NSColor.blackColor().CGColor
            layer.fontSize = 25
            textLayers.append(layer)
        }
    }
    
}
