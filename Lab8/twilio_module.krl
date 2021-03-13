ruleset com.twilio.sms {
  meta {
    configure using
      account_sid = ""
      auth_token = ""
    provides send_sms, messages
    //shares messages
  }
  
  global {

    send_sms = defaction(to, from, message) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
       http:post(base_url + "Messages.json", form = {
                "From":from,
                "To":to,
                "Body":message
            })
    }
    
    messages = function(to, from, limit) {
        base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/>>
        args = {"To": to, "From": from}
        response = http:get(base_url + account_sid + "/Messages.json", args){"content"}.decode().get("messages")
        m_limit = limit
        => limit - 1
        | response.length() - 1
        response.slice(m_limit)
    }
    
  }

  // rule initialize_state {
  //   select when wrangler ruleset_installed
  //     where event:attrs{"rids"} >< meta:rid
  //     pre{
  //       the_sensor = {"eci": event:attr("eci")}.klog("RECIEVED ECI:")
  //     }
  //     event:send(
  //       { "eci": the_sensor.get("eci").klog("send installation event"), 
  //       "eid": "install_rulesets_requested",
  //       "domain": "wrangler", 
  //       "type": "install_ruleset_request",
  //       "attrs": {
  //           "absoluteURL":meta:rulesetURI.klog("RULESET URI"),
  //           "rid": "sensor_profile",
  //           "config": {},
  //           "sensor_id": event:attrs{"sensor_id"},
  //           "s_name": event:attrs{"s_name"},
  //           "location": event:attrs{"sensor_id"},
  //           "threshold_temp": event:attrs{"threshold_temp"},
  //           "sms_num": "+14103706090",
  //           "eci": the_sensor.get("eci")
  //       }
  //       }
  //   )
  // }
  
}