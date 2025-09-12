-- The MIT License (MIT)
--
-- Copyright (c) 2024 bundlecore
--
help([==[

Description
===========
BEDTools is an extensive suite of utilities for comparing genomic features in BED format.

More information
================
 - Home page: https://bedtools.readthedocs.io/en/latest/
 - DOI:	https://doi.org/10.1093/bioinformatics/btq033
 - License: https://spdx.org/licenses/MIT.html
 - Category: {"Genomics", "Data formatting", "Sequence merging"}
]==])

whatis("Name: BEDTools")
whatis("Version: 2.31.0--hf5e1c6e_3")
whatis("Description: BEDTools is an extensive suite of utilities for comparing genomic features in BED format.")
whatis("Home page: https://bedtools.readthedocs.io/en/latest/")

conflict(myModuleName())

local programs = {"annotateBed", "bamToBed", "bamToFastq", "bed12ToBed6", "bedpeToBam", "bedToBam", "bedToIgv", "bedtools", "closestBed", "clusterBed", "complementBed", "coverageBed", "expandCols", "fastaFromBed", "flankBed", "genomeCoverageBed", "getOverlap", "groupBy", "intersectBed", "linksBed", "mapBed", "maskFastaFromBed", "mergeBed", "multiBamCov", "multiIntersectBed", "nucBed", "pairToBed", "pairToPair", "randomBed", "shiftBed", "shuffleBed", "slopBed", "sortBed", "subtractBed", "tagBam", "unionBedGraphs", "windowBed", "windowMaker"}
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
