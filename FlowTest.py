#!/usr/bin/env python3
# import Adafruit_MotorHAT, Adafruit_DCMotor, Adafruit_Stepper
from Adafruit_MotorHAT import Adafruit_MotorHAT, Adafruit_DCMotor, Adafruit_StepperMotor

# import other libraries for motor movement
import time
import atexit

# create a default motor object, no changes to I2C address or frequency
mh = Adafruit_MotorHAT()

# declare peristaltic pump (DC motor)
myMotor = mh.getMotor(3)
myMotor.setSpeed(100)

# declare peristaltic pump DC motor
# mapping function found on rpi forums:
# www.raspberrypi.org/forums/viewtopic.php?t=149371
# maps tidal values to usable range
def newReading():
    myMotor.run(Adafruit_MotorHAT.FORWARD)
    myMotor.setSpeed(10)
    time.sleep(10)
    myMotor.run(Adafruit_MotorHAT.RELEASE)

# recommended for auto-disabling motors on shutdown!
def turnOffMotors():
    mh.getMotor(1).run(Adafruit_MotorHAT.RELEASE)
    mh.getMotor(2).run(Adafruit_MotorHAT.RELEASE)
    mh.getMotor(3).run(Adafruit_MotorHAT.RELEASE)
    mh.getMotor(4).run(Adafruit_MotorHAT.RELEASE)

atexit.register(turnOffMotors)


if __name__ == '__main__':
    try:
        while( True ):
            newReading()
            time.sleep(10)
    except ( KeyboardInterrupt ):
            turnOffMotors()
            exit()
