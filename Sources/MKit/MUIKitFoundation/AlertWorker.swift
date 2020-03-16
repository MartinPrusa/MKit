//
//  AlertWorker.swift
//  MKit-iOS
//
//  Created by Martin Prusa on 4/23/19.
//

import UIKit

public final class AlertWorker {

    // MARK: Show

    public static func showConfirmationAlert(title: String?, message: String?, cancelTitle: String? = nil, okTitle: String?, presentController: UIViewController, okAction: (() -> ())?) {
        let alert = AlertWorker.alertWithCancelAndAction(title: title, message: message, cancelTitle: cancelTitle, okTitle: okTitle, okAction: okAction, cancelAction: nil)
        presentController.present(alert, animated: true, completion: nil)
    }

    public static func showConfirmationAlert(title: String?, message: String?, cancelTitle: String? = nil, okTitle: String?, presentController: UIViewController, okAction: @escaping () -> (), cancelAction: @escaping () -> ()) {
        let alert = AlertWorker.alertWithCancelAndAction(title: title, message: message, cancelTitle: cancelTitle, okTitle: okTitle, okAction: okAction, cancelAction: cancelAction)
        presentController.present(alert, animated: true, completion: nil)
    }

    public  static func showAlert(title: String?, message: String?, okTitle: String? = "OK", presentController: UIViewController, okAction: (() -> ())? = nil) {
        let alert = AlertWorker.alertWithCancel(title: title, message: message, okTitle: okTitle, okAction: okAction)
        presentController.present(alert, animated: true, completion: nil)
    }

    // MARK: Create alert

    public static func alertWithCancelAndAction(title: String?, message: String?, cancelTitle: String?, okTitle: String?, okAction: (() -> ())?, cancelAction: (() -> ())? = nil) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        if let okAction = okAction, let okTitle = okTitle {
            alert.addAction(UIAlertAction(title: okTitle, style: .default, handler: { (_) in
                okAction()
            }))
        }

        if let cancelTitle = cancelTitle {
            alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: { (_) in
                cancelAction?()
            }))
        } else {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                cancelAction?()
            }))
        }

        return alert
    }

    public static func alertWithCancel(title: String?, message: String?, okTitle: String?, okAction: (() -> ())? = nil) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: okTitle, style: .cancel, handler: { _ in
            if let action = okAction {
                action()
            }
        }))
        return alert
    }

    public static func alertWithCancel(cancelTitle: String?, cancelAction: (() -> Void)?, title: String?, message: String?, actions: [UIAlertAction]) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)

        if cancelTitle != nil {
            alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: { _ in
                if let action = cancelAction {
                    action()
                }
            }))
        }

        for action in actions {
            alert.addAction(action)
        }

        return alert
    }

    public static func alert(withTitle title: String?, message: String?) -> UIAlertController {
        return UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
    }

    // MARK: Action sheet

    public func actionSheet(title: String?, message: String?, sourceView: UIView) -> UIAlertController {
        let actionSheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)

        // following lines applied only on iPad which presents actionSheet as a popover
        actionSheet.popoverPresentationController?.sourceView = sourceView
        actionSheet.popoverPresentationController?.sourceRect = CGRect(x: sourceView.frame.width / 2, y: sourceView.frame.height / 2, width: 0, height: 0)
        actionSheet.popoverPresentationController?.permittedArrowDirections = .init(rawValue: 0)

        return actionSheet
    }
}

