#!/usr/bin/env python3
"""
Remove Flutter build scripts from Xcode project
"""
import re

project_file = 'Runner.xcodeproj/project.pbxproj'

print("Reading project file...")
with open(project_file, 'r') as f:
    content = f.read()

print("Original file size:", len(content))

# Remove Flutter shell script build phases
# Pattern to match shell script sections with Flutter/macos_assemble
pattern = r'/\* Begin PBXShellScriptBuildPhase section \*/.*?/\* End PBXShellScriptBuildPhase section \*/'
match = re.search(pattern, content, re.DOTALL)

if match:
    section = match.group(0)
    # Keep the section markers but remove Flutter-specific scripts
    new_section = "/* Begin PBXShellScriptBuildPhase section */\n\t\t/* End PBXShellScriptBuildPhase section */"
    content = content.replace(section, new_section)
    print("✅ Removed Flutter shell scripts")
else:
    print("⚠️  No shell script section found")

# Remove references to Flutter Assemble from build phases
content = re.sub(r'\t\t\t\t[A-F0-9]+ /\* PBXShellScriptBuildPhase \*/,?\n', '', content)

# Remove shell script references from target dependencies
content = re.sub(r'\t\t\t\t33CC111E2044C6BF0003C045.*?\n', '', content)

print("Modified file size:", len(content))

# Backup original
import shutil
shutil.copy(project_file, project_file + '.backup')
print("✅ Created backup:", project_file + '.backup')

# Write modified file
with open(project_file, 'w') as f:
    f.write(content)

print("✅ Project file updated successfully!")
print("\nNext steps:")
print("1. Reopen Xcode: open Runner.xcodeproj")
print("2. Clean: Shift + Command + K")
print("3. Build: Command + R")
