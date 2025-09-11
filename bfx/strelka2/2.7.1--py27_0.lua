-- The MIT License (MIT)
--
-- Copyright (c) 2024 bundlecore
--
help([==[

Description
===========
Strelka is an analysis package designed to detect somatic SNVs and small indels from the aligned sequencing reads of matched tumor-normal samples.

More information
================
 - Home page: https://github.com/Illumina/strelka
 - DOI:	doi.org/10.1038/s41592-018-0051-x
 - License: GNU General Public License v3.0 or later
 - Category: {"Genetic variation", "Variant calling"}
]==])

whatis("Name: Strelka2")
whatis("Version: 2.7.1--py27_0")
whatis("Description: Strelka is an analysis package designed to detect somatic SNVs and small indels from the aligned sequencing reads of matched tumor-normal samples.")
whatis("Home page: https://github.com/Illumina/strelka")

conflict(myModuleName())

local programs = {"configureStrelkaGermlineWorkflow.py", "configureStrelkaSomaticWorkflow.py", "runStrelkaGermlineWorkflowDemo.bash", "runStrelkaSomaticWorkflowDemo.bash"}
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
