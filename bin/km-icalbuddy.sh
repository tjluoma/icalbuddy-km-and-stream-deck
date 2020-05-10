#!/usr/bin/env zsh -f
# Purpose: Use icalBuddy and Keyboard Maestro to show calendar events on Stream Deck
#
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2020-05-09

	## NOTE! ! ! YOU MUST MUST MUST EDIT THE 'CALENDARS' VARIABLE
	# if more than one, separate with a comma, no space
	# CaSe MAtTERs!
CALENDARS='Tj,TJ-Private'

##############################################################################################################
##############################################################################################################

NAME="$0:t:r"

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
else
	PATH="$HOME/scripts:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin"
fi

zmodload zsh/datetime

TIME=$(strftime "%Y-%m-%d--%H.%M.%S" "$EPOCHSECONDS")

function timestamp { strftime "%Y-%m-%d--%H.%M.%S" "$EPOCHSECONDS" }

##############################################################################################################

if ((! $+commands[icalBuddy] ))
then
	echo "$NAME: 'icalBuddy' is required but not found in $PATH" >>/dev/stderr
	exit 1
fi

if ((! $+commands[seconds2readable.sh] ))
then
	echo "$NAME: 'seconds2readable.sh' is required but not found in $PATH" >>/dev/stderr
	exit 1
fi

##############################################################################################################

	## In short, this says: Look for any events which are upcoming today
	## not including All Day Events
	## not including events which are already over
	## and checking only the calendars that we named above
AMPM=$(icalBuddy \
	--includeEventProps title,datetime \
	--excludeAllDayEvents \
	--noPropNames \
	--includeOnlyEventsFromNowOn \
	--noCalendarNames \
	--includeCals "$CALENDARS" \
		eventsToday)

	# icalBuddy uses '• ' as the first characters of any line which has an event title
	# so we can count those and see how many events we have coming up
EVENT_COUNT=$(echo "${AMPM}" | egrep '^• ' | wc -l | tr -dc '[0-2]')

	## if there are NONE then it either means that this script had some kind of silent
	## failure, or it means that you don't have any more meetings scheduled for today.
	## Let's stay positive and assume it's the latter.
if [[ "$EVENT_COUNT" == "0" ]]
then
		## Note that this Keyboard Maestro macro is being called by name,
		## so if you rename it, you should change the next line
	osascript -e 'tell application "Keyboard Maestro Engine" to do script "R3C6 - Set No Meetings"'

		# once we know there are no more meetings, we can exit now and skip the rest
	exit 0
fi

##############################################################################################################
##############################################################################################################
##############################################################################################################
#######
#######			So, if we get here, we know there IS at least one more meeting today
#######


## FIRST QUESTION: Are you currently IN a meeting?

	## is there an event going on right now?
NOW=$(icalBuddy \
        --maxNumNoteChars 0 \
        --excludeAllDayEvents \
        --timeFormat '%H:%M' \
        --includeOnlyEventsFromNowOn \
        --noCalendarNames \
        --includeCals "$CALENDARS" \
                eventsNow)

##############################################################################################################

if [[ "$NOW" == "" ]]
then

		## If we get here
		## then we are NOT currently in a meeting
		## but we know (from above) there is another meeting today
		## so we need to find out when that is

		## we need the info for the NEXT in "military" / 24-hour time to make it easier to parse
		## This will get just the next calendar event
	NEXT=$(icalBuddy \
        --limitItems 1 \
        --includeEventProps title,datetime \
        --excludeAllDayEvents \
        --noPropNames \
        --includeOnlyEventsFromNowOn \
        --noCalendarNames \
        --includeCals "$CALENDARS" \
        --timeFormat '%H:%M' \
			eventsToday )


		## This will give us the HH:MM showing when the next event is going to BEGIN
	NEXT_START_TIME=$(echo "${NEXT}" | tail -1 | awk '{print $1}')

		## This will give us the HH:MM showing when the next event is going to END
	NEXT_END_TIME=$(echo   "${NEXT}" | tail -1 | awk '{print $3}')

		## This will show us how many more events there are
	REMAINING_EVENTS_COUNT=$(echo "${AMPM}" | egrep '^• ' | wc -l | tr -dc '[0-2]')

