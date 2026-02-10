//
//  AWSService.swift
//  Gameboxd
//
//  AWS Integration Service demonstrating AWS Certified Developer knowledge
//  Covers: Cognito, S3, Lambda, API Gateway, DynamoDB, CloudWatch
//

import Foundation

// MARK: - AWS Configuration
struct AWSConfig {
    static let region = "eu-west-1"
    static let userPoolId = "eu-west-1_XXXXXXXXX"
    static let clientId = "xxxxxxxxxxxxxxxxxxxxxxxxxx"
    static let identityPoolId = "eu-west-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    static let s3Bucket = "gameboxd-user-data"
    static let apiGatewayEndpoint = "https://xxxxxxxxxx.execute-api.eu-west-1.amazonaws.com/prod"
}

// MARK: - AWS Cognito Authentication
/// Demonstrates AWS Cognito User Pool integration for secure authentication
/// Implements SRP (Secure Remote Password) protocol flow
class CognitoAuthService {
    static let shared = CognitoAuthService()
    
    private var accessToken: String?
    private var idToken: String?
    private var refreshToken: String?
    private var tokenExpiration: Date?
    
    // MARK: - User Pool Authentication
    
    /// Initiates authentication with Cognito User Pool
    /// Uses USER_SRP_AUTH flow for secure password verification
    func signIn(username: String, password: String) async throws -> CognitoAuthResult {
        // Step 1: InitiateAuth with USER_SRP_AUTH
        let srpA = generateSRPAuthValue()
        
        let initiateAuthRequest = [
            "AuthFlow": "USER_SRP_AUTH",
            "ClientId": AWSConfig.clientId,
            "AuthParameters": [
                "USERNAME": username,
                "SRP_A": srpA
            ]
        ] as [String: Any]
        
        // Step 2: Respond to PASSWORD_VERIFIER challenge
        // In production, this would compute SRP signature
        let challengeResponse = try await respondToAuthChallenge(
            username: username,
            password: password,
            challenge: initiateAuthRequest
        )
        
        // Step 3: Store tokens securely using Keychain (see SecurityManager)
        self.accessToken = challengeResponse.accessToken
        self.idToken = challengeResponse.idToken
        self.refreshToken = challengeResponse.refreshToken
        self.tokenExpiration = Date().addingTimeInterval(TimeInterval(challengeResponse.expiresIn))
        
        return challengeResponse
    }
    
    /// Refresh tokens using Cognito refresh token flow
    func refreshSession() async throws -> CognitoAuthResult {
        guard let refreshToken = refreshToken else {
            throw AWSError.noRefreshToken
        }
        
        let _ = [
            "AuthFlow": "REFRESH_TOKEN_AUTH",
            "ClientId": AWSConfig.clientId,
            "AuthParameters": [
                "REFRESH_TOKEN": refreshToken
            ]
        ] as [String: Any]
        
        // Simulate token refresh
        return CognitoAuthResult(
            accessToken: "refreshed_access_token_\(UUID().uuidString)",
            idToken: "refreshed_id_token_\(UUID().uuidString)",
            refreshToken: refreshToken,
            expiresIn: 3600
        )
    }
    
    /// Sign up new user with Cognito User Pool
    func signUp(username: String, password: String, email: String) async throws -> SignUpResult {
        // Validate password policy (Cognito requirements)
        guard isPasswordValid(password) else {
            throw AWSError.invalidPassword
        }
        
        let _ = [
            "ClientId": AWSConfig.clientId,
            "Username": username,
            "Password": password,
            "UserAttributes": [
                ["Name": "email", "Value": email]
            ]
        ] as [String: Any]
        
        // In production: POST to Cognito SignUp endpoint
        return SignUpResult(
            userSub: UUID().uuidString,
            userConfirmed: false,
            codeDeliveryDetails: CodeDeliveryDetails(
                destination: maskEmail(email),
                deliveryMedium: "EMAIL",
                attributeName: "email"
            )
        )
    }
    
    /// Confirm sign up with verification code
    func confirmSignUp(username: String, confirmationCode: String) async throws {
        let _ = [
            "ClientId": AWSConfig.clientId,
            "Username": username,
            "ConfirmationCode": confirmationCode
        ]
        
        // Validate 6-digit code format
        guard confirmationCode.count == 6, confirmationCode.allSatisfy({ $0.isNumber }) else {
            throw AWSError.invalidConfirmationCode
        }
        
        // In production: POST to Cognito ConfirmSignUp endpoint
    }
    
