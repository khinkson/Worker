import AsyncHTTPClient
import AWSLambdaRuntime
import AWSLambdaEvents
import SotoSQS
import Backtrace
import Regex
import WorkerInterface
import Foundation

public let divider              : Character = "|"

typealias InitFunction = @convention(c) () -> UnsafeMutableRawPointer

Backtrace.install()
//var count: Int = 0

if #available(macOS 12, *) {
    DynamoDBHandler.main()
} else {
    fatalError("DynamoDBHandler cannot be run on less than macOS12")
}

@available(macOS 12, *)
struct DynamoDBHandler: AsyncLambdaHandler {

    static let incomingPath     : Regex? = "^/([0-9a-zA-Z-_]+)(/)?.*$".r
    let jsonDecoder             : JSONDecoder
    let jsonEncoder             : JSONEncoder
    let awsClient               : AWSClient
    let sqs                     : SotoSQS.SQS
    
    typealias In = String
    typealias Out = String
    
    init(context: Lambda.InitializationContext) async throws {
        self.awsClient = .init(credentialProvider: .selector(.environment, .configFile()), httpClientProvider: .createNew)
        self.sqs = .init(client: awsClient)
        
        self.jsonEncoder = .init()
        self.jsonEncoder.dateEncodingStrategy = .custom( { (date, encoder) in
            let dateString: String = date.iso8601withFractionalSeconds
            var container = encoder.singleValueContainer()
            try container.encode(dateString)
        })
        
        self.jsonDecoder = .init()
        self.jsonDecoder.dateDecodingStrategy = .custom( {(decoder) in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            guard let date = dateString.iso8601withFractionalSeconds else {
                throw DecodingError.typeMismatch(Date.Type.self, DecodingError.Context.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Decoding date failed for \(dateString)")
                )
            }
            return date
        })
    }
    
    public mutating func syncShutdown(context: AWSLambdaRuntimeCore.Lambda.ShutdownContext) throws {
        try? self.awsClient.syncShutdown()
    }

    func handle(event: String, context: Lambda.Context) async throws -> String {
        //count += 1
        var errorMessages: [String] = []
        let response: APIGateway.V2.Response = APIError.Message.internalErrorResponse(
            jsonEncoder: jsonEncoder,
            errorMessages: &errorMessages
        )

        defer {
            for errorMessage in errorMessages {
                context.logger.error(.init(stringLiteral: errorMessage))
            }
        }
        
        do {
            let path: String = try await fetchModuleViaEFS()
            context.logger.error(.init(stringLiteral: "path: \(path)"))
            let response: String = try runPlugin(at: path, event: event, logger: context.logger)
            context.logger.error(.init(stringLiteral: "Returning response: \(response)"))
            return response

        } catch {
            errorMessages.append("GENERIC ERROR: — \(error)")
        }
        return try jsonEncoder.encodeAsString(response)
    }
    
    func runPlugin(at path: String, event: String, logger: Logger) throws -> String {

        guard let openRes: UnsafeMutableRawPointer = dlopen(path, RTLD_NOW|RTLD_LOCAL) else {
            if let err: UnsafeMutablePointer<CChar> = dlerror() {
                let safeErr: String = .init(cString: err)
                throw PluginError.libOpenErrorWithMessage(.init(), safeErr, path)
            }
            else {
                throw PluginError.libOpenError(.init(), path)
            }
        }

        defer {
            let closed: Int32 = dlclose(openRes)
            if 0 != closed {
                logger.error(.init(stringLiteral: "dlclose failed for path: \(path)"))
            }
        }

        let symbolName: String = "createPlugin"
        guard let sym: UnsafeMutableRawPointer = dlsym(openRes, symbolName) else {
            throw PluginError.symbolLoadError(.init(), symbolName, path)
        }
        let f: InitFunction = unsafeBitCast(sym, to:InitFunction.self)
        //let pluginPointer: UnsafeMutableRawPointer = f()
        //let builder: WorkerInterfaceBuilder = Unmanaged<WorkerInterfaceBuilder>.fromOpaque(pluginPointer).takeRetainedValue()
        let builder: WorkerInterfaceBuilder = Unmanaged<WorkerInterfaceBuilder>.fromOpaque(f()).takeRetainedValue()
        let interface: WorkerInterface = builder.build()
        let code: UInt = interface.runWorker(event: event)
        let response: APIGateway.V2.Response = .init(statusCode: .init(code: code))
        return try jsonEncoder.encodeAsString(response)
    }
    
    func fetchModuleViaEFS() async throws -> String {
        //let path: String = (count % 2 == 0) ? "/mnt/efs/modules/libWorkerPlugin1.so" : "/mnt/efs/modules/libWorkerPlugin.so"
        let path: String = "/mnt/efs/modules/libWorkerPlugin.so"
        guard FileManager.default.fileExists(atPath: path) else {
            throw EFSError.fileDoesNotExist(.init(), path)
        }
        return path
    }
}

enum EFSError: LocalizedError {
    case fileDoesNotExist(UUID, String)
    
    public var errorDescription: String? {
        switch self {
        case .fileDoesNotExist(_, let path):
            return "file DOES NOT exist|pathWithFilename:\(path)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case
                .fileDoesNotExist(let errorID, _):
            return errorID.uuidString
        }
    }
}

enum PluginError: LocalizedError {
    case symbolLoadError(UUID, String, String)
    case libOpenErrorWithMessage(UUID, String, String)
    case libOpenError(UUID, String)
    
    public var errorDescription: String? {
        switch self {
        case .symbolLoadError(_, let symbolName, let path):
            return "error loading lib\(divider)symbol:\(symbolName)\(divider)path:\(path)"
            
        case .libOpenErrorWithMessage(_, let errorMessage, let path):
            return "error opending lib\(divider)message:\(errorMessage)\(divider)path:\(path)"
        
        case .libOpenError(_, let path):
            return "error opending lib\(divider)path:\(path)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case
                .symbolLoadError(let errorID, _, _),
                .libOpenError(let errorID, _),
                .libOpenErrorWithMessage(let errorID, _, _):
            return errorID.uuidString
        }
    }
}
