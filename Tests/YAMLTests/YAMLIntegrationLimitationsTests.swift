import Testing
@testable import YAML
import Foundation

@Suite("YAML Integration Tests - Parser Limitations")
struct YAMLIntegrationLimitationsTests {
    
    @Test("Document parser now supports flexible sequence indentation")
    func documentFlexibleSequenceIndentation() throws {
        // Our parser now supports the YAML spec's flexible indentation rules
        
        // Common YAML pattern that now works:
        let commonPattern = """
        parent:
          key:
          - item1
          - item2
        """
        
        // This should now parse successfully
        let node1 = try YAML.parse(commonPattern)
        guard case .mapping(let root1) = node1,
              case .mapping(let parent1) = root1["parent"],
              case .sequence(let items1) = parent1["key"] else {
            #expect(Bool(false))
            return
        }
        
        #expect(items1.count == 2)
        #expect(items1[0].string == "item1")
        #expect(items1[1].string == "item2")
        
        // The indented format also still works:
        let indentedPattern = """
        parent:
          key:
            - item1
            - item2
        """
        
        let node2 = try YAML.parse(indentedPattern)
        guard case .mapping(let root2) = node2,
              case .mapping(let parent2) = root2["parent"],
              case .sequence(let items2) = parent2["key"] else {
            #expect(Bool(false))
            return
        }
        
        #expect(items2.count == 2)
    }
    
    @Test("CircleCI config with adjusted indentation")
    func parseCircleCIAdjusted() throws {
        // This is a simplified CircleCI config that works with our parser
        let circleCIYAML = """
        version: 2.1
        
        orbs:
          node: circleci/node@5.0.2
        
        executors:
          node-executor:
            docker:
              - image: cimg/node:18.0
        
        commands:
          install-deps:
            description: Install npm dependencies
            steps:
              - restore_cache:
                  keys:
                    - v1-dependencies-{{ checksum "package-lock.json" }}
              - run:
                  name: Install Dependencies
                  command: npm ci
        
        jobs:
          test:
            executor: node-executor
            steps:
              - checkout
              - install-deps
        """
        
        let node = try YAML.parse(circleCIYAML)
        
        guard case .mapping(let root) = node else {
            #expect(Bool(false))
            return
        }
        
        #expect(root["version"]?.double == 2.1)
        
        // Check commands
        guard case .mapping(let commands) = root["commands"],
              case .mapping(let installDeps) = commands["install-deps"],
              case .sequence(let steps) = installDeps["steps"] else {
            #expect(Bool(false))
            return
        }
        
        #expect(steps.count == 2)
    }
    
    @Test("Serverless Framework config with adjusted indentation")
    func parseServerlessAdjusted() throws {
        // This is a simplified Serverless config that works with our parser
        let serverlessYAML = """
        service: my-service
        frameworkVersion: '3'
        
        provider:
          name: aws
          runtime: nodejs18.x
          environment:
            NODE_ENV: production
            TABLE_NAME: ${self:service}-table
        
        functions:
          hello:
            handler: handler.hello
            events:
              - http:
                  path: hello
                  method: get
                  cors: true
        
          createUser:
            handler: handler.createUser
            events:
              - http:
                  path: users
                  method: post
        """
        
        let node = try YAML.parse(serverlessYAML)
        
        guard case .mapping(let root) = node else {
            #expect(Bool(false))
            return
        }
        
        #expect(root["service"]?.string == "my-service")
        
        // Check functions
        guard case .mapping(let functions) = root["functions"],
              case .mapping(let hello) = functions["hello"],
              case .sequence(let helloEvents) = hello["events"] else {
            #expect(Bool(false))
            return
        }
        
        #expect(helloEvents.count == 1)
    }
}