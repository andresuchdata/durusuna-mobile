#!/usr/bin/env python3
"""
Script to remove all print() statements from Dart files in the Flutter project.
This preserves debugPrint() statements as they are more appropriate for production.
"""

import os
import re
import sys

def remove_print_statements(file_path):
    """Remove print() statements from a Dart file while preserving debugPrint()"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        lines = content.split('\n')
        cleaned_lines = []
        
        for line in lines:
            # Skip lines that contain only print() statements (including multiline)
            # But preserve debugPrint() statements
            stripped = line.strip()
            
            # Check if line is a print statement (but not debugPrint)
            if re.match(r'^\s*print\s*\(', line) and 'debugPrint' not in line:
                # Skip standalone print statements
                continue
            elif 'print(' in line and 'debugPrint' not in line:
                # Handle inline print statements - this is more complex
                # For now, just comment them out for manual review
                cleaned_lines.append(line.replace('print(', '// print('))
            else:
                cleaned_lines.append(line)
        
        # Join lines back
        cleaned_content = '\n'.join(cleaned_lines)
        
        # If content changed, write back to file
        if cleaned_content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(cleaned_content)
            
            print(f"✅ Cleaned: {file_path}")
            return True
        else:
            print(f"⏭️  No changes: {file_path}")
            return False
            
    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")
        return False

def main():
    """Main function to process all Dart files"""
    if len(sys.argv) > 1:
        project_root = sys.argv[1]
    else:
        project_root = "."
    
    lib_dir = os.path.join(project_root, "lib")
    
    if not os.path.exists(lib_dir):
        print(f"❌ lib directory not found at: {lib_dir}")
        return
    
    print(f"🔍 Scanning for Dart files in: {lib_dir}")
    
    files_processed = 0
    files_changed = 0
    
    # Walk through all Dart files in lib directory
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                files_processed += 1
                
                if remove_print_statements(file_path):
                    files_changed += 1
    
    print(f"\n📊 Summary:")
    print(f"   Files processed: {files_processed}")
    print(f"   Files changed: {files_changed}")
    print(f"   debugPrint() statements preserved")
    
    if files_changed > 0:
        print(f"\n⚠️  Please review the changes and run 'flutter analyze' to check for any issues.")

if __name__ == "__main__":
    main() 