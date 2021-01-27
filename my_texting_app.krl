ruleset my_texting_app {
  meta {
    use module com.twilio.sms alias twilio
      with
        account_sid = meta:rulesetConfig{"account_sid"}
        auth_token = meta:rulesetConfig{"auth_token"}
  }
  
  global {

  }
  
  rule test_send_sms {
    select when test new_message
    twilio:send_sms(event:attr("to"),
                    event:attr("from"),
                    event:attr("message")
                   )
  }
  
 rule get_sms {
    select when test view_message
    pre {
        to = event:attr("to")
        => event:attr("to")
        | null
        from = event:attr("from")
        => event:attr("from")
        | null
        limit = event:attr("limit")
        => event:attr("limit")
        | null
        messages = twilio:messages(to, from, limit) 
    }
    send_directive(messages)
  }
}