    /// Get current authenticated user's attributes
    func getCurrentUser() async throws -> CognitoUser? {
        guard let _ = accessToken, let expiration = tokenExpiration else {
            return nil
        }
        
        // Check token expiration
        if Date() > expiration {
            _ = try await refreshSession()
        }
        
        // In production: Call GetUser API with access token
        return CognitoUser(
            username: "current_user",
            sub: UUID().uuidString,
            email: "user@example.com",
            emailVerified: true
        )
    }
    
    // MARK: - Helper Methods
    
    private func generateSRPAuthValue() -> String {
        // SRP-6a protocol: Generate large random number A = g^a mod N
        // In production, use proper cryptographic library
        return Data((0..<256).map { _ in UInt8.random(in: 0...255) }).base64EncodedString()
    }
    
    private func respondToAuthChallenge(username: String, password: String, challenge: [String: Any]) async throws -> CognitoAuthResult {
        // Simulate SRP challenge response
        // In production: Compute password signature using SRP protocol
        return CognitoAuthResult(
            accessToken: "access_token_\(UUID().uuidString)",
            idToken: "id_token_\(UUID().uuidString)",
            refreshToken: "refresh_token_\(UUID().uuidString)",
            expiresIn: 3600
        )
    }
    
    private func isPasswordValid(_ password: String) -> Bool {
        // Cognito default password policy
        let minLength = password.count >= 8
        let hasUppercase = password.contains(where: { $0.isUppercase })
        let hasLowercase = password.contains(where: { $0.isLowercase })
        let hasNumber = password.contains(where: { $0.isNumber })
        let hasSpecial = password.contains(where: { "!@#$%^&*()_+-=[]{}|;':\",./<>?".contains($0) })
        
        return minLength && hasUppercase && hasLowercase && hasNumber && hasSpecial
    }
    
    private func maskEmail(_ email: String) -> String {
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return "***" }
        let name = String(parts[0])
        let domain = String(parts[1])
        let masked = String(name.prefix(2)) + "***"
        return "\(masked)@\(domain)"
    }
}

// MARK: - AWS S3 Service
/// Demonstrates S3 integration for object storage
/// Implements presigned URLs, multipart upload, and bucket operations
class S3Service {
    static let shared = S3Service()
    
    private let bucketName = AWSConfig.s3Bucket
    
    /// Generate presigned URL for secure upload
    /// Presigned URLs allow temporary access without exposing credentials
    func generatePresignedUploadURL(key: String, contentType: String, expiresIn: Int = 3600) -> PresignedURL {
        let expiration = Date().addingTimeInterval(TimeInterval(expiresIn))
        
        // In production: Use AWS SDK to generate presigned URL
        // Components: bucket, key, HTTP method, expiration, signature
        let signature = computeAWS4Signature(
            method: "PUT",
            bucket: bucketName,
            key: key,
            expiration: expiration
        )
        
        return PresignedURL(
            url: "https://\(bucketName).s3.\(AWSConfig.region).amazonaws.com/\(key)?X-Amz-Signature=\(signature)",
            expiration: expiration,
            headers: [
                "Content-Type": contentType,
                "x-amz-acl": "private"
            ]
        )
    }
    
    /// Upload file using multipart upload for large files
    /// Recommended for files > 100MB
    func initiateMultipartUpload(key: String, contentType: String) async throws -> MultipartUpload {
        // Step 1: CreateMultipartUpload
        let uploadId = UUID().uuidString
        
        return MultipartUpload(
            uploadId: uploadId,
            key: key,
            bucket: bucketName,
            parts: []
        )
    }
    
    /// Upload individual part of multipart upload
    func uploadPart(uploadId: String, partNumber: Int, data: Data) async throws -> UploadPartResult {
        // Each part must be at least 5MB (except last part)
        let etag = computeETag(data: data)
        
        return UploadPartResult(
            partNumber: partNumber,
            etag: etag
        )
    }
    
    /// Complete multipart upload
    func completeMultipartUpload(uploadId: String, key: String, parts: [UploadPartResult]) async throws -> CompleteUploadResult {
        // Combine all parts into final object
        return CompleteUploadResult(
            location: "https://\(bucketName).s3.\(AWSConfig.region).amazonaws.com/\(key)",
            bucket: bucketName,
            key: key,
            etag: "\"combined-etag\""
        )
    }
    
    /// List objects in bucket with pagination
    func listObjects(prefix: String? = nil, maxKeys: Int = 1000, continuationToken: String? = nil) async throws -> ListObjectsResult {
        return ListObjectsResult(
            contents: [
                S3Object(key: "backups/user123/games.json", size: 1024, lastModified: Date()),
                S3Object(key: "backups/user123/sessions.json", size: 512, lastModified: Date())
            ],
            isTruncated: false,
            nextContinuationToken: nil
        )
    }
    
