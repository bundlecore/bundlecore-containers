-- The MIT License (MIT)
--
-- Copyright (c) 2024 bundlecore
--
help([==[

Description
===========
Snpeff is an open source tool that annotates variants and predicts their effects on genes by using an interval forest approach

More information
================
 - Home page: http://pcingola.github.io/SnpEff/
 - DOI:	10.4161/fly.19695
 - License: https://spdx.org/licenses/MIT
 - Category: {"DNA polymorphism", "Genetic variation", "SNP detection"}
]==])

whatis("Name: SnpEff")
whatis("Version: 5.2--hdfd78af_1")
whatis("Description: Snpeff is an open source tool that annotates variants and predicts their effects on genes by using an interval forest approach")
whatis("Home page: http://pcingola.github.io/SnpEff/")

conflict(myModuleName())

local programs = {"snpEff"}
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
