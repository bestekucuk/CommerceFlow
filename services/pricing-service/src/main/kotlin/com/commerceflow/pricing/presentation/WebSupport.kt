package com.commerceflow.pricing.presentation

import com.commerceflow.pricing.application.PreconditionRequired
import com.commerceflow.pricing.application.PriceVersionConflict
import com.commerceflow.pricing.domain.InvalidPrice
import com.commerceflow.pricing.domain.InvalidQuote
import com.commerceflow.pricing.domain.MixedCurrencies
import com.commerceflow.pricing.domain.UnpricedSkus
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.MDC
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.http.HttpStatus
import org.springframework.http.ProblemDetail
import org.springframework.http.converter.HttpMessageNotReadableException
import org.springframework.stereotype.Component
import org.springframework.web.bind.MissingServletRequestParameterException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice
import org.springframework.web.filter.OncePerRequestFilter
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException
import java.net.URI
import java.util.UUID

/**
 * Accepts `X-Correlation-Id` (or creates one), echoes it in the response and puts it in the
 * logging MDC as `correlation_id`.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
class CorrelationIdFilter : OncePerRequestFilter() {

    override fun doFilterInternal(request: HttpServletRequest, response: HttpServletResponse, chain: FilterChain) {
        val incoming = request.getHeader(HEADER)
        val id = if (incoming != null && VALID.matches(incoming)) incoming else UUID.randomUUID().toString()
        request.setAttribute(ATTRIBUTE, id)
        response.setHeader(HEADER, id)
        MDC.put(MDC_KEY, id)
        try {
            chain.doFilter(request, response)
        } finally {
            MDC.remove(MDC_KEY)
        }
    }

    companion object {
        const val HEADER = "X-Correlation-Id"
        const val MDC_KEY = "correlation_id"
        private const val ATTRIBUTE = "commerceflow.correlationId"
        private val VALID = Regex("^[A-Za-z0-9._-]{1,64}$")

        fun current(request: HttpServletRequest): String =
            request.getAttribute(ATTRIBUTE) as String? ?: UUID.randomUUID().toString()
    }
}

/**
 * RFC 9457 problem details. Never exposes stack traces or SQL. Ordered before Spring Boot's own
 * ProblemDetailsExceptionHandler so framework 400s also carry our type and correlationId.
 */
@RestControllerAdvice
@Order(Ordered.HIGHEST_PRECEDENCE)
class ProblemHandler {

    @ExceptionHandler(
        InvalidRequest::class, InvalidPrice::class, InvalidQuote::class, HttpMessageNotReadableException::class,
        MethodArgumentTypeMismatchException::class, MissingServletRequestParameterException::class,
    )
    fun badRequest(e: Exception, request: HttpServletRequest) =
        problem(HttpStatus.BAD_REQUEST, "invalid-request", "Invalid request",
            if (e is InvalidRequest || e is InvalidPrice || e is InvalidQuote) e.message else "Malformed request body or parameter", request)

    @ExceptionHandler(NotFound::class)
    fun notFound(e: NotFound, request: HttpServletRequest) =
        problem(HttpStatus.NOT_FOUND, "not-found", "Not found", e.message, request)

    @ExceptionHandler(PreconditionRequired::class)
    fun preconditionRequired(e: PreconditionRequired, request: HttpServletRequest) =
        problem(HttpStatus.PRECONDITION_REQUIRED, "precondition-required", "If-Match required", e.message, request)

    @ExceptionHandler(PriceVersionConflict::class, StaleEtag::class)
    fun preconditionFailed(e: Exception, request: HttpServletRequest) =
        problem(HttpStatus.PRECONDITION_FAILED, "precondition-failed", "Price was changed",
            "Read the price again and retry with its current ETag", request)

    @ExceptionHandler(UnpricedSkus::class)
    fun unpriced(e: UnpricedSkus, request: HttpServletRequest) =
        problem(HttpStatus.UNPROCESSABLE_ENTITY, "unpriced-sku", "Some SKUs have no price", e.message, request)
            .apply { setProperty("skus", e.skus) }

    @ExceptionHandler(MixedCurrencies::class)
    fun mixed(e: MixedCurrencies, request: HttpServletRequest) =
        problem(HttpStatus.UNPROCESSABLE_ENTITY, "mixed-currency", "Basket mixes currencies", e.message, request)

    private fun problem(status: HttpStatus, type: String, title: String, detail: String?, request: HttpServletRequest) =
        ProblemDetail.forStatus(status).apply {
            this.type = URI.create("https://commerceflow.dev/problems/$type")
            this.title = title
            this.detail = detail
            setProperty("correlationId", CorrelationIdFilter.current(request))
        }
}
