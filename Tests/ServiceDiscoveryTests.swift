import XCTest
@testable import ServiceDiscovery

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class ServiceDiscoveryTests: XCTestCase {
    
    var serviceDiscovery: ServiceDiscoveryManager!
    var configuration: ServiceDiscoveryConfiguration!
    
    override func setUp() {
        super.setUp()
        
        configuration = ServiceDiscoveryConfiguration(
            discoveryInterval: 1.0,
            timeout: 5.0,
            maxCacheSize: 100,
            enableHealthChecking: true
        )
        
        serviceDiscovery = ServiceDiscoveryManager(configuration: configuration)
    }
    
    override func tearDown() {
        serviceDiscovery = nil
        configuration = nil
        super.tearDown()
    }
    
    func testServiceRegistration() {
        let expectation = XCTestExpectation(description: "Service registration")
        
        let service = ServiceDefinition(
            name: "test-service",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "instance-1",
                    endpoint: "https://test-service-1.com",
                    host: "test-service-1.com",
                    port: 443
                )
            ]
        )
        
        serviceDiscovery.registerService(service) { result in
            switch result {
            case .success:
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Service registration failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testServiceDiscovery() {
        let expectation = XCTestExpectation(description: "Service discovery")
        
        let service = ServiceDefinition(
            name: "discovery-test",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "instance-1",
                    endpoint: "https://discovery-test-1.com",
                    host: "discovery-test-1.com",
                    port: 443
                )
            ]
        )
        
        serviceDiscovery.registerService(service) { [weak self] result in
            switch result {
            case .success:
                self?.serviceDiscovery.discoverServices { result in
                    switch result {
                    case .success(let services):
                        XCTAssertFalse(services.isEmpty)
                        XCTAssertTrue(services.contains { $0.name == "discovery-test" })
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Service discovery failed: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Service registration failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testGetServiceInstances() {
        let expectation = XCTestExpectation(description: "Get service instances")
        
        let service = ServiceDefinition(
            name: "instances-test",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "instance-1",
                    endpoint: "https://instances-test-1.com",
                    host: "instances-test-1.com",
                    port: 443
                ),
                ServiceInstance(
                    id: "instance-2",
                    endpoint: "https://instances-test-2.com",
                    host: "instances-test-2.com",
                    port: 443
                )
            ]
        )
        
        serviceDiscovery.registerService(service) { [weak self] result in
            switch result {
            case .success:
                self?.serviceDiscovery.getServiceInstances(for: "instances-test") { result in
                    switch result {
                    case .success(let instances):
                        XCTAssertEqual(instances.count, 2)
                        XCTAssertTrue(instances.contains { $0.id == "instance-1" })
                        XCTAssertTrue(instances.contains { $0.id == "instance-2" })
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Failed to get service instances: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Service registration failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testServiceSubscription() {
        let expectation = XCTestExpectation(description: "Service subscription")
        
        let service = ServiceDefinition(
            name: "subscription-test",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "instance-1",
                    endpoint: "https://subscription-test-1.com",
                    host: "subscription-test-1.com",
                    port: 443
                )
            ]
        )
        
        serviceDiscovery.subscribeToService("subscription-test") { instances in
            XCTAssertEqual(instances.count, 1)
            XCTAssertEqual(instances.first?.id, "instance-1")
            expectation.fulfill()
        }
        
        serviceDiscovery.registerService(service) { _ in }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testServiceDeregistration() {
        let expectation = XCTestExpectation(description: "Service deregistration")
        
        let service = ServiceDefinition(
            name: "deregister-test",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "instance-1",
                    endpoint: "https://deregister-test-1.com",
                    host: "deregister-test-1.com",
                    port: 443
                )
            ]
        )
        
        serviceDiscovery.registerService(service) { [weak self] result in
            switch result {
            case .success:
                self?.serviceDiscovery.deregisterService("deregister-test") { result in
                    switch result {
                    case .success:
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Service deregistration failed: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Service registration failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testInvalidServiceName() {
        let expectation = XCTestExpectation(description: "Invalid service name")
        
        let invalidService = ServiceDefinition(
            name: "",
            version: "1.0.0",
            instances: []
        )
        
        serviceDiscovery.registerService(invalidService) { result in
            switch result {
            case .success:
                XCTFail("Should have failed with invalid service name")
            case .failure(let error):
                XCTAssertEqual(error, .invalidServiceName)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testServiceNotFound() {
        let expectation = XCTestExpectation(description: "Service not found")
        
        serviceDiscovery.getServiceInstances(for: "non-existent-service") { result in
            switch result {
            case .success:
                XCTFail("Should have failed with service not found")
            case .failure(let error):
                XCTAssertEqual(error, .serviceNotFound)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConfigurationUpdate() {
        let expectation = XCTestExpectation(description: "Configuration update")
        
        let newConfiguration = ServiceDiscoveryConfiguration(
            discoveryInterval: 60.0,
            timeout: 15.0,
            maxCacheSize: 500,
            enableHealthChecking: false
        )
        
        serviceDiscovery.updateConfiguration(newConfiguration)
        
        // Verify configuration was updated
        XCTAssertEqual(serviceDiscovery.configuration.discoveryInterval, 60.0)
        XCTAssertEqual(serviceDiscovery.configuration.timeout, 15.0)
        XCTAssertEqual(serviceDiscovery.configuration.maxCacheSize, 500)
        XCTAssertFalse(serviceDiscovery.configuration.enableHealthChecking)
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPerformance() {
        let expectation = XCTestExpectation(description: "Performance test")
        
        let startTime = Date()
        
        let service = ServiceDefinition(
            name: "performance-test",
            version: "1.0.0",
            instances: [
                ServiceInstance(
                    id: "instance-1",
                    endpoint: "https://performance-test-1.com",
                    host: "performance-test-1.com",
                    port: 443
                )
            ]
        )
        
        serviceDiscovery.registerService(service) { [weak self] result in
            switch result {
            case .success:
                let endTime = Date()
                let executionTime = endTime.timeIntervalSince(startTime)
                
                // Performance should be under 1 second
                XCTAssertLessThan(executionTime, 1.0)
                expectation.fulfill()
                
            case .failure(let error):
                XCTFail("Performance test failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
} 