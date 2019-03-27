//
//  PlayerViewController.swift
//
//
//  Created by alchemist on 5/9/2018.
//
//  NOTES:
//  USED WCSESSION TO ENABLE COMMUNICATION WITH APPLE WATCH
//  USED AUDIOSESSION AND 'BACKGROUND MODE' IN PROJECT SETTINGS TO ENABLE PLAYING AUDIO IN BACKGROUND
//  USED AVPLAYER TO PLAY AUDIO
//  USED ImgCache to store a temporary copy of cover of the song, titleCache and artistCache to store details of songs. Playlist stores the url of the online audio file.
//  USED DELEGATE PATTERN TO DO ACTION IN MAIN THREAD WHEN RECEIVING SIGNAL FROM OTHER FUNCTION( doubanModelProtocol to retrieve json file and watchsessionprotocol to receive predicted gesture result)
//  USED DispatchQueue.main.async FUNCTION TO UPDATE ALL THE STORYBOARD'S ELEMENTS( UILABEL & UIBUTTON'S IMAGE & PROGRESS BAR...)

import UIKit
import AVFoundation
import QuartzCore
import AVKit
import CoreMotion
import CoreML
import WatchConnectivity

class PlayerViewController: UIViewController,doubanModelProtocol, WCSessionDelegate {
    
