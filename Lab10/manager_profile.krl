ruleset manager_profile{
    meta {
        use module com.twilio.sms alias twilio
        with
            account_sid = meta:rulesetConfig{"account_sid"}
            auth_token = meta:rulesetConfig{"auth_token"}
    }
    global {
        to_number = "None" //"+14103706090"
        from_number = "+18152402977"
    }
    
    rule threshold_notification {
        select when wovyn threshold_violation
        pre {
            to = to_number.klog("SENT TEXT TO:")
            sms_message = ("A Wovyn Sensor registered a temperature above your threshold: " + event:attrs{"temperature"}).klog("MESSAGE DRAFTED: ")
        }
        twilio:send_sms(to, from_number, sms_message)
        
    }
}