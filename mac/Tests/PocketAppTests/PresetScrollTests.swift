import AppKit
import PocketCore
import SwiftUI
import XCTest
@testable import Pocket

@MainActor
final class PresetScrollTests: XCTestCase {
    private func mountRow(count: Int = 12) throws -> (NSWindow, Store, PresetScrollView) {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pocket-scroll-\(UUID())")
        let suite = "pocket-scroll-tests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(false, forKey: "reminders")
        let store = Store(directory: directory, defaults: defaults, servicesEnabled: false)
        XCTAssertTrue(store.start(currency: "USD", cents: 10000, openAtLogin: false))
        for index in 0..<count {
            store.savePreset(Preset(label: "Button \(index + 1)", cents: 100 + index, sign: -1, category: "food"))
        }
        let host = NSHostingView(rootView: QuickBar(onAsk: { _ in }).environmentObject(store).frame(width: 340, height: 40))
        let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 340, height: 40), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        func find(_ view: NSView) -> PresetScrollView? {
            if let scroll = view as? PresetScrollView { return scroll }
            return view.subviews.lazy.compactMap(find).first
        }
        let scroll = try XCTUnwrap(find(host))
        addTeardownBlock {
            await MainActor.run { window.orderOut(nil) }
            try? FileManager.default.removeItem(at: directory)
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        return (window, store, scroll)
    }

    func testPagingReachesHiddenButtonsAndClampsAtBothEnds() throws {
        let (_, store, scroll) = try mountRow()
        let state = try XCTUnwrap(scroll.state)
        XCTAssertGreaterThan(scroll.maximumOffset, 500)
        state.refresh()
        XCTAssertTrue(state.canScrollForward)
        XCTAssertFalse(state.canScrollBack)
        state.page(1)
        scroll.settle()
        XCTAssertGreaterThan(scroll.contentView.bounds.minX, 0)
        scroll.scrollHorizontally(to: .greatestFiniteMagnitude)
        state.refresh()
        XCTAssertEqual(scroll.contentView.bounds.minX, scroll.maximumOffset, accuracy: 1)
        XCTAssertTrue(state.canScrollBack)
        XCTAssertFalse(state.canScrollForward)
        state.page(-1)
        scroll.settle()
        XCTAssertLessThan(scroll.contentView.bounds.minX, scroll.maximumOffset)
        scroll.scrollHorizontally(to: -1000)
        state.refresh()
        XCTAssertEqual(scroll.contentView.bounds.minX, 0, accuracy: 1)
        XCTAssertFalse(state.canScrollBack)
        XCTAssertEqual(store.balance, 10000, "browsing quick-add buttons must never record an entry")
    }

    func testShortRowDoesNotShowPagingControls() throws {
        let (_, _, scroll) = try mountRow(count: 1)
        let state = try XCTUnwrap(scroll.state)
        state.refresh()
        XCTAssertFalse(state.overflows)
        XCTAssertEqual(scroll.maximumOffset, 0, accuracy: 1)
    }

