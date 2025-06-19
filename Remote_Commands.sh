#!/bin/bash

HOST_IP=$1
USER="ltadmin"
PASSWORD="password"

REMOTE_COMMAND='for udid in $(/opt/homebrew/bin/idevice_id -l); do echo "$udid" && /opt/homebrew/bin/idevicepair -u $udid pair; done'
                #for udid in $(idevice_id -l); do echo "$udid" && idevicediagnostics -u $udid restart; done
                #for udid in $(idevice_id -l); do echo "$udid" && ideviceinstaller -u $udid -U com.lambdatest.MediaApp; done
                #for udid in $(idevice_id -l); do echo "$udid" && ideviceinstaller -u $udid -U fullDeviceCleanup-Runner.app; done
                #for udid in $(idevice_id -l); do echo "$udid" && ideviceinstaller -u $udid -U com.LT.LTApp; done
                #for udid in $(idevice_id -l); do echo "$udid" && ideviceinstaller -u $udid -U com.manageengine.mdm.iosagent; done
                #for udid in $(idevice_id -l); do echo "$udid" && ideviceinstaller -u $udid -U com.appium.WebDriverAgentRunner.xctrunner; done
                #for udid in $(idevice_id -l); do echo "$udid" && ideviceinstaller -u $udid -U com.apple.Numbers; done
                #for udid in $(idevice_id -l); do echo "$udid" && ideviceinstaller -u $udid -U com.apple.Health; done
                #for udid in $(idevice_id -l); do echo "$udid" && ideviceinstaller -u $udid -U com.apple.Pages; done
                #for udid in $(idevice_id -l); do echo "$udid" && ideviceinstaller -u $udid -U com.apple.store.Jolly; done
                #for udid in $(idevice_id -l); do echo "$udid" && ideviceinstaller -u $udid -U com.apple.Keynote; done
                #for udid in $(idevice_id -l); do echo "$udid" && ideviceinstaller -u $udid -U com.facebook.WebDriverAgentRunner.xctrunner; done
                #for udid in $(idevice_id -l); do echo "$udid" && ideviceinstaller -u $udid -U 9J9RFX296W.com.facebook.WebDriverAgentRunner.xctrunner; done
                #for udid in `go-adb listdevices | jq -r '.devicelist[].SerialNumber'`; do docker exec -it adbd_$udid bash -c "adb devices"; done
                #for udid in `go-adb listdevices | jq -r '.devicelist[].SerialNumber'`; do adb -s $udid reboot; done
                #for udid in `/usr/bin/go-adb listdevices | jq -r '.devicelist[].SerialNumber'`; do adb -s $udid install -r /home/ltadmin/Documents/Mobile_Binary/LambdaTestService.apk; done
                #for udid in `/usr/bin/go-adb listdevices | jq -r '.devicelist[].SerialNumber'`; do adb -s $udid shell 'pm disable-user --user 0 com.oneplus.brickmode'; done
                #for udid in `/usr/bin/go-adb listdevices | jq -r '.devicelist[].SerialNumber'`; do adb -s $udid install -r /home/ltadmin/Documents/Mobile_Binary/gnirehtet.apk; done
                #for udid in `/usr/bin/go-adb listdevices | jq -r '.devicelist[].SerialNumber'`; do adb -s $udid shell locksettings set-pin 1234 ; done
                #for udid in `/usr/bin/go-adb listdevices | jq -r '.devicelist[].SerialNumber'`; do adb -s $udid shell locksettings clear --old  1234; done
                #for udid in `/usr/bin/go-adb listdevices | jq -r '.devicelist[].SerialNumber'`; do adb -s $udid shell locksettings set-disabled true; done

sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USER@$HOST_IP" "$REMOTE_COMMAND"
