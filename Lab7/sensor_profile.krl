ruleset sensor_profile {
    meta {
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
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
          parent_eci = wrangler:parent_eci()
          wellKnown_eci = subs:wellKnown_Rx(){"id"}.klog("GETTING THE WKE:")
        }
        event:send({
            "eci": parent_eci,
            "domain": "sensor", "type": "identify",
            "attrs": {
            "sensor_id": sensor_id,
            "wellKnown_eci": wellKnown_eci
            }
        })
        always {
          ent:sensor_id := sensor_id
          raise sensor event "profile_updates"
            attributes {"location": location,
                        "s_name" : s_name,
                        "threshold_temp " : threshold_temp,
                        "sms_num" : sms_num }

        }
    }

    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        pre {
          my_role = event:attr("Rx_role")
          their_role = event:attr("Tx_role")
        }
        if my_role=="temperature_sensor" && their_role=="sensor_collection" then noop()
        fired {
          raise wrangler event "pending_subscription_approval".klog("ACCEPTed SUB")
            attributes event:attrs
          ent:subscriptionTx := event:attr("Tx")
        } else {
          raise wrangler event "inbound_rejection".klog("DIDN'T ACCEPT SUB")
            attributes event:attrs
        }
      }

      rule auto_accept2 {
        select when wrangler inbound_pending_subscription_added
        pre {
          my_role = event:attr("Rx_role").klog("MY ROLE")
          their_role = event:attr("Tx_role").klog("THEIR ROLE")
        }
        if my_role=="collection" && their_role=="temp_sensor" then noop()
        fired {
          raise wrangler event "pending_subscription_approval".klog("ACCEPTed22222222 SUB MAN")
            attributes event:attrs.klog("EVENTS TO INSPECT:")
          
          ent:subscriptionTx := event:attr("Tx")
        } else {
          raise wrangler event "inbound_rejection".klog("Rejected222222222  SUB MAN")
            attributes event:attrs
        }
      }

      rule connect_to_collection{ 
        select when sensor unconnected
        fired{
            raise sensor event "add_existing"
            attributes {
                "sensor_id": ent:sensor_profile{"s_name"},
                "eci": wrangler:parent_eci(),
                "wellKnown_eci": subs:wellKnown_Rx(){"id"}
            }
        }
      } 
    
}