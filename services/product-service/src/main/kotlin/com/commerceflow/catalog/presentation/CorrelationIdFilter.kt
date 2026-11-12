package com.commerceflow.catalog.presentation

import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.MDC
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import java.util.UUID

/**
 * Accepts `X-Correlation-Id` (or creates one), echoes it in the response, puts it in the
 * logging MDC as `correlation_id`, and makes it available to use cases, which copy it into
 * event metadata.
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
