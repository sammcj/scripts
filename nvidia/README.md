# NV Fan Control

A small utility I wrote to control the custom cooling's 12v fan speed on my Nvidia Tesla P100.

My mainboard is a ASRock x670 Pro RS (sorry, not turbo or intercooler) which uses an NCT 6775 controller.

## Usage

```shell
nv_fan_control -help
nv_fan_control -sensitivity 5 -threshold 50 -maxPWM 255 -basePWM 100
```

## Installation

```shell
go build nv_fan_control.go
chmod +x nv_fan_control
mv nv_fan_control /usr/local/sbin/
```

_Note: I have added a install.sh script, but haven't tested it on a clean machine yet._

You may also want to create a systemd service to run this at boot and in the background.

```shell
cp nv_fan_control.service /etc/systemd/system/
systemctl daemon reload
systemctl enable nv_fan_control.service --now
```

## NCT 6775 + Fedora 38

```shell
cat /etc/modprobe.d/am5-sensors.conf
options nct6775 force_id=0xd420 force
```

![](fan_response_curve.svg)
