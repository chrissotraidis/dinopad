// dinopad_support.mm - DinoPad-owned macOS implementations of the bundle-path
// helpers that upstream dino-recomp declares but never defines (upstream is
// Windows/Linux). Mirrors the PaperPad paths pattern.

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

#include "runtime/support.hpp"

#include <filesystem>
#include <functional>

namespace dino::runtime {

std::filesystem::path get_bundle_directory() {
    @autoreleasepool {
        NSString* bundle_path = [[NSBundle mainBundle] bundlePath];
        if (bundle_path != nil && [bundle_path length] > 0) {
            return std::filesystem::path{bundle_path.UTF8String};
        }
    }
    // Bare executable (no app bundle): use the executable's directory.
    return std::filesystem::path{};
}

std::filesystem::path get_bundle_resource_directory() {
    @autoreleasepool {
        NSString* resource_path = [[NSBundle mainBundle] resourcePath];
        if (resource_path != nil && [resource_path length] > 0) {
            return std::filesystem::path{resource_path.UTF8String};
        }
    }
    // Bare executable: fall back to the bundle directory (its parent folder).
    return get_bundle_directory();
}

void dispatch_on_ui_thread(std::function<void()> function) {
    dispatch_async(dispatch_get_main_queue(), ^{
        function();
    });
}

}  // namespace dino::runtime
