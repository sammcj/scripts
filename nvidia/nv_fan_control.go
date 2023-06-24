// A simple tool that adjusts the fan speed of the GPU based on its temperature.
// Its designed for a custom cooler I have on my Nvidia Tesla P100 which is a 12v non-pwm fan.
// Author: Sam McLeod @sammcj
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

var fanPath string
var fanSensitivity int
var daemonMode bool
var pollInterval int
var listAllFans bool
var basePWM int
var maxPWM int
var noSave bool
var noLoad bool
var temp bool

const configPath = "~/.config/nv_fan_control"

type Config struct {
	FanPath        string `json:"fan_path"`
	FanSensitivity int    `json:"fan_sensitivity"`
	DaemonMode     bool   `json:"daemon_mode"`
	PollInterval   int    `json:"poll_interval"`
	BasePWM        int    `json:"base_pwm"`
	MaxPWM         int    `json:"max_pwm"`
}

func init() {
	// 1. Define all flags
	flag.StringVar(&fanPath, "fanpath", "/sys/class/hwmon/hwmon4/pwm3", "Path to the PWM fan control")
	flag.IntVar(&fanSensitivity, "sensitivity", 5, "Adjust this value. Higher means more aggressive fan response, and lower is more gradual.")
	flag.BoolVar(&daemonMode, "daemon", false, "Run as a background daemon")
	flag.IntVar(&pollInterval, "interval", 5, "Polling interval in seconds")
	flag.BoolVar(&listAllFans, "list", false, "List all controllable fans")
	flag.IntVar(&basePWM, "basePWM", 62, "Baseline PWM value for the fan")
	flag.IntVar(&maxPWM, "maxPWM", 255, "Maximum PWM value for the fan")
	flag.BoolVar(&noSave, "nosave", false, "Prevent saving to the config file on shutdown")
	flag.BoolVar(&noLoad, "noload", false, "Prevent loading from the config file on start")
	flag.BoolVar(&temp, "temp", false, "Print the current GPU temperature and exit")

	// 2. Parse the flags
	flag.Parse()

	// If `-temp` is set, set noload, nosave print the GPU temperature and exit
	if temp {
		noLoad = true
		noSave = true
		fmt.Println(getGPUTemperature())
		os.Exit(0)
	}

	// Store the original flag values
	originalFanPath := fanPath
	originalFanSensitivity := fanSensitivity
	originalDaemonMode := daemonMode
	originalPollInterval := pollInterval
	originalBasePWM := basePWM
	originalMaxPWM := maxPWM

	// 3. If `-noload` is not set and config exists, load the config values
	if !noLoad && !os.IsNotExist(checkConfig()) {
		loadConfig()
	}

	// 4. If any flag is set explicitly by the user, overwrite the corresponding loaded config value with the flag value
	if fanPath != originalFanPath {
		fanPath = originalFanPath
	}
	if fanSensitivity != originalFanSensitivity {
		fanSensitivity = originalFanSensitivity
	}
	if daemonMode != originalDaemonMode {
		daemonMode = originalDaemonMode
	}
	if pollInterval != originalPollInterval {
		pollInterval = originalPollInterval
	}
	if basePWM != originalBasePWM {
		basePWM = originalBasePWM
	}
	if maxPWM != originalMaxPWM {
		maxPWM = originalMaxPWM
	}

	// Save config if `-nosave` is not set
	if !noSave {
		defer saveConfig()
	}
}

func expandHome(path string) string {
	home, _ := os.UserHomeDir()
	return strings.Replace(path, "~", home, 1)
}

func checkConfig() error {
	_, err := os.Stat(expandHome(configPath))
	return err
}

func loadConfig() {
	data, err := os.ReadFile(expandHome(configPath))
	if err != nil {
		log.Println("Failed to read config file:", err)
		return
	}

	var cfg Config
	err = json.Unmarshal(data, &cfg)
	if err != nil {
		log.Println("Failed to parse config file:", err)
		return
	}

	fanPath = cfg.FanPath
	fanSensitivity = cfg.FanSensitivity
	daemonMode = cfg.DaemonMode
	pollInterval = cfg.PollInterval
	basePWM = cfg.BasePWM
	maxPWM = cfg.MaxPWM

	log.Println("Found and loaded config with values:", cfg)
}

func saveConfig() {
	log.Println("Saving current settings to config file...")

	cfg := Config{
		FanPath:        fanPath,
		FanSensitivity: fanSensitivity,
		DaemonMode:     daemonMode,
		PollInterval:   pollInterval,
		BasePWM:        basePWM,
		MaxPWM:         maxPWM,
	}

	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		log.Println("Failed to serialize config:", err)
		return
	}

	err = os.WriteFile(expandHome(configPath), data, 0644)
	if err != nil {
		log.Println("Failed to save config:", err)
	} else {
		log.Println("Config saved successfully. The program will run with these settings next time.")
	}
}

