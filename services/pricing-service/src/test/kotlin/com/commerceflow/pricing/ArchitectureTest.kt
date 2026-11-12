package com.commerceflow.pricing

import com.tngtech.archunit.core.importer.ImportOption
import com.tngtech.archunit.junit.AnalyzeClasses
import com.tngtech.archunit.junit.ArchTest
import com.tngtech.archunit.lang.ArchRule
import com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses

@AnalyzeClasses(packages = ["com.commerceflow"], importOptions = [ImportOption.DoNotIncludeTests::class])
class ArchitectureTest {

    @ArchTest
    val domainIsFrameworkFree: ArchRule = noClasses().that().resideInAPackage("..pricing.domain..")
        .should().dependOnClassesThat().resideInAnyPackage(
            "org.springframework..", "org.flywaydb..", "java.sql..", "javax.sql..",
            "..pricing.application..", "..pricing.infrastructure..", "..pricing.presentation..",
        )
        .allowEmptyShould(true)

    @ArchTest
    val applicationDoesNotDependOnAdapters: ArchRule = noClasses().that().resideInAPackage("..pricing.application..")
        .should().dependOnClassesThat().resideInAnyPackage("..pricing.infrastructure..", "..pricing.presentation..")
        .allowEmptyShould(true)

    @ArchTest
    val noOtherServiceContexts: ArchRule = noClasses().should().dependOnClassesThat()
        .resideInAnyPackage("com.commerceflow.catalog..", "com.commerceflow.ordering..", "com.commerceflow.payments..", "com.commerceflow.customer..")
        .allowEmptyShould(true)
}
