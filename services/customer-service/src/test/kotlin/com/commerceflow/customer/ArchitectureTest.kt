package com.commerceflow.customer

import com.tngtech.archunit.core.importer.ImportOption
import com.tngtech.archunit.junit.AnalyzeClasses
import com.tngtech.archunit.junit.ArchTest
import com.tngtech.archunit.lang.ArchRule
import com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses

@AnalyzeClasses(packages = ["com.commerceflow"], importOptions = [ImportOption.DoNotIncludeTests::class])
class ArchitectureTest {

    @ArchTest
    val domainIsFrameworkFree: ArchRule = noClasses().that().resideInAPackage("..customer.domain..")
        .should().dependOnClassesThat().resideInAnyPackage(
            "org.springframework..", "org.flywaydb..", "java.sql..", "javax.sql..",
            "..customer.application..", "..customer.infrastructure..", "..customer.presentation..",
        )
        .allowEmptyShould(true)

    @ArchTest
    val applicationDoesNotDependOnAdapters: ArchRule = noClasses().that().resideInAPackage("..customer.application..")
        .should().dependOnClassesThat().resideInAnyPackage("..customer.infrastructure..", "..customer.presentation..")
        .allowEmptyShould(true)

    @ArchTest
    val noOtherServiceContexts: ArchRule = noClasses().should().dependOnClassesThat()
        .resideInAnyPackage("com.commerceflow.catalog..", "com.commerceflow.ordering..", "com.commerceflow.payments..", "com.commerceflow.pricing..")
        .allowEmptyShould(true)
}