func getGPUTemperature() (int, error) {
	cmd := exec.Command("nvidia-smi", "-q", "-d", "temperature")
	output, err := cmd.Output()
	if err != nil {
		return 0, err
	}

	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if strings.Contains(line, "GPU Current Temp") {
			tempStr := strings.TrimSpace(strings.Split(line, ":")[1])
			tempStr = strings.TrimRight(tempStr, " C") // Remove the " C" from the end
			return strconv.Atoi(tempStr)
		}
	}
	return 0, fmt.Errorf("failed to find GPU temperature")
}

func listControllableFans() ([]string, error) {
	var pwmPaths []string
	hwmons, err := os.ReadDir("/sys/class/hwmon")
	if err != nil {
		return nil, err
	}

	for _, hwmon := range hwmons {
		potentialPaths, _ := filepath.Glob("/sys/class/hwmon/" + hwmon.Name() + "/pwm*")
		for _, path := range potentialPaths {
			if _, err := os.OpenFile(path, os.O_WRONLY, 0644); err == nil {
				pwmPaths = append(pwmPaths, path)
			}
		}
	}

	return pwmPaths, nil
}

func adjustFanSpeed() {
	TEMP, err := getGPUTemperature()
	if err != nil {
		log.Println("Error reading GPU temperature:", err)
		return
	}

	// Points for linear equation
	x1 := 30
	y1 := basePWM
	x2 := 80
	y2 := maxPWM - (fanSensitivity-1)*5
	// For every increase in sensitivity by 1, the point y2y2 decreases by 5.

	// Calculate PWM value using linear equation
	PWM := (TEMP-x1)*(y2-y1)/(x2-x1) + y1

	// Ensure PWM is within bounds
	if PWM < basePWM {
		PWM = basePWM
	} else if PWM > maxPWM {
		PWM = maxPWM
	}

	err = os.WriteFile(fanPath, []byte(strconv.Itoa(PWM)), 0644)
	if err != nil {
		log.Println("Failed to adjust fan speed:", err)
		return
	}

	log.Printf("Adjusted fan speed to %d based on GPU temperature of %d°C.\n", PWM, TEMP)
}

func suggestUdevRules() {
	hwmons, err := os.ReadDir("/sys/class/hwmon")
	if err != nil {
		log.Fatalf("Error reading hwmon directory: %v", err)
	}

	rules := []string{}
	for _, hwmon := range hwmons {
		// Construct the path to the device's attributes
		path := filepath.Join("/sys/class/hwmon", hwmon.Name(), "device")

		// Try to read idVendor and idProduct
		idVendor, errVendor := os.ReadFile(filepath.Join(path, "idVendor"))
		idProduct, errProduct := os.ReadFile(filepath.Join(path, "idProduct"))

		if errVendor == nil && errProduct == nil {
			rule := fmt.Sprintf(`SUBSYSTEM=="hwmon", ATTRS{idVendor}=="%s", ATTRS{idProduct}=="%s", SYMLINK+="fancontroller_%s"`, strings.TrimSpace(string(idVendor)), strings.TrimSpace(string(idProduct)), hwmon.Name())
			rules = append(rules, rule)
		}
	}

	if len(rules) > 0 {
		fmt.Println("Suggested udev rules:")
		for _, rule := range rules {
			fmt.Println(rule)
		}
	} else {
		fmt.Println("No suitable udev rules found. Your system might not provide idVendor and idProduct for fan controllers.")
	}
}

func main() {
	// Handle graceful shutdown
	shutdown := make(chan os.Signal, 1)
	signal.Notify(shutdown, syscall.SIGINT, syscall.SIGTERM)

	log.Println("Starting fan control program...")

	TEMP, err := getGPUTemperature()
	if err != nil {
		log.Println("Error reading GPU temperature:", err)
	} else {
		log.Printf("Current GPU temperature: %d°C", TEMP)
	}

	// Set listFans based on listAllFans flag
	listFans := &listAllFans

	if *listFans {
		fans, err := listControllableFans()
		if err != nil {
			log.Fatalf("Error listing fans: %v", err)
		}

		fmt.Println("Controllable fans found:")
		for _, fan := range fans {
			fmt.Println(fan)
		}

		suggestUdevRules()
		return
	}

	if daemonMode {
		log.Println("Running in daemon mode...")
		ticker := time.NewTicker(time.Duration(pollInterval) * time.Second)
		go func() {
			for {
				select {
				case <-shutdown:
					ticker.Stop()
					log.Println("Received shutdown signal, stopping daemon...")
					return
				case <-ticker.C:
					adjustFanSpeed()
				}
			}
		}()
		<-shutdown
		log.Println("Shutting down...")
	} else {
		adjustFanSpeed()
	}
}
