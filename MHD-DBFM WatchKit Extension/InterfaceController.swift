//
//  InterfaceController.swift
//  MagicalHandGesture WatchKit Extension
//
//  Created by alchemist on 9/16/17.
//  Copyright © 2017 haojianyang. All rights reserved.
//

import WatchKit
import Foundation
import CoreMotion
import CoreML
import WatchConnectivity
import HealthKit
//import CSV   !has bugs--- would have strange format when output to a file

class InterfaceController: WKInterfaceController, WCSessionDelegate{
    
    @available(watchOS 2.2, *)
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        //..code
    }
    
    //created for communication with iphone
    @IBOutlet var resetButton:
        WKInterfaceLabel!
    @IBOutlet var messageLabel: WKInterfaceLabel!
    @IBOutlet var sendButton: WKInterfaceButton!
    @IBOutlet var sendFileButton: WKInterfaceButton!
    
    @IBOutlet var predict_result_label: WKInterfaceLabel!
    @IBOutlet var inMessageText: WKInterfaceLabel!
    @IBOutlet var statusLabel: WKInterfaceLabel!
    
    @IBOutlet var accX: WKInterfaceLabel!
    @IBOutlet var accY: WKInterfaceLabel!
    @IBOutlet var accZ: WKInterfaceLabel!
    @IBOutlet var maxAccX: WKInterfaceLabel!
    @IBOutlet var maxAccY: WKInterfaceLabel!
    @IBOutlet var maxAccZ: WKInterfaceLabel!
    
    @IBOutlet var rotX: WKInterfaceLabel!
    @IBOutlet var rotY: WKInterfaceLabel!
    @IBOutlet var rotZ: WKInterfaceLabel!
    @IBOutlet var maxRotX: WKInterfaceLabel!
    @IBOutlet var maxRotY: WKInterfaceLabel!
    @IBOutlet var maxRotZ: WKInterfaceLabel!
    
    
    var currentMaxAccelX: Double = 0.0
    var currentMaxAccelY: Double = 0.0
    var currentMaxAccelZ: Double = 0.0
    
    var currentMaxRotX: Double = 0.0
    var currentMaxRotY: Double = 0.0
    var currentMaxRotZ: Double = 0.0
    
    var motionManager = CMMotionManager()
    
    var counter = 0
    var predict_counter = 0
    var timer = Timer()
    var punch_timer = Timer()
    var handler_timer = Timer()
    var predict_timer = Timer()
    @objc var predict_finished = 0
    let queue = OperationQueue()
    let manager = FileManager.default
    var session : WCSession!
    var seconds = 2
    let dimensionOfData = 180 / 6 //indicate how many elements in a line in csv file
    
    var observable_flag : Int = 0 {//indicate if a punch & ges are both predicted
        willSet {
            //newValue
            if(observable_flag == 1){
                // should correctly update this flag in the main thread, cause assignment here would be override by the assginment in main thread
            }
        }
        didSet {
            //oldValue
            //if a prediction is finished, reactivate the punch_detection and repeat this process so that to keep recognizing hand gestures
            if(observable_flag == 1){
                //wait for previous process to be completed
                sleep(1)
                punch_detection_activate()
            }
        }
    }
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    fileprivate var hapticFeedbackTimer: Timer?
    
    var gesToRecognize = [Double]()
    
    override init() {
        super.init()
        //Now it's safe to access interface objects
        //self.accX.setText("Hello watch,I am Haojian. ")
        //queue.maxConcurrentOperationCount = 2
        queue.name = "MotionManagerQueue"
        //UIApplication.shared.isIdleTimerDisabled = true

        self.reset()
        let fileName = "ges.csv"
        let filePath:String = NSHomeDirectory() + "/Documents/" + fileName
        createFile(name:fileName)
        //        //Now it's safe to access interface objects
        //        let menloFont = UIFont(name: "Menlo", size: 12.0)!
        //        var fontAttrs = [NSFontAttributeName : menloFont]
        //        var attrString = NSAttributedString(string: "Hello watch.my name is Haojian Yang.", attributes: fontAttrs)
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
//        let urlForDocument = manager.urls( for: .documentDirectory,
//                                           in:.userDomainMask)
//        // Documents directory
//        let url = urlForDocument[0]
//        // create file
//        //createFile(name:"hello.csv", fileBaseUrl: url)
//        // get file url
//        let fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
//            .appendingPathComponent("hello.csv")
        //set isAutorotating  to be true
        WKExtension.shared().isAutorotating = true
        
        if WCSession.isSupported() {
            session = WCSession.default
            session.delegate = self
            session.activate()
        }
        
        sendFileButton.setTitle("File Not Ready")
        
        punch_detection_activate()
        
        // startWorkout()
        //let fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("ges.csv")
        
        //self.startUpdates(filePath)
    }
    
    func punch_detection_activate(){
        //reset()
        observable_flag = 0
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates()
        punch_timer = Timer.scheduledTimer(timeInterval: 1.0/60, target: self, selector: #selector(InterfaceController.is_punch), userInfo: nil, repeats: true)
    }
        
    @objc func is_punch(){
        if let deviceMotion = motionManager.deviceMotion{
            self.accX.setText(String(format: "%.2fg", deviceMotion.gravity.x))
            self.accY.setText(String(format: "%.2fg", deviceMotion.gravity.y))
            self.accZ.setText(String(format: "%.2fg", deviceMotion.gravity.z))
            self.rotX.setText(String(format: "%.2fg", deviceMotion.rotationRate.x))
            self.rotY.setText(String(format: "%.2fg", deviceMotion.rotationRate.y))
            self.rotZ.setText(String(format: "%.2fg", deviceMotion.rotationRate.z))
            if(abs(deviceMotion.rotationRate.z) > 4){
                punch_timer.invalidate()
                motionManager.stopDeviceMotionUpdates()
                predict_start()
                // set the falg to 1 to trigger observer handler to restart punch_detection.
                observable_flag = 1
            }
        }
    }
    
    private func startWorkout() {
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .other
        
        do {
            workoutSession = try HKWorkoutSession(configuration: workoutConfiguration)
            workoutSession?.delegate = self as! HKWorkoutSessionDelegate
            healthStore.start(workoutSession!)
        } catch {
            print(error)
        }
    }
    
    @objc fileprivate func vibrate() {
        WKInterfaceDevice.current().play(.success)
    }
    
//    func startUpdates(_ filePath:String) {
//        if !motionManager.isDeviceMotionAvailable {
//            print("Device Motion is not available.")
//            return
//        }
//        //set sampling interval
//        // 1.0 / 60.0 is a little overload
//
//        //var lines = 1
//        var iterations = 0
//        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
//        //
//        //                                     to: withHandler? difference?
//        //var gameTimer: Timer!
//        //gameTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(runTimedCode), userInfo: nil, repeats: true)
//        motionManager.startDeviceMotionUpdates(to: queue) { (deviceMotion: CMDeviceMotion?, error: Error?) in
//            if error != nil {
//                print("Encountered error: \(error!)")
//            }
//
//            if deviceMotion != nil {
//
//                    self.outputGestureData(deviceMotion!, filePath)
//            }
//        }
//
//
//    }
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        // To set the autorotating back to default
        WKExtension.shared().isAutorotating = false
    }

    
    // *******************************  Training Part  ****************************** //
    @IBAction func start(){
        sendFileButton.setTitle("File Not Ready") //Start recording,File not ready
        sendFileButton.setEnabled(false)          //Disable send button
        counter = 0 // to limit number of data
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        //      motionManager.startAccelerometerUpdates()
        //      motionManager.startGyroUpdates()
        motionManager.startDeviceMotionUpdates()
        timer = Timer.scheduledTimer(timeInterval: 1.0/60, target: self, selector: #selector(InterfaceController.update_csv), userInfo: nil, repeats: true) //timer to trigger update() every 1/60 sec
    }
    
    @objc func update_csv() { //write data to csv file
        let fileName = "ges.csv"
        let filePath:String = NSHomeDirectory() + "/Documents/" + fileName
        counter += 1
        if let deviceMotion = motionManager.deviceMotion {
            print(deviceMotion)
            outputGestureData(deviceMotion, filePath)
        }
        if(counter >= dimensionOfData){ // TIMER STOP, REGULATE NUMBER OF DATA
            timer.invalidate()
            self.addToFile(content: "\n", filepath: filePath)
            //motionManager.stopDeviceMotionUpdates()
            sendFileButton.setTitle("Ready")//File ready
            sendFileButton.setEnabled(true) //Enable send button
        }
        //
        //        if let accelerometerData = motionManager.accelerometerData {
        //            print(accelerometerData)
        //
        //        }
        //        if let gyroData = motionManager.gyroData {
        //            print(gyroData)
        //        }
        
        //        if let magnetometerData = motionManager.magnetometerData {
        //            print(magnetometerData)
        //        }
    }
    @IBAction func sendFile(){
        let fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("ges.csv")
        WCSession.default.transferFile(fileURL,metadata: ["fileName" : "dataset"])
        sendFileButton.setTitle("Sent")
    }
    @IBAction func createFile(){ //create file under Documents/
        let name = "ges.csv"
        let manager = FileManager.default
        let file = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(name)
        print("file: \(file)")
        let exist = manager.fileExists(atPath: file.path)
        
        if exist { //if exist, delete item and recreate a blank file
            do{
                try manager.removeItem(atPath: file.path)
            }catch let error {
                print("error occurred, here are the details:\n \(error)")
            }
            
        }
        let createSuccess = manager.createFile(atPath: file.path,contents:nil,attributes:nil)
        print("Result of create file: \(createSuccess)")
    }
    func createFile(name:String){ //create file under Documents/
        let manager = FileManager.default
        let file = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(name)
        print("file: \(file)")
        let exist = manager.fileExists(atPath: file.path)
        
        if exist { //if exist, delete item and recreate a blank file
            do{
                try manager.removeItem(atPath: file.path)
            }catch let error {
                print("error occurred, here are the details:\n \(error)")
            }
            
        }
        let createSuccess = manager.createFile(atPath: file.path,contents:nil,attributes:nil)
        print("Result of create file: \(createSuccess)")
    }
    @IBAction func deleteDataFile(){
        let name = "ges.csv"
        let manager = FileManager.default
        let file = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(name)
        print("file: \(file)")
        let exist = manager.fileExists(atPath: file.path)
        inMessageText.setText("File not exist")
        if exist { //if exist, delete item and recreate a blank file
            inMessageText.setText("File exist")
            do{
                try manager.removeItem(atPath: file.path)
            }catch let error {
                print("error occurred, here are the details:\n \(error)")
            }
            
        }
    }
    //seek to end of file and write text
    func addToFile(content: String, filepath: String) {
        let contentToAppend = content  //+"\n"
        //let filePath = NSHomeDirectory() + "/Documents/" + fileName
        let filePath = filepath
        //Check if file exists
        if let fileHandle = FileHandle(forWritingAtPath: filePath) {
            //Append to file
            fileHandle.seekToEndOfFile()
            fileHandle.write(contentToAppend.data(using: String.Encoding.utf8)!)
        }
        else {
            //Create new file
            do {
                try contentToAppend.write(toFile: filePath, atomically: true, encoding: String.Encoding.utf8)
            } catch {
                print("Error creating \(filePath)")
            }
        }
    }
    // **************************  Predict Part  *************************************** //
    @IBAction func predict_start(){
        predict_counter = 0 // to limit number of data
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        //      motionManager.startAccelerometerUpdates()
        //      motionManager.startGyroUpdates()
        motionManager.startDeviceMotionUpdates()
        predict_timer = Timer.scheduledTimer(timeInterval: 1.0/60, target: self, selector: #selector(InterfaceController.predict_update), userInfo: nil, repeats: true) //timer to trigger update() every 1/60 sec
    }
    
    @objc func predict_update() { // get gesture input
        predict_counter += 1
        if let deviceMotion = motionManager.deviceMotion {
            getGesture(deviceMotion)
        }
        if(predict_counter >= dimensionOfData){ // TIMER STOP, REGULATE NUMBER OF DATA
            predict_timer.invalidate()
            predict()
            gesToRecognize.removeAll()
        }
    }
    
    func predict(){
        let model = sklearn()   //Create model object
        let data = gesToRecognize //Gesture data ( Double array--size is 180 )
        //Format(Shape) Double array to MLMultiArray
        guard let mlMultiArray = try? MLMultiArray(shape:[180,1], dataType:MLMultiArrayDataType.double) else {
            fatalError("Unexpected runtime error. MLMultiArray")
        }
        for (index, element) in data.enumerated() {
            mlMultiArray[index] = NSNumber(floatLiteral: element)
        }
        //Predict gesture with trained model (SVM model)
        let predict_result = try! model.prediction(input: mlMultiArray)
        predict_result_label.setText(predict_result.classLabel) //Output predict result
        sendMessage(["Message": predict_result.classLabel])
    }
    
    func getGesture(_ deviceMotion: CMDeviceMotion) {//_ fileURL: URL){ //,
        let gravity = deviceMotion.gravity
        let rotationRate = deviceMotion.rotationRate
        //sendMessage(["Message" : "accX: " + String(format: "%.2fg", gravity.x)])
        //  CSV File Format:
        
        //  |accx|rotx||accy|roty||accz|rotz|...   one complete gesture
        //  |accx|rotx||accy|roty||accz|rotz|...   another gesture
        gesToRecognize.append(Double(String(format: "%.2f", gravity.x))!)
        gesToRecognize.append(Double(String(format: "%.2f", rotationRate.x))!)
        gesToRecognize.append(Double(String(format: "%.2f", gravity.y))!)
        gesToRecognize.append(Double(String(format: "%.2f", rotationRate.y))!)
        gesToRecognize.append(Double(String(format: "%.2f", gravity.z))!)
        gesToRecognize.append(Double(String(format: "%.2f", rotationRate.z))!)
 
    }
    func outputGestureData(_ deviceMotion: CMDeviceMotion,_ filePath:String){//_ fileURL: URL){ //,
        reset()
        let gravity = deviceMotion.gravity
        let rotationRate = deviceMotion.rotationRate
        //sendMessage(["Message" : "accX: " + String(format: "%.2fg", gravity.x)])
        //  CSV File Format:
        
        //  |accx|rotx||accy|roty||accz|rotz|...   one complete gesture
        //  |accx|rotx||accy|roty||accz|rotz|...   another gesture
        if(counter < dimensionOfData){
        addToFile(content: String(format: "%.2f", gravity.x)+","+String(format: "%.2f", rotationRate.x) + ","
            + String(format: "%.2f", gravity.y)+","+String(format: "%.2f", rotationRate.y) + ","
            + String(format: "%.2f", gravity.z)+","+String(format: "%.2f", rotationRate.z) + "," ,filepath: filePath)
        }
        else if(counter >= dimensionOfData){ // end of line should not add the comma ','
            addToFile(content: String(format: "%.2f", gravity.x)+","+String(format: "%.2f", rotationRate.x) + ","
                + String(format: "%.2f", gravity.y)+","+String(format: "%.2f", rotationRate.y) + ","
                + String(format: "%.2f", gravity.z)+","+String(format: "%.2f", rotationRate.z) ,filepath: filePath)
        }
        
        accX.setText(String(format: "%.2fg", gravity.x))
        if abs(gravity.x) > abs(currentMaxAccelX) {
            currentMaxAccelX = gravity.x
        }
        
        accY.setText(String(format: "%.2fg", gravity.y))
        //sendMessage(["Message" : "accY: " + String(format: "%.2fg", gravity.y)])
        
        if abs(gravity.y) > abs(currentMaxAccelY) {
            currentMaxAccelY = gravity.y
        }
        
        accZ.setText(String(format: "%.2fg", gravity.z))
        //sendMessage(["Message" : "accZ: " + String(format: "%.2fg", gravity.z)])
        
        if abs(gravity.z) > abs(currentMaxAccelZ) {
            currentMaxAccelZ = gravity.z
        }
        
        maxAccX.setText(String(format: "%.2fg", currentMaxAccelX))
        maxAccY.setText(String(format: "%.2fg", currentMaxAccelY))
        maxAccZ.setText(String(format: "%.2fg", currentMaxAccelZ))
        
        
        rotX.setText(String(format: "%.2fr/s", rotationRate.x))
        //send data to ios app
        //sendMessage(["Message" : "rotX: " + String(format: "%.2fr/s", rotationRate.x)])
        
        if abs(rotationRate.x) > abs(currentMaxRotX) {
            currentMaxRotX = rotationRate.x
        }
        
        rotY.setText(String(format: "%.2fr/s", rotationRate.y))
        //sendMessage(["Message" : "rotY: " + String(format: "%.2fr/s", rotationRate.y)])
        
        if abs(rotationRate.y) > abs(currentMaxRotY) {
            currentMaxRotY = rotationRate.y
        }
        
        rotZ.setText(String(format: "%.2fr/s", rotationRate.z))
        //sendMessage(["Message" : "rotZ: " + String(format: "%.2fr/s", rotationRate.z)])
        
        
        if abs(rotationRate.z) > abs(currentMaxRotZ) {
            currentMaxRotZ = rotationRate.z
        }
        
        maxRotX.setText(String(format: "%.2fr/s", currentMaxRotX))
        maxRotY.setText(String(format: "%.2fr/s", currentMaxRotY))
        maxRotZ.setText(String(format: "%.2fr/s", currentMaxRotZ))
    }
    @IBAction func reset() {
        currentMaxAccelX = 0.0
        currentMaxAccelY = 0.0
        currentMaxAccelZ = 0.0
        currentMaxRotX = 0.0
        currentMaxRotY = 0.0
        currentMaxRotZ = 0.0
        maxAccX.setText(String("0"))
        maxAccY.setText(String("0"))
        maxAccZ.setText(String("0"))
        maxRotX.setText(String("0"))
        maxRotY.setText(String("0"))
        maxRotZ.setText(String("0"))
    }
}




//Workout session
extension InterfaceController: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didGenerate event: HKWorkoutEvent) {
        
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        switch toState {
        case .running:
            hapticFeedbackTimer = Timer(timeInterval: 5, target: self, selector: #selector(vibrate), userInfo: nil, repeats: true)
            RunLoop.main.add(hapticFeedbackTimer!, forMode: .defaultRunLoopMode)
        default:
            hapticFeedbackTimer?.invalidate()
            hapticFeedbackTimer = nil
        }
    }
}

