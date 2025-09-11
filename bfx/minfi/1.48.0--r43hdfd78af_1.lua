-- The MIT License (MIT)
--
-- Copyright (c) 2024 bundlecore
--
help([==[

Description
===========
Tools to analyze & visualize Illumina Infinium methylation arrays.

More information
================
 - Home page: https://bioconductor.org/packages/minfi
 - DOI:	https://dx.doi.org/10.1093/bioinformatics/btw691
 - License: https://spdx.org/licenses/Artistic-2.0
 - Category: {"DNA Methylation", "Epigenetics", "Microarray experiment"}
]==])

whatis("Name: minfi")
whatis("Version: 1.48.0--r43hdfd78af_1")
whatis("Description: Tools to analyze & visualize Illumina Infinium methylation arrays.")
whatis("Home page: https://bioconductor.org/packages/minfi")

conflict(myModuleName())

local programs = {}
local entrypoint_args = ""

-- The absolute path to Apptainer is needed
-- nodes without the corresponding module necessarily being loaded.
local apptainer = capture("which apptainer | head -c -1")

local cimage = pathJoin(os.getenv("BC_IMAGE_DIR"), ("IMAGE_NAME"))
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
