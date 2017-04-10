//
//  AppDelegate.swift
//  LoLBookOfChampions-native
//
//  Created by Jeff Roberts on 3/15/17.
//  Copyright (c) 2017 Nimble Noggin Software. All rights reserved.
//

import UIKit
import RxSwift
import SwiftyBeaver

class AppContext {
    var lol: LoLRepo?
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var appContext : AppContext?
    let logger = SwiftyBeaver.self
    var appForegroundDisposeBag = DisposeBag()
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        logger.addDestination(ConsoleDestination())
        logger.info("applicationDidFinishLaunchingWithOptions")

        self.appContext = AppContext()
        self.appContext?.lol = LoLRepo(databasePath: "databases", apiEndpoint: "", apiKey: "")

        self.applicationWillEnterForeground(application)
        return true
    }


    func applicationWillResignActive(_ application: UIApplication) {
        logger.info("applicationWillResignActive")
    }


    func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

    }


    func applicationWillEnterForeground(_ application: UIApplication) {
        logger.info("applicationWillEnterForeground")

        self.appContext?.lol?.start()

        do {
            let _ = try self.appContext?.lol?.create(uri: "/lol/champions/sync", values: ["force": false])
        } catch let error {
            self.logger.error("Boom!: \(error)")
        }

    }


    func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }


    func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }



}
