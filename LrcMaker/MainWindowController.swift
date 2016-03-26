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

class MainWindowController: NSWindowController {
    
    var iTunes: iTunesBridge!
    var needsLoadingSong: Bool = false
    // player
    var player: AVAudioPlayer!
    var duration: Int = 0
    var currentPosition: Int = 0
    var timeTagUpdateTimer: NSTimer!
    @IBOutlet weak var playPauseButton: NSButton!
    @IBOutlet weak var playerSlider: NSSlider!
    @IBOutlet weak var positionLabel: NSTextField!
    
    // lyrics Making
    var lyricsArray: [String]!
    var lrcLineArray: [LyricsLineModel]!
    var lyricsView: LyricsView!
    var currentLine: Int = -1
    var isSaved: Bool = false
    
    var currentView: Int = 1
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
    @IBOutlet weak var lyricsXButton: NSButton!
    @IBOutlet weak var saveButton: NSButton!
    
    convenience init() {
        self.init(windowNibName:"MainWindow")
        self.window?.makeMainWindow()
        iTunes = iTunesBridge()
        switchToView(firstView, animated: false)
        lrcLineArray = [LyricsLineModel]()
        
        lyricsView = LyricsView(frame: scrollView.frame)
        scrollView.documentView = lyricsView
        let musicPath = NSSearchPathForDirectoriesInDomains(.MusicDirectory, [.UserDomainMask], true).first!
        path.URL = NSURL(string: musicPath)
        NSDistributedNotificationCenter.defaultCenter().addObserver(self, selector: #selector(iTunesPlayerInfoChanged(_:)), name: "com.apple.iTunes.playerInfo", object: nil)
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
        if currentView == 2 {
            if lrcLineArray.count > 0 && !isSaved {
                let alert: NSAlert = NSAlert()
                alert.messageText = NSLocalizedString("NOT_SAVE", comment: "")
                alert.informativeText = NSLocalizedString("CHECK_LEAVE", comment: "")
                alert.addButtonWithTitle(NSLocalizedString("CANCEL", comment: ""))
                alert.addButtonWithTitle(NSLocalizedString("LEAVE", comment: ""))
                alert.beginSheetModalForWindow(self.window!, completionHandler: { (response) -> Void in
                    if response == NSAlertSecondButtonReturn {
                        self.switchToView(self.firstView, animated: true)
                        self.currentView = 1
                        self.lrcLineArray.removeAll()
                    }
                })
                return
            }
        }
        switchToView(firstView, animated: true)
        currentView = 1
        lrcLineArray.removeAll()
    }
    
    @IBAction func switchSecondView(sender: AnyObject) {
        if player == nil {
            NSBeep()
            ErrorWindowController.sharedErrorWindow.displayError(NSLocalizedString("NO_SONG", comment: ""))
            return
        }
        if songTitle.stringValue.stringByReplacingOccurrencesOfString(" ", withString: "") == "" {
            NSBeep()
            ErrorWindowController.sharedErrorWindow.displayError(NSLocalizedString("NO_TITLE", comment: ""))
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
            i += 1
        }
        if isEmpty {
            ErrorWindowController.sharedErrorWindow.displayError(NSLocalizedString("NO_LYRICS", comment: ""))
            return
        }
        lyricsView.setLyricsLayerWithArray(lyricsArray)
        scrollView.contentView.scrollToPoint(lyricsView.frame.origin)
        switchToView(secondView, animated: true)
        currentView = 2
        currentLine = -1
        lyricsXButton.enabled = false
        saveButton.enabled = false
        isSaved = false
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
        if timeTagUpdateTimer == nil {
            timeTagUpdateTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(updateTimeTag), userInfo: nil, repeats: true)
        } else {
            timeTagUpdateTimer.fireDate = NSDate()
        }
        playPauseButton.image = NSImage(named: "pause_icon")
        playPauseButton .toolTip = NSLocalizedString("PAUSE", comment: "")
    }
    
    func pause() {
        NSLog("Player paused")
        player.pause()
        if timeTagUpdateTimer != nil {
            timeTagUpdateTimer.fireDate = NSDate.distantFuture()
        }
        playPauseButton.image = NSImage(named: "play_icon")
        playPauseButton .toolTip = NSLocalizedString("PLAY", comment: "")
    }
    
