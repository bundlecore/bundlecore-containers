import json

def fill_lua_template_from_json(json_file_path, lua_template_path):
    """
    Reads JSON data, processes tags, and generates one Lua file per tag using a template.

    :param json_file_path: Path to the input JSON file
    :param lua_template_path: Path to the Lua template file
    
    """
    try:
    
        # Read the Lua template
        with open(lua_template_path, 'r') as lua_file:
            lua_template_content = lua_file.read()
            
        # Read JSON data
        with open(json_file_path, 'r') as json_file:
            data = json.load(json_file)
        
        # Extract tags from the JSON data
        tags = data.get("data", {}).get("tool", {}).get("tags", [])
        data_tool = data.get("data", {}).get("tool", {})
                
        if not tags:
            print("No tags found in the JSON data.")
            return

        # Generate Lua scripts for each tag
        for idx, tag in enumerate(tags):
            try:
            
                version=tag.get("version", "N/A")
                uri=tag.get("uri", "N/A")
                #cmds=tag.get("cmds", "N/A")
                
                cmds=', '.join('"{0}"'.format(w) for w in tag.get("cmds", "N/A"))
                name=data_tool.get("name","N/A")
                description=data_tool.get("description","N/A")
                url=data_tool.get("url","N/A")
                doi=data_tool.get("doi","N/A")
                license=data_tool.get("license","N/A")
                categories=', '.join('"{0}"'.format(w) for w in data_tool.get("categories","N/A"))
                entrypoint_args=data_tool.get("entrypoint_args","N/A")
                #print(version,uri,cmds,description,url,doi,license,categories,entrypoint_args)
                # Fill template with tag details

                filled_lua = lua_template_content.format( 
                    version = version, 
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
                lua_output_path = version+".lua"

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
    json_file_path = 'data.json'  # Path to the uploaded JSON file
    lua_template_path = 'template_file.lua'  # Path to the Lua template file
    

    # Generate Lua files
    fill_lua_template_from_json(json_file_path, lua_template_path)
