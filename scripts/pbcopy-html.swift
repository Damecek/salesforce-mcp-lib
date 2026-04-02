#!/usr/bin/env swift
//
// pbcopy-html.swift
// Reads HTML from stdin and copies it to the macOS pasteboard
// with the "public.html" UTI so that rich-text-aware apps
// (LinkedIn editor, Google Docs, Notion, etc.) paste formatted content.
//
// Usage:  echo "<h1>Hello</h1>" | ./pbcopy-html.swift
//

import AppKit

let input = FileHandle.standardInput.readDataToEndOfFile()

guard !input.isEmpty else {
    fputs("Error: No input received on stdin.\n", stderr)
    exit(1)
}

let pasteboard = NSPasteboard.general
pasteboard.clearContents()
pasteboard.setData(input, forType: .html)

// Also set a plain-text fallback so Cmd-V works everywhere
if let htmlString = String(data: input, encoding: .utf8) {
    pasteboard.setString(htmlString, forType: .string)
}