    @IBAction func jumpToTime(sender: AnyObject) {
        let timePoint: Int = Int((sender as! NSSlider).doubleValue)
        player.currentTime = Double(timePoint) / 1000
        updateTimeTag()
        
        // In the 2nd View
        if currentView == 2 && lrcLineArray.count > 0 {
            if timePoint < lrcLineArray.last?.msecPosition {
                lyricsXButton.enabled = false
                saveButton.enabled = false
                isSaved = false
                
                var i: Int = 0
                var lrcCount: Int = 0
                while i < lrcLineArray.count {
                    if lrcLineArray[i].msecPosition > timePoint {
                        lrcLineArray.removeRange(i...lrcLineArray.count-1)
                        break
                    }
                    else {
                        if lrcLineArray[i].lyricsSentence != "" {
                            lrcCount += 1
                        }
                    }
                    i += 1
                }
                if lrcLineArray.count > 0 {
                    currentLine = lrcCount - 1
                    if lrcLineArray.last?.lyricsSentence == "" {
                        lyricsView.setHighlightedAtIndex(currentLine, andStyle: 2)
                    }
                    else {
                        lyricsView.setHighlightedAtIndex(currentLine, andStyle: 1)
                    }
                }
                else {
                    currentLine = -1
                    lyricsView.unsetHighlighted()
                }
            }
            scrollViewToFit()
        }
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
    
    //MARK: - Music Source
    
    @IBAction func setSongFromiTunes(sender: AnyObject) {
        if !iTunes.running() {
            return
        }
        if iTunes.playing() {
            needsLoadingSong = true
            iTunes.pause()
        }
        else {
            needsLoadingSong = true
            iTunes.playPause()
            iTunes.pause()
        }
    }
    
    @IBAction func setSongInOpenPanel(sender: AnyObject) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["mp3", "m4a", "wav", "aiff"]
        openPanel.extensionHidden = false
        openPanel.beginSheetModalForWindow(self.window!) { (response) -> Void in
            if response == NSFileHandlingPanelOKButton {
                self.songTitle.stringValue = ""
                self.artist.stringValue = ""
                self.album.stringValue = ""
                self.path.URL = openPanel.URL
                do {
                    self.player = try AVAudioPlayer(contentsOfURL: openPanel.URL!)
                } catch let theError as NSError {
                    NSLog("%@", theError.localizedDescription)
                    ErrorWindowController.sharedErrorWindow.displayError(NSLocalizedString("FAILED_INIT_PLAYER", comment: ""))
                    let musicPath = NSSearchPathForDirectoriesInDomains(.MusicDirectory, [.UserDomainMask], true).first!
                    self.path.URL = NSURL(string: musicPath)
                    return
                }
                NSLog("Song changed")
                let asset = AVURLAsset(URL: self.path.URL!, options: nil)
                asset.loadValuesAsynchronouslyForKeys(["commonMetadata"], completionHandler: { () -> Void in
                    let metadatas: [AVMetadataItem]
                    if openPanel.URL?.pathExtension == "mp3" {
                        metadatas = AVMetadataItem.metadataItemsFromArray(asset.commonMetadata, withKey: nil, keySpace: AVMetadataKeySpaceID3)
                    }
                    else {
                        metadatas = AVMetadataItem.metadataItemsFromArray(asset.commonMetadata, withKey: nil, keySpace: AVMetadataKeySpaceiTunes)
                    }
                    for md in metadatas {
                        switch md.commonKey! {
                        case "title":
                            self.songTitle.stringValue = md.value as! String
                        case "artist":
                            self.artist.stringValue = md.value as! String
                        case "albumName":
                            self.album.stringValue = md.value as! String
                        default:
                            break
                        }
                    }
                })
                self.setValue(Int(self.player.duration * 1000), forKey: "duration")
                self.setValue(0, forKey: "currentPosition")
                self.player.prepareToPlay()
                self.updateTimeTag()
                if NSUserDefaults.standardUserDefaults().boolForKey("LMPlayWhenAdded") {
                    self.play()
                }
            }
        }
    }
    
    //MARK: - Save lrc
    
