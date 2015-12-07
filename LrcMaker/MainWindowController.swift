//
//  MainWindow.swift
//  LrcMaker
//
//  Created by Eru on 15/12/7.
//  Copyright © 2015年 Eru. All rights reserved.
//

import Cocoa
import AVFoundation
import QuartzCore

class MainWindowController: NSWindowController, NSXMLParserDelegate {

    var timer: NSTimer!
    var iTunes: iTunesBridge!
    
    // xml parser
    var persistentID: String!
    var whetherGetPath: Bool = false
    var currentKey: String!
    var currentString: String!
    
    // player
    var player: AVAudioPlayer!
    var duration: Int = 0
    var currentPosition: Int = 0
    @IBOutlet weak var playPauseButton: NSButton!
    @IBOutlet weak var playerSlider: NSSlider!
    @IBOutlet weak var positionLabel: NSTextField!
    
    private var errorWin: ErrorWindow!
    private var lyricsArray: [String]!
    private var lrcLineArray: [LyricsLineModel]!
    private var lyricsView: LyricsView!
    @IBOutlet var textView: TextView!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var box: NSBox!
    @IBOutlet weak var infoView: NSView!
    @IBOutlet weak var lrcMakingView: NSView!
    @IBOutlet weak var songTitle: NSTextField!
    @IBOutlet weak var artist: NSTextField!
    @IBOutlet weak var album: NSTextField!
    @IBOutlet weak var maker: NSTextField!
    @IBOutlet weak var path: NSPathControl!
    
    
    convenience init() {
        self.init(windowNibName:"MainWindow")
        self.window?.makeMainWindow()
        iTunes = iTunesBridge()
        switchToView(infoView, animated: false)
        lyricsArray = [String]()
        lrcLineArray = [LyricsLineModel]()
        errorWin = ErrorWindow()
        
        lyricsView = LyricsView(frame: scrollView.frame)
        scrollView.documentView = lyricsView
        let musicPath = NSSearchPathForDirectoriesInDomains(.MusicDirectory, [.UserDomainMask], true).first!
        path.URL = NSURL(string: musicPath)
        
        self.showWindow(nil)
    }
    
    override func windowDidLoad() {
        self.window?.makeKeyAndOrderFront(nil)
    }
    
    //MARK: - Switch Views
    
    func switchToView(view: NSView, animated: Bool) {
        let boxSize:NSSize = box.contentView!.frame.size
        let newSize:NSSize = view.frame.size
        let deltaW:CGFloat = newSize.width - boxSize.width
        let deltaH:CGFloat = newSize.height - boxSize.height
        var windowFrame:NSRect = self.window!.frame
        let y:CGFloat = box.frame.origin.y
        
        windowFrame.size.height += deltaH
        windowFrame.size.width += deltaW
        windowFrame.origin.y -= deltaH
        
        box.contentView = nil
        box.frame.size = newSize
        self.window!.setFrame(windowFrame, display: true, animate: animated)
        box.contentView = view
        box.contentView?.frame.size=newSize
        box.frame.origin.y = y
    }
    
    @IBAction func switchToLyricsMakingView(sender: AnyObject) {
        if player == nil {
            NSBeep()
            errorWin.fadeInAndOutWithErrorString(NSLocalizedString("NO_SONG", comment: ""))
            return
        }
        if songTitle.stringValue.stringByReplacingOccurrencesOfString(" ", withString: "") == "" {
            NSBeep()
            errorWin.fadeInAndOutWithErrorString(NSLocalizedString("NO_TITLE", comment: ""))
            return
        }
        lyricsArray = textView.string!.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
        var isEmpty: Bool = true
        for str in lyricsArray {
            if str.stringByReplacingOccurrencesOfString(" ", withString: "") != "" {
                isEmpty = false
            }
        }
        if isEmpty {
            errorWin.fadeInAndOutWithErrorString(NSLocalizedString("NO_LYRICS", comment: ""))
            return
        }
        lyricsView.setLyricsLayerWithArray(lyricsArray)
        switchToView(lrcMakingView, animated: true)
        self.window!.makeFirstResponder(lyricsView)
    }
    
    @IBAction func switchToInfoView(sender: AnyObject) {
        switchToView(infoView, animated: true)
    }
    
    //MARK: - Player Controller
    
    @IBAction func playPause(sender: AnyObject?) {
        if player == nil {
            return
        }
        if player.playing {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        NSLog("Player is playing")
        iTunes.pause()
        player.play()
        if timer == nil {
            timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "updateTimeTag", userInfo: nil, repeats: true)
        } else {
            timer.fireDate = NSDate()
        }
        playPauseButton.image = NSImage(named: "pause_icon")
        playPauseButton .toolTip = NSLocalizedString("PAUSE", comment: "")
    }
    
    func pause() {
        NSLog("Player paused")
        player.pause()
        if timer != nil {
            timer.fireDate = NSDate.distantFuture()
        }
        playPauseButton.image = NSImage(named: "play_icon")
        playPauseButton .toolTip = NSLocalizedString("PLAY", comment: "")
    }
    
