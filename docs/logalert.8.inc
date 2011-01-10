[CONFIGURATION FILE]
Runtime configuration can be customized through a configuration file.
The default configuration file path is /etc/logalert/logalert.conf.
This path can be changed using the \fB\-c\fR or \fB\-C\fR command line options.
.SS "Variables: (command line override) [default value]"
.TP
CONFDIR
Directory containing configuration files (\fB\-C\fR) [/etc/logalert]
.TP
STATEDIR
Directory where scan information is retained (\fB\-S\fR) [/var/logalert]
.TP
LOGGROUPDIR
Directory containing log groups to scan (\fB\-r\fR) [$CONFDIR/logs.d]
.TP
SUBJECTHOSTNAME
Hostname to use in the subject of email messages (\fB\-H\fR) [$(hostname)]
.TP
SUBJECTPREPEND
Text to prepend to subject of email messages (\fB\-e\fR) []
.TP
SUBJECTAPPEND
Text to append to subject of email messages (\fB\-E\fR) []
.TP
SYSADMINFROM
Email address of the sender of email messages [$(id)@$(hostname)]
.TP
SYSADMINTO
Email address of the recipient of email messages (\fB\-m\fR) [$(id)@$(hostname)]
.TP
FORMATAWKPATH
Path to default Awk script used to format logs as HTML (\fB\-f\fR) [$CONFDIR/default.format.awk]
.TP
RULESAWKPATH
Path to default Awk script used to process rules [$CONFDIR/default.rules.awk]
.TP
STYLESPATH
Path to default <style> definitions included in email messages (\fB\-s\fR) [$CONFDIR/default.format.styles]
.TP
INTROPATH
Path to HTML file to insert into body before log activity [$CONFDIR/intro.html]
.TP
FOOTERPATH
Path to HTML file to insert into body after log activity [$CONFDIR/footer.html]
.TP
LOGTAILCMD
Command used to monitor log activity [logtail2]
.TP
GREPCMD
Command used to grep ignore and alert patterns [egrep]
.TP
MAILCMD
Command used to send mail [sendmail \-ti]
.TP
AWKCMD
Command used to run Awk [awk \-\-re\-interval \-f]
.TP
FORMATCMD
Command used to format log messages as HTML [$AWKCMD]

[SEE ALSO]
More documentation may be found at <https://github.com/lovette/logalert/wiki>
