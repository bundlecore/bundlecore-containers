import json
import sys
import requests
import os


def fill_lua_template_from_api(tool_name, tool_version, lua_template_path, tool_domain):
    """
    Reads JSON data from Bundlecore API and generates one Lua file per version of rgw tool using a template.

    :param tool_name: Tool name to be used in the API URL
    :param tool_version: Tool version to be filled in the Lua template
    :param lua_template_path: Path to the Lua template file

    """
    try:

        # Read the Lua template
        with open(lua_template_path, 'r') as lua_file:
            lua_template_content = lua_file.read()
            
        # Connect with Bundlecore API and get the JSON data
        """Call Bcore appstore and list new apps and versions. Usage: appstore <tool name>"""
        API_URL = f"https://bundlecore.com/api/tools/{tool_name}"
        AUTH_TOKEN = os.environ.get("BCORE_AUTH_TOKEN")
        if not AUTH_TOKEN:
            print("Error: BCORE_AUTH_TOKEN environment variable not set.")
            sys.exit(1)

        # Set up the headers with Authorization
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
            "Authorization": f"Bearer {AUTH_TOKEN}",
            "Accept": "application/json"
        }


        try:
            response = requests.get(API_URL, headers=headers)
            print(f"Received response with status code: {response.status_code}")
            if response.status_code == 200:
                data = response.json()
                #print(json.dumps(data, indent=4))
                versions  = data.get("data", {}).get("tool", {}).get("versions", [])
                data_tool = data.get("data", {}).get("tool", {})
            else:
                print(f"Failed to retrieve data. Status code: {response.status_code}")
                print("Response:", response.text)
        except requests.RequestException as e:
            print(f"Bcore remote host not reachable. Please contact support team for help.")
            print(e)              
                
        if not versions:
            print(f"No versions found for tool {tool_name} from Bcore api data.")
            return

        # Generate Lua scripts for each tag
        for idx, version in enumerate(versions):
            try:
                if version.get("version") != tool_version:
                    continue

                tool_version_ = version.get("version", "N/A")
                uri = version.get("bcRegistryUrl", "N/A")
                
                cmds = ', '.join('"{0}"'.format(w) for w in version.get("commands", "N/A"))
                name = data_tool.get("name", "N/A")
                description = data_tool.get("description", "N/A")
                url = data_tool.get("url", "N/A")
                doi = data_tool.get("doi", "N/A")
                license = data_tool.get("license", "N/A")
                categories = ', '.join('"{0}"'.format(w) for w in data_tool.get("categories", "N/A"))
                entrypoint_args = ', '.join('"{0}"'.format(w) for w in version.get("entryCmds", "N/A")) 
                #print(version,uri,cmds,description,url,doi,license,categories,entrypoint_args)
                # Fill template with tag details

                filled_lua = lua_template_content.format( 
                    version = tool_version_, 
                    uri = uri,
                    cmds = cmds,
                    name = name,
                    description = description,
                    url = url,
                    doi = doi,
                    license = license,
                    categories = categories,
                    entrypoint_args = entrypoint_args
                )
                # Ensure the output directory exists
                # os.makedirs(os.path.join(tool_domain, tool_name), exist_ok=True)
                
                # Output file path
                lua_output_path = os.path.join(tool_domain, tool_name, tool_version + ".lua")

                # Write the filled Lua file
                with open(lua_output_path, 'w') as output_file:
                    output_file.write(filled_lua)

                print(f"Generated Lua file: {lua_output_path}")
            except KeyError as e:
                print(f"Missing placeholder in template for tag {idx + 1}: {e}")
            except Exception as e:
                print(f"Error processing tag {idx + 1}: {e}")

    except FileNotFoundError as e:
        print(f"Error: File not found - {e}")
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON format - {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":

    # Input and output file paths
    try:
        tool_name    = sys.argv[1].strip()  #"star" # Tool name from command line argument
        tool_version = sys.argv[2].strip()  #"2.7.11b--h5ca1c30_5" # Tool version from command line argument
        tool_domain = sys.argv[3].strip()  ## bfx # Tool domain from command line argument
             
    except IndexError:
        print("Error: Missing command line argument for tool/version.")
        sys.exit(1)
    
    try:
        lua_template_path = 'scripts/template_file.lua'  # Path to the Lua template file
        if not os.path.isfile(lua_template_path):
            print(f"Error: Lua template file '{lua_template_path}' not found.")
            sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
    

    # Generate Lua files
    fill_lua_template_from_api(tool_name, tool_version, lua_template_path, tool_domain)
