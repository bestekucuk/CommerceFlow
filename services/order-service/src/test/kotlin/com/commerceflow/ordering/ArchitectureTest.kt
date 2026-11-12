package com.commerceflow.ordering

import com.tngtech.archunit.core.importer.ImportOption
import com.tngtech.archunit.junit.AnalyzeClasses
import com.tngtech.archunit.junit.ArchTest
import com.tngtech.archunit.lang.ArchRule
import com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses

@AnalyzeClasses(packages = ["com.commerceflow"], importOptions = [ImportOption.DoNotIncludeTests::class])
class ArchitectureTest {

    @ArchTest
    val domainIsFrameworkFree: ArchRule = noClasses().that().resideInAPackage("..ordering.domain..")
        .should().dependOnClassesThat().resideInAnyPackage(
            "org.springframework..", "org.flywaydb..", "java.sql..", "javax.sql..",
            "..ordering.application..", "..ordering.infrastructure..", "..ordering.presentation..",
        )
        .allowEmptyShould(true)

    @ArchTest
    val applicationDoesNotDependOnAdapters: ArchRule = noClasses().that().resideInAPackage("..ordering.application..")
        .should().dependOnClassesThat().resideInAnyPackage("..ordering.infrastructure..", "..ordering.presentation..")
        .allowEmptyShould(true)

    @ArchTest
    val noOtherServiceContexts: ArchRule = noClasses().should().dependOnClassesThat()
        .resideInAnyPackage("com.commerceflow.catalog..", "com.commerceflow.payments..", "com.commerceflow.customer..", "com.commerceflow.pricing..")
        .allowEmptyShould(true)
}