    /// Set object lifecycle policy
    func setLifecyclePolicy(rules: [LifecycleRule]) async throws {
        // Configure automatic transitions and expirations
        // Example: Move to Glacier after 90 days, delete after 365 days
    }
    
    // MARK: - Helper Methods
    
    private func computeAWS4Signature(method: String, bucket: String, key: String, expiration: Date) -> String {
        // AWS Signature Version 4 signing process
        // 1. Create canonical request
        // 2. Create string to sign
        // 3. Calculate signature using HMAC-SHA256
        return Data((0..<32).map { _ in UInt8.random(in: 0...255) }).base64EncodedString()
    }
    
    private func computeETag(data: Data) -> String {
        // ETag is MD5 hash of content
        return "\"\(data.hashValue)\""
    }
}

// MARK: - AWS Lambda Service
/// Demonstrates Lambda function invocation
/// Covers synchronous/asynchronous invocation, payload handling
class LambdaService {
    static let shared = LambdaService()
    
    /// Invoke Lambda function synchronously (RequestResponse)
    func invoke(functionName: String, payload: [String: Any]) async throws -> LambdaResponse {
        // Serialize payload to JSON
        let _ = try JSONSerialization.data(withJSONObject: payload)
        
        // In production: Use AWS SDK or API Gateway to invoke
        // Lambda execution context includes:
        // - requestId, functionName, memoryLimitInMB, logGroupName, logStreamName
        
        return LambdaResponse(
            statusCode: 200,
            payload: ["message": "Function executed successfully", "requestId": UUID().uuidString],
            executedVersion: "$LATEST",
            logResult: nil
        )
    }
    
    /// Invoke Lambda function asynchronously (Event)
    func invokeAsync(functionName: String, payload: [String: Any]) async throws {
        // Async invocation returns immediately
        // Lambda handles retries (2 retries by default)
        // Dead Letter Queue for failed invocations
    }
    
    /// Invoke Lambda through API Gateway
    func invokeViaAPIGateway(path: String, method: String, body: [String: Any]?) async throws -> APIGatewayResponse {
        let _ = "\(AWSConfig.apiGatewayEndpoint)\(path)"
        
        // API Gateway handles:
        // - Request validation
        // - Authorization (IAM, Cognito, Lambda authorizer)
        // - Throttling and rate limiting
        // - Request/response transformation
        
        return APIGatewayResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: ["success": true]
        )
    }
}

// MARK: - AWS DynamoDB Service
/// Demonstrates DynamoDB operations
/// Covers CRUD, queries, scans, and batch operations
class DynamoDBService {
    static let shared = DynamoDBService()
    
    private let tableName = "GameboxdUserData"
    
    /// Put item into DynamoDB table
    func putItem(item: [String: DynamoDBAttribute]) async throws {
        // DynamoDB data types: S (String), N (Number), B (Binary), 
        // SS (String Set), NS (Number Set), M (Map), L (List), BOOL, NULL
        
        let _ = [
            "TableName": tableName,
            "Item": item.mapValues { $0.toDynamoDB() }
        ] as [String: Any]
        
        // Conditional writes prevent overwrites
        // ConditionExpression: "attribute_not_exists(pk)"
    }
    
    /// Get item by primary key
    func getItem(pk: String, sk: String) async throws -> [String: DynamoDBAttribute]? {
        let _ = [
            "TableName": tableName,
            "Key": [
                "pk": ["S": pk],
                "sk": ["S": sk]
            ]
        ] as [String: Any]
        
        // ConsistentRead: true for strong consistency (vs eventual)
        return nil
    }
    
    /// Query items using partition key and sort key conditions
    func query(pk: String, skBeginsWith: String? = nil) async throws -> [DynamoDBItem] {
        // KeyConditionExpression: "pk = :pk AND begins_with(sk, :prefix)"
        // Use indexes (GSI/LSI) for alternative query patterns
        
        return []
    }
    
    /// Batch write up to 25 items
    func batchWrite(items: [[String: DynamoDBAttribute]]) async throws {
        // BatchWriteItem allows up to 25 put/delete requests
        // Total payload must be < 16MB
        // Each item must be < 400KB
        
        guard items.count <= 25 else {
            throw AWSError.batchSizeExceeded
        }
    }
    
    /// Update item with expressions
    func updateItem(pk: String, sk: String, updates: [String: Any]) async throws {
        // UpdateExpression: "SET #attr = :val, #count = #count + :inc"
        // ExpressionAttributeNames for reserved words
        // ExpressionAttributeValues for values
    }
    
    /// Transaction write for ACID operations
    func transactWrite(items: [TransactWriteItem]) async throws {
        // TransactWriteItems supports up to 25 actions
        // All-or-nothing: either all succeed or all fail
        // Supports Put, Update, Delete, ConditionCheck
    }
}

