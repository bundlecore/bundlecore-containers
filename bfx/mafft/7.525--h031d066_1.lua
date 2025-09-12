-- The MIT License (MIT)
--
-- Copyright (c) 2024 bundlecore
--
help([==[

Description
===========
MAFFT (Multiple Alignment using Fast Fourier Transform) is a high speed multiple sequence alignment program.

More information
================
 - Home page: http://mafft.cbrc.jp/alignment/server/index.html
 - DOI:	https://doi.org/10.1093/bib/bbx108
 - License: https://spdx.org/licenses/BSD-Source-Code
 - Category: {"Multiple sequence alignment", "Sequence analysis"}
]==])

whatis("Name: MAFFT")
whatis("Version: 7.525--h031d066_1")
whatis("Description: MAFFT (Multiple Alignment using Fast Fourier Transform) is a high speed multiple sequence alignment program.")
whatis("Home page: http://mafft.cbrc.jp/alignment/server/index.html")

conflict(myModuleName())

local programs = {"mafft", "mafft-distance", "mafft-einsi", "mafft-fftns", "mafft-fftnsi", "mafft-ginsi", "mafft-homologs.rb", "mafft-linsi", "mafft-nwns", "mafft-nwnsi", "mafft-profile", "mafft-qinsi", "mafft-sparsecore.rb", "mafft-xinsi", "einsi", "fftns", "fftnsi", "ginsi", "linsi", "nwns", "nwnsi"}
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
