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

    public class Builder {
        private var inserts = 0
        private var updates = 0
        private var deletes = 0
        private var authenticationErrors = 0
        private var networkErrors = 0
        private var otherErrors = 0

        func inserts(_ value : Int) -> Builder {
            self.inserts = self.inserts + value
            return self
        }

        func updates(_ value : Int) -> Builder {
            self.updates = self.updates + value
            return self
        }

        func deletes(_ value : Int) -> Builder {
            self.deletes = self.deletes + value
            return self
        }

        func authenticationErrors(_ value : Int) -> Builder {
            self.authenticationErrors = self.authenticationErrors + value
            return self
        }

        func networkErrors(_ value : Int) -> Builder {
            self.networkErrors = self.networkErrors + value
            return self
        }

        func otherErrors(_ value : Int) -> Builder {
            self.otherErrors = self.otherErrors + value
            return self
        }

        func build() -> SyncResult {
            return SyncResult(inserts: self.inserts,
                    updates: self.updates,
                    deletes: self.deletes,
                    authenticationErrors: self.authenticationErrors,
                    networkErrors: self.networkErrors,
                    otherErrors: self.otherErrors)
        }
    }
}

public protocol Syncable {
    func sync(force : Bool) -> SyncResult
}

public enum RepoError : Error {
    case repoNotStarted(message : String)
}

public enum ApiError : Error {
    case badUrl(message : String)
}