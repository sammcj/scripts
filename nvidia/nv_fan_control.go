// A simple tool that adjusts the fan speed of the GPU based on its temperature.
// Its designed for a custom cooler I have on my Nvidia Tesla P100 which is a 12v non-pwm fan.
// Author: Sam McLeod @sammcj
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"log/syslog"
	"math"
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
var save bool
var load bool
var lastTemperature int
var temp bool
var threshold int
var logFile string
var logger *log.Logger
var maxTemp int

const configPath = "~/.config/nv_fan_control"

type Config struct {
	FanPath        string `json:"fan_path"`
	FanSensitivity int    `json:"fan_sensitivity"`
	DaemonMode     bool   `json:"daemon_mode"`
	PollInterval   int    `json:"poll_interval"`
	BasePWM        int    `json:"base_pwm"`
	MaxPWM         int    `json:"max_pwm"`
	MaxTemp        int    `json:"max_temp"`
	Threshold      int    `json:"threshold"`
	LogFile        string `json:"log_file"`
}

func init() {
	// Initialize the logger
	logger = log.New(os.Stdout, "INFO: ", log.Ldate|log.Ltime|log.Lshortfile)

	flag.StringVar(&fanPath, "fanpath", "/sys/class/hwmon/hwmon4/pwm3", "Path to the PWM fan control")
	flag.IntVar(&fanSensitivity, "sensitivity", 5, "Adjust this value. Higher means more aggressive fan response, and lower is more gradual.")
	flag.BoolVar(&daemonMode, "daemon", false, "Run as a background daemon")
	flag.IntVar(&pollInterval, "interval", 5, "Polling interval in seconds")
	flag.BoolVar(&listAllFans, "list", false, "List all controllable fans")
	flag.IntVar(&basePWM, "basePWM", 55, "Baseline PWM value for the fan")
	flag.IntVar(&maxPWM, "maxPWM", 255, "Maximum PWM value for the fan")
	flag.BoolVar(&save, "save", false, "Save to the config file on shutdown (~/.config/nv_fan_control)")
	flag.BoolVar(&load, "load", false, "Load config file (~/.config/nv_fan_control)")
	flag.BoolVar(&temp, "temp", false, "Print the current GPU temperature and exit")
	flag.IntVar(&threshold, "threshold", 50, "Temperature threshold for non-linear response (in degrees C))")
	flag.IntVar(&maxTemp, "maxTemp", 82, "Maximum temperature to be reached before fan is at 100%")
	flag.StringVar(&logFile, "log", "", "File to log to (leave blank to log to journalctl)")

	flag.Parse()

	if temp {
		load = true
		save = false
		fmt.Println(getGPUTemperature())
		os.Exit(0)
	}

	originalFanPath := fanPath
	originalFanSensitivity := fanSensitivity
	originalDaemonMode := daemonMode
	originalPollInterval := pollInterval
	originalBasePWM := basePWM
	originalMaxPWM := maxPWM
	originalThreshold := threshold
	originalLogFile := logFile
	originalMaxTemp := maxTemp

	if load && os.IsExist(checkConfig()) {
		loadConfig()
	}

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
	if threshold != originalThreshold {
		threshold = originalThreshold
	}
	if logFile != originalLogFile {
		logFile = originalLogFile
	}
	if maxTemp != originalMaxTemp {
		maxTemp = originalMaxTemp
	}

	if save {
		defer saveConfig()
	}

	// Setup logging
	if logFile != "" {
		f, err := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if err != nil {
			log.Fatal(err)
		}
		logger = log.New(f, "", log.LstdFlags)
	} else {
		syslogger, err := syslog.New(syslog.LOG_NOTICE, "nv_fan_control")
		if err != nil {
			log.Fatal(err)
		}
		logger = log.New(syslogger, "", 0)
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
		logger.Println("Failed to read config file:", err)
		return
	}

	var cfg Config
	err = json.Unmarshal(data, &cfg)
	if err != nil {
		logger.Println("Failed to parse config file:", err)
		return
	}

	fanPath = cfg.FanPath
	fanSensitivity = cfg.FanSensitivity
	daemonMode = cfg.DaemonMode
	pollInterval = cfg.PollInterval
	basePWM = cfg.BasePWM
	maxPWM = cfg.MaxPWM
	threshold = cfg.Threshold
	logFile = cfg.LogFile
	maxTemp = cfg.MaxTemp

	logger.Println("Found and loaded config with values:", cfg)
}

func saveConfig() {
	logger.Println("Saving current settings to config file...")

	cfg := Config{
		FanPath:        fanPath,
		FanSensitivity: fanSensitivity,
		DaemonMode:     daemonMode,
		PollInterval:   pollInterval,
		BasePWM:        basePWM,
		MaxPWM:         maxPWM,
		MaxTemp:        maxTemp,
		Threshold:      threshold,
		LogFile:        logFile,
	}

	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		logger.Println("Failed to serialize config:", err)
		return
	}

	err = os.WriteFile(expandHome(configPath), data, 0644)
	if err != nil {
		logger.Println("Failed to save config:", err)
	} else {
		logger.Println("Config saved successfully. The program will run with these settings next time.")
	}
}

