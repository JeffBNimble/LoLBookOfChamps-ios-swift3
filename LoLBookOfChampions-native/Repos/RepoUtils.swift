//
// Created by Jeff Roberts on 3/19/17.
// Copyright (c) 2017 Nimble Noggin Software. All rights reserved.
//

import Foundation

public typealias DeleteCount = Int
public typealias Grouping = String
public typealias Having = String
public typealias Projection = [String]
public typealias ResourceIdentifier = Int64
public typealias ResourceNotifier = ((ResourcePath) -> ())
public typealias ResourcePath = String
public typealias Selection = String
public typealias SelectionArgs = [String : Any]
public typealias Sort = String
public typealias UpdateCount = Int
public typealias Values = [String : Any]

public protocol ResourceNotifiable {
    func register(path : ResourcePath, notifier : ResourceNotifier)
    func unregister(path : ResourcePath, notifier : ResourceNotifier)
}

public protocol ResourceRoutable {
    func delete(path : ResourcePath, selection : Selection?, selectionArgs : SelectionArgs?) throws -> DeleteCount
    func get(path : ResourcePath, projection : Projection?, selection : Selection?, selectionArgs : SelectionArgs?, grouping : Grouping?, having : Having?, sort : Sort?) throws -> Results
    func getSingle(path : ResourcePath, projection : Projection?, selection : Selection?, selectionArgs : SelectionArgs?, grouping : Grouping?, having : Having?) throws -> Result
    func post(path : ResourcePath, values : Values) throws -> ResourceIdentifier
    func put(path : ResourcePath, values : Values, selection : Selection?, selectionArgs : SelectionArgs?) throws -> UpdateCount
}

public protocol Result {

}

public protocol Results : Result {

}

public struct SyncResult {
    var inserts = 0
    var updates = 0
    var deletes = 0
    var authenticationErrors = 0
    var networkErrors = 0
    var otherErrors = 0
}

public protocol Syncable {
    func sync(force : Bool) -> SyncResult
}

public enum RepoError : Error {
    case repoNotStarted(message : String)
}