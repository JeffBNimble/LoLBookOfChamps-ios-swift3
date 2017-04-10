//
// Created by Jeff Roberts on 3/19/17.
// Copyright (c) 2017 Nimble Noggin Software. All rights reserved.
//

import Foundation
import SQLite
import SwiftyBeaver

public class LoLRepo {
    private let apiKey : String
    private let apiEndpoint : String
    fileprivate let database : LoLDatabase

    fileprivate var router : Router?

    init(databasePath : String?, apiEndpoint: String, apiKey : String) {
        self.apiEndpoint = apiEndpoint
        self.apiKey = apiKey
        self.database = LoLDatabase(databasePath: databasePath)
    }

    func start() {
        self.createRouter()
    }

    func stop() {
        self.router = nil
    }
}

// Separate out all of the route building/handling
extension LoLRepo {
    private func buildChampionRoutes(parentSegment: BuildableRoute, withBuilder builder: Router.RouteBuilder) -> BuildableRoute {
        let championsSegment = builder.addSegment(path: "champions", toSegment: parentSegment)

        // GET champions
        championsSegment.add(readHandler: { (projection: Projection?, selection: Selection?, selectionArgs: SelectionArgs?, grouping: Grouping? , having: Having?, sort: Sort?) in
            return ResultSet()
        })

        let namedChampionSegment = builder.addSegment(path: Router.RouteBuilder.createTextVariable(named: LoLDatabase.COLUMN_NAME) , toSegment: championsSegment)
        let idChampionSegment = builder.addSegment(path: Router.RouteBuilder.createNumericVariable(named: LoLDatabase.COLUMN_CHAMPION_ID) , toSegment: championsSegment)

        // GET a champion by name
        namedChampionSegment.add(readHandler: { (projection: Projection?, selection: Selection?, selectionArgs: SelectionArgs?, grouping: Grouping? , having: Having?, sort: Sort?) in
            return ResultSet()
        })

        // GET a champion by id
        idChampionSegment.add(readHandler: { (projection: Projection?, selection: Selection?, selectionArgs: SelectionArgs?, grouping: Grouping? , having: Having?, sort: Sort?) in
            return ResultSet()
        })

        let _ = self.buildChampionSkinsRoutes(parentSegment: namedChampionSegment, withBuilder: builder)
        let _ = self.buildChampionSkinsRoutes(parentSegment: idChampionSegment, withBuilder: builder)

        let syncChampionsSegment = builder.addSegment(path: "sync", toSegment: championsSegment)

        // CREATE champions (which causes a sync from the LoL Api)
        syncChampionsSegment.add(createHandler: { values in
            // See if we have the force parameter
            let force = values?["force"] as? Bool ?? false

            let syncResults = self.sync(force: force)

            return syncResults.authenticationErrors > 0 || syncResults.networkErrors > 0 || syncResults.otherErrors > 0 ? -1 : 1
        })

        return championsSegment
    }

    private func buildChampionSkinsRoutes(parentSegment: BuildableRoute, withBuilder builder: Router.RouteBuilder) -> BuildableRoute {
        let skinsSegment = builder.addSegment(path: "skins", toSegment: parentSegment)

        // GET skins
        skinsSegment.add(readHandler: { (projection: Projection?, selection: Selection?, selectionArgs: SelectionArgs?, grouping: Grouping? , having: Having?, sort: Sort?) in
            print("OMG: \(selectionArgs)")
            return ResultSet()
        })

        let idSkinSegment = builder.addSegment(path: Router.RouteBuilder.createNumericVariable(named: LoLDatabase.COLUMN_CHAMPION_SKIN_ID) , toSegment: skinsSegment)

        // GET skin by id
        idSkinSegment.add(readHandler: { (projection: Projection?, selection: Selection?, selectionArgs: SelectionArgs?, grouping: Grouping? , having: Having?, sort: Sort?) in
            return ResultSet()
        })

        return skinsSegment
    }

    fileprivate func createRouter() {
        let builder = Router.RouteBuilder()
        let lolSegment = builder.addSegment(path: "/lol")
        let _ = self.buildChampionRoutes(parentSegment: lolSegment, withBuilder: builder)

        self.router = builder.build()
    }
}

// Invoke requests against the routes
extension LoLRepo : RouteRequestable {
    public func create(uri : String, values : Values) throws -> ResourceIdentifier {
        let routeInfo = try findRoute(uri: uri)

        guard let handler = routeInfo.route?.createHandler else {
            throw RoutingError.noHandlerFound(message: uri)
        }

        return try handler(values + routeInfo.pathVariables)
    }

