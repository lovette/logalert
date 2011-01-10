# This awk script is used to format logs as an HTML <table>
#
# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# Available from https://github.com/lovette/logalert

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

regdate = "([a-z]{3}[ ]+[0-9]{1,2})" # MMM DD
regtime = "([0-9:]{8})"              # HH:MM:SS
reghost = "([-_a-z0-9]+)"            # Hostname
regsvc  = "([^:\\[]+)"               # Service
regpid  = "\\[([0-9]+)\\]"           # [PID]
regmsg  = "[ \t]*(.*)"               # Message

reglogfull  = "^" regdate " " regtime " " reghost " " regsvc regpid ":" regmsg "$"
reglognopid = "^" regdate " " regtime " " reghost " " regsvc ":" regmsg "$"
reglognosvc = "^" regdate " " regtime " " reghost " " regmsg "$"

lastdate = ""
lasttime = ""
lastservice = ""

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
service = ""
message = ""

# Extract the parts of each message that we want to output
if (match($0, reglogfull, parts))
{
	date = parts[1]
	time = parts[2]
	service = parts[4]
	message = parts[6]
}
else if (match($0, reglognopid, parts))
{
	date = parts[1]
	time = parts[2]
	service = parts[4]
	message = parts[5]
}
else if (match($0, reglognosvc, parts))
{
	date = parts[1]
	time = parts[2]
	service = "-"
	message = parts[4]
}
else if (match($0, /^[ \t]+(.*)/, parts))
{
	# multiline message
	date = lastdate
	time = lasttime
	service = lastservice
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
	else if (date != lastdate || time != lasttime || service != lastservice)
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
		print "<td nowrap>" nowrap(service) "</td>"
		print "<td>" htmlsafe(message) "</td>"
		print "</tr>"
	}
	else
	{
		# Same date/time/service as previous message
		print "<tr>"
		print "<td>&nbsp;</td>"
		print "<td>...</td>"
		print "<td>" htmlsafe(message) "</td>"
		print "</tr>"
	}
}

lastdate = date
lasttime = time
lastservice = service
}

END {
print "</table>"
}