func getGPUTemperature() int {
	output, err := exec.Command("nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader").Output()
	if err != nil {
		logger.Println("Failed to get GPU temperature:", err)
		os.Exit(1)
	}

	trimmedOutput := strings.TrimSuffix(string(output), "\n")
	temperature, err := strconv.Atoi(trimmedOutput)
	if err != nil {
		logger.Println("Failed to parse GPU temperature:", err)
		os.Exit(1)
	}

	return temperature
}

func setFanSpeed(percentage int) {
	pwm := basePWM + (maxPWM-basePWM)*percentage/100
	err := os.WriteFile(fanPath, []byte(strconv.Itoa(pwm)), 0644)
	if err != nil {
		logger.Println("Failed to set fan speed:", err)
	}
}

func sigmoid(x float64) float64 {
	return 1.0 / (1.0 + math.Exp(-x))
}

func main() {
	if listAllFans {
		// List all fans and exit
		os.Exit(0)
	}

	loadConfig()

	logFile := "/var/log/nv_fan_control.log"
	logf, err := os.OpenFile(logFile, os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0644)
	if err != nil {
		log.Fatal(err)
	}
	defer logf.Close()

	// Reinitialize the logger
	if logFile != "" {
		logger = log.New(io.MultiWriter(os.Stdout, logf), "", log.LstdFlags)
	} else {
		syslogger, err := syslog.New(syslog.LOG_NOTICE, "nv_fan_control")
		if err != nil {
			log.Fatal(err)
		}
		logger = log.New(io.MultiWriter(os.Stdout, syslogger), "", 0)
	}

	// Log out the current settings
	logger.Println("Current settings:", Config{
		FanPath:        fanPath,
		FanSensitivity: fanSensitivity,
		DaemonMode:     daemonMode,
		PollInterval:   pollInterval,
		BasePWM:        basePWM,
		MaxPWM:         maxPWM,
		MaxTemp:        maxTemp,
		Threshold:      threshold,
		LogFile:        logFile,
	})

	if daemonMode {
		// Start in daemon mode
		if _, err := os.Stat("/.dockerenv"); err == nil {
			// We're inside a Docker container, don't daemonize
			logger.Println("Running in Docker container, won't daemonize")
		} else if _, err := os.Stat(filepath.Join("/proc", strconv.Itoa(os.Getppid()), "cmdline")); err == nil {
			// We're not the top process, fork off a child
			logger.Println("Not top process, forking")
			args := os.Args[1:]

			// Ensure only one -daemon flag
			newArgs := []string{}
			for _, arg := range args {
				if arg != "-daemon" {
					newArgs = append(newArgs, arg)
					logger = log.New(io.MultiWriter(logf, os.Stdout), "", log.LstdFlags)

				}

			}
			newArgs = append(newArgs, "-daemon")

			cmd := exec.Command(os.Args[0], newArgs...)
			cmd.Start()
			logger.Println("Forked child, exiting")
			logger.Println("Child PID:", cmd.Process.Pid)
			os.Exit(0)
		}
	}

	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		for range signalChan {
			logger.Println("Caught an interrupt, stopping fan control")
			setFanSpeed(0) // Let the system control the fan
			os.Exit(0)
		}
	}()

	for {
		temperature := getGPUTemperature()

		var pwm int

		// if there's no change, don't do anything
		if temperature == lastTemperature {
			time.Sleep(time.Duration(pollInterval) * time.Second)
			continue
		}

		if temperature <= threshold {
			// Below the threshold, we use a non-linear sigmoid function
			adjustedTemp := float64(temperature - threshold)
			pwm = basePWM + int(sigmoid(float64(fanSensitivity)*adjustedTemp)*float64(maxPWM-basePWM))
			logger.Printf("GPU Temp: %d is below or at threshold. Threshold distance: %.2f, calculated fan speed (pwm): %d\n", temperature, adjustedTemp, pwm)
		} else {
			// Above the threshold, we scale pwm linearly from basePWM at threshold to maxPWM at maxTemp
			pwm = basePWM + (maxPWM-basePWM)*(temperature-threshold)/(maxTemp-threshold)
			logger.Printf("GPU Temp: %d is above threshold. Calculated fan speed (pwm): %d\n", temperature, pwm)
		}

		// Ensure pwm is within bounds
		if pwm < basePWM {
			pwm = basePWM
		} else if pwm > maxPWM {
			pwm = maxPWM
		}

		setFanSpeed(pwm)

		lastTemperature = temperature

		time.Sleep(time.Duration(pollInterval) * time.Second)
	}
}
