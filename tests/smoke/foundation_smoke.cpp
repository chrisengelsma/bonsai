#include "bonsai/foundation/version.h"

int main() {
    if (bonsai::foundation::version_major() != 0) {
        return 1;
    }

    if (bonsai::foundation::version_minor() != 1) {
        return 1;
    }

    if (bonsai::foundation::version_patch() != 0) {
        return 1;
    }

    if (bonsai::foundation::version_string() != "0.1.0") {
        return 1;
    }

    return 0;
}