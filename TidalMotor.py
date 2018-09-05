# Elias Berkhout brackish, Jun-Sep 2018
# This script reads tidal data from an online json file and uses that data
# to control one stepper motor and one dc motor connected to an Adafruit motorhat
# apscheduler is used to run the script every three minutes, but the data online is updated only
# every 15 minutes, meaning the motorised components will return to the same location four to five times.

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

# start osc – client is a macbook pro and 57120 is the default supercollider port
client = udp_client.SimpleUDPClient('192.168.0.102', 57120)

# occasionally the ip address of the macbook pro can change... this is here as a precaution
# client = udp_client.SimpleUDPClient('192.168.0.100', 57120)

# create a default motor object, no changes to I2C address or frequency
mh = Adafruit_MotorHAT()

# declare stepper motor to move plate
myStepper = mh.getStepper(200, 1)   # 200 steps/rev, motor port #1
myStepper.setSpeed(300)             # RPM

# declare peristaltic pump DC motor
myMotor = mh.getMotor(3)            # it is connected to port 3 on the Adafruit MotorHAT
myMotor.setSpeed(155)               # speed is set 0-255

# mapping function found on rpi forums:
# www.raspberrypi.org/forums/viewtopic.php?t=149371
# maps tidal values to usable range (0 - 100)
def mapper(x, in_min, in_max, out_min, out_max):
    return ((x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min)

# this is the function given to the scheduler, which will run every 3 minutes
def newReading():
    # this url is the location of the json file
    url = "https://environment.data.gov.uk/flood-monitoring/id/stations/0003/measures"
    json_data = requests.get(url).json()
    # go into the various json arrays to find the latest reading (updated every 15 minutes)
    level = json_data['items'][0]['latestReading']['value']
    # print the raw level out
    print("level = ", level)
    #map the level to a better range and print the mapped level out
    mappedLevel  = round(mapper(level, -2.96, 4.21, 0, 100))
    print("mappedLevel =", mappedLevel)
    # create an osc message to be sent to supercollider
    msg = osc_message_builder.OscMessageBuilder(address = '/pySend')
    msg.add_arg(level, arg_type='f') # add a float argument
    msg = msg.build() # build the message
    client.send(msg) # send it
    # map the level of the tide to the number of possible steps
    mappedSteps = round(mapper(mappedLevel, 0, 100, 50, 4715))
    # print it out
    print("stepping ", mappedSteps, "of a possible 4715 steps")
    # step the motor to the relative location along the rails and release it
    myStepper.step(mappedSteps, Adafruit_MotorHAT.BACKWARD,  Adafruit_MotorHAT.DOUBLE)
    mh.getMotor(1).run(Adafruit_MotorHAT.RELEASE)
    # map the tide level to a usable range for the peristaltic pump (dc motor)
    # this means more water will come through the pump at high tide, less at low tide, etc
    mappedFlow = round(mapper(mappedLevel, 0, 100, 100, 255))
    print("mappedFlow = ", mappedFlow)
    myMotor.setSpeed(mappedFlow)
    myMotor.run(Adafruit_MotorHAT.FORWARD)
    time.sleep(10) # run the pump for ten seconds
    mh.getMotor(3).run(Adafruit_MotorHAT.RELEASE) # release the pump
    myStepper.step(mappedSteps, Adafruit_MotorHAT.FORWARD, Adafruit_MotorHAT.DOUBLE) # return to home
    turnOffMotors() # run the turnOffMotors() function

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
