//
//  TSSTPage+CoreDataClass.swift
//  SimpleComic
//
//  Created by C.W. Betts on 10/13/16.
//  Copyright © 2016 Dancing Tortoise Software. All rights reserved.
//

import Cocoa
import CoreData
import UniversalDetector
import XADMaster.XADArchive

private let monospaceCharacterSize: NSSize = {
	let fontAttributes = [NSFontAttributeName: NSFont(name: "Monaco", size: 14)!]
	return "A".boundingRect(with: .zero, options: [], attributes: fontAttributes).size
}()

private let TSSTInfoPageAttributes: [String: Any] = {
	var tabStops = [NSTextTab]()
	/* Loop through the tab stops */
	
	for tabSize in stride(from: CGFloat(8), to: 120, by: 8) {
		let tabLocation = tabSize * monospaceCharacterSize.width
		let tabStop = NSTextTab(textAlignment: .left, location: tabLocation, options: [:])
		tabStops.append(tabStop)
	}
	
	var style = NSParagraphStyle.default().mutableCopy() as! NSMutableParagraphStyle
	style.tabStops = tabStops

	return [NSFontAttributeName: NSFont(name: "Monaco", size: 14)!,
		NSParagraphStyleAttributeName: style.copy()]
}()

@objc(TSSTPage)
public class TSSTPage: NSManagedObject {
	private var thumbLock: NSLock? = nil
	private var loaderLock: NSLock? = nil

	static let imageTypes: [String] = {
		var imgTypes = NSImage.imageTypes()
		var remIdx = IndexSet()
		if let anIdx = imgTypes.index(of: kUTTypePDF as String) {
			remIdx.insert(anIdx)
		}
		
		if let anIdx = imgTypes.index(of: "com.adobe.encapsulated-postscript") {
			remIdx.insert(anIdx)
		}
		
		for anIdx in remIdx.reversed() {
			imgTypes.remove(at: anIdx)
		}
		
		return imgTypes
	}()
	
	static let imageExtensions: [String] = {
		var aImageTypes = Set<String>(minimumCapacity: imageTypes.count * 2)
		for uti in imageTypes {
			if let fileExts = UTTypeCopyAllTagsWithClass(uti as NSString, kUTTagClassFilenameExtension)?.takeRetainedValue() as NSArray? as? [String] {
				aImageTypes.formUnion(fileExts)
			}
		}
		
		return Array(aImageTypes)
	}()

	static let textExtensions: [String] = ["txt", "nfo", "info"]
	
	var name: String {
		return (imagePath! as NSString).lastPathComponent
	}
	
	var shouldDisplayAlone: Bool {
		if text?.boolValue ?? false {
			return true
		}
		
		let defaultAspect: CGFloat = 1
		var aspect: CGFloat = aspectRatio as CGFloat? ?? 0
		if aspect == 0 {
			let imageData = pageData!
			setOwnSizeInfo(with: imageData)
			aspect = aspectRatio as CGFloat? ?? 0
		}
		
		return aspect != 0 ? aspect > defaultAspect : true;
	}
	
	private func setOwnSizeInfo(with data: Data) {
		guard let pageRep = NSBitmapImageRep(data: data) else {
			return
		}
		
		let imageSize = NSSize(width: pageRep.pixelsWide, height: pageRep.pixelsHigh)
		
		guard imageSize != .zero else {
			return
		}
		let aspect = imageSize.width / imageSize.height
		width = imageSize.width as NSNumber
		height = imageSize.height as NSNumber
		aspectRatio = aspect as NSNumber
	}
	
	var thumbnail: NSImage? {
		var thumbnail: NSImage?
		if let thumbnailData = self.thumbnailData as Data? {
			thumbnail = NSImage(data: thumbnailData)
		} else if let thumbData = prepThumbnail() {
			self.thumbnailData = thumbData as NSData
			thumbnail = NSImage(data: thumbData)
		}
		
		return thumbnail
	}
	
