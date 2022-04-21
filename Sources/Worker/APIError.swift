//
//  APIError.swift
//
//
//  Created by Kevin Hinkson on 2021-05-11.
//

import AWSLambdaEvents
import Logging
import Foundation

public struct APIError {
    
    public enum Kind: String {
        case DecodingException                  = "DecodingException"
        case ForbiddenException                 = "ForbiddenException"
        case ConditionalConflictException       = "ConditionalConflictException"
        case SizeLimitException                 = "SizeLimitException"
        case SystemThroughputException          = "SystemThroughputException"
        case TransactionConflictException       = "TransactionConflictException"
        case InvalidValueException              = "InvalidValueException"
        case contentTypeException               = "ContentTypeException"
    }
    
    struct Error: Encodable {
        let message: Message
        
        func serialize(jsonEncoder: JSONEncoder, logger: Logger) -> String? {
            do {
                return try jsonEncoder.encodeAsString(self)
            } catch {
                logger.error(.init(stringLiteral: "an error occured encoding the error message. Oops! \(self)"))
            }
            return nil
        }
        
        func serialize(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> String? {
            do {
                return try jsonEncoder.encodeAsString(self)
            } catch {
                errorMessages.append("an error occured encoding the error message. Oops! \(self)")
            }
            return nil
        }
    }

    public struct Message: Encodable {
        let title: String
        let detail: String
        let kind: Kind
        let status: HTTPResponseStatus
        
        enum CodingKeys: String, CodingKey {
            case title
            case detail
            case kind = "type"
            case status
        }
        
        public init(title: String, detail: String, kind: Kind, status: HTTPResponseStatus) {
            self.title = title
            self.detail = detail
            self.kind = kind
            self.status = status
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(title, forKey: .title)
            try container.encode(detail, forKey: .detail)
            try container.encode(kind.rawValue, forKey: .kind)
            try container.encode(String(status.code), forKey: .status)
        }

        public func response(statusCode: HTTPResponseStatus, jsonEncoder: JSONEncoder, logger: Logger) -> APIGateway.V2.Response {
            let error: Error = .init(message: self)
            let errorBody = error.serialize(jsonEncoder: jsonEncoder, logger: logger)
            let response: APIGateway.V2.Response = .init(statusCode: statusCode,
                                                         headers: nil,
                                                         body: errorBody,
                                                         isBase64Encoded: false,
                                                         cookies: nil)
            return response
        }
        
