#!/usr/bin/python

##### Simple script to prime the motor before and after showing
#### as the tube the water moves through is quite long, this script will be used
### to make sure the tube is filled with water before the piece is started, and
## at the end of the day to move water out of the tube so it isn't stagnant in
# the tube overnight


from Adafruit_MotorHAT import Adafruit_MotorHAT, Adafruit_DCMotor

import time
import atexit

# create a default object for the motor hat
mh = Adafruit_MotorHAT(addr=0x60)

# disable all motor ports on shutdown
def turnOffMotors():
    mh.getMotor(1).run(Adafruit_MotorHAT.RELEASE)
    mh.getMotor(2).run(Adafruit_MotorHAT.RELEASE)
    mh.getMotor(3).run(Adafruit_MotorHAT.RELEASE)
    mh.getMotor(4).run(Adafruit_MotorHAT.RELEASE)

# precautionary exit disabling of motors
atexit.register(turnOffMotors)

# the motor is connected to port 3
myMotor = mh.getMotor(3)

# run this until keyboard interrupt and then turn off all the motor ports
if __name__ == '__main__':
    try:
        while( True ):
            myMotor.setSpeed(255)
            myMotor.run(Adafruit_MotorHAT.FORWARD)
    except ( KeyboardInterrupt ):
        turnOffMotors()
        exit()
