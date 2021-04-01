//
//  CameraButton.swift
//  PhotoPreviewer
//
//  Created by Swaminathan on 25/02/21.
//  Copyright © 2021 ZoomRx. All rights reserved.
//

import Foundation
import UIKit

class CameraButton: UIButton {
    
    var circleBorder: CALayer!
    var innerCircle: UIView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        drawButton()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        drawButton()
    }
    
    
    /// Styles the button UIView
    func drawButton() {
        self.backgroundColor = UIColor.clear
        
        circleBorder = CALayer()
        circleBorder.backgroundColor = UIColor.clear.cgColor
        circleBorder.borderWidth = 6.0
        circleBorder.borderColor = UIColor.white.cgColor
        circleBorder.bounds = self.bounds
        circleBorder.position = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        circleBorder.cornerRadius = self.frame.size.width / 2
        layer.insertSublayer(circleBorder, at: 0)
        
    }
    
}
