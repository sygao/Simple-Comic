//
//  TSSTPage+CoreDataProperties.swift
//  SimpleComic
//
//  Created by C.W. Betts on 10/13/16.
//  Copyright © 2016 Dancing Tortoise Software. All rights reserved.
//

import Cocoa
import CoreData


extension TSSTPage {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TSSTPage> {
        return NSFetchRequest<TSSTPage>(entityName: "Image");
    }

    @NSManaged public var aspectRatio: NSNumber?
    @NSManaged public var height: NSNumber?
    @NSManaged public var imagePath: String?
    @NSManaged public var index: NSNumber?
    @NSManaged public var text: NSNumber?
    @NSManaged public var thumbnailData: NSData?
    @NSManaged public var width: NSNumber?
    @NSManaged public var group: TSSTManagedGroup?
    @NSManaged public var session: TSSTManagedSession?

}
