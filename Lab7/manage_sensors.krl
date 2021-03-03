ruleset manage_sensors {
    meta {
        use module io.picolabs.subscription alias subs
        use module io.picolabs.wrangler alias wrangler
        shares nameFromID, showChildren, manage_sensors, sensors//, getChildProfile, getChildRulesets, getChildTemps
    }
    global {
        collection_threshold = 30

        nameFromID = function(sensor_id) {
            "Sensor " + sensor_id + " Pico"
          }

        showChildren = function() {
            wrangler:children()
        }

        sensors = function() {
            ent:sensors
        }
        
        manage_sensors = function(){
            valid_sensors = subs:established().filter(function(v,k){
              v{"Tx_role"} == "temperature_sensor"
            }).klog("FILTERED")
            separates = valid_sensors.map(function(v, k){
                args = {}
                eci = v{"Tx"}.klog("eci: ")
                ctx:query(eci, "temperature_store","temperatures", args)
            });
            separates.values().reduce(function(a, b){
              a.values().append(b.values())
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

    rule add_exisiting_sensor {
      select when sensor add_existing
      pre {
        sensor_id = event:attr("sensor_id").klog("CONNECT TO EXISTING")
        the_sensor = {"eci": null}
        wellKnown_eci = event:attr("wellKnown_eci")
      }
      fired {
        ent:sensors{sensor_id} := the_sensor
        ent:sensors{[sensor_id,"wellKnown_eci"]} := wellKnown_eci
        raise sensor event "new_subscription_request".klog("RAISING SUB REQ EVENT for existing pico")
          attributes {"sensor_id": sensor_id}
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

    rule accept_wellKnown {
      select when sensor identify
        sensor_id re#(.+)#
        wellKnown_eci re#(.+)#.klog("IN WELL KNOWN")
        setting(sensor_id,wellKnown_eci)
        send_directive("well known", {"wkeci": wellKnown_eci})
      fired {
        ent:sensors{[sensor_id,"wellKnown_eci"]} := wellKnown_eci
        raise sensor event "new_subscription_request".klog("RAISING SUB REQ EVENT")
          attributes {"sensor_id": sensor_id}
      }
    }

    rule make_a_subscription {
      select when sensor new_subscription_request
      pre{
        sensor_id = event:attr("sensor_id")
        wk_rx = ent:sensors{[sensor_id,"wellKnown_eci"]}.klog("ABOUT TO SEND REQ:")
      }
      event:send({
        "eci": wk_rx,
        "domain":"wrangler", "name":"subscription",
        "attrs": {
          "wellKnown_Tx":subs:wellKnown_Rx(){"id"},
          "Rx_role":"temperature_sensor", "Tx_role":"sensor_collection",
          "name":sensor_id+"-temp_management", "channel_type":"subscription"
        }
      })
    } 

    rule auto_accept {
      select when wrangler inbound_pending_subscription_added
      pre {
        my_role = event:attr("Rx_role").klog("MY ROLE")
        their_role = event:attr("Tx_role").klog("THEIR ROLE")
      }
      if their_role=="temperature_sensor" && my_role=="sensor_collection" then noop()
      fired {
        raise wrangler event "pending_subscription_approval".klog("ACCEPTed SUB MAN")
          attributes event:attrs
        ent:subscriptionTx := event:attr("Tx")
      } else {
        raise wrangler event "inbound_rejection".klog("Rejected  SUB MAN")
          attributes event:attrs
      }
    }
}
