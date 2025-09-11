-- The MIT License (MIT)
--
-- Copyright (c) 2024 bundlecore
--
help([==[

Description
===========
A program for quantifying abundances of transcripts from RNA-Seq data, or more generally of target sequences using high-throughput sequencing reads. It is based on the novel idea of pseudoalignment for rapidly determining the compatibility of reads with targets, without the need for alignment.

More information
================
 - Home page: https://pachterlab.github.io/kallisto/
 - DOI:	https://dx.doi.org/10.1038/nbt.3519
 - License: https://spdx.org/licenses/BSD-2-Clause
 - Category: {"Transcriptomics", "RNA-Seq", "Gene expression", "Gene expression profiling", "Statistical models", "Sequence analysis"}
]==])

whatis("Name: kallisto")
whatis("Version: 0.50.0--hc877fd6_0")
whatis("Description: A program for quantifying abundances of transcripts from RNA-Seq data, or more generally of target sequences using high-throughput sequencing reads. It is based on the novel idea of pseudoalignment for rapidly determining the compatibility of reads with targets, without the need for alignment.")
whatis("Home page: https://pachterlab.github.io/kallisto/")

conflict(myModuleName())

local programs = {"kallisto"}
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
