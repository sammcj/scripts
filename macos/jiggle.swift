#!/usr/bin/env swift

// Keeps the Mac awake by nudging the mouse a few random pixels on an interval,
// but skips the nudge if real user input happened within the idle threshold.
//
// Uses a posted mouseMoved CGEvent (not just a cursor warp) so it actually
// resets the HID idle timer and prevents display/system sleep.
//
// Build (recommended so the Accessibility grant sticks to one binary):
//   swiftc jiggle.swift -o jiggle && ./jiggle
// Or run directly:
//   ./jiggle.swift
//
// Options:
//   --interval <seconds>   how often to consider a nudge   (default 45)
//   --idle <seconds>       skip if input seen within this   (default 30)
//   --nudge <pixels>       max move per axis                (default 8)
// Stop: Ctrl-C
//
// Needs Accessibility permission for whatever binary runs it
// (System Settings > Privacy & Security > Accessibility). On first run it
// prompts; grant it, then re-run.

import ApplicationServices
import CoreGraphics
import Foundation

// --- arg parsing ---------------------------------------------------------

var interval: TimeInterval = 45
var userIdleThreshold = 30.0
var nudgeRange = 8

func usage() -> Never {
    FileHandle.standardError.write(
        "usage: jiggle [--interval <s>] [--idle <s>] [--nudge <px>]\n".data(using: .utf8)!)
    exit(2)
}

var args = Array(CommandLine.arguments.dropFirst())
while let flag = args.first {
    args.removeFirst()
    guard let raw = args.first else { usage() }
    args.removeFirst()
    switch flag {
    case "--interval": guard let v = Double(raw), v > 0 else { usage() }; interval = v
    case "--idle":     guard let v = Double(raw), v >= 0 else { usage() }; userIdleThreshold = v
    case "--nudge":    guard let v = Int(raw), v > 0 else { usage() }; nudgeRange = v
    default: usage()
    }
}

// --- helpers -------------------------------------------------------------

func log(_ msg: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    FileHandle.standardError.write("\(ts) \(msg)\n".data(using: .utf8)!)
}

// Prompt for Accessibility access if we don't have it yet. Posting events
// silently fails without this, so bail rather than spin uselessly.
func ensureAccessibility() {
    let opt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    if AXIsProcessTrustedWithOptions([opt: true] as CFDictionary) { return }
    log("no Accessibility permission - approve this binary in System Settings > "
        + "Privacy & Security > Accessibility, then re-run.")
    exit(1)
}

// Seconds since any real input event (key, mouse move, click, scroll).
// Our own posted events count too, which is what keeps the idle timer reset.
func secondsSinceLastInput() -> Double {
    return CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                   eventType: .init(rawValue: ~0)!)
}

func currentMouseLocation() -> CGPoint {
    return CGEvent(source: nil)?.location ?? .zero
}

func randomOffset() -> CGFloat {
    var d = 0
    while d == 0 { d = Int.random(in: -nudgeRange...nudgeRange) }  // non-zero
    return CGFloat(d)
}

func post(_ point: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
            mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
}

func jiggle() {
    let from = currentMouseLocation()
    let to = CGPoint(x: from.x + randomOffset(), y: from.y + randomOffset())
    post(to)
    usleep(60_000)   // 60ms so the move is actually visible
    post(from)       // move back so the cursor doesn't drift over time
}

// --- main loop -----------------------------------------------------------

ensureAccessibility()
log("started: every \(Int(interval))s, skip if input within "
    + "\(Int(userIdleThreshold))s, nudge +/-\(nudgeRange)px")

while true {
    let idle = secondsSinceLastInput()
    if idle >= userIdleThreshold {
        jiggle()
        log("jiggled (idle \(String(format: "%.0f", idle))s)")
    } else {
        log("skipped (active \(String(format: "%.0f", idle))s ago)")
    }
    Thread.sleep(forTimeInterval: interval)
}
