//
//  MainController.swift
//  windmill
//
//  Created by Markos Charatzas on 13/02/2019.
//  Copyright © 2019 Windmill. All rights reserved.
//

import UIKit
import os

class MainController: UIViewController {
    
    var mainNavigationController: MainNavigationController? {
        return self.children.first{ $0 is MainNavigationController } as? MainNavigationController
    }

    var appsNavigationController: AppsNavigationController? {
        return self.children.first{ $0 is AppsNavigationController } as? AppsNavigationController
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        NotificationCenter.default.addObserver(self, selector: #selector(subscriptionActive(notification:)), name: SubscriptionManager.SubscriptionActive, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        NotificationCenter.default.addObserver(self, selector: #selector(subscriptionActive(notification:)), name: SubscriptionManager.SubscriptionActive, object: nil)
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        self.children.forEach { child in
            if let restorationIdentifier = child.restorationIdentifier {
                coder.encode(child, forKey: restorationIdentifier)
            }
        }
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        
        if let appsNavigationController = coder.decodeObject(of: [AppsNavigationController.self], forKey: AppsNavigationController.restorationIdentifier) as? AppsNavigationController {
            self.addChild(appsNavigationController)
        }
    }

    override func viewDidLayoutSubviews() {
        self.tabBarItem.title = self.children.first?.title

        switch (self.mainNavigationController, self.appsNavigationController) {
        case (let mainNavigationController?, let appsNavigationController?):
            self.switch(source: mainNavigationController, destination: appsNavigationController)
        default:
            break
        }        
    }
    
    /**
     Prior to calling this method, you must ensure that both `UIViewController` `source` and `destination` are children of `MainController`.
     
     e.g.
        `self.addChild(destination)`
        `try? self.switch(source: source, destination: destination)`
     
     @param source the `UIViewController` to switch from
     @param destination the `UIViewController` to switch to
     @precondition the given `destination` UIViewController must be a child of this container controller
     @return
     */
    func `switch`(source: UIViewController, destination: UIViewController) {
        
        source.willMove(toParent: nil)
        
        destination.view.frame = self.view.bounds
        self.view.addSubview(destination.view)

        source.view.removeFromSuperview()
        source.removeFromParent()
        
        destination.didMove(toParent: self)
    }

    func transition(from: UIViewController, to: UIViewController) {
        from.willMove(toParent: nil)
        self.addChild(to)
        
        self.transition(from: from, to: to, duration: self.transitionCoordinator?.transitionDuration ?? 0.4, options: [], animations: {
            
        }) { (finished) in
            from.removeFromParent()
            to.didMove(toParent: self)
        }
    }
    
    @IBAction func unwindToMainTabBarController(_ segue: UIStoryboardSegue) {}
    
    @IBAction func unwindToSubscriber(_ segue: UIStoryboardSegue) {
        
        if let appsNavigationController = AppsNavigationController.make() {
            transitionAppsNavigationController(appsNavigationController)
        }
    }
    
    func transitionAppsNavigationController(_ to: AppsNavigationController) {
        if let mainNavigationController = self.mainNavigationController {
            self.transition(from: mainNavigationController, to: to)
        }
    }
    
    @IBAction func displayAppsNavigationController() {
        if let appsNavigationController = AppsNavigationController.make() {
            self.displayAppsNavigationController(appsNavigationController)
        }
    }
    
    func displayAppsNavigationController(_ destination: AppsNavigationController) {
        if let mainNavigationController = self.mainNavigationController {
            self.addChild(destination)
            self.switch(source: mainNavigationController, destination: destination)
        }
    }
    
    @objc func subscriptionActive(notification: NSNotification) {
        if let appsNavigationController = AppsNavigationController.make() {
            self.displayAppsNavigationController(appsNavigationController)
        }
    }
}
