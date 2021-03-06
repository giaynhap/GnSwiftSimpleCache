 
import UIKit
import Foundation

public enum ImageFormat {
    case unknown, png, jpeg
}

open class SwiftSimpleCache {
    static let cacheDirectoryPrefix = "ai.techlab.cache."
    static let ioQueuePrefix = "ai.techlab.queue."
    static let defaultMaxCachePeriodInSecond: TimeInterval = 60 * 60 * 24 * 7
    public static let instance = SwiftSimpleCache(name: "default")
    
    let cachePath: String 
    let memCache = NSCache<AnyObject, AnyObject>()
    let ioQueue: DispatchQueue
    let fileManager: FileManager
    open var name: String = ""
    open var maxCachePeriodInSecond = SwiftSimpleCache.defaultMaxCachePeriodInSecond
    open var maxDiskCacheSize: UInt = 0
    public init(name: String, path: String? = nil) {
        self.name = name
        
        var cachePath = path ?? NSSearchPathForDirectoriesInDomains(.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first!
        cachePath = (cachePath as NSString).appendingPathComponent(SwiftSimpleCache.cacheDirectoryPrefix + name)
        self.cachePath = cachePath
        
        ioQueue = DispatchQueue(label: SwiftSimpleCache.ioQueuePrefix + name)
        
        self.fileManager = FileManager()
        
        #if !os(OSX) && !os(watchOS)
            NotificationCenter.default.addObserver(self, selector: #selector(cleanExpiredDiskCache), name: UIApplication.willTerminateNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(cleanExpiredDiskCache), name: UIApplication.didEnterBackgroundNotification, object: nil)
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
 
    public func write(data: Data, forKey key: String) {
        memCache.setObject(data as AnyObject, forKey: key as AnyObject)
        writeDataToDisk(data: data, key: key)
    }
    
    private func writeDataToDisk(data: Data, key: String) {
        ioQueue.async {
            if self.fileManager.fileExists(atPath: self.cachePath) == false {
                do {
                    try self.fileManager.createDirectory(atPath: self.cachePath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("DataCache: Error while creating cache folder: \(error.localizedDescription)")
                }
            }
            
            self.fileManager.createFile(atPath: self.cachePath(forKey: key), contents: data, attributes: nil)
        }
    }
     
    public func readData(forKey key:String) -> Data? {
        var data = memCache.object(forKey: key as AnyObject) as? Data
        
        if data == nil {
            if let dataFromDisk = readDataFromDisk(forKey: key) {
                data = dataFromDisk
                memCache.setObject(dataFromDisk as AnyObject, forKey: key as AnyObject)
            }
        }
        
        return data
    }
     
    public func readDataFromDisk(forKey key: String) -> Data? {
        return self.fileManager.contents(atPath: cachePath(forKey: key))
    }
     
    public func write<T: Encodable>(codable: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(codable)
        write(data: data, forKey: key)
    }
    
    public func readCodable<T: Decodable>(forKey key: String) throws -> T? {
        guard let data = readData(forKey: key) else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
     
    public func write(object: NSCoding, forKey key: String) {
        let data = NSKeyedArchiver.archivedData(withRootObject: object)
        write(data: data, forKey: key)
    }
  
    public func write(string: String, forKey key: String) {
        write(object: string as NSCoding, forKey: key)
    }
     
    public func write(dictionary: Dictionary<AnyHashable, Any>, forKey key: String) {
        write(object: dictionary as NSCoding, forKey: key)
    }
  
    public func write(array: Array<Any>, forKey key: String) {
        write(object: array as NSCoding, forKey: key)
    }
     
    public func readObject(forKey key: String) -> NSObject? {
        let data = readData(forKey: key)
        
        if let data = data {
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? NSObject
        }
        
        return nil
    }
     
    public func readString(forKey key: String) -> String? {
        return readObject(forKey: key) as? String
    }
     
    public func readArray(forKey key: String) -> Array<Any>? {
        return readObject(forKey: key) as? Array<Any>
    }
     
    public func readDictionary(forKey key: String) -> Dictionary<AnyHashable, Any>? {
        return readObject(forKey: key) as? Dictionary<AnyHashable, Any>
    }
     
    public func write(image: UIImage, forKey key: String, format: ImageFormat? = nil) {
        var data: Data? = nil
        
        if let format = format, format == .png {
            data = image.pngData()
        }
        else {
            data = image.jpegData(compressionQuality: 0.9)
        }
        
        if let data = data {
            write(data: data, forKey: key)
        }
    }
    
 
    public func readImageForKey(key: String) -> UIImage? {
        let data = readData(forKey: key)
        if let data = data {
            return UIImage(data: data, scale: 1.0)
        }
        
        return nil
    }
}
 
extension SwiftSimpleCache {
    public func hasData(forKey key: String) -> Bool {
        return hasDataOnDisk(forKey: key) || hasDataOnMem(forKey: key)
    }
     
    public func hasDataOnDisk(forKey key: String) -> Bool {
        return self.fileManager.fileExists(atPath: self.cachePath(forKey: key))
    }
     
    public func hasDataOnMem(forKey key: String) -> Bool {
        return (memCache.object(forKey: key as AnyObject) != nil)
    }
}
 
extension SwiftSimpleCache {
     
    public func cleanAll() {
        cleanMemCache()
        cleanDiskCache()
    }
     
    public func clean(byKey key: String) {
        memCache.removeObject(forKey: key as AnyObject)
        
        ioQueue.async {
            do {
                try self.fileManager.removeItem(atPath: self.cachePath(forKey: key))
            } catch {
                print("DataCache: Error while remove file: \(error.localizedDescription)")
            }
        }
    }
    
    public func cleanMemCache() {
        memCache.removeAllObjects()
    }
    
    public func cleanDiskCache() {
        ioQueue.async {
            do {
                try self.fileManager.removeItem(atPath: self.cachePath)
            } catch {
                print("DataCache: Error when clean disk: \(error.localizedDescription)")
            }
        }
    }
     
    @objc public func cleanExpiredDiskCache() {
        cleanExpiredDiskCache(completion: nil)
    }
     
    open func cleanExpiredDiskCache(completion handler: (()->())? = nil) {
    
        ioQueue.async {
            
            var (URLsToDelete, diskCacheSize, cachedFiles) = self.travelCachedFiles(onlyForCacheSize: false)
            
            for fileURL in URLsToDelete {
                do {
                    try self.fileManager.removeItem(at: fileURL)
                } catch {
                    print("DataCache: Error while removing files \(error.localizedDescription)")
                }
            }
            
            if self.maxDiskCacheSize > 0 && diskCacheSize > self.maxDiskCacheSize {
                let targetSize = self.maxDiskCacheSize / 2
                 
                let sortedFiles = cachedFiles.keysSortedByValue {
                    resourceValue1, resourceValue2 -> Bool in
                    
                    if let date1 = resourceValue1.contentAccessDate,
                       let date2 = resourceValue2.contentAccessDate
                    {
                        return date1.compare(date2) == .orderedAscending
                    }
                    return true
                }
                
                for fileURL in sortedFiles {
                    
                    do {
                        try self.fileManager.removeItem(at: fileURL)
                    } catch {
                        print("DataCache: Error while removing files \(error.localizedDescription)")
                    }
                    
                    URLsToDelete.append(fileURL)
                    
                    if let fileSize = cachedFiles[fileURL]?.totalFileAllocatedSize {
                        diskCacheSize -= UInt(fileSize)
                    }
                    
                    if diskCacheSize < targetSize {
                        break
                    }
                }
            }
            
            DispatchQueue.main.async(execute: { () -> Void in
                handler?()
            })
        }
    }
  
  open func getCacheFiles() ->  [URL] {
      
      let diskCacheURL = URL(fileURLWithPath: cachePath)
      let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .contentAccessDateKey, .totalFileAllocatedSizeKey]
  
      var cachedFiles = [URL]()
  
      for fileUrl in (try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles)) ?? [] {
          
          do {
              let resourceValues = try fileUrl.resourceValues(forKeys: resourceKeys)
              if resourceValues.isDirectory == true {
                  continue
              }
              cachedFiles.append(fileUrl)
          } catch {
              print("DataCache: Error while iterating files \(error.localizedDescription)")
          }
      }
      
      return cachedFiles
  }
}
 
extension SwiftSimpleCache {
     
    fileprivate func travelCachedFiles(onlyForCacheSize: Bool) -> (urlsToDelete: [URL], diskCacheSize: UInt, cachedFiles: [URL: URLResourceValues]) {
        
        let diskCacheURL = URL(fileURLWithPath: cachePath)
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .contentAccessDateKey, .totalFileAllocatedSizeKey]
        let expiredDate: Date? = (maxCachePeriodInSecond < 0) ? nil : Date(timeIntervalSinceNow: -maxCachePeriodInSecond)
        
        var cachedFiles = [URL: URLResourceValues]()
        var urlsToDelete = [URL]()
        var diskCacheSize: UInt = 0
        
        for fileUrl in (try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles)) ?? [] {
            
            do {
                let resourceValues = try fileUrl.resourceValues(forKeys: resourceKeys)
                if resourceValues.isDirectory == true {
                    continue
                }
                 
                if !onlyForCacheSize,
                    let expiredDate = expiredDate,
                    let lastAccessData = resourceValues.contentAccessDate,
                    (lastAccessData as NSDate).laterDate(expiredDate) == expiredDate
                {
                    urlsToDelete.append(fileUrl)
                    continue
                }
                
                if let fileSize = resourceValues.totalFileAllocatedSize {
                    diskCacheSize += UInt(fileSize)
                    if !onlyForCacheSize {
                        cachedFiles[fileUrl] = resourceValues
                    }
                }
            } catch {
                print("DataCache: Error while iterating files \(error.localizedDescription)")
            }
        }
        
        return (urlsToDelete, diskCacheSize, cachedFiles)
    }
    
    func cachePath(forKey key: String) -> String {
        let fileName = key.md5
        return (cachePath as NSString).appendingPathComponent(fileName)
    }
}
  
extension Dictionary {
   func keysSortedByValue(_ isOrderedBefore: (Value, Value) -> Bool) -> [Key] {
       return Array(self).sorted{ isOrderedBefore($0.1, $1.1) }.map{ $0.0 }
   }
}
