//
// Created by Jeff Roberts on 3/28/17.
// Copyright (c) 2017 Nimble Noggin Software. All rights reserved.
//

import Foundation

public typealias CreateHandler = (Values?) throws -> ResourceIdentifier
public typealias DeleteHandler = (Selection?, SelectionArgs?) throws -> DeleteCount
public typealias ReadHandler = (Projection?, Selection?, SelectionArgs?, Grouping?, Having?, Sort?) throws -> Results
public typealias UpdateHandler = (Values, Selection?, SelectionArgs?) throws -> UpdateCount

public class Router {
    fileprivate var routes : [RouteSegment]

    init(routes : [RouteSegment]) {
        self.routes = routes
    }
}

extension Router {
    public class RouteBuilder {
        public static func createTextVariable(named variableName: String) -> String {
            return "{\(variableName):*}"
        }

        public static func createNumericVariable(named variableName: String) -> String {
            return "{\(variableName):#}"
        }

        private var segments : [BuildableRoute] = []

        func addSegment(path: String, toSegment segment: BuildableRoute? = nil) -> BuildableRoute {
            var pathComponents = path.components(separatedBy: "/")
            let createSegment : ((String, BuildableRoute?) -> BuildableRoute) = { (path : String, parentSegment : BuildableRoute?) in
                let newSegment = RouteSegment(pathComponent: path)

                guard let parentSegment = parentSegment else {
                    self.segments.append(newSegment)
                    return newSegment
                }

                let _ = parentSegment.add(segment: newSegment)
                return newSegment
            }

            if pathComponents.count > 0 && pathComponents[0].isEmpty {
                pathComponents.removeFirst()
            }

            guard pathComponents.count > 1 else {
                return createSegment(pathComponents[0], segment)
            }

            let newSegment = createSegment(pathComponents.removeFirst(), segment)
            return self.addSegment(path: pathComponents.joined(separator: "/"), toSegment: newSegment)
        }

        func build() -> Router {
            return Router(routes: self.segments.map() { segment in
                return segment.asRouteSegment()
            })
        }
    }
}

extension Router {
    public class RouterFinder {
        private(set) var pathVariables : [String : Any]?

        private func containsNumericVariable(path: String) -> Bool {
            return !execRegex(pattern: "^(\\{[a-zA-Z0-9_-]*\\:\\#\\})$", on: path).isEmpty
        }

        private func containsTextVariable(path: String) -> Bool {
            return !execRegex(pattern: "^(\\{[a-zA-Z0-9_-]*\\:\\*\\})$", on: path).isEmpty
        }

        private func execRegex(pattern: String, on text: String) -> [String] {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let nsString = text as NSString
                let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
                return results.map { nsString.substring(with: $0.range)}
            } catch let error {
                print("invalid regex: \(error.localizedDescription)")
                return []
            }
        }

        private func extract(pathVariable: String, fromSegment segment: RouteSegment, into pathVariables: inout [String : Any]) {
            if containsTextVariable(path: segment.pathComponent) {
                extract(textVariable: pathVariable, fromPath: segment.pathComponent, into: &pathVariables)
            } else if containsNumericVariable(path: segment.pathComponent) {
                extract(numericVariable: Int64(pathVariable), fromPath: segment.pathComponent, into: &pathVariables)
            }
        }

        private func extract(numericVariable value: Int64?, fromPath path: String, into pathVariables: inout [String : Any]) {
            guard let value = value, let variableName = extractVariableName(fromPathVariable: path) else {
                return
            }

            pathVariables[variableName] = value
        }

        private func extract(textVariable value: String, fromPath path: String, into pathVariables: inout [String : Any]) {
            guard let variableName = extractVariableName(fromPathVariable: path) else {
                return
            }

            pathVariables[variableName] = value
        }

