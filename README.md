### Summary
"Why Not Repack?" is a utility designed for unpacking and repacking binary files. It relies on tools like ```binwalk``` for parsing binary sections and ```dd``` for the unpacking and repacking operations.
--- 
### Download and install
```bash
$ git clone https://github.com/Lucas-WF/why-not-repack/ && cd why-not-repack
$ chmod +x why-not-repack.sh
```
---
### Usage
```
Usage: ./packer.sh [-u|-r] -f input_file
Options:
  -h  To see the help menu
  -u  Unpack the input file
  -r  Repack the unpacked files
  -f  Specify the input file
  -n  Repack without the uImage Header
```
---
### How it works
During the unpacking process, "Why Not Repack?" creates a file named "repack_info" containing descriptions of binary sections, along with their start and end offsets. It also generates an "unpacked" directory to store all sections as binary files. If a section is repeated, the utility renames the file as ```<section>-<count>.bin```.
Repacking requires the "repack_info" file and the "unpacked" directory. If repacking with the -n flag, the uImage header is excluded, allowing you to add it later with a tool like ```mkimage```.
---
### Contribution
Please, contribute! This is just a hobby (4fun) two days project. Every help to improve the tool is welcome!
---
### License
This tool is licensed under MIT License
