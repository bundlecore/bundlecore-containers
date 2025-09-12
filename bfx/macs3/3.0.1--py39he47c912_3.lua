-- The MIT License (MIT)
--
-- Copyright (c) 2024 bundlecore
--
help([==[

Description
===========
Model based analysis for chip-seq data

More information
================
 - Home page: https://macs3-project.github.io/MACS
 - DOI:	10.1186/gb-2008-9-9-r137
 - License: BSD 3-Clause "New" or "Revised" License
 - Category: {"ChIP-seq", "Molecular interactions", "Pathways and networks", "Transcription factors and regulatory sites"}
]==])

whatis("Name: MACS3")
whatis("Version: 3.0.1--py39he47c912_3")
whatis("Description: Model based analysis for chip-seq data")
whatis("Home page: https://macs3-project.github.io/MACS")

conflict(myModuleName())

local programs = {"macs3"}
local entrypoint_args = ""

-- The absolute path to Apptainer is needed
-- nodes without the corresponding module necessarily being loaded.
local apptainer = capture("which apptainer | head -c -1")

local cimage = "BC_IMAGE_DIR/IMAGE_NAME"
if not (isFile(cimage)) then
   -- The image could not be found in the container directory
   if (mode() == "load") then
      LmodMessage("file not found: " .. cimage)
   end
end


-- Determine Nvidia and/or AMD GPUs (set the flag to Apptainer)
local run_args = {}
if (capture("nvidia-smi -L 2>/dev/null") ~= "") then
   if (mode() == "load") then
      LmodMessage("BC: Enabling Nvidia GPU support in the container.")
   end
   table.insert(run_args, "--nv")
end
if (capture("/opt/rocm/bin/rocm-smi -i 2>/dev/null | grep ^GPU") ~= "") then
   if (mode() == "load") then
      LmodMessage("BC: Enabling AMD GPU support in the container.")
   end
   table.insert(run_args, "--rocm")
end

-- Assemble container command
local app_cmd = apptainer .. " run " .. table.concat(run_args, " ") .. " " .. cimage .. " " .. entrypoint_args

-- Programs to setup in the shell
for i,program in pairs(programs) do
    set_shell_function(program, app_cmd .. " " .. program .. " \"$@\"",
                                app_cmd .. " " .. program .. " $*")
end
