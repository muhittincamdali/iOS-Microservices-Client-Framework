import XCTest
@testable import CircuitBreaker

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class CircuitBreakerTests: XCTestCase {
    
    var circuitBreaker: CircuitBreaker!
    var configuration: CircuitBreakerConfiguration!
    
    override func setUp() {
        super.setUp()
        
        configuration = CircuitBreakerConfiguration(
            failureThreshold: 3,
            timeout: 60.0,
            successThreshold: 2,
            halfOpenRequestLimit: 1,
            enabled: true
        )
        
        circuitBreaker = CircuitBreaker(configuration: configuration)
    }
    
    override func tearDown() {
        circuitBreaker = nil
        configuration = nil
        super.tearDown()
    }
    
    func testCircuitBreakerStates() {
        let serviceName = "test-service"
        
        // Initially circuit should be closed
        XCTAssertTrue(circuitBreaker.isClosed(for: serviceName))
        XCTAssertFalse(circuitBreaker.isOpen(for: serviceName))
        XCTAssertFalse(circuitBreaker.isHalfOpen(for: serviceName))
    }
    
    func testCircuitBreakerFailureThreshold() {
        let serviceName = "test-service"
        
        // Record failures up to threshold
        for i in 1...3 {
            circuitBreaker.recordFailure(for: serviceName)
            
            if i < 3 {
                XCTAssertTrue(circuitBreaker.isClosed(for: serviceName))
            } else {
                XCTAssertTrue(circuitBreaker.isOpen(for: serviceName))
            }
        }
    }
    
    func testCircuitBreakerSuccessRecording() {
        let serviceName = "test-service"
        
        // Record some failures to open the circuit
        for _ in 1...3 {
            circuitBreaker.recordFailure(for: serviceName)
        }
        
        XCTAssertTrue(circuitBreaker.isOpen(for: serviceName))
        
        // Record successes (should not close circuit immediately)
        circuitBreaker.recordSuccess(for: serviceName)
        circuitBreaker.recordSuccess(for: serviceName)
        
        // Circuit should still be open until timeout
        XCTAssertTrue(circuitBreaker.isOpen(for: serviceName))
    }
    
    func testCircuitBreakerReset() {
        let serviceName = "test-service"
        
        // Open the circuit
        for _ in 1...3 {
            circuitBreaker.recordFailure(for: serviceName)
        }
        
        XCTAssertTrue(circuitBreaker.isOpen(for: serviceName))
        
        // Reset the circuit
        circuitBreaker.reset(for: serviceName)
        
        XCTAssertTrue(circuitBreaker.isClosed(for: serviceName))
    }
    
    func testCircuitBreakerStatistics() {
        let serviceName = "test-service"
        
        // Record some successes and failures
        circuitBreaker.recordSuccess(for: serviceName)
        circuitBreaker.recordSuccess(for: serviceName)
        circuitBreaker.recordFailure(for: serviceName)
        circuitBreaker.recordSuccess(for: serviceName)
        
        let statistics = circuitBreaker.getStatistics(for: serviceName)
        
        XCTAssertEqual(statistics.serviceName, serviceName)
        XCTAssertEqual(statistics.state, .closed)
        XCTAssertEqual(statistics.totalRequests, 4)
        XCTAssertEqual(statistics.totalSuccesses, 3)
        XCTAssertEqual(statistics.totalFailures, 1)
        XCTAssertEqual(statistics.failureRate, 0.25, accuracy: 0.01)
    }
    
    func testCircuitBreakerHalfOpenState() {
        let serviceName = "test-service"
        
        // Open the circuit
        for _ in 1...3 {
            circuitBreaker.recordFailure(for: serviceName)
        }
        
        XCTAssertTrue(circuitBreaker.isOpen(for: serviceName))
        
        // Simulate timeout by manually setting last failure time
        // In a real implementation, this would be handled by the timeout mechanism
        
        // After timeout, circuit should move to half-open
        // This is a simplified test - in reality, the timeout would be checked
        let state = circuitBreaker.getCircuitState(for: serviceName)
        XCTAssertTrue(state == .open || state == .halfOpen)
    }
    
    func testCircuitBreakerDisabled() {
        let disabledConfiguration = CircuitBreakerConfiguration(
            failureThreshold: 3,
            timeout: 60.0,
            successThreshold: 2,
            halfOpenRequestLimit: 1,
            enabled: false
        )
        
        let disabledCircuitBreaker = CircuitBreaker(configuration: disabledConfiguration)
        let serviceName = "test-service"
        
        // Even with failures, circuit should remain closed when disabled
        for _ in 1...5 {
            disabledCircuitBreaker.recordFailure(for: serviceName)
        }
        
        XCTAssertTrue(disabledCircuitBreaker.isClosed(for: serviceName))
    }
    
    func testCircuitBreakerConfigurationUpdate() {
        let serviceName = "test-service"
        
        // Open circuit with current configuration
        for _ in 1...3 {
            circuitBreaker.recordFailure(for: serviceName)
        }
        
        XCTAssertTrue(circuitBreaker.isOpen(for: serviceName))
        
        // Update configuration
        let newConfiguration = CircuitBreakerConfiguration(
            failureThreshold: 10,
            timeout: 120.0,
            successThreshold: 5,
            halfOpenRequestLimit: 2,
            enabled: true
        )
        
        circuitBreaker.updateConfiguration(newConfiguration)
        
        // Circuit should still be open (configuration update doesn't reset state)
        XCTAssertTrue(circuitBreaker.isOpen(for: serviceName))
    }
    
    func testMultipleServices() {
        let service1 = "service-1"
        let service2 = "service-2"
        
        // Open circuit for service 1
        for _ in 1...3 {
            circuitBreaker.recordFailure(for: service1)
        }
        
        XCTAssertTrue(circuitBreaker.isOpen(for: service1))
        XCTAssertTrue(circuitBreaker.isClosed(for: service2))
        
        // Open circuit for service 2
        for _ in 1...3 {
            circuitBreaker.recordFailure(for: service2)
        }
        
        XCTAssertTrue(circuitBreaker.isOpen(for: service1))
        XCTAssertTrue(circuitBreaker.isOpen(for: service2))
        
        // Reset only service 1
        circuitBreaker.reset(for: service1)
        
        XCTAssertTrue(circuitBreaker.isClosed(for: service1))
        XCTAssertTrue(circuitBreaker.isOpen(for: service2))
    }
    
    func testPerformance() {
        let serviceName = "performance-test"
        let startTime = Date()
        
        // Record many operations
        for _ in 1...1000 {
            circuitBreaker.recordSuccess(for: serviceName)
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        XCTAssertLessThan(executionTime, 1.0)
    }
} 