else
		## If we get here
		## then we ARE in a meeting NOW
		## So the next thing to do is check to see any meetings are schedule for
		## AFTER the END of THIS meeting but before 23:59 (aka 11:59pm)
		##
		## Again, if you schedule overlapping events, this will break.
		## Which is not my fault.

		## This will give us the HH:MM showing when the next event is going to BEGIN
	NOW_START_TIME=$(echo "${NOW}" | tail -1 | awk '{print $1}')

		## This will give us the HH:MM showing when the next event is going to END
	NOW_END_TIME=$(echo   "${NOW}" | tail -1 | awk '{print $3}')

		## these might not be needed, but it won't hurt anything
	NEXT_START_TIME=''
	NEXT_START_TIME_12_HOUR=''

	REMAINING_EVENTS=$(icalBuddy \
		--includeEventProps title,datetime \
		--excludeAllDayEvents \
		--noPropNames \
		--noCalendarNames \
		--includeCals "$CALENDARS" \
		--timeFormat '%H:%M' \
			eventsFrom:"$NOW_END_TIME" to:"23:59")

	REMAINING_EVENTS_COUNT=$(echo "$REMAINING_EVENTS" | egrep '^• ' | wc -l | tr -dc '[0-2]')

	if [[ "$REMAINING_EVENTS_COUNT" == "0" ]]
	then
			## We are currently in our last meeting of the day! Huzzah!
			## Again, if you rename the macro, rename it here too
		osascript -e 'tell application "Keyboard Maestro Engine" to do script "R3C6 - Set No Meetings"'
		exit 0
	fi

		## If we get here,
		## then we are in a meeting
		## and have at least one more coming
	NEXT_START_TIME=$(echo "$REMAINING_EVENTS" | head -2 | tail -1 | awk '{print $3}')
	NEXT_END_TIME=$(echo "$REMAINING_EVENTS"   | head -2 | tail -1 | awk '{print $5}')
fi

##############################################################################################################
##############################################################################################################
##
## OK, so now we know we have a meeting or meetings left
## So now we need to formulate what we will output

	# This will tell us how many meetings we have left.
	# could be "1 Left" or could be "4 Left" etc
COUNT="${REMAINING_EVENTS_COUNT} Left"

	# we need to figure out how many seconds there are between NOW and the start time
	# if the next meeting, so we can do some calculations
	# which are easier to do with seconds than with seconds AND minutes AND hours

	## since we are only interested in events that are happening today
	## we need today's date
TODAYS_DATE=$(strftime "%Y-%m-%d" "$EPOCHSECONDS")

	## this line will show up the Unix Epoch Seconds for the start time
	## of the next event. Don't worry if you don't know what that means
NEXT_START_TIME_SECONDS=$(strftime -r "%Y-%m-%d %H:%M" "${TODAYS_DATE} ${NEXT_START_TIME}")

	## All you need to know is that we can use THAT number of seconds
	## and subtract it from the CURRENT number of seconds '$EPOCHSECONDS'
	## and figure out how long it is until our next meeting
DIFF=$(($NEXT_START_TIME_SECONDS - $EPOCHSECONDS))

	## Converting seconds into hours and minutes is tedious and I don't like doing it
	## over and over again, so I have a script called `seconds2readable.sh` which will
	## take a given number of seconds and change it into hours/minutes/seconds. For example
	## `seconds2readable.sh 744` will give the result: "12 minutes 24 seconds"
	## and `seconds2readable.sh 3794` will give "1 hour 3 minutes 14 seconds"
	##
	## Now, for the Stream Deck display, we only have a few characters to work with,
	## so we are going to use, for example: '5h' instead of '5 hours' and '3m' instead of '3 minutes'
	##
	## We are going to ignore seconds altogether
	##
	## Again, since we are only dealing with events within the span of one day
	## we don't need to worry about any timeframe greater than hours
	##
	## This command will show the hour and minute, but if the hour is '0h'
	## then we will remove that because it's superfluous and distracting
DIFF_READABLE=$(seconds2readable.sh -a "$DIFF" | awk '{print $3"h "$5"m"}'  | sed 's#^0h ##g')

	## I know 24-hour time is more logical, but I still prefer a 12-hour clock
	## because that's how I think
	##
	## So, we are going to split the Hour and Minute of the starting time of the next event
	## into two components
	##
NEXT_START_HOUR=$(echo "$NEXT_START_TIME" | sed 's#:.*##g')
NEXT_START_MINUTE=$(echo "$NEXT_START_TIME" | sed 's#.*:##g')

	## now we can check to see if the hour is GREATER than 12
	## and if it is, we just subtract 12 from it
if [[ "$NEXT_START_HOUR" -gt "12" ]]
then
	AM_OR_PM='PM'
	NEXT_START_HOUR=$(($NEXT_START_HOUR - 12))
