#!/usr/bin/perl -w
use strict;

# This program is a quick hack to give dynamic DNS functionality
# for non-static hosts.  
#

# Variables to set
my $NAMESERVER1="lenyap.ifost.org.au";
my $NAMESERVER2="forest.ifost.org.au";
my $NAMESERVER_TARGET_FILE="/var/named/namedb/southbank.db";
my $NAMESERVER_LOGIN_USERNAME="southbank";
my $MY_HOSTNAME="southbank.coronation.ecsdwn.com.au";
my $DOMAINNAME="southbank.ecsdwn.com.au";
my $MY_SHORT_HOSTNAME="southbank";

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = gmtime();
my $date = sprintf("%2d%2d%2d",$year+1900,$mon+1,$mday+1);

# This program should print this end of the ADSL link's IP address
my $IP_ADDRESS_TOOL="lynx -source http://lenyap.ifost.org.au/cgi-bin/your-ip";

print "Get current\n";
my $CURRENT_IP=qx"$IP_ADDRESS_TOOL";
chomp($CURRENT_IP);
print "Get DNS\n";
my $RECORDED_IP1=`host -t a $MY_HOSTNAME $NAMESERVER1 | grep 'has address' | sed 's/.*has address //' `;
chomp($RECORDED_IP1);
my $RECORDED_IP2=`host -t a $MY_HOSTNAME $NAMESERVER2 | grep 'has address' | sed 's/.*has address //' `;
chomp($RECORDED_IP2);
print "Compare $CURRENT_IP vs $RECORDED_IP1 vs $RECORDED_IP2\n";


if ( $CURRENT_IP eq $RECORDED_IP1 and  $CURRENT_IP eq $RECORDED_IP2 ) {
  # system("logger -i -p local3.info -t adsldns 'IP still the same'");
  exit(0);
}


my $NAMEDB_TEMPLATE_FILE=qq{
\@ IN SOA $DOMAINNAME.       gregb.ifost.org.au. (
   $date ; serial
   1000 ; refresh
   1000 ; retry
   3600 ; expire
   300 ; default_ttl
)
                IN      NS      lenyap.ifost.org.au.
                IN      NS      forest.ifost.org.au.
                IN      MX      10      $MY_HOSTNAME
$MY_SHORT_HOSTNAME IN      A       $CURRENT_IP
$MY_SHORT_HOSTNAME IN      MX      10 coronation
www             IN      A       $CURRENT_IP
www             IN      MX      10 coronation
};

my $temp_file = "/tmp/adsldns.$$";
open(TEMP_FILE,">$temp_file") || die "Can't write to $temp_file";
print TEMP_FILE $NAMEDB_TEMPLATE_FILE;
close(TEMP_FILE);

if ($CURRENT_IP ne $RECORDED_IP1 ) {
  print "Copying to $NAMESERVER1\n";
  system("scp -q $temp_file $NAMESERVER_LOGIN_USERNAME\@$NAMESERVER1:$NAMESERVER_TARGET_FILE");
# reload named
  system("ssh -l $NAMESERVER_LOGIN_USERNAME $NAMESERVER1 sudo /usr/sbin/named.reload");
}


if ($CURRENT_IP ne $RECORDED_IP2 ) {
  print "Copying to $NAMESERVER2\n";
  system("scp -q $temp_file $NAMESERVER_LOGIN_USERNAME\@$NAMESERVER2:$NAMESERVER_TARGET_FILE");
# reload named
  system("ssh -l $NAMESERVER_LOGIN_USERNAME $NAMESERVER2 sudo /usr/sbin/named.reload");
}


unlink($temp_file);

system("logger -i -p local3.info -t adsldns '(cron job) Set new IP of $CURRENT_IP'");







