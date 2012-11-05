require "rubygems"
require "bundler/setup"
require 'google/api_client'
require "mailman"
require 'open-uri'
require 'nokogiri'
require 'json'

module Ticketmaster

   module Parser

     class << self

       def receive_mail(message)

        # Generic attributes for Ticketmaster:
        item = Item.new
        item.merchant = "Ticketmaster"
        item.category = "events"

        email_subject = message.subject.to_s
        email_subject =~ /Order Confirmation for (.*)/

        # Name the item saved to a user's account/calendar
        item.name = $1


        # If the message was sent to the default 
        # "stuff@propdi.com," find the user by the
        # email's from field. If that doesn't exist,
        # it means the user provided their Propdi email
        # address during checkout from a merchant, so the 
        # receipt was sent to that email.

        if message.to =~ /stuff@propdi.com/i
          item.user_id=User.find_by_email(message.from)
        else 
          item.user_id=User.find_by_assigned_email(message.to)
        end

        fullemail = message.body.to_s
        doc = Nokogiri::HTML(fullemail)
        doc = doc.text.split("Please do not reply to this email")
        doc = doc[0]
        
        # Set item attribute #2: the order number from the ticket purchase

        doc =~ /this purchase is (\S*)\./i
          item.att2 = "Order number: #{$1}"
        
        # Set ticket quantity from the purchase

        doc =~ /purchased (\d{1,3})/i
          item.quantity = $1
        
        # Parse out the name of the event. This has a conditional
        # because on occassion, a performer can have the word "at"
        # in their formal name (ie, Panic at the Disco). I use the 
        # assumption that most mainstream acts don't have the word 
        # "at" twice in their name.

        doc =~ /(.*)\s(.*)\s(.*(AM|PM))\s{1,4}order/i
          if $1.to_s.include?('at')
            tempeventname = $1.to_s.split('at')
            if tempeventname.count = 2
              item.name = tempeventname[0].to_s
            else
              item.name = "#{tempeventname[0].to_s} #{tempeventname[1].to_s}"  
            end
          else
            item.name = $1
          end

        # Set the address and date where the event occurs

          item.address = $2
          item.date_from_email = $3

        # Set the date time where the event occurs. This is used
        # for chronological sorting of multiple items in a user's
        # account. The default end time is 7200 seconds (2 hours)
        # after the start time. Users can change this in their
        # account preferences. I also user strftime to convert this
        # date time to a format that the Google Calendar API will accept.

          item.dateTime = DateTime.parse(item.date_from_email)

            start_time = Time.parse(item.date_from_email)
            end_time = start_time + 7200
      
            item.gcal_start_date = start_time.strftime("%Y-%m-%dT%H:%M:%S").gsub(" ","")
            item.gcal_end_date = end_time.strftime("%Y-%m-%dT%H:%M:%S").gsub(" ","")
        
        # Set price of purchase

        doc =~ /Total charge:.*\s(\d{1,4}\D\d{1,2})\s/i
          item.att3 = $1

        # Set seat location

        doc =~ /seat location: (.*)\s/i
          ticket.att1 = "Seat location: #{$1}"
        
        # Set delivery/shipping method


        if doc.include?("TicketFast")
          item.att4 = "TicketFast"
        else
          doc =~ /via: (\w* \w*{0,})/i  
          item.att4 = $1
          
          doc =~ /via: \w* \w*{0,}\W*(.*)\s/i
          item.att5 = $1
        end 
        
        # Find the sender and email them a confirmation that the
        # item has been added to their account (if it saves). Then,
        # generate JSON and pass it to Google to add it to the user's
        # calendar!
                
        user = User.find_by_email(message.from)

        if item.save
           UserMailer.new_ticket_confirmation(user, item).deliver
        end
           

                  
                  
        event = {
            'summary' => "#{ticket.eventname}",
            'location' => "#{ticket.address}",
            'start' => {
              'dateTime' => "#{correct_start_time}",
              'timeZone' => "America/Chicago",    
            },
            'end' => {
              'dateTime' => "#{correct_end_time}",
              'timeZone' => "America/Chicago",    
            },
            # 'reminders' => {
            #   'useDefault' => "useDefault",
            # },
            'description' => "Quantity: #{item.quantity}; Location: #{item.seat}. You paid #{item.price} for this order. Your order number is #{item.orderno}"
        }
 
        client = Google::APIClient.new  
          
          client.authorization.access_token = User.find_by_email(message.from).get_oauth_token
          service = client.discovered_api('calendar', 'v3')
          result = client.execute(:api_method => service.events.insert,
                                  :parameters => {'calendarId' => 'primary'},
                                  :body_object => event,
                                  :headers => {'Content-Type' => 'application/json'})
                    
        end
        
      end
    end


    #http://www.google.com/calendar/event?action=TEMPLATE&pprop=eidmsgid%3A_clr6arjkbsrjedpm6sq30ci0dlimat3le0n66rrd_139277f707ab6790&dates=20120815T193000%2F20120815T223000&text=CA%20Wednesday%20Drinks&location&details=Code%20Academy%0AWednesday%2C%20August%2015%20at%207%3A30%20PM%0A%0AWhat%3A%20CA%20Wednesday%20Drinks%0A%0AWhere%3A%20Pepper%20Canister%20509%20N.%20Wells.%20(just%20two%20blocks%20south%20of%20Merch%20on%20Wells)%0A%0AWhy%3A%20Mid-week%20drinking%20is%20good%0A%0AWhen%3A%207%3A30pm...%0A%0ADetails%3A%20http%3A%2F%2Fwww.meetup.com%2Fcodeacademy%2Fevents%2F77767402%2F&add=ianmargolis%40gmail.com&ctok=aWFubWFyZ29saXNAZ21haWwuY29t


