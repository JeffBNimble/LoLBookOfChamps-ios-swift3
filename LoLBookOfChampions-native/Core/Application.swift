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

let backgroundDispatchQueue = DispatchQueue(label: "com.nimbleNogginSoftware.LoLBookOfChampions-background")
let concurrentBackgroundScheduler = ConcurrentDispatchQueueScheduler(queue: backgroundDispatchQueue)

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

        let httpDriver = HttpDriver(urlSession: URLSession(configuration: URLSessionConfiguration.default))
        self.appContext?.lol = LoLRepo(databasePath: "databases",
                http: httpDriver,
                apiEndpoint: "https://na1.api.riotgames.com",
                apiKey: "949cc35d-47fd-448d-b450-3ff6c9cfe360",
                scheduler: concurrentBackgroundScheduler)

        self.applicationWillEnterForeground(application)
        return true
    }


    func applicationWillResignActive(_ application: UIApplication) {
        logger.info("applicationWillResignActive")

        self.appForegroundDisposeBag = DisposeBag()
    }


    func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

    }


    func applicationWillEnterForeground(_ application: UIApplication) {
        logger.info("applicationWillEnterForeground")

        self.appForegroundedObservable()
            .observeOn(concurrentBackgroundScheduler)
            .subscribeOn(MainScheduler.instance)
            .subscribe(onNext: {
                self.logger.info("appForegroundedObservable subscribed!")
            }, onError: { error in
                self.logger.error("An error occurred attempting to sync data from the remote Riot Api, err=\(error)")
            }, onDisposed: {
                self.appContext?.lol?.stop()
            })
        .addDisposableTo(self.appForegroundDisposeBag)
    }


    func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }


    func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

private extension AppDelegate {
    func appForegroundedObservable() -> Observable<Void> {
        return Observable.create() { observer in
            self.appContext?.lol?.start()

            do {
                let _ = try self.appContext?.lol?.create(uri: "/lol/champions/sync")
            } catch let error {
                observer.onError(error)
            }

            return Disposables.create()
        }
    }
}