    public func delete(uri : String, selection : Selection?, selectionArgs : SelectionArgs?) throws -> DeleteCount {
        let routeInfo = try findRoute(uri: uri)

        guard let handler = routeInfo.route?.deleteHandler else {
            throw RoutingError.noHandlerFound(message: uri)
        }

        let selectionBuilder = mergeSelection(requestSelection: selection, requestSelectionArgs: selectionArgs, routePathVariables: routeInfo.pathVariables)

        return try handler(selectionBuilder?.buildSelection() ?? selection, selectionBuilder?.buildSelectionArgs() ?? selectionArgs)
    }

    private func findRoute(uri: String) throws -> (route: RouteSegment?, pathVariables: [String : Any]?) {
        guard let router = self.router else {
            throw RepoError.repoNotStarted(message: "Are you sure you started the repo?")
        }

        let routeFinder = Router.RouterFinder()

        guard let routeSegment = routeFinder.findRoute(path: uri, inRouter: router) else {
            throw RoutingError.noRouteFound(message: uri)
        }

        return (route: routeSegment, pathVariables: routeFinder.pathVariables)
    }

    private func mergeSelection(requestSelection: Selection?, requestSelectionArgs: SelectionArgs?, routePathVariables: Values?) -> SelectionBuilder? {
        guard let routePathVariables = routePathVariables else {
            return nil
        }

        let selectionBuilder = SelectionBuilder(initialClause: requestSelection, initialArgs: requestSelectionArgs)

        for (key, value) in routePathVariables {
            let _ = selectionBuilder.with(expression: key, equalsValue: value)
        }

        return selectionBuilder
    }

    public func read(uri : String, projection : Projection?, selection : Selection?, selectionArgs : SelectionArgs?, grouping : Grouping?, having : Having?, sort : Sort?) throws -> Results {
        let routeInfo = try findRoute(uri: uri)

        guard let handler = routeInfo.route?.readHandler else {
            throw RoutingError.noHandlerFound(message: uri)
        }

        let selectionBuilder = mergeSelection(requestSelection: selection, requestSelectionArgs: selectionArgs, routePathVariables: routeInfo.pathVariables)

        return try handler(projection,
                selectionBuilder?.buildSelection() ?? selection,
                selectionBuilder?.buildSelectionArgs() ?? selectionArgs,
                grouping,
                having,
                sort)
    }

    public func readSingle(uri : String, projection : Projection?, selection : Selection?, selectionArgs : SelectionArgs?, grouping : Grouping?, having : Having?, sort : Sort?) throws -> Result? {
        return try read(uri: uri, projection: projection, selection: selection, selectionArgs: selectionArgs, grouping: grouping, having: having, sort: sort) as? Result
    }

    public func update(uri : String, selection : Selection?, selectionArgs : SelectionArgs?, values : Values) throws -> UpdateCount {
        let routeInfo = try findRoute(uri: uri)

        guard let handler = routeInfo.route?.updateHandler else {
            throw RoutingError.noHandlerFound(message: uri)
        }

        let selectionBuilder = mergeSelection(requestSelection: selection, requestSelectionArgs: selectionArgs, routePathVariables: routeInfo.pathVariables)

        return try handler(values, selectionBuilder?.buildSelection() ?? selection, selectionBuilder?.buildSelectionArgs() ?? selectionArgs)
    }
}

extension LoLRepo : Syncable {
    public func sync(force : Bool) -> SyncResult {
        print("OMG I'm syncing with force? \(force)")

        return SyncResult()
    }

}

fileprivate class LoLDatabase {
    public static let REALM_VERSION_TABLE = "realm_version"
    public static let CHAMPION_TABLE = "champion"
    public static let CHAMPION_SKIN_TABLE = "champion_skin"
    public static let COLUMN_CHAMPION_ID = "champion_id"
    public static let COLUMN_CHAMPION_SKIN_ID = "skin_id"
    public static let COLUMN_CHAMPION_SKIN_NUMBER = "skin_number"
    public static let COLUMN_BLURB = "blurb"
    public static let COLUMN_ID = "_id"
    public static let COLUMN_IMAGE_URL = "image_url"
    public static let COLUMN_KEY = "key"
    public static let COLUMN_LANDSCAPE_IMAGE_URL = "landscape_image_url"
    public static let COLUMN_NAME = "name"
    public static let COLUMN_PORTRAIT_IMAGE_URL = "portrait_image_url"
    public static let COLUMN_TITLE = "title"
    public static let COLUMN_TYPE = "type"
    public static let COLUMN_VERSION = "version"

    static let DBVersion = 1
    private let openHelper : SQLiteOpenHelper

    init(databasePath: String?) {
        openHelper = LoLDatabaseOpenHelper(databasePath: databasePath, version: LoLDatabase.DBVersion)
    }
}

