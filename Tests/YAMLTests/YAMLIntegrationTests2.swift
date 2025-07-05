import Testing
@testable import YAML
import Foundation

@Suite("YAML Integration Tests - More Real World Configurations")
struct YAMLIntegrationTests2 {
    
    @Test("Parse Rails database configuration")
    func parseRailsDatabase() throws {
        let url = Bundle.module.url(forResource: "Fixtures/rails-database", withExtension: "yml")!
        let railsDbYAML = try String(contentsOf: url, encoding: .utf8)
        let node = try YAML.parse(railsDbYAML)
        
        guard case .mapping(let root) = node else {
            #expect(Bool(false), "Expected root mapping")
            return
        }
        
        // Check that we have all environments
        #expect(root.keys.contains("default"))
        #expect(root.keys.contains("development"))
        #expect(root.keys.contains("test"))
        #expect(root.keys.contains("production"))
        
        // Check default config
        guard case .mapping(let defaultConfig) = root["default"] else {
            #expect(Bool(false), "Expected default mapping")
            return
        }
        
        #expect(defaultConfig["adapter"]?.string == "postgresql")
        #expect(defaultConfig["encoding"]?.string == "unicode")
        #expect(defaultConfig["timeout"]?.int == 5000)
        
        // Check that development inherits from default
        guard case .mapping(let devConfig) = root["development"] else {
            #expect(Bool(false), "Expected development mapping")
            return
        }
        
        #expect(devConfig["database"]?.string == "myapp_development")
        #expect(devConfig["host"]?.string == "localhost")
        #expect(devConfig["port"]?.int == 5432)
        
        // Note: The <<: *default merge key would need special handling
        // which our parser doesn't currently support
    }
    
    @Test("Parse Swagger/OpenAPI specification")
    func parseSwaggerSpec() throws {
        let url = Bundle.module.url(forResource: "Fixtures/swagger-openapi", withExtension: "yml")!
        let swaggerYAML = try String(contentsOf: url, encoding: .utf8)
        let node = try YAML.parse(swaggerYAML)
        
        guard case .mapping(let root) = node else {
            #expect(Bool(false), "Expected root mapping")
            return
        }
        
        #expect(root["openapi"]?.string == "3.0.0")
        
        // Check info section
        guard case .mapping(let info) = root["info"] else {
            #expect(Bool(false), "Expected info mapping")
            return
        }
        
        #expect(info["title"]?.string == "Sample API")
        #expect(info["version"]?.string == "0.1.9")
        
        // Check servers
        guard case .sequence(let servers) = root["servers"] else {
            #expect(Bool(false), "Expected servers sequence")
            return
        }
        
        #expect(servers.count == 2)
        
        guard case .mapping(let prodServer) = servers.first else {
            #expect(Bool(false), "Expected production server mapping")
            return
        }
        
        #expect(prodServer["url"]?.string == "https://api.example.com/v1")
        #expect(prodServer["description"]?.string == "Production server")
        
        // Check paths
        guard case .mapping(let paths) = root["paths"],
              case .mapping(let usersPath) = paths["/users"] else {
            #expect(Bool(false), "Expected /users path")
            return
        }
        
        #expect(usersPath.keys.contains("get"))
        #expect(usersPath.keys.contains("post"))
        
        // Check GET /users operation
        guard case .mapping(let getUsersOp) = usersPath["get"] else {
            #expect(Bool(false), "Expected GET operation")
            return
        }
        
        #expect(getUsersOp["summary"]?.string == "List all users")
        #expect(getUsersOp["operationId"]?.string == "listUsers")
        
        // Check parameters
        guard case .sequence(let parameters) = getUsersOp["parameters"],
              case .mapping(let limitParam) = parameters.first else {
            #expect(Bool(false), "Expected parameters")
            return
        }
        
        #expect(limitParam["name"]?.string == "limit")
        #expect(limitParam["in"]?.string == "query")
        
        // Check components/schemas
        guard case .mapping(let components) = root["components"],
              case .mapping(let schemas) = components["schemas"],
              case .mapping(let userSchema) = schemas["User"] else {
            #expect(Bool(false), "Expected User schema")
            return
        }
        
        #expect(userSchema["type"]?.string == "object")
        
        guard case .sequence(let requiredFields) = userSchema["required"] else {
            #expect(Bool(false), "Expected required fields")
            return
        }
        
        #expect(requiredFields.contains { $0.string == "id" })
        #expect(requiredFields.contains { $0.string == "name" })
    }
    
