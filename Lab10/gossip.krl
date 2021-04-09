// Clone another engine and run it separately, see github page for info 
// Have the two engines talk to each other
ruleset gossip {
    meta {
        use module io.picolabs.subscription alias subs
        use module sensor_profile alias sp
        provides smart_tracker, temp_logs
        shares smart_tracker, temp_logs, my_seen, status, v_status, violation_count, seen_violations
    }
    global {
        default_message = {
            "MessageID": null,
            "SensorID": null,
            "Temperature": -99,
            "Timestamp": null
        }
        clear_log = {}
        message_type = "none"

        violation_count = function(){
            ent:seen_violations.defaultsTo({}).values().reduce(function(a,b){a + b})
        }

        seen_violations = function(){
            ent:seen_violations.defaultsTo({})
        }

        status = function(){
            ent:process.defaultsTo("off")
        }

        v_status = function(){
            ent:v_status.defaultsTo(-1)
        }

        smart_tracker = function(){
            ent:smart_tracker.defaultsTo({})
        }

        my_seen = function(){
            ent:my_seen.defaultsTo({})
        }

        temp_logs = function(){
            ent:temp_logs.defaultsTo({})
        }

        notSeen = function(seen1, seen2){
            t1 = seen1
            t2 = seen2
            // Add keys that are in 1 but not 2
            nSarray = seen1.keys().difference(seen2.keys())
            temp = nSarray

            // Add keys that are in both but, val 2 < val 1
            s_map = seen1.map(function(v, k){
                val_diffs = seen2.filter(function(v2, k2){
                    k2 == k && v2.as("Number") < v.as("Number")
                })
                val_diffs.keys()[0]
            })

            nSarray.append(s_map.values()).filter(function(a){
                t = a
                a != null
            })
        }

        getPeer = function(){
            peers = subs:established().filter(function(v,k){v{"Tx_role"} == "node"})
            items_needed = peers.map(function(a){
                t2 = ent:smart_tracker.keys()
                seen2 = ent:smart_tracker{a{"Rx"}}.defaultsTo({})
                nsResult = notSeen(ent:my_seen, seen2)
                nsResult.length()
            })
            peer = peers.filter(function(p){
                t = p
                seen2 = ent:smart_tracker{p{"Rx"}}.defaultsTo({})
                nsResult = notSeen(ent:my_seen, seen2)
                nsResult.length() == items_needed.values().sort("reverse")[0]
            })
            rand_n = random:integer(peer.length() - 1)
            peer[rand_n]
        }

        prepareRumor = function(subscriber){
            message_type = "rumor".klog("IN RUMOR 1")
            seen2 = ent:smart_tracker{subscriber{"Rx"}}.defaultsTo({})
            possible_rumors = notSeen(ent:my_seen, seen2)
            // Randomly select a rumor to send that the subscriber hasn't seen
            n2 = random:integer(possible_rumors.length() - 1)
            r = possible_rumors[n2]
            temp = ent:temp_logs.keys()
            
            // Send the most recent based on given id
            source_logs = ent:temp_logs{r}
            k = source_logs.keys().reverse()[0]
            source_logs{k}
        }

        prepareSeen = function(){
            message_type = "seen".klog("IN SEEN")
            ent:my_seen.defaultsTo({})
        }

        prepareRumor2 = function(){
            message_type = "rumor2".klog("IN RUMOR 2")
            nV = random:integer(ent:seen_violations - 1).klog("n2")
            testing = ent:seen_violations.klog("SEEN VIOLATIONS")
            vK = ent:seen_violations.keys()[nV].klog("VK")
            vNum = (ent:seen_violations{vK} >= 1) => 1 | 0
            newArr = [vK, vNum].klog("THE VIO MESSAGE")
            newArr
            // ent:seen_violations{ent:my_id}.defaultsTo(0).klog("THE VIO MESSAGE")
        }

        prepareMessage = function(subscriber){
            n = random:integer(upper = 1, lower = 0)
            nr = random:integer(upper = 1, lower = 0)
            ns = random:integer(upper = 1, lower = 0)
            rumor_type = (nr < 1) => prepareRumor(subscriber) | prepareRumor2(subscriber)
            output = (n < 1) => rumor_type | prepareSeen()
            output.klog("PREP MESS OUTPUT")
        }
    }


    rule process_gossip_heartbeat{
        select when gossip heartbeat
        pre {
            subscriber = getPeer()
            m = prepareMessage(subscriber).klog("MESSAGE:")
            message_type = (typeof(m) == "Map").klog("is map") => "seen" | "rumor2"
            final_message_type = (m.get("MessageID")) => "rumor" | message_type
            temp = final_message_type.klog("EVENT TYPES IS:") 
            
        }
        if m != null then
            event:send({
                "eci": subscriber{"Tx"},                        
                "eid":"sending_info",                  
                "domain":"gossip",                     
                "type": final_message_type.klog("SENDING SOMETHING from heartbeat"),             
                "attrs":{
                        "message": m,
                        "sensor_id": subscriber{"Tx"}, //subs:wellKnown_Rx(){"id"}
                        "host": subscriber{"Tx_host"}
                        },
            }, subscriber{"Tx_host"})
        always{
            schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:hb_period.defaultsTo(10)}).klog("SENDING HEARTBEAT from HB")
        }
    }

    rule setup {
        select when gossip initialize
        foreach subs:established().filter(function(v,k){v{"Tx_role"} == "node"}) setting(sens)
        pre {
            eci = sens{"Tx"}.klog("Putting in smart tracker")
            hbp = event:attr("period")
        }
        always{
            ent:hb_period := hbp
            ent:temp_logs := {}  
            ent:smart_tracker := {}   
            ent:my_seen := {}  
            ent:seen_violations := {}     
            ent:process := "on"
            schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:hb_period}).klog("SENDING HEARTBEAT from SETUP") on final
        }
    }

    rule process_rumor {
        select when gossip rumor
        pre {
            message = event:attr("message")
            message_id = message.get("MessageID")
            origin_id = message.get("SensorId")
            rumor_type = message.get("RumorType")
            message_num = message_id.substr(message_id.length() - 1).as("Number").klog("MESSAGE NUM")
        }
            if (message_num - ent:my_seen{origin_id}.as("Number") < 1) then noop()
            fired{
                ent:my_seen := ent:my_seen.defaultsTo({}).put([origin_id], ent:my_seen{origin_id}.as("Number")).klog("updated seen") if ent:process == "on"
                ent:temp_logs := ent:temp_logs.put([origin_id, message_id], message) if ent:process == "on".klog("UPDATE TEMP LOGS IN PR1")
            }
            else{
                ent:my_seen := ent:my_seen.defaultsTo({}).put([origin_id], message_num).klog("updated seen") if ent:process == "on"
                ent:temp_logs := ent:temp_logs.put([origin_id, message_id], message) if ent:process == "on".klog("UPDATE TEMP LOGS IN PR2")
            }    
    }

    rule process_rumor2 {
        select when gossip rumor2
        pre {
            message = event:attr("message").klog("MESSAGE")
            mp1 = message[0]
            mp2 = message[1]
            sv = ent:seen_violations{mp1}.defaultsTo(0).klog("SV")
            sv2 = (sv >= 1) => 1 | sv
            message2 = (mp2 >= 1) => 1 | mp2
            // message_id = message.get("MessageID")
            // origin_id = message.get("SensorId")
            // rumor_type = message.get("RumorType")
            // message_num = message_id.substr(message_id.length() - 1).as("Number").klog("MESSAGE NUM")
        }
        if mp1 != null then noop()
        fired {
            ent:seen_violations := ent:seen_violations.defaultsTo({}).put([mp1], sv2 + message2)
        }
        // always{
        //     // updated_val1 = (ent:seen_violations{event:attr("sensor_id")}.defaultsTo(0) + message).klog("Updated val")
        //     // updated_val2 = (updated_val1 > 0) => 1 | updated_val1
        //     // updated_val3 = (updated_val2 < 0) => 0 | updated_val2


        //     ent:seen_violations := ent:seen_violations.defaultsTo({}).put([mp1], sv2 + message2)
        //     //ent:seen_violations{event:atttr("sensor_id")} := ent:seen_violations{event:attr("sensor_id")}.defaultsTo(0).klog("existing val") + message
        // } 
    }

    rule add_message {
        select when gossip add_message
        pre{
            origin_id = event:attr("OriginID")
            message_id = event:attr("MessageID")
            temperature = event:attr("Temperature")
            timestamp = event:attr("Timestamp")
            tempDifference = (temperature - sp:getProfile(){"threshold_temp"}).klog("TEMP DIFFERENCE: ")
            // filler = (ent:v_status.defaultsTo(-1) >= 0) => 0 | 1
            message_num = message_id.substr(message_id.length() - 1).klog("MESSAGE NUM")
            violation = tempDifference > 0
            sv = ent:seen_violations{ent:my_id}.defaultsTo(0)
            message = {
                "MessageID": message_id,
                "SensorId": origin_id,
                "Temperature": temperature,
                "Timestamp": timestamp,
            }
            ones_val = (violation == false && sv == 1) => -1 | 1
        }
        always{
            ent:temp_logs := ent:temp_logs.defaultsTo({}).put([origin_id, message_id], message.klog("message")).klog("UPDATE TEMP LOGS IN ADD")
            ent:my_seen := ent:my_seen.defaultsTo({}).put([origin_id], message_num).klog("updated seen")
            ent:my_id := subs:wellKnown_Rx(){"id"}
            ent:v_status := ( (violation == false && sv == 0) || 
                              (violation == true && sv == 1) || 
                              (violation == false && sv == -1))
                              => 0 | ones_val
            my_status = sv + ent:v_status.klog("MY STATUS!!!!!")
            my_stat = (my_status >= 1) => 1 | my_status
            ent:seen_violations{ent:my_id} := my_stat.klog("updated stat")
            schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:hb_period.defaultsTo(10)}).klog("SENDING HEARTBEAT from PROCESS") if ent:process == "on"
        }
    }

    rule process_seen {
        select when gossip seen
        foreach notSeen(ent:my_seen, ent:smart_tracker{event:attr("sensor_id")}.defaultsTo({})) setting(rumor)
        pre {
            temp = rumor.klog("CURRENT RUMOR")
            eci = event:attr("sensor_id").klog("SENDING UNSEEN FROM PROCESS SEEN")
            message = event:attr("message")
            
            temp2 = ent:temp_logs.keys().klog("match here")
            
            // Send the most recent based on given id
            source_logs = ent:temp_logs{rumor}
            k = source_logs.keys().reverse()[0]
            mToReturn = source_logs{k}.klog("RUMOR MESSAGE TO SEND: ")
        }
            if mToReturn != null && ent:process == "on" then
                event:send({
                    "eci": event:attr("sensor_id"),                        
                    "eid":"sending_info",                  
                    "domain":"gossip",                     
                    "type": "rumor",             
                    "attrs":{"message": mToReturn,
                            "sensor_id": event:attr("sensor_id") //subs:wellKnown_Rx(){"id"},
                            }
                }, event:attr("host"))
            always {
                ent:smart_tracker := ent:smart_tracker.defaultsTo({}).put([eci], message).klog("updated smart tracker") if ent:process == "on"
            }
    }

    rule turn_off_on{
        select when gossip process_gossip_heartbeat
        pre {
            status = event:attr("status").defaultsTo("off")
        }
        always{
            ent:process := status
            schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:hb_period.defaultsTo(10)}).klog("SENDING HEARTBEAT from PROCESS") if ent:process == "on"
        }
    }
}