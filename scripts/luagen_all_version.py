import json
import sys
import requests
import os


def fill_lua_template_from_api(tool_name, lua_template_path):
    """
    Reads JSON data from Bundlecore API, processes tags, and generates one Lua file per tag using a template.

    :param tool_name: Tool name to be used in the API URL
    :param lua_template_path: Path to the Lua template file
    
    """
    try:
    
        # Read the Lua template
        with open(lua_template_path, 'r') as lua_file:
            lua_template_content = lua_file.read()
            
        # Connect with Bundlecore API and get the JSON data
        """Call Bcore appstore and list new apps and versions. Usage: appstore <tool name>"""
        API_URL = f"https://bundlecore.com/api/tools/{tool_name}"
        AUTH_TOKEN = os.getenv('BCORE_AUTH_TOKEN')
        if not AUTH_TOKEN:
            raise ValueError("BCORE_AUTH_TOKEN environment variable is not set")

        # Set up the headers with Authorization
        headers = {
            "Authorization": f"Bearer {AUTH_TOKEN}",
            "Accept": "application/json"
        }


        try:
            response = requests.get(API_URL, headers=headers)
            if response.status_code == 200:
                data = response.json()
                print(json.dumps(data, indent=4))
                versions  = data.get("data", {}).get("tool", {}).get("versions", [])
                data_tool = data.get("data", {}).get("tool", {})
            else:
                print(f"Failed to retrieve data. Status code: {response.status_code}")
                print("Response:", response.text)
        except requests.RequestException as e:
            print(f"Bcore remote host not reachable. Please contact support team for help.")
            print(e)              
                
        if not versions:
            print("No versions found from Bcore api data.")
            return

        # Generate Lua scripts for each tag
        for idx, version in enumerate(versions):
            try:
            
                tool_version = version.get("version", "N/A")
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
                    version = tool_version, 
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
                
                # Output file path
                lua_output_path = tool_version+".lua"

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
        tool_name = sys.argv[0].strip()  # Tool name from command line argument
    except IndexError:
        print("Error: Missing command line argument for tool name.")
        sys.exit(1)
    
    try:
        lua_template_path = 'template_file.lua'  # Path to the Lua template file
        if not os.path.isfile(lua_template_path):
            print(f"Error: Lua template file '{lua_template_path}' not found.")
            sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
    

    # Generate Lua files
    fill_lua_template_from_api(tool_name, lua_template_path)
