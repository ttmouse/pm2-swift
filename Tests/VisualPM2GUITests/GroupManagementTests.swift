import XCTest
import SwiftUI
import AppKit
@testable import VisualPM2GUI

// MARK: - Mock PM2 Service
final class MockPM2Service: PM2ServiceProtocol {
    var shouldThrowOnStart = false
    var shouldThrowOnStop = false
    var startedProjects: [String] = []
    var stoppedProjects: [String] = []
    var fetchResult: [PM2Project] = []

    func fetchProjects() async throws -> [PM2Project] { fetchResult }
    func startProject(_ id: String) async throws {
        if shouldThrowOnStart { throw PM2ServiceError.commandFailed("mock error") }
        startedProjects.append(id)
    }
    func stopProject(_ id: String) async throws {
        if shouldThrowOnStop { throw PM2ServiceError.commandFailed("mock error") }
        stoppedProjects.append(id)
    }
    func restartProject(_ id: String) async throws {}
    func deleteProject(_ id: String) async throws {}
    func fetchLogs(for id: String, lines: Int) async throws -> String { "" }
    func flushLogs() async throws {}
    func saveState() async throws {}
    func scanForNewProjects() async throws -> [DiscoveredApp] { [] }
    func startDiscoveredApp(configPath: String, appName: String) async throws {}
}

// MARK: - PM2Project Group Key Tests
final class ProjectGroupKeyTests: XCTestCase {

    func testProjectGroupKey_TwoSegments() {
        let project = PM2Project.mock(id: "xm-console-api", status: .online)
        XCTAssertEqual(project.projectGroupKey, "xm-console")
    }

    func testProjectGroupKey_ThreeSegments() {
        let project = PM2Project.mock(id: "XM-bazi-backend", status: .online)
        XCTAssertEqual(project.projectGroupKey, "XM-bazi")
    }

    func testProjectGroupKey_TwoSegmentsLowerCase() {
        let project = PM2Project.mock(id: "web-share", status: .stopped)
        XCTAssertEqual(project.projectGroupKey, "web-share")
    }

    func testProjectGroupKey_SingleSegment() {
        let project = PM2Project.mock(id: "subform", status: .online)
        XCTAssertEqual(project.projectGroupKey, "subform")
    }

    func testProjectGroupKey_UnderscoreDelimited() {
        let project = PM2Project.mock(id: "hello_world_api", status: .stopped)
        XCTAssertEqual(project.projectGroupKey, "hello")
    }

    func testProjectGroupKey_EmptyString() {
        let project = PM2Project.mock(id: "", status: .stopped)
        XCTAssertEqual(project.projectGroupKey, "未分组")
    }

    func testProjectGroupKey_NoDelimiter() {
        let project = PM2Project.mock(id: "myapp", status: .online)
        XCTAssertEqual(project.projectGroupKey, "myapp")
    }
}

// MARK: - AppState Group Logic Tests
@MainActor
final class AppStateGroupTests: XCTestCase {
    var mockService: MockPM2Service!
    var appState: AppState!

    override func setUp() async throws {
        mockService = MockPM2Service()
        appState = await AppState(pm2Service: mockService)

        // Stop auto-refresh to keep tests deterministic
        await MainActor.run {
            appState.autoRefresh = false
        }
    }

    override func tearDown() async throws {
        mockService = nil
        appState = nil
    }

    func testIsGroupOnline_AllOnline() async {
        let projects = [
            PM2Project.mock(id: "xm-console-api", status: .online),
            PM2Project.mock(id: "xm-console-frontend", status: .online),
        ]
        await MainActor.run {
            appState.projects = projects
        }

        let isOnline = appState.isGroupOnline("xm-console")
        XCTAssertTrue(isOnline)
    }

    func testIsGroupOnline_SomeStopped() async {
        let projects = [
            PM2Project.mock(id: "xm-console-api", status: .online),
            PM2Project.mock(id: "xm-console-frontend", status: .stopped),
        ]
        await MainActor.run {
            appState.projects = projects
        }

        let isOnline = appState.isGroupOnline("xm-console")
        XCTAssertFalse(isOnline)
    }