    /** Called when all delegate callbacks for the previously selected watch has occurred. The session can be re-activated for the now selected watch using activateSession. */
    @available(iOS 9.3, *)
    public func sessionDidDeactivate(_ session: WCSession) {
        //..
    }
    
    
    /** Called when the session can no longer be used to modify or add any new transfers and, all interactive messages will be cancelled, but delegate callbacks for background transfers can still occur. This will happen when the selected watch is being changed. */
    @available(iOS 9.3, *)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        //..
    }
    
    
    /** Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
    @available(iOS 9.3, *)
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        //..
    }
    @IBOutlet weak var cover: UIImageView!
    //@IBOutlet weak var predict_result_label: UILabel!
    @IBOutlet weak var songTitle: UILabel!
    @IBOutlet weak var songArtist: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var prevButton: UIButton!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var playerSlider: UISlider!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var seekLoadingLabel: UILabel!

    // 用一个字典保存对应的地址和图片到本地
    var imgCache = Dictionary<String,UIImage>()
    var titleCache = Dictionary<String,String>()
    var artistCache = Dictionary<String,String>()
    
    var songsList : NSArray = NSArray()    //歌曲列表
    var channelsList : NSArray = NSArray() //频道列表
    
    var imgList: NSMutableArray = NSMutableArray()
    var playList: NSMutableArray = NSMutableArray()
    var timer: Timer?
    var index: Int = Int()
    var avPlayer: AVPlayer!
    var isPaused: Bool!
    var doubanModel : DoubanModel = DoubanModel()
    var firstSearchCompleted = false
    
    var session: WCSession!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isPaused = false
        index = 0
        
        if WCSession.isSupported() {
            session = WCSession.default
            session.delegate = self
            session.activate()
        }
        
        
        playButton.setImage(UIImage(named:"pause"), for: .normal)
        
        doubanModel.delegate = self
        //doubanModel.searchWithUrl("https://api.douban.com/v2/fm/app_channels")
        doubanModel.searchWithUrl("https://api.douban.com/v2/fm/playlist?alt=json&apikey=02646d3fb69a52ff072d47bf23cef8fd&app_name=radio_iphone&channel=10&client=s%3Amobile%7Cy%3AiOS%2010.2%7Cf%3A115%7Cd%3Ab88146214e19b8a8244c9bc0e2789da68955234d%7Ce%3AiPhone7%2C1%7Cm%3Aappstore&douban_udid=b635779c65b816b13b330b68921c0f8edc049590&formats=aac&kbps=128&pt=0.0&type=n&udid=b88146214e19b8a8244c9bc0e2789da68955234d&version=115")
        
    }
    
    
    
    
    //Delegate for DoubanModelProtocol
    func didRecieveResults(_ results: NSDictionary) {
        if (results["song"] != nil) {
            //print(results)
            self.songsList = results["song"] as! NSArray
            //Load music information to table
            //DispatchQueue.main.async {
            //self.tableView.reloadData()
            //}
            
            //默认播放第一条数据音乐
            let musicDict : NSDictionary = self.songsList[0] as! NSDictionary
            let title : String = musicDict["title"] as! String
            let artist : String = musicDict["artist"] as! String
            let imgUrl : String  = musicDict["picture"] as! String
            let audioUrl : String = musicDict["url"] as! String
            //save title to cache
            self.titleCache[audioUrl] = title
            self.artistCache[audioUrl] = artist
            print(audioUrl)
            onSetImage(imgUrl)
            //onSetAudio(audioUrl)
            
            //play with avplayer
//            if(isPaused==true){
//
//            }
            //USE AUDIOSESSION TO ENABLE BACKGROUND AUDIO MODE
            var audioSession = AVAudioSession.sharedInstance()
            do{
                try audioSession.setCategory(AVAudioSessionCategoryPlayback)
            }
            catch{
                print(error)
            }
            self.playList.add(audioUrl)
            self.imgList.add(imgUrl)
            //update the timer asynchronously
            //without this, slider doesn't work properly
            DispatchQueue.main.async {
                self.index = self.index + 1
                if(self.firstSearchCompleted == false){
                    self.index = self.index - 1
                }
                print(self.index)
                self.songTitle.text = title
                self.songArtist.text = artist
                self.play(videoURL: URL(string:(self.playList[self.index] as! String))!)
                self.setupTimer()
                self.firstSearchCompleted = true
            }
            
            
            //}else if(results["channels"] != nil){
            //Show channels
            //self.channelsList = results["channels"] as! NSArray
            
            //}
        }else{
            print("SONG == NIL")
        }
    }
    
    func onSetImage(_ url:String){
        let image = self.imgCache[url] as UIImage?
        if (image == nil){
            let session = URLSession.shared
            let imgURL : URL = URL(string: url)!
            let req : URLRequest = URLRequest(url: imgURL)
            session.dataTask(with: req, completionHandler: {
                (data:Data!, response:URLResponse!, error:Error!)->Void in
                let image = UIImage(data: data)
                DispatchQueue.main.async {
                    self.cover.image = image
                }
                self.imgCache[url] = image
                } as! (Data?, URLResponse?, Error?) -> Void).resume()
        }else{
            DispatchQueue.main.async {
                self.cover.image = image
            }
        }
        
        
    }
    
    func play(videoURL:URL) {
        let protectionSpace = URLProtectionSpace.init(host: "http://mr3.doubanio.com/",
                                                      port: 80,
                                                      protocol: "http",
                                                      realm: nil,
                                                      authenticationMethod: nil)
        let userCredential = URLCredential(user: "user",
                                           password: "password",
                                           persistence: .permanent)
        
        URLCredentialStorage.shared.setDefaultCredential(userCredential, for: protectionSpace)
        self.avPlayer?.volume = 1.0
        let asset = AVAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
        self.avPlayer = AVPlayer(playerItem: item)
        if #available(iOS 10.0, *) {
            self.avPlayer.automaticallyWaitsToMinimizeStalling = false
        }
        avPlayer!.volume = 1.0
        avPlayer.play()
    }
    
    
    override func viewWillDisappear( _ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        self.avPlayer = nil
        self.timer?.invalidate()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func playButtonClicked(_ sender: UIButton) {
        if #available(iOS 10.0, *) {
            self.togglePlayPause()
        } else {
            // showAlert "upgrade ios version to use this feature"
           
        }
    }
    
    @available(iOS 10.0, *)
    func togglePlayPause() {
        if avPlayer.timeControlStatus == .playing  {
            playButton.setImage(UIImage(named:"play"), for: .normal)
            avPlayer.pause()
            isPaused = true
        } else {
            playButton.setImage(UIImage(named:"pause"), for: .normal)
            avPlayer.play()
            isPaused = false
        }
    }
    
    @IBAction func nextButtonClicked(_ sender: Any) {
        self.nextTrack()
    }
    
    @IBAction func prevButtonClicked(_ sender: Any) {
        self.prevTrack()
    }
    
    @IBAction func sliderValueChange(_ sender: UISlider) {
        let seconds : Int64 = Int64(sender.value)
        let targetTime:CMTime = CMTimeMake(seconds, 1)
        avPlayer!.seek(to: targetTime)
        if(isPaused == false){
            seekLoadingLabel.alpha = 1
        }
    }
    
    @IBAction func sliderTapped(_ sender: UILongPressGestureRecognizer) {
        if let slider = sender.view as? UISlider {
            if slider.isHighlighted { return }
            let point = sender.location(in: slider)
            let percentage = Float(point.x / slider.bounds.width)
            let delta = percentage * (slider.maximumValue - slider.minimumValue)
            let value = slider.minimumValue + delta
            slider.setValue(value, animated: false)
            let seconds : Int64 = Int64(value)
            let targetTime:CMTime = CMTimeMake(seconds, 1)
            avPlayer!.seek(to: targetTime)
            if(isPaused == false){
                seekLoadingLabel.alpha = 1
            }
        }
    }
    
    func setupTimer(){
        NotificationCenter.default.addObserver(self, selector: #selector(self.didPlayToEnd), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        timer = Timer(timeInterval: 0.001, target: self, selector: #selector(PlayerViewController.tick), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: RunLoopMode.commonModes)
    }
    
    @objc func didPlayToEnd() {
        self.nextTrack()
    }
    
    @objc func tick(){
        if(avPlayer.currentTime().seconds == 0.0){
            loadingLabel.alpha = 1
        }else{
            loadingLabel.alpha = 0
        }
        
        if(isPaused == false){
            if(avPlayer.rate == 0){
                avPlayer.play()
                seekLoadingLabel.alpha = 1
            }else{
                seekLoadingLabel.alpha = 0
            }
        }
        
        if((avPlayer.currentItem?.asset.duration) != nil){
            let currentTime1 : CMTime = (avPlayer.currentItem?.asset.duration)!
            let seconds1 : Float64 = CMTimeGetSeconds(currentTime1)
            let time1 : Float = Float(seconds1)
            playerSlider.minimumValue = 0
            playerSlider.maximumValue = time1
            let currentTime : CMTime = (self.avPlayer?.currentTime())!
            let seconds : Float64 = CMTimeGetSeconds(currentTime)
            let time : Float = Float(seconds)
            self.playerSlider.value = time
            timeLabel.text =  self.formatTimeFromSeconds(totalSeconds: Int32(Float(Float64(CMTimeGetSeconds((self.avPlayer?.currentItem?.asset.duration)!)))))
            currentTimeLabel.text = self.formatTimeFromSeconds(totalSeconds: Int32(Float(Float64(CMTimeGetSeconds((self.avPlayer?.currentItem?.currentTime())!)))))
            
        }else{
            playerSlider.value = 0
            playerSlider.minimumValue = 0
            playerSlider.maximumValue = 0
            timeLabel.text = "Live stream \(self.formatTimeFromSeconds(totalSeconds: Int32(CMTimeGetSeconds((avPlayer.currentItem?.currentTime())!))))"
        }
    }
    
    
    func nextTrack(){
        if(index < playList.count-1){
            index = index + 1
            isPaused = false
            DispatchQueue.main.async {
                self.playButton.setImage(UIImage(named:"pause"), for: .normal)
            }
            onSetImage(imgList[self.index] as! String)
            self.play(videoURL: URL(string:(playList[self.index] as! String))!)
            DispatchQueue.main.async {
                self.songTitle.text = self.titleCache[self.playList[self.index] as! String]
                self.songArtist.text = self.artistCache[self.playList[self.index] as! String]
            }
            
        }else{
            //last song of list,  then request douban and get a new song
            //index = index + 1
            isPaused = true
            self.avPlayer.pause()
            DispatchQueue.main.async {
                self.playButton.setImage(UIImage(named:"pause"), for: .normal)
            }
//            let group = DispatchGroup()
//            group.enter()
            
            // avoid deadlocks by not using .main queue here
//            DispatchQueue.global().async {
            self.doubanModel.searchWithUrl("https://api.douban.com/v2/fm/playlist?alt=json&apikey=02646d3fb69a52ff072d47bf23cef8fd&app_name=radio_iphone&channel=10&client=s%3Amobile%7Cy%3AiOS%2010.2%7Cf%3A115%7Cd%3Ab88146214e19b8a8244c9bc0e2789da68955234d%7Ce%3AiPhone7%2C1%7Cm%3Aappstore&douban_udid=b635779c65b816b13b330b68921c0f8edc049590&formats=aac&kbps=128&pt=0.0&type=n&udid=b88146214e19b8a8244c9bc0e2789da68955234d&version=115")
//                group.leave()
//            }
//
//            // wait ...
//            group.wait()
            
            //self.play(videoURL: URL(string:(playList[self.index] as! String))!)
        }
    }
    
    func prevTrack(){
        if(index > 0){
            index = index - 1
            isPaused = false
            DispatchQueue.main.async {
                self.playButton.setImage(UIImage(named:"pause"), for: .normal)
            }
            self.play(videoURL: URL(string:(playList[self.index] as! String))!)
            onSetImage(imgList[self.index] as! String)
            //onSetTitle(playList[self.index] as! String)
            DispatchQueue.main.async {
                self.songTitle.text = self.titleCache[self.playList[self.index] as! String]
                self.songArtist.text = self.artistCache[self.playList[self.index] as! String]
            }
            
            
        }
    }
    
    func formatTimeFromSeconds(totalSeconds: Int32) -> String {
        let seconds: Int32 = totalSeconds%60
        let minutes: Int32 = (totalSeconds/60)%60
        let hours: Int32 = totalSeconds/3600
        return String(format: "%02d:%02d:%02d", hours,minutes,seconds)
    }
    
    @IBAction func backButtonClicked(_ sender: Any) {
        self.dismiss(animated: true) {
            self.avPlayer = nil
            self.timer?.invalidate()
        }
    }
    
}
extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}


//MARK: - WatchSessionProtocol -> ViewController
typealias WatchSessionProtocol = PlayerViewController
extension WatchSessionProtocol {
    
    // WCSession Delegate protocol
    // Main function to process the received message from apple watch's "sendMessage()" and set reply message which would be retrieved by apple watch's "sendMessage()"
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        
        // Reply handler, received message
        let value = message["Message"] as? String
        
        if(value == "right"){
            self.nextTrack()
        }else if(value == "left"){
            self.prevTrack()
        }
        else if(value == "circle"){
            self.togglePlayPause()
        }
        
        print(value)
        // GCD - Present on the screen
//        DispatchQueue.main.async { () -> Void in
//            self.predict_result_label.text = value!
//        }
        
        // Send a reply
        replyHandler(["Message":"Hey Watch! Nice to meet you!"])
    }
}

