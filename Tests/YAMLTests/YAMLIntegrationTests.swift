import Testing
@testable import YAML
import Foundation

@Suite("YAML Integration Tests - Real World Configurations")
struct YAMLIntegrationTests {
    
    @Test("Parse Docker Compose configuration")
    func parseDockerCompose() throws {
        let url = Bundle.module.url(forResource: "Fixtures/docker-compose", withExtension: "yml")!
        let dockerComposeYAML = try String(contentsOf: url, encoding: .utf8)
        let node = try YAML.parse(dockerComposeYAML)
        
        // Verify structure
        guard case .mapping(let root) = node else {
            #expect(Bool(false), "Expected root mapping")
            return
        }
        
        #expect(root["version"]?.string == "3.8")
        
        // Check services
        guard case .mapping(let services) = root["services"] else {
            #expect(Bool(false), "Expected services mapping")
            return
        }
        
        #expect(services.count == 3)
        #expect(services.keys.contains("web"))
        #expect(services.keys.contains("redis"))
        #expect(services.keys.contains("db"))
        
        // Check web service
        guard case .mapping(let web) = services["web"] else {
            #expect(Bool(false), "Expected web service mapping")
            return
        }
        
        #expect(web["build"]?.string == ".")
        
        // Check ports
        guard case .sequence(let webPorts) = web["ports"] else {
            #expect(Bool(false), "Expected ports sequence")
            return
        }
        #expect(webPorts.count == 1)
        #expect(webPorts.first?.string == "5000:5000")
        
        // Check environment
        guard case .mapping(let webEnv) = web["environment"] else {
            #expect(Bool(false), "Expected environment mapping")
            return
        }
        #expect(webEnv["FLASK_ENV"]?.string == "development")
        
        // Test round-trip
        let emitted = YAML.emit(node)
        let reparsed = try YAML.parse(emitted)
        #expect(areNodesEquivalent(node, reparsed))
    }
    
    @Test("Parse Kubernetes deployment")
    func parseKubernetesDeployment() throws {
        let url = Bundle.module.url(forResource: "Fixtures/kubernetes-deployment", withExtension: "yml")!
        let k8sYAML = try String(contentsOf: url, encoding: .utf8)
        let node = try YAML.parse(k8sYAML)
        
        guard case .mapping(let root) = node else {
            #expect(Bool(false), "Expected root mapping")
            return
        }
        
        #expect(root["apiVersion"]?.string == "apps/v1")
        #expect(root["kind"]?.string == "Deployment")
        
        // Check metadata
        guard case .mapping(let metadata) = root["metadata"] else {
            #expect(Bool(false), "Expected metadata mapping")
            return
        }
        #expect(metadata["name"]?.string == "nginx-deployment")
        
        // Check spec
        guard case .mapping(let spec) = root["spec"] else {
            #expect(Bool(false), "Expected spec mapping")
            return
        }
        #expect(spec["replicas"]?.int == 3)
        
        // Check containers
        guard case .mapping(let template) = spec["template"],
              case .mapping(let templateSpec) = template["spec"],
              case .sequence(let containers) = templateSpec["containers"] else {
            #expect(Bool(false), "Expected containers sequence")
            return
        }
        
        #expect(containers.count == 1)
        
        guard case .mapping(let container) = containers.first else {
            #expect(Bool(false), "Expected container mapping")
            return
        }
        
        #expect(container["name"]?.string == "nginx")
        #expect(container["image"]?.string == "nginx:1.14.2")
        
        // Check resources
        guard case .mapping(let resources) = container["resources"],
              case .mapping(let limits) = resources["limits"] else {
            #expect(Bool(false), "Expected resource limits")
            return
        }
        
        #expect(limits["memory"]?.string == "128Mi")
        #expect(limits["cpu"]?.string == "500m")
    }
    
    @Test("Parse GitHub Actions workflow")
    func parseGitHubActions() throws {
        let url = Bundle.module.url(forResource: "Fixtures/github-actions", withExtension: "yml")!
        let githubActionsYAML = try String(contentsOf: url, encoding: .utf8)
        let node = try YAML.parse(githubActionsYAML)
        
        guard case .mapping(let root) = node else {
            #expect(Bool(false), "Expected root mapping")
            return
        }
        
        #expect(root["name"]?.string == "CI")
        
        // Check 'on' triggers
        guard case .mapping(let on) = root["on"] else {
            #expect(Bool(false), "Expected 'on' mapping")
            return
        }
        
        #expect(on.keys.contains("push"))
        #expect(on.keys.contains("pull_request"))
        #expect(on.keys.contains("workflow_dispatch"))
        
        // Check jobs
        guard case .mapping(let jobs) = root["jobs"],
              case .mapping(let testJob) = jobs["test"] else {
            #expect(Bool(false), "Expected test job")
            return
        }
        
        #expect(testJob["name"]?.string == "Test Suite")
        #expect(testJob["runs-on"]?.string == "${{ matrix.os }}")
        
        // Check matrix strategy
        guard case .mapping(let strategy) = testJob["strategy"],
              case .mapping(let matrix) = strategy["matrix"] else {
            #expect(Bool(false), "Expected matrix strategy")
            return
        }
        
        guard case .sequence(let osMatrix) = matrix["os"] else {
            #expect(Bool(false), "Expected OS matrix")
            return
        }
        
        #expect(osMatrix.count == 3)
        #expect(osMatrix.contains { $0.string == "ubuntu-latest" })
        #expect(osMatrix.contains { $0.string == "macos-latest" })
        
        // Check steps
        guard case .sequence(let steps) = testJob["steps"] else {
            #expect(Bool(false), "Expected steps sequence")
            return
        }
        
        #expect(steps.count >= 5)
        
        // Check first step (checkout)
        guard case .mapping(let checkoutStep) = steps.first else {
            #expect(Bool(false), "Expected checkout step")
            return
        }
        
        #expect(checkoutStep["uses"]?.string == "actions/checkout@v3")
    }
    
