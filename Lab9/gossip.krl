// Clone another engine and run it separately, see github page for info 
// Have the two engines talk to each other
ruleset gossip {
    meta {
        use module io.picolabs.subscription alias subs
        provides smart_tracker, temp_logs
        shares smart_tracker, temp_logs, my_seen, status
    }
    global {
        default_message = {
            "MessageID": null,
            "SensorID": null,
            "Temperature": -99,
            "Timestamp": null
        }
        clear_log = {}

        status = function(){
            ent:process.defaultsTo("off")
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
            t1 = seen1.klog("seen1")
            t2 = seen2.klog("seen2")
            // Add keys that are in 1 but not 2
            nSarray = seen1.keys().difference(seen2.keys())
            temp = nSarray.klog("in 1 but not 2")

            // Add keys that are in both but, val 2 < val 1
            s_map = seen1.map(function(v, k){
                val_diffs = seen2.filter(function(v2, k2){
                    k2 == k && v2.as("Number") < v.as("Number")
                })
                val_diffs.keys()[0].klog("Adding keys in both but v2 < v1")
            }).klog("s_map")

            nSarray.append(s_map.values()).filter(function(a){
                t = a.klog("a")
                a != null
            }).klog("FINAL NOT SEEN RETURN")
        }

        getPeer = function(){
            peers = subs:established().filter(function(v,k){v{"Tx_role"} == "node"}).klog("PEERS TO CHECK")
            items_needed = peers.map(function(a){
                t2 = ent:smart_tracker.keys()
                seen2 = ent:smart_tracker{a{"Rx"}}.defaultsTo({})
                nsResult = notSeen(ent:my_seen, seen2)
                nsResult.length().klog("Items needed:")
            })
            peer = peers.filter(function(p){
                t = p.klog("P")
                seen2 = ent:smart_tracker{p{"Rx"}}.klog("seen2 in peer filter").defaultsTo({})
                nsResult = notSeen(ent:my_seen, seen2)
                nsResult.length() == items_needed.values().sort("reverse")[0].klog("max val")
            })
            rand_n = random:integer(peer.length() - 1).klog("WHICH PEER TO CHOOSE?")
            peer[rand_n].klog("RETURN OF GET PEER")
        }

        prepareRumor = function(subscriber){
            seen2 = ent:smart_tracker{subscriber{"Rx"}.klog("eci")}.defaultsTo({})
            possible_rumors = notSeen(ent:my_seen, seen2).klog("possible rumors")
            // Randomly select a rumor to send that the subscriber hasn't seen
            n2 = random:integer(possible_rumors.length() - 1).klog("n2")
            r = possible_rumors[n2].klog("r")
            temp = ent:temp_logs.keys().klog("match here")
            
            // Send the most recent based on given id
            source_logs = ent:temp_logs{r}
            k = source_logs.keys().reverse()[0]
            source_logs{k}.klog("RUMOR MESSAGE TO SEND: ")
        }

        prepareSeen = function(){
            ent:my_seen.defaultsTo({})
        }

        prepareMessage = function(subscriber){
            n = random:integer(upper = 1, lower = 0).klog("RANDOM NUMBER:")
            output = (n < 1) => prepareRumor(subscriber) | prepareSeen()
            output
        }
    }


    rule process_gossip_heartbeat{
        select when gossip heartbeat
        pre {
            subscriber = getPeer()
            m = prepareMessage(subscriber).klog("MESSAGE:")
            message_type = (m.get("MessageID")) => "rumor" | "seen"
        }
        if m != null then
            event:send({
                "eci": subscriber{"Tx"},                        
                "eid":"sending_info",                  
                "domain":"gossip",                     
                "type": message_type.klog("SENDING SOMETHING from heartbeat"),             
                "attrs":{
                        "message": m,
                        "sensor_id": subscriber{"Tx"} //subs:wellKnown_Rx(){"id"}
                        }
            })
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

    rule add_message {
        select when gossip add_message
        pre{
            origin_id = event:attr("OriginID")
            message_id = event:attr("MessageID")
            temperature = event:attr("Temperature")
            timestamp = event:attr("Timestamp")
            message_num = message_id.substr(message_id.length() - 1).klog("MESSAGE NUM")
            message = {
                "MessageID": message_id,
                "SensorId": origin_id,
                "Temperature": temperature,
                "Timestamp": timestamp
            }
        }
        always{
            // ent:temp_logs := ent:temp_logs.defaultsTo(clear_log, "initialization was needed");
            // ent:temp_logs := ent:temp_logs.put([origin_id, message_id, "MessageID"], message_id)
            //                 .put([origin_id, message_id, "SensorId"], origin_id)
            //                 .put([origin_id, message_id, "Temperature"], temperature)
            //                 .put([origin_id, message_id, "Timestamp"], timestamp)
            ent:temp_logs := ent:temp_logs.defaultsTo({}).put([origin_id, message_id], message.klog("message")).klog("UPDATE TEMP LOGS IN ADD")
            ent:my_seen := ent:my_seen.defaultsTo({}).put([origin_id], message_num).klog("updated seen")
            ent:my_id := subs:wellKnown_Rx(){"id"}
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
                            "sensor_id": event:attr("sensor_id") //subs:wellKnown_Rx(){"id"}
                            }
                })
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