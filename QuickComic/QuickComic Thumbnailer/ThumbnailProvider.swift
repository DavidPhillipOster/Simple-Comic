//
//  ThumbnailProvider.swift
//  QuickComic Thumbnailer
//
//  Created by C.W. Betts on 12/15/22.
//  Copyright © 2022 Dancing Tortoise Software. All rights reserved.
//

import QuickLookThumbnailing
import XADMaster

class ThumbnailProvider: QLThumbnailProvider {
    
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
		do {
			let archiveURL = request.fileURL
			let archivePath = archiveURL.path
			let coverName = (try? UKXattrMetadataStore.string(forKey: SCQuickLookCoverName, atPath: archivePath, traverseLink: false)) ?? ""
			let coverRectString = (try? UKXattrMetadataStore.string(forKey: SCQuickLookCoverRect, atPath: archivePath, traverseLink: false)) ?? ""
			
			var imageData: Data? = nil
			var cropRect = CGRect.zero
			if !coverName.isEmpty {
				let partialArchive = try PartialArchiveParser(with: archiveURL, searchString: coverName)
				if coverRectString != "" {
					cropRect = NSRectFromString(coverRectString)
				}
				imageData = partialArchive.searchResult
			} else {
				let archive = try XADArchive(fileURL: archiveURL, delegate: nil)
				let fileList = fileList(for: archive)
				if fileList.count > 0 {
					let list2 = (fileList as NSArray).sortedArray(using: fileSort) as! [[String : Any]]
					
					// Nope! Not doing this!
					// coverName = [fileList.firstObject valueForKey: @"rawName"];
					// [UKXattrMetadataStore setString: coverName forKey: SCQuickLookCoverName atPath: archivePath traverseLink: NO error: nil];
					let coverIndex = list2.first!["index"] as! Int
					imageData = try archive.contents(ofEntry: coverIndex)
				}
			}
			
			guard let imageData, let image = NSImage(data: imageData) else {
				throw CocoaError(.fileReadCorruptFile, userInfo: [NSURLErrorKey: archiveURL])
			}
			
			var imageSize = cropRect.isEmpty ? image.size : cropRect.size
			imageSize = constrainSize(imageSize, dimension: request.maximumSize.height)
			
			let reply = QLThumbnailReply(contextSize: imageSize, currentContextDrawing: { () -> Bool in

				var canvasRect: CGRect = .zero
				var drawRect: CGRect = .zero

				if cropRect.isEmpty {
					// no crop
					canvasRect = NSRect(origin: .zero, size: imageSize)
					drawRect = NSRect(origin: .zero, size: fitSize(imageSize, in: image.size))
				} else {
					// crop
					canvasRect.size = fitSize(imageSize, in: cropRect.size)
					let vertScale = canvasRect.size.height / image.size.height
					let horScale = canvasRect.size.width / image.size.width
					drawRect.origin = CGPoint(x: -(cropRect.origin.x), y: -(cropRect.origin.y))
					drawRect.size = CGSize(width: cropRect.size.width / horScale, height: cropRect.size.height / vertScale)
					canvasRect.size = imageSize
				}
				
				image.draw(in: canvasRect, from: drawRect, operation: .copy, fraction: 1)
				
				return true
			})
			
			handler(reply, nil)
		} catch {
			handler(nil, error)
		}
    }
}
