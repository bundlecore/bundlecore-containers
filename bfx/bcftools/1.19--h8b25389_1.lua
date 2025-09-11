-- The MIT License (MIT)
--
-- Copyright (c) 2024 bundlecore
--
help([==[

Description
===========
BCFtools is a set of utilities that manipulate variant calls in the Variant Call Format (VCF) and its binary counterpart BCF. All commands work transparently with both VCFs and BCFs, both uncompressed and BGZF-compressed.

More information
================
 - Home page: https://www.htslib.org/
 - DOI:	https://dx.doi.org/10.1093/bioinformatics/btp352
 - License: https://spdx.org/licenses/MIT
 - Category: {"Genetic variation", "DNA polymorphism", "GWAS study", "Genotyping experiment", "Data handling", "Variant calling"}
]==])

whatis("Name: BCFtools")
whatis("Version: 1.19--h8b25389_1")
whatis("Description: BCFtools is a set of utilities that manipulate variant calls in the Variant Call Format (VCF) and its binary counterpart BCF. All commands work transparently with both VCFs and BCFs, both uncompressed and BGZF-compressed.")
whatis("Home page: https://www.htslib.org/")

conflict(myModuleName())

local programs = {"bcftools", "color-chrs.pl", "guess-ploidy.py", "plot-roh.py", "plot-vcfstats", "run-roh.pl", "vcfutils.pl"}
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
