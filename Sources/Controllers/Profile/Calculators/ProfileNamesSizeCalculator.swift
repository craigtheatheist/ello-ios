////
///  ProfileNamesSizeCalculator.swift
//

import FutureKit


public struct ProfileNamesSizeCalculator {
    let promise = Promise<CGFloat>()

    public func calculate(item: StreamCellItem, maxWidth: CGFloat) -> Future<CGFloat> {
        guard let
            user = item.jsonable as? User
        else {
            promise.completeWithSuccess(0)
            return promise.future
        }

        let nameFont = ProfileNamesView.nameFont
        let usernameFont = ProfileNamesView.usernameFont

        let nameSize: CGSize
        if user.name.isEmpty {
            nameSize = .zero
        }
        else {
            nameSize = user.name.sizeWithAttributes([
                NSFontAttributeName: nameFont
            ]).integral
        }

        let usernameSize = user.atName.sizeWithAttributes([
            NSFontAttributeName: usernameFont
        ]).integral

        let (height, _) = ProfileNamesView.preferredHeight(nameSize: nameSize, usernameSize: usernameSize, maxWidth: maxWidth)
        let totalHeight = height + ProfileNamesView.Size.outerMargins.top + ProfileNamesView.Size.outerMargins.bottom
        promise.completeWithSuccess(totalHeight)

        return promise.future
    }
}
