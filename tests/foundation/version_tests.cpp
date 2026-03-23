#include <catch2/catch_test_macros.hpp>

#include "bonsai/foundation/version.h"

TEST_CASE("foundation version components match the current engine version", "[foundation][version]") {
    REQUIRE(bonsai::foundation::version_major() == 0);
    REQUIRE(bonsai::foundation::version_minor() == 1);
    REQUIRE(bonsai::foundation::version_patch() == 0);
}

TEST_CASE("foundation version string matches semantic version text", "[foundation][version]") {
    REQUIRE(bonsai::foundation::version_string() == "0.1.0");
}