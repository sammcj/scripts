package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"syscall"
	"text/template"
)

// GeneratePlist generates a launchd plist file based on user input
func GeneratePlist() {
	const plistTemplate = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>{{.Label}}</string>
	<key>ProgramArguments</key>
	<array>
		<string>{{.TargetCommand}}</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>ENV_VARS</key>
		<string>{{.EnvVars}}</string>
	</dict>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>
`

	// Set default values
	data := struct {
		Label         string
		TargetCommand string
		EnvVars       string
	}{
		Label:         "DefaultLabel",
		TargetCommand: "/usr/local/bin/myapp",
		EnvVars:       "",
	}

	// Read user input and override defaults if provided
	fmt.Print("Enter Label (Default:" + data.Label + "): ")
	fmt.Scanln(&data.Label)
	fmt.Print("Enter Target Command (Default: " + data.TargetCommand + "): ")
	fmt.Scanln(&data.TargetCommand)
	fmt.Print("Enter Environment Variables (Default:" + data.EnvVars + "): ")
	fmt.Scanln(&data.EnvVars)

	tmpl, err := template.New("plist").Parse(plistTemplate)
	if err != nil {
		fmt.Println("Error creating template:", err)
		return
	}

	plistPath := filepath.Join(".", data.Label+".plist")
	fmt.Println("Saving plist to:", plistPath)

	file, err := os.Create(plistPath)
	if err != nil {
		fmt.Println("Error creating plist file:", err)
		return
	}
	defer file.Close()

	// output the plist to file
	err = tmpl.Execute(file, data)
	if err != nil {
		fmt.Println("Error executing template:", err)
	}

	// output the plist to stdout
	err = tmpl.Execute(os.Stdout, data)
	if err != nil {
		fmt.Println("Error executing template:", err)
	}

}

// InstallAndLoadPlist installs and loads the plist into launchd
func InstallAndLoadPlist(plistPath string) {
	usr, err := user.Current()
	if err != nil {
		fmt.Println("Cannot get the current user:", err)
		return
	}

	destPath := filepath.Join(usr.HomeDir, "Library", "LaunchAgents", filepath.Base(plistPath))
	cmd := exec.Command("sudo", "cp", plistPath, destPath)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err = cmd.Run()
	if err != nil {
		fmt.Println("Failed to copy plist:", err)
		return
	}

	cmd = exec.Command("sudo", "launchctl", "load", destPath)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err = cmd.Run()
	if err != nil {
		fmt.Println("Failed to load plist:", err)
		return
	}

	fmt.Println("Plist installed and loaded successfully.")
}

// main is the entrypoint for the program
func main() {
	if len(os.Args) < 2 {
		fmt.Println("Insufficient arguments provided.")
		fmt.Println("Usage:")
		fmt.Println("  launchdanything generate-plist")
		fmt.Println("  launchdanything install-plist <plist-path>")
		fmt.Println("  launchdanything <command> <args>")
		os.Exit(1)
	}

	if len(os.Args) == 2 && os.Args[1] == "generate-plist" {
		GeneratePlist()
		return
	}

	if len(os.Args) == 3 && os.Args[1] == "install-plist" {
		InstallAndLoadPlist(os.Args[2])
		return
	}

	cmdName := os.Args[1]
	cmdArgs := os.Args[2:]

	// Set environment variables if any
	envVars := os.Getenv("ENV_VARS")
	if envVars != "" {
		os.Setenv("ENV_VARS", envVars)
	}

	// Create the command
	cmd := exec.Command(cmdName, cmdArgs...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}

	// Inherit environment variables
	if os.Getenv("INHERIT_ENV") == "true" {
		cmd.Env = os.Environ()
	}

	// Execute the command
	err := cmd.Start()
	if err != nil {
		fmt.Printf("Failed to start command: %s\n", err)
		os.Exit(1)
	}

	fmt.Printf("Started process with PID %d\n", cmd.Process.Pid)
}
