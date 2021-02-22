ruleset sensor_profile {
    meta {
        use module io.picolabs.wrangler alias wrangler
        provides getProfile, getRulesets
        shares getProfile, getRulesets
    }

    global {
        default_profile = {
            "s_name": "Annie's Sensor",
            "location": "Annie's Apartment",
            "threshold_temp": 70,
            "sms_num": "+14103706090"
        }

        getProfile = function(){
            ent:sensor_profile
        }

        getRulesets = function(){
            wrangler:installedRIDs
        }
       
    }

    rule init {
        select when wrangler ruleset_added
        pre{

        }
        always{
            ent:sensor_profile := default_profile
        }
    }

    rule update_profile {
        select when sensor profile_updates 
        pre {
            location = event:attrs{"location"}.klog("SOMETHING IS WORKING") || "Annie's Apartment".klog("SOMETHING ELSE")
            s_name = event:attrs{"s_name"} || "Annie's Sensor"
            threshold_temp = event:attrs{"threshold_temp"} || 70
            sms_num = event:attrs{"sms_num"} || "+14103706090"
        }
        send_directive("profile info", {
            "location": location,
            "s_name" : s_name,
            "threshold_temp " : threshold_temp,
            "sms_num" : sms_num 
          })
          always{
            ent:sensor_profile := ent:sensor_profile.defaultsTo(default_profile, "initialization was needed")
            ent:sensor_profile{"s_name"} := s_name
            ent:sensor_profile{"location"} := location
            ent:sensor_profile{"threshold_temp"} := threshold_temp
            ent:sensor_profile{"sms_num"} := sms_num
            raise wovyn event "update_prof"
          }
    }

    rule pico_ruleset_added {
        select when wrangler ruleset_installed
          where event:attr("rids") >< meta:rid
        pre {
          sensor_id = event:attr("sensor_id")
          location = event:attrs{"location"} || "Annie's Apartment"
          s_name = event:attrs{"s_name"} || "Annie's Sensor"
          threshold_temp = event:attrs{"threshold_temp"} || 70
          sms_num = event:attrs{"sms_num"} || "+14103706090"
        }
        always {
          ent:sensor_id := sensor_id
          raise sensor event "profile_updates"
            attributes {"location": location,
                        "s_name" : s_name,
                        "threshold_temp " : threshold_temp,
                        "sms_num" : sms_num }

        }
    }

    // rule initialize_state {
    //     select when wrangler ruleset_installed
    //       where event:attrs{"rids"} >< meta:rid
    //       pre{
    //         the_sensor = {"eci": event:attr("eci")}
    //       }
    //       event:send(
    //         { "eci": the_sensor.get("eci").klog("send installation event"), 
    //         "eid": "install_rulesets_requested",
    //         "domain": "wrangler", 
    //         "type": "install_ruleset_request",
    //         "attrs": {
    //             "absoluteURL":meta:rulesetURI.klog("RULESET URI"),
    //             "rid": "wovyn_base",
    //             "config": {},
    //             "sensor_id": event:attrs{"sensor_id"},
    //             "s_name": event:attrs{"s_name"},
    //             "location": event:attrs{"sensor_id"},
    //             "threshold_temp": event:attrs{"threshold_temp"},
    //             "sms_num": "+14103706090",
    //             "eci": the_sensor.get("eci")
    //         }
    //         }
    //     )
    //   }

}