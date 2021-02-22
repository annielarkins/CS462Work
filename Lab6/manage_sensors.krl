ruleset manage_sensors {
    meta {
        use module io.picolabs.wrangler alias wrangler
        shares nameFromID, showChildren, manage_sensors, sensors, getChildProfile
    }
    global {
        collection_threshold = 70

        nameFromID = function(sensor_id) {
            "Sensor " + sensor_id + " Pico"
          }

        showChildren = function() {
            wrangler:children()
        }

        sensors = function() {
            ent:sensors
        }

        getChildProfile = function(child_eci){
          args = {}
          wrangler:skyQuery(child_eci, "sensor_profile", "getProfile", args);
        }

        manage_sensors = function(){
            showChildren().map(function(v, k){
              args = {}
              eci = v{"eci"}
              wrangler:skyQuery(eci,"temperature_store","temperatures",args).klog("get temp for " + eci + ": ");
            })
        }
    }

    rule initialize_sensors {
        select when sensor needs_initialization
        always {
          ent:sensors := {}
        }
      }

    rule sensor_already_exists {
        select when sensor needed
        pre {
            sensor_id = event:attr("sensor_id")
            exists = ent:sensors && ent:sensors >< sensor_id
        }
        if exists then
            send_directive("DUPLICATE: SENSOR ALREADY EXISTS", {"sensor_id":sensor_id})
    }

    rule sensor_already_exists2 {
        select when sensor needed
        pre {
          sensor_id = event:attr("sensor_id")
          exists = ent:sensors && ent:sensors >< sensor_id
        }
        if not exists then noop()
        fired {
          raise wrangler event "new_child_request"
            attributes { "name": nameFromID(sensor_id),
                         "backgroundColor": "#ff69b4",
                         "sensor_id": sensor_id }
        }
      }

    rule store_new_sensor {
        select when wrangler new_child_created
        foreach ["twilio_module", "sensor_profile", "wovyn_base", "wovyn_emitter", "temperature_store"] setting (x)
        pre {
            the_sensor = {"eci": event:attr("eci")}
            sensor_id = event:attr("sensor_id")
        }
        if sensor_id.klog("found sensor_id")
            then 
                event:send(
                    { "eci": the_sensor.get("eci").klog("send installation event"), 
                    "eid": "install_rulesets_requested",
                    "domain": "wrangler", 
                    "type": "install_ruleset_request",
                    "attrs": {
                        "absoluteURL":meta:rulesetURI.klog("RULESET URI"),
                        "rid": x,
                        "config": {},
                        "sensor_id":sensor_id,
                        "s_name": sensor_id,
                        "location": "Annie's Apartment",
                        "threshold_temp": collection_threshold,
                        "sms_num": "+14103706090",
                        "eci": the_sensor.get("eci")
                    }
                    }
                )
        fired {
            ent:sensors{sensor_id} := the_sensor
        }
    }

    rule delete_sensor {
        select when sensor unneeded
        pre {
          sensor_id = event:attr("sensor_id")
          exists = ent:sensors >< sensor_id
          eci_to_delete = ent:sensors{[sensor_id,"eci"]}
        }
        if exists && eci_to_delete then
          send_directive("deleting_sensor", {"sensor_id":sensor_id})
        fired {
          raise wrangler event "child_deletion_request"
            attributes {"eci": eci_to_delete};
          clear ent:sensors{sensor_id}
        }
      }
}
