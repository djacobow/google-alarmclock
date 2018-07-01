
# What is this

This code implements a RaspberryPi-based alarm clock. The code does a couple of 
things:

 * gets events from Google Calendar. It looks for the keyword "wakeup" in the google event
 * Displays the time and upcoming events for the day on an HD44780 display connected via i2c and an MCP23008
 * pulses a GPIO which can be connected by a driver circuit to operate a solenoid/hammer to ring a chime

This code is old and uses old perl modules, and the whole thing really should be 
converted to Python for readability's sake, but it has been running well for me 
for nearly a decade so far. The only changes I've had to make in years are to match
changes in Google APIs.

My clock is based on an original RPi v1, with the small GPIO header. But it 
should run on newer boards, too.

I'm not sure I'd recommend that anybody adopt or use this old code. It's mainly
here for me for when my SD card inevitably fails, and I need to fix my clock.

## Getting this things running

Getting this runnning on an RPi takes a bit of doing.

### Configure raspbian

I use Raspbian "Stretch" and the "Raspbian-lite" version installed from NOOBS.

Use ```raspi-config``` to:
     * turn on ssh if you do not like having to plug your keyboard and monitor into the Pi
     * set a password
     * set the keyboard / timezone yadda
     * enable the i2c port


### Get a bunch of stuff from apt

First, install a bunch of modules, mostly Perl libraries:

```
sudo apt install \
libdatetime-perl \
libnet-address-ip-local  \
libnet-address-ip-local-perl  \
libdatetime-format-rfc3339-perl  \
libwww-perl \
libnet-google-authsub-perl  \
libxml-atom-perl  \
liblocal-lib-perl  \
cpanminus \
libdata-ical-perl  \
libinline-perl \
libncurses-dev \
install wiringpi \
git 
```

### Get a bit more stuff from cpan

There are a handful of Perl libraries tha are not available in the RPi apt repos, so
you'll need to install those using cpan or cpanm. I like cpanm. I disable the 
tests because they take forEVer on the RPi1 and I'm pretty sure they work.

```
cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
cpanm -n Net::Google::Calendar
cpanm -n Google::API::Client
```

If everything is ready to go, you should be able to check with `perl -c clock.pl` to see if all the modules are found. If you get errors, then find the modules one way or another, rinse, repeat. I prefer to use the apt modules if I can find them, otherwise, build from cpan.

Note that I am configuring and installing local::lib, which means that to run the 
program you will need appropriate environment variables set to point to /home/pi/perl5. The example systemd unit file `aclock.service` has them. Alternatively, you can run cpanm as sudo and install modules globally.

### Build and install lcdproc

The code talks to an HD44780 4x20 display driven by an i2c controller (MCP23008).
lcdproc is a nice library for doing this, but it requires a background daemon.

You can get lcdproc here: http://lcdproc.omnipotent.net/

It's pretty easy to build, with one catch -- if you are using my LCD module with the MCDP23008, you will need to apply a patch to the file ./server/drivers/hd44780-i2c.c. The patch is included in this git repo.

```
patch hd44780-i2c.c hd44780-i2c-back-patch.txt
```

Once you've done that:

```
./configure --enable-drivers=curses,hd44780
make
make install
```

Finally, the ```LCDd.conf``` supplied in the package isn't so good for my 
display. You can use the one in this repo.


### Install the service files and start the services

sudo cp aclock.service /etc/systemd/system
sudo cp lcdd.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable lcdd.service
sudo systemctl enable aclock.service
sudo systemctl start  lcdd.service
sudo systemctl start  aclock.service

That *should* be everything you need!

## Hardware hookup

The i2c signals are on the standard i2c pins on the RPi GPIO.

The other GPIOs used (for dinging, snooze, and snooze led) are specified in 
dinger.pm.


