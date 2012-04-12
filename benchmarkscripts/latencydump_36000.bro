type Idx: record {
	i: int;
};

type Sval: record {
	t: time;
};

#@load frameworks/communication/listen

redef pkt_profile_file = open_log_file("pkt-prof");
redef pkt_profile_mode = PKT_PROFILE_MODE_SECS;
redef pkt_profile_freq = 1.0;


## Configuration option: factor with which the current lines-per-second rate is multiplied each hartbeat interval
## default: 1 -> to not grow.
#redef InputBenchmark::factor = 1.3;

## Configuration option: factor which is added to the current lines-per-second rate each heartbeat interfal
## default 0 -> don't add anything
#redef InputBenchmark::addfactor = 2000;

## Configuration option: usleep interval that is inserted between each line. Can be used to spread out the events over the heartbeat interval.
## User must take care to keep this small enough that all lines are queued within heartbeat-interval, otherwise heartbeats will start queueing up.
## default: 0 -> disabled. Must be < 1000000 ( 1 sec ), otherwise implementations might ignore it.
#redef InputBenchmark::spread = 1;

## Configuration option: same as spread, but dymanic.
## Auutospread sets the spreading interval based on the current number of lines per second:
## usleep ( 1000000 / autospread * num_lines )
## default: 0.0 -> disabled.
#redef InputBenchmark::autospread = 2.5;

## Configuration option: stop spreading beginning at x lines.
## necessary, because at some time even tiny usleeps make the sender too slow.
## but - not nice...
## defaultL 0 -> disabled
#redef InputBenchmark::stopspreadat = 200000;
# 200000, because with in my purely trial and error simulations beginning with 200000 spreading fact

## Configuration option: timed spreads
## default: 0 -> disabled. Everything else - percentage of heartbeat interval that should not be used to send stuff.
## so -> 0.15 means that all data will be send in the first 85% of heartbeat_interval.
redef InputBenchmark::timedspread = 0.05;

redef Threading::heart_beat_interval = 5 secs;


global outfile: file;
global changes: file;

global lastheartbeat: time;
global currentlines: count;

global skiplines: count;
global firstbeat: bool;

event line(description: Input::EventDescription, tpe: Input::Event, t: time) {
	skiplines = skiplines + 1;

	if ( skiplines != 100 ) {
		return;
	}

	local ti = current_time();
	local difference = ti - t;
	print outfile,(fmt("%f %d %f", current_time(), currentlines, difference));
	skiplines = 0;

}

event bro_init()
{
	outfile = open ("timings.log");
	changes = open ("changes.log");
	# first read in the old stuff into the table...
## Configuration option:
## $source specifies the initial number of lines per minute that are generated by the 
	Input::add_event([$source="36000", $name="input", $fields=Sval, $ev=line, $reader=Input::READER_BENCHMARK, $mode=Input::STREAM]);
	currentlines = 10;
	print outfile, "ts lines difference";
	print changes, "difference currts";

	lastheartbeat = current_time();
	skiplines = 0;
	firstbeat = T;
}


## event is raised every time, an heartbeat is completed by the benchmark reader.
event HeartbeatDone() {
	local difference = (current_time() - lastheartbeat);
	print fmt("last heartbeat Current time: %f, time since last heartbeat %f", current_time(), difference);
	print changes, fmt("%f %f", difference, current_time());

	firstbeat = F;
	lastheartbeat = current_time();
}

## this event is raised if InputBenchmark::factor is != 1.0 each time the number of lines per seconds is changed.
event lines_changed(newlines: count, changetime: time) {
	print fmt("Rate changed to %d lines per second at %f", newlines, changetime);
	print changes, fmt("%f %f %d", changetime, current_time(), newlines);
	
	currentlines = newlines;
}

