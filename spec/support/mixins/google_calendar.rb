# Monkey Patch google calendar to return dummy data in test environment

require 'json'
require 'ostruct'

class GoogleCalendar
	class Request
		private 
		def get_data
			response = OpenStruct.new
			response.body = '{
				"items": [],
			  "kind": "calendar#event",
			  "etag": "etag",
			  "id": "string",
			  "status": "string",
			  "htmlLink": "string",
			  "created": "datetime",
			  "updated": "datetime",
			  "summary": "string",
			  "description": "string",
			  "location": "string",
			  "colorId": "string",
			  "creator": {
			    "id": "string",
			    "email": "string",
			    "displayName": "string",
			    "self": true
			  },
			  "organizer": {
			    "id": "string",
			    "email": "string",
			    "displayName": "string",
			    "self": true
			  },
			  "start": {
			    "date": "date",
			    "dateTime": "datetime",
			    "timeZone": "string"
			  },
			  "end": {
			    "date": "date",
			    "dateTime": "datetime",
			    "timeZone": "string"
			  },
			  "endTimeUnspecified": true,
			  "recurrence": [
			    "string"
			  ],
			  "recurringEventId": "string",
			  "originalStartTime": {
			    "date": "date",
			    "dateTime": "datetime",
			    "timeZone": "string"
			  },
			  "transparency": "string",
			  "visibility": "string",
			  "iCalUID": "string",
			  "sequence": 42,
			  "attendees": [
			    {
			      "id": "string",
			      "email": "string",
			      "displayName": "string",
			      "organizer": true,
			      "self": true,
			      "resource": true,
			      "optional": true,
			      "responseStatus": "string",
			      "comment": "string",
			      "additionalGuests": 42
			    }
			  ],
			  "attendeesOmitted": true,
			  "extendedProperties": {
			    "private": {
			      "key": "string"
			    },
			    "shared": {
			      "key": "string"
			    }
			  },
			  "hangoutLink": "string",
			  "gadget": {
			    "type": "string",
			    "title": "string",
			    "link": "string",
			    "iconLink": "string",
			    "width": 42,
			    "height": 42,
			    "display": "string",
			    "preferences": {
			      "key": "string"
			    }
			  },
			  "anyoneCanAddSelf": true,
			  "guestsCanInviteOthers": true,
			  "guestsCanModify": true,
			  "guestsCanSeeOtherGuests": true,
			  "privateCopy": true,
			  "locked": true,
			  "reminders": {
			    "useDefault": true,
			    "overrides": [
			      {
			        "method": "string",
			        "minutes": 42
			      }
			    ]
			  },
			  "source": {
			    "url": "string",
			    "title": "string"
			  }
			}'
			response
		end
	end
end