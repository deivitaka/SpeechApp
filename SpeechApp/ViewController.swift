//
//  ViewController.swift
//  SpeechApp
//
//  Created by Deivi Taka on 1/16/17.
//  Copyright © 2017 Deivi Taka. All rights reserved.
//

import UIKit
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {

    @IBOutlet weak var noteLabel: UILabel!
    @IBOutlet weak var microphoneImageView: UIImageView!
    @IBOutlet weak var button: UIButton!
    
    private var listening = false
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine = AVAudioEngine()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize SFSpeechRecognizer
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func tappedButton() {
        askMicPermission(completion: { (granted, message) in
            DispatchQueue.main.async {
                if self.listening {
                    // Setup the text and stop the recording
                    self.listening = false
                    self.microphoneImageView.image = UIImage(named: "Microphone")
                    
                    if granted {
                        self.stopListening()
                    }
                } else {
                    // Setup the text and start recording
                    self.listening = true
                    self.microphoneImageView.image = UIImage(named: "Microphone Filled")
                    self.noteLabel.text = message
                    
                    if granted {
                        self.startListening()
                    }
                }
            }
        })
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        button.isEnabled = available
        if available {
            // Prepare to listen
            listening = true
            noteLabel.text = "Tap to listen"
            tappedButton()
        } else {
            noteLabel.text = "Recognition is not available."
        }
    }
    
    // MARK: - Private methods
    
    /**
        Check the status of Speech Recognizer authorization.
        - returns: A message, and if the access is granted.
     */
    private func askMicPermission(completion: @escaping (Bool, String) -> ()) {
        SFSpeechRecognizer.requestAuthorization { status in
            let message: String
            var granted = false
            
            switch status {
                case .authorized:
                    message = "Listening..."
                    granted = true
                    break
                    
                case .denied:
                    message = "Access to speech recognition is denied by the user."
                    break
                    
                case .restricted:
                    message = "Speech recognition is restricted."
                    break
                    
                case .notDetermined:
                    message = "Speech recognition has not been authorized yet."
                    break
            }
            
            completion(granted, message)
        }
    }

    /**
        Start listening to audio and try to convert it to text
     */
    private func startListening() {
        // Clear existing tasks
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Start audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch let error {
            noteLabel.text = "An error occurred when starting audio session. \(error.localizedDescription)"
            return
        }
        
        // Request speech recognition
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else {
            fatalError("No input node detected")
        }
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            var isFinal = false
            
            if result != nil {
                self.noteLabel.text = result?.bestTranscription.formattedString
                isFinal = result!.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.noteLabel.text = "Tap to listen"
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch let error {
            noteLabel.text = "An error occurred starting audio engine. \(error.localizedDescription)"
        }
    }
    
    /**
        Stop listening to audio and speech recognition
     */
    private func stopListening() {
        self.audioEngine.stop()
        self.recognitionRequest?.endAudio()
    }
}

