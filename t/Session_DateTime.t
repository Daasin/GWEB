#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2006 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------
 
# ---- BEGIN DO NOT EDIT ----
use strict;
use lib '../lib';
use Getopt::Long;
use WebGUI::Session;
# ---- END DO NOT EDIT ----
use Test::More tests => 22; # increment this value for each test you create
 
my $session = initialize();  # this line is required

my $wgbday = 997966800;
ok($session->datetime->addToDate($wgbday,1,2,3) >= $wgbday+1*60*60*24*365+2*60*60*24*28+3*60*60*24, "addToDate()"); 
ok($session->datetime->addToTime($wgbday,1,2,3) >= $wgbday+1*60*60+2*60+3, "addToTime()"); 
my ($start, $end) = $session->datetime->dayStartEnd($wgbday);
ok($end-$start >= 60*60*23, "dayStartEnd()"); 
is($session->datetime->epochToHuman($wgbday,"%%%c%d%h"), "%August1608", "epochToHuman()"); 
is($session->datetime->epochToSet($wgbday,1), "2001-08-16 08:00:00", "epochToSet()");
is($session->datetime->getDayName(7), "Sunday", "getDayName()");
is($session->datetime->getDaysInMonth($wgbday), 31, "getDaysInMonth()");
is($session->datetime->getDaysInInterval($wgbday,$wgbday+3*60*60*24), 3, "getDaysInInterval()");
is($session->datetime->getFirstDayInMonthPosition($wgbday), 3, "getFirstDayInMonthPosition()");
is($session->datetime->getMonthName(1), "January", "getMonthName()");
is($session->datetime->getSecondsFromEpoch($wgbday), 60*60*8, "getSecondsFromEpoch()");
SKIP: {
	skip("getTimeZones() - not sure how to test",1);
	ok($session->datetime->getTimeZones(),"getTimeZones()");
    }
is($session->datetime->humanToEpoch("2001-08-16 08:00:00"), $wgbday, "humanToEpoch()");
is($session->datetime->intervalToSeconds(2,"weeks"),60*60*24*14, "intervalToSeconds()");
is(join("-",$session->datetime->localtime($wgbday)),'2001-8-16-8-0-0-228-4-1', "localtime()");
is($session->datetime->monthCount($wgbday,$wgbday+60*60*24*365), 12, "monthCount()");
my ($start, $end) = $session->datetime->monthStartEnd($wgbday);
ok($end-$start >= 60*60*24*28, "monthStartEnd()"); 
is(join(" ",$session->datetime->secondsToInterval(60*60*24*365*2)),"2 years", "secondsToInterval()");
is($session->datetime->secondsToTime(60*60*8),"08:00:00", "secondsToTime()");
is($session->datetime->setToEpoch("2001-08-16 08:00:00"), $wgbday, "setToEpoch()");
ok($session->datetime->time() > $wgbday,"time()");
is($session->datetime->timeToSeconds("08:00:00"), 60*60*8, "timeToSeconds()");
 
cleanup($session); # this line is required
 
# ---- DO NOT EDIT BELOW THIS LINE -----
sub initialize {
        $|=1; # disable output buffering
        my $configFile;
        GetOptions(
                'configFile=s'=>\$configFile
        );
        exit 1 unless ($configFile);
        my $session = WebGUI::Session->open("..",$configFile);
}
sub cleanup {
        my $session = shift;
        $session->close();
}
