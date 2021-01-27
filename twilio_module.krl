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
  
}