	func prepThumbnail() -> Data? {
		thumbLock?.lock()
		let managedImage = pageImage
		var thumbData: Data? = nil
		var pixelSize: NSSize = managedImage?.size ?? .zero
		if let managedImage = managedImage {
			pixelSize = constrainSize(pixelSize, byDimension: 256)
			let temp = NSImage(size: pixelSize)
			temp.lockFocus()
			NSGraphicsContext.current()?.imageInterpolation = .high
			managedImage.draw(in: NSRect(origin: .zero, size: pixelSize), from: .zero, operation: .sourceOver, fraction: 1)
			temp.unlockFocus()
			thumbData = temp.tiffRepresentation
		}
		thumbLock?.unlock()

		return thumbData
	}

	public override func awakeFromInsert() {
		super.awakeFromInsert()
		thumbLock = NSLock()
		loaderLock = NSLock()
	}
	
	
	public override func awakeFromFetch() {
		super.awakeFromFetch()
		thumbLock = NSLock()
		loaderLock = NSLock()
	}

	public override func didTurnIntoFault() {
		loaderLock = nil
		thumbLock = nil
	}
	
	var pageData: Data? {
		var imageData: Data? = nil
		let group = self.group
		if let entryIndex = index?.intValue {
			imageData = group?.data(forPageIndex: entryIndex)
		} else if let imgPath = imagePath {
			imageData = try? Data(contentsOf: URL(fileURLWithPath: imgPath))
		}
		
		return imageData
	}
	
	var textPage: NSImage {
		let textData: Data = {
			var txtDat: Data? = nil
			if let idx = index?.intValue {
				txtDat = group?.data(forPageIndex: idx)
			} else if let imgPath = imagePath {
				txtDat = try? Data(contentsOf: URL(fileURLWithPath: imgPath))
			}
			return txtDat!
		}()
		
		let encodingDetector = UniversalDetector()
		encodingDetector.analyze(textData)
		guard let text = String(data: textData, encoding: String.Encoding(rawValue: encodingDetector.encoding)) else {
			return NSImage()
		}
		var pageRect = NSRect.zero
		var aindex = text.startIndex
		let textLength = text.endIndex
		while aindex < textLength {
			let bRange: Range<String.Index> = aindex ..< text.index(after: aindex)
			let lineRange = text.lineRange(for: bRange)
			aindex = lineRange.upperBound
			let singleLine = text[lineRange]
			let lineRect = (singleLine as NSString).boundingRect(with: NSSize(width: 800, height: 800), options: .usesLineFragmentOrigin, attributes: TSSTInfoPageAttributes)
			if lineRect.width > pageRect.width {
				pageRect.size.width = lineRect.size.width
			}
			pageRect.size.height += lineRect.height - 19
		}
		
		pageRect.size.width += 10;
		pageRect.size.height += 10;
		pageRect.size.height = max(pageRect.height, 500)
		
		let textImage = NSImage(size: pageRect.size)
		
		textImage.lockFocus()
		NSColor.white.set()
		NSRectFill(pageRect)
		(text as NSString).draw(with: pageRect.insetBy(dx: 5, dy: 5), options: .usesLineFragmentOrigin, attributes: TSSTInfoPageAttributes)
		textImage.unlockFocus()
		
		return textImage
	}
	
	var pageImage: NSImage? {
		if self.text?.boolValue ?? false {
			return textPage
		}
		
		var imageFromData: NSImage?
		let imageData = pageData
		
		if let imageData = imageData {
			setOwnSizeInfo(with: imageData)
			imageFromData = NSImage(data: imageData)
		}
		
		let imageSize = NSSize(width: self.width as? CGFloat ?? 0, height: self.height as? CGFloat ?? 0)
		
		if imageFromData == nil || imageSize == .zero {
			imageFromData = nil
		} else {
			imageFromData!.cacheMode = .never
			
			imageFromData!.size = imageSize
			imageFromData?.cacheMode = .bySize
		}
		
		
		return imageFromData
	}
}
