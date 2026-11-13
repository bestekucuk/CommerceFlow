package com.commerceflow.pricing.infrastructure.config

import com.commerceflow.pricing.application.CreateQuote
import com.commerceflow.pricing.application.GetPrices
import com.commerceflow.pricing.application.GetQuote
import com.commerceflow.pricing.application.SetPrice
import com.commerceflow.pricing.domain.PriceRepository
import com.commerceflow.pricing.domain.QuoteRepository
import com.commerceflow.pricing.infrastructure.persistence.JdbcPriceRepository
import com.commerceflow.pricing.infrastructure.persistence.JdbcQuoteRepository
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.jdbc.core.simple.JdbcClient
import java.time.Clock
import java.time.Duration

/** Wires use cases to adapters. Domain and application classes carry no Spring stereotypes. */
@Configuration
class PricingConfig {

    @Bean
    // microseconds: what PostgreSQL stores, so responses equal later reads
    fun clock(): Clock = Clock.tick(Clock.systemUTC(), Duration.ofNanos(1_000))

    @Bean
    fun priceRepository(jdbc: JdbcClient): PriceRepository = JdbcPriceRepository(jdbc)

    @Bean
    fun quoteRepository(jdbc: JdbcClient): QuoteRepository = JdbcQuoteRepository(jdbc)

    @Bean
    fun setPrice(prices: PriceRepository, clock: Clock) = SetPrice(prices, clock)

    @Bean
    fun getPrices(prices: PriceRepository) = GetPrices(prices)

    @Bean
    fun createQuote(
        prices: PriceRepository,
        quotes: QuoteRepository,
        clock: Clock,
        @Value("\${commerceflow.pricing.quote-ttl:PT15M}") ttl: Duration,
    ) = CreateQuote(prices, quotes, clock, ttl)

    @Bean
    fun getQuote(quotes: QuoteRepository) = GetQuote(quotes)
}
