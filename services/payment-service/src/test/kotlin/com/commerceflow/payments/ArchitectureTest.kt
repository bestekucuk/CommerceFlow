package com.commerceflow.payments

import com.tngtech.archunit.core.importer.ImportOption
import com.tngtech.archunit.junit.AnalyzeClasses
import com.tngtech.archunit.junit.ArchTest
import com.tngtech.archunit.lang.ArchRule
import com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses

@AnalyzeClasses(packages = ["com.commerceflow"], importOptions = [ImportOption.DoNotIncludeTests::class])
class ArchitectureTest {

    @ArchTest
    val domainIsFrameworkFree: ArchRule = noClasses().that().resideInAPackage("..payments.domain..")
        .should().dependOnClassesThat().resideInAnyPackage(
            "org.springframework..", "org.flywaydb..", "java.sql..", "javax.sql..",
            "..payments.application..", "..payments.infrastructure..", "..payments.presentation..",
        )
        .allowEmptyShould(true)

    @ArchTest
    val applicationDoesNotDependOnAdapters: ArchRule = noClasses().that().resideInAPackage("..payments.application..")
        .should().dependOnClassesThat().resideInAnyPackage("..payments.infrastructure..", "..payments.presentation..")
        .allowEmptyShould(true)

    @ArchTest
    val noOtherServiceContexts: ArchRule = noClasses().should().dependOnClassesThat()
        .resideInAnyPackage("com.commerceflow.catalog..", "com.commerceflow.ordering..", "com.commerceflow.customer..", "com.commerceflow.pricing..")
        .allowEmptyShould(true)
}
