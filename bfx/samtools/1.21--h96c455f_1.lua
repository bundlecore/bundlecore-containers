-- The MIT License (MIT)
--
-- Copyright (c) 2024 bundlecore
--
help([==[

Description
===========
SAMtools are widely used for processing and analysing high-throughput sequencing data. They include tools for file format conversion and manipulation, sorting, querying, statistics, variant calling, and effect analysis amongst other methods.

More information
================
 - Home page: https://www.htslib.org/
 - DOI:	https://dx.doi.org/10.1093/bioinformatics/btp352
 - License: https://spdx.org/licenses/MIT
 - Category: {"Mapping", "Sequence analysis", "Data formatting", "Data filtering", "Indexing"}
]==])

whatis("Name: SAMtools")
whatis("Version: 1.21--h96c455f_1")
whatis("Description: SAMtools are widely used for processing and analysing high-throughput sequencing data. They include tools for file format conversion and manipulation, sorting, querying, statistics, variant calling, and effect analysis amongst other methods.")
whatis("Home page: https://www.htslib.org/")

conflict(myModuleName())

local programs = {"ace2sam", "blast2sam.pl", "bowtie2sam.pl", "export2sam.pl", "fasta-sanitize.pl", "interpolate_sam.pl", "maq2sam-long", "maq2sam-short", "md5fa", "md5sum-lite", "novo2sam.pl", "plot-ampliconstats", "plot-bamstats", "psl2sam.pl", "sam2vcf.pl", "samtools", "samtools.pl", "seq_cache_populate.pl", "soap2sam.pl", "wgsim", "wgsim_eval.pl", "zoom2sam.pl"}
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
