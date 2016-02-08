//
//  ViewController.swift
//  forGreengrad
//
//  Created by Roman Spirichkin on 06/02/16.
//  Copyright © 2016 rs. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import CoreData

class RSSongsVC: UICollectionViewController {

    @IBOutlet var RSActivity: UIActivityIndicatorView!
    var refreshControl:UIRefreshControl!
    var songs : [Song] = []     // main (collecetionView)
    var tempSongs : [Song] = []     // temp (download)
    
    // MARK: viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView!.delegate = self
        self.collectionView!.dataSource = self
//        let tap: UITapGestureRecognizer = UI TapGestureRecognizer(target: self, action: "dismissKeyboard")
//        self.collectionView.addGestureRecognizer(tap)
        // pullToRefresh
        self.refreshControl = UIRefreshControl()
        self.refreshControl.attributedTitle = NSAttributedString(string: "Обновить")
        self.refreshControl.addTarget(self, action: "pullToRefresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.collectionView!.addSubview(refreshControl)
        // set activityIndicator
        self.view.addSubview(RSActivity)
        RSActivity.center = CGPoint(x: self.view.bounds.width/2, y: (self.view.bounds.height-60)/2)
        
        deleteCoreData()
        // read old data
        readCoreData()
        self.collectionView?.reloadData()
        // download new data    (&reload)
        songsDownload()
        // show data
    }
    func pullToRefresh(sender:AnyObject) { songsDownload() }
    
    // MARK: Download
    func songsDownload() {
        self.RSActivity.startAnimating()
        self.refreshControl.endRefreshing()
        // download new
        self.tempSongs.removeAll()
        Alamofire.request(.GET, "http://tomcat.kilograpp.com/songs/api/songs").responseJSON { response in
            if let dummyData = response.data {
                let dummyJSON = JSON(data: dummyData)
                for (_, subJSON) in dummyJSON {
                    let newSong = Song(label: subJSON["label"].stringValue, author: subJSON["author"].stringValue, id: subJSON["id"].intValue)
                    self.tempSongs.append(newSong)
                }
            } else { print("No-No-No ;(") }
            
            // "reload"
            if self.songs.count == 0 { // if no loaded data
                self.songs = self.tempSongs
                self.collectionView?.reloadData()
            } else { // reload view
                self.reloadSongArray()
            }
            
            self.RSActivity.stopAnimating() // stop spinin
            // save coreData
            dispatch_async(dispatch_get_main_queue()) {
                self.writeCoreData()
            }
        }
    }
    
    func reloadSongArray() {
        // compare temp and current songs
        var deleteNSIndex : [NSIndexPath] = []
        var insertNSIndex : [NSIndexPath] = []
        var removmentCount = -1 // for safe search
        var j = 0;
        for var i = 0; i < self.songs.count; i++ {
            if i == removmentCount + self.songs.count {
                break }
            if i < self.tempSongs.count-1 {
                if self.songs[i].id != self.tempSongs[j].id {
                    self.songs.removeAtIndex(i)
                    deleteNSIndex.append(NSIndexPath(forItem: i-1-removmentCount, inSection: 0))
                    removmentCount++
                }
            } else { // no more song in new data
                for var i2 = i+1; i2 < self.songs.count; i2++ {
                    self.songs.removeLast()
                    deleteNSIndex.append(NSIndexPath(forItem: i2, inSection: 0))
                    removmentCount++
                }
            }
            j++
        }
        // add all other songs
        for var i = self.songs.count; i < self.tempSongs.count; i++ {
            self.songs.append(self.tempSongs[i])
            insertNSIndex.append(NSIndexPath(forItem: i, inSection: 0))
        }
        dispatch_async(dispatch_get_main_queue()) {
            // reload
            var d1 : [Int] = []
            for d in deleteNSIndex {
                d1.append(d.row)
            }
            var i1 : [Int] = []
            for i in insertNSIndex {
                i1.append(i.row)
            }
            if deleteNSIndex.count > 0 {  // delete old songs
                self.collectionView?.deleteItemsAtIndexPaths(deleteNSIndex)
            }
            if insertNSIndex.count > 0 {  // insert new songs
                self.collectionView?.insertItemsAtIndexPaths(insertNSIndex)
            }
        }
        
    }
    
    
    // MARK: collectionView
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return songs.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("RSSongCell", forIndexPath: indexPath) as! RSSongCell
        cell.RSAuthorLabel.text = songs[indexPath.row].author
        cell.RSSongLabel.text = songs[indexPath.row].label
        cell.layer.cornerRadius = 3
        cell.layer.borderWidth = 1
        cell.clipsToBounds = true
        return cell
    }
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let length = min(self.view.bounds.width, self.view.bounds.height)
        return CGSizeMake(length/2 - 6, length/2 - 6) //inset between
    }
    
    
    
    // MARK: CoreData
    func readCoreData() {
        let managedContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName("Song", inManagedObjectContext: managedContext)
        do {
            let fetchedEntities = try managedContext.executeFetchRequest(request) as! [NSManagedObject]
            songs.removeAll()
            for fetchedEntity in fetchedEntities {
                songs.append(Song(label: fetchedEntity.valueForKey("label") as! String, author: fetchedEntity.valueForKey("author") as! String, id: fetchedEntity.valueForKey("id") as! Int))
            }
        } catch { print(error) }
    }
    func writeCoreData() {
        deleteCoreData()
        let managedContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
        let songEntity = NSEntityDescription.entityForName("Song", inManagedObjectContext: managedContext)
        for songsItem in tempSongs {
        let currentD = NSManagedObject(entity: songEntity!, insertIntoManagedObjectContext: managedContext)
            currentD.setValue( NSNumber.IntegerLiteralType(songsItem.id), forKey: "id")
            currentD.setValue(songsItem.author, forKey: "author")
            currentD.setValue(songsItem.label, forKey: "label")
        }
        do { try managedContext.save() }
        catch { print("Could not save \(error)") }
    }
    func deleteCoreData() {
        let managedContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName("Song", inManagedObjectContext: managedContext)
        do {
            let fetchedEntities = try managedContext.executeFetchRequest(request) as! [NSManagedObject]
            for entity in fetchedEntities { managedContext.deleteObject(entity) }
            try managedContext.save()
        } catch { print(error) }
    }
}

