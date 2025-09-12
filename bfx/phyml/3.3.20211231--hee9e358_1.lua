-- The MIT License (MIT)
--
-- Copyright (c) 2024 bundlecore
--
help([==[

Description
===========
Phylogenetic estimation software using Maximum Likelihood

More information
================
 - Home page: http://www.atgc-montpellier.fr/phyml/
 - DOI:	https://dx.doi.org/10.1093/sysbio/syq010
 - License: https://spdx.org/licenses/GPL-3.0
 - Category: {"Phylogenetics", "Evolutionary biology"}
]==])

whatis("Name: PhyML")
whatis("Version: 3.3.20211231--hee9e358_1")
whatis("Description: Phylogenetic estimation software using Maximum Likelihood")
whatis("Home page: http://www.atgc-montpellier.fr/phyml/")

conflict(myModuleName())

local programs = {"phyml", "phyml-mpi", "phyrex", "phytime"}
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
