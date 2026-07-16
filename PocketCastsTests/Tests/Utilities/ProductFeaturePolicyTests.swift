import XCTest
@testable import podcasts

final class ProductFeaturePolicyTests: XCTestCase {
    func testStagingBuildUsesLocalPremiumFeaturesWithoutPocketCastsSubscriptions() {
        #if STAGING
            XCTAssertFalse(ProductFeaturePolicy.usesPocketCastsSubscriptions)
            XCTAssertTrue(ProductFeaturePolicy.hasLocalPremiumAccess)
        #else
            XCTAssertTrue(ProductFeaturePolicy.usesPocketCastsSubscriptions)
            XCTAssertFalse(ProductFeaturePolicy.hasLocalPremiumAccess)
        #endif
    }

    func testPremiumOnboardingFlowsAreIdentified() {
        XCTAssertTrue(OnboardingFlow.Flow.plusUpsell.requiresPocketCastsSubscription)
        XCTAssertTrue(OnboardingFlow.Flow.suggestedFolderUpsell.requiresPocketCastsSubscription)
        XCTAssertFalse(OnboardingFlow.Flow.initialOnboarding.requiresPocketCastsSubscription)
        XCTAssertFalse(OnboardingFlow.Flow.loggedOut.requiresPocketCastsSubscription)
    }
}
