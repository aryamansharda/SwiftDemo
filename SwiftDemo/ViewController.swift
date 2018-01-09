//
//  ViewController.swift
//  SwiftDemo
//
//  Created by Aryaman Sharda on 1/8/18.
//  Copyright © 2018 Aryaman Sharda. All rights reserved.
//

import UIKit

class ViewController: UITableViewController {
    
    @IBOutlet weak var searchPhraseField: UITextField!
    
    var refreshCtrl: UIRefreshControl!
    
    //Stores information retrieved from iTunes
    var tableData:[AnyObject]!
    
    //Handles URL requests
    var task: URLSessionDownloadTask!
    var session: URLSession!
    
    //Stores retrieved images
    var cache:NSCache<AnyObject, AnyObject>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        session = URLSession.shared
        task = URLSessionDownloadTask()
        
        //Setup refresh control to trigger refreshTableView()
        self.refreshCtrl = UIRefreshControl()
        self.refreshCtrl.addTarget(self, action: #selector(ViewController.refreshTableView), for: .valueChanged)
        self.refreshControl = self.refreshCtrl
        
        //Initalize cache and table data
        self.tableData = []
        self.cache = NSCache()
        
        //Using "books" as a placeholder query for now
        refreshTableView(query:"books")
    }
    
    @IBAction func searchItunesForQuery(sender: UIButton) {
        
        //Remove existing items from the table data array and clearing the cache
        self.tableData.removeAll()
        self.cache.removeAllObjects()
        
        //Executing new query
        refreshTableView(query:(self.searchPhraseField.text?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed))!)
        
        //Dismissing the keyboard
        self.searchPhraseField.resignFirstResponder()
    }
    
    @objc func refreshTableView(query: String){
        
        //Populate iTunes with search query
        let url:URL! = URL(string: "https://itunes.apple.com/search?entity=software&term=" + query)
        
        task = session.downloadTask(with: url, completionHandler: { (location: URL?, response: URLResponse?, error: Error?) -> Void in
            if location != nil{
                let data:Data! = try? Data(contentsOf: location!)
                do {
                    let dic = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as AnyObject
                    
                    //Unpack the results and assign it to the tableData - the table view data source
                    self.tableData = dic.value(forKey : "results") as? [AnyObject]
                    DispatchQueue.main.async(execute: { () -> Void in
                        //Performing UI changes on main 
                        self.tableView.reloadData()
                        self.refreshControl?.endRefreshing()
                    })
                } catch{
                    print("something went wrong, try again")
                }
            }
        })
        task.resume()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        self.cache.removeAllObjects()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.tableData.count
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AppCell", for: indexPath)
        let dictionary = self.tableData[(indexPath as NSIndexPath).row] as! [String:AnyObject]
        
        //Configure cell w/ placeholder image until async request returns
        cell.textLabel!.text = dictionary["trackName"] as? String
        cell.imageView?.image = UIImage(named: "placeholder")
        
        if (self.cache.object(forKey: (indexPath as NSIndexPath).row as AnyObject) != nil){
            //Cached image used, no need to download it
            cell.imageView?.image = self.cache.object(forKey: (indexPath as NSIndexPath).row as AnyObject) as? UIImage
        } else {
            //Async load image
            let artworkUrl = dictionary["artworkUrl100"] as! String
            let url:URL! = URL(string: artworkUrl)
            task = session.downloadTask(with: url, completionHandler: { (location, response, error) -> Void in
                if let data = try? Data(contentsOf: url){
            
                    //Only perform UI updates on the main thread
                    DispatchQueue.main.async(execute: { () -> Void in
                        if let updateCell = tableView.cellForRow(at: indexPath) {
                            let img:UIImage! = UIImage(data: data)
                            updateCell.imageView?.image = img
                            
                            //Save retrieved image in cache
                            self.cache.setObject(img, forKey: (indexPath as NSIndexPath).row as AnyObject)
                        }
                    })
                }
            })
            task.resume()
        }
        return cell
    }
}
