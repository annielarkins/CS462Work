# importing the requests library
import time

import requests


def main():
    # Part 0 - connect the physical sensor to a newly created pico - this part is manual
    URL = "http://localhost:3000/sky/event/ckldxwasd0036zqujbjxkf1um/phys_device/sensor/needed"
    args = {"sensor_id": "Physical Device"}
    r = requests.get(url=URL, params=args)

    # Get the eci and print out a string for pasting into the wovyn sensor
    URL = "http://localhost:3000/sky/cloud/ckldxwasd0036zqujbjxkf1um/manage_sensors/sensors"
    args = {}
    r = requests.get(url=URL, params=args)
    phys_dev_eci = r.json()["Physical Device"]['eci']
    phys_dev_url = "http://192.168.1.20:3000/sky/event/" + phys_dev_eci + "/temp/wovyn/heartbeat"
    print("Use this url for the sensor:", phys_dev_url)
    input("Press Enter to continue...")

    # Part 1 - create a first child
    URL = "http://localhost:3000/sky/event/ckldxwasd0036zqujbjxkf1um/child1/sensor/needed"
    child_1_args = {"sensor_id": "Test #1"}
    r = requests.get(url=URL, params=child_1_args)

    # Part 2 - create a first child
    URL = "http://localhost:3000/sky/event/ckldxwasd0036zqujbjxkf1um/child2/sensor/needed"
    child_2_args = {"sensor_id": "Test #2"}
    r = requests.get(url=URL, params=child_2_args)

    # Part 3 - make sure child has the correct rulesets installed
    URL = "http://localhost:3000/sky/cloud/ckldxwasd0036zqujbjxkf1um/manage_sensors/sensors"
    args = {}
    r = requests.get(url=URL, params=args)
    child_1_eci = r.json()['Test #1']['eci']

    URL = "http://localhost:3000/sky/cloud/ckldxwasd0036zqujbjxkf1um/manage_sensors/getChildRulesets?child_eci=" + child_1_eci
    args = {}
    r = requests.get(url=URL, params=args)
    rulesets = r.json()
    assert ("com.twilio.sms" in rulesets)
    assert ("sensor_profile" in rulesets)
    assert ("wovyn_base" in rulesets)
    assert ("io.picolabs.wovyn.emitter" in rulesets)
    assert ("temperature_store" in rulesets)

    # Part 4 - make sure child 1 has the correct profile
    URL = "http://localhost:3000/sky/cloud/ckldxwasd0036zqujbjxkf1um/manage_sensors/getChildProfile?child_eci=" + child_1_eci
    args = {}
    r = requests.get(url=URL, params=args)
    profile = r.json()
    assert(profile['s_name'] == "Test #1")

    # Part 5 - make sure child 1 has actual temperature data
    print("\nSleeping to give the device time to get temperature values...")
    time.sleep(15)
    URL = "http://localhost:3000/sky/cloud/ckldxwasd0036zqujbjxkf1um/manage_sensors/getChildTemps?child_eci=" + child_1_eci
    args = {}
    r = requests.get(url=URL, params=args)
    temps = r.json()
    assert(len(temps) > 0)
    assert(list(temps.values())[0]['temperature'] is not None)

    # Part 6 - get all the sensors (should be 3)
    URL = "http://localhost:3000/sky/cloud/ckldxwasd0036zqujbjxkf1um/manage_sensors/sensors"
    args = {}
    r = requests.get(url=URL, params=args)
    sensors = r.json()
    assert(len(sensors) == 3)

    URL = "http://localhost:3000/sky/cloud/ckldxwasd0036zqujbjxkf1um/manage_sensors/showChildren"
    args = {}
    r = requests.get(url=URL, params=args)
    sensors = r.json()
    assert(len(sensors) == 3)

    # Part 7 - try to create a duplicate child
    URL = "http://localhost:3000/sky/event/ckldxwasd0036zqujbjxkf1um/child_dup/sensor/needed"
    child_1_args = {"sensor_id": "Test #1"}
    r = requests.get(url=URL, params=child_1_args)
    directive_name = r.json()["directives"][0]['name']
    assert("DUPLICATE" in directive_name)

    # Part 8 - get all the sensors (make sure duplicate wasn't added)
    URL = "http://localhost:3000/sky/cloud/ckldxwasd0036zqujbjxkf1um/manage_sensors/sensors"
    args = {}
    r = requests.get(url=URL, params=args)
    sensors = r.json()
    assert(len(sensors) == 3)

    URL = "http://localhost:3000/sky/cloud/ckldxwasd0036zqujbjxkf1um/manage_sensors/showChildren"
    args = {}
    r = requests.get(url=URL, params=args)
    sensors = r.json()
    assert(len(sensors) == 3)

    # Part 9 - get all the temperatures from all children
    URL = "http://localhost:3000/sky/cloud/ckldxwasd0036zqujbjxkf1um/manage_sensors/manage_sensors"
    args = {}
    r = requests.get(url=URL, params=args)
    sensors = r.json()
    first_temp_count = len(sensors)
    assert(len(sensors) > 3)

    # Part 10 - delete child 1
    URL = "http://localhost:3000/sky/event/ckldxwasd0036zqujbjxkf1um/child_dup/sensor/unneeded"
    child_1_args = {"sensor_id": "Test #1"}
    r = requests.get(url=URL, params=child_1_args)
    directive_name = r.json()["directives"][0]['name']
    assert("deleting" in directive_name)

    # Part 11 - get all the sensors (should only be 2 now)
    URL = "http://localhost:3000/sky/cloud/ckldxwasd0036zqujbjxkf1um/manage_sensors/sensors"
    args = {}
    r = requests.get(url=URL, params=args)
    sensors = r.json()
    assert(len(sensors) == 2)

    URL = "http://localhost:3000/sky/cloud/ckldxwasd0036zqujbjxkf1um/manage_sensors/showChildren"
    args = {}
    r = requests.get(url=URL, params=args)
    sensors = r.json()
    assert(len(sensors) == 2)

    # Part 12 - get temperatures (should work despite deleting one child)
    URL = "http://localhost:3000/sky/cloud/ckldxwasd0036zqujbjxkf1um/manage_sensors/manage_sensors"
    args = {}
    r = requests.get(url=URL, params=args)
    sensors = r.json()
    assert(len(sensors) < first_temp_count)

    print("\nALL TESTS PASSED!")


if __name__ == "__main__":
    main()
