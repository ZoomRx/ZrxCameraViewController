//
//  CameraViewController.swift
//  PhotoPreviewer
//
//  Created by Swaminathan on 25/02/21.
//  Copyright © 2021 ZoomRx. All rights reserved.
//

import UIKit
import AVFoundation

public protocol CameraViewControllerDelegate {
    
    /// Called when the user has finished capturing the image
    /// - Parameters:
    ///   - image: optional UIImage object
    ///   - viewController: the CameraViewController
    func didFinishTaking(image: UIImage?, viewController: CameraViewController)
    
    /// Called when the session has been cancelled due to an error
    /// - Parameters:
    ///   - message: the error message
    ///   - error: the error object
    ///   - viewController: the CameraViewController
    func didCancelWith(message: String, error: Error?, viewController: CameraViewController)
    
    /// Called when the user has not given the camera permission
    /// - Parameter viewController: the CameraViewController
    func permissionDenied(viewController: CameraViewController)
}

public class CameraViewController: UIViewController {
    
    //MARK: - Outlets
    @IBOutlet weak var captureButton: CameraButton!
    @IBOutlet weak var flipCameraButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var captureButtonHeight: NSLayoutConstraint!
    @IBOutlet weak var captureButtonWidth: NSLayoutConstraint!
    @IBOutlet weak var flipCameraButtonTrailing: NSLayoutConstraint!
    @IBOutlet weak var flashButtonLeading: NSLayoutConstraint!
    
    //MARK: - Properties
    public var iPadCaptureButtonDimension: CGFloat = 75
    public var iPadButtonSpacing: CGFloat = 100
    public var shadowOpacity: Float = 0.25
    public var flashMode: AVCaptureDevice.FlashMode = .off
    public var pinchToZoom = true
    public var delegate: CameraViewControllerDelegate?
    
    var captureSession: AVCaptureSession!
    var cameraPosition: AVCaptureDevice.Position = .back
    var cameraDeviceInput: AVCaptureDeviceInput!
    var cameraDeviceOutput: AVCapturePhotoOutput!
    var cameraDevice: AVCaptureDevice!
    var previewLayer : AVCaptureVideoPreviewLayer!
    
    static var bundle: Bundle {
        return Bundle(for: CameraViewController.self)
    }
    
    //MARK: - Methods
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    /// To allow init as CameraViewController() and not specify bundle everytime
    convenience init() {
        self.init(nibName: "CameraViewController" , bundle: CameraViewController.bundle)
    }
    
    /// Mandatory since this ViewController has xib file. Leaving it with the default template as it will not load from storyboard directly
    /// - Parameter coder: NSCoder object
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        flipCameraButton.layer.shadowOpacity = shadowOpacity
        captureButton.layer.shadowOpacity = shadowOpacity
        flashButton.layer.shadowOpacity = shadowOpacity
        
