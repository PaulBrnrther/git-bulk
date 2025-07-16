# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a git bulk operations project for performing git commands on multiple repositories in parallel. The project provides bash scripts that take a list of repository names and execute git operations across all of them simultaneously.

## Architecture

The project follows a simple script-based architecture:

- **Repository List Files**: Plain text files containing repository names (one per line). Comments starting with `#` and empty lines are ignored.
- **Bash Scripts**: Individual executable scripts for different git operations, each taking two arguments:
  1. Path to a repository list file
  2. Path to directory containing the repositories
- **Error Handling**: Scripts validate inputs, check for git repositories, and provide meaningful warnings for missing or invalid repos.

## Current Scripts

### git-status.sh
Shows git status for repositories specified in a list file with colorized, compact output for easy visual parsing.

Usage: `./git-status.sh <repo_list_file> <repos_directory>`

## Repository Structure Pattern

Scripts expect:
- A directory containing multiple git repositories as subdirectories
- Repository list files containing names matching the subdirectory names
- Each subdirectory must be a valid git repository (contain `.git` directory)

## Example Usage

```bash
# Show git status for repos in repos-with-defaultnodesettings
./git-status.sh repos-with-defaultnodesettings ~/knime/repos
```

## Development Notes

- All scripts should be executable (`chmod +x`)
- Scripts change directory to each repository before executing git commands
- Error handling includes validation of file existence, directory existence, and git repository validity
- Output format uses `=== repo_name ===` headers to separate results from different repositories

## Output Design Principles

- This is a productivity tool, so the output of a script should be visually parsable easily: Compact layout and using coloring where it makes sense

## Safety and Configurability

- The tools should be safe to use per default and optionally configurable to do unsafe things (e.g. by --no-fetch for a script that resets to origin or --no-stash for a tool that checks out a new branch)