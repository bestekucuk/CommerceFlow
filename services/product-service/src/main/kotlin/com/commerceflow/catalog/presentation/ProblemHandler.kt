package com.commerceflow.catalog.presentation

import com.commerceflow.catalog.domain.DuplicateSku
import com.commerceflow.catalog.domain.InvalidProduct
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpStatus
import org.springframework.http.ProblemDetail
import org.springframework.http.converter.HttpMessageNotReadableException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException
import java.net.URI

/** RFC 9457 problem details. Never exposes stack traces or SQL. */
@RestControllerAdvice
class ProblemHandler {

    @ExceptionHandler(InvalidRequest::class, HttpMessageNotReadableException::class, MethodArgumentTypeMismatchException::class)
    fun badRequest(e: Exception, request: HttpServletRequest) =
        problem(HttpStatus.BAD_REQUEST, "invalid-request", "Invalid request",
            if (e is InvalidRequest) e.message else "Malformed request body or parameter", request)

    @ExceptionHandler(InvalidProduct::class)
    fun invalidProduct(e: InvalidProduct, request: HttpServletRequest) =
        problem(HttpStatus.UNPROCESSABLE_ENTITY, "invalid-product", "Product rule violated", e.message, request)

    @ExceptionHandler(DuplicateSku::class)
    fun duplicateSku(e: DuplicateSku, request: HttpServletRequest) =
        problem(HttpStatus.CONFLICT, "duplicate-sku", "SKU already exists", "One of the SKU codes is already in use", request)

    @ExceptionHandler(ProductNotFound::class)
    fun notFound(e: ProductNotFound, request: HttpServletRequest) =
        problem(HttpStatus.NOT_FOUND, "not-found", "Product not found", null, request)

    private fun problem(status: HttpStatus, type: String, title: String, detail: String?, request: HttpServletRequest) =
        ProblemDetail.forStatus(status).apply {
            this.type = URI.create("https://commerceflow.dev/problems/$type")
            this.title = title
            this.detail = detail
            setProperty("correlationId", CorrelationIdFilter.current(request))
        }
}