        flipCameraButton.tintColor = .white
        flashButton.tintColor = .white
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.edgesForExtendedLayout = []
            captureButtonHeight.constant = iPadCaptureButtonDimension
            captureButtonWidth.constant = iPadCaptureButtonDimension
            flipCameraButtonTrailing.constant = iPadButtonSpacing
            flashButtonLeading.constant = iPadButtonSpacing
        }
        
        checkPermissionAndStart()
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if self.captureSession != nil {
            self.captureSession.stopRunning()
        }
    }
    
    //MARK: - IBActions
    /// Action when the switch camera button is tapped
    /// - Parameter sender: the sender object
    @IBAction func cameraSwitchTapped(_ sender: Any) {
        switchCamera()
    }
    
    /// Action when the toggle flash button is tapped
    /// - Parameter sender: the sender object
    @IBAction func toggleFlashTapped(_ sender: Any) {
        toggleFlashAnimation()
    }
    
    /// Action when the capture button is tapped
    /// - Parameter sender: the sender object
    @IBAction func takePhoto(_ sender: UIButton) {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])
        if cameraPosition == .front {
            settings.flashMode = .off
        } else {
            settings.flashMode = flashMode
        }
        self.cameraDeviceOutput.capturePhoto(with: settings, delegate: self)
    }
    
    //MARK: - Gestures
    /// Pinch gesture handler which handles the zoom functionality
    /// - Parameter pinch: UIPinchGestureRecognizer object
    @objc func zoomGesture(pinch: UIPinchGestureRecognizer) {
        guard pinchToZoom == true && self.cameraPosition == .back else {
            //ignore pinch
            return
        }
        do {
            
            try cameraDevice?.lockForConfiguration()
            defer {
                cameraDevice?.unlockForConfiguration()
            }
            
            let zoomScale = min(max(pinch.scale, 1.0), cameraDevice.activeFormat.videoMaxZoomFactor)
            
            cameraDevice?.videoZoomFactor = zoomScale
            
        } catch {
            print("Error while zooming")
        }
    }
    
    /// Tap gesture which handles the focus functionality
    /// - Parameter tap: UITapGestureRecognizer object
    @objc func singleTapGesture(tap: UITapGestureRecognizer) {
        
        let screenSize = self.view.frame.size
        let tapPoint = tap.location(in: self.view)
        let x = tapPoint.y / screenSize.height
        let y = 1.0 - tapPoint.x / screenSize.width
        let focusPoint = CGPoint(x: x, y: y)
        
        do {
            try cameraDevice.lockForConfiguration()
            
            if cameraDevice.isFocusPointOfInterestSupported == true {
                cameraDevice.focusPointOfInterest = focusPoint
                cameraDevice.focusMode = .autoFocus
            }
            cameraDevice.exposurePointOfInterest = focusPoint
            cameraDevice.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
            cameraDevice.unlockForConfiguration()
        } catch {
            // just ignore
        }
    }
    
    //MARK: - Utility functions
    /// This is used to return the UIImage from a specified bundle and not the default app bundle
    /// - Parameter named: name of the image
    /// - Returns: Optional UIImage object
    func bundledImage(named: String) -> UIImage? {
        return UIImage(named: named, in: Bundle(for: CameraViewController.self), compatibleWith: nil)
    }
    
    /// function to check (and ask for) camera permission and then start the configuration if granted
    func checkPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupAndStartCaptureSession()
            addGestures()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (granted) in
                if !granted {
                    DispatchQueue.main.async {
                        self.delegate?.permissionDenied(viewController: self)
                        return
                    }
                }
                
                DispatchQueue.main.async {
                    self.setupAndStartCaptureSession()
                    self.addGestures()
                }
            }
        default:
            DispatchQueue.main.async {
                self.delegate?.permissionDenied(viewController: self)
            }
        }
    }
    
    /// Function to add the pinch and zoom gestures
    func addGestures() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(zoomGesture(pinch:)))
        self.view.addGestureRecognizer(pinchGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(singleTapGesture(tap:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    /// Switches the camera when the switch camera button is tapped
    func switchCamera() {
        flipCameraButton.isUserInteractionEnabled = false
        
        guard captureSession.isRunning == true else {
            return
        }
        
        switch cameraPosition {
        case .front:
            cameraPosition = .back
        case .back:
            cameraPosition = .front
        default:
            break
        }
        
        captureSession.beginConfiguration()
        
        self.captureSession.removeInput(cameraDeviceInput)
        
        setupInputs()
        
        if cameraPosition == .front {
            // To avoid lateral inversion
            cameraDeviceOutput.connections.first?.isVideoMirrored = true
        }
        
        captureSession.commitConfiguration()
        
        flipCameraButton.isUserInteractionEnabled = true
        
    }
    
    /// Function to change flash icon and toggle flashMode when the toggle flash button is clicked
    func toggleFlashAnimation() {
        if flashMode == .auto{
            flashMode = .on
            flashButton.setImage(bundledImage(named: "flash") , for: UIControl.State())
        }else if flashMode == .on{
            flashMode = .off
            flashButton.setImage(bundledImage(named: "flashOff") , for: UIControl.State())
        }else if flashMode == .off{
            flashMode = .auto
            flashButton.setImage(bundledImage(named: "flashauto"), for: UIControl.State())
        }
    }
    
    /// Function to setup and start the AVCaptureSession
    func setupAndStartCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession = AVCaptureSession()
            self.captureSession.beginConfiguration()
            
            if self.captureSession.canSetSessionPreset(.photo) {
                self.captureSession.sessionPreset = .photo
            }
            
            self.setupInputs()
            self.setupOutput()
            self.captureSession.commitConfiguration()
            
            DispatchQueue.main.async {
                self.flashButton.isHidden = false
            }
            
            if !self.cameraDevice.hasTorch {
                DispatchQueue.main.async {
                    self.flashButton.isHidden = true
                }
            }
            
            self.captureSession.startRunning()
            
            DispatchQueue.main.async {
                self.setupPreviewLayer()
            }
        }
    }
    
    /// Function to configure input devices
    func setupInputs() {
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) {
            cameraDevice = device
        } else {
            delegate?.didCancelWith(message: "No back camera found", error: nil, viewController: self)
        }
        
        guard let cameraInput = try? AVCaptureDeviceInput(device: cameraDevice) else {
            delegate?.didCancelWith(message: "Could not create input device", error: nil, viewController: self)
            return
        }
        
        if !captureSession.canAddInput(cameraInput) {
            delegate?.didCancelWith(message: "Could not add input session", error: nil, viewController: self)
            return
        }
        
        cameraDeviceInput = cameraInput
        captureSession.addInput(cameraInput)
    }
    
    /// Function to configure output devices
    func setupOutput() {
        cameraDeviceOutput = AVCapturePhotoOutput()
        
        if !captureSession.canAddOutput(cameraDeviceOutput) {
            delegate?.didCancelWith(message: "Could not add output session", error: nil, viewController: self)
        }
        
        captureSession.addOutput(cameraDeviceOutput)
    }
    
    /// Function to setup the previewLayer which shows the live camera preview
    func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//        previewLayer.videoGravity = .resizeAspectFill
        var frame = self.view.layer.frame
        frame.origin.y = 0
        previewLayer.frame = frame
        previewLayer.connection?.videoOrientation = .portrait
        view.layer.insertSublayer(previewLayer, below: captureButton.layer)
    }
    
}

//MARK: - AVCapturePhotoCapture Delegate methods
extension CameraViewController: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        var image: UIImage? = nil
        
        if let imageData = photo.fileDataRepresentation() {
            image = UIImage(data: imageData)
        }
        
//        let outputRect = previewLayer.metadataOutputRectConverted(fromLayerRect: previewLayer.bounds)
//        var cgImage = image!.cgImage!
//        let width = CGFloat(cgImage.width)
//        let height = CGFloat(cgImage.height)
//        let cropRect = CGRect(x: outputRect.origin.x * width, y: outputRect.origin.y * height, width: outputRect.size.width * width, height: outputRect.size.height * height)
//
//        cgImage = cgImage.cropping(to: cropRect)!
//        let croppedUIImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: image!.imageOrientation)
        
        delegate?.didFinishTaking(image: image, viewController: self)
        
    }
}

