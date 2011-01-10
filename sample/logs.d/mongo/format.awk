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

regdate = "([a-z]{3} [a-z]{3} [0-9]{1,2})" # DDD MMM DD
regtime = "([0-9:]{8})"                    # HH:MM:SS
regmsg = "[ \t]*(.*)"                      # Message

reglog = "^" regdate " " regtime " " regmsg "$"

lastdate = ""
lasttime = ""

h1style="\"padding:3pt; font-weight:bold; background-color:#cccccc; margin:0px\""

print "<table width=\"100%\">"

# Set default attributes for our three columns
print "<colgroup>"
print "<col width=\"1\">"
print "<col>"
print "</colgroup>"
}

# For each line
{
date = ""
time = ""
message = ""

# Extract the parts of each message that we want to output
if (match($0, reglog, parts))
{
	date = parts[1]
	time = parts[2]
	message = parts[3]
}
else if (match($0, /^[* \t]+(.*)/, parts))
{
	# multiline message
	date = lastdate
	time = lasttime
	message = parts[1]
}
else if ($0 == "")
{
	# blank line
	date = lastdate
	time = lasttime
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
		print "<td colspan=\"2\">" htmlsafe(message) "</td>"
		print "</tr>"
	}
	else if (date != lastdate || time != lasttime)
	{
		# Print header line for each new date
		if (date != lastdate)
		{
			print "<tr>"
			print "<td colspan=\"2\" style=" h1style ">" date "</td>"
			print "</tr>"
		}

		print "<tr>"
		print "<td nowrap>" time "</td>"
		print "<td>" htmlsafe(message) "</td>"
		print "</tr>"
	}
	else
	{
		# Same date/time as previous message
		print "<tr>"
		print "<td>&nbsp;</td>"
		print "<td>" htmlsafe(message) "</td>"
		print "</tr>"
	}
}

lastdate = date
lasttime = time
}

END {
print "</table>"
}
