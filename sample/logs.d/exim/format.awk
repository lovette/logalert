# Escape unsafe characters
function htmlsafe(s)
{
	gsub("&", "\\&amp;", s);
	gsub("<", "\\&lt;", s);
	gsub(">", "\\&gt;", s);
	gsub("\"", "\\&quot;", s);
	return s
}

# Convert spaces to nonbreak space entity
function nowrap(s)
{
	gsub(" ", "\\&nbsp;", s);
	return s;
}

BEGIN {
# Regex below are case-insensitive
IGNORECASE = 1

regdate  = "([-0-9]{10})"                          # MM-DD-YYYY
regtime  = "([0-9:]{8})"                           # HH:MM:SS
regmsgid = "([a-z0-9]{6}-[a-z0-9]{6}-[a-z0-9]{2})" # alnum-alnum-alnum
regmsg   = "[ \t]*(.*)"                            # Message

reglogmsg   = "^" regdate " " regtime " " regmsgid " " regmsg "$"
reglognomsg = "^" regdate " " regtime " " regmsg "$"

lastdate = ""
lasttime = ""
lastmsgid = ""

h1style="\"padding:3pt; font-weight:bold; background-color:#cccccc; margin:0px\""

print "<table width=\"100%\">"

# Set default attributes for our three columns
print "<colgroup>"
print "<col width=\"1\">"
print "<col width=\"1\">"
print "<col>"
print "</colgroup>"
}

# For each line
{
date = ""
time = ""
msgid = ""
message = ""

# Extract the parts of each message that we want to output
if (match($0, reglogmsg, parts))
{
	# Message related
	date = parts[1]
	time = parts[2]
	msgid = parts[3]
	message = parts[4]
}
else if (match($0, reglognomsg, parts))
{
	# No message id
	date = parts[1]
	time = parts[2]
	msgid = "-"
	message = parts[3]
}
else if (match($0, /^[ \t]+(.*)/, parts))
{
	# multiline message
	date = lastdate
	time = lasttime
	msgid = lastmsgid
	message = parts[1]
}
else
{
	# unknown format
	message = $0
}

# Output a table row for each log message
if (message != "")
{
	if (date == "")
	{
		# Unknown message format
		print "<tr>"
		print "<td colspan=\"3\">" htmlsafe(message) "</td>"
		print "</tr>"
	}
	else if (date != lastdate || time != lasttime || msgid != lastmsgid)
	{
		# Print header line for each new date
		if (date != lastdate)
		{
			print "<tr>"
			print "<td colspan=\"3\" style=" h1style ">" date "</td>"
			print "</tr>"
		}

		print "<tr>"
		print "<td nowrap>" time "</td>"
		print "<td nowrap>" nowrap(msgid) "</td>"
		print "<td>" htmlsafe(message) "</td>"
		print "</tr>"
	}
	else
	{
		# Same date/time/msgid as previous message
		print "<tr>"
		print "<td>&nbsp;</td>"
		print "<td>...</td>"
		print "<td>" htmlsafe(message) "</td>"
		print "</tr>"
	}
}

lastdate = date
lasttime = time
lastmsgid = msgid
}

END {
print "</table>"
}
