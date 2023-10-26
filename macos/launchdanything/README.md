# LaunchdAnything

A simple Go application designed to work with macOS's `launchd` to run processes.

This application allows you to run a target program/script as an argument and allows for optional environment variables.

## Features

- Generate a `launchd` plist file based on user input.
- Install and load the plist into `launchd`.
- Execute the target command and either exit, leaving the process running, or wait for it to exit.
- Take a list of optional environment variables as arguments.
- Set the process name to the name of the program/script it executes.

## Installation

1. Save the compiled binary to a location of your choice.
2. Generate a plist file using the `generate-plist` command or create one manually.
3. Install and load the plist file using the `install-plist` command or manually.

## Usage

### Generate a plist File

To generate a plist file, run the following command and follow the prompts:

```bash
./launchd_wrapper generate-plist
```

The location where the plist is saved will be displayed.

## Install and Load the plist

To install and load the plist, run the following command:

```bash
./launchd_wrapper install-plist /path/to/plist
```

This may prompt for sudo access.

## Run a Command

To run a command, use the following:

```bash
./launchd_wrapper <command> [args...]
```

## License

MIT License
Copyright (c) 2023 Sam McLeod
