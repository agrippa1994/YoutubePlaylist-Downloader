//
//  Playlist.swift
//  Music Player
//
//  Created by Sem on 7/9/15.
//  Copyright (c) 2015 Sem. All rights reserved.
//

import UIKit
import CoreData
import AVFoundation
import AVKit

class Playlist: UITableViewController, UISearchResultsUpdating, PlaylistDelegate {
    
    
    @IBOutlet var selectButton: UIBarButtonItem!
    @IBOutlet var shuffleButton: UIBarButtonItem!
    @IBOutlet var deleteButton: UIBarButtonItem!
    
    var appDel : AppDelegate!
    var context : NSManagedObjectContext!
    var songSortDescriptor = NSSortDescriptor(key: "title", ascending: true)
    
    var songs : NSArray!
    var documentsDir = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! String
    var identifiers : [String] = []
    
    //search control
    var filteredSongs : NSArray!
    var resultSearchController = UISearchController(searchResultsController: nil)
    var x : [Int] = [] //for shuffling
    var playerQueue = AVQueuePlayer()
    var curNdx = 0
    var videoTracks : [AVPlayerItemTrack]!
    
    var isConnected = false
    //sort + reload data
    override func viewWillAppear(animated: Bool) {
        
        isConnected = IJReachability.isConnectedToNetwork()
        
        
        //reset tableView
        setEditing(false, animated: true)
        navigationController?.setNavigationBarHidden(false, animated: true)
        definesPresentationContext = false
        resultSearchController.active = false
        definesPresentationContext = true
    }
    func reloadPlaylist(notification: NSNotification){
        refreshPlaylist()
        resetX()
        shuffleButton.tintColor = UIColor.grayColor()
    }
    
    func refreshPlaylist(){
        var request = NSFetchRequest(entityName: "Songs")
        request.sortDescriptors = [songSortDescriptor]
        
        if !isConnected {//removes nonDownloaded songs from list if no connection detected
            request.predicate = NSPredicate(format: "isDownloaded = %@", true)
        }
        songs = context.executeFetchRequest(request, error: nil)
        identifiers = []
        
        for song in songs{
            var identifier = song.valueForKey("identifier") as! String
            identifiers += [identifier]
        }
        
        tableView.reloadData()
        
    }
    
    func resetX(){
        x = []
        if songs.count > 0 {
            for var index = 0; index < songs.count; ++index {
                x += [index]
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = 44
        
        appDel = UIApplication.sharedApplication().delegate as! AppDelegate
        context = appDel!.managedObjectContext
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "enteredBackground:", name: "enteredBackgroundID", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "enteredForeground:", name: "enteredForegroundID", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reloadPlaylist:", name: "reloadPlaylistID", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerItemDidReachEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: playerQueue.currentItem)
        
        //set audio to play in bg
        var audio : AVAudioSession = AVAudioSession()
        audio.setCategory(AVAudioSessionCategoryPlayback , error: nil)
        audio.setActive(true, error: nil)
        
        tableView.backgroundColor = UIColor.clearColor()
        var imgView = UIImageView(image: UIImage(named: "pastel.jpg"))
        imgView.frame = tableView.frame
        tableView.backgroundView = imgView
        
        navigationItem.leftBarButtonItem = editButtonItem()
        editButtonItem().title = "Select"
        deleteButton.setTitleTextAttributes([NSForegroundColorAttributeName : UIColor.grayColor()], forState: UIControlState.Disabled)
        
        shuffleButton.setTitleTextAttributes([NSForegroundColorAttributeName : UIColor.grayColor()], forState: UIControlState.Disabled)
        shuffleButton.tintColor = UIColor.grayColor()
        
        isConnected = IJReachability.isConnectedToNetwork()
        refreshPlaylist()
        resetX()
        
        setEditing(false, animated: true)
        navigationController?.setNavigationBarHidden(false, animated: true)
        
        
        
        resultSearchController.searchResultsUpdater = self
        resultSearchController.dimsBackgroundDuringPresentation = false
        resultSearchController.hidesNavigationBarDuringPresentation = false
        resultSearchController.searchBar.sizeToFit()
        definesPresentationContext = true
        tableView.tableHeaderView = resultSearchController.searchBar
        
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if resultSearchController.active && resultSearchController.searchBar.text != ""{
            return filteredSongs.count
        }
        else{
            return songs.count
        }
    }
    
    //called when select pressed
    override func setEditing(editing: Bool, animated: Bool) {
        
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: true)
        
        if editing {
            shuffleButton.enabled = false
            deleteButton.enabled = false
            selectButton.title = "Select All"
            editButtonItem().title = "Cancel"
            navigationController?.toolbarHidden = false
            navigationController?.hidesBarsOnSwipe = true
        }
            
        else {
            editButtonItem().title = "Select"
            shuffleButton.enabled = true
            navigationController?.hidesBarsOnSwipe = false
            navigationController?.toolbarHidden = true
        }
    }
    
    //set up editing mode
    @IBAction func selectPressed() {
        
        if selectButton.title == "Select All"{
            for var row = 0; row < tableView.numberOfRowsInSection(0); ++row {
                var indexPath = NSIndexPath(forRow: row, inSection: 0)
                tableView.selectRowAtIndexPath(indexPath, animated: true, scrollPosition: UITableViewScrollPosition.None)
            }
            selectButton.title = "Select None"
            deleteButton.enabled = true
        }
            
        else{
            for var row = 0; row < tableView.numberOfRowsInSection(0); ++row {
                var indexPath = NSIndexPath(forRow: row, inSection: 0)
                tableView.deselectRowAtIndexPath(indexPath, animated: true)
            }
            selectButton.title = "Select All"
            deleteButton.enabled = false
        }
        
    }
    
    //two functions to detect when no items selected and when at least one item selected
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if tableView.editing{
            deleteButton.enabled = true
        }
    }
    
