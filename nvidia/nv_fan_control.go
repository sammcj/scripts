// A simple tool that adjusts the fan speed of the GPU based on its temperature.
// Its designed for a custom cooler I have on my Nvidia Tesla P100 which is a 12v non-pwm fan.
// Author: Sam McLeod @sammcj
package main

import (
	"bytes"
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

// Global Variables
var currentIndex int
var fanPath string
var fanSensitivity int
var daemonMode bool
var pollInterval int
var listAllFans bool
var basePWM int
var maxPWM int
var maxSamples int = 40
var save bool
var load bool
var previousTemperature int
var temp bool
var threshold int
var logFile string
var logger *log.Logger
var maxTemp int
var previousPWM int
var debug bool
var offBelow int
var offSamples int
var idxOffSample int

// Set temperatureChanges to [maxSamples]int
var temperatureChanges = make([]int, maxSamples)

// Constants
const (
	configPath = "~/.config/nv_fan_control"
)

type Config struct {
	FanPath        string `json:"fan_path"`
	FanSensitivity int    `json:"fan_sensitivity"`
	DaemonMode     bool   `json:"daemon_mode"`
	PollInterval   int    `json:"poll_interval"`
	BasePWM        int    `json:"base_pwm"`
	MaxPWM         int    `json:"max_pwm"`
	MaxSamples     int    `json:"max_samples"`
	MaxTemp        int    `json:"max_temp"`
	OffBelow       int    `json:"off_below"`
	Threshold      int    `json:"threshold"`
	LogFile        string `json:"log_file"`
	Debug          bool   `json:"debug"`
	OffSamples     int    `json:"off_samples"`
}

func init() {
	// Initialize the logger
	logger = log.New(os.Stdout, "INFO: ", log.Ldate|log.Ltime|log.Lshortfile)

	flag.StringVar(&fanPath, "fanpath", "/sys/class/hwmon/hwmon4/pwm3", "Path to the PWM fan control")
	flag.IntVar(&fanSensitivity, "sensitivity", 5, "Adjust this value. Higher means more aggressive fan response, and lower is more gradual.")
	flag.BoolVar(&daemonMode, "daemon", false, "Run as a background daemon")
	flag.IntVar(&pollInterval, "interval", 5, "Polling interval in seconds")
	flag.BoolVar(&listAllFans, "list", false, "List all controllable fans")
	flag.IntVar(&basePWM, "basePWM", 42, "Baseline PWM value for the fan, it is off below this")
	flag.IntVar(&maxPWM, "maxPWM", 250, "Maximum PWM value for the fan")
	flag.IntVar(&offBelow, "offBelow", 34, "Turn the fan off below this temperature (in degrees C)")
	flag.IntVar(&offSamples, "offSamples", 10, "Number of samples to wait before turning the fan off")
	flag.BoolVar(&save, "save", false, "Save to the config file on shutdown (~/.config/nv_fan_control)")
	flag.BoolVar(&load, "load", false, "Load config file (~/.config/nv_fan_control)")
	flag.BoolVar(&temp, "temp", false, "Print the current GPU temperature and exit")
	flag.IntVar(&threshold, "threshold", 60, "Temperature threshold to move linear response (in degrees C))")
	flag.IntVar(&maxTemp, "maxTemp", 80, "Maximum operating temperature, fan at 100%")
	flag.StringVar(&logFile, "log", "", "File to log to (leave blank to log to journalctl)")
	flag.IntVar(&maxSamples, "MaxSamples", 40, "Number of samples to log for the moving average information")
	flag.BoolVar(&debug, "debug", false, "Enable debug logging")

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
	originalMaxSamples := maxSamples
	originalOffBelow := offBelow
	originalOffSamples := offSamples

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
	if maxSamples != originalMaxSamples {
		maxSamples = originalMaxSamples
	}
	if offBelow != originalOffBelow {
		offBelow = originalOffBelow
	}
	if offSamples != originalOffSamples {
		offSamples = originalOffSamples
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
	offSamples = cfg.OffSamples

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

func setFanSpeed(pwm int) {
	// If the current fan speed is < basePWM give the fan an extra kick on top of basePWM to get it going
	if pwm > basePWM && previousPWM < basePWM {
		pwm = basePWM + 25
		time.Sleep(750 * time.Millisecond)
	}
	// write the pwm int to the file
	err := os.WriteFile(fanPath, []byte(strconv.Itoa(pwm)), 0644)
	if err != nil {
		logger.Println("Failed to set fan speed:", err)
	}
	if debug {
		logger.SetPrefix("DEBUG: ")
		logger.Println("Ran:", fanPath, []byte(strconv.Itoa(pwm)))
	}

	// check that the file was written correctly (read it to an int and compare)
	outputByte, err := os.ReadFile(fanPath)
	if err != nil {
		logger.Println("Failed to read fan speed:", err)
	}
	// take the output bytes and read them as an int
	outputInt, err := strconv.Atoi(strings.TrimSpace(string(outputByte)))

	// compare the output to the input
	if outputInt != pwm {
		logger.Println("Failed to set fan speed: output does not match input")
	}
	if debug {
		logger.SetPrefix("DEBUG: ")
		logger.Println("Read:", fanPath, outputInt)
	}

	previousPWM = pwm
}

// This function checks if the GPU is currently under heavy computation or CUDA load.
func GPUUtilisation() int {
	// This command checks for utilisation.
	output, err := exec.Command("nvidia-smi", "--query-gpu", "utilization.gpu", "--format=csv,nounits,noheader").Output()
	if err != nil {
		logger.Println("Failed to check GPU computational load:", err)
		utilisation := 100
		return utilisation
	} else {
		utilisation, err := strconv.Atoi(strings.TrimSpace(string(output)))
		if err != nil {
			logger.Println("Failed to parse GPU computational load:", err)
			utilisation := 100
			return utilisation
		} else {
			return utilisation
		}
	}
}

// Checks for other running instances of this application.
func isAlreadyRunning() bool {
	processList, _ := exec.Command("pgrep", "-f", "nv_fan_control").Output()

	// remove the current process from the list
	processList = bytes.ReplaceAll(processList, []byte(strconv.Itoa(os.Getpid())), []byte(""))

	processes := strings.Split(strings.TrimSpace(string(processList)), "\n")
	return len(processes) > 1
}

func dataLog(previousTemperature int, previousPWM int, temperature int, pwm int) {
	if previousTemperature > 0 && previousPWM > 0 {
		tempChange := temperature - previousTemperature
		pwmChange := pwm - previousPWM

		// Log the relation between the PWM and temperature changes
		logger.Printf("For PWM change of %d, the temperature change was: %d\n", pwmChange, tempChange)

		if math.Abs(float64(pwmChange)) > 10 && math.Abs(float64(tempChange)) < 1 {
			logger.Println("Alert: Significant (>=10) PWM change did not affect temperature.")
		}

		// Storing temperature change
		if currentIndex < maxSamples {
			temperatureChanges[currentIndex] = temperature
			currentIndex++
		} else {
			// Output the summary
			dataSummary()
			// Shift all items to the left and add newTemp to the end
			copy(temperatureChanges[:], temperatureChanges[1:])
			temperatureChanges[maxSamples-1] = temperature
		}
	}
}

func dataSummary() {
	// Output all data from the array
	logger.Println("Temperature changes:", temperatureChanges)

	// Calculate the average temperature change
	var sum int
	for _, temp := range temperatureChanges {
		sum += temp
	}
	averageTempChange := sum / maxSamples

	// Log the average temperature change
	logger.Println("Average temperature change:", averageTempChange)

	// Calculate the average PWM change
	var sumPWM int
	for i := 1; i < maxSamples; i++ {
		sumPWM += temperatureChanges[i] - temperatureChanges[i-1]
	}
	averagePWMChange := sumPWM / (maxSamples - 1)

	// Log the average PWM change
	logger.Println("Average PWM change:", averagePWMChange)

	// Calculate the average temperature change per PWM change
	averageTempChangePerPWMChange := float64(averageTempChange) / float64(averagePWMChange)

	// Log the average temperature change per PWM change
	logger.Println("Average temperature change per PWM change:", averageTempChangePerPWMChange)
}

func main() {
	if listAllFans {
		// List all fans and exit
		os.Exit(0)
	}

	if !daemonMode && isAlreadyRunning() {
		logger.Println("Another instance of nv_fan_control is running.")
		fmt.Println("Would you like to:")
		fmt.Println("1. Stop the daemon?")
		fmt.Println("2. Tail the existing log file?")
		fmt.Println("3. Exit?")
		var choice int
		fmt.Scan(&choice)

		switch choice {
		case 1:
			// Stop the daemon (this implementation might need to be more robust)
			exec.Command("systemctl", "stop", "nv_fan_control").Run()
		case 2:
			// Assuming you have a command to tail the log. Modify as necessary.
			exec.Command("tail", "-f", "/var/log/nv_fan_control.log").Run()
			os.Exit(0)
		case 3:
			os.Exit(0)
		default:
			fmt.Println("Invalid choice.")
			os.Exit(1)
		}
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
		MaxSamples:     maxSamples,
		Threshold:      threshold,
		LogFile:        logFile,
		OffBelow:       offBelow,
		OffSamples:     offSamples,
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
			// Output the summary
			dataSummary()

			// check if we're running computations
			if GPUUtilisation() > 1 {
				logger.Println("Computations are running, exiting with fans at current speed")
				os.Exit(0)
			}
			setFanSpeed(0) // Let the system control the fan
			os.Exit(0)
		}
	}()

	for {
		temperature := getGPUTemperature()

		var pwm int

		// if there's no change, don't do anything
		if temperature == previousTemperature {
			time.Sleep(time.Duration(pollInterval) * time.Second)
			continue
		}

		if temperature <= threshold {
			adjustedTemp := float64(temperature - threshold)

			// If the temperature is below offBelow and the utilisation is below 5%, turn the fan off
			if temperature < offBelow && (GPUUtilisation() < 5) {
				// If the temperature has been below offBelow for more than 10 samples, turn the fan off
				if idxOffSample < offSamples {
					idxOffSample++
					logger.Printf("GPU Temp: %d. Below %d and utilisation is below 5%%, [Not turning off, until cycle %d >= %d]\n", temperature, offBelow, idxOffSample, offSamples)
				} else {
					pwm = 0
					logger.Printf("GPU Temp: %d. Below %d and utilisation is below 5%%, [Turning off]\n", temperature, offBelow)
				}
			} else {
				// Ensure pwm is within bounds
				if pwm < basePWM {
					pwm = basePWM
				} else if pwm > maxPWM {
					pwm = maxPWM
				}
			}

			// Calculate the PWM, first from the minimum fan speed to the threshold speed, then from the threshold speed to the maximum speed
			// e.g. if threshold speed = 150, basePWM = 30, temperature = 50, threshold = 60, max speed = 250 the resulting pwm speed is 70, but if we're over the threshold, e.g. 70, we scale from the threshold speed (100) to the max speed (250) resulting in 175.
			// the value is then multiplied by the fanSensitivity-5, so that if fanSensitivity = 5 the curve is linear, if it's 8 the curve is more pronounced etc...
			// first convert things to float64 to avoid integer division
			pwm = int((float64(basePWM) + (float64(threshold-basePWM)/(1+math.Exp(-adjustedTemp/float64(fanSensitivity-5))))*(1+(float64(maxPWM-threshold)/(1+math.Exp(-adjustedTemp/float64(fanSensitivity-5)))))))

			logger.Printf("GPU Temp: %d. Threshold distance: %.2f, Utilisation: %d%%, [Calculated PWM: %d]\n", temperature, adjustedTemp, GPUUtilisation(), pwm)
		} else {
			// Above the threshold, we scale pwm linearly from basePWM at threshold to maxPWM at maxTemp
			pwm = (basePWM + (maxPWM-basePWM)*(temperature-threshold)/(maxTemp-threshold))
			logger.Printf("GPU Temp: %d. [Calculated fan PWM: %d]\n", temperature, pwm)
		}

		// Store the previous values
		previousTemperature = temperature

		// Update the fan PWM
		setFanSpeed(pwm)

		// Log the data #TODO: fix this
		dataLog(previousTemperature, previousPWM, temperature, pwm)

		time.Sleep(time.Duration(pollInterval) * time.Second)
	}
}
