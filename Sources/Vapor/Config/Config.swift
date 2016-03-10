import Foundation

public class Config {
	public static let configDir = Application.workDir + "Config"
	private let fileManager = NSFileManager.defaultManager()
	private var repository: [String: Json]

	public init(repository: [String: Json] = Dictionary()) {
		self.repository = repository
	}

	public func has(keyPath: String) -> Bool {
		return self.get(keyPath) != nil
	}

	public func get(keyPath: String) -> Json? {
		var keys = keyPath.keys

		guard keys.count > 0 else {
			return nil
		}

		var value = self.repository[keys.removeFirst()]

		while value != nil && value != Json.NullValue && keys.count > 0 {
			value = value?[keys.removeFirst()]
		}

		return value
	}

	public func set(value: Json, forKeyPath keyPath: String) {
		var keys = keyPath.keys
		let group = keys.removeFirst()

		if keys.count == 0 {
			self.repository[group] = value
		} else {
			self.repository[group]?.set(value, keys: keyPath.keys)
		}
	}

	public func populate(path: String, application: Application) throws {
		var url = NSURL(fileURLWithPath: path)
		var files = Dictionary<String, [NSURL]>()
		try self.populateConfigFiles(&files, in: url)

		for env in application.environment.description.keys {
			#if os(Linux)
				url = url.URLByAppendingPathComponent(env)!
			#else
				url = url.URLByAppendingPathComponent(env)
			#endif

			if self.fileManager.fileExistsAtPath(url.path!) {
				try self.populateConfigFiles(&files, in: url)
			}
		}

		for (group, files) in files {
			for file in files {
				let data = try NSData(contentsOfURL: file, options: [])
				let json = try Json.deserialize(data)

				if self.repository[group] == nil {
					self.repository[group] = json
				} else {
					self.repository[group]?.merge(json)
				}
			}
		}
	}

	private func populateConfigFiles(inout files: [String: [NSURL]], in url: NSURL) throws {
		let contents = try self.fileManager.contentsOfDirectoryAtURL(url, includingPropertiesForKeys: nil, options: [ ])

		for file in contents {
			guard file.pathExtension == "json" else {
				continue
			}

			guard let name = file.URLByDeletingPathExtension?.lastPathComponent else {
				continue
			}

			if files[name] == nil {
				files[name] = Array()
			}

			files[name]?.append(file)
		}
	}

}

extension Json {

	mutating private func set(value: Json, keys: [String]) {
		var keys = keys

		guard keys.count > 0 else {
			return
		}

		let key = keys.removeFirst()

		guard case let .ObjectValue(object) = self else {
			return
		}

		var updated = object

		if keys.count == 0 {
			updated[key] = value
		} else {
			var child = updated[key] ?? Json.ObjectValue([:])
			child.set(value, keys: keys)
		}

		self = .ObjectValue(updated)
	}

}

extension String {

	private var keys: [String] {
		return self.split(".")
	}

}