fileprivate class LoLDatabaseOpenHelper : SQLiteOpenHelper {
    private static let DATABASE_NAME = "datadragon.sqlite3"

    public convenience init(databasePath: String?, version: Int) {
        let dbName : String?

        switch databasePath {
            case .none:
                dbName = nil
            case .some where databasePath?.characters.count == 0:
                dbName = databasePath
            default:
                if let path = databasePath {
                    var prefix = ""
                    var suffix = ""

                    if !path.hasPrefix("/") {
                        prefix = "/"
                    }
                    if !path.hasSuffix("/") {
                        suffix = "/"
                    }

                    let fixedPath = "\(prefix)\(path)\(suffix)"
                    dbName = "\(fixedPath)\(LoLDatabaseOpenHelper.DATABASE_NAME)"
                } else {
                    dbName = nil
                }
        }
        self.init(databaseName: dbName, version: version)
    }

    public required init(databaseName: String?, version: Int) {
        super.init(databaseName: databaseName, version: version)
    }

    private func createChampionTable(_ database: Connection) throws {
        logger.debug("Creating Champion table...")
        var sqlString = "CREATE TABLE " +
                LoLDatabase.CHAMPION_TABLE +
                " (" +
                LoLDatabase.COLUMN_CHAMPION_ID + " INTEGER NOT NULL PRIMARY KEY, " +
                LoLDatabase.COLUMN_NAME + " TEXT NOT NULL, " +
                LoLDatabase.COLUMN_TITLE + " TEXT NOT NULL, " +
                LoLDatabase.COLUMN_BLURB + " TEXT NOT NULL, " +
                LoLDatabase.COLUMN_KEY + " TEXT NOT NULL, " +
                LoLDatabase.COLUMN_IMAGE_URL + " TEXT NOT NULL)"

        try database.run(sqlString)

        sqlString = "CREATE INDEX champion_idx_01 ON " +
                LoLDatabase.CHAMPION_TABLE +
                "(" + LoLDatabase.COLUMN_NAME + ")"

        try database.run(sqlString)
    }

    private func createChampionSkinTable(_ database: Connection) throws {
        logger.debug("Creating Champion Skin table...")
        let sqlString = "CREATE TABLE " +
                LoLDatabase.CHAMPION_SKIN_TABLE +
                " (" +
                LoLDatabase.COLUMN_CHAMPION_SKIN_ID + " INTEGER NOT NULL, " +
                LoLDatabase.COLUMN_CHAMPION_ID + " INTEGER NOT NULL, " +
                LoLDatabase.COLUMN_CHAMPION_SKIN_NUMBER + " INTEGER NOT NULL, " +
                LoLDatabase.COLUMN_NAME + " TEXT NOT NULL, " +
                LoLDatabase.COLUMN_PORTRAIT_IMAGE_URL + " TEXT NOT NULL, " +
                LoLDatabase.COLUMN_LANDSCAPE_IMAGE_URL + " TEXT NOT NULL, " +
                "PRIMARY KEY(" +
                LoLDatabase.COLUMN_CHAMPION_SKIN_ID + "," +
                LoLDatabase.COLUMN_CHAMPION_SKIN_NUMBER + "))"

        try database.run(sqlString)
    }

    private func createRealmVersionTable(_ database: Connection) throws {
        logger.debug("Creating Realm table...")
        let sqlString = "CREATE TABLE " +
                LoLDatabase.REALM_VERSION_TABLE +
                " (" +
                LoLDatabase.COLUMN_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, " +
                LoLDatabase.COLUMN_TYPE + " TEXT UNIQUE NOT NULL, " +
                LoLDatabase.COLUMN_VERSION + " TEXT NOT NULL " +
                ")"

        try database.run(sqlString)

    }

    public override func onConfigure(database: Connection) throws {
        try super.onConfigure(database: database)

        database.trace() { message in
            self.logger.debug(message)
        }

        database.updateHook() { (operation, databaseName, tableName, rowId) in
            self.logger.debug("A(n) \(operation) operation occurred against row \(rowId) in table \(databaseName).\(tableName)")
        }

        database.commitHook() {
            self.logger.debug("A database transaction was committed.")
        }

        database.rollbackHook() {
            self.logger.debug("A database transaction was rolled back.")
        }
    }

    public override func onCreate(database: Connection) throws {
        try super.onCreate(database: database)

        do {
            try self.createRealmVersionTable(database)
            try self.createChampionTable(database)
            try self.createChampionSkinTable(database)
        } catch {
            logger.error("An error occurred creating tables in the LoL database \(error)")
        }
    }
}