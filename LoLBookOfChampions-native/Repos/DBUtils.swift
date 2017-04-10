//
// Created by Jeff Roberts on 3/21/17.
// Copyright (c) 2017 Nimble Noggin Software. All rights reserved.
//

import Foundation
import SQLite
import SwiftyBeaver

public class ResultSet : Results {}

/// A helper for building SQL selections (i.e. the clauses that form the WHERE)
/// When invoking SQL, selections can either use parameter marker syntax (WHERE someColumn = ?)
/// or named parameter syntax (WHERE someColumn = :someColumn)
public class SelectionBuilder {
    public enum GeneratedType {
        case marker
        case named
    }

    private var clauses : [String] = []
    private let type : GeneratedType
    private var parameterValues : [AnyHashable : Any] = [:]

    init(type : GeneratedType = .marker) {
        self.type = type
    }

    convenience init(type : GeneratedType = .marker, initialClause : Selection?, initialArgs : SelectionArgs?) {
        self.init(type: type)

        guard let initialClause = initialClause, let initialArgs = initialArgs as? [AnyHashable : Any] else {
            return
        }

        clauses.append(initialClause)
        parameterValues += initialArgs
    }

    private func add(clause: String) {
        clauses.append(clause)
    }

    func buildSelection() -> String? {
        let selection = clauses.reduce("") { generated, clause in
            return generated.isEmpty ? clause : "\(generated) AND \(clause)"
        }

        return selection.isEmpty ? nil : selection
    }

    func buildSelectionArgs() -> [String : Any]? {
        return self.parameterValues as? [String : Any]
    }

    func buildSelectionArgsList() -> [Any]? {
        guard self.type == GeneratedType.marker else {
            return nil
        }

        return parameterValues.keys
                .sorted() { first, second in
                    guard let first = first as? Int, let second = second as? Int else {
                        return false
                    }

                    return first < second
                }
                .map() { self.parameterValues[$0] as Any }
    }

    private func generateParameterAndPlaceholder(for value: Any) -> String {
        let placeholder : String

        switch self.type {
            case .marker:
                placeholder = "?"
                parameterValues[parameterValues.count] = value

            case .named:
                placeholder = ":value\(parameterValues.count)"
                parameterValues[placeholder.substring(from: placeholder.index(placeholder.startIndex, offsetBy: 1))] = value
        }

        return placeholder
    }

    func with(expression : String, equalsValue value : Any? = nil) -> SelectionBuilder {
        guard let value = value else {
            return self
        }

        add(clause: "(\(expression)=\(generateParameterAndPlaceholder(for: value)))")

        return self
    }
}

/// A base class for managing the lifecycle of a SQLite database
public class SQLiteOpenHelper {
    internal let logger = SwiftyBeaver.self

    public var databaseName : String?
    public var version : Int

    private var databaseConnection : Connection?

    public required init(databaseName: String?, version: Int) {
        self.databaseName = databaseName;
        self.version = version;
    }

    public func close() throws {
        self.databaseConnection = nil
    }

    internal func ensureDatabaseLocation(_ dbLocation : Connection.Location) throws -> Connection.Location {
        switch dbLocation {
            case .uri(let fullPath):
                var pathComponents = fullPath.components(separatedBy: "/").filter() { pathComponent in
                    return !pathComponent.isEmpty
                }

                pathComponents = pathComponents.filter() { pathComponent in
                    return pathComponent != pathComponents.last
                }

                var path = ""
                pathComponents.forEach() { pathComponent in
                    path += "/\(pathComponent)"
                }

                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                fallthrough
            default:
                return dbLocation
        }
    }

    public func getDatabase() throws -> Connection? {
        guard let dbConnection = self.databaseConnection else {
            do {
                let dbLocation : Connection.Location
                if let name = self.databaseName {
                    if name.isEmpty {
                        dbLocation = .temporary
                    } else {
                        dbLocation = .uri(self.asAbsolutePath(relativePath: name))
                    }
                } else {
                    dbLocation = .inMemory
                }

                self.databaseConnection = try Connection(ensureDatabaseLocation(dbLocation), readonly: false)
                try self.prepareDatabase()
            } catch {
                logger.error("Database creation failed with error, \(error)")
                throw error
            }

            return self.databaseConnection
        }

        return dbConnection
    }

    public func onConfigure(database: Connection) throws {
    }

    public func onCreate(database: Connection) throws {
    }

    public func onDowngrade(database: Connection, fromOldVersion oldVersion: Int, toNewVersion newVersion: Int) throws {
    }

    public func onOpen(database: Connection) {
    }

    public func onUpgrade(database: Connection, fromOldVersion oldVersion: Int, toNewVersion newVersion: Int) throws {
    }

    private func prepareDatabase() throws {
        guard let connection = self.databaseConnection else {
            return
        }
        
        do {
            try connection.transaction() {
                self.logger.debug("Configuring SQLite database...")
                try self.onConfigure(database: connection)

                // If the database version is 0, we just created it
                let currentVersion: Int = try self.getCurrentDatabaseVersion()
                if currentVersion <= 0 {
                    self.logger.debug("Creating SQLite database...")
                    try self.onCreate(database: connection)
                }

                // Upgrade or downgrade if necessary
                if currentVersion > 0 {
                    if currentVersion < self.version {
                        self.logger.info("Upgrading SQLite database from V\(currentVersion) to V\(self.version)...")
                        try self.onUpgrade(database: connection, fromOldVersion: currentVersion, toNewVersion: self.version)
                    } else if currentVersion > self.version {
                        self.logger.info("Downgrading SQLite database from V\(currentVersion) to V\(self.version)...")
                        try self.onDowngrade(database: connection, fromOldVersion: currentVersion, toNewVersion: self.version)
                    }
                }

                // If the current and new database versions are different, mark the database version with the new version
                if currentVersion != self.version {
                    try self.setNewDatabaseVersion(version: self.version)
                }

                self.logger.debug("Opening SQLite database...")
                self.onOpen(database: connection)
            }
        } catch {
            self.logger.error("An error occurred attempting to prepare the database")
        }

    }

    private func asAbsolutePath(relativePath:String) -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0];
        let fullPath = "\(documentsPath)\(relativePath)"
        logger.debug("Using SQLite database at '\(fullPath)'")

        return fullPath
    }

    private func getCurrentDatabaseVersion() throws -> Int {
        guard let db = self.databaseConnection else {
            return -1
        }

        guard let version = try db.scalar("PRAGMA user_version") as? Int64 else {
            return -1
        }

        return Int(version)
    }

    private func setNewDatabaseVersion(version:Int) throws {
        guard let db = try self.getDatabase() else {
            return
        }

        let statement = try db.prepare("PRAGMA user_version = \(version)")
        try statement.run()
    }

}