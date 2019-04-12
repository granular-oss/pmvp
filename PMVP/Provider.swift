//
//  Provider.swift
//  PMVP
//
//  Created by Aubrey Goodman on 4/8/19.
//  Copyright © 2019 Aubrey Goodman. All rights reserved.
//

import RxSwift

class Provider<K: Hashable, T: Proxy, A: LocalObject, B: RemoteObject, L: LocalStorage<K, A, T>, R: RemoteStorage<K, B, T>> {

	private let localStorage: LocalStorage<K, A, T>

	private let remoteStorage: RemoteStorage<K, B, T>

	private let storageQueue: DispatchQueue

	private let scheduler: SchedulerType

	private var subjectMap: [K: BehaviorSubject<T?>] = [:]

	init(queueName: String, localStorage: LocalStorage<K, A, T>, remoteStorage: RemoteStorage<K, B, T>) {
		self.storageQueue = DispatchQueue(label: queueName)
		self.scheduler = SerialDispatchQueueScheduler(queue: storageQueue, internalSerialQueueName: queueName)
		self.localStorage = localStorage
		self.remoteStorage = remoteStorage
	}

	// MARK: - Required Methods

	func createSubject() -> BehaviorSubject<T?> {
		fatalError("unimplemented \(#function)")
	}

	func key(for object: T?) -> K? {
		fatalError("unimplemented \(#function)")
	}

	// MARK: - Basic ORM

	public final func object(for key: K, queue: DispatchQueue, callback: @escaping (T?) -> Void) {
		let local = self.localStorage
		let workerQueue = self.storageQueue
		let wrapperCallback = buildWrapper(using: queue, for: callback)
		storageQueue.async { local.object(for: key, queue: workerQueue, callback: wrapperCallback) }
	}

	public final func objects(for keys: [K], queue: DispatchQueue, callback: @escaping ([T]) -> Void) {
		let local = self.localStorage
		let workerQueue = self.storageQueue
		let wrapperCallback = buildWrapper(using: queue, for: callback)
		storageQueue.async { local.objects(for: keys, queue: workerQueue, callback: wrapperCallback) }
	}

	public final func update(_ object: T, queue: DispatchQueue, callback: @escaping (T) -> Void) {
		let local = self.localStorage
		let workerQueue = self.storageQueue
		let wrapperCallback = buildWrapper(using: queue, for: callback)
		storageQueue.async { local.update(object, queue: workerQueue, callback: wrapperCallback) }
	}

	public final func update(_ objects: [T], queue: DispatchQueue, callback: @escaping ([T]) -> Void) {
		let local = self.localStorage
		let workerQueue = self.storageQueue
		let wrapperCallback = buildWrapper(using: queue, for: callback)
		storageQueue.async { local.update(objects, queue: workerQueue, callback: wrapperCallback) }
	}

	public final func destroy(_ object: T, queue: DispatchQueue, callback: @escaping (T) -> Void) {
		let local = self.localStorage
		let workerQueue = self.storageQueue
		let wrapperQueue = buildWrapper(using: queue, for: callback)
		storageQueue.async { local.destroy(object, queue: workerQueue, callback: wrapperQueue) }
	}

	// MARK: - Rx Observable Methods

	func object(for key: K) -> Observable<T?> {
		var result: Observable<T?>!
		storageQueue.sync { [weak self] in
			guard let strongSelf = self else {
				fatalError("curious")
			}
			result = strongSelf.findOrCreateSubject(for: key)
		}
		return result
	}

	// MARK: - Private Helper Methods

	private func findOrCreateSubject(for key: K) -> BehaviorSubject<T?> {
		if let existingSubject: BehaviorSubject<T?> = subjectMap[key] {
			return existingSubject
		}
		else {
			let newSubject: BehaviorSubject<T?> = createSubject()
			subjectMap[key] = newSubject
			_ = newSubject
				.observeOn(scheduler)
				.do(onDispose: { [weak self] in self?.clearUnusedSubject(for: key) })
			return newSubject
		}
	}

	private func clearUnusedSubject(for key: K) {
		if let subject: BehaviorSubject<T?> = subjectMap[key], !subject.hasObservers {
			subjectMap.removeValue(forKey: key)
		}
	}

	private func notify(_ object: T?) {
		guard let key = self.key(for: object) else { return }
		storageQueue.async { [weak self] in
			if let strongSelf = self, let subject = strongSelf.subjectMap[key] {
				subject.onNext(object)
			}
		}
	}

	typealias OptionalInstanceCallback = (T?) -> Void
	private func buildWrapper(using queue: DispatchQueue, for callback: @escaping OptionalInstanceCallback) -> OptionalInstanceCallback {
		return { [weak self] (result: T?) in
			queue.async { callback(result) }
			self?.notify(result)
		}
	}

	typealias InstanceCallback = (T) -> Void
	private func buildWrapper(using queue: DispatchQueue, for callback: @escaping InstanceCallback) -> InstanceCallback {
		return { [weak self] (result: T) in
			queue.async { callback(result) }
			self?.notify(result)
		}
	}

	typealias ArrayCallback = ([T]) -> Void
	private func buildWrapper(using queue: DispatchQueue, for callback: @escaping ArrayCallback) -> ArrayCallback {
		return { [weak self] (results: [T]) in
			queue.async { callback(results) }
			for observer in results {
				self?.notify(observer)
			}
		}
	}

}