//WatchActions -> InterfaceController
typealias WatchActions = InterfaceController
extension WatchActions {
    
    // Send message to paired iOS App (Parent)
    @IBAction func sendToParent() {
        sendMessage()
    }
    
}

//WatchSessionProtocol -> InterfaceController
typealias WatchSessionProtocol = InterfaceController
extension WatchSessionProtocol {
    
    // WCSession Delegate protocol
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        
        // Reply handler, received message
        let value = message["Message"] as? String
        
        // GCD - Present on the screen
        DispatchQueue.main.async { () -> Void in
            self.messageLabel.setText(value!)
        }
        
        // Send a reply
        replyHandler(["Message":"Hi 8 Plus, I received your message"])
        
    }
}

//WatchSessionTasks -> InterfaceController
typealias WatchSessionTasks = InterfaceController
extension WatchSessionTasks {
    
    // Method to send message to paired iOS App (Parent)
    func sendMessage(){
        // A dictionary of property list values that you want to send.
        let messageToSend = ["Message":"Hi 8 Plus! I'm reachable!!!"]
        
        // Task : Sends a message immediately to the counterpart and optionally delivers a response
        session.sendMessage(messageToSend, replyHandler: { (replyMessage) in
            
            // Reply handler - present the reply message on screen
            let value = replyMessage["Message"] as? String
            
            // Set message label text with value
            self.messageLabel.setText(value)
            
        }) { (error) in
            // Catch any error Handler
            print("error: \(error.localizedDescription)")
        }
    }
    
    //send the data file to iphone
    //    func sendFile(){
    //
    //    }
    
    func sendMessage(_ message: [String : Any]){
        let messageToSend = message
        
        // Task : Sends a message immediately to the counterpart and collect the response from counterpart
        session.sendMessage(messageToSend, replyHandler: { (replyMessage) in
            
            // Reply handler - present the reply message on screen, this message is set by replayHandler in counterpart (viewcontroller.swift)
            let value = replyMessage["Message"] as? String
            
            // Set message label text with value
            self.messageLabel.setText(value)
            
        }) { (error) in
            // Catch any error Handler
            print("error: \(error.localizedDescription)")
        }
    }
    
}

