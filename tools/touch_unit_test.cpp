// touch_unit_test.cpp - Unit tests for DinoPad touch tap latch and analog math.
#include <array>
#include <atomic>
#include <cassert>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <algorithm>

class TouchTapLatch {
public:
    void extend(uint16_t mask, uint8_t polls) {
        for (size_t bit = 0; bit < counters_.size(); ++bit) {
            const uint16_t bitMask = static_cast<uint16_t>(1u << bit);
            if ((mask & bitMask) == 0) continue;
            uint8_t current = counters_[bit].load(std::memory_order_relaxed);
            while (current < polls &&
                   !counters_[bit].compare_exchange_weak(
                       current, polls, std::memory_order_relaxed)) {}
        }
    }

    void clearAll() {
        for (auto& counter : counters_) {
            counter.store(0, std::memory_order_relaxed);
        }
    }

    void clear(uint16_t mask) {
        for (size_t bit = 0; bit < counters_.size(); ++bit) {
            if ((mask & static_cast<uint16_t>(1u << bit)) != 0) {
                counters_[bit].store(0, std::memory_order_relaxed);
            }
        }
    }

    uint16_t consume() {
        uint16_t buttons = 0;
        for (size_t bit = 0; bit < counters_.size(); ++bit) {
            uint8_t current = counters_[bit].load(std::memory_order_relaxed);
            while (current != 0) {
                if (counters_[bit].compare_exchange_weak(
                        current, static_cast<uint8_t>(current - 1),
                        std::memory_order_relaxed)) {
                    buttons |= static_cast<uint16_t>(1u << bit);
                    break;
                }
            }
        }
        return buttons;
    }

private:
    std::array<std::atomic<uint8_t>, 16> counters_{};
};

static void compute_analog(float dx, float dy, float radius, float* out_x, float* out_y) {
    float length = std::hypot(dx, dy);
    if (length > radius && length > 0.0f) {
        dx *= radius / length;
        dy *= radius / length;
    }
    float x = dx / radius;
    float y = -dy / radius;
    constexpr float deadzone = 0.16f;
    float magnitude = std::hypot(x, y);
    if (magnitude <= deadzone) {
        x = 0.0f;
        y = 0.0f;
    } else {
        float remapped = (magnitude - deadzone) / (1.0f - deadzone);
        float response = remapped * remapped * (0.75f + 0.25f * remapped);
        float scale = response / magnitude;
        x *= scale;
        y *= scale;
        constexpr float cardinalBias = 1.45f;
        if (std::abs(x) > std::abs(y) * cardinalBias) y = 0.0f;
        else if (std::abs(y) > std::abs(x) * cardinalBias) x = 0.0f;
    }
    *out_x = std::clamp(x, -1.0f, 1.0f);
    *out_y = std::clamp(y, -1.0f, 1.0f);
}

static int checks = 0;
static int failures = 0;

static void check(bool ok, const char* what) {
    checks++;
    if (!ok) {
        failures++;
        printf("FAIL: %s\n", what);
    } else {
        printf("PASS: %s\n", what);
    }
}

int main() {
    // 1. Digital masks bitwise distinct
    constexpr uint16_t kA = 0x8000;
    constexpr uint16_t kB = 0x4000;
    constexpr uint16_t kZ = 0x2000;
    constexpr uint16_t kStart = 0x1000;
    constexpr uint16_t kDUp = 0x0800;
    constexpr uint16_t kDDown = 0x0400;
    constexpr uint16_t kDLeft = 0x0200;
    constexpr uint16_t kDRight = 0x0100;
    constexpr uint16_t kL = 0x0020;
    constexpr uint16_t kR = 0x0010;
    constexpr uint16_t kCUp = 0x0008;
    constexpr uint16_t kCDown = 0x0004;
    constexpr uint16_t kCLeft = 0x0002;
    constexpr uint16_t kCRight = 0x0001;

    const std::array<uint16_t, 14> masks = {
        kA, kB, kZ, kStart, kDUp, kDDown, kDLeft, kDRight,
        kL, kR, kCUp, kCDown, kCLeft, kCRight
    };
    uint16_t combined = 0;
    for (uint16_t m : masks) {
        check((combined & m) == 0, "digital mask bits are non-overlapping");
        combined |= m;
    }
    check(combined == 0xFF3F, "all 14 masks combine to 0xFF3F");

    // 2. TouchTapLatch extend, consume, and decay
    TouchTapLatch latch;
    check(latch.consume() == 0, "fresh latch consumes 0");
    latch.extend(kA, 3);
    check(latch.consume() == kA, "consume poll 1 returns A");
    check(latch.consume() == kA, "consume poll 2 returns A");
    check(latch.consume() == kA, "consume poll 3 returns A");
    check(latch.consume() == 0, "consume poll 4 returns 0 after 3 polls");

    // Multi-button latch
    latch.extend(kA | kB | kZ, 2);
    check(latch.consume() == (kA | kB | kZ), "multi-button latch poll 1");
    check(latch.consume() == (kA | kB | kZ), "multi-button latch poll 2");
    check(latch.consume() == 0, "multi-button latch decays");

    // Clear all
    latch.extend(kA | kStart, 5);
    latch.clearAll();
    check(latch.consume() == 0, "clearAll resets all counters");

    // 3. Analog math: deadzone
    float x = 0.0f, y = 0.0f;
    compute_analog(0.05f, 0.05f, 1.0f, &x, &y);
    check(x == 0.0f && y == 0.0f, "analog magnitude <= 0.16 is deadzone zero");

    // 4. Analog math: cardinal directions (radius = 50.0)
    // Up: dy = -50.0
    compute_analog(0.0f, -50.0f, 50.0f, &x, &y);
    check(x == 0.0f && y >= 0.99f && y <= 1.0f, "analog cardinal Up produces x=0, y=1.0");

    // Down: dy = +50.0
    compute_analog(0.0f, 50.0f, 50.0f, &x, &y);
    check(x == 0.0f && y <= -0.99f && y >= -1.0f, "analog cardinal Down produces x=0, y=-1.0");

    // Left: dx = -50.0
    compute_analog(-50.0f, 0.0f, 50.0f, &x, &y);
    check(x <= -0.99f && x >= -1.0f && y == 0.0f, "analog cardinal Left produces x=-1.0, y=0");

    // Right: dx = +50.0
    compute_analog(50.0f, 0.0f, 50.0f, &x, &y);
    check(x >= 0.99f && x <= 1.0f && y == 0.0f, "analog cardinal Right produces x=1.0, y=0");

    // Diagonal: dx = 35.35, dy = -35.35
    compute_analog(35.35f, -35.35f, 50.0f, &x, &y);
    check(x > 0.5f && y > 0.5f, "analog diagonal Up-Right has positive x and y");

    // Clamp beyond radius
    compute_analog(100.0f, 0.0f, 50.0f, &x, &y);
    check(x == 1.0f && y == 0.0f, "analog input beyond radius clamps magnitude to 1.0");

    printf("\ntouch_unit_test: %d checks, %d failures\n", checks, failures);
    return failures == 0 ? 0 : 1;
}

