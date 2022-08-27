//
//  ViewController.swift
//  FaceDetectionSystem
//
//  Created by David Razmadze on 8/27/22.
//
//  Following this tutorial: https://medium.com/onfido-tech/live-face-tracking-on-ios-using-vision-framework-adf8a1799233

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {

  // MARK: - Variables
  
  private var drawings: [CAShapeLayer] = []
  
  private let videoDataOutput = AVCaptureVideoDataOutput()
  private let captureSession = AVCaptureSession()
  
  /// Using `lazy` keyword because the `captureSession` needs to be loaded before we can use the preview layer.
  private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
  
  // MARK: - Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    
    addCameraInput()
    showCameraFeed()
    
    getCameraFrames()
    captureSession.startRunning()
  }
  
  /// The account for when the container's `view` changes.
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    previewLayer.frame = view.frame
  }
  
  // MARK: - Helper Functions
  
  private func addCameraInput() {
    
    guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInDualCamera, .builtInWideAngleCamera], mediaType: .video, position: .front).devices.first else {
      fatalError("No camera detected. Please use a real camera, not a simulator.")
    }
    
    // ⚠️ You should wrap this in a `do-catch` block, but this will be good enough for the demo.
    let cameraInput = try! AVCaptureDeviceInput(device: device)
    captureSession.addInput(cameraInput)
  }
  
  private func showCameraFeed() {
    previewLayer.videoGravity = .resizeAspectFill
    view.layer.addSublayer(previewLayer)
    previewLayer.frame = view.frame
  }
  
  private func getCameraFrames() {
    videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString): NSNumber(value: kCVPixelFormatType_32BGRA)] as [String: Any]
    
    videoDataOutput.alwaysDiscardsLateVideoFrames = true
    // You do not want to process the frames on the Main Thread so we off load to another thread
    videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
    
    captureSession.addOutput(videoDataOutput)
    
    guard let connection = videoDataOutput.connection(with: .video), connection.isVideoOrientationSupported else {
      return
    }
    
    connection.videoOrientation = .portrait
  }
  
  private func detectFace(image: CVPixelBuffer) {
    let faceDetectionRequest = VNDetectFaceLandmarksRequest { vnRequest, error in
      DispatchQueue.main.async {
        if let results = vnRequest.results as? [VNFaceObservation], results.count > 0 {
          // print("✅ Detected \(results.count) faces!")
          self.handleFaceDetectionResults(observedFaces: results)
        } else {
          // print("❌ No face was detected")
          self.clearDrawings()
        }
      }
    }
    
    let imageResultHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
    try? imageResultHandler.perform([faceDetectionRequest])
  }
  
  private func handleFaceDetectionResults(observedFaces: [VNFaceObservation]) {
    clearDrawings()
    
    // Create the boxes
    let facesBoundingBoxes: [CAShapeLayer] = observedFaces.map({ (observedFace: VNFaceObservation) -> CAShapeLayer in
      
      let faceBoundingBoxOnScreen = previewLayer.layerRectConverted(fromMetadataOutputRect: observedFace.boundingBox)
      let faceBoundingBoxPath = CGPath(rect: faceBoundingBoxOnScreen, transform: nil)
      let faceBoundingBoxShape = CAShapeLayer()
      
      // Set properties of the box shape
      faceBoundingBoxShape.path = faceBoundingBoxPath
      faceBoundingBoxShape.fillColor = UIColor.clear.cgColor
      faceBoundingBoxShape.strokeColor = UIColor.green.cgColor
      
      return faceBoundingBoxShape
    })
    
    // Add boxes to the view layer and the array
    facesBoundingBoxes.forEach { faceBoundingBox in
      view.layer.addSublayer(faceBoundingBox)
      drawings = facesBoundingBoxes
    }
  }
  
  private func clearDrawings() {
    drawings.forEach({ drawing in drawing.removeFromSuperlayer() })
  }
  
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    
    guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      debugPrint("Unable to get image from the sample buffer")
      return
    }
    
    detectFace(image: frame)
  }
  
}
