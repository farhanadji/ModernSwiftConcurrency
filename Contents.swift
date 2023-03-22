import Foundation
import UIKit
import PlaygroundSupport
import SwiftUI
import Combine


// MARK: - Concurrency Introduction
/*
  Synchronously -> The execution happens sequentially,
                   runs in one execution thread on a single CPU core
  Asynchronously -> The execution allows to run in any order on one thread
                    and sometimes at the same time on multiple threads
                    depending on events and system availability

Modern Swift Concurrency
  1. A cooperative thread pool.
  2. async/awaitsyntax.
  3. Structured concurrency.
  4. Context-aware code compilation.
*/

// MARK: - Pre-async/await
//struct IntroRepository {
//    static func fetchData(completion: @escaping(Result<String, Error>) -> Void) {
//        APIClient.shared.fetch(request: "Testing") { response in
//            completion(response)
//        }
//    }
//}
//
//func introRun() {
//    IntroRepository.fetchData() { result in
//        switch result {
//        case .success(let value):
//            print(value)
//        case .failure(let error):
//            print(error.localizedDescription)
//        }
//    }
//}
//
//introRun()

/*
 Drawbacks
    1. The compiler has no clear way of knowing how many times you’ll call completion
    2. Need to handle memory management manually by weakly capturing
    3. The compiler has no way to make sure you handled the error
 */

// MARK: - Intro async/await
/*
     The modern concurrency model provides the following three tools to achieve the same goals as the example above:
     • async: Indicates that a method or function is asynchronous. Using it lets you suspend execution until an asynchronous method returns a result.
     • await: Indicates that your code might pause its execution while it waits for an async-annotated method or function to return.
     • Task: A unit of asynchronous work. You can wait for a task to complete or cancel it before it finishes.
 */

struct IntroAsyncRepository {
    @discardableResult func fetchData(request: String) async -> String {
        do {
            let value = try await APIClient.shared.fetch(request: request)
            print(value)
            return value
        } catch {
            print(error)
            return ""
        }
    }
}

//let task = Task { //Task executes the given closure in an asynchronous context so the compiler knows what code is safe (or unsafe) to write in that closure.
//    await IntroAsyncRepository().fetchData(request: "Hello from async!")
//}

// MARK: - Grouping async calls

func groupAsyncCall() async {
    let repo = IntroAsyncRepository()
    await repo.fetchData(request: "first call")
    await repo.fetchData(request: "second call")
}

func groupAsyncConcurrentCall() async {
    let repo = IntroAsyncRepository()
    async let val1 = repo.fetchData(request: "first call concurrent")
    async let val2 = repo.fetchData(request: "second call concurrent")
    print("concurrent result => \(await val1) - \(await val2)")
    
    //Alternative
    //let (value1, value2) = await (val1, val2)
    //print("concurrent result => \(value1) - \(value2)")
}

//Task {
//    print("-- Group call serial --")
//    await groupAsyncCall()
//    try await Task.sleep(seconds: 2)
//    print("\n-- Group call concurrent --")
//    await groupAsyncConcurrentCall()
//}

//MARK: Task introduction
/*
Task is a type that represents a top-level asynchronous task. Being top-level means it can create an asynchronous context — which can start from a synchronous context.
 
 Long story short, any time you want to run asynchronous code from a synchronous context, you need a new Task.
 
 You can use the following APIs to manually control a task’s execution:
 
 • Task(priority:operation): Schedules operation for asynchronous execution with the given priority. It inherits defaults from the current synchronous context.
 
    Task(priority: .background) {
        //async task
    }
 
 • Task.detached(priority:operation): Similar to Task(priority:operation), except that it doesn’t inherit the defaults of the calling context.
 
     Task { --> parent task
         Task.detached(priority: .utility) {
            //async task
         }
    
        try await task() -> supposed this call is failed and throw an error, Task.detached won't be cancelled
     }
 
 • Task.value: Waits for the task to complete, then returns its value, similarly to a promise in other languages.
 
        let task = Task {
            await getValue()
        }
     
        print(await task.value)
 
 • Task.isCancelled: Returns true if the task was canceled since the last suspension point. You can inspect this boolean to know when you should stop the execution of scheduled work.
 
 • Task.checkCancellation(): Throws a CancellationError if the task is canceled. This lets the function use the error-handling infrastructure to yield execution.
 
 • Task.sleep(nanoseconds:): Makes the task sleep for at least the given number of nanoseconds, but doesn’t block the thread while that happens.
 */

//MARK: - Intermediate task
/*
 === Canceling Tasks ===
 You can, however, implement a finer-grained cancellation strategy for your task- based code by using the following Task APIs:
 • Task.isCancelled: Returns true if the task is still alive but has been canceled since the last suspension point.
 • Task.currentPriority: Returns the current task’s priority.
 • Task.cancel(): Attempts to cancel the task and its child tasks.
 • Task.checkCancellation(): Throws a CancellationError if the task is canceled, making it easier to exit a throwing context.
 • Task.yield(): Suspends the execution of the current task, giving the system a chance to cancel it automatically to execute some other task with higher priority.
 
 
 SwiftUI Modifier
 using .task {...} -> automatically canceling your code when the view disappears
 
 Manually cancelling tasks
 1. Store Task object into variable
    @State var ourTask: Task<String, Error>?
 
 2. Replace Task with ourTask or store the task to ourTask
    ourTask = Task { ... }
 
 3. Call .cancel() rightaway
    Button {
        ourTask?.cancel()
    } {
        Text("Cancel")
    }
 */

