ruleset wovyn_base {
    meta {
        use module sensor_profile alias sp
        use module com.twilio.sms alias twilio
        with
            account_sid = meta:rulesetConfig{"account_sid"}
            auth_token = meta:rulesetConfig{"auth_token"}
        shares __testing
    }
    global {
        sensor_profile = sp:getProfile()
        temperature_threshold = sensor_profile{"threshold_temp"}
        to_number = sensor_profile{"sms_num"}
        from_number = "+18152402977"
    }
   
    rule process_heartbeat {
        select when wovyn heartbeat where event:attrs{"genericThing"} != "" 
        && event:attrs{"genericThing"} != null
        pre {
            msg = "Inside process_heartbeat!"
            generic_thing = event:attrs{"genericThing"}.klog("Generic Thing:" )
            temperature = generic_thing{"data"}{"temperature"}[0]{"temperatureF"}.klog("WOVYN TEMP: ")
            timestamp = time:now()
        }
        send_directive(msg)
        always {
            raise wovyn event "new_temperature_reading"
                attributes {"temperature": temperature,
                            "timestamp": timestamp}

        }
    }

    rule update_globals {
        select when wovyn update_prof
        pre {
            sensor_profile = sp:getProfile().klog("The profile values have been changed within wovyn base rulset!")
            temperature_threshold = sensor_profile{"threshold_temp"}.klog("UPDATED TVALUE:")
            to_number = sensor_profile{"sms_num"}
            from_number = "+18152402977"
        }
        send_directive("The profile values have been changed within wovyn base rulset!")
    }

    rule find_high_temps {
        select when wovyn new_temperature_reading
        pre {
            msg = "Inside find_high_temps!"
            temperature = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
            tempDifference = (temperature - sp:getProfile(){"threshold_temp"}).klog("TEMP DIFFERENCE: ")
        }
        send_directive(msg)
        always {
            raise wovyn event "threshold_violation"
                attributes {"temperature": temperature,
                    "timestamp": timestamp}
            if tempDifference > 0
        }
    }

    rule threshold_notification {
        select when wovyn threshold_violation
        pre {
            to = sp:getProfile(){"sms_num"}.klog("SENT TEXT TO:")
            sms_message = ("The Wovyn Sensor registered a temperature above your threshold: " + event:attrs{"temperature"}).klog("MESSAGE DRAFTED: ")
        }
        twilio:send_sms(to, from_number, sms_message)
        
    }
}