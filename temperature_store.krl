ruleset temperature_store {
    meta {
        provides temperatures, threshold_violations, inrange_temperatures
        shares temperatures, threshold_violations, inrange_temperatures
    }

    global {
        clear_temp = {"0": {"temperature": -99, "timestamp": -99}}
        clear_temp_2 = {}

        temperatures = function(){
            ent:stored_temps
        }

        threshold_violations = function(){
            ent:stored_violations
        }

        inrange_temperatures = function(){
            inrange = ent:stored_temps.filter(
                function(v, k){
                    c_temp = v{"temperature"}
                    violated = ent:stored_violations.values().klog("VIO TEMPS: ")
                    result = violated.none(
                        function(y){
                            y{"temperature"} == c_temp
                        }
                    )
                    result
                }
            )
            inrange 
        }
    }

    rule collect_temperatures {
        select when wovyn new_temperature_reading
        pre {
            temperature = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
            passed_id = random:uuid().klog("RANDOM ID: ")

        }
        send_directive("store_temp", {
            "id": passed_id,
            "temperature" : temperature,
            "timestamp" : timestamp
          })
          always{
            ent:stored_temps := ent:stored_temps.defaultsTo(clear_temp, "initialization was needed");
            ent:stored_temps := ent:stored_temps.put([passed_id,"temperature"], temperature)
                                .put([passed_id,"timestamp"], timestamp)
          }
    }

    rule collect_threshold_violations{
        select when wovyn threshold_violation
        pre {
            temperature = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
            passed_id = random:uuid().klog("RANDOM ID: ")
        }
        send_directive("store_temp", {
            "temperature" : temperature,
            "timestamp" : timestamp
          })
        always{
            ent:stored_violations := ent:stored_violations.defaultsTo(clear_temp, "initialization was needed");
            ent:stored_violations := ent:stored_violations.put([passed_id,"temperature"], temperature)
                                .put([passed_id,"timestamp"], timestamp)
        }
    }

    rule clear_temperatures {
        select when sensor reading_reset
        always {
            ent:stored_temps := clear_temp_2
            ent:stored_violations := clear_temp_2
        }
    }
}