struct CancelView: View {
    @State var ourTask: Task<Void, Error>?
    @State var errorText: String?
    @State var value: String?
    
    var body: some View {
        VStack {
            Button {
                errorText = nil
                value = nil
                guard ourTask == nil else {
                    ourTask?.cancel()
                    ourTask = nil
                    return
                }
                
                ourTask = Task {
                    do {
                        try await Task.sleep(seconds: 3)
                        value = "Value from task"
                    } catch {
                        if let _ = error as? CancellationError {
                            errorText = "Task cancelled"
                        }
                    }
                }
            } label: {
                Text(ourTask == nil ? "Start" : "Cancel")
            }
            
            if let value = value {
                Text(value)
            }
            
            if let value = errorText {
                Text(value)
            }
        }
        .frame(width: 200, height: 200)
    }
}

//PlaygroundPage.current.setLiveView(CancelView())


//MARK: - Bridging Combine and AsyncSequence
struct CombineAsyncSequenceView: View {
    @State var timerTask: Task<Void, Error>?
    @State var duration: String = ""
    var body: some View {
        VStack {
            Button {
                guard timerTask == nil else {
                    timerTask?.cancel()
                    timerTask = nil
                    duration = ""
                    return
                }
                
                let startDate = Date().timeIntervalSince1970
                let timerSequence = Timer
                    .publish(every: 1, tolerance: 1, on: .main, in: .common)
                    .autoconnect()
                    .map { date -> String in
                        let duration = Int(date.timeIntervalSince1970 -  startDate)
                        return "\(duration)s"
                    }
                    .values // AsyncPublisher
                //you can use for await with any Combine publisher by accessing its values property, which automatically wraps the publisher in an AsyncSequence.
                
                timerTask = Task {
                    for await duration in timerSequence {
                        self.duration = duration
                    }
                }
            } label: {
                Text(timerTask == nil ? "Start timer" : "Stop timer")
            }

            Text(duration)
        }
        .frame(width: 200, height: 200)
    }
}

//PlaygroundPage.current.setLiveView(CombineAsyncSequenceView())

//MARK: - Custom Async Sequences with AsyncStream
func demoAsyncStream(text: String) -> AsyncStream<String> {
    //init(unfolding:onCancel:): Creates a new stream that produces values by returning them from the unfolding closure. It optionally executes an onCancel closure when it’s canceled.
    var phrase = text
    var index = phrase.startIndex
    return AsyncStream<String> {
        guard index < phrase.endIndex else { return nil }
        do {
            try await Task.sleep(seconds: 0.5)
        } catch {
            return nil
        }
        
        defer { index = phrase.index(after: index) }
        return String(phrase[phrase.startIndex...index])
        /*
            Your unfolding closure will be called every time you’re expected to begin producing a value for your stream. In practice this means that your closure will be called, you perform some work, you return a value and then your closure is called. This repeats until the for loop is cancelled, the task that contains your async for loop is cancelled, or until you return nil from your unfolding closure.
             
             The AsyncStream(unfolding:) way to produce a stream of values is quite convenient but it’s particularly useful in situations where:
             - You want to perform async work that needs to be awaited to produce elements
             - You have a need to handle back pressure when bridging an API you own
         */
        
    }
}
////
//Task {
//    for await item in demoAsyncStream(text: "Hello form async stream!") {
//        print(item)
//    }
//}

// Producing an async stream with continuation
func demoTimerAsyncStreamContinuation(duration: Int) -> AsyncStream<String> {
    var countdown = duration
    return AsyncStream { continuation in
        DispatchQueue.main.async {
            Timer.scheduledTimer(
                withTimeInterval: 1.0,
                repeats: true
            ) { timer in
                guard countdown > 0 else {
                    timer.invalidate()
                    continuation.yield(with: .success("🎉 Finish"))
                    continuation.finish()
                    return
                }
                continuation.yield("\(countdown)....")
                countdown -= 1
            }
        }
    }
}
/*
     With a continuation you have the ability to construct an async stream object and send values over the async stream whenever values become available.
     
     If we’re building an AsyncSTream that wraps a delegate based API, we can hold on to our continuation in the delegate object and call yield whenever a relevant delegate method is called.
     
     For example, we could call continuation.yield from within a CLLocationManagerDelegate whenever a new user location is made available to us:
 
         class AsyncLocationStream: NSObject, CLLocationManagerDelegate {
             lazy var stream: AsyncStream<CLLocation> = {
                 AsyncStream { (continuation: AsyncStream<CLLocation>.Continuation) -> Void in
                     self.continuation = continuation
                 }
             }()
             var continuation: AsyncStream<CLLocation>.Continuation?

             func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

                 for location in locations {
                     continuation?.yield(location)
                 }
             }
         }
 
    read more: https://www.donnywals.com/understanding-swift-concurrencys-asyncstream/
 */

Task {
    for await value in demoTimerAsyncStreamContinuation(duration: 3) {
        print(value)
    }
    print("Yay!")
}