    func testIsGroupOnline_AllStopped() async {
        let projects = [
            PM2Project.mock(id: "xm-console-api", status: .stopped),
            PM2Project.mock(id: "xm-console-frontend", status: .stopped),
        ]
        await MainActor.run {
            appState.projects = projects
        }

        let isOnline = appState.isGroupOnline("xm-console")
        XCTAssertFalse(isOnline)
    }

    func testIsGroupOnline_EmptyGroup() async {
        let isOnline = appState.isGroupOnline("non-existent-group")
        XCTAssertFalse(isOnline)
    }

    func testSortedGroupedProjects_ActiveGroupsFirst() async {
        let projects = [
            // xm-bazi group: mixed status
            PM2Project.mock(id: "XM-bazi-backend", status: .online),
            PM2Project.mock(id: "XM-bazi-frontend", status: .stopped),
            // xm-digital-human group: all stopped
            PM2Project.mock(id: "xm-digital-human-api", status: .stopped),
            PM2Project.mock(id: "xm-digital-human-frontend", status: .stopped),
            // xm-console group: all online
            PM2Project.mock(id: "xm-console-api", status: .online),
            PM2Project.mock(id: "xm-console-frontend", status: .online),
        ]
        await MainActor.run {
            appState.filterText = ""
            appState.selectedCategory = nil
            appState.selectedTab = .all
            appState.projects = projects
        }

        let groups = appState.sortedGroupedProjects

        // Active groups should come first: xm-console (all online), XM-bazi (some online), then xm-digital-human (all stopped)
        XCTAssertEqual(groups.count, 3, "Should have 3 groups")

        if groups.count >= 3 {
            // First group should be xm-console (all online) — alphabetically first among active
            XCTAssertEqual(groups[0].groupName, "xm-console")
            XCTAssertEqual(groups[1].groupName, "XM-bazi")
            // Last group should be xm-digital-human (all stopped)
            XCTAssertEqual(groups[2].groupName, "xm-digital-human")
        }
    }

    func testStartProjectsInGroup_FiltersCorrectly() async {
        let projects = [
            PM2Project.mock(id: "xm-console-api", status: .stopped),
            PM2Project.mock(id: "xm-console-frontend", status: .online),
            PM2Project.mock(id: "xm-digital-human-api", status: .stopped),
        ]
        await MainActor.run {
            appState.filterText = ""
            appState.selectedCategory = nil
            appState.selectedTab = .all
            appState.projects = projects
        }

        await appState.startProjectsInGroup("xm-console")

        // Only xm-console-api should be started (it's the only stopped project in the xm-console group)
        XCTAssertEqual(mockService.startedProjects, ["xm-console-api"])
    }

    func testStopProjectsInGroup_FiltersCorrectly() async {
        let projects = [
            PM2Project.mock(id: "xm-console-api", status: .online),
            PM2Project.mock(id: "xm-console-frontend", status: .stopped),
            PM2Project.mock(id: "xm-digital-human-api", status: .online),
        ]
        await MainActor.run {
            appState.projects = projects
        }

        await appState.stopProjectsInGroup("xm-console")

        // Only xm-console-api should be stopped (it's the only online project in the xm-console group)
        XCTAssertEqual(mockService.stoppedProjects, ["xm-console-api"])
    }

    func testGroupManagement_IgnoresOtherGroups() async {
        let projects = [
            PM2Project.mock(id: "xm-console-api", status: .stopped),
            PM2Project.mock(id: "xm-digital-human-api", status: .stopped),
        ]
        await MainActor.run {
            appState.projects = projects
        }

        await appState.startProjectsInGroup("xm-console")

        // Only xm-console-api should be affected, not xm-digital-human-api
        XCTAssertEqual(mockService.startedProjects, ["xm-console-api"])
        XCTAssertFalse(mockService.startedProjects.contains("xm-digital-human-api"))
    }
}
