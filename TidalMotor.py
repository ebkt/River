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
from apscheduler.schedulers.background import BackgroundScheduler

# instantiate scheduler
scheduler = BackgroundScheduler()

# create a default motor object, no changes to I2C address or frequency
mh = Adafruit_MotorHAT()

# recommended for auto-disabling motors on shutdown!
def turnOffMotors():
    mh.getMotor(1).run(Adafruit_MotorHAT.RELEASE)
    mh.getMotor(2).run(Adafruit_MotorHAT.RELEASE)
    mh.getMotor(3).run(Adafruit_MotorHAT.RELEASE)
    mh.getMotor(4).run(Adafruit_MotorHAT.RELEASE)
    
atexit.register(turnOffMotors)

# declare stepper motor
myStepper = mh.getStepper(200, 1)  # 200 steps/rev, motor port #1
myStepper.setSpeed(30)             # 30 RPM

def newReading():
    url = "https://environment.data.gov.uk/flood-monitoring/id/stations/0003/measures"
    json_data = requests.get(url).json()

    level = json_data['items'][0]['latestReading']['value']
    print("level = ")
    print(level)
    mappedLevel = round(mapper(level, -2.67, 3.65, 0, 100))
    print("mappedLevel =")
    print(mappedLevel)
    myStepper.step(mappedLevel * 10, Adafruit_MotorHAT.FORWARD,  Adafruit_MotorHAT.MICROSTEP)
    myStepper.step(mappedLevel * 10, Adafruit_MotorHAT.BACKWARD, Adafruit_MotorHAT.MICROSTEP)

scheduler.add_job(newReading, 'interval', minutes = 15, id='move')
scheduler.start()

# mapping function found on rpi forums:
# www.raspberrypi.org/forums/viewtopic.php?t=149371
def mapper(x, in_min, in_max, out_min, out_max):
    return ((x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min)

    

