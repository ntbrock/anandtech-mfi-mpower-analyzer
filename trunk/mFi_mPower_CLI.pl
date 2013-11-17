#!/usr/bin/perl
use warnings ;
use strict ;

use Getopt::Long ;
use Carp::Assert ;
use Net::SSH::Perl ;

use Term::ReadKey ;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
                  clock_gettime clock_getres clock_nanosleep clock
                  stat );
my $Debug = '';
my $DevIP ;
my $UserName ;
my $Password ;

# ReadMode ('cbreak') ;
# while (1) {
#   
#   	my $Tmp1 = [gettimeofday] ;
#    my $Tmp3 ;
#   	my $Tmp2 = ReadKey(-1) ;
#   	do {
#    	$Tmp3 = [gettimeofday] ;
#    	$Tmp3 = tv_interval($Tmp1,$Tmp3) ;
#    	printf "\nCurrently elapsed time interval : $Tmp3" ;
#    	sleep 1 ;
#    } while ($Tmp3 < 10) ;
#   	if (!(defined $Tmp2)) {
#   		print "Got nothin in last 10s\n" ;
#   	} else {
#   		print "Got : $Tmp2 : in the last 10s\n" ;
#   		exit(0) ;
#   	}
#   
# }


my $OptionRetVal = GetOptions (	'debug' => \$Debug, 'ip=s' => \$DevIP, 'un=s' => \$UserName, 'pw=s' => \$Password );

assert ((defined $DevIP), "mPower Unit IP Not Specified (Use -ip=xxx.xxx.xxx.xxx)") ;
assert ((defined $UserName), "Username for mPower Not Specified (Use -un=username)") ;
assert ((defined $Password), "Password for mPower Not Specified (Use -pw=password)") ;

my $mFiHostSSH = Net::SSH::Perl->new($DevIP);
$mFiHostSSH->login($UserName, $Password) || die "\nUnable to SSH into $DevIP\n" ;

my ($cmdout, $cmderr, $Enabled1ExitStatus, $Enabled3ExitStatus, $Enabled4ExitStatus, $Tmp) ;
my $DeviceName = "";
my $NumOutlets ;
my $ExitStatus ;
my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
my $CSV_FileName ;
my $CSV_FileHandle ;
my $CSVFileStr ;

# my $TK = Term::TermKey->new (\*STDIN);


my $cmd = "cat /proc/power/enabled1" ;
($cmdout, $cmderr, $Enabled1ExitStatus) = $mFiHostSSH->cmd($cmd) ;
$cmd = "cat /proc/power/enabled3" ;
($cmdout, $cmderr, $Enabled3ExitStatus) = $mFiHostSSH->cmd($cmd) ;
$cmd = "cat /proc/power/enabled4" ;
($cmdout, $cmderr, $Enabled4ExitStatus) = $mFiHostSSH->cmd($cmd) ;

if ($Enabled1ExitStatus == 1) {

	print "\nPlease check whether $DevIP is a mFi mPower Unit\n" ;
	exit(1) ;

} else {

	if ($Enabled3ExitStatus == 1) {

		$DeviceName = "mPower Mini" ;
		$NumOutlets = 1 ;

	} elsif ($Enabled4ExitStatus == 1) {

		$DeviceName = "mPower" ;
		$NumOutlets = 3 ;

	} else {

		$DeviceName = "mPower Pro" ;
		$NumOutlets = 8 ;

	}

}

my @CurrentOutletNames ;
my @CurrentOutletStatus ;

