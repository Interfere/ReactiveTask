//
//  TaskSpec.swift
//  ReactiveTask
//
//  Created by Justin Spahr-Summers on 2014-10-11.
//  Copyright (c) 2014 Carthage. All rights reserved.
//

// swiftlint:disable function_body_length

import Foundation
import Nimble
import Quick
import ReactiveSwift
import ReactiveTask

class TaskSpec: QuickSpec {
	override func spec() {
		it("should notify that a task is about to be launched") {
			var isLaunched: Bool = false

			let task = Task("/usr/bin/true")
			let result = task.launch()
				.on(value: { event in
					if case let .launch(launched) = event {
						isLaunched = true
						expect(launched) == task
					}
				})
				.wait()

			expect(try result.get()).notTo(throwError())
			expect(isLaunched) == true
		}

		it("should launch a task that writes to stdout") {
			let result = Task("/bin/echo", arguments: [ "foobar" ]).launch()
				.reduce(Data()) { aggregated, event in
					var mutableData = aggregated
					if case let .standardOutput(data) = event {
						mutableData.append(data)
					}

					return mutableData
				}
				.single()

			expect(result).notTo(beNil())
      if case let .success(data) = result {
				expect(String(data: data, encoding: .utf8)).to(equal("foobar\n"))
			}
		}

		it("should launch a task that writes to stderr") {
			var aggregated = Data()
			let result = Task("/usr/bin/stat", arguments: [ "not-a-real-file" ]).launch()
				.reduce(aggregated) { _, event in
					if case let .standardError(data) = event {
						aggregated.append(data)
					}
					return aggregated
				}
				.single()

			expect(result).notTo(beNil())
      expect(try result?.get()).to(throwError())
			expect(String(data: aggregated, encoding: .utf8)).to(equal("stat: not-a-real-file: stat: No such file or directory\n"))
		}

		it("should launch a task with standard input") {
			let strings = [ "foo\n", "bar\n", "buzz\n", "fuzz\n" ]
			let data = strings.map { $0.data(using: .utf8)! }

			let result = Task("/usr/bin/sort").launch(standardInput: SignalProducer(data))
        .compactMap { event in event.value }
				.single()

			expect(result).notTo(beNil())
      if case let .success(data) = result {
				expect(String(data: data, encoding: .utf8)).to(equal("bar\nbuzz\nfoo\nfuzz\n"))
			}
		}

		it("should error correctly") {
			let task = Task("/usr/bin/stat", arguments: [ "not-a-real-file" ])
			let result = task.launch()
				.wait()

			expect(result).notTo(beNil())
      switch result {
        case let .failure(error):
          expect(error) == TaskError.shellTaskFailed(task, exitCode: 1, standardError: "stat: not-a-real-file: stat: No such file or directory\n")
          expect(error.description) == "A shell task (/usr/bin/stat not-a-real-file) failed with exit code 1:\nstat: not-a-real-file: stat: No such file or directory\n"
        case .success:
          fail("Error expected")
      }
		}
	}
}