        private func extractVariableName(fromPathVariable pathVariable: String) -> String? {
            let matches = execRegex(pattern: "[^\\{\\}]*", on: pathVariable)

            guard let variable = matches.filter({ !$0.isEmpty }).first else {
                return nil
            }

            return variable.components(separatedBy: ":").first
        }

        func findRoute(path: String, inRouter router: Router) -> RouteSegment? {
            var variables : [String : Any] = [:]
            var pathComponents = path.components(separatedBy: "/")
            var segments = router.routes

            // If a path begins with /, the first component is an empty string
            if pathComponents.count > 0 && pathComponents[0].isEmpty {
                pathComponents.removeFirst()
            }

            var lastPathSegment : RouteSegment?

            for pathComponent in pathComponents {
                guard let segment = getSegment(matching: pathComponent, inRoutes: segments) else {
                    self.pathVariables = nil
                    return nil
                }

                extract(pathVariable: pathComponent, fromSegment: segment, into: &variables)

                lastPathSegment = segment
                segments = segment.segments.map() { $0.asRouteSegment() }
            }

            self.pathVariables = variables

            return lastPathSegment
        }

        private func getSegment(matching path: String, inRoutes routes: [RouteSegment]) -> RouteSegment? {
            let matches = routes
                    .filter() { segment in
                        let pathComponent = segment.pathComponent
                        return pathComponent == path ||
                                (containsTextVariable(path: pathComponent) && Int64(path) == nil) ||
                                (containsNumericVariable(path: pathComponent) && Int64(path) != nil)
                    }

            // If I have multiple matches, it's because I have an exact path match and a path variable match
            // In this case, take the exact path match over the variable match
            return matches.filter() { $0.pathComponent == path }.first ?? matches.first
        }

    }
}

public class RouteSegment {
    let pathComponent : String
    var createHandler : CreateHandler?
    var deleteHandler : DeleteHandler?
    var readHandler : ReadHandler?
    var updateHandler : UpdateHandler?
    var segments : [BuildableRoute] = []

    init(pathComponent: String) {
        self.pathComponent = pathComponent
    }
}

extension RouteSegment : BuildableRoute {
    public func add(createHandler: @escaping CreateHandler) {
        self.createHandler = createHandler
    }

    public func add(deleteHandler : @escaping DeleteHandler) {
        self.deleteHandler = deleteHandler
    }

    public func add(readHandler : @escaping ReadHandler) {
        self.readHandler = readHandler
    }

    public func add(updateHandler : @escaping UpdateHandler) {
        self.updateHandler = updateHandler
    }

    public func add(segment : BuildableRoute) -> BuildableRoute {
        self.segments.append(segment)
        return segment
    }

    public func asRouteSegment() -> RouteSegment {
        return self as RouteSegment
    }
}

public protocol BuildableRoute {
    func add(createHandler : @escaping CreateHandler)
    func add(deleteHandler : @escaping DeleteHandler)
    func add(readHandler : @escaping ReadHandler)
    func add(updateHandler : @escaping UpdateHandler)
    func add(segment: BuildableRoute) -> BuildableRoute
    func asRouteSegment() -> RouteSegment
}

public protocol RouteRequestable {
    func create(uri : String, values : Values?) throws -> ResourceIdentifier
    func delete(uri : String, selection : Selection?, selectionArgs : SelectionArgs?) throws -> DeleteCount
    func read(uri : String, projection : Projection?, selection : Selection?, selectionArgs : SelectionArgs?, grouping : Grouping?, having : Having?, sort : Sort?) throws -> Results
    func readSingle(uri: String, projection : Projection?, selection : Selection?, selectionArgs : SelectionArgs?, grouping : Grouping?, having : Having?, sort : Sort?) throws -> Result?
    func update(uri: String, selection : Selection?, selectionArgs : SelectionArgs?, values : Values) throws -> UpdateCount
}

public enum RoutingError : Error {
    case noRouteFound(message : String)
    case noHandlerFound(message : String)
}