while (1) {

	&ClearScreen ();
	print "\nmFi " . $DeviceName . " Command Center\n" ;
	print "\nActive IP : $DevIP\n" ;
	print "\nMenu:\n" ;
	print "\n1. Check / Alter Outlet Names & Status" ;
	print "\n2. Power Logging Options" ;
	print "\n3. Exit Command Center" ;
	print "\n\nEnter choice: " ;

	my $Option = <STDIN> ;
	chomp $Option ;

	assert ( ($Option >= 1 && $Option <= 3), 'Selected Option Unavailable' ) ;

	&RefreshOutletStatus ();
	&RefreshOutletNames ();

	if ($Option == 1) {

		my $ShowSocketMenu = 1;
	
		while ($ShowSocketMenu == 1) {

			&ClearScreen ();
			print "\nmFi " . $DeviceName . " Command Center\n" ;
			print "\nActive IP : $DevIP\n" ;
			print "\nSocket Status\n" ;
			for (my $SocketNum = 1; $SocketNum <= $NumOutlets ; $SocketNum ++) {
				my $COIdx = $SocketNum - 1 ;
				printf "\n%0d. %s : %s", $SocketNum, $CurrentOutletNames[$COIdx], $CurrentOutletStatus[$COIdx] ;
			}
			print "\n\nMenu:\n" ;
			for (my $SocketNum = 1; $SocketNum <= $NumOutlets; $SocketNum ++) {
				printf "\n%d. Toggle Socket %d Status, i.e, Turn %s %s",
					$SocketNum, $SocketNum, $CurrentOutletNames[$SocketNum - 1], 
					($CurrentOutletStatus[$SocketNum - 1] eq "ON") ? "OFF" : "ON" ;
			}
			for (my $Ctr = $NumOutlets + 1; $Ctr <= 2*$NumOutlets; $Ctr ++) {
				printf "\n%d. Change Socket %d [ %s ] Name",
					$Ctr, $Ctr - $NumOutlets, $CurrentOutletNames[$Ctr - $NumOutlets - 1] ;
			}
			my $LastMenuOptionNumber = (2*$NumOutlets) + 1 ;
			printf "\n%d. Return to Main Menu", $LastMenuOptionNumber ;
 			print "\n\nEnter choice: ";
 			my $SocketMenuOption = <STDIN>;
 			chomp $SocketMenuOption ;

 			assert ( ($SocketMenuOption >= 1 && $SocketMenuOption <= $LastMenuOptionNumber), 'Selected Option Not Available' );

			if ($SocketMenuOption == $LastMenuOptionNumber) {
				$ShowSocketMenu = 0 ;
			} else {
				if ($SocketMenuOption >= 1 && $SocketMenuOption <= $NumOutlets) {
					&ToggleSocketStatus($SocketMenuOption) ;
				} else {
					printf "\nChange %s to : ",$CurrentOutletNames[$SocketMenuOption - $NumOutlets - 1] ;
					my $NewSocketName = <STDIN> ;
					chomp $NewSocketName ;
					&UpdateSocketName($SocketMenuOption - $NumOutlets - 1, $NewSocketName);
				}
			}

		}

	} elsif ($Option == 2) {

		my $ShowSocketMenu = 1;
	
		while ($ShowSocketMenu == 1) {

			&ClearScreen ();
			print "\nmFi " . $DeviceName . " Command Center\n" ;
			print "\nActive IP : $DevIP\n" ;
			print "\nPower Logging Options\n" ;
			for (my $SocketNum = 1; $SocketNum <= $NumOutlets ; $SocketNum ++) {
				my $COIdx = $SocketNum - 1 ;
				printf "\n%0d. %s : %s", $SocketNum, $CurrentOutletNames[$COIdx], $CurrentOutletStatus[$COIdx] ;
			}
			print "\n\nMenu:\n" ;
 			for (my $Ctr = 0; $Ctr < $NumOutlets; $Ctr ++) {
 				printf "\n%d. Power Logging for Socket %d [ %s ] (%s)",
 					$Ctr + 1, $Ctr + 1, $CurrentOutletNames[$Ctr], 
 					($CurrentOutletStatus[$Ctr] eq "ON") ? "Available" : "Not Available" ;
 			}
 			printf "\n%d. Power Logging for All Sockets Simultaneously", $NumOutlets + 1 ;
 			printf "\n%d. Return to Main Menu", $NumOutlets + 2 ;
 			print "\n\nEnter choice: ";
 			my $SocketMenuOption = <STDIN>;
 			chomp $SocketMenuOption ;
 
 			assert ( ($SocketMenuOption >= 1 && $SocketMenuOption <= ($NumOutlets + 2)), 'Selected Option Not Available' );

			if ($SocketMenuOption <= $NumOutlets) {
				assert ( ($CurrentOutletStatus[$SocketMenuOption-1] eq "ON"), 'Power Logging Not Available for Switched Off Outlet' );
			}
			if ($SocketMenuOption == ($NumOutlets + 2)) {
				$ShowSocketMenu = 0 ;
			} else {
 				print "\nPress (P - Start Logging to CSV File, L - Start Logging to Screen, Q - Stop Logging)\n" ;
 				my $WaitForInputs = 1 ;
				my @CurrPower ;
				my @CurrTotalPower ;
				my @AvPower ;
				for (my $Ctr = 0 ; $Ctr < $NumOutlets ; $Ctr ++) {
					$CurrPower[$Ctr] = 0 ;
					$CurrTotalPower[$Ctr] = 0 ;
					$AvPower[$Ctr] = 0 ;
				}
 				while ($WaitForInputs == 1) {
 					ReadMode ('cbreak') ;
 					my $KeyPress ;
 					while (not defined ($KeyPress = ReadKey(-1))) {
 					} 
					my $WriteToCSVFile = ($KeyPress eq "P" || $KeyPress eq "p") ? 1 : 0 ;
					my $ProceedWithLogging = ($WriteToCSVFile == 1 || $KeyPress eq "L" || $KeyPress eq "l") ? 1 : 0 ;

 					if ($ProceedWithLogging == 1) {
							
						my $SampleStartTime = [gettimeofday] ;
			 			my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
			 			my $year = 1900 + $yearOffset;
			 			my $theTime = "$hour-$minute-$second-$weekDays[$dayOfWeek]-$months[$month]-$dayOfMonth-$year" ;
			 			# Open the file
			 			my $SocketString = ($SocketMenuOption <= $NumOutlets) ? sprintf "Outlet-%d-%s", $SocketMenuOption, $CurrentOutletNames[$SocketMenuOption - 1] : "All-Outlets" ;
			 			$CSV_FileName = sprintf "%s-%s.csv", $SocketString, $theTime ;
			 			print "\n\nStarted recording instantaneous power data" ;
						printf " for Socket: %s\n\n", ($SocketMenuOption == ($NumOutlets + 1)) ? "All-Sockets" : $CurrentOutletNames[$SocketMenuOption - 1];
			 			print " to $CSV_FileName\n\n" if ($WriteToCSVFile == 1) ;
			 			if ($SocketMenuOption != ($NumOutlets + 1)) {
			 				$CSVFileStr = "Time,Instantaneous Power,Average Power\n" ;
			 			} else {
			 				$CSVFileStr = sprintf "Time" ;
							for (my $TmpCtr = 0; $TmpCtr < $NumOutlets; $TmpCtr ++) {
								$CSVFileStr .= sprintf ", Instantaneous Power %s", $CurrentOutletNames[$TmpCtr] ;
							}
							for (my $TmpCtr = 0; $TmpCtr < $NumOutlets; $TmpCtr ++) {
								$CSVFileStr .= sprintf ", Average Power %s", $CurrentOutletNames[$TmpCtr] ;
							}
							$CSVFileStr .= "\n" ;
			 			}
						my $CurrNumSamples = 0 ;
						my $IntermediateKeyPress ;

						$cmd = sprintf "cat ";
						for (my $Ctr = 0; $Ctr < $NumOutlets ; $Ctr ++) {
							$cmd .= sprintf "/proc/power/active_pwr%d ",($Ctr+1) ;
						}
						do {
							$SampleStartTime = [gettimeofday] ;
							($cmdout,$cmderr,$ExitStatus) = $mFiHostSSH->cmd($cmd);
							my $CurrTime = [gettimeofday] ;
							my @PowerStrings = split /\n/, $cmdout ;
							my $SockCtr = 0;
							foreach my $PowerNum (@PowerStrings) {
								assert (($SockCtr < $NumOutlets), 'Error in mPower unit output for power query: $cmd , $cmdout');
								$CurrPower[$SockCtr ++] = $PowerNum ;
							}
							my $Elapsed = tv_interval ($SampleStartTime, $CurrTime );
							my $NumWholeSeconds = int ($Elapsed) ;
							my $FictRec = 0 ;
							do {
								$CurrNumSamples ++ ;
								for (my $Ctr = 0; $Ctr < $NumOutlets; $Ctr ++) {
									$CurrTotalPower[$Ctr] += $CurrPower[$Ctr] ;
									$AvPower[$Ctr] = ($CurrTotalPower[$Ctr] * 1.0) / $CurrNumSamples ;
								}
								if ($SocketMenuOption <= $NumOutlets) {
									$CSVFileStr .= sprintf "%d, %.04f, %.04f\n", $CurrNumSamples, 
										$CurrPower[$SocketMenuOption - 1], $AvPower[$SocketMenuOption - 1];
									printf "\r%04d: Current Power: %.04f, Average Power: %.04f\t\t\t", $CurrNumSamples,
										$CurrPower[$SocketMenuOption - 1], $AvPower[$SocketMenuOption - 1];
										
								} else {
									$CSVFileStr .= sprintf "%d", $CurrNumSamples ;
									printf "\r%04d: Current Power: (%.04f", $CurrNumSamples, $CurrPower[0] ;
									for (my $SockNum = 0; $SockNum < $NumOutlets; $SockNum ++) {
										$CSVFileStr .= sprintf ", %.04f", $CurrPower[$SockNum] ;
										printf ", %.04f", $CurrPower[$SockNum] if ($SockNum != 0);
									}
									printf "), Average Power: (%.04f", $AvPower[0] ;
									for (my $SockNum = 0; $SockNum < $NumOutlets; $SockNum ++) {
										$CSVFileStr .= sprintf ", %.04f", $AvPower[$SockNum] ;
										printf ", %.04f", $AvPower[$SockNum] if ($SockNum != 0);
									}
									$CSVFileStr .= ("\n") ;
									printf ")\t\t\t" ;
								}
								printf "\b\b\b: RS: %0d of %0d", $FictRec, $NumWholeSeconds if $Debug ;
								$FictRec ++ ;									
							} while ($FictRec < $NumWholeSeconds);
							$CurrTime = [gettimeofday] ;
							$Elapsed = tv_interval ($SampleStartTime, $CurrTime) ;
							my $SleepInterval = 1.00 - ($Elapsed - int($Elapsed)) ;
							Time::HiRes::sleep ($SleepInterval) ;
							$IntermediateKeyPress = ReadKey(-1);
							if (not defined $IntermediateKeyPress) {
								$IntermediateKeyPress = 'c' ;
							}
						} while (!($IntermediateKeyPress eq "q" || $IntermediateKeyPress eq "Q")) ;

						if ($WriteToCSVFile == 1) {
							open ($CSV_FileHandle, ">$CSV_FileName") or 
								die "Can't open $CSV_FileName for writing\nRaw CSV Data: $CSVFileStr" ;
							printf $CSV_FileHandle "$CSVFileStr" ;
							close ($CSV_FileHandle) ;
						}
						$WaitForInputs = 0 ;

 					} elsif ($KeyPress eq "Q" || $KeyPress eq "q") {
 						$WaitForInputs = 0;
 					}
 				}
 				ReadMode 0 ;
			}

		}

	} else {

		exit(0) ;

	}

}

