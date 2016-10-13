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
				aImageTypes.formIntersection(fileExts)
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
	
	func prepThumbnail() -> Data? {
		thumbLock?.lock()
		
		/*
[thumbLock lock];
NSImage * managedImage = [self pageImage];
NSData * thumbnailData = nil;
NSSize pixelSize = [managedImage size];
if(managedImage)
{
pixelSize = sizeConstrainedByDimension(pixelSize, 256);
NSImage * temp = [[NSImage alloc] initWithSize: pixelSize];
[temp lockFocus];
[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
[managedImage drawInRect: NSMakeRect(0, 0, pixelSize.width, pixelSize.height)
fromRect: NSZeroRect
operation: NSCompositeSourceOver
fraction: 1.0];
[temp unlockFocus];
thumbnailData = [temp TIFFRepresentation];
}
[thumbLock unlock];

return thumbnailData;
*/

		return nil
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

/*
open class var imageTypes: [String] { get }

open class var imageExtensions: [String] { get }

open class var textExtensions: [String] { get }


open var name: String { get }

//- (NSString *)deconflictionName;

open var shouldDisplayAlone: Bool { get }

open func setOwnSizeInfoWith(_ imageData: Data)

@NSCopying open var thumbnail: NSImage { get }

open func prepThumbnail() -> Data?

@NSCopying open var textPage: NSImage { get }

@NSCopying open var pageImage: NSImage { get }
*/
	
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
		let text = String(data: textData, encoding: String.Encoding(rawValue: encodingDetector.encoding))
	}
	
	/*
	
	- (NSImage *)textPage
	{
	NSData * textData;
	if([self valueForKey: @"index"])
	{
	textData = [[self valueForKeyPath: @"group"] dataForPageIndex: [[self valueForKey: @"index"] integerValue]];
	}
	else
	{
	textData = [NSData dataWithContentsOfFile: [self valueForKey: @"imagePath"]];
	}
	
	UniversalDetector * encodingDetector = [UniversalDetector detector];
	[encodingDetector analyzeData: textData];
	NSString * text = [[NSString alloc] initWithData: textData encoding: [encodingDetector encoding]];
	//	int lineCount = 0;
	NSRect lineRect;
	NSRect pageRect = NSZeroRect;
	
	NSUInteger index = 0;
	NSUInteger textLength = [text length];
	NSRange lineRange;
	NSString * singleLine;
	while(index < textLength)
	{
	lineRange = [text lineRangeForRange: NSMakeRange(index, 0)];
	index = NSMaxRange(lineRange);
	singleLine = [text substringWithRange: lineRange];
	lineRect = [singleLine boundingRectWithSize: NSMakeSize(800, 800) options: NSStringDrawingUsesLineFragmentOrigin attributes: TSSTInfoPageAttributes];
	if(NSWidth(lineRect) > NSWidth(pageRect))
	{
	pageRect.size.width = lineRect.size.width;
	}
	
	pageRect.size.height += (NSHeight(lineRect) - 19);
	
	}
	pageRect.size.width += 10;
	pageRect.size.height += 10;
	pageRect.size.height = NSHeight(pageRect) < 500 ? 500 : NSHeight(pageRect);
	
	NSImage * textImage = [[NSImage alloc] initWithSize: pageRect.size];
	
	[textImage lockFocus];
	[[NSColor whiteColor] set];
	NSRectFill(pageRect);
	[text drawWithRect: NSInsetRect( pageRect, 5, 5) options: NSStringDrawingUsesLineFragmentOrigin attributes: TSSTInfoPageAttributes];
	[textImage unlockFocus];
	
	return textImage;
	}

	
- (NSImage *)pageImage
{
if([[self valueForKey: @"text"] boolValue])
{
return [self textPage];
}

NSImage * imageFromData = nil;
NSData * imageData = [self pageData];

if(imageData)
{
[self setOwnSizeInfoWithData: imageData];
imageFromData = [[NSImage alloc] initWithData: imageData];
}

NSSize imageSize =  NSMakeSize([[self valueForKey: @"width"] doubleValue], [[self valueForKey: @"height"] doubleValue]);

if(!imageFromData || NSEqualSizes(NSZeroSize, imageSize))
{
imageFromData = nil;
}
else
{
[imageFromData setCacheMode: NSImageCacheNever];

[imageFromData setSize: imageSize];
[imageFromData setCacheMode: NSImageCacheBySize];
}

return imageFromData;
}
*/
}
