// SheetMuse: lifecycle of the iOS host facade (SheetMuse #889). `AlphaTabApiBase.init` queues `initialRender` on the
// next main turn; `destroy()` sets the facade's api to nil. Work queued before `destroy()` must not run after it.
#if canImport(CoreGraphics)
@testable import AlphaTab
import AlphaTabIOS
import AlphaTabRuntime
import Foundation
import Testing

private final class Flag: @unchecked Sendable { var value = false }

/// Resumes after every block already queued on the main queue has run.
@MainActor
private func drainMainQueue() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async { continuation.resume() }
    }
}

@MainActor
private func makeHost() throws -> (HostUiFacade, AlphaTabApiBase<Any?>) {
    let facade = HostUiFacade()
    facade.root.width = 600
    let api = try AlphaTabApiBase<Any?>(facade, Settings())
    return (facade, api)
}

@Suite struct HostFacadeLifecycleTests {
    /// The #889 crash: destroy in the same turn as the constructor, then the queued first render runs. A trap
    /// ("Unexpectedly found nil", SIGTRAP) fails the exit test; the child process must exit normally.
    @Test func destroyingInTheSameTurnLeavesTheQueuedRenderHarmless() async {
        await #expect(processExitsWith: .success) {
            await MainActor.run {
                let facade = HostUiFacade()
                facade.root.width = 600
                let api = try! AlphaTabApiBase<Any?>(facade, Settings())
                try! api.destroy()
            }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }

    /// A cursor update or any other `beginInvoke` queued before `destroy()` must not run after it.
    @MainActor
    @Test func workQueuedBeforeDestroyDoesNotRunAfterIt() async throws {
        let (facade, api) = try makeHost()
        await drainMainQueue() // the first render runs while the api is alive
        let ran = Flag()
        try facade.beginInvoke { ran.value = true }
        try api.destroy()
        await drainMainQueue()
        #expect(ran.value == false)
    }

    /// Work posted after `destroy()` is dropped too.
    @MainActor
    @Test func workPostedAfterDestroyIsDropped() async throws {
        let (facade, api) = try makeHost()
        await drainMainQueue()
        try api.destroy()
        let ran = Flag()
        try facade.beginInvoke { ran.value = true }
        await drainMainQueue()
        #expect(ran.value == false)
    }

    /// `destroy()` twice must not trap.
    @MainActor
    @Test func destroyingTwiceIsHarmless() async throws {
        let (_, api) = try makeHost()
        await drainMainQueue()
        try api.destroy()
        try api.destroy()
        await drainMainQueue()
    }
}
#endif
