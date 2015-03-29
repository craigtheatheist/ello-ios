//
//  UIScreenEdgePanGestureRecognizer.swift
//  Ello
//
//  Created by Gordon Fontenot on 3/23/15.
//  Copyright (c) 2015 Ello. All rights reserved.
//

import UIKit

extension UIScreenEdgePanGestureRecognizer {
    var percentageThroughView: CGFloat {
        let view = self.view!
        let x = locationInView(view).x
        let width = view.bounds.size.width
        var percent = x / width

        if translationInView(view).x < 0.0 {
            percent = 1.0 - percent
        }

        return percent
    }
}