    @IBAction func saveLrc(sender: AnyObject) {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["lrc"]
        panel.nameFieldStringValue = songTitle.stringValue + " - " + artist.stringValue + ".lrc"
        panel.extensionHidden = false
        panel.beginSheetModalForWindow(self.window!) { (response) -> Void in
            if response == NSFileHandlingPanelOKButton {
                let lrcContents: String = self.generateLrc()
                let fm = NSFileManager.defaultManager()
                if fm.fileExistsAtPath(panel.URL!.path!) {
                    do {
                        try fm.removeItemAtPath(panel.URL!.path!)
                    } catch let theError as NSError {
                        NSLog("%@", theError.localizedDescription)
                        return
                    }
                }
                do {
                    try lrcContents.writeToURL(panel.URL!, atomically: false, encoding: NSUTF8StringEncoding)
                } catch let theError as NSError {
                    NSLog("%@", theError.localizedDescription)
                    return
                }
                self.isSaved = true
            }
        }
    }
    
    @IBAction func sendLrcToLyricsX(sender: AnyObject) {
        let lrcContent: String = generateLrc()
        let userInfo: [String:AnyObject] = ["SongTitle" : songTitle.stringValue,
            "Artist" : artist.stringValue,
            "Sender" : "LrcMaker",
            "LyricsContents" : lrcContent]
        NSDistributedNotificationCenter.defaultCenter().postNotificationName("ExtenalLyricsEvent", object: nil, userInfo: userInfo, deliverImmediately: true)
    }
    
    func generateLrc() -> String {
        var lrcContents: String = String()
        if self.songTitle.stringValue.stringByReplacingOccurrencesOfString(" ", withString: "") != "" {
            lrcContents.appendContentsOf("[ti:" + self.songTitle.stringValue + "]\n")
        }
        if self.artist.stringValue.stringByReplacingOccurrencesOfString(" ", withString: "") != "" {
            lrcContents.appendContentsOf("[ar:" + self.artist.stringValue + "]\n")
        }
        if self.album.stringValue.stringByReplacingOccurrencesOfString(" ", withString: "") != "" {
            lrcContents.appendContentsOf("[al:" + self.album.stringValue + "]\n")
        }
        if self.maker.stringValue.stringByReplacingOccurrencesOfString(" ", withString: "") != "" {
            lrcContents.appendContentsOf("[by:" + self.maker.stringValue + "]\n")
        }
        lrcContents.appendContentsOf("[tool:LrcMaker]\n")
        for lrcLine in self.lrcLineArray {
            let str = String(format: "%@%@\n", lrcLine.timeTag!,lrcLine.lyricsSentence)
            lrcContents.appendContentsOf(str)
        }
        if lrcContents.characters.count > 0 {
            lrcContents.removeAtIndex(lrcContents.endIndex.advancedBy(-1))
        }
        return lrcContents
    }
    
    // MARK: - Keyboard Events
    
    override func keyDown(theEvent: NSEvent) {
        if currentView == 1 {
            super.keyDown(theEvent)
        }
        else {
            switch theEvent.keyCode {
            case 123: //left arrow
                endCurrentLine()
            case 125: //down arrow
                nextLine()
            case 126: //up arrow
                previousLine()
            default:
                super.keyDown(theEvent)
            }
        }
    }
    
    // Lyrics Making Methods
    func nextLine() {
        let msecPosition: Int = Int(player.currentTime * 1000)
        // Not allow two lyrics in the same time point
        if lrcLineArray.count > 0 && lrcLineArray.last!.msecPosition == msecPosition {
            ErrorWindowController.sharedErrorWindow.displayError(NSLocalizedString("DUPLICATE_IN_T_PT", comment: ""))
            NSBeep()
            return
        }
        // Current line is last line
        if currentLine == lyricsArray.count - 1 {
            endCurrentLine()
            return
        }
        NSLog("Add New Lrc Line")
        currentLine += 1
        let lrcLine = LyricsLineModel()
        lrcLine.lyricsSentence = lyricsArray[currentLine]
        lrcLine.setTimeTagWithMsecPosition(msecPosition)
        lrcLineArray.append(lrcLine)
        lyricsView.setHighlightedAtIndex(currentLine, andStyle: 1)
        
        scrollViewToFit()
    }
    