elif [[ "$NEXT_START_HOUR" == "12" ]]
then
		## if the hour is exactly 12, it's still PM
		## but we don't want to subtract 12 from it
	AM_OR_PM='PM'
else
		## if we get here it must have been less than 12, so it's 'AM'
	AM_OR_PM='AM'
fi


##############################################################################################################
##############################################################################################################
##
##		Here is where the magic happens!
##
##		(Disclaimer: contains no magic)
##
##		However, this is where we actually 'echo' the output
##		which Keyboard Maestro will use as the text of the button
##		on the Stream Deck.
##
## 		Technically get more than 3 lines to display, but I think it looks better
##		if you don't cram too much into the tiny button display
##		so I use 3 lines, and try not to put too much on each line
##
##		The first line shows how many meetings are left in the day.
##		Could be '1 Left' could be '3 Left" etc
##
##		The second line shows the start time of the next meeting
##		which could be "9:00 AM" or "12:30 PM" etc
##
##		The last line will show the time remaining (hours and minutes)
##		until the next next meeting.
##		For example, if the current time was 9:40 a.m. and you had a meeting
##		at 11:00 a.m. it would say "1h 20m"
##
##		In the Stream Deck app on your Mac, be sure that "SHOW TITLE" is
##		checked for the button you are using, and make sure that it is
##		centered as well. (See screenshot at Github repo)

echo "${COUNT}
${NEXT_START_HOUR}:${NEXT_START_MINUTE} ${AM_OR_PM}
${DIFF_READABLE}"


##############################################################################################################
##############################################################################################################
##
##		BUT WAIT! There's more!
##
##		Stream Deck buttons have a black background by default, which is good.
##		However, you CAN change the color of the background, which is helpful.
##		I use this to change the color of the button as my next meeting gets closer.
##
##		More specifically: when my next meeting is 30 minutes or less from NOW then
##		I set the button to a nice blue color. This is a gentle way to tell myself
##		"Hey! Reminder! You have a meeting coming up!"
##
##		When it gets to 15 minuts or less, the button turns yellow. Because by now
##		I should be getting ready. If we're meeting on Zoom (and we probably are)
##		I need to make sure that I'm set up for that.
##
##		When it gets to 10 minutes or less, the button goes to orange. That's a
##		step up from yellow, but not quite red, and says "No, seriously, stop
##		what you're doing and get ready.
##
##		When it gets to 5 minutes or less, now the button goes RED as in RED ALERT
##		(You can imagine the Star Trek klaxon sounding. Or you could
##		grab this clip from YouTube https://www.youtube.com/watch?v=Hi1GVeIzo4Q
##		and make Keyboard Maestro play the sound if you want.
##		NOTE: Do not do this if you live / work with others who will hear it
##		I will not be held responsible for your divorce and/or murder if you do.
##
##		You can adjust the times when you want the colors to change by changing
##		the values below. You can change which colors go with which times
##		by moving the 'osascript' lines around if you want.
##
##		The GitHub repo already includes my macros which include the appropriate colors.
##
##		Note that my 'Set Color Red' macro also tells the Stream Deck to show an alert badge
##		momentarily.
##
##		If you want to adjust the times below, just remember that you are entering values
##		in seconds. So if you want 5 minutes, you enter '300' (5 * 60)
##
##		You'll notice that these times are a minute more than you'd usually expect
##		That's because there's some 'inexactness' which comes from the fact that
##		although Keyboard Maestro is running this every minute, there's going to be
##		some number of seconds more than whatever the "minute" count is that we show
##		so I've added an extra minute here because I'd rather err on the side of early.
##
##		31 minutes = 1860
##		16 minutes =  960
##		11 minutes =  660
##		 6 minutes =  360

  if [[ "$DIFF" -le "360" ]]
then
	osascript -e 'tell application "Keyboard Maestro Engine" to do script "R3C6 - Set Color Red"'

elif [[ "$DIFF" -le "660" ]]
then

	osascript -e 'tell application "Keyboard Maestro Engine" to do script "R3C6 - Set Color Orange"'

elif [[ "$DIFF" -le "960" ]]
then

	osascript -e 'tell application "Keyboard Maestro Engine" to do script "R3C6 - Set Color Yellow"'

elif [[ "$DIFF" -le "1860" ]]
then

	osascript -e 'tell application "Keyboard Maestro Engine" to do script "R3C6 - Set Color Blue"'

else

	osascript -e 'tell application "Keyboard Maestro Engine" to do script "R3C6 - Set Color Black"'
fi

## WE MADE IT! Congrats on making it all the way to the bottom. You rock.

exit 0
#EOF