    @IBAction func playAtTime(sender: AnyObject) {
        player.currentTime = (sender as! NSSlider).doubleValue / 1000
        updateTimeTag()
    }
    
    func updateTimeTag() {
        
        self.setValue(Int(player.currentTime * 1000), forKey: "currentPosition")
        
        let currentSec = currentPosition / 1000 % 60
        let currentMin = currentPosition / 60000
        let durationSec = duration / 1000 % 60
        let durationMin = duration / 60000
        
        let currentSecStr: String
        let currentMinStr: String
        let durationSecStr: String
        let durationMinStr: String
        
        if currentSec < 10 {
            currentSecStr = "0\(currentSec)"
        } else {
            currentSecStr = "\(currentSec)"
        }
        
        if currentMin < 10 {
            currentMinStr = "0\(currentMin)"
        } else {
            currentMinStr = "\(currentMin)"
        }
        
        if durationSec < 10 {
            durationSecStr = "0\(durationSec)"
        } else {
            durationSecStr = "\(durationSec)"
        }
        
        if durationMin < 10 {
            durationMinStr = "0\(durationMin)"
        } else {
            durationMinStr = "\(durationMin)"
        }
        
        positionLabel.stringValue = currentMinStr + ":" + currentSecStr + "/" + durationMinStr + ":" + durationSecStr
        
        if !player.playing {
            pause()
        }
    }
    
    //MARK: - Interface Methods
    
    @IBAction func setSongFromiTunes(sender: AnyObject) {
        (sender as! NSButton).enabled = false
        if iTunes.running() {
            songTitle.stringValue = iTunes.currentTitle()
            artist.stringValue = iTunes.currentArtist()
            album.stringValue = iTunes.currentAlbum()
            
            persistentID = (iTunes.currentPersistentID() as NSString).copy() as! String
            if persistentID == "" {
                (sender as! NSButton).enabled = true
                return
            }
            playPause(nil)
            let fm: NSFileManager = NSFileManager.defaultManager()
            let iTunesLibrary: String = NSSearchPathForDirectoriesInDomains(.MusicDirectory, [.UserDomainMask], true).first! + "/iTunes/iTunes Music Library.xml"
            if fm.fileExistsAtPath(iTunesLibrary) {
                let data: NSData = NSData(contentsOfFile: iTunesLibrary)!
                let parser: NSXMLParser = NSXMLParser(data: data)
                parser.delegate = self
                whetherGetPath = false
                currentKey = ""
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                    if parser.parse() == false {
                        NSLog("%@", parser.parserError!)
                    }
                    
                    do {
                        self.player = try AVAudioPlayer(contentsOfURL: self.path.URL!)
                    } catch let theError as NSError {
                        NSLog("%@", theError.localizedDescription)
                        (sender as! NSButton).enabled = true
                        return
                    }
                    self.player.prepareToPlay()
                    NSLog("Song changed")
                    
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.setValue(Int(self.player.duration * 1000), forKeyPath: "self.duration")
                        self.setValue(0, forKey: "currentPosition")
                        self.updateTimeTag()
                        self.playPause(nil)
                        (sender as! NSButton).enabled = true
                    })
                })
            }
        }
    }
    
    @IBAction func setSongInOpenPanel(sender: AnyObject) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["mp3", "m4a", "wav", "aiff"]
        openPanel.extensionHidden = false
        openPanel.beginSheetModalForWindow(self.window!) { (response) -> Void in
            if response == NSFileHandlingPanelOKButton {
                self.path.URL = openPanel.URL
                do {
                    self.player = try AVAudioPlayer(contentsOfURL: openPanel.URL!)
                } catch let theError as NSError {
                    NSLog("%@", theError.localizedDescription)
                    return
                }
                NSLog("Song changed")
                self.setValue(Int(self.player.duration * 1000), forKey: "duration")
                self.setValue(0, forKey: "currentPosition")
                self.player.prepareToPlay()
                self.updateTimeTag()
                self.playPause(nil)
            }
        }
    }
    
    @IBAction func preview(sender: AnyObject) {
    }
    
    @IBAction func shareLrc(sender: AnyObject) {
    }
    
    //MARK: - XML Parser Delegate
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "key" {
            let trimmed = currentString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            currentKey = trimmed
        } else if currentString != nil {
            let trimmed = currentString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            if currentKey == "Persistent ID" && trimmed == persistentID {
                whetherGetPath = true
            }
            if whetherGetPath && currentKey == "Location" {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.path.URL = NSURL(string: trimmed)
                })
                whetherGetPath = false
            }
        }
        currentString = nil
    }
    
    func parser(parser: NSXMLParser, foundCharacters string: String) {
        if currentString == nil {
            currentString = String()
        }
        currentString = currentString + string
    }
    
    // MARK: - Keyboard Events
    
    override func keyDown(theEvent: NSEvent) {
        switch theEvent.keyCode {
        case 123: //left arrow
            Swift.print("Left")
        case 125: //down arrow
            Swift.print("Down")
        case 126: //up arrow
            Swift.print("Up")
        default:
            super.keyDown(theEvent)
        }
    }

}
