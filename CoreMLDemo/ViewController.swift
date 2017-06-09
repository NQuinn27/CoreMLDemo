//
//  ViewController.swift
//  CoreMLDemo
//
//  Created by niall quinn on 09/06/2017.
//  Copyright © 2017 Niall Quinn. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate{
  
  var session: AVCaptureSession?
  var stillImageOutput: AVCapturePhotoOutput?
  var videoPreviewLayer: AVCaptureVideoPreviewLayer?
  
  let model = VGG16()
  
  @IBOutlet weak var imageView: UIView!
  @IBOutlet weak var resultLabel: UILabel!
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    session = AVCaptureSession()
    session!.sessionPreset = AVCaptureSession.Preset.photo
    
    let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
    
    var error: NSError?
    var input: AVCaptureDeviceInput!
    do {
      input = try AVCaptureDeviceInput(device: backCamera!)
    } catch let error1 as NSError {
      error = error1
      input = nil
      print(error!.localizedDescription)
    }
    
    if error == nil && session!.canAddInput(input) {
      session!.addInput(input)
      stillImageOutput = AVCapturePhotoOutput()
      if session!.canAddOutput(stillImageOutput!) {
        session!.addOutput(stillImageOutput!)
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session!)
        videoPreviewLayer!.videoGravity = AVLayerVideoGravity.resizeAspect
        videoPreviewLayer!.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        imageView.layer.addSublayer(videoPreviewLayer!)
        session!.startRunning()
      }
    }
  }
  
  override func viewDidAppear(_ animated: Bool) {
    videoPreviewLayer!.frame = imageView.bounds
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    _ = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.capture), userInfo: nil, repeats: true);
    // Do any additional setup after loading the view, typically from a nib.
  }
  
  @objc func capture() {
    let settings = AVCapturePhotoSettings()
    let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
    let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                         kCVPixelBufferWidthKey as String: 224,
                         kCVPixelBufferHeightKey as String: 224]
    settings.previewPhotoFormat = previewFormat
    self.stillImageOutput?.capturePhoto(with: settings, delegate: self)
  }
  
  func photoOutput(_ captureOutput: AVCapturePhotoOutput,
                   didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?,
                   previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
               resolvedSettings: AVCaptureResolvedPhotoSettings,
               bracketSettings: AVCaptureBracketedStillImageSettings?,
               error: Error?) {
    
    if let sampleBuffer = photoSampleBuffer, let previewBuffer = previewPhotoSampleBuffer, let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {
      if let image : UIImage = UIImage(data: dataImage) {
        guard let pixelBuffer = image.resize(to: CGSize(width: 224, height: 224)).pixelBuffer() else {
          fatalError()
        }
        guard let modelOutput = try? model.prediction(image: pixelBuffer) else {
          print("Error")
          return
        }
        self.resultLabel.text = modelOutput.classLabel
      }
    }
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
  }
  


}

extension UIImage {
  
  func resize(to newSize: CGSize) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(CGSize(width: newSize.width, height: newSize.height), true, 1.0)
    self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    
    return resizedImage
  }
  
  func pixelBuffer() -> CVPixelBuffer? {
    let width = self.size.width
    let height = self.size.height
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                 kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                     Int(width),
                                     Int(height),
                                     kCVPixelFormatType_32ARGB,
                                     attrs,
                                     &pixelBuffer)
    
    guard let resultPixelBuffer = pixelBuffer, status == kCVReturnSuccess else {
      return nil
    }
    
    CVPixelBufferLockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(resultPixelBuffer)
    
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: pixelData,
                                  width: Int(width),
                                  height: Int(height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(resultPixelBuffer),
                                  space: rgbColorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
                                    return nil
    }
    
    context.translateBy(x: 0, y: height)
    context.scaleBy(x: 1.0, y: -1.0)
    
    UIGraphicsPushContext(context)
    self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
    UIGraphicsPopContext()
    CVPixelBufferUnlockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
    return resultPixelBuffer
  }
}

