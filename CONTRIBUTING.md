# Contributing to iOS Microservices Client Framework

Thank you for your interest in contributing to the iOS Microservices Client Framework! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

We welcome contributions from the community! Here are the main ways you can contribute:

### 🐛 Bug Reports

If you find a bug, please report it by creating an issue with the following information:

- **Description**: Clear description of the bug
- **Steps to Reproduce**: Detailed steps to reproduce the issue
- **Expected Behavior**: What you expected to happen
- **Actual Behavior**: What actually happened
- **Environment**: iOS version, device, framework version
- **Code Example**: Minimal code example that reproduces the issue
- **Screenshots**: If applicable, include screenshots or logs

### 💡 Feature Requests

We welcome feature requests! Please include:

- **Description**: Clear description of the feature
- **Use Case**: Why this feature is needed
- **Proposed Implementation**: How you think it should work
- **Alternatives**: Any alternatives you've considered

### 🔧 Code Contributions

We welcome code contributions! Please follow these guidelines:

## 🛠 Development Setup

### Prerequisites

- Xcode 15.0+
- iOS 15.0+ SDK
- Swift 5.9+
- Git

### Getting Started

1. **Fork the repository**
   ```bash
   git clone https://github.com/your-username/iOS-Microservices-Client-Framework.git
   cd iOS-Microservices-Client-Framework
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Set up the development environment**
   ```bash
   swift package resolve
   swift build
   ```

4. **Run tests**
   ```bash
   swift test
   ```

## 📝 Coding Standards

### Swift Style Guide

We follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) and [Google Swift Style Guide](https://google.github.io/swift/).

#### Code Style

- Use 4 spaces for indentation
- Maximum line length: 120 characters
- Use meaningful variable and function names
- Add comprehensive documentation comments

#### Naming Conventions

```swift
// ✅ Good
class ServiceDiscoveryManager {
    func registerService(_ service: ServiceDefinition) { }
    let configuration: ServiceDiscoveryConfiguration
}

// ❌ Bad
class serviceDiscoveryManager {
    func register_service(_ service: serviceDefinition) { }
    let config: serviceDiscoveryConfiguration
}
```

#### Documentation

All public APIs must be documented:

```swift
/// Manages service discovery for microservices architecture
/// 
/// This class provides automatic service registration and discovery capabilities
/// with health-based filtering and real-time updates.
/// 
/// ## Example Usage
/// ```swift
/// let manager = ServiceDiscoveryManager(configuration: config)
/// manager.registerService(service) { result in
///     // Handle result
/// }
/// ```
/// 
/// - Note: This class is thread-safe and can be used from multiple threads
/// - Important: Always call `stopMonitoring()` when done to prevent memory leaks
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public final class ServiceDiscoveryManager {
    
    /// Register a service with the discovery system
    /// 
    /// - Parameters:
    ///   - service: The service definition to register
    ///   - completion: Completion handler called with the result
    /// 
    /// - Throws: `ServiceDiscoveryError.invalidServiceName` if service name is empty
    /// 
    /// ## Example
    /// ```swift
    /// let service = ServiceDefinition(name: "user-service", version: "1.0.0", instances: [])
    /// manager.registerService(service) { result in
    ///     switch result {
    ///     case .success:
    ///         print("Service registered successfully")
    ///     case .failure(let error):
    ///         print("Registration failed: \(error)")
    ///     }
    /// }
    /// ```
    public func registerService(_ service: ServiceDefinition, completion: @escaping (Result<Void, ServiceDiscoveryError>) -> Void) {
        // Implementation
    }
}
```

### Architecture Guidelines

#### Clean Architecture

Follow Clean Architecture principles:

- **Entities**: Core business objects
- **Use Cases**: Application-specific business rules
- **Interface Adapters**: Controllers, presenters, gateways
- **Frameworks & Drivers**: External frameworks, databases, UI

#### SOLID Principles

- **Single Responsibility**: Each class has one reason to change
- **Open/Closed**: Open for extension, closed for modification
- **Liskov Substitution**: Subtypes are substitutable
- **Interface Segregation**: Many specific interfaces over one general
- **Dependency Inversion**: Depend on abstractions, not concretions

#### Error Handling

Use comprehensive error handling:

```swift
public enum MicroservicesError: Error, LocalizedError {
    case circuitBreakerOpen
    case noServiceInstances
    case invalidEndpoint
    case encodingError
    case decodingError
    case noData
    case networkError(Error)
    case serviceDiscoveryError(String)
    case loadBalancingError(String)
    case healthMonitoringError(String)
    