        public func response(statusCode: HTTPResponseStatus, jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let error: Error = .init(message: self)
            let errorBody = error.serialize(jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
            let response: APIGateway.V2.Response = .init(statusCode: statusCode,
                                                         headers: nil,
                                                         body: errorBody,
                                                         isBase64Encoded: false,
                                                         cookies: nil)
            return response
        }
        
        public static func invalidBeforeAfterPageParameterJSONResponse(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Both Before & After Page parameters present.",
                                                    detail: "Pagination using both page[before] and page[after] simultaneously is not supported.",
                                                    kind: .DecodingException,
                                                    status: .badRequest)
            return errorBody.response(statusCode: .badRequest, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func invalidPageParameterJSONResponse(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Page parameter invalid.",
                                                    detail: "The page parameter value provided is not a valid cursor.",
                                                    kind: .DecodingException,
                                                    status: .badRequest)
            return errorBody.response(statusCode: .badRequest, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func invalidPageParameterJSONResponse(name: String, jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Page parameter '\(name)' invalid.",
                                                    detail: "The value provided for page parameter name is not a valid cursor.",
                                                    kind: .DecodingException,
                                                    status: .badRequest)
            return errorBody.response(statusCode: .badRequest, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func invalidPageSizeParameterJSONResponse(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Page size value invalid.",
                                                    detail: "You requested a page size that is not a valid integer.",
                                                    kind: .DecodingException,
                                                    status: .badRequest)
            return errorBody.response(statusCode: .badRequest, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func maxPageSizeExceededJSONResponse(maxPageSize: Int, jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Page size requested is too large.",
                                                    detail: "You requested a page size larger than the maxiumum of \(maxPageSize).",
                                                    kind: .DecodingException,
                                                    status: .badRequest)
            return errorBody.response(statusCode: .badRequest, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func badSortParameterJSONResponse(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Invalid Sort Query Parameter",
                                                    detail: "Unable to sort with the query parameter provided. We can only sort on one (1) existing attribute and it must be indexed.",
                                                    kind: .DecodingException,
                                                    status: .badRequest)
            return errorBody.response(statusCode: .badRequest, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func badContentTypeJSONResponse(jsonEncoder: JSONEncoder, logger: Logger) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Invalid Content Type",
                                                    detail: "The content-type of your request is malformed. Content type should be application/vnd.api+json with no media type.",
                                                    kind: .contentTypeException,
                                                    status: .unsupportedMediaType)
            return errorBody.response(statusCode: .badRequest, jsonEncoder: jsonEncoder, logger: logger)
        }
        
        public static func badRequestDecodingJSONResponse(jsonEncoder: JSONEncoder, logger: Logger) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Invalid Request Format",
                                                    detail: "The body of your request is not valid JSON or contains unexpected attributes.",
                                                    kind: .DecodingException,
                                                    status: .badRequest)
            return errorBody.response(statusCode: .badRequest, jsonEncoder: jsonEncoder, logger: logger)
        }
        
        public static func badRequestDecodingJSONResponse(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Invalid Request Format",
                                                    detail: "The body of your request is not valid JSON or contains unexpected attributes.",
                                                    kind: .DecodingException,
                                                    status: .badRequest)
            return errorBody.response(statusCode: .badRequest, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func badRequestFunctionURLResponse(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Invalid Request Format",
                                                    detail: "The url of your request does not match any known function name.",
                                                    kind: .DecodingException,
                                                    status: .badRequest)
            return errorBody.response(statusCode: .badRequest, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func internalErrorFunctionsResponse(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Internal Error",
                                                    detail: "An internal error has occured. The expected function could not be found.",
                                                    kind: .DecodingException,
                                                    status: .internalServerError)
            return errorBody.response(statusCode: .internalServerError, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func internalErrorResponse(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Internal Error",
                                                    detail: "An internal error has occured.",
                                                    kind: .DecodingException,
                                                    status: .internalServerError)
            return errorBody.response(statusCode: .internalServerError, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func tooManyRequestsResponse(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "System Throughput Overloaded",
                                                    detail: "We are unable to process your request due to system load. We are allocating more resources. Try again, backing off exponentially.",
                                                    kind: .SystemThroughputException,
                                                    status: .tooManyRequests)
            return errorBody.response(statusCode: .tooManyRequests, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func transactionConflictResponse(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Transaction Conflict",
                                                    detail: "We are unable to process your request due to an ongoing transaction for this object. Try again.",
                                                    kind: .TransactionConflictException,
                                                    status: .conflict)
            return errorBody.response(statusCode: .conflict, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func conditionalConflictResponse(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Data Conflict",
                                                    detail: "The required condition for this request does not exist. Eg: could be the uniqueness of a data point",
                                                    kind: .ConditionalConflictException,
                                                    status: .conflict)
            return errorBody.response(statusCode: .conflict, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func forbiddenAccessResponse(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Forbidden",
                                                    detail: "Your credentials do not allow you to access this resource or to perform the requested action on this resource.",
                                                    kind: .ForbiddenException,
                                                    status: .forbidden)
            return errorBody.response(statusCode: .forbidden, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func clientGeneratedIDResponse(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Forbidden",
                                                    detail: "Client Generated IDs are not allowed on this resource.",
                                                    kind: .ForbiddenException,
                                                    status: .forbidden)
            return errorBody.response(statusCode: .forbidden, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
        
        public static func schemaNotFoundResponse(jsonEncoder: JSONEncoder, errorMessages: inout [String]) -> APIGateway.V2.Response {
            let errorBody: APIError.Message = .init(title: "Not Found",
                                                    detail: "The schema for your request was not found. There is likely an error in your request url.",
                                                    kind: .InvalidValueException,
                                                    status: .notFound)
            return errorBody.response(statusCode: .notFound, jsonEncoder: jsonEncoder, errorMessages: &errorMessages)
        }
    }
}
