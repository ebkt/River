#!/usr/bin/env python3
# import Adafruit_MotorHAT, Adafruit_DCMotor, Adafruit_Stepper
from Adafruit_MotorHAT import Adafruit_MotorHAT, Adafruit_DCMotor, Adafruit_StepperMotor

# import other libraries for motor movement
import time
import atexit

# import libraries for API access and number crunching
import requests
import json
from decimal import Decimal

# import scheduler
from pytz import utc
import datetime
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.jobstores.sqlalchemy import SQLAlchemyJobStore
# import osc modules
from pythonosc import osc_message_builder
from pythonosc import udp_client

# instantiate scheduler
Scheduler = BackgroundScheduler()

# start osc
client = udp_client.SimpleUDPClient('10.100.114.42', 57120)

# create a default motor object, no changes to I2C address or frequency
mh = Adafruit_MotorHAT()

# declare stepper motor to move plate
myStepper = mh.getStepper(200, 1)  # 200 steps/rev, motor port #1
myStepper.setSpeed(300)             # RPM

# declare peristaltic pump DC motor
myMotor = mh.getMotor(3)           # it is connected to port 3 on the Adafruit MotorHAT
myMotor.setSpeed(155)              # speed is set 0-255

# mapping function found on rpi forums:
# www.raspberrypi.org/forums/viewtopic.php?t=149371
# maps tidal values to usable range
def mapper(x, in_min, in_max, out_min, out_max):
    return ((x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min)

def newReading():
    url = "https://environment.data.gov.uk/flood-monitoring/id/stations/0003/measures"
    json_data = requests.get(url).json()
    level = json_data['items'][0]['latestReading']['value']
    print("level = ", level)
    #mappedLevel = round(mapper(level, -1.80, 4.30, 0, 100))
    mappedLevel  = round(mapper(level, -2.96, 4.21, 0, 100))
    print("mappedLevel =", mappedLevel)
    msg = osc_message_builder.OscMessageBuilder(address = '/pySend')
    msg.add_arg(level, arg_type='f')
    msg = msg.build()
    client.send(msg)
    mappedSteps = round(mapper(mappedLevel, 0, 100, 50, 4715))
    print("stepping ", mappedSteps, "of a possible 4715 steps")
    myStepper.step(mappedSteps, Adafruit_MotorHAT.BACKWARD,  Adafruit_MotorHAT.DOUBLE)
    mh.getMotor(1).run(Adafruit_MotorHAT.RELEASE)
    mh.getMotor(2).run(Adafruit_MotorHAT.RELEASE)
    mappedFlow = round(mapper(mappedLevel, 0, 100, 100, 255))
    print("mappedFlow = ", mappedFlow)
    myMotor.setSpeed(mappedFlow)
    myMotor.run(Adafruit_MotorHAT.FORWARD)
    time.sleep(10)
    mh.getMotor(3).run(Adafruit_MotorHAT.RELEASE)
    myStepper.step(mappedSteps, Adafruit_MotorHAT.FORWARD, Adafruit_MotorHAT.DOUBLE)
    turnOffMotors()

# recommended for auto-disabling motors on shutdown!
def turnOffMotors():
    mh.getMotor(1).run(Adafruit_MotorHAT.RELEASE)
    mh.getMotor(2).run(Adafruit_MotorHAT.RELEASE)
    mh.getMotor(3).run(Adafruit_MotorHAT.RELEASE)
    mh.getMotor(4).run(Adafruit_MotorHAT.RELEASE)

atexit.register(turnOffMotors)


if __name__ == '__main__':
    # add scheduler job to run newReading() function at intervals to retrieve new values
    # values on the json are updated every fifteen minutes
    Scheduler.start()
    Scheduler.add_job(newReading, 'interval', minutes = 3, next_run_time = datetime.datetime.now())
    try:
        while( True ):
            time.sleep(1)
    except ( KeyboardInterrupt ):
            turnOffMotors()
            exit()