    @Test("Parse Ansible playbook")
    func parseAnsiblePlaybook() throws {
        let url = Bundle.module.url(forResource: "Fixtures/ansible-playbook", withExtension: "yml")!
        let ansibleYAML = try String(contentsOf: url, encoding: .utf8)
        let nodes = try YAML.parseStream(ansibleYAML)
        #expect(nodes.count == 1)
        
        let node = nodes.first!
        guard case .sequence(let playbooks) = node else {
            #expect(Bool(false), "Expected playbooks sequence")
            return
        }
        
        #expect(playbooks.count == 1)
        
        guard case .mapping(let playbook) = playbooks.first else {
            #expect(Bool(false), "Expected playbook mapping")
            return
        }
        
        #expect(playbook["name"]?.string == "Configure webservers")
        #expect(playbook["hosts"]?.string == "webservers")
        #expect(playbook["become"]?.bool == true)
        
        // Check vars
        guard case .mapping(let vars) = playbook["vars"] else {
            #expect(Bool(false), "Expected vars mapping")
            return
        }
        
        #expect(vars["http_port"]?.int == 80)
        #expect(vars["max_clients"]?.int == 200)
        
        // Check tasks
        guard case .sequence(let tasks) = playbook["tasks"] else {
            #expect(Bool(false), "Expected tasks sequence")
            return
        }
        
        #expect(tasks.count == 5)
        
        // Check first task
        guard case .mapping(let firstTask) = tasks.first else {
            #expect(Bool(false), "Expected first task mapping")
            return
        }
        
        #expect(firstTask["name"]?.string == "Ensure Apache is installed")
        
        // Check package module parameters
        guard case .mapping(let packageParams) = firstTask["package"] else {
            #expect(Bool(false), "Expected package parameters")
            return
        }
        
        #expect(packageParams["state"]?.string == "present")
    }
    
    @Test("Parse Travis CI configuration")
    func parseTravisCI() throws {
        let url = Bundle.module.url(forResource: "Fixtures/travis-ci", withExtension: "yml")!
        let travisYAML = try String(contentsOf: url, encoding: .utf8)
        let node = try YAML.parse(travisYAML)
        
        guard case .mapping(let root) = node else {
            #expect(Bool(false), "Expected root mapping")
            return
        }
        
        #expect(root["language"]?.string == "node_js")
        
        // Check Node.js versions
        guard case .sequence(let nodeVersions) = root["node_js"] else {
            #expect(Bool(false), "Expected node_js sequence")
            return
        }
        
        #expect(nodeVersions.count == 3)
        #expect(nodeVersions.contains { $0.string == "16" })
        #expect(nodeVersions.contains { $0.string == "20" })
        
        // Check cache
        guard case .mapping(let cache) = root["cache"],
              case .sequence(let cacheDirectories) = cache["directories"] else {
            #expect(Bool(false), "Expected cache directories")
            return
        }
        
        #expect(cacheDirectories.count == 2)
        #expect(cacheDirectories.contains { $0.string == "node_modules" })
        
        // Check environment
        guard case .mapping(let env) = root["env"],
              case .sequence(let globalEnv) = env["global"] else {
            #expect(Bool(false), "Expected global environment")
            return
        }
        
        #expect(globalEnv.contains { $0.string == "NODE_ENV=test" })
        
        // Check deploy section
        guard case .mapping(let deploy) = root["deploy"] else {
            #expect(Bool(false), "Expected deploy mapping")
            return
        }
        
        #expect(deploy["provider"]?.string == "npm")
        
        // Check deploy conditions
        guard case .mapping(let deployOn) = deploy["on"] else {
            #expect(Bool(false), "Expected deploy conditions")
            return
        }
        
        #expect(deployOn["tags"]?.bool == true)
        #expect(deployOn["node"]?.string == "18")
    }
    
    // Helper function to compare nodes (ignoring key order in mappings)
    private func areNodesEquivalent(_ lhs: YAMLNode, _ rhs: YAMLNode) -> Bool {
        switch (lhs, rhs) {
        case (.scalar(let l), .scalar(let r)):
            return l.value == r.value && l.tag == r.tag
            
        case (.sequence(let l), .sequence(let r)):
            guard l.count == r.count else { return false }
            return zip(l, r).allSatisfy { areNodesEquivalent($0, $1) }
            
        case (.mapping(let l), .mapping(let r)):
            guard l.count == r.count else { return false }
            for (key, lValue) in l {
                guard let rValue = r[key] else { return false }
                if !areNodesEquivalent(lValue, rValue) { return false }
            }
            return true
            
        default:
            return false
        }
    }
}