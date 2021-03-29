ruleset manage_sensors {
    meta {
        use module io.picolabs.subscription alias subs
        use module io.picolabs.wrangler alias wrangler
        shares nameFromID, showChildren, manage_sensors, sensors, reports //, getChildProfile, getChildRulesets, getChildTemps
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
        tempReports = function() {
          ent:temperature_reports
      }
        
        manage_sensors = function(){
            valid_sensors = subs:established().filter(function(v,k){
              v{"Tx_role"} == "temp_sensor"
            }).klog("FILTERED")
            separates = valid_sensors.map(function(v, k){
                args = {}
                eci = v{"Tx"}.klog("eci: ")
                host = v{"Tx_host"}
                //ctx:query(eci, "temperature_store","temperatures", args)
                wrangler:picoQuery(eci, "temperature_store", 
                "temperatures", null, host);
            });
            separates.values().reduce(function(a, b){
              a.values().append(b.values())
            })
        }

        reports = function(){
          crop_val = (ent:report_data.length() <= 5) => ent:report_data.length() - 1
          | 4
          t = crop_val.klog("crop val")
          reduced_keys = ent:report_data.keys().slice((ent:report_data.length() - crop_val - 1).klog("begin"), ent:report_data.length() - 1).klog("new keys")
          ent:report_data.filter(function(v, k){reduced_keys.any(function(x){x.klog("X") == k.klog("K")})})
        }
    }

    rule start_gossip{
      select when gossip start
      foreach subs:established().filter(function(v,k){
        v{"Tx_role"} == "temp_sensor"
      }).klog("FILTERED") setting(node)

      pre{
        eci = node{"Tx"}.klog("eci: ")
        host = node{"Tx_host"}
      }
      event:send({
        "eci":eci,                        
        "eid":"sending_info",                  
        "domain":"gossip",                     
        "type":"initialize", 
        "attrs": {"period": event:attr("period")}          
      })
      
    }

    rule initialize_sensors {
        select when sensor needs_initialization
        always {
          ent:sensors := {}
        }
      }

      rule initialize_records {
        select when record needs_initialization
        always {
          ent:report_data := {}
          ent:temperature_reports := {}
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
        foreach ["temperature_store", "twilio_module", "sensor_profile", "wovyn_base", "wovyn_emitter", "gossip"] setting (x)
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
        hostname = event:attr("hostname") || null
      }
      event:send({
        "eci": wellKnown_eci,
        "domain": "wrangler", "type": "subscription",
        "attrs": {
            "wellKnown_Tx": subs:wellKnown_Rx(){"id"},
            "Tx_role": "collection", 
            "Rx_role": "temp_sensor",
            "name": "collection-" + sensor_id,
            "channel_type": "subscription",
            "Tx_host": hostname,
            "Rx_host": "http://366a94bb8c21.ngrok.io"
        }
      }, hostname)
      fired {
        ent:sensors{sensor_id} := the_sensor
        ent:sensors{[sensor_id,"wellKnown_eci"]} := wellKnown_eci
        // raise sensor event "new_subscription_request".klog("RAISING SUB REQ EVENT for existing pico")
        //   attributes {"sensor_id": sensor_id}
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
          "Rx_role":"temp_sensor", "Tx_role":"collection",
          "name":sensor_id+"-temp_management", "channel_type":"subscription"
        }
      })
    } 

    rule auto_accept2 {
      select when wrangler inbound_pending_subscription_added
      pre {
        my_role = event:attr("Rx_role").klog("MY ROLE")
        their_role = event:attr("Tx_role").klog("THEIR ROLE")
      }
      if their_role=="temp_sensor" && my_role=="collection" then noop()
      fired {
        raise wrangler event "pending_subscription_approval".klog("ACCEPTed SUB MAN")
          attributes event:attrs
        ent:subscriptionTx := event:attr("Tx")
      } else {
        raise wrangler event "inbound_rejection".klog("Rejected  SUB MAN")
          attributes event:attrs
      }
    }

    rule start_temperature_report {
      select when manager temperature_report_start
      pre {
        new_rcn = random:uuid()
        rcn = event:attr("report_correlation_number") || new_rcn
        start = time:now()
        report_data = {
          "start": start
        }
        // augmented_attrs = event:attrs.put(["report_correlation_number", rcn]).klog("put")
        // aug2 = augmented_attrs.set(["report_correlation_number"], rcn).klog("set")
      }
      fired {
        raise explicit event "temperature_report_routable"
          attributes event:attrs.put(["report_correlation_number"], rcn)
        ent:report_data{rcn} := report_data
      }
    }

    rule process_temperature_report_with_rcn {
      select when explicit temperature_report_routable
      foreach subs:established().filter(function(v,k){v{"Tx_role"} == "temp_sensor"}) setting(sens)
        pre {
          rcn = event:attr("report_correlation_number")
          eci = sens{"Tx"}.klog("eci: ")
          host = sens{"Tx_host"}
          start = event:attr("start")
        }
        event:send({
                  "eci":eci,                        
                  "eid":"sending_info",                  
                  "domain":"sensor",                     
                  "type":"periodic_temperature_report",             
                  "attrs":{"report_correlation_number": rcn,
                            "start": start}
        })
    }

    rule catch_period_temperature_reports {
      select when sensor periodic_temperature_report_created
      pre {
        sensor_id = event:attr("sensor_id")
        rcn = event:attr("report_correlation_number")
        updated_temperature_reports = (ent:temperature_reports{[rcn, "reports"]})
                                        .defaultsTo([])
                                        .append(event:attr("temperature"));
      }
      noop();
      always{
        ent:temperature_reports{[rcn,"reports"]} := updated_temperature_reports.klog("REPORT FROM CREATE");
        raise explicit event "periodic_temperature_report_added"
          attributes event:attrs
      }
    }

    rule check_periodic_report_status {
      select when explicit periodic_temperature_report_added
      pre {
        rcn = event:attr("report_correlation_number")
        sensors_in_collection = subs:established().filter(function(v,k){v{"Tx_role"} == "temp_sensor"}).length();
        test = ent:temperature_reports{rcn}.klog("CURRENT REPORTS")
        number_of_reports_received = (ent:temperature_reports{[rcn,"reports"]}).length();
      }
      if (sensors_in_collection <= number_of_reports_received) then noop();
      fired {
        log info "process temperature reports ";
        raise explicit event "period_report_ready"
          attributes event:attrs
      } else {
        log info "we're still waiting for " + (sensors_in_collection - number_of_reports_received)
        + " reports on #{rcn}";
      }
    }

    rule update_report_data {
      select when explicit period_report_ready
      pre{
        rcn = event:attr("report_correlation_number")
        temp = ent:report_data{rcn}.put(["temperatures"], ent:temperature_reports{rcn}{"reports"}).klog("putting data in")
        temp2 = temp.put(["temperature_sensors"], subs:established().filter(function(v,k){v{"Tx_role"} == "temp_sensor"}).length()).klog("temp2")
        temp3 = temp2.put(["responding"], ent:temperature_reports{[rcn,"reports"]}.length())
      }
      noop();
      always {
        ent:report_data{rcn} := temp3
      }
    }
}
