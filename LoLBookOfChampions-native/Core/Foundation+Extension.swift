//
// Created by Jeff Roberts on 4/9/17.
// Copyright (c) 2017 Nimble Noggin Software. All rights reserved.
//

import Foundation

/// Convenience function to add values from one Dictionary to another
public func += <K, V>(lhs : inout [K:V], rhs : [K:V]?) {
    guard let rhs = rhs else {
        return
    }

    for (key, value) in rhs {
        lhs.updateValue(value, forKey: key)
    }
}

/// Convenience function to add two optional Dictionaries together and return a new Dictionary containing values from both
public func + <K, V>(lhs : [K:V]?, rhs : [K:V]?) -> [K:V]? {
    guard lhs != nil || rhs != nil else {
        return nil
    }

    guard lhs != nil else {
        return rhs
    }

    guard rhs != nil else {
        return lhs
    }

    var merged : [K:V] = [:]

    merged += lhs
    merged += rhs

    return merged
}