    @Test("Parse Serverless Framework configuration")
    func parseServerlessConfig() throws {
        let url = Bundle.module.url(forResource: "Fixtures/serverless-framework", withExtension: "yml")!
        let serverlessYAML = try String(contentsOf: url, encoding: .utf8)
        let node = try YAML.parse(serverlessYAML)
        
        guard case .mapping(let root) = node else {
            #expect(Bool(false), "Expected root mapping")
            return
        }
        
        #expect(root["service"]?.string == "my-service")
        #expect(root["frameworkVersion"]?.string == "3")
        
        // Check provider
        guard case .mapping(let provider) = root["provider"] else {
            #expect(Bool(false), "Expected provider mapping")
            return
        }
        
        #expect(provider["name"]?.string == "aws")
        #expect(provider["runtime"]?.string == "nodejs18.x")
        #expect(provider["memorySize"]?.int == 512)
        #expect(provider["timeout"]?.int == 30)
        
        // Check functions
        guard case .mapping(let functions) = root["functions"] else {
            #expect(Bool(false), "Expected functions mapping")
            return
        }
        
        #expect(functions.keys.contains("hello"))
        #expect(functions.keys.contains("createUser"))
        #expect(functions.keys.contains("processQueue"))
        
        // Check hello function
        guard case .mapping(let helloFunc) = functions["hello"],
              case .sequence(let helloEvents) = helloFunc["events"],
              case .mapping(let httpEvent) = helloEvents.first,
              case .mapping(let httpConfig) = httpEvent["http"] else {
            #expect(Bool(false), "Expected hello function structure")
            return
        }
        
        #expect(helloFunc["handler"]?.string == "handler.hello")
        #expect(httpConfig["path"]?.string == "hello")
        #expect(httpConfig["method"]?.string == "get")
        #expect(httpConfig["cors"]?.bool == true)
        
        // Check resources
        guard case .mapping(let resources) = root["resources"],
              case .mapping(let resourceList) = resources["Resources"],
              case .mapping(let usersTable) = resourceList["UsersTable"] else {
            #expect(Bool(false), "Expected resources")
            return
        }
        
        #expect(usersTable["Type"]?.string == "AWS::DynamoDB::Table")
        
        // Check plugins
        guard case .sequence(let plugins) = root["plugins"] else {
            #expect(Bool(false), "Expected plugins sequence")
            return
        }
        
        #expect(plugins.count == 3)
        #expect(plugins.contains { $0.string == "serverless-webpack" })
        #expect(plugins.contains { $0.string == "serverless-offline" })
    }
    
    @Test("Parse CircleCI configuration")
    func parseCircleCI() throws {
        let url = Bundle.module.url(forResource: "Fixtures/circleci-config", withExtension: "yml")!
        let circleCIYAML = try String(contentsOf: url, encoding: .utf8)
        let node = try YAML.parse(circleCIYAML)
        
        guard case .mapping(let root) = node else {
            #expect(Bool(false), "Expected root mapping")
            return
        }
        
        #expect(root["version"]?.double == 2.1)
        
        // Check orbs
        guard case .mapping(let orbs) = root["orbs"] else {
            #expect(Bool(false), "Expected orbs mapping")
            return
        }
        
        #expect(orbs["node"]?.string == "circleci/node@5.0.2")
        #expect(orbs["aws-cli"]?.string == "circleci/aws-cli@3.1.1")
        
        // Check executors
        guard case .mapping(let executors) = root["executors"],
              case .mapping(let nodeExecutor) = executors["node-executor"],
              case .sequence(let docker) = nodeExecutor["docker"],
              case .mapping(let dockerImage) = docker.first else {
            #expect(Bool(false), "Expected executor structure")
            return
        }
        
        #expect(dockerImage["image"]?.string == "cimg/node:18.0")
        #expect(nodeExecutor["working_directory"]?.string == "~/repo")
        
        // Check jobs
        guard case .mapping(let jobs) = root["jobs"] else {
            #expect(Bool(false), "Expected jobs mapping")
            return
        }
        
        #expect(jobs.keys.contains("test"))
        #expect(jobs.keys.contains("build"))
        #expect(jobs.keys.contains("deploy"))
        
        // Check workflows
        guard case .mapping(let workflows) = root["workflows"],
              case .mapping(let testBuildDeploy) = workflows["test-build-deploy"],
              case .sequence(let workflowJobs) = testBuildDeploy["jobs"] else {
            #expect(Bool(false), "Expected workflows")
            return
        }
        
        #expect(workflows["version"]?.int == 2)
        #expect(workflowJobs.count == 3)
    }
}