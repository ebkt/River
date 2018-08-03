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
client = udp_client.SimpleUDPClient('10.100.115.165', 57120)

# create a default motor object, no changes to I2C address or frequency
mh = Adafruit_MotorHAT()

# declare stepper motor to move plate
myStepper = mh.getStepper(200, 1)  # 200 steps/rev, motor port #1
myStepper.setSpeed(120)             # RPM

# declare peristaltic pump DC motor
myMotor = mh.getMotor(3)           # it is connected to port 3 on the Adafruit MotorHAT
myMotor.setSpeed(150)              # speed is set 0-255

# mapping function found on rpi forums:
# www.raspberrypi.org/forums/viewtopic.php?t=149371
# maps tidal values to usable range
def mapper(x, in_min, in_max, out_min, out_max):
    return ((x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min)


def newReading():
    url = "https://environment.data.gov.uk/flood-monitoring/id/stations/0003/measures"
    json_data = requests.get(url).json()
    level = json_data['items'][0]['latestReading']['value']
    print("level = ")
    print(level)
    mappedLevel = round(mapper(level, -2.67, 3.65, 0, 100))
    print("mappedLevel =")
    print(mappedLevel)
    msg = osc_message_builder.OscMessageBuilder(address = '/pySend')
    msg.add_arg(level, arg_type='f')
    msg = msg.build()
    client.send(msg)
    myStepper.step(mappedLevel * 30, Adafruit_MotorHAT.BACKWARD,  Adafruit_MotorHAT.DOUBLE)
    myMotor.run(Adafruit_MotorHAT.FORWARD)
    for i in range(200):
        myMotor.setSpeed(i)
    time.sleep(2)
    mh.getMotor(3).run(Adafruit_MotorHAT.RELEASE)
    time.sleep(1.0)
    myStepper.step(mappedLevel * 30, Adafruit_MotorHAT.FORWARD, Adafruit_MotorHAT.DOUBLE)
    mh.getMotor(1).run(Adafruit_MotorHAT.RELEASE)


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
    Scheduler.add_job(newReading, 'interval', minutes = 15, next_run_time = datetime.datetime.now())
    Scheduler.start()
    try:
        while( True ):
            time.sleep(10)
    except ( KeyboardInterrupt ):
            turnOffMotors()
            exit()
    
