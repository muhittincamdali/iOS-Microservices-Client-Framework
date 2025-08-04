import XCTest
import Foundation
@testable import MicroservicesClient

@available(iOS 15.0, *)
final class MicroservicesClientManagerTests: XCTestCase {
    
    var manager: MicroservicesClientManager!
    var mockAnalytics: MockMicroservicesAnalytics!
    
    override func setUp() {
        super.setUp()
        mockAnalytics = MockMicroservicesAnalytics()
        manager = MicroservicesClientManager(analytics: mockAnalytics)
    }
    
    override func tearDown() {
        manager = nil
        mockAnalytics = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitializationWithAnalytics() {
        XCTAssertNotNil(manager)
        XCTAssertNotNil(mockAnalytics)
        XCTAssertEqual(manager.configuration.serviceDiscoveryEnabled, true)
        XCTAssertEqual(manager.configuration.loadBalancingEnabled, true)
        XCTAssertEqual(manager.configuration.circuitBreakerEnabled, true)
    }
    
    func testInitializationWithoutAnalytics() {
        let managerWithoutAnalytics = MicroservicesClientManager()
        XCTAssertNotNil(managerWithoutAnalytics)
    }
    
    // MARK: - Service Discovery Tests
    
    func testServiceDiscovery() {
        let expectation = XCTestExpectation(description: "Service discovery")
        
        manager.discoverServices { result in
            switch result {
            case .success(let services):
                XCTAssertGreaterThanOrEqual(services.count, 0)
            case .failure(let error):
                XCTFail("Service discovery failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testServiceRegistration() {
        let expectation = XCTestExpectation(description: "Service registration")
        
        let service = Microservice(
            id: "test-service",
            name: "Test Service",
            type: .user,
            endpoint: URL(string: "https://api.example.com/test")!
        )
        
        manager.registerService(service) { result in
            switch result {
            case .success:
                XCTAssertTrue(true, "Service registered successfully")
            case .failure(let error):
                XCTFail("Service registration failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testGetServiceById() {
        let service = Microservice(
            id: "test-service",
            name: "Test Service",
            type: .user,
            endpoint: URL(string: "https://api.example.com/test")!
        )
        
        // Register service first
        let registerExpectation = XCTestExpectation(description: "Service registration")
        manager.registerService(service) { result in
            XCTAssertTrue(result.isSuccess)
            registerExpectation.fulfill()
        }
        wait(for: [registerExpectation], timeout: 10.0)
        
        // Get service by ID
        let retrievedService = manager.getService(id: "test-service")
        XCTAssertNotNil(retrievedService)
        XCTAssertEqual(retrievedService?.id, "test-service")
        XCTAssertEqual(retrievedService?.name, "Test Service")
    }
    
    func testGetAllServices() {
        let service1 = Microservice(
            id: "service-1",
            name: "Service 1",
            type: .user,
            endpoint: URL(string: "https://api.example.com/service1")!
        )
        
        let service2 = Microservice(
            id: "service-2",
            name: "Service 2",
            type: .payment,
            endpoint: URL(string: "https://api.example.com/service2")!
        )
        
        // Register services
        let group = DispatchGroup()
        
        group.enter()
        manager.registerService(service1) { _ in group.leave() }
        
        group.enter()
        manager.registerService(service2) { _ in group.leave() }
        
        group.wait()
        
        // Get all services
        let allServices = manager.getAllServices()
        XCTAssertGreaterThanOrEqual(allServices.count, 2)
    }
    
    // MARK: - Load Balancing Tests
    
    func testLoadBalancing() {
        let expectation = XCTestExpectation(description: "Load balancing")
        
        manager.balanceLoad(serviceType: .user) { result in
            switch result {
            case .success(let service):
                XCTAssertNotNil(service)
                XCTAssertEqual(service.type, .user)
            case .failure(let error):
                XCTFail("Load balancing failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testLoadBalancingWithStrategy() {
        let expectation = XCTestExpectation(description: "Load balancing with strategy")
        
        manager.balanceLoad(
            serviceType: .payment,
            strategy: .leastConnections
        ) { result in
            switch result {
            case .success(let service):
                XCTAssertNotNil(service)
                XCTAssertEqual(service.type, .payment)
            case .failure(let error):
                XCTFail("Load balancing failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testServiceHealthUpdate() {
        let service = Microservice(
            id: "health-test-service",
            name: "Health Test Service",
            type: .user,
            endpoint: URL(string: "https://api.example.com/health")!
        )
        
        // Register service
        let registerExpectation = XCTestExpectation(description: "Service registration")
        manager.registerService(service) { result in
            XCTAssertTrue(result.isSuccess)
            registerExpectation.fulfill()
        }
        wait(for: [registerExpectation], timeout: 10.0)
        
        // Update health status
        manager.updateServiceHealth(serviceId: "health-test-service", health: .healthy)
        
        // Verify analytics were called
        XCTAssertTrue(mockAnalytics.serviceHealthUpdatedCalled)
        XCTAssertEqual(mockAnalytics.lastServiceId, "health-test-service")
        XCTAssertEqual(mockAnalytics.lastHealth, .healthy)
    }
    
    // MARK: - Circuit Breaker Tests
    
    func testCircuitBreakerExecution() {
        let expectation = XCTestExpectation(description: "Circuit breaker execution")
        
        let request = ServiceRequest(
            serviceId: "test-service",
            method: "GET",
            path: "/test",
            headers: ["Authorization": "Bearer token"]
        )
        
        manager.executeWithCircuitBreaker(
            serviceId: "test-service",
            request: request
        ) { result in
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
            case .failure(let error):
                XCTFail("Circuit breaker execution failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCircuitBreakerStatus() {
        let status = manager.getCircuitBreakerStatus(serviceId: "test-service")
        XCTAssertNotNil(status)
    }
    
    // MARK: - Connection Management Tests
    
    func testConnectionEstablishment() {
        let expectation = XCTestExpectation(description: "Connection establishment")
        
        let service = Microservice(
            id: "connection-test-service",
            name: "Connection Test Service",
            type: .user,
            endpoint: URL(string: "https://api.example.com/connection")!
        )
        
        manager.establishConnection(to: service) { result in
            switch result {
            case .success(let connection):
                XCTAssertNotNil(connection)
                XCTAssertEqual(connection.serviceId, service.id)
                XCTAssertTrue(connection.isActive)
            case .failure(let error):
                XCTFail("Connection establishment failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testConnectionStatistics() {
        let stats = manager.getConnectionStatistics()
        XCTAssertNotNil(stats)
        XCTAssertGreaterThanOrEqual(stats?.totalConnections ?? 0, 0)
        XCTAssertGreaterThanOrEqual(stats?.activeConnections ?? 0, 0)
    }
    
    // MARK: - Request Execution Tests
    
    func testRequestExecution() {
        let expectation = XCTestExpectation(description: "Request execution")
        
        let request = ServiceRequest(
            serviceId: "test-service",
            method: "GET",
            path: "/users/123",
            headers: ["Authorization": "Bearer token"]
        )
        
        manager.executeRequest(serviceId: "test-service", request: request) { result in
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
            case .failure(let error):
                XCTFail("Request execution failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testBatchRequestExecution() {
        let expectation = XCTestExpectation(description: "Batch request execution")
        
        let requests = [
            ServiceRequest(serviceId: "service-1", method: "GET", path: "/users/1"),
            ServiceRequest(serviceId: "service-2", method: "GET", path: "/users/2"),
            ServiceRequest(serviceId: "service-3", method: "GET", path: "/users/3")
        ]
        
        manager.executeBatchRequests(requests) { result in
            switch result {
            case .success(let responses):
                XCTAssertEqual(responses.count, requests.count)
            case .failure(let error):
                XCTFail("Batch request execution failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Monitoring Tests
    
    func testPerformanceMonitoring() {
        let expectation = XCTestExpectation(description: "Performance monitoring")
        
        manager.monitorPerformance { result in
            switch result {
            case .success(let metrics):
                XCTAssertNotNil(metrics)
                XCTAssertGreaterThanOrEqual(metrics.serviceCount, 0)
                XCTAssertGreaterThanOrEqual(metrics.activeConnections, 0)
                XCTAssertGreaterThanOrEqual(metrics.averageResponseTime, 0)
            case .failure(let error):
                XCTFail("Performance monitoring failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testSystemAnalysis() {
        let report = manager.analyzeMicroservicesSystem()
        
        XCTAssertNotNil(report)
        XCTAssertGreaterThanOrEqual(report.totalServices, 0)
        XCTAssertGreaterThanOrEqual(report.healthyServices, 0)
    }
    
    // MARK: - Configuration Tests
    
    func testConfigurationUpdate() {
        var newConfig = MicroservicesConfiguration()
        newConfig.serviceDiscoveryEnabled = false
        newConfig.loadBalancingEnabled = false
        newConfig.circuitBreakerEnabled = false
        newConfig.connectionPoolingEnabled = false
        newConfig.timeout = 60.0
        newConfig.retryCount = 5
        
        manager.configuration = newConfig
        
        XCTAssertEqual(manager.configuration.serviceDiscoveryEnabled, false)
        XCTAssertEqual(manager.configuration.loadBalancingEnabled, false)
        XCTAssertEqual(manager.configuration.circuitBreakerEnabled, false)
        XCTAssertEqual(manager.configuration.connectionPoolingEnabled, false)
        XCTAssertEqual(manager.configuration.timeout, 60.0)
        XCTAssertEqual(manager.configuration.retryCount, 5)
    }
    
    // MARK: - Analytics Tests
    
    func testAnalyticsIntegration() {
        // Perform various operations and verify analytics are called
        let service = Microservice(
            id: "analytics-test",
            name: "Analytics Test",
            type: .user,
            endpoint: URL(string: "https://api.example.com/analytics")!
        )
        
        let registerExpectation = XCTestExpectation(description: "Service registration for analytics")
        manager.registerService(service) { result in
            XCTAssertTrue(result.isSuccess)
            registerExpectation.fulfill()
        }
        wait(for: [registerExpectation], timeout: 10.0)
        
        XCTAssertTrue(mockAnalytics.serviceRegisteredCalled)
        XCTAssertEqual(mockAnalytics.lastServiceId, "analytics-test")
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        // Test with invalid service ID
        let expectation = XCTestExpectation(description: "Error handling")
        
        let request = ServiceRequest(
            serviceId: "non-existent-service",
            method: "GET",
            path: "/test"
        )
        
        manager.executeRequest(serviceId: "non-existent-service", request: request) { result in
            switch result {
            case .success:
                XCTFail("Should have failed with non-existent service")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceServiceDiscovery() {
        measure {
            let expectation = XCTestExpectation(description: "Performance test")
            
            manager.discoverServices { _ in
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testPerformanceLoadBalancing() {
        measure {
            let expectation = XCTestExpectation(description: "Performance test")
            
            manager.balanceLoad(serviceType: .user) { _ in
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
}

// MARK: - Mock Classes

@available(iOS 15.0, *)
class MockMicroservicesAnalytics: MicroservicesAnalytics {
    var serviceDiscoverySetupCalled = false
    var loadBalancerSetupCalled = false
    var circuitBreakerSetupCalled = false
    var connectionPoolSetupCalled = false
    var servicesDiscoveredCalled = false
    var serviceDiscoveryFailedCalled = false
    var serviceRegisteredCalled = false
    var serviceRegistrationFailedCalled = false
    var loadBalancedCalled = false
    var loadBalancingFailedCalled = false
    var serviceHealthUpdatedCalled = false
    var circuitBreakerSuccessCalled = false
    var circuitBreakerFailureCalled = false
    var connectionEstablishedCalled = false
    var connectionFailedCalled = false
    var connectionClosedCalled = false
    var batchRequestsCompletedCalled = false
    var batchRequestsFailedCalled = false
    var performanceMonitoringStartedCalled = false
    var performanceMetricsCollectedCalled = false
    
    var lastServiceCount: Int?
    var lastError: Error?
    var lastServiceId: String?
    var lastStrategy: LoadBalancingStrategy?
    var lastHealth: ServiceHealth?
    var lastErrorCount: Int?
    var lastMetrics: PerformanceMetrics?
    
    func recordServiceDiscoverySetup() {
        serviceDiscoverySetupCalled = true
    }
    
    func recordLoadBalancerSetup() {
        loadBalancerSetupCalled = true
    }
    
    func recordCircuitBreakerSetup() {
        circuitBreakerSetupCalled = true
    }
    
    func recordConnectionPoolSetup() {
        connectionPoolSetupCalled = true
    }
    
    func recordServicesDiscovered(count: Int) {
        servicesDiscoveredCalled = true
        lastServiceCount = count
    }
    
    func recordServiceDiscoveryFailed(error: Error) {
        serviceDiscoveryFailedCalled = true
        lastError = error
    }
    
    func recordServiceRegistered(serviceId: String) {
        serviceRegisteredCalled = true
        lastServiceId = serviceId
    }
    
    func recordServiceRegistrationFailed(error: Error) {
        serviceRegistrationFailedCalled = true
        lastError = error
    }
    
    func recordLoadBalanced(serviceId: String, strategy: LoadBalancingStrategy) {
        loadBalancedCalled = true
        lastServiceId = serviceId
        lastStrategy = strategy
    }
    
    func recordLoadBalancingFailed(error: Error) {
        loadBalancingFailedCalled = true
        lastError = error
    }
    
    func recordServiceHealthUpdated(serviceId: String, health: ServiceHealth) {
        serviceHealthUpdatedCalled = true
        lastServiceId = serviceId
        lastHealth = health
    }
    
    func recordCircuitBreakerSuccess(serviceId: String) {
        circuitBreakerSuccessCalled = true
        lastServiceId = serviceId
    }
    
    func recordCircuitBreakerFailure(serviceId: String, error: Error) {
        circuitBreakerFailureCalled = true
        lastServiceId = serviceId
        lastError = error
    }
    
    func recordConnectionEstablished(serviceId: String) {
        connectionEstablishedCalled = true
        lastServiceId = serviceId
    }
    
    func recordConnectionFailed(error: Error) {
        connectionFailedCalled = true
        lastError = error
    }
    
    func recordConnectionClosed(serviceId: String) {
        connectionClosedCalled = true
        lastServiceId = serviceId
    }
    
    func recordBatchRequestsCompleted(count: Int) {
        batchRequestsCompletedCalled = true
        lastServiceCount = count
    }
    
    func recordBatchRequestsFailed(errorCount: Int) {
        batchRequestsFailedCalled = true
        lastErrorCount = errorCount
    }
    
    func recordPerformanceMonitoringStarted() {
        performanceMonitoringStartedCalled = true
    }
    
    func recordPerformanceMetricsCollected(metrics: PerformanceMetrics) {
        performanceMetricsCollectedCalled = true
        lastMetrics = metrics
    }
} 