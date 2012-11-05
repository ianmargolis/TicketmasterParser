This is a sample module from my email parsing application. While it doesn't include full-fledged settings functionality (and has several improvements still to be made), it should give you a basic sense as to the strategies that I use to take a noisy email confirmation and parse out the meaningful details. 

This type of parsing can be used in conjunction with either an email receiver to fetch forwarded emails (try the Mailman gem) or direct inbox access (I use OAuth2 for read-only Gmail access).

I also include a look into how purchase details are used (in JSON format) to add the information to a user's Google Calendar.