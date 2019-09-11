//
//  Attributes.swift
//  SwiftNetCDF
//
//  Created by Patrick Zippenfenig on 2019-09-09.
//

import Foundation

public protocol AttributeProvider {
    var varid: Int32 { get } // could be NC_GLOBAL
    var group: Group { get }
    
    /// groups and variables have differnet ways to get the attributes count
    var numberOfAttributes: Int32 { get }
}

extension AttributeProvider {
    public func getAttributes() throws -> [Attribute<Self>] {
        return try (0..<numberOfAttributes).map {
            try getAttribute(try netcdfLock.inq_attname(ncid: group.ncid, varid: varid, attid: $0))!
        }
    }
    
    public func getAttribute(_ key: String) throws -> Attribute<Self>? {
        return try Attribute(fromExistingName: key, parent: self)
    }
    
    /*public func setAttribute(_ name: String, _ value: String) throws {
        try value.withCString {
            try netcdfLock.put_att(ncid: group.ncid, varid: varid, name: name, type: String.netcdfType.rawValue, length: 1, ptr: [$0])
        }
    }*/
    
    public func setAttribute<T: NetcdfConvertible>(_ name: String, _ value: T) throws {
        try T.withPointer(to: value) { type, ptr in
            try setAttributeRaw(name: name, type: type, length: 1, ptr: ptr)
        }
    }
    
    public func setAttribute<T: NetcdfConvertible>(_ name: String, _ value: [T]) throws {
        try T.withPointer(to: value) { type, ptr in
            try setAttributeRaw(name: name, type: type, length: value.count, ptr: ptr)
        }
    }
    
    /// Set a netcdf attribute from raw pointer type
    public func setAttributeRaw(name: String, type: DataType, length: Int, ptr: UnsafeRawPointer) throws {
        try netcdfLock.put_att(ncid: group.ncid, varid: varid, name: name, type: type.typeid, length: length, ptr: ptr)
    }
}

public struct Attribute<Parent: AttributeProvider> {
    let parent: Parent
    let name: String
    let type: DataType
    let length: Int
    
    init?(fromExistingName name: String, parent: Parent) throws {
        do {
            let attinq = try netcdfLock.inq_att(ncid: parent.group.ncid, varid: parent.varid, name: name)
            self.parent = parent
            self.length = attinq.length
            self.type = try DataType(fromTypeId: attinq.typeid, group: parent.group)
            self.name = name
        } catch NetCDFError.attributeNotFound {
            return nil
        }
    }
    
    public func read<T: NetcdfConvertible>() throws -> [T]? {
        return try T.createFromBuffer(length: length, dataType: type, fn: readRaw)
    }
    
    public func read<T: NetcdfConvertible>() throws -> T? {
        return try T.createFromPointer(dataType: type, fn: readRaw)
    }
    
    /// Read the raw into a prepared pointer
    public func readRaw(into buffer: UnsafeMutableRawPointer) throws {
        try netcdfLock.get_att(ncid: parent.group.ncid, varid: parent.varid, name: name, buffer: buffer)
    }
    
    public func to<T: ExternalDataProtocol>(type _: T.Type) -> AttributePrimitiv<T>? {
        guard T.netcdfType.rawValue == self.type.typeid else {
            return nil
        }
        return AttributePrimitiv()
    }
}

/// is this layer usefull?
public struct AttributePrimitiv<T: Primitive> {
    
}
