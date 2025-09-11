-- The MIT License (MIT)
--
-- Copyright (c) 2024 bundlecore
--
help([==[

Description
===========
The Genome Analysis Toolkit (GATK) is a set of bioinformatic tools for analyzing high-throughput sequencing (HTS) and variant call format (VCF) data. The toolkit is well established for germline short variant discovery from whole genome and exome sequencing data. GATK4 expands functionality into copy number and somatic analyses and offers pipeline scripts for workflows.

More information
================
 - Home page: https://www.broadinstitute.org/gatk/
 - DOI:	https://doi.org/10.1101/gr.107524.110
 - License: https://spdx.org/licenses/Apache-2.0
 - Category: {"Sequence analysis", "Genetic variation", "Polymorphism detection", "Genotyping", "Statistical calculation"}
]==])

whatis("Name: GATK4")
whatis("Version: 4.6.2.0--py310hdfd78af_0")
whatis("Description: The Genome Analysis Toolkit (GATK) is a set of bioinformatic tools for analyzing high-throughput sequencing (HTS) and variant call format (VCF) data. The toolkit is well established for germline short variant discovery from whole genome and exome sequencing data. GATK4 expands functionality into copy number and somatic analyses and offers pipeline scripts for workflows.")
whatis("Home page: https://www.broadinstitute.org/gatk/")

conflict(myModuleName())

local programs = {"gatk"}
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
