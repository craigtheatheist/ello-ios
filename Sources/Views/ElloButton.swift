//
//  ElloButton.swift
//  Ello
//
//  Created by Sean Dougherty on 11/24/14.
//  Copyright (c) 2014 Ello. All rights reserved.
//

import UIKit

public class ElloButton: UIButton {

    override public var enabled: Bool {
        didSet { updateStyle() }
    }

    override public var selected: Bool {
        didSet { updateStyle() }
    }

    func updateStyle() {
        backgroundColor = enabled ? UIColor.blackColor() : UIColor.grey231F20()
    }

    required override public init(frame: CGRect) {
        super.init(frame: frame)
        sharedSetup()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        sharedSetup()
    }

    public override func awakeFromNib() {
        super.awakeFromNib()

        if buttonType != .Custom {
            print("Warning, ElloButton instance '\(currentTitle)' should be configured as 'Custom', not \(buttonType)")
        }

        updateStyle()
    }

    func sharedSetup() {
        titleLabel?.font = UIFont.defaultFont()
        titleLabel?.numberOfLines = 1
        setTitleColor(UIColor.whiteColor(), forState: .Normal)
        setTitleColor(UIColor.greyA(), forState: .Disabled)
        updateStyle()
    }

    public override func titleRectForContentRect(contentRect: CGRect) -> CGRect {
        var titleRect = super.titleRectForContentRect(contentRect)
        let delta: CGFloat = 4
        titleRect.size.height += 2 * delta
        titleRect.origin.y -= delta
        return titleRect
    }

}

public class LightElloButton: ElloButton {

    override func updateStyle() {
        backgroundColor = enabled ? UIColor.greyE5() : UIColor.greyF1()
    }

    override func sharedSetup() {
        titleLabel?.font = UIFont.defaultFont()
        titleLabel?.numberOfLines = 1
        setTitleColor(UIColor.grey6(), forState: .Normal)
        setTitleColor(UIColor.blackColor(), forState: .Highlighted)
        setTitleColor(UIColor.greyC(), forState: .Disabled)
    }

}

public class WhiteElloButton: ElloButton {

    required public init(frame: CGRect) {
        super.init(frame: frame)
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func updateStyle() {
        if !enabled {
            backgroundColor = UIColor.greyA()
        }
        else if selected {
            backgroundColor = UIColor.blackColor()
        }
        else {
            backgroundColor = UIColor.whiteColor()
        }
    }

    override func sharedSetup() {
        super.sharedSetup()
        titleLabel?.font = UIFont.defaultFont()
        setTitleColor(UIColor.blackColor(), forState: .Normal)
        setTitleColor(UIColor.grey6(), forState: .Highlighted)
        setTitleColor(UIColor.greyC(), forState: .Disabled)
        setTitleColor(UIColor.whiteColor(), forState: .Selected)
    }
}

public class OutlineElloButton: WhiteElloButton {

    override func sharedSetup() {
        super.sharedSetup()
        backgroundColor = UIColor.whiteColor()
        updateOutline()
    }

    override public var highlighted: Bool {
        didSet {
            updateOutline()
        }
    }

    private func updateOutline() {
        layer.borderColor = highlighted ? UIColor.greyE5().CGColor : UIColor.blackColor().CGColor
        layer.borderWidth = 1
    }
}


public class RoundedElloButton: ElloButton {
    var borderColor: UIColor = UIColor.blackColor() {
        didSet {
            updateOutline()
        }
    }

    override public func sharedSetup() {
        super.sharedSetup()
        setTitleColor(UIColor.blackColor(), forState: .Normal)
        setTitleColor(UIColor.grey6(), forState: .Highlighted)
        setTitleColor(UIColor.greyC(), forState: .Disabled)
        layer.borderWidth = 1
        backgroundColor = UIColor.clearColor()
        updateOutline()
    }

    override func updateStyle() {
        backgroundColor = enabled ? UIColor.clearColor() : UIColor.grey231F20()
    }

    func updateOutline() {
        layer.borderColor = borderColor.CGColor
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(frame.height, frame.width) / 2
    }
}

public class GreenElloButton: ElloButton {

    override func updateStyle() {
        backgroundColor = enabled ? UIColor.greenD1() : UIColor.greyF1()
    }

    override func sharedSetup() {
        titleLabel?.font = UIFont.defaultFont()
        titleLabel?.numberOfLines = 1
        setTitleColor(UIColor.whiteColor(), forState: .Normal)
        setTitleColor(UIColor.grey6(), forState: .Highlighted)
        setTitleColor(UIColor.greyA(), forState: .Disabled)
        layer.cornerRadius = 5
    }

}
