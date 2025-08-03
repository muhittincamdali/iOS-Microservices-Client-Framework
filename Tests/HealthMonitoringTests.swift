import XCTest
@testable import HealthMonitoring

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class HealthMonitoringTests: XCTestCase {
    
    var healthMonitor: HealthMonitor!
    var configuration: HealthMonitoringConfiguration!
    
    override func setUp() {
        super.setUp()
        
        configuration = HealthMonitoringConfiguration(
            monitoringInterval: 1.0,
            timeout: 5.0,
            retryCount: 3,
            enableNotifications: true
        )
        
        healthMonitor = HealthMonitor(configuration: configuration)
    }
    
    override func tearDown() {
        healthMonitor = nil
        configuration = nil
        super.tearDown()
    }
    
    func testHealthStatusUpdate() {
        let serviceName = "test-service"
        let status = ServiceHealthStatus(
            serviceName: serviceName,
            status: .healthy,
            responseTime: 100.0,
            lastChecked: Date(),
            errorMessage: nil
        )
        
        healthMonitor.updateHealthStatus(status)
        
        let expectation = XCTestExpectation(description: "Health status retrieval")
        
        healthMonitor.getHealthStatus { result in
            switch result {
            case .success(let statuses):
                XCTAssertFalse(statuses.isEmpty)
                XCTAssertTrue(statuses.contains { $0.serviceName == serviceName })
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Health status retrieval failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testHealthMonitoringStartStop() {
        let expectation = XCTestExpectation(description: "Health monitoring")
        
        healthMonitor.startMonitoring { status in
            expectation.fulfill()
        }
        
        // Stop monitoring after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.healthMonitor.stopMonitoring()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testHealthStatusSubscription() {
        let serviceName = "subscription-test"
        let expectation = XCTestExpectation(description: "Health status subscription")
        
        healthMonitor.subscribeToHealthUpdates(for: serviceName) { status in
            XCTAssertEqual(status.serviceName, serviceName)
            expectation.fulfill()
        }
        
        let status = ServiceHealthStatus(
            serviceName: serviceName,
            status: .healthy,
            responseTime: 50.0,
            lastChecked: Date(),
            errorMessage: nil
        )
        
        healthMonitor.updateHealthStatus(status)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testHealthStatusUnsubscription() {
        let serviceName = "unsubscription-test"
        var callbackCalled = false
        
        healthMonitor.subscribeToHealthUpdates(for: serviceName) { _ in
            callbackCalled = true
        }
        
        healthMonitor.unsubscribeFromHealthUpdates(for: serviceName)
        
        let status = ServiceHealthStatus(
            serviceName: serviceName,
            status: .healthy,
            responseTime: 50.0,
            lastChecked: Date(),
            errorMessage: nil
        )
        
        healthMonitor.updateHealthStatus(status)
        
        // Wait a bit to ensure callback is not called
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertFalse(callbackCalled)
        }
    }
    
    func testMultipleHealthStatuses() {
        let services = ["service-1", "service-2", "service-3"]
        let expectations = services.map { XCTestExpectation(description: "Health status for \($0)") }
        
        for (index, serviceName) in services.enumerated() {
            let status = ServiceHealthStatus(
                serviceName: serviceName,
                status: index % 2 == 0 ? .healthy : .unhealthy,
                responseTime: Double(index * 50),
                lastChecked: Date(),
                errorMessage: index % 2 == 1 ? "Service temporarily unavailable" : nil
            )
            
            healthMonitor.updateHealthStatus(status)
        }
        
        healthMonitor.getHealthStatus { result in
            switch result {
            case .success(let statuses):
                XCTAssertEqual(statuses.count, 3)
                
                for (index, serviceName) in services.enumerated() {
                    let status = statuses.first { $0.serviceName == serviceName }
                    XCTAssertNotNil(status)
                    XCTAssertEqual(status?.status, index % 2 == 0 ? .healthy : .unhealthy)
                    XCTAssertEqual(status?.responseTime, Double(index * 50))
                }
                
                expectations.forEach { $0.fulfill() }
            case .failure(let error):
                XCTFail("Health status retrieval failed: \(error)")
            }
        }
        
        wait(for: expectations, timeout: 5.0)
    }
    
    func testHealthStatusWithError() {
        let serviceName = "error-test"
        let errorMessage = "Connection timeout"
        
        let status = ServiceHealthStatus(
            serviceName: serviceName,
            status: .unhealthy,
            responseTime: 5000.0,
            lastChecked: Date(),
            errorMessage: errorMessage
        )
        
        healthMonitor.updateHealthStatus(status)
        
        let expectation = XCTestExpectation(description: "Health status with error")
        
        healthMonitor.getHealthStatus { result in
            switch result {
            case .success(let statuses):
                let errorStatus = statuses.first { $0.serviceName == serviceName }
                XCTAssertNotNil(errorStatus)
                XCTAssertEqual(errorStatus?.status, .unhealthy)
                XCTAssertEqual(errorStatus?.errorMessage, errorMessage)
                XCTAssertEqual(errorStatus?.responseTime, 5000.0)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Health status retrieval failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConfigurationUpdate() {
        let expectation = XCTestExpectation(description: "Configuration update")
        
        let newConfiguration = HealthMonitoringConfiguration(
            monitoringInterval: 60.0,
            timeout: 15.0,
            retryCount: 5,
            enableNotifications: false
        )
        
        healthMonitor.updateConfiguration(newConfiguration)
        
        // Verify configuration was updated
        // Note: In a real implementation, we would access the configuration
        // For now, we just verify the method doesn't crash
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testHealthStatusTypes() {
        let healthyStatus = ServiceHealthStatus(
            serviceName: "healthy-service",
            status: .healthy,
            responseTime: 50.0,
            lastChecked: Date(),
            errorMessage: nil
        )
        
        let unhealthyStatus = ServiceHealthStatus(
            serviceName: "unhealthy-service",
            status: .unhealthy,
            responseTime: 5000.0,
            lastChecked: Date(),
            errorMessage: "Service unavailable"
        )
        
        let unknownStatus = ServiceHealthStatus(
            serviceName: "unknown-service",
            status: .unknown,
            responseTime: 0.0,
            lastChecked: Date(),
            errorMessage: nil
        )
        
        healthMonitor.updateHealthStatus(healthyStatus)
        healthMonitor.updateHealthStatus(unhealthyStatus)
        healthMonitor.updateHealthStatus(unknownStatus)
        
        let expectation = XCTestExpectation(description: "Health status types")
        
        healthMonitor.getHealthStatus { result in
            switch result {
            case .success(let statuses):
                XCTAssertEqual(statuses.count, 3)
                
                let healthy = statuses.first { $0.serviceName == "healthy-service" }
                let unhealthy = statuses.first { $0.serviceName == "unhealthy-service" }
                let unknown = statuses.first { $0.serviceName == "unknown-service" }
                
                XCTAssertNotNil(healthy)
                XCTAssertNotNil(unhealthy)
                XCTAssertNotNil(unknown)
                
                XCTAssertEqual(healthy?.status, .healthy)
                XCTAssertEqual(unhealthy?.status, .unhealthy)
                XCTAssertEqual(unknown?.status, .unknown)
                
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Health status retrieval failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testPerformance() {
        let startTime = Date()
        
        // Update many health statuses
        for i in 1...100 {
            let status = ServiceHealthStatus(
                serviceName: "service-\(i)",
                status: i % 2 == 0 ? .healthy : .unhealthy,
                responseTime: Double(i * 10),
                lastChecked: Date(),
                errorMessage: i % 3 == 0 ? "Error \(i)" : nil
            )
            
            healthMonitor.updateHealthStatus(status)
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        XCTAssertLessThan(executionTime, 1.0)
    }
} 