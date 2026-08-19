import os
import re

lib_dir = r"c:\Users\Aastha\Desktop\sem 7\Minor Project\TripSync\Frontend\lib"

# We need to add imports to every modified file:
imports_to_add = """
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart'; // Note: Adjust import path if needed, we can use relative or absolute. Wait, it's better to just use relative or project absolute. Let's use `import 'package:YOUR_APP_NAME...` wait, app name is `tripsync` in pubspec.yaml.
"""
# Let's use project absolute: import 'package:tripsync/core/utils/image_utils.dart';

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    
    # Check if we need to modify
    if 'NetworkImage' not in content and 'Image.network' not in content:
        return
        
    print(f"Modifying {filepath}")

    # Replace NetworkImage(url) -> CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(url))
    # Regex handles optional whitespace and string/variable inside.
    # We will use a function to properly balance parentheses if needed, but a simple regex might work for 90% of cases.
    
    # It's safer to just do simple regex for NetworkImage:
    content = re.sub(
        r'NetworkImage\s*\(\s*(.+?)\s*\)',
        r'CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(\1))',
        content
    )

    # For Image.network(url, ...) -> CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl(url), ...)
    # This is tricky because it spans multiple lines.
    # Let's find all occurrences of Image.network(
    
    def repl_image_network(match):
        inner = match.group(1)
        # Split by the first comma (ignoring commas inside nested calls is hard with simple split, 
        # but usually the URL is just a string or variable before the first comma or the end of paren).
        
        # Let's find the first comma
        comma_idx = inner.find(',')
        if comma_idx != -1:
            url_part = inner[:comma_idx].strip()
            rest = inner[comma_idx+1:]
            
            # replace errorBuilder with errorWidget
            rest = re.sub(r'errorBuilder:\s*\([^\)]+\)\s*=>', r'errorWidget: (context, url, error) =>', rest)
            
            return f"CachedNetworkImage(\n  imageUrl: ImageUtils.getOptimizedImageUrl({url_part}),{rest})"
        else:
            url_part = inner.strip()
            return f"CachedNetworkImage(\n  imageUrl: ImageUtils.getOptimizedImageUrl({url_part})\n)"

    # A better approach for Image.network is to replace the start "Image.network(" and the first argument.
    # We can match `Image.network(  foo  ,` -> `CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl(foo),`
    # and `Image.network( foo )` -> `CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl(foo))`
    
    content = re.sub(r'Image\.network\s*\(\s*([^,]+)\s*,', r'CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl(\1),', content)
    content = re.sub(r'Image\.network\s*\(\s*([^,]+)\s*\)', r'CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl(\1))', content)

    # Replace errorBuilder for CachedNetworkImage
    content = re.sub(r'errorBuilder:\s*\([^\)]+\)\s*=>', r'errorWidget: (context, url, error) =>', content)

    if content != original_content:
        # Add imports if not present
        if 'cached_network_image.dart' not in content:
            # find last import
            last_import_idx = content.rfind("import '")
            if last_import_idx != -1:
                end_of_line = content.find('\n', last_import_idx)
                content = content[:end_of_line] + "\nimport 'package:cached_network_image/cached_network_image.dart';\nimport 'package:tripsync/core/utils/image_utils.dart';" + content[end_of_line:]
            else:
                content = "import 'package:cached_network_image/cached_network_image.dart';\nimport 'package:tripsync/core/utils/image_utils.dart';\n" + content
                
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