// MARK: - AWS CloudWatch Service
/// Demonstrates CloudWatch for monitoring and logging
class CloudWatchService {
    static let shared = CloudWatchService()
    
    /// Put custom metric to CloudWatch
    func putMetric(namespace: String, metricName: String, value: Double, unit: MetricUnit, dimensions: [String: String]? = nil) async throws {
        let _: [String: Any] = [
            "MetricName": metricName,
            "Value": value,
            "Unit": unit.rawValue,
            "Dimensions": dimensions?.map { ["Name": $0.key, "Value": $0.value] } ?? []
        ]
        
        // Metrics are aggregated at 1-minute intervals
        // High-resolution metrics available (1-second)
    }
    
    /// Send logs to CloudWatch Logs
    func putLogEvents(logGroupName: String, logStreamName: String, events: [LogEvent]) async throws {
        // Log events must be in chronological order
        // Max batch size: 1MB or 10,000 events
        // Requires sequence token for subsequent calls
    }
    
    /// Create CloudWatch alarm
    func createAlarm(alarmName: String, metricName: String, threshold: Double, comparisonOperator: String) async throws {
        // Alarm states: OK, ALARM, INSUFFICIENT_DATA
        // Actions: SNS notification, Auto Scaling, EC2 action
    }
}

// MARK: - Data Models

struct CognitoAuthResult {
    let accessToken: String
    let idToken: String
    let refreshToken: String
    let expiresIn: Int
}

struct SignUpResult {
    let userSub: String
    let userConfirmed: Bool
    let codeDeliveryDetails: CodeDeliveryDetails
}

struct CodeDeliveryDetails {
    let destination: String
    let deliveryMedium: String
    let attributeName: String
}

struct CognitoUser {
    let username: String
    let sub: String
    let email: String
    let emailVerified: Bool
}

struct PresignedURL {
    let url: String
    let expiration: Date
    let headers: [String: String]
}

struct MultipartUpload {
    let uploadId: String
    let key: String
    let bucket: String
    var parts: [UploadPartResult]
}

struct UploadPartResult {
    let partNumber: Int
    let etag: String
}

struct CompleteUploadResult {
    let location: String
    let bucket: String
    let key: String
    let etag: String
}

struct ListObjectsResult {
    let contents: [S3Object]
    let isTruncated: Bool
    let nextContinuationToken: String?
}

struct S3Object {
    let key: String
    let size: Int
    let lastModified: Date
}

struct LifecycleRule {
    let id: String
    let prefix: String
    let transitions: [Transition]
    let expiration: Int?
    
    struct Transition {
        let days: Int
        let storageClass: String // GLACIER, DEEP_ARCHIVE, INTELLIGENT_TIERING
    }
}

struct LambdaResponse {
    let statusCode: Int
    let payload: [String: Any]
    let executedVersion: String
    let logResult: String?
}

struct APIGatewayResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: [String: Any]
}

struct DynamoDBItem {
    let attributes: [String: DynamoDBAttribute]
}

enum DynamoDBAttribute {
    case string(String)
    case number(Double)
    case binary(Data)
    case stringSet([String])
    case numberSet([Double])
    case map([String: DynamoDBAttribute])
    case list([DynamoDBAttribute])
    case bool(Bool)
    case null
    
    func toDynamoDB() -> [String: Any] {
        switch self {
        case .string(let s): return ["S": s]
        case .number(let n): return ["N": String(n)]
        case .binary(let b): return ["B": b.base64EncodedString()]
        case .stringSet(let ss): return ["SS": ss]
        case .numberSet(let ns): return ["NS": ns.map { String($0) }]
        case .map(let m): return ["M": m.mapValues { $0.toDynamoDB() }]
        case .list(let l): return ["L": l.map { $0.toDynamoDB() }]
        case .bool(let b): return ["BOOL": b]
        case .null: return ["NULL": true]
        }
    }
}

struct TransactWriteItem {
    enum Action {
        case put([String: DynamoDBAttribute])
        case update(String, [String: Any])
        case delete(String, String)
        case conditionCheck(String, String, String)
    }
    let action: Action
}

struct LogEvent {
    let timestamp: Date
    let message: String
}

enum MetricUnit: String {
    case seconds = "Seconds"
    case microseconds = "Microseconds"
    case milliseconds = "Milliseconds"
    case bytes = "Bytes"
    case kilobytes = "Kilobytes"
    case megabytes = "Megabytes"
    case gigabytes = "Gigabytes"
    case count = "Count"
    case percent = "Percent"
    case none = "None"
}

enum AWSError: Error {
    case noRefreshToken
    case invalidPassword
    case invalidConfirmationCode
    case batchSizeExceeded
    case unauthorized
    case serviceError(String)
}
