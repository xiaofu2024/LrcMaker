//
//  MainWindowController.swift
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
    var currentKey: String!
    var currentString: String!
    var whetherGetPath: Bool = false
    
    // player
    var player: AVAudioPlayer!
    var duration: Int = 0
    var currentPosition: Int = 0
    @IBOutlet weak var playPauseButton: NSButton!
    @IBOutlet weak var playerSlider: NSSlider!
    @IBOutlet weak var positionLabel: NSTextField!
    
    // lyrics Making
    private var lyricsArray: [String]!
    private var lrcLineArray: [LyricsLineModel]!
    private var lyricsView: LyricsView!
    private var currentLine: Int = -1
    
    private var currentView: Int = 1
    private var errorWin: ErrorWindow!
    @IBOutlet var textView: TextView!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var box: NSBox!
    @IBOutlet weak var firstView: NSView!
    @IBOutlet weak var secondView: NSView!
    @IBOutlet weak var songTitle: NSTextField!
    @IBOutlet weak var artist: NSTextField!
    @IBOutlet weak var album: NSTextField!
    @IBOutlet weak var maker: NSTextField!
    @IBOutlet weak var path: NSPathControl!
    
    convenience init() {
        self.init(windowNibName:"MainWindow")
        self.window?.makeMainWindow()
        iTunes = iTunesBridge()
        switchToView(firstView, animated: false)
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
    
    @IBAction func switchToFirstView(sender: AnyObject) {
        switchToView(firstView, animated: true)
        currentView = 1
        lrcLineArray.removeAll()
    }
    
    @IBAction func switchSecondView(sender: AnyObject) {
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
        var i: Int = 0
        while i < lyricsArray.count {
            if lyricsArray[i].stringByReplacingOccurrencesOfString(" ", withString: "") == "" {
                lyricsArray.removeAtIndex(i)
                continue
            } else {
                isEmpty = false
            }
            ++i
        }
        if isEmpty {
            errorWin.fadeInAndOutWithErrorString(NSLocalizedString("NO_LYRICS", comment: ""))
            return
        }
        lyricsView.setLyricsLayerWithArray(lyricsArray)
        switchToView(secondView, animated: true)
        currentView = 2
        currentLine = -1
        player.currentTime = 0
        play()
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
        let lrcContent: NSMutableString = NSMutableString()
        for lrcLine in lrcLineArray {
            let str = NSString(format: "%@%@\n", lrcLine.timeTag,lrcLine.lyricsSentence)
            lrcContent.appendString(str as String)
        }
        print(lrcContent)
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
        if currentView == 1 {
            super.keyDown(theEvent)
        }
        else {
            switch theEvent.keyCode {
            case 123: //left arrow
                leftKeyPressed()
            case 125: //down arrow
                downKeyPressed()
            case 126: //up arrow
                print("Up")
                upKeyPressed()
            default:
                super.keyDown(theEvent)
            }
        }
    }
    
    // Lyrics Making Methods
    func downKeyPressed() {
        let msecPosition: Int = Int(player.currentTime * 1000)
        if lrcLineArray.count > 0 && lrcLineArray.last!.msecPosition == msecPosition {
            errorWin.fadeInAndOutWithErrorString(NSLocalizedString("DUPLICATE_IN_T_PT", comment: ""))
            return
        }
        if currentLine == lyricsArray.count - 1 {
            //Done
            return
        }
        NSLog("Add New Lrc Line")
        currentLine++
        let lrcLine: LyricsLineModel = LyricsLineModel()
        lrcLine.lyricsSentence = lyricsArray[currentLine]
        lrcLine.setTimeTagWithMsecPosition(msecPosition)
        lrcLineArray.append(lrcLine)
        lyricsView.setHighlightedLyricsLayerAtIndex(currentLine)
        
        let viewOrigin: NSPoint = lyricsView.frame.origin
        if currentLine < 4 {
            scrollView.contentView.scrollToPoint(NSMakePoint(viewOrigin.x, viewOrigin.y))
        }
        else if lyricsArray.count-currentLine < 5 {
            scrollView.contentView.scrollToPoint(NSMakePoint(viewOrigin.x, viewOrigin.y+CGFloat(lyricsArray.count-7)*lyricsView.height))
        }
        else {
            scrollView.contentView.scrollToPoint(NSMakePoint(viewOrigin.x, viewOrigin.y+CGFloat(currentLine-3)*lyricsView.height))
        }
    }
    
    func leftKeyPressed() {
        if lrcLineArray.count == 0 || lrcLineArray.last?.lyricsSentence == "" {
            return
        }
        NSLog("End Current Lyrics")
        let msecPosition: Int = Int(player.currentTime * 1000)
        let lrcLine: LyricsLineModel = LyricsLineModel()
        lrcLine.lyricsSentence = ""
        lrcLine.setTimeTagWithMsecPosition(msecPosition)
        lrcLineArray.append(lrcLine)
        lyricsView.changeHighlightedStyle()
    }
    
    func upKeyPressed() {
        
    }

}
