# Copyright (c) 2011 Lance Lovette. All rights reserved.
# Licensed under the BSD License.
# See the file LICENSE.txt for the full license text.
#
# This awk script is used to process rules

BEGIN {
	regexprefix = ""
}

# For each line
{
	if (match($0, "^#|^[[:space:]]*$"))
	{
		# Skip comments and blank lines
	}
	else if (match($0, "^\\[logalert:regex:prefix=(.+)\\]$", parts))
	{
		# regex:prefix pattern is prepended to following patterns
		regexprefix = parts[1]
	}
	else
	{
		print regexprefix $0
	}
}