    public var errorDescription: String? {
        switch self {
        case .circuitBreakerOpen:
            return "Circuit breaker is open for this service"
        case .noServiceInstances:
            return "No service instances available"
        case .invalidEndpoint:
            return "Invalid service endpoint"
        case .encodingError:
            return "Failed to encode request"
        case .decodingError:
            return "Failed to decode response"
        case .noData:
            return "No data received from service"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serviceDiscoveryError(let message):
            return "Service discovery error: \(message)"
        case .loadBalancingError(let message):
            return "Load balancing error: \(message)"
        case .healthMonitoringError(let message):
            return "Health monitoring error: \(message)"
        }
    }
}
```

## 🧪 Testing

### Test Requirements

- **Unit Tests**: 100% coverage for all public APIs
- **Integration Tests**: Test module interactions
- **Performance Tests**: Load and stress testing
- **Error Handling Tests**: Failure scenario testing

### Test Structure

```swift
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
}
```

### Running Tests

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter ServiceDiscoveryTests

# Run with verbose output
swift test --verbose

# Run performance tests
swift test --filter PerformanceTests
```

## 📋 Pull Request Process

### Before Submitting

1. **Ensure code quality**
   - Follow coding standards
   - Add comprehensive tests
   - Update documentation
   - Check for memory leaks

2. **Run tests locally**
   ```bash
   swift test
   swift build
   ```

3. **Update documentation**
   - Update README.md if needed
   - Add code examples
   - Update API documentation

4. **Check performance**
   - Run performance tests
   - Ensure no performance regressions
   - Optimize if necessary

### Pull Request Guidelines

1. **Create a descriptive title**
   - Use conventional commit format
   - Be specific about the change

2. **Provide detailed description**
   - What the change does
   - Why the change is needed
   - How it was implemented
   - Any breaking changes

3. **Include tests**
   - Unit tests for new functionality
   - Integration tests if needed
   - Performance tests if applicable

4. **Update documentation**
   - API documentation
   - README updates
   - Example code

### Pull Request Template

```markdown
## Description

Brief description of the changes.

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Performance improvement

## Testing

- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Performance tests pass
- [ ] Manual testing completed

## Checklist

- [ ] Code follows the style guidelines
- [ ] Self-review of code completed
- [ ] Code is documented
- [ ] Tests are added and pass
- [ ] Documentation is updated
- [ ] No breaking changes (or breaking changes are documented)

## Additional Notes

Any additional information or context.
```

## 🏷️ Commit Message Guidelines

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, etc.)
- **refactor**: Code refactoring
- **test**: Adding or updating tests
- **chore**: Maintenance tasks

### Examples

```
feat(service-discovery): add support for custom health checks

Add ability to configure custom health check endpoints and intervals
for service instances. This allows more flexible health monitoring
for different service types.

Closes #123
```

```
fix(load-balancer): resolve race condition in instance selection

Fix intermittent issue where load balancer could select unavailable
instances due to race condition in health status updates.

Fixes #456
```

## 🚀 Release Process

### Version Bumping

We use [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Release Checklist

- [ ] All tests pass
- [ ] Documentation is updated
- [ ] CHANGELOG.md is updated
- [ ] Version is bumped
- [ ] Release notes are written
- [ ] Tag is created
- [ ] Release is published

## 🤝 Community Guidelines

### Code of Conduct

We are committed to providing a welcoming and inclusive environment for all contributors.

### Communication

- Be respectful and constructive
- Use clear and concise language
- Provide context for suggestions
- Ask questions when needed

### Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- GitHub contributors page

## 📞 Getting Help

- **Issues**: [GitHub Issues](https://github.com/muhittincamdali/iOS-Microservices-Client-Framework/issues)
- **Discussions**: [GitHub Discussions](https://github.com/muhittincamdali/iOS-Microservices-Client-Framework/discussions)
- **Documentation**: [Wiki](https://github.com/muhittincamdali/iOS-Microservices-Client-Framework/wiki)

## 🙏 Thank You

Thank you for contributing to the iOS Microservices Client Framework! Your contributions help make this framework better for the entire iOS development community.

---

*This contributing guide is inspired by best practices from the open source community and adapted for our specific project needs.* 