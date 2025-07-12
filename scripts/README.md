# LuaGen Script

## Overview

`luagen.py` automates the generation of Lua files for a specific tool and version using metadata from the Bundlecore API and a Lua template.

## Prerequisites

- Python 3.x
- The `requests` library  
  Install with:
  ```
  pip install requests
  ```
- A Lua template file named `template_file.lua` in the same directory.

## Usage

Run the script from the command line, providing the tool name and tool version as arguments:

```
python luagen.py <tool_name> <tool_version> <tool_domain>
```

**Example:**
```
python luagen.py star 2.7.11b--h5ca1c30_5 bfx
```

This will:
- Fetch metadata for `<tool_name>` from the Bundlecore API.
- Fill the Lua template with data for `<tool_version>`.
- Output a Lua file named `<tool_version>.lua`.

## Notes

- The script requires internet access to reach the Bundlecore API.
- If the template file is missing or the tool/version is not found, the script will print an error message.
- The output Lua file will be created in the current directory.

## Troubleshooting

- **requests not installed:**  
  Run `pip install requests`
- **Missing template:**  
  Ensure `template_file.lua` exists in the script directory.
- **API errors:**  
  Check your network connection or contact