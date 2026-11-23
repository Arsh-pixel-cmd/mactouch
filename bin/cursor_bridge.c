#include <ApplicationServices/ApplicationServices.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// MacTouch native cursor helper for macOS.
// Reads simple commands from stdin for ultra-low-latency mouse control.
int main(int argc, char *argv[]) {
    // Disable stdout buffering
    setbuf(stdout, NULL);
    setbuf(stdin, NULL);

    char line[256];
    CGPoint currentPos = CGPointMake(500, 500);

    // Initial position query
    CGEventRef initialEvent = CGEventCreate(NULL);
    if (initialEvent) {
        currentPos = CGEventGetLocation(initialEvent);
        CFRelease(initialEvent);
    }

    while (fgets(line, sizeof(line), stdin)) {
        // Strip newline
        size_t len = strlen(line);
        if (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r')) {
            line[len - 1] = '\0';
        }

        if (line[0] == '\0') continue;

        char cmd = line[0];

        if (cmd == 'm') {
            // Move absolute: m <x> <y>
            double x, y;
            if (sscanf(line + 1, "%lf %lf", &x, &y) == 2) {
                currentPos = CGPointMake(x, y);
                CGEventRef move = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, currentPos, kCGMouseButtonLeft);
                if (move) {
                    CGEventPost(kCGHIDEventTap, move);
                    CFRelease(move);
                }
            }
        } else if (cmd == 'r') {
            // Move relative: r <dx> <dy>
            double dx, dy;
            if (sscanf(line + 1, "%lf %lf", &dx, &dy) == 2) {
                CGEventRef current = CGEventCreate(NULL);
                if (current) {
                    currentPos = CGEventGetLocation(current);
                    CFRelease(current);
                }
                currentPos.x += dx;
                currentPos.y += dy;
                CGEventRef move = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, currentPos, kCGMouseButtonLeft);
                if (move) {
                    CGEventPost(kCGHIDEventTap, move);
                    CFRelease(move);
                }
            }
        } else if (cmd == 'c') {
            // Left click at current position
            CGEventRef down = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, currentPos, kCGMouseButtonLeft);
            CGEventRef up = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, currentPos, kCGMouseButtonLeft);
            if (down && up) {
                CGEventPost(kCGHIDEventTap, down);
                CGEventPost(kCGHIDEventTap, up);
                CFRelease(down);
                CFRelease(up);
            }
        } else if (cmd == 'k') {
            // Right click (context menu)
            CGEventRef rdown = CGEventCreateMouseEvent(NULL, kCGEventRightMouseDown, currentPos, kCGMouseButtonRight);
            CGEventRef rup = CGEventCreateMouseEvent(NULL, kCGEventRightMouseUp, currentPos, kCGMouseButtonRight);
            if (rdown && rup) {
                CGEventPost(kCGHIDEventTap, rdown);
                CGEventPost(kCGHIDEventTap, rup);
                CFRelease(rdown);
                CFRelease(rup);
            }
        } else if (cmd == 'd') {
            // Left mouse down (start drag)
            CGEventRef down = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, currentPos, kCGMouseButtonLeft);
            if (down) {
                CGEventPost(kCGHIDEventTap, down);
                CFRelease(down);
            }
        } else if (cmd == 'u') {
            // Left mouse up (end drag)
            CGEventRef up = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, currentPos, kCGMouseButtonLeft);
            if (up) {
                CGEventPost(kCGHIDEventTap, up);
                CFRelease(up);
            }
        } else if (cmd == 'g') {
            // Drag move: g <x> <y>
            double x, y;
            if (sscanf(line + 1, "%lf %lf", &x, &y) == 2) {
                currentPos = CGPointMake(x, y);
                CGEventRef drag = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDragged, currentPos, kCGMouseButtonLeft);
                if (drag) {
                    CGEventPost(kCGHIDEventTap, drag);
                    CFRelease(drag);
                }
            }
        } else if (cmd == 's') {
            // Scroll wheel: s <dy>
            int dy = 0;
            if (sscanf(line + 1, "%d", &dy) == 1) {
                CGEventRef scroll = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 1, dy);
                if (scroll) {
                    CGEventPost(kCGHIDEventTap, scroll);
                    CFRelease(scroll);
                }
            }
        } else if (cmd == 'p') {
            // Print current position
            CGEventRef current = CGEventCreate(NULL);
            if (current) {
                currentPos = CGEventGetLocation(current);
                CFRelease(current);
            }
            printf("%.1f %.1f\n", currentPos.x, currentPos.y);
        } else if (cmd == 'q') {
            break;
        }
    }

    return 0;
}