    func testNativeDragScrollsWithoutActivatingAPreset() throws {
        let (window, store, scroll) = try mountRow()
        let start = scroll.convert(NSPoint(x: 140, y: 17), to: nil)
        for (index, type) in [NSEvent.EventType.leftMouseDown, .leftMouseDragged, .leftMouseDragged, .leftMouseUp].enumerated() {
            let x = start.x - CGFloat(index) * 30
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: NSPoint(x: x, y: start.y), modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime + Double(index) * 0.03, windowNumber: window.windowNumber,
                context: nil, eventNumber: index, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1))
            window.sendEvent(event)
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        }
        XCTAssertGreaterThan(scroll.contentView.bounds.minX, 20)
        scroll.settle()
        XCTAssertEqual(store.balance, 10000)
        XCTAssertEqual(store.ledger.entries.count, 1)
        let click = scroll.convert(NSPoint(x: 20, y: 17), to: nil)
        for (index, type) in [NSEvent.EventType.leftMouseDown, .leftMouseUp].enumerated() {
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: click, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime + Double(index) * 0.03, windowNumber: window.windowNumber,
                context: nil, eventNumber: index + 10, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1))
            window.sendEvent(event)
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        }
        XCTAssertEqual(store.ledger.entries.count, 2, "the next ordinary click must still add exactly once")
    }

    func testNumberShortcutStillUsesAButtonOutsideTheVisibleRow() throws {
        let (window, store, _) = try mountRow()
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: "9", charactersIgnoringModifiers: "9", isARepeat: false, keyCode: 25))
        XCTAssertTrue(window.performKeyEquivalent(with: event))
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        XCTAssertEqual(store.balance, 9892)
        XCTAssertEqual(store.ledger.entries.count, 2)
    }

    func testPresetButtonsRemainExposedToAccessibility() throws {
        let (_, _, scroll) = try mountRow()
        func buttons(in object: Any, depth: Int = 0) -> Int {
            guard depth < 12, let element = object as? NSAccessibilityProtocol else { return 0 }
            let own = element.accessibilityRole() == .button ? 1 : 0
            return own + (element.accessibilityChildren() ?? []).reduce(0) { $0 + buttons(in: $1, depth: depth + 1) }
        }
        XCTAssertGreaterThan(buttons(in: scroll), 0, "the native bridge must expose its hosted preset buttons")
    }

    // MARK: Fluid behavior

    private func drag(_ window: NSWindow, in scroll: PresetScrollView, from x: CGFloat, by step: CGFloat, moves: Int = 3, interval: Double = 0.016) throws {
        let start = scroll.convert(NSPoint(x: x, y: 17), to: nil)
        let types: [NSEvent.EventType] = [.leftMouseDown] + Array(repeating: .leftMouseDragged, count: moves) + [.leftMouseUp]
        for (index, type) in types.enumerated() {
            let moved = CGFloat(min(index, moves)) * step
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: NSPoint(x: start.x + moved, y: start.y), modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 100 + index, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1))
            window.sendEvent(event)
            RunLoop.main.run(until: Date().addingTimeInterval(interval))
        }
    }

    func testRubberbandResistsMoreTheFurtherItIsPulledAndInvertsExactly() {
        XCTAssertEqual(rubberband(0, dimension: 340), 0)
        let small = rubberband(-40, dimension: 340), large = rubberband(-400, dimension: 340)
        XCTAssertLessThan(small, 0)
        XCTAssertGreaterThan(abs(small), 40 * 0.4, "a short pull still follows the pointer closely")
        XCTAssertLessThan(abs(large) / 400, abs(small) / 40, "a long pull follows proportionally less")
        XCTAssertLessThan(abs(rubberband(-100_000, dimension: 340)), 340)
        for raw in [-300.0, -25, 0, 25, 300] as [CGFloat] {
            XCTAssertEqual(unrubberband(rubberband(raw, dimension: 340), dimension: 340), raw, accuracy: 0.01)
        }
    }

    func testProjectionMatchesScrollDeceleration() {
        XCTAssertEqual(projectedDistance(1000), 499, accuracy: 0.5)
        XCTAssertEqual(projectedDistance(-500), -249.5, accuracy: 0.5)
    }

    func testAThrowKeepsGlidingAfterReleaseAndComesToRestInRange() throws {
        let (window, store, scroll) = try mountRow()
        try drag(window, in: scroll, from: min(220, scroll.frame.width - 10), by: -40)
        let released = scroll.contentView.bounds.minX
        XCTAssertTrue(scroll.isMoving, "a fast release should hand its velocity to a glide")
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertGreaterThan(scroll.contentView.bounds.minX, released + 5, "the row keeps moving the way it was thrown")
        // A faster throw takes longer to decay. Wait for it to settle across display refresh rates.
        let deadline = Date().addingTimeInterval(6)
        while scroll.isMoving && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertFalse(scroll.isMoving)
        XCTAssertGreaterThanOrEqual(scroll.contentView.bounds.minX, 0)
        XCTAssertLessThanOrEqual(scroll.contentView.bounds.minX, scroll.maximumOffset + 0.5)
        XCTAssertEqual(store.balance, 10000)
    }

    func testPullingPastTheStartResistsThenSpringsBack() throws {
        let (window, _, scroll) = try mountRow()
        // Drag right from the start: past the end, slowly enough that it's a pull, not a throw.
        let start = scroll.convert(NSPoint(x: 40, y: 17), to: nil)
        for (index, type) in [NSEvent.EventType.leftMouseDown, .leftMouseDragged, .leftMouseDragged, .leftMouseDragged].enumerated() {
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: NSPoint(x: start.x + CGFloat(index) * 40, y: start.y), modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                eventNumber: 200 + index, clickCount: 1, pressure: 1))
            window.sendEvent(event)
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        }
        let pulled = scroll.contentView.bounds.minX
        XCTAssertLessThan(pulled, -10, "the row follows a pull past its start")
        XCTAssertGreaterThan(pulled, -120, "but less than the pointer moved")
        let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: NSPoint(x: start.x + 120, y: start.y), modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            eventNumber: 210, clickCount: 1, pressure: 0))
        window.sendEvent(up)
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        XCTAssertEqual(scroll.contentView.bounds.minX, 0, accuracy: 0.5, "and springs back to the start when let go")
        XCTAssertFalse(scroll.isMoving)
    }

    func testClickingAMovingRowStopsItWithoutAddingMoney() throws {
        let (window, store, scroll) = try mountRow()
        scroll.state?.page(1)
        XCTAssertTrue(scroll.isMoving)
        let click = scroll.convert(NSPoint(x: 60, y: 17), to: nil)
        for (index, type) in [NSEvent.EventType.leftMouseDown, .leftMouseUp].enumerated() {
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: click, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 300 + index, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1))
            window.sendEvent(event)
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        }
        XCTAssertFalse(scroll.isMoving, "a click catches the row")
        XCTAssertEqual(store.ledger.entries.count, 1, "and does not press the button under it")
        XCTAssertEqual(store.balance, 10000)
    }

    func testPagingTwiceQuicklyLandsTwoPagesOn() throws {
        let (_, _, scroll) = try mountRow()
        let state = try XCTUnwrap(scroll.state)
        let page = max(80, scroll.contentSize.width * 0.8)
        state.page(1)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        state.page(1)
        scroll.settle()
        XCTAssertEqual(scroll.contentView.bounds.minX, min(scroll.maximumOffset, page * 2), accuracy: 1)
    }
}
