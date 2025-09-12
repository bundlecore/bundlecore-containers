-- The MIT License (MIT)
--
-- Copyright (c) 2024 bundlecore
--
help([==[

Description
===========
A C++ drop-in replacement of FastQC to assess the quality of sequence read data

More information
================
 - Home page: https://falco.readthedocs.io/
 - DOI:	doi.org/10.12688/f1000research.21142.2
 - License: https://spdx.org/licenses/LGPL-3.0-or-later.html
 - Category: {"Data quality management", "Sequencing quality control", "Sequence composition calculation"}
]==])

whatis("Name: Falco")
whatis("Version: 1.2.0--h9f5acd7_0")
whatis("Description: A C++ drop-in replacement of FastQC to assess the quality of sequence read data")
whatis("Home page: https://falco.readthedocs.io/")

conflict(myModuleName())

local programs = {"falco"}
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
