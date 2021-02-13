ruleset sensor_profile {
    meta {
        provides getProfile
        shares getProfile
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

}