sub UpdateSocketName {

	my $SocketNumToChange = shift ; # 0 start
	my $NewName = shift ;
	$cmd = sprintf "sed -i '/port.%d.label.*/c\\port.%d.label=%s' /var/etc/persistent/cfg/config_file", 
		$SocketNumToChange, $SocketNumToChange, $NewName ;
	($cmdout,$cmderr,$ExitStatus) = $mFiHostSSH->cmd($cmd);
	print "Command:\n $cmd \nOutput:\n $cmdout" if $Debug ;
	&RefreshOutletNames () ;

}


sub ToggleSocketStatus {
	
	my $SocketNumToToggle = shift ;
	my $ValToPush = ($CurrentOutletStatus[$SocketNumToToggle - 1] eq "ON") ? 0 : 1 ;
	$cmd = sprintf "echo \"%d\" > /proc/power/relay%d",  $ValToPush, $SocketNumToToggle ;
	($cmdout,$cmderr,$ExitStatus) = $mFiHostSSH->cmd($cmd);
	print "Command:\n $cmd \nOutput:\n $cmdout" if $Debug ;
	&RefreshOutletStatus () ;

}

sub RefreshOutletStatus {

	my $ExitStatus ;
	for ($Tmp = 1; $Tmp <= $NumOutlets; $Tmp ++) {
		$cmd = sprintf "cat /proc/power/relay%d", $Tmp ;
		($cmdout,$cmderr,$ExitStatus) = $mFiHostSSH->cmd($cmd);
		print "Command:\n $cmd \nOutput:\n $cmdout" if $Debug ;
		$CurrentOutletStatus[$Tmp - 1] = ($cmdout == 1) ? "ON" : "OFF" ;
	}

}

sub RefreshOutletNames {

	$cmd = "grep label /var/etc/persistent/cfg/config_file" ;
	($cmdout, $cmderr, $Tmp) = $mFiHostSSH->cmd($cmd) ;
	print "Command:\n $cmd \nOutput:\n $cmdout" if $Debug ;
	for ($Tmp = 0; $Tmp < $NumOutlets; $Tmp ++) {

		($CurrentOutletNames[$Tmp]) = ($cmdout =~ /port.$Tmp.label=(.*)/);

	}

}
 
sub ClearScreen {
 
 	system $^O eq 'MSWin32' ? 'cls' : 'clear';
 
}

END { 
	ReadMode 0 ;
	if (defined $mFiHostSSH) {
		$mFiHostSSH->cmd("exit");
	}
}
