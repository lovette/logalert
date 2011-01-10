# Logalert

Scans log files and sends unexpected activity and alerts to a sysadmin via email.

If you're familiar with log monitoring tools such as [Logcheck](http://logcheck.org/)
then you already know what Logalert does. The premise of these tools is simple.
In short, you have Cron run the tool periodically and it will email
unusual/unexpected log activity to a sysadmin. Log entries that should be
considered unusual activity are defined by regular expressions (or the lack thereof).


Features
---
* Log activity emails are formatted in HTML
* Logs are scanned using only two sets of regular expressions - 
  ignore patterns and alert patterns
* Logs are scanned for alerts after ignore patterns are filtered
* Log files with common rule sets are grouped together by directory (and called a log group)
* Email is sent per log group, separate emails are sent for alerts
  and unusual activity
* Log activity is formatted as HTML with awk for easy customization
* Rules files are processed with awk to allow for user defined tag extensions
* Can use the same regular expressions as Logcheck for ignore and alert patterns


Requirements
---

* [BASH 2.05 or later](http://www.gnu.org/software/bash/)
* [Awk 3.0 or later](http://www.gnu.org/software/gawk/)
* A log tail tool such as those in the [Logcheck](http://logcheck.org/) package;
  the default configuration references logtail2 which is a Perl script


Installation
---
Download the archive and extract into a folder. Then, to install the package:

	make install

This installs scripts to `/usr/sbin`, configuration files to `/etc/logalert` and
man pages to `/usr/share/man`. You can also stage the installation with:

	make DESTDIR=/stage/path install

You can undo the install with:

	make uninstall

A script is provided to configure Cron to run logalert at boot time and every 5 minutes:

	cp sample/logalert.cron /etc/cron.d/logalert


### Installing logtail2 from Logcheck package

The easiest way to get a log tail tool is to download and install the 
[Logcheck](http://logcheck.org/) package. If you want to only install logtail2 itself,
download the tarball and add a "logtail" target to the Makefile.
	
	cat sample/logtail.makefile.target >> /path/to/logcheck/source/Makefile
	cd /path/to/logcheck/source
	make logtail


Usage
---

	logalert [OPTION]...

Run the command with `--help` argument or view the logalert(8) man page to see available OPTIONS.


Getting Started
---

The only configuration necessary is to create at least one log group directory (see next
section). Runtime configuration can be customized through a configuration file
and command line options. Configuration file variables are listed in a following section.


Log Groups
---
The rules defining each group of log files to scan are saved in a directory.
Each directory is called a log group. By default, these log group directories should be 
subdirectories of `/etc/logalert/logs.d/`. Each log group directory contains a set of 
files which define the log files to scan for the group, what log activity is to be 
ignored or trigger alerts, and how log activity is formatted as HTML.

* `*.logfiles` - These files contain full paths of log files to scan. Log activity
  for all log files listed is combined and scanned together. Results are sent in a
  single email per group. <i>This is the only file required for scanning logs.</i>
* `*.ignore` - These files contain regular expressions of log activity to ignore. 
  All .ignore patterns apply to all log files in the group. If no .ignore files
  exist, all log activity will be emailed. Patterns here should be as specific
  as possible!
* `*.alert` - These files contain regular expressions of log activity that should
  trigger an ALERT email. All .alert patterns apply to all log files in the group. 
  Patterns listed in .ignore files will not trigger alerts.
* `format.awk` - Log activity is converted to HTML by awk. Since log formats
  vary greatly (especially the date format) it is common for log groups to override 
  the default format script. The default format script is `default.format.awk` 
  in the conf directory.
* `format.styles` - HTML content created by `format.awk` can reference custom HTML styles. 
  In this case you need to override the default styles.
  The default styles are defined in `default.format.styles` in the conf directory. 
  Note that some mail readers prefer inline styles (and Gmail requires it).
* `rules.awk` - The log rules files .logfiles, .ignore and .alert can contain special tags
  (see below). Each log group can override the default to customize the rules language.
  The default rules processing script is `default.rules.awk` in the conf directory. 

A few sample log groups are in `sample/logs.d/`.


Special rules file tags
---
The log rules files .logfiles, .ignore and .alert can contain special tags.
You can create your own tags by customizing `default.rules.awk` or creating
`rules.awk` within a specific log group.

* `[logalert:regex:prefix=STRING]` - STRING is prepended to each line following in the file,
  or until the next prefix is defined.


Configuration file
---
Runtime configuration can be customized through a configuration file.
The default configuration file path is `/etc/logalert/logalert.conf..
This path can be changed using the `-c` or `-C` command line options.
The file is a simple script that assigns a value to each configuration variable.
All variables are optional. Available variables with (command line override) and [default value]:

* CONFDIR - Directory containing configuration files (-C) [/etc/logalert]
* STATEDIR - Directory where scan information is retained (-S) [/var/logalert]
* LOGGROUPDIR - Directory containing log groups to scan (-r) [$CONFDIR/logs.d]
* SUBJECTHOSTNAME - Hostname to use in the subject of email messages (-H) [$(hostname)]
* SUBJECTPREPEND - Text to prepend to subject of email messages (-e) []
* SUBJECTAPPEND - Text to append to subject of email messages (-E) []
* SYSADMINFROM - Email address of the sender of email messages [$(id)@$(hostname)]
* SYSADMINTO - Email address of the recipient of email messages (-m) [$(id)@$(hostname)]
* FORMATAWKPATH - Path to default Awk script used to format logs as HTML (-f) [$CONFDIR/default.format.awk]
* RULESAWKPATH - Path to default Awk script used to process rules [$CONFDIR/default.rules.awk]
* STYLESPATH - Path to default < style > definitions included in email messages (-s) [$CONFDIR/default.format.styles]
* INTROPATH - Path to HTML file to insert into body before log activity [$CONFDIR/intro.html]
* FOOTERPATH - Path to HTML file to insert into body after log activity [$CONFDIR/footer.html]
* LOGTAILCMD - Command used to monitor log activity [logtail2]
* GREPCMD - Command used to grep ignore and alert patterns [egrep]
* MAILCMD - Command used to send mail [sendmail -ti]
* AWKCMD - Command used to run Awk [awk --re-interval -f]
* FORMATCMD - Command used to format log messages as HTML [$AWKCMD]

A sample configuration file is `sample/logalert.conf`.