    override func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        
        var selectedRows = tableView.indexPathsForSelectedRows()
        if selectedRows == nil {
            deleteButton.enabled = false
        }
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SongCell", forIndexPath: indexPath) as! SongCell
        
        var songname : String!
        
        if resultSearchController.active && resultSearchController.searchBar.text != "" {
            songname = filteredSongs[indexPath.row].valueForKey("title") as? String
        }
            
        else{
            var row = x[indexPath.row]
            songname = songs[row].valueForKey("title") as? String
        }
        
        
        cell.songLabel?.text = "\(indexPath.row + 1).  \(songname)"
        cell.contentView.backgroundColor = UIColor.clearColor()
        cell.backgroundColor = UIColor.clearColor()
        return cell
    }
    
    
    
    func findNdxInFullList(ndxInSearchList : Int) -> Int{
        var identifier = filteredSongs[ndxInSearchList].valueForKey("identifier") as! String
        var ndxIdentifiers = find(identifiers, identifier)!
        var ndxInFullList = find(x,ndxIdentifiers)!
        return ndxInFullList
    }
    
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        
        //in editing mode
        if !shuffleButton.enabled {
            setEditing(false, animated: true)
        }
        
        var request = NSFetchRequest(entityName: "Songs")
        request.sortDescriptors = [songSortDescriptor]
        request.predicate = NSPredicate(format: "title CONTAINS[c] %@", searchController.searchBar.text!)
        filteredSongs = context.executeFetchRequest(request, error: nil)
        tableView.reloadData()
        
        
    }
    
    
    
    
    ////////////////
    //////////////////
    //////////////////
    ////
    //shuffle functions
    
    
    @IBAction func shufflePlaylist() {
        
        if shuffleButton.tintColor != nil{
            shuffle(&x)
            shuffleButton.tintColor = nil
        }
        else{
            resetX()
            shuffleButton.tintColor = UIColor.grayColor()
        }
        tableView.reloadData()
    }
    
    func shuffle<C: MutableCollectionType where C.Index == Int>(inout list: C) {
        if songs.count > 0 {
            let c = count(list)
            for i in 0..<(c - 1) {
                let j = Int(arc4random_uniform(UInt32(c - i))) + i
                swap(&list[i], &list[j])
            }
        }
    }
    
    
    
    
    ////////////////
    //////////////////
    //////////////////
    ////
    //delete functions
    
    
    
    @IBAction func deletePressed() {//delete selected songs
        
        if var selectedIndexPaths = tableView.indexPathsForSelectedRows() as? [NSIndexPath] {
            var selectedRows : [Int] = []
            
            //if search active, find indexes of selected rows in the full shuffled playlist
            if resultSearchController.active && resultSearchController.searchBar.text != "" {
                
                for indexPath : NSIndexPath in selectedIndexPaths {
                    
                    var selectedRow = indexPath.row
                    var id = filteredSongs[selectedRow].valueForKey("identifier") as! String
                    var ndxIdentifiers = find(identifiers, id)!
                    selectedRow = find(x,ndxIdentifiers)!
                    
                    
                    selectedRows += [selectedRow]
                    var identifier = songs[ndxIdentifiers].valueForKey("identifier") as! String
                    
                    deleteSong(identifier)
                }
                
                
            }
                
            else{
                for indexPath : NSIndexPath in selectedIndexPaths {
                    selectedRows += [indexPath.row]
                    var row = x[indexPath.row]
                    var identifier = songs[row].valueForKey("identifier") as! String
                    
                    deleteSong(identifier)
                }
            }
            
            //horribly unreadable, but keeps shuffled songs in order after deletion
            var temp = x
            var selectedSongs : [Int] = []
            
            for num in selectedRows {
                selectedSongs += [x[num]]
            }
            
            for var index = 0; index < x.count; ++index {
                if var found = find(selectedSongs, x[index]) {
                    x.removeAtIndex(index)
                    index--
                }
            }
            
            var temp2 = x
            for num in temp {
                if find(x, num) == nil {
                    for var index = 0; index < x.count; ++index {
                        if x[index] > num {
                            temp2[index]--
                        }
                    }
                }
            }
            x = temp2
            
            refreshPlaylist()
        }
        
        setEditing(false, animated: true)
        navigationController?.setNavigationBarHidden(false, animated: true)
        updateSearchResultsForSearchController(resultSearchController)
    }
    
    override func tableView(tableView: UITableView, willBeginEditingRowAtIndexPath indexPath: NSIndexPath) {
        editButtonItem().enabled = false
        shuffleButton.enabled = false
    }
    
    override func tableView(tableView: UITableView, didEndEditingRowAtIndexPath indexPath: NSIndexPath) {
        editButtonItem().enabled = true
        shuffleButton.enabled = true
    }
    
    //swipe to delete
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == UITableViewCellEditingStyle.Delete {
            
            var row : Int!
            
            if resultSearchController.active && resultSearchController.searchBar.text != ""{
                var selectedRow = indexPath.row
                row = x[findNdxInFullList(selectedRow)]
                x.removeAtIndex(row)
            }
                
            else{
                row = x[indexPath.row]
                x.removeAtIndex(indexPath.row)
            }
            
            var identifier = songs[row].valueForKey("identifier") as! String
            deleteSong(identifier)
            
            
            for var index = 0; index < x.count; ++index {
                if x[index] > row {
                    x[index]--
                }
            }
            
            refreshPlaylist()
            editButtonItem().enabled = true
            updateSearchResultsForSearchController(resultSearchController)
            
        }
    }
    
    func deleteSong(identifier : String){
        var songRequest = NSFetchRequest(entityName: "Songs")
        songRequest.predicate = NSPredicate(format: "identifier = %@", identifier)
        var fetchedSongs : NSArray = context.executeFetchRequest(songRequest, error: nil)!
        var selectedSong = fetchedSongs[0] as! NSManagedObject
        
        
        var dict = ["identifier" : identifier]
        NSNotificationCenter.defaultCenter().postNotificationName("resetDownloadTasksID", object: nil, userInfo: dict as [NSObject : AnyObject])
        
        var fileManager = NSFileManager.defaultManager()
        
        //remove item in both documents directory and persistentData
        var isDownloaded = selectedSong.valueForKey("isDownloaded") as! Bool
        
        
        if isDownloaded {
            var file = selectedSong.valueForKey("identifier") as! String
            file = file.stringByAppendingString(".mp4")
            var filePath = documentsDir.stringByAppendingPathComponent(file)
            fileManager.removeItemAtPath(filePath, error: nil)
        }
        context.deleteObject(selectedSong)
        
        
        context.save(nil)
    }
    
    
    
    
    ////////////////
    //////////////////
    //////////////////
    ////
    //avplayer related functions
    
    
    
    //don't segue to AVPlayer if editing
    override func shouldPerformSegueWithIdentifier(identifier: String?, sender: AnyObject?) -> Bool {
        if !tableView.editing {
            return true
        }
        
        return false
    }
    
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showPlayer"{
            playerQueue.removeAllItems()
            
            
            if resultSearchController.active && resultSearchController.searchBar.text != ""{
                var selectedRow = (tableView.indexPathForSelectedRow()?.row)!
                var identifier = filteredSongs[selectedRow].valueForKey("identifier") as! String
                var ndxIdentifiers = find(identifiers, identifier)!
                curNdx = find(x,ndxIdentifiers)!
                
                resultSearchController.active = false
                var path = NSIndexPath(forRow: curNdx, inSection: 0)
                tableView.selectRowAtIndexPath(path, animated: true, scrollPosition: UITableViewScrollPosition.Middle)
                
                
            }
                
                
            else{
                
                curNdx = (tableView.indexPathForSelectedRow()?.row)!
            }
            addSongToQueue(curNdx)
            
            
            
            
            //if download finished, initialize avplayer\
            let player : Player = segue.destinationViewController as! Player
            player.playlistDelegate = self
            player.player = playerQueue
        }
        
        
    }
    
    func addSongToQueue(index : Int) {
        if let curItem = playerQueue.currentItem{
            curItem.seekToTime(kCMTimeZero)
            playerQueue.advanceToNextItem()
        }
        
        var ndx = x[index]
        var isDownloaded = songs[ndx].valueForKey("isDownloaded") as! Bool
        var identifier = songs[ndx].valueForKey("identifier") as! String
        
        if isDownloaded {
            
            var file = identifier.stringByAppendingString(".mp4")
            var filePath = documentsDir.stringByAppendingPathComponent(file)
            let url = NSURL(fileURLWithPath: filePath)
            
            var playerItem = AVPlayerItem(URL: url)
            playerQueue.insertItem(playerItem, afterItem: nil)
        }
            
        else{
            
            var songRequest = NSFetchRequest(entityName: "Songs")
            songRequest.predicate = NSPredicate(format: "identifier = %@", identifier)
            var fetchedSongs : NSArray = context.executeFetchRequest(songRequest, error: nil)!
            var selectedSong = fetchedSongs[0] as! NSManagedObject
            
            var currentDate = NSDate()
            var expireDate = songs[ndx].valueForKey("expireDate") as! NSDate
            
            if currentDate.compare(expireDate) == NSComparisonResult.OrderedDescending { //update streamURL
                
                XCDYouTubeClient.defaultClient().getVideoWithIdentifier(identifier, completionHandler: {(video, error) -> Void in
                    if error == nil {
                        var streamURLs : NSDictionary = video.valueForKey("streamURLs") as! NSDictionary
                        var desiredURL = (streamURLs[22] != nil ? streamURLs[22] : (streamURLs[18] != nil ? streamURLs[18] : streamURLs[36])) as! NSURL
                        
                        selectedSong.setValue(video.expirationDate, forKey: "expireDate")
                        selectedSong.setValue("\(desiredURL)", forKey: "streamURL")
                        
                        self.context.save(nil)
                        
                        var url = NSURL(string: selectedSong.valueForKey("streamURL") as! String)!
                        println(url)
                        var playerItem = AVPlayerItem(URL: url)
                        self.playerQueue.insertItem(playerItem, afterItem: nil)
                    }
                })
            }
                
            else {
                var url = NSURL(string: selectedSong.valueForKey("streamURL") as! String)!
                var playerItem = AVPlayerItem(URL: url)
                playerQueue.insertItem(playerItem, afterItem: nil)
            }
        }
    }
    
    func advance(){
        if curNdx == songs.count - 1 { curNdx = 0 }
        else{ curNdx++ }
        
        enableVidTracks()
        addSongToQueue(curNdx)
    }
    
    func retreat(){
        if curNdx == 0 { curNdx = songs.count - 1 }
        else { curNdx-- }
        
        if (songs.count == 1) { advance() }
        else{
            enableVidTracks()
            addSongToQueue(curNdx)
        }
    }
    
    func playerItemDidReachEnd(notification : NSNotification){
        enableVidTracks()
        advance()
    }
    
    func enableVidTracks(){
        videoTracks = playerQueue.currentItem.tracks as! [AVPlayerItemTrack]
        for track : AVPlayerItemTrack in videoTracks{
            track.enabled = true; // enable the track
        }
    }
    
    func enteredForeground(notification: NSNotification){
        if playerQueue.currentItem != nil{
            enableVidTracks()
        }
    }
    
    //disable vidTracks
    func enteredBackground(notification: NSNotification){
        
        if playerQueue.currentItem != nil {
            videoTracks = playerQueue.currentItem.tracks as! [AVPlayerItemTrack]
            
            for track : AVPlayerItemTrack in videoTracks{
                
                if(!track.assetTrack.hasMediaCharacteristic("AVMediaCharacteristicAudible")){
                    track.enabled = false; // disable the track
                }
            }
        }
    }
}