    func endCurrentLine() {
        if lrcLineArray.count == 0 || lrcLineArray.last!.lyricsSentence == "" {
            NSBeep()
            return
        }
        NSLog("End Current Lyrics")
        if currentLine == lyricsArray.count - 1 {
            lyricsXButton.enabled = true
            saveButton.enabled = true
        }
        let msecPosition: Int = Int(player.currentTime * 1000)
        let lrcLine: LyricsLineModel = LyricsLineModel()
        lrcLine.lyricsSentence = ""
        lrcLine.setTimeTagWithMsecPosition(msecPosition)
        lrcLineArray.append(lrcLine)
        lyricsView.setHighlightedAtIndex(currentLine, andStyle: 2)
    }
    
    func previousLine() {
        if lrcLineArray.count == 0 {
            NSBeep()
            return
        }
        var timePoint: Int = (lrcLineArray.last?.msecPosition)! - 2000
        if lrcLineArray.last?.lyricsSentence != "" {
            currentLine -= 1
        }
        
        lrcLineArray.removeLast()
        lyricsXButton.enabled = false
        saveButton.enabled = false
        isSaved = false
        
        if timePoint < 0 {
            timePoint = 0
        }
        if lrcLineArray.count > 0 {
            let tp: Int = lrcLineArray.last!.msecPosition!
            if tp > timePoint {
                timePoint = tp
            }
            if lrcLineArray.last!.lyricsSentence == "" {
                lyricsView.setHighlightedAtIndex(currentLine, andStyle: 2)
            }
            else {
                lyricsView.setHighlightedAtIndex(currentLine, andStyle: 1)
            }
        }
        else {
            lyricsView.unsetHighlighted()
        }
        player.currentTime = Double(timePoint/1000)
        player.play()
        
        scrollViewToFit()
    }
    
    func scrollViewToFit() {
        let viewOrigin: NSPoint = lyricsView.frame.origin
        if currentLine < 4 {
            scrollView.contentView.scrollToPoint(viewOrigin)
        }
        else if lyricsArray.count-currentLine < 5 {
            scrollView.contentView.scrollToPoint(NSMakePoint(viewOrigin.x, viewOrigin.y+CGFloat(lyricsArray.count-7)*lyricsView.height))
        }
        else {
            scrollView.contentView.scrollToPoint(NSMakePoint(viewOrigin.x, viewOrigin.y+CGFloat(currentLine-3)*lyricsView.height))
        }
    }
    
    //MARK: - Notifications
    
    func iTunesPlayerInfoChanged(n: NSNotification) {
        let userInfo = n.userInfo
        if needsLoadingSong {
            needsLoadingSong = false
            let currentTitle = userInfo!["Name"]
            let currentArtist = userInfo!["Artist"]
            let currentAlbum = userInfo!["Album"]
            let fileLocation = userInfo!["Location"]
            if currentTitle != nil {
                songTitle.stringValue = currentTitle as! String
            }
            if currentArtist != nil {
                artist.stringValue = currentArtist as! String
            }
            if currentAlbum != nil {
                album.stringValue = currentAlbum as! String
            }
            if fileLocation != nil {
                path.URL = NSURL(string: fileLocation as! String)
                do {
                    self.player = try AVAudioPlayer(contentsOfURL: path.URL!)
                } catch let theError as NSError {
                    NSLog("%@", theError.localizedDescription)
                    ErrorWindowController.sharedErrorWindow.displayError(NSLocalizedString("FAILED_INIT_PLAYER", comment: ""))
                    let musicPath = NSSearchPathForDirectoriesInDomains(.MusicDirectory, [.UserDomainMask], true).first!
                    self.path.URL = NSURL(string: musicPath)
                    return
                }
                NSLog("Song changed")
                self.setValue(Int(self.player.duration * 1000), forKey: "duration")
                self.setValue(0, forKey: "currentPosition")
                self.player.prepareToPlay()
                self.updateTimeTag()
                if NSUserDefaults.standardUserDefaults().boolForKey("LMPlayWhenAdded") {
                    self.play()
                }
            }
            else {
                let musicPath = NSSearchPathForDirectoriesInDomains(.MusicDirectory, [.UserDomainMask], true).first!
                path.URL = NSURL(string: musicPath)
                ErrorWindowController.sharedErrorWindow.displayError(NSLocalizedString("LOCAL_MUSIC_ONLY", comment: ""))
            }
        }
